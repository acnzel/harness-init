#!/usr/bin/env python3
"""커밋 메시지에 브랜치의 티켓 번호를 붙인다.

왜
--
브랜치명에는 티켓이 있는데 커밋 메시지에는 없는 경우가 많다. 나중에 "이 줄이 왜
이렇게 됐나"를 되짚을 때 커밋에서 티켓으로 못 가면 맥락이 끊긴다. 브랜치는 머지 후
사라지므로, 티켓은 커밋에 남아야 한다.

설정 없이 동작한다. 브랜치명에서 `ABC-123` 꼴을 찾을 뿐이라 Jira·Linear·GitHub
어느 쪽이든 같은 형태면 잡힌다. 프로젝트 키를 물어보지 않는 이유는, 물어보면
설정 파일이 하나 늘고 그 파일이 낡기 때문이다.

무엇을 하지 않는가
------------------
- 티켓이 없어도 **막지 않는다**. hotfix·문서 수정처럼 티켓 없는 커밋은 정상이다.
  차단하면 우회(`--no-verify`)를 학습시키고, 그러면 다른 게이트까지 같이 꺼진다.
- 이미 티켓이 적혀 있으면 건드리지 않는다.
- merge/revert/squash/fixup 커밋은 건드리지 않는다. 형식이 의미를 갖는 메시지다.

사용법 (pre-commit 의 commit-msg 스테이지에서 호출)
  python3 commit-msg.py <메시지 파일 경로>
"""

import os
import re
import subprocess
import sys

# feature/ABC-123-설명, ABC-123, bugfix_ABC-123 등에서 잡는다.
TICKET_RE = re.compile(r"\b([A-Z][A-Z0-9]{1,9}-\d+)\b", re.IGNORECASE)
# 이미 제목에 티켓이 있는가 (대괄호 유무 무관)
SUBJECT_TICKET_RE = re.compile(r"\[?[A-Z][A-Z0-9]{1,9}-\d+\]?", re.IGNORECASE)
SKIP_PREFIXES = ("merge ", "revert ", "fixup!", "squash!", "amend!")


def current_branch():
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True,
            text=True,
            check=True,
        )
        return out.stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return ""


def rebase_in_progress():
    """rebase·merge 중에는 메시지를 고치지 않는다. 이력이 꼬인다."""
    try:
        git_dir = subprocess.run(
            ["git", "rev-parse", "--git-dir"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return False
    return any(
        os.path.exists(os.path.join(git_dir, name))
        for name in ("rebase-merge", "rebase-apply", "MERGE_HEAD", "CHERRY_PICK_HEAD")
    )


def transform(message, ticket):
    lines = message.split("\n")
    if not lines:
        return message
    subject = lines[0]

    if not subject.strip():
        return message
    if subject.lower().startswith(SKIP_PREFIXES):
        return message
    if SUBJECT_TICKET_RE.search(subject):
        return message

    # conventional prefix 가 있으면 그 뒤에 넣는다: "feat: [ABC-123] 제목"
    match = re.match(r"^([a-z]+(?:\([^)]*\))?!?:\s*)(.*)$", subject)
    if match:
        lines[0] = f"{match.group(1)}[{ticket}] {match.group(2)}"
    else:
        lines[0] = f"[{ticket}] {subject}"
    return "\n".join(lines)


def main(argv=None):
    argv = argv if argv is not None else sys.argv[1:]
    if not argv:
        return 0
    path = argv[0]

    if rebase_in_progress():
        return 0

    found = TICKET_RE.search(current_branch())
    if not found:
        # 티켓 없는 브랜치는 정상이다. 조용히 통과.
        return 0
    ticket = found.group(1).upper()

    try:
        message = open(path, encoding="utf-8").read()
    except OSError:
        return 0

    updated = transform(message, ticket)
    if updated != message:
        try:
            open(path, "w", encoding="utf-8").write(updated)
        except OSError:
            return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
