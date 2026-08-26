"""공용 테스트 헬퍼 — 픽스처 레포를 만들고 `init.sh` 를 실제로 실행한다.

왜 모킹하지 않나
----------------
이 하네스가 없애려는 실패는 "설치했다고 보고했지만 실제로는 안 깔린" 종류다.
`pre-bash-guard.sh` 가 존재하지 않는 `$TOOL_INPUT` 을 읽어 한 번도 발화하지 않았고,
`templates/js/.github/workflows/post-merge-docs.yml` 은 배선이 없어 한 번도 설치된 적이
없었다. 둘 다 설치는 성공으로 보고됐다.

설치를 흉내 내는 테스트는 그 실패를 그대로 통과시킨다. 그래서 여기서는 진짜 임시
레포를 만들고 진짜 `init.sh` 를 돌린 뒤 디스크에 남은 결과만 본다.

선택 의존성 처리
----------------
`pre-commit`, `ruff`, `pytest`, `claude`, `codegraph` 는 있을 수도 없을 수도 있다.
있는 기계에서만 통과하는 테스트는 CI 에서 깨지고, 없는 기계에서만 통과하는 테스트는
로컬에서 깨진다. 그래서 단언은 **어느 쪽이든 참인 것**에만 건다. 선택 의존성이 없는
경로를 확인해야 할 때는 `strip_path=` 로 PATH 를 명시적으로 좁힌다.
"""

import os
import re
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INIT = ROOT / "init.sh"

# 스택별 감지 마커. scripts/migration.sh 의 detect_stack() 과 짝이다.
STACK_MARKERS = {
    "django": {"manage.py": "import os\n"},
    "nextjs": {"package.json": '{"name":"fx","dependencies":{"next":"14.0.0"}}\n'},
    "node": {"package.json": '{"name":"fx","version":"1.0.0"}\n'},
    "unknown": {},
}



def strip_comments(text):
    """`#` 주석을 걷어낸다.

    이 레포의 훅과 워크플로는 과거 버그를 주석에 그대로 남긴다("이전 버전은
    $TOOL_INPUT 을 읽었다"). 그래서 "이 문자열이 없어야 한다" 류 단언은 주석을
    걷지 않으면 설명문을 위반으로 잡는다. 실제로 두 번 그랬다.
    """
    return re.sub(r"(?m)^\s*#.*$", "", text)

def git(cwd, *arguments):
    return subprocess.run(
        ["git", "-C", str(cwd), *arguments],
        capture_output=True,
        text=True,
        check=False,
    )


def make_fixture(directory, stack="django", commit=False):
    """스택 마커를 갖춘 빈 git 레포를 만든다."""
    path = Path(directory)
    path.mkdir(parents=True, exist_ok=True)
    git(path, "init", "-q", ".")
    git(path, "config", "user.email", "fixture@example.invalid")
    git(path, "config", "user.name", "fixture")
    for name, body in STACK_MARKERS[stack].items():
        (path / name).write_text(body, encoding="utf-8")
    if commit:
        git(path, "add", "-A")
        git(path, "commit", "-qm", "fixture")
    return path


def run_init(path, env_type="auto", strip_path=False, extra_env=None):
    """픽스처에서 init.sh 를 실행한다. 비대화형이므로 프롬프트는 뜨지 않는다."""
    env = dict(os.environ)
    env["ENV_TYPE"] = env_type
    env["USE_ATLASSIAN_MCP"] = "no"
    if strip_path:
        # 선택 의존성이 하나도 없는 기계를 흉내 낸다.
        #
        # 표준 시스템 경로만 남긴다. homebrew·pipx·asdf 처럼 사용자가 도구를 까는
        # 경로가 빠지므로 pre-commit·ruff·claude·codegraph 는 사라지고 coreutils·
        # git·python3 는 남는다. 필수 도구까지 날리면 "선택 의존성 부재"가 아니라
        # 그냥 깨진 환경을 시험하게 된다 (dirname 을 날려 실제로 그랬다).
        system = [
            path
            for path in ("/usr/bin", "/bin", "/usr/sbin", "/sbin")
            if Path(path).is_dir()
        ]
        env["PATH"] = os.pathsep.join(system)
    if extra_env:
        env.update(extra_env)
    return subprocess.run(
        ["bash", str(INIT)],
        cwd=str(path),
        env=env,
        capture_output=True,
        text=True,
        check=False,
        stdin=subprocess.DEVNULL,
    )


def tree_snapshot(path):
    """설치 결과를 {상대경로: 바이트} 로 뜬다. 멱등성 비교에 쓴다.

    기준은 **커밋되는 파일**이다. `.gitignore` 목록을 하드코딩하지 않고 git 에게
    직접 묻는다. 설치는 훅 발화 기록(`.claude/local/`), 바이트코드 캐시, ruff·
    codegraph 캐시 같은 런타임 산출물도 만드는데, 그건 재실행마다 달라지는 게
    정상이라 멱등성 위반이 아니다. 반대로 커밋되는 파일이 재실행으로 바뀌면
    그건 남의 레포에 전파되는 변화라 반드시 잡아야 한다.

    무시 목록을 손으로 적으면 새 캐시 디렉터리가 생길 때마다 테스트가 깨지고,
    그때 사람이 목록에 추가하면서 진짜 회귀까지 함께 묻힌다.
    """
    root = Path(path)
    ignored = set()
    listing = git(root, "ls-files", "--others", "--ignored", "--exclude-standard")
    if listing.returncode == 0:
        ignored = {line for line in listing.stdout.splitlines() if line}

    snapshot = {}
    for item in sorted(root.rglob("*")):
        if not item.is_file() or item.is_symlink():
            continue
        relative = item.relative_to(root).as_posix()
        if relative.split("/")[0] == ".git" or relative in ignored:
            continue
        snapshot[relative] = item.read_bytes()
    return snapshot


class HarnessTestCase(unittest.TestCase):
    """픽스처 한 개를 만들고 설치까지 끝낸 상태로 시작하는 테스트."""

    stack = "django"
    env_type = "auto"

    @classmethod
    def setUpClass(cls):
        import tempfile

        cls._tmp = tempfile.TemporaryDirectory()
        cls.path = make_fixture(Path(cls._tmp.name) / "fixture", cls.stack)
        cls.result = run_init(cls.path, env_type=cls.env_type)

    @classmethod
    def tearDownClass(cls):
        cls._tmp.cleanup()

    def read(self, relative):
        return (self.path / relative).read_text(encoding="utf-8")

    def assertInstalled(self, relative):
        target = self.path / relative
        self.assertTrue(target.is_file(), f"설치되지 않음: {relative}")
        return target
