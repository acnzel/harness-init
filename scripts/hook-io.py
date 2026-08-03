#!/usr/bin/env python3
"""훅 공용 입출력 — 페이로드 파싱(parse)과 발화 기록(event).

왜 이 파일이 있나
-----------------
Claude Code 훅은 도구 정보를 **stdin 에 JSON 으로** 넘긴다. 환경변수가 아니다.
harness-init 의 pre-bash-guard.sh 는 `${TOOL_INPUT:-}` 를 읽고 있었고, 그래서
migrate·DROP TABLE·WHERE 없는 DELETE 경고가 **한 번도 발화한 적이 없었다**.

2026-08-03 실측:
  stdin JSON 입력      → 무음, exit 0   (죽어 있음)
  TOOL_INPUT 강제 주입 → 경고 정상 출력 (로직은 멀쩡, 배선만 틀림)

훅마다 각자 파싱하면 같은 불일치가 또 생긴다. 파싱은 여기 한 곳에만 둔다.

두 서브커맨드가 한 파일에 있는 이유
-----------------------------------
parse 는 Bash 도구 호출마다 돌고, event 는 실제 발화 때만 돈다. 호출 빈도가
다르지만 둘 다 인터프리터 한 번이면 끝나는 작업이라, 파일을 나누면 훅이
source 해야 할 경로만 늘어난다.

사용법
------
  python3 hook-io.py parse                    # stdin: 훅 JSON → stdout: 셸 대입문
  python3 hook-io.py event --event gate_fired --source pre-bash-guard.sh \
      --tool Bash --detail "migrate"
"""

import argparse
import json
import os
import shlex
import sys
from datetime import datetime, timezone

DETAIL_LIMIT = 400
EMPTY = {
    "HOOK_EVENT": "",
    "HOOK_TOOL": "",
    "HOOK_COMMAND": "",
    "HOOK_FILE_PATH": "",
    "HOOK_SESSION": "",
    "HOOK_CWD": "",
}


def repo_root(explicit):
    """CLAUDE_PROJECT_DIR 를 우선한다 — 훅은 임의 cwd 에서 실행될 수 있다."""
    return explicit or os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()


# --- parse ---------------------------------------------------------------


def emit_assignments(values, ok):
    """항상 HOOK_PARSE_OK 를 먼저 낸다.

    호출부는 `eval "$(... parse)"` 로 받는다. 실패해도 대입문 자체는 나와야
    호출부가 `[ "$HOOK_PARSE_OK" = 1 ]` 로 분기할 수 있다. 여기서 아무것도
    출력하지 않으면 이전 세션의 변수가 남아 오판한다.
    """
    print(f"HOOK_PARSE_OK={1 if ok else 0}")
    for key in EMPTY:
        print(f"{key}={shlex.quote(str(values.get(key) or ''))}")


def cmd_parse():
    raw = sys.stdin.read()
    if not raw.strip():
        # 페이로드가 비어 있는 것은 고장이 아니다 (수동 실행 등). 조용히 빈 값.
        emit_assignments(EMPTY, ok=True)
        return 0

    try:
        event = json.loads(raw)
        if not isinstance(event, dict):
            raise ValueError("최상위가 object 가 아님")
    except Exception as exc:  # noqa: BLE001 - 어떤 파싱 실패든 동일하게 표면화
        print(
            f"[harness] 훅 페이로드 파싱 실패: {exc}\n"
            f"[harness] 이 훅의 판정은 무효입니다 — 차단을 믿지 마세요.",
            file=sys.stderr,
        )
        emit_assignments(EMPTY, ok=False)
        return 1

    tool_input = event.get("tool_input")
    if not isinstance(tool_input, dict):
        tool_input = {}

    emit_assignments(
        {
            "HOOK_EVENT": event.get("hook_event_name", ""),
            "HOOK_TOOL": event.get("tool_name", ""),
            "HOOK_COMMAND": tool_input.get("command", ""),
            "HOOK_FILE_PATH": tool_input.get("file_path", ""),
            "HOOK_SESSION": event.get("session_id", ""),
            "HOOK_CWD": event.get("cwd", ""),
        },
        ok=True,
    )
    return 0


# --- event ---------------------------------------------------------------


def event_path(root, now):
    """월별 파일로 나눈다 — 한 파일이 무한히 자라면 아무도 열지 않는다."""
    return os.path.join(root, ".claude", "local", f"events-{now:%Y-%m}.jsonl")


def record_event(event, source, repo="", **fields):
    """이벤트 한 줄을 append 한다. 실패해도 절대 예외를 올리지 않는다.

    gate-runner.py 처럼 같은 디렉터리의 다른 도구가 importlib 로 불러 쓴다.
    기록 구현이 두 벌이 되면 포맷이 갈라지므로 진입점은 여기 하나다.
    """
    now = datetime.now(timezone.utc)
    record = {
        "ts": now.isoformat(timespec="seconds"),
        "event": event,
        "source": source,
    }
    for key, value in fields.items():
        if value in (None, ""):
            continue
        record[key] = value[:DETAIL_LIMIT] if isinstance(value, str) else value

    path = event_path(repo_root(repo), now)
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "a", encoding="utf-8") as handle:
            handle.write(json.dumps(record, ensure_ascii=False) + "\n")
    except OSError:
        # 계측 실패가 게이트를 막아서는 안 된다. 훅 쪽에서도 || true 로 감싼다.
        pass


def cmd_event(args):
    record_event(
        args.event,
        args.source,
        repo=args.repo,
        tool=args.tool,
        session=args.session,
        detail=args.detail,
    )
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("parse", help="stdin 훅 JSON → 셸 대입문")

    ev = sub.add_parser("event", help="발화 기록을 events-YYYY-MM.jsonl 에 append")
    ev.add_argument("--event", required=True)
    ev.add_argument("--source", required=True)
    ev.add_argument("--tool", default="")
    ev.add_argument("--session", default="")
    ev.add_argument("--detail", default="")
    ev.add_argument("--repo", default="")

    args = parser.parse_args(argv)
    if args.cmd == "parse":
        return cmd_parse()
    return cmd_event(args)


if __name__ == "__main__":
    sys.exit(main())
