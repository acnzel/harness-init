#!/usr/bin/env python3
"""AGENTS.md 의 자동 구간을 실제 설정에서 렌더한다.

왜 생성하는가
-------------
문서에 규칙을 손으로 옮겨 적으면 원본과 어긋난다. 이 레포에도 이미 그런 중복이
있었다 — `.gemini/styleguide.md` 가 `.claude/rules/` 의 레이어·테스트 규칙을 다시
쓰고 있어서, 한쪽을 고치면 다른 쪽이 조용히 낡았다.

드리프트를 검사로 잡는 방법도 있지만, 더 싼 답은 **드리프트할 대상을 없애는 것**이다.
파생 문서를 손으로 쓰지 않고 생성물로 만들면 어긋날 수가 없다.

무엇을 렌더하는가
-----------------
지금 두 가지다. 둘 다 다른 파일이 정본이고, 문서는 그것의 표현일 뿐이다.

  검증 파이프라인  ← .claude/gates.json   (언제 무엇이 도는가)
  금지 명령        ← .claude/settings.json permissions.deny

두 번째가 중요한 이유: `settings.json` 의 deny 는 Claude Code 에만 적용된다.
Codex·Cursor 같은 다른 에이전트는 그 파일을 읽지 않으므로, AGENTS.md 에 같은
목록이 **글로도** 있어야 전달된다. 중복이 아니라 다른 청중을 위한 유일한 경로다.
그래서 손으로 옮겨 적지 않고 deny 목록에서 렌더한다.

마커 규약
---------
자동 구간은 마커 사이다. 마커가 정확히 한 쌍이 아니거나 순서가 뒤집혀 있으면
덮어쓰지 않고 실패한다. 잘못 잘라내면 사람이 쓴 내용이 유실된다.

사용법
------
  python3 scripts/render-agents.py --repo .           # 갱신
  python3 scripts/render-agents.py --repo . --check   # 낡았으면 exit 1 (CI/pre-commit)

종료 코드
---------
  0  갱신 완료 또는 이미 최신
  1  --check 에서 낡음
  2  마커 손상·AGENTS.md 없음 등 내부 오류
"""

import argparse
import json
import os
import sys

MARKER_START = "<!-- harness:auto:start -->"
MARKER_END = "<!-- harness:auto:end -->"

STAGE_LABELS = [
    ("pre-commit", "커밋 직전"),
    ("pre-push", "push 직전"),
    ("ci", "CI"),
]


