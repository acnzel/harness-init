"""새 클론의 로컬 게이트 부트스트랩.

`.pre-commit-config.yaml` 과 `.claude/` 는 커밋되지만 `.git/hooks/` 는 전파되지
않는다. 그래서 레포를 새로 clone 한 사람은 설정을 전부 받고도 **로컬 게이트 없이
커밋한다**. 본인은 하네스가 지켜주는 줄 안다.

새 클론에 훅을 강제할 방법은 없다. pre-commit 도 husky 도 설치 단계를 요구한다.
그래서 강제 대신 크게 알리고, 놓친 것은 CI 의 gate-runner 가 PR 에서 받는다.

여기서는 그 알림이 실제로 발화하는지를 positive/negative 쌍으로 고정한다. 한쪽만
검사하면 항상 발화하는 훅도 정상으로 통과한다.
"""

import subprocess
import tempfile
import unittest
from pathlib import Path

from support import ROOT, git, make_fixture, run_init

SELFTEST = ".claude/hooks/gate-selftest.sh"


def selftest(path):
    return subprocess.run(
        ["bash", SELFTEST],
        cwd=str(path),
        capture_output=True,
        text=True,
        check=False,
    ).stdout


class BootstrapGateTests(unittest.TestCase):
    """설치한 레포와 그것을 clone 한 레포에서 판정이 갈려야 한다."""

    @classmethod
    def setUpClass(cls):
        cls._tmp = tempfile.TemporaryDirectory()
        root = Path(cls._tmp.name)

        cls.origin = make_fixture(root / "origin", "django")
        result = run_init(cls.origin, env_type="python")
        assert result.returncode == 0, result.stderr[-2000:]
        git(cls.origin, "add", "-A")
        # 포맷 훅이 파일을 고쳐 커밋이 한 번 실패하는 것은 여기서 시험 대상이 아니다.
        git(cls.origin, "commit", "-qm", "harness", "--no-verify")

        cls.clone = root / "clone"
        subprocess.run(
            ["git", "clone", "-q", str(cls.origin), str(cls.clone)],
            check=True,
            capture_output=True,
        )

    @classmethod
    def tearDownClass(cls):
        cls._tmp.cleanup()

    def test_origin_has_the_config_committed(self):
        tracked = git(self.origin, "ls-files").stdout.splitlines()
        self.assertIn(".pre-commit-config.yaml", tracked)
        self.assertIn(".claude/gates.json", tracked)

    def test_clone_receives_config_but_not_hooks(self):
        # 이 비대칭이 문제의 원인이다. 사라지면 이 게이트도 필요 없어진다.
        self.assertTrue((self.clone / ".pre-commit-config.yaml").is_file())
        self.assertTrue((self.clone / ".claude/gates.json").is_file())
        self.assertFalse(
            (self.clone / ".git/hooks/pre-commit").is_file(),
            "clone 이 훅을 받았다면 이 게이트의 전제가 바뀐 것이다",
        )

    def test_negative_installed_repo_does_not_fire(self):
        output = selftest(self.origin)
        self.assertNotIn("로컬 훅 미설치", output, "설치한 레포에서 오발화했다")

    def test_positive_fresh_clone_fires(self):
        output = selftest(self.clone)
        self.assertIn("로컬 훅 미설치", output, "새 클론에서 발화하지 않았다")

    def test_message_carries_the_exact_recovery_command(self):
        # 경고만 하고 복구 방법을 안 주면 사람들은 경고를 끈다.
        output = selftest(self.clone)
        self.assertIn("pre-commit install", output)

    def test_selftest_never_blocks_the_session(self):
        # SessionStart 를 막으면 하네스를 통째로 꺼버린다.
        for path in (self.origin, self.clone):
            result = subprocess.run(
                ["bash", SELFTEST],
                cwd=str(path),
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0)


class CiSafetyNetTests(unittest.TestCase):
    """로컬에서 놓친 것을 CI 가 받는다는 전제가 실제로 배선돼 있는가."""

    def test_pr_workflow_runs_the_same_runner(self):
        for template in ("django", "js"):
            workflow = ROOT / f"templates/{template}/.github/workflows/pr-test.yml"
            self.assertIn(
                "gate-runner.py", workflow.read_text(encoding="utf-8"), template
            )

    def test_ci_stage_is_declared_in_gates(self):
        import json

        for template in ("django", "js"):
            gates = json.loads(
                (ROOT / f"templates/{template}/.claude/gates.json").read_text(
                    encoding="utf-8"
                )
            )
            stages = {stage for gate in gates["gates"] for stage in gate["stages"]}
            self.assertIn("ci", stages, template)


if __name__ == "__main__":
    unittest.main()
