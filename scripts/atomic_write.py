"""원자적 파일 쓰기 — 중단돼도 반쪽짜리 파일을 남기지 않는다.

왜 이 파일이 있나
-----------------
하네스 소유 스크립트 셋이 전부 `open(path, "w").write(...)` 을 쓰고 있었다. 이건
**먼저 잘라내고 그다음에 쓴다**. 그 사이에 프로세스가 죽거나 디스크가 차면 원본은
이미 사라졌고 새 내용은 안 들어간 상태로 끝난다.

셋 다 사람이 쓴 파일을 덮어쓴다.

    render-agents.py   AGENTS.md      팀이 절대 규칙을 채워 넣는 문서
    commit-msg.py      COMMIT_EDITMSG 방금 사람이 작성한 커밋 메시지
    lint-baseline.py   pyproject.toml 프로젝트 설정 전체

이 레포의 CLAUDE.md 는 "마커를 다루는 코드는 한 쌍이 아니면 덮어쓰지 않는다. 잘못
자르면 사람이 쓴 내용이 유실되고, 그건 되돌릴 수 없다"고 적어 놓고 있었다. 마커
판정은 지키면서 쓰기 자체는 안 지키고 있었다.

어떻게 동작하나
---------------
같은 디렉터리에 임시 파일을 만들고, 다 쓴 뒤 `os.replace` 로 갈아끼운다. 같은
파일시스템 안이므로 rename 은 원자적이다. 중단되면 원본이 그대로 남고 임시 파일만
버려진다.

같은 디렉터리를 쓰는 이유는 `/tmp` 가 다른 파일시스템일 수 있어서다. 그러면
`os.replace` 가 원자적 rename 이 아니라 복사가 되고, 원자성이 사라진다.
"""

import os
import stat
import tempfile
from pathlib import Path

__all__ = ["atomic_write_text"]


def atomic_write_text(path, text, encoding="utf-8"):
    """`path` 를 `text` 로 원자적으로 교체한다. 기존 권한을 유지한다.

    심볼릭 링크는 따라간다. 팀이 AGENTS.md 를 다른 곳으로 링크해 두었을 때
    링크를 실체 파일로 바꿔버리면 그쪽 구조가 조용히 깨지기 때문이다.
    """
    path = Path(path)
    target = Path(os.path.realpath(path)) if path.is_symlink() else path
    directory = target.parent
    directory.mkdir(parents=True, exist_ok=True)

    mode = stat.S_IMODE(target.stat().st_mode) if target.exists() else 0o644

    handle = tempfile.NamedTemporaryFile(
        "w", encoding=encoding, dir=directory, delete=False
    )
    try:
        with handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        temporary = Path(handle.name)
        os.chmod(temporary, mode)
        os.replace(temporary, target)
    except BaseException:
        Path(handle.name).unlink(missing_ok=True)
        raise
