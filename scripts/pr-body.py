#!/usr/bin/env python3
"""PR 본문의 자동 수집 구간을 만든다. 사람이 쓴 내용은 건드리지 않는다.

왜 이 파일이 있나
-----------------
이전 워크플로는 PR 본문을 **통째로 덮어썼다**. 작성자가 템플릿을 채워 PR 을 열면
그 내용이 그대로 사라졌다. 게다가 OpenAI 로 diff 요약을 생성했는데, 리뷰어는 diff 를
직접 읽을 수 있으므로 얻는 게 적고 환각 위험만 남았다.

이제 두 가지가 다르다.
  1. 마커 사이만 갱신한다. 마커가 없으면 본문 맨 앞에 붙이고 나머지는 보존한다.
  2. LLM 을 쓰지 않는다. git 과 gates.json 에서 기계적으로 얻는 사실만 적는다.
     (domain-drift 가 "LLM 미사용, 환각 없음"을 택한 것과 같은 이유다.)

사용법
------
  python3 pr-body.py --base <sha> --head <sha> [--body-file 현재본문.md] [--repo .]

현재 본문을 stdin 이나 --body-file 로 주면 병합 결과를, 안 주면 자동 구간만 낸다.
결과는 stdout 으로 나온다.
"""

import argparse
import json
import os
import subprocess
import sys

MARKER_START = "<!-- harness:pr:start -->"
MARKER_END = "<!-- harness:pr:end -->"
FILE_LIMIT = 30

# 하네스 자체 설정. 바뀌면 게이트의 강도가 달라지므로 리뷰에서 짚어야 한다.
HARNESS_PATHS = (
    ".claude/gates.json",
    ".claude/settings.json",
    ".claude/hooks/",
    ".claude/scripts/",
    ".pre-commit-config.yaml",
    "AGENTS.md",
)


def changed_files(repo, base, head):
    """(파일 목록, 성공 여부) — 실패를 '변경 0건'으로 위장하지 않는다.

    fetch-depth 부족이나 잘못된 SHA 로 git diff 가 실패하면 빈 목록이 나오는데,
    그걸 그대로 "변경 파일: 0개"로 적으면 PR 본문이 거짓을 말한다.
    """
    try:
        out = subprocess.run(
            ["git", "diff", "--name-only", f"{base}...{head}"],
            cwd=repo,
            capture_output=True,
            text=True,
            check=True,
        ).stdout
    except (OSError, subprocess.CalledProcessError):
        return [], False
    return [line for line in out.splitlines() if line.strip()], True


def ci_gate_names(repo):
    path = os.path.join(repo, ".claude", "gates.json")
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError):
        return []
    gates = data.get("gates") if isinstance(data, dict) else None
    if not isinstance(gates, list):
        return []
    return [
        g["name"] for g in gates if isinstance(g, dict) and "ci" in g.get("stages", [])
    ]


def build_block(repo, base, head):
    files, diff_ok = changed_files(repo, base, head)
    gates = ci_gate_names(repo)
    touched_harness = sorted(
        {p for f in files for p in HARNESS_PATHS if f == p or f.startswith(p)}
    )

    lines = [
        MARKER_START,
        "<!-- 자동 수집 구간입니다. 이 마커 사이는 워크플로가 갱신하므로 직접 쓰지 마세요.",
        "     마커 밖에 쓴 내용은 보존됩니다. -->",
        "",
        "### 자동 수집",
        "",
        f"- 기준 SHA: `{base[:12]}` → `{head[:12]}`",
    ]
    if diff_ok:
        lines.append(f"- 변경 파일: {len(files)}개")
    else:
        lines.append(
            "- 변경 파일: **집계 실패** (git diff 를 실행할 수 없었습니다. "
            "fetch-depth 나 SHA 를 확인하세요.)"
        )

    if files:
        lines.append("")
        lines.append("<details><summary>변경 파일 목록</summary>")
        lines.append("")
        for path in files[:FILE_LIMIT]:
            lines.append(f"- `{path}`")
        if len(files) > FILE_LIMIT:
            lines.append(f"- … 외 {len(files) - FILE_LIMIT}개")
        lines.append("")
        lines.append("</details>")

    lines.append("")
    if gates:
        lines.append(f"- CI 게이트: {', '.join(gates)}")
    else:
        lines.append("- CI 게이트: 선언 없음 (`.claude/gates.json` 확인 필요)")

    if touched_harness:
        lines += [
            "",
            "> **하네스 설정이 변경되었습니다** — 게이트의 강도가 달라질 수 있습니다.",
            "> 변경 경로: " + ", ".join(f"`{p}`" for p in touched_harness),
            "> 검사를 약화시키는 변경이라면 사유를 본문에 남겨주세요.",
        ]

    lines += ["", MARKER_END]
    return "\n".join(lines)


def merge(body, block):
    """마커가 온전하면 그 사이만, 없으면 맨 앞에 붙인다."""
    starts = body.count(MARKER_START)
    ends = body.count(MARKER_END)

    if starts == 1 and ends == 1:
        start = body.find(MARKER_START)
        end = body.find(MARKER_END)
        if start < end:
            return body[:start] + block + body[end + len(MARKER_END) :]
        # 순서가 뒤집힌 손상 상태. 자르면 사람이 쓴 내용이 유실되므로 손대지 않는다.
    elif starts == 0 and ends == 0:
        return block + "\n\n" + body if body.strip() else block

    # 마커가 여러 개거나 짝이 안 맞는 손상 상태. 사람이 쓴 내용을 잘라낼 수 없으니
    # 앞에 붙이되, **직전에 우리가 붙인 블록은 교체**한다. 그냥 붙이기만 하면
    # 실행할 때마다 본문이 계속 자라 결국 본문이 자동 블록으로 뒤덮인다.
    stripped = body.lstrip()
    offset = len(body) - len(stripped)
    if stripped.startswith(MARKER_START):
        first_end = stripped.find(MARKER_END)
        if first_end != -1:
            rest = stripped[first_end + len(MARKER_END) :].lstrip("\n")
            return block + "\n\n" + rest if rest.strip() else block
    return block + "\n\n" + body[offset:]


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--base", required=True)
    parser.add_argument("--head", required=True)
    parser.add_argument("--repo", default=".")
    parser.add_argument(
        "--body-file", default="", help="현재 PR 본문 파일 (없으면 stdin)"
    )
    args = parser.parse_args(argv)

    block = build_block(args.repo, args.base, args.head)

    body = ""
    if args.body_file:
        # 읽지 못하면 **아무것도 출력하지 않고 실패한다**. 빈 본문으로 진행하면
        # 자동 블록만 남은 결과가 나오고, 호출부가 그걸 그대로 PR 에 쓰면 사람이 쓴
        # 본문이 통째로 지워진다. 이 스크립트가 없애려던 사고가 바로 그것이다.
        # stdin 으로 대체하지도 않는다. 파이프가 안 닫힌 환경에서 그대로 멈춘다.
        try:
            body = open(args.body_file, encoding="utf-8").read()
        except OSError as exc:
            print(
                f"[pr-body] --body-file 을 읽을 수 없습니다: {exc}\n"
                f"[pr-body] 본문을 덮어쓰지 않도록 아무것도 출력하지 않고 멈춥니다.",
                file=sys.stderr,
            )
            return 2
    elif not sys.stdin.isatty():
        body = sys.stdin.read()

    sys.stdout.write(merge(body, block) if body.strip() else block)
    return 0


if __name__ == "__main__":
    sys.exit(main())
