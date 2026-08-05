#!/usr/bin/env python3
"""게이트 러너 — 선언된 검사를 시점(stage)별로 실행한다.

왜 필요한가
-----------
지금 하네스에는 커밋 직전(pre-commit)과 CI 사이가 비어 있다. pre-commit 은
변경 라인만 보고, CI 는 너무 늦은 데다 구현이 따로 놀아 "로컬은 통과했는데
CI 가 깨지는" 드리프트가 생긴다.

같은 러너를 pre-commit·pre-push·CI 셋이 호출하게 해서 그 틈을 없앤다.
검사 목록은 `.claude/gates.json` 한 곳에만 두고, 실행 시점만 stage 로 나눈다.

왜 YAML 이 아니라 JSON 인가
---------------------------
PyYAML 은 표준 라이브러리가 아니다. 하네스는 남의 레포에 주입되므로 인터프리터
업그레이드 한 번에 사라질 수 있는 의존성을 게이트 경로에 둘 수 없다. 실제로
`~/.claude` 의 규칙 레지스트리가 brew python 3.14 업그레이드로 PyYAML 을 잃고
전 규칙이 무음 통과한 사례가 있다. 주석을 못 쓰는 불편은 `note` 필드로 갚는다.

SKIP 은 PASS 가 아니다
----------------------
도구가 없어 건너뛴 검사를 통과로 세면, 아무것도 설치 안 된 환경에서 전 항목
초록불이 뜬다. SKIP 은 별도 상태로 세고 요약에서 이름까지 다시 부른다.

gates.json 형식
---------------
  {
    "gates": [
      {
        "name": "changed-line lint",
        "cmd": "ruff check",
        "stages": ["pre-commit", "pre-push", "ci"],
        "requires": "ruff",          # 이 실행 파일이 없으면 SKIP (선택)
        "requires_file": "tests",    # 이 경로가 없으면 SKIP (문자열 또는 배열, 선택)
        "allow_failure": false,      # true 면 실패해도 계속 (선택)
        "note": "사람이 읽는 설명"    # (선택)
      }
    ]
  }

사용법
------
  python3 .claude/scripts/gate-runner.py --stage pre-push
  python3 .claude/scripts/gate-runner.py --stage ci --no-fail-fast
  python3 .claude/scripts/gate-runner.py --list

종료 코드
---------
  0  전 게이트 통과 (SKIP 포함)
  1  게이트 실패 — 고쳐야 한다
  2  내부 오류 (gates.json 손상 등) — 하네스가 깨진 것이지 코드 문제가 아니다
"""

import argparse
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import time

VALID_STAGES = ("pre-commit", "pre-push", "ci")
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

GREEN, RED, YELLOW, DIM, RESET = (
    ("\033[0;32m", "\033[0;31m", "\033[1;33m", "\033[2m", "\033[0m")
    if sys.stdout.isatty()
    else ("", "", "", "", "")
)


def repo_root(explicit):
    return explicit or os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()


def emit(event, **fields):
    """hook-io.py 의 record_event 를 재사용한다.

    파일명에 하이픈이 있어 일반 import 가 안 된다. 두 스크립트는 항상 같은
    디렉터리로 복사되므로 경로는 옆이다 (domain-gate.py 와 같은 방식).
    계측은 절대 게이트를 막지 않는다 — 어떤 실패든 조용히 넘긴다.
    """
    try:
        path = os.path.join(SCRIPT_DIR, "hook-io.py")
        spec = importlib.util.spec_from_file_location("hook_io", path)
        if spec is None or spec.loader is None:
            return
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        module.record_event(event, "gate-runner.py", **fields)
    except Exception:  # noqa: BLE001 - 계측 실패는 무해해야 한다
        pass


