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
    try:
        out = subprocess.run(
            ["git", "diff", "--name-only", f"{base}...{head}"],
            cwd=repo,
            capture_output=True,
            text=True,
            check=True,
        ).stdout
    except (OSError, subprocess.CalledProcessError):
        return []
    return [line for line in out.splitlines() if line.strip()]


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
    files = changed_files(repo, base, head)
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
        f"- 변경 파일: {len(files)}개",
    ]

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
        # 순서가 뒤집힌 손상 상태. 자르면 사람이 쓴 내용이 유실되므로 손대지 않고
        # 앞에 붙이기만 한다.
    elif starts == 0 and ends == 0:
        return block + "\n\n" + body if body.strip() else block

    # 마커가 여러 개거나 짝이 안 맞으면 잘라내지 않는다. 덧붙이는 쪽이 안전하다.
    return block + "\n\n" + body


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
    if args.body_file and os.path.exists(args.body_file):
        body = open(args.body_file, encoding="utf-8").read()
    elif not sys.stdin.isatty():
        body = sys.stdin.read()

    sys.stdout.write(merge(body, block) if body.strip() else block)
    return 0


if __name__ == "__main__":
    sys.exit(main())