def read_json(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return None


def render_pipeline(gates):
    lines = ["### 검증 파이프라인", ""]
    if not gates:
        lines += [
            "`.claude/gates.json` 이 없거나 비어 있습니다. 통합 게이트가 설정되지 않았습니다.",
            "",
        ]
        return lines

    lines += ["| 시점 | 검사 |", "|---|---|"]
    for stage, label in STAGE_LABELS:
        names = [g["name"] for g in gates if stage in g.get("stages", [])]
        lines.append(f"| {label} | {', '.join(names) if names else '없음'} |")

    lines += [
        "",
        "push 직전과 CI 는 **같은 러너·같은 선언**을 쓴다. 한쪽에만 검사를 추가하면",
        "로컬 통과와 CI 실패가 갈라진다.",
        "",
        "```bash",
        "python3 .claude/scripts/gate-runner.py --list              # 목록",
        "python3 .claude/scripts/gate-runner.py --stage pre-push    # 직접 실행",
        "```",
        "",
        "SKIP 은 통과가 아니다. 도구가 없어 건너뛴 검사를 통과로 세지 말 것.",
        "",
    ]
    return lines


def render_forbidden(deny):
    lines = ["### 금지 명령", ""]
    if not deny:
        lines += ["설정된 금지 명령이 없습니다.", ""]
        return lines

    lines += [
        "아래는 `.claude/settings.json` 의 `permissions.deny` 에서 생성됩니다.",
        "Claude Code 는 이를 기계적으로 차단하지만 다른 에이전트는 그 파일을 읽지",
        "않으므로, 플랫폼과 무관하게 **글로도** 금지임을 명시한다.",
        "",
    ]
    for pattern in deny:
        lines.append(f"- `{pattern}`")
    lines += [
        "",
        "게이트 우회(`--no-verify` 등)는 금지가 아니라 **표면화 대상**이다. 우회했으면",
        "사유를 PR 설명에 남긴다. 조용히 넘기지 말 것.",
        "",
    ]
    return lines


def build_block(repo):
    gates_data = read_json(os.path.join(repo, ".claude", "gates.json")) or {}
    gates = gates_data.get("gates") if isinstance(gates_data, dict) else None
    settings = read_json(os.path.join(repo, ".claude", "settings.json")) or {}
    deny = (settings.get("permissions") or {}).get("deny") or []

    lines = [
        MARKER_START,
        "<!-- 이 구간은 .claude/gates.json 과 .claude/settings.json 에서 생성됩니다.",
        "     직접 편집하지 마세요 — scripts/render-agents.py 가 덮어씁니다. -->",
        "",
    ]
    lines += render_pipeline(gates)
    lines += render_forbidden(deny)
    lines.append(MARKER_END)
    return "\n".join(lines)


def replace_block(content, block, path):
    """(새 내용, 오류) — 마커가 온전할 때만 자른다."""
    starts = content.count(MARKER_START)
    ends = content.count(MARKER_END)
    if starts != 1 or ends != 1:
        return None, (
            f"{path} 의 마커는 정확히 한 쌍이어야 합니다 "
            f"(현재 start {starts}개 / end {ends}개). 잘못 자르면 사람이 쓴 내용이 "
            f"유실되므로 덮어쓰지 않습니다."
        )
    start = content.find(MARKER_START)
    end = content.find(MARKER_END)
    if start > end:
        return None, f"{path} 의 마커 순서가 뒤집혀 있습니다"
    return content[:start] + block + content[end + len(MARKER_END) :], None


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--repo", default=".", help="레포 루트")
    parser.add_argument(
        "--check",
        action="store_true",
        help="쓰지 않고 최신 여부만 확인 (낡았으면 exit 1)",
    )
    args = parser.parse_args(argv)

    repo = args.repo or "."
    path = os.path.join(repo, "AGENTS.md")
    if not os.path.exists(path):
        # AGENTS.md 가 없는 레포는 하네스 미설치이거나 이전 버전이다.
        # 오류로 커밋을 막지 않는다.
        print(f"[render-agents] {path} 없음 — 건너뜁니다.")
        return 0

    try:
        content = open(path, encoding="utf-8").read()
    except OSError as exc:
        print(f"[render-agents] {path} 를 읽을 수 없습니다: {exc}", file=sys.stderr)
        return 2

    if MARKER_START not in content and MARKER_END not in content:
        print(
            f"[render-agents] {path} 에 자동 구간 마커가 없습니다 — 건너뜁니다.\n"
            f"  자동 갱신을 원하면 아래 두 줄을 넣으세요:\n"
            f"    {MARKER_START}\n    {MARKER_END}"
        )
        return 0

    updated, error = replace_block(content, build_block(repo), path)
    if error:
        print(f"[render-agents] {error}", file=sys.stderr)
        return 2

    if updated == content:
        return 0
    if args.check:
        print(
            f"[render-agents] {path} 의 자동 구간이 낡았습니다.\n"
            f"  갱신: python3 .claude/scripts/render-agents.py --repo .",
            file=sys.stderr,
        )
        return 1

    try:
        open(path, "w", encoding="utf-8").write(updated)
    except OSError as exc:
        print(f"[render-agents] {path} 를 쓸 수 없습니다: {exc}", file=sys.stderr)
        return 2
    print(f"[render-agents] {path} 자동 구간 갱신")
    return 0


if __name__ == "__main__":
    sys.exit(main())