def load_gates(path):
    """(gates, error) 를 돌려준다. error 가 있으면 호출부가 종료 코드를 정한다."""
    if not os.path.exists(path):
        return None, None  # 미설치 — 오류가 아니다
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError) as exc:
        return None, f"{path} 를 읽을 수 없습니다: {exc}"

    gates = data.get("gates") if isinstance(data, dict) else None
    if not isinstance(gates, list):
        return None, f"{path} 에 최상위 'gates' 배열이 없습니다"

    for index, gate in enumerate(gates):
        if not isinstance(gate, dict):
            return None, f"gates[{index}] 가 object 가 아닙니다"
        for field in ("name", "cmd", "stages"):
            if not gate.get(field):
                return None, f"gates[{index}] 에 '{field}' 가 없습니다"
        # stages 를 문자열로 쓰면 set("ci") 가 {'c','i'} 가 되어 조용히 아무 stage 에도
        # 안 걸린다. 오타 한 번에 게이트가 사라지므로 타입을 먼저 본다.
        if not isinstance(gate["stages"], list):
            return None, (
                f"gates[{index}] '{gate['name']}' 의 stages 는 배열이어야 합니다 "
                f'(예: ["pre-push", "ci"])'
            )
        unknown = set(gate["stages"]) - set(VALID_STAGES)
        if unknown:
            return None, (
                f"gates[{index}] '{gate['name']}' 의 알 수 없는 stage: "
                f"{sorted(unknown)} (가능: {list(VALID_STAGES)})"
            )
    return gates, None


def run_gate(gate, root):
    """(status, seconds, output) — status 는 PASS / FAIL / SKIP."""
    requires = gate.get("requires")
    if requires and not shutil.which(requires):
        return "SKIP", 0.0, f"{requires} 없음"

    # 대상이 아예 없는 검사는 실패가 아니라 해당 없음이다. tests 디렉터리가
    # 없는데 pytest 를 돌리면 "수집된 테스트 없음"으로 실패해, 하네스를 깐
    # 첫날 전 게이트가 빨간불이 된다. 그러면 아무도 안 쓴다.
    required_files = gate.get("requires_file") or []
    if isinstance(required_files, str):
        required_files = [required_files]
    missing = [f for f in required_files if not os.path.exists(os.path.join(root, f))]
    if missing:
        return "SKIP", 0.0, f"{', '.join(missing)} 없음"

    started = time.monotonic()
    try:
        completed = subprocess.run(
            gate["cmd"],
            shell=True,
            cwd=root,
            capture_output=True,
            text=True,
        )
    except OSError as exc:
        return "FAIL", time.monotonic() - started, str(exc)

    elapsed = time.monotonic() - started
    output = (completed.stdout or "") + (completed.stderr or "")
    if completed.returncode == 0:
        return "PASS", elapsed, output
    if gate.get("allow_failure"):
        # SKIP 으로 세지 않는다. SKIP 은 "실행하지 못했다"는 뜻인데 이건 실행하고
        # 실패한 것이다. 섞으면 "실행된 게이트가 없습니다" 경고가 잘못 뜬다.
        return "WARN", elapsed, f"실패했지만 allow_failure: {output}"
    return "FAIL", elapsed, output


def cmd_list(gates):
    for gate in gates:
        stages = ",".join(gate["stages"])
        print(f"  {gate['name']:32} [{stages}]")
        print(f"  {DIM}{'':32} $ {gate['cmd']}{RESET}")
        if gate.get("note"):
            print(f"  {DIM}{'':32} {gate['note']}{RESET}")
    return 0


def cmd_run(gates, stage, root, fail_fast):
    selected = [g for g in gates if stage in g["stages"]]
    if not selected:
        print(f"[gate-runner] stage '{stage}' 에 해당하는 게이트가 없습니다.")
        return 0

    print(f"[gate-runner] stage={stage} · 게이트 {len(selected)}개")
    results = []
    total_started = time.monotonic()

    for index, gate in enumerate(selected, start=1):
        print(f"▶ [{index}/{len(selected)}] {gate['name']}")
        status, elapsed, output = run_gate(gate, root)
        results.append((gate, status, elapsed))

        if status == "PASS":
            print(f"  {GREEN}✓ PASS{RESET}  ({elapsed:.1f}초)")
        elif status == "WARN":
            print(f"  {YELLOW}! WARN{RESET}  ({elapsed:.1f}초) {output.strip()[:120]}")
        elif status == "SKIP":
            print(f"  {YELLOW}- SKIP{RESET}  {output.strip()[:120]}")
        else:
            print(f"  {RED}✗ FAIL{RESET}  ({elapsed:.1f}초)")
            if output.strip():
                for line in output.rstrip().splitlines():
                    print(f"    {line}")
            if fail_fast:
                print(f"\n{RED}fail-fast: 첫 실패에서 멈춥니다.{RESET}")
                break

    return summarize(results, stage, root, time.monotonic() - total_started)


def summarize(results, stage, root, total_elapsed):
    passed = [g for g, s, _ in results if s == "PASS"]
    failed = [g for g, s, _ in results if s == "FAIL"]
    skipped = [g for g, s, _ in results if s == "SKIP"]
    warned = [g for g, s, _ in results if s == "WARN"]

    print("\n" + "─" * 52)
    summary = (
        f"  {GREEN}PASS {len(passed)}{RESET} · "
        f"{RED}FAIL {len(failed)}{RESET} · "
        f"{YELLOW}SKIP {len(skipped)}{RESET}"
    )
    if warned:
        summary += f" · {YELLOW}WARN {len(warned)}{RESET}"
    print(f"{summary}   (총 {total_elapsed:.1f}초)")

    if warned:
        names = ", ".join(g["name"] for g in warned)
        print(f"  {YELLOW}! allow_failure 로 통과 처리됨: {names}{RESET}")

    # SKIP 을 통과로 읽는 것을 막는다. 이름을 다시 불러야 눈에 들어온다.
    if skipped:
        names = ", ".join(g["name"] for g in skipped)
        print(f"  {YELLOW}⚠ SKIP {len(skipped)}건은 통과가 아닙니다: {names}{RESET}")

    # 전부 SKIP 이면 게이트가 하나도 실행되지 않은 것이다. 종료 코드는 0 이라
    # 초록불로 보이지만 아무것도 검사하지 않았다. 도구가 없는 머신에서 push 를
    # 통째로 막는 건 과하므로 통과시키되, 이 상태를 조용히 넘기지는 않는다.
    # (검사가 0건인 것은 안전 신호가 아니라 스캐너가 없다는 신호다.)
    if skipped and not passed and not failed and not warned:
        print(
            f"  {RED}⚠ 실행된 게이트가 없습니다 — 이 push 는 아무것도 검증되지 "
            f"않았습니다.{RESET}"
        )
        print(
            f"  {DIM}  필요한 도구를 설치하거나 .claude/gates.json 의 "
            f"requires·requires_file 을 이 프로젝트에 맞게 고치세요.{RESET}"
        )
    if failed:
        names = ", ".join(g["name"] for g in failed)
        print(f"  {RED}✗ 실패: {names}{RESET}")
    print("─" * 52)

    emit(
        "gate_run",
        repo=root,
        stage=stage,
        detail=json.dumps(
            {
                "pass": [g["name"] for g in passed],
                "fail": [g["name"] for g in failed],
                "skip": [g["name"] for g in skipped],
                "warn": [g["name"] for g in warned],
            },
            ensure_ascii=False,
        ),
    )
    return 1 if failed else 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--stage", choices=VALID_STAGES, help="실행할 시점")
    parser.add_argument("--list", action="store_true", help="게이트 목록만 출력")
    parser.add_argument("--repo", default="", help="레포 루트")
    parser.add_argument(
        "--no-fail-fast",
        action="store_true",
        help="첫 실패에서 멈추지 않고 전부 실행",
    )
    args = parser.parse_args(argv)

    root = repo_root(args.repo)
    config = os.path.join(root, ".claude", "gates.json")
    gates, error = load_gates(config)

    if error:
        # 손상된 설정은 조용히 넘기지 않는다. 하네스가 깨진 것을 알려야 한다.
        print(f"[gate-runner] {error}", file=sys.stderr)
        return 2
    if gates is None:
        # 미설치는 정상 상황이다 (하네스를 안 깐 레포에서 CI 가 도는 경우 등).
        print(f"[gate-runner] {config} 없음 — 건너뜁니다.")
        return 0

    if args.list:
        return cmd_list(gates)
    if not args.stage:
        parser.error("--stage 또는 --list 중 하나가 필요합니다")
    return cmd_run(gates, args.stage, root, fail_fast=not args.no_fail_fast)


if __name__ == "__main__":
    sys.exit(main())
