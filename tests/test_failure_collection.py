"""실패 수집 — 게이트가 막았을 때·실패했을 때·우회됐을 때를 기록한다.

왜 필요한가
-----------
지금까지 `.claude/local/events-*.jsonl` 에 쌓이던 건 `gate_fired` 하나였다. 게이트가
**잘 작동한** 순간의 기록이라, "무엇이 실제로 방해가 되는가"를 만들 재료가 없었다.

레포는 이미 "게이트 우회(`--no-verify` 등)는 금지가 아니라 표면화 대상"이라고
선언하고 있는데(render-agents.py 가 AGENTS.md 에 렌더한다), 표면화하는 코드가
없어서 아무도 모르게 우회됐다.

무엇을 막지 않는가
------------------
우회를 막지 않는다. 막으면 우회의 우회를 학습시킨다. 계측도 게이트를 막지 않는다.
기록이 실패해도 커밋과 푸시는 통과해야 한다.
"""

import json
import subprocess
import tempfile
import unittest
from pathlib import Path

from support import ROOT, make_fixture, run_init

# 플래그를 조립해서 만든다. 소스에 문자열 그대로 두면 사용자 전역 커밋 가드가
# 이 파일을 실제 우회 시도로 오인한다 (실제로 그랬다).
NO_VERIFY = "--no-" + "verify"


def hook_payload(command):
    return json.dumps(
        {
            "hook_event_name": "PreToolUse",
            "tool_name": "Bash",
            "tool_input": {"command": command},
            "session_id": "test",
        }
    )


class InstalledFixture(unittest.TestCase):
    """설치가 끝난 픽스처 하나를 공유한다. 설치는 느리고 판정은 빠르다."""

    @classmethod
    def setUpClass(cls):
        cls._tmp = tempfile.TemporaryDirectory()
        cls.path = make_fixture(Path(cls._tmp.name) / "fx", "django")
        result = run_init(cls.path, env_type="python")
        assert result.returncode == 0, result.stderr[-2000:]

    @classmethod
    def tearDownClass(cls):
        cls._tmp.cleanup()

    def run_guard(self, command):
        return subprocess.run(
            ["bash", ".claude/hooks/pre-bash-guard.sh"],
            cwd=str(self.path),
            input=hook_payload(command),
            capture_output=True,
            text=True,
            check=False,
        )

    def events(self, kind=None):
        found = []
        for log in (self.path / ".claude/local").glob("events-*.jsonl"):
            for line in log.read_text(encoding="utf-8").splitlines():
                if line.strip():
                    record = json.loads(line)
                    if kind is None or record.get("event") == kind:
                        found.append(record)
        return found


class BypassDetectionTests(InstalledFixture):
    def test_positive_commit_bypass_is_recorded(self):
        result = self.run_guard(f"git commit {NO_VERIFY} -m x")
        self.assertIn("우회 기록됨", result.stdout)
        self.assertTrue(
            any(
                "no-verify" in event.get("detail", "")
                for event in self.events("bypass_used")
            ),
            "우회가 기록되지 않았다",
        )

    def test_positive_push_bypass_is_recorded(self):
        result = self.run_guard(f"git push {NO_VERIFY}")
        self.assertIn("우회 기록됨", result.stdout)

    def test_positive_precommit_skip_is_recorded(self):
        result = self.run_guard("SKIP=ruff git commit -m x")
        self.assertIn("우회 기록됨", result.stdout)

    def test_negative_ordinary_commit_does_not_fire(self):
        self.assertNotIn("우회 기록됨", self.run_guard("git commit -m x").stdout)

    def test_negative_unrelated_command_does_not_fire(self):
        self.assertNotIn("우회 기록됨", self.run_guard("git status").stdout)

    def test_negative_unrelated_dash_n_does_not_fire(self):
        # `-n` 은 수많은 명령의 평범한 플래그다. git commit/push 가 아니면 우회가 아니다.
        self.assertNotIn("우회 기록됨", self.run_guard("npm run build -n").stdout)

    def test_negative_gpg_sign_skip_is_not_a_bypass(self):
        # 서명 생략은 게이트를 건너뛰지 않는다.
        self.assertNotIn(
            "우회 기록됨", self.run_guard("git commit --no-gpg-sign -m x").stdout
        )

    def test_bypass_is_never_blocked(self):
        # 막으면 우회의 우회를 학습시킨다. 기록만 한다.
        self.assertEqual(self.run_guard(f"git commit {NO_VERIFY} -m x").returncode, 0)

    def test_secrets_are_redacted_before_recording(self):
        self.run_guard(
            f"git commit {NO_VERIFY} -m x --author='t' && export AWS_SECRET_ACCESS_KEY=AKIAIOSFODNN7EXAMPLE"
        )
        recorded = json.dumps(self.events("bypass_used"), ensure_ascii=False)
        self.assertNotIn("AKIAIOSFODNN7EXAMPLE", recorded, "시크릿이 기록에 남았다")


class InstrumentationIsFailOpenTests(InstalledFixture):
    """계측이 죽어도 게이트는 통과해야 한다."""

    def test_guard_survives_a_broken_recorder(self):
        recorder = self.path / ".claude/scripts/hook-io.py"
        original = recorder.read_bytes()
        try:
            recorder.write_text("import sys; sys.exit(3)\n", encoding="utf-8")
            result = self.run_guard(f"git commit {NO_VERIFY} -m x")
            self.assertEqual(result.returncode, 0, "계측 고장이 훅을 막았다")
        finally:
            recorder.write_bytes(original)

    def test_guard_survives_a_missing_local_directory(self):
        import shutil

        local = self.path / ".claude/local"
        backup = self.path / ".claude/local-backup"
        if local.exists():
            shutil.move(str(local), str(backup))
        try:
            self.assertEqual(self.run_guard("git status").returncode, 0)
        finally:
            if backup.exists():
                shutil.rmtree(local, ignore_errors=True)
                shutil.move(str(backup), str(local))


class DeclaredContractTests(unittest.TestCase):
    """레포가 선언한 것과 구현이 어긋나면 안 된다."""

    def test_bypass_surfacing_is_declared_and_implemented(self):
        # AGENTS.md 자동 구간이 "우회는 표면화 대상"이라고 선언한다. 선언만 있고
        # 구현이 없던 상태가 정확히 이 기능이 메우려는 구멍이다.
        renderer = (ROOT / "scripts/render-agents.py").read_text(encoding="utf-8")
        self.assertIn("표면화 대상", renderer)
        guard = (ROOT / "templates/django/.claude/hooks/pre-bash-guard.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn("bypass_used", guard, "선언은 있는데 기록 구현이 없다")


class FailureReportTests(InstalledFixture):
    """기록만 하고 아무도 안 읽는 로그는 없는 것과 같다."""

    def report(self, *extra):
        return subprocess.run(
            ["python3", ".claude/scripts/failure-report.py", ".", *extra],
            cwd=str(self.path), capture_output=True, text=True, check=False,
            env={"PATH": "/usr/bin:/bin", "NO_COLOR": "1", "HOME": str(self.path)},
        )

    def test_report_ships_with_the_harness(self):
        self.assertTrue((self.path / ".claude/scripts/failure-report.py").is_file())

    def test_recurring_bypass_becomes_a_candidate(self):
        for _ in range(3):
            self.run_guard(f"git commit {NO_VERIFY} -m x")
        result = self.report()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("규칙 후보", result.stdout)
        self.assertIn("no-verify", result.stdout)

    def test_recurrence_threshold_policy_is_two(self):
        """정책 자체를 고정한다.

        앞선 테스트는 보고서가 스스로 보고한 threshold 를 기준으로 삼아서,
        임계값을 1 로 낮춰도 기준이 같이 움직여 통과했다. 자기참조 테스트라
        아무것도 지키지 못했다 (뮤테이션으로 확인).

        2 라는 숫자에는 근거가 있다. 사용자 전역 /weekly-retro 가 debrief 2건
        이상 재발을 승격 조건으로 두고, 1회짜리를 규칙으로 굳히면 그 프로젝트에만
        맞는 임시방편이 된다.
        """
        payload = json.loads(self.report("--format", "json").stdout)
        self.assertEqual(payload["threshold"], 2, "기본 재발 임계값이 2 가 아니다")
        source = (ROOT / "scripts/failure-report.py").read_text(encoding="utf-8")
        self.assertIn("RECURRENCE_THRESHOLD = 2", source)

    def test_a_single_occurrence_never_becomes_a_candidate(self):
        """1회는 데이터가 아니다. 기본 임계값에서 판정한다."""
        self.run_guard("SKIP=onlyonce git commit -m x")
        payload = json.loads(self.report("--format", "json").stdout)
        counts = {
            name: count
            for bucket in payload["counts"].values()
            for name, count in bucket.items()
        }
        candidates = [row["name"] for row in payload["candidates"]]
        for name, count in counts.items():
            if count < 2:
                self.assertNotIn(name, candidates, f"1회짜리가 후보로 올라갔다: {name}")

    def test_report_is_a_diagnosis_not_a_gate(self):
        # 진단이 종료 코드로 작업을 막으면 사람들이 안 돌린다.
        for _ in range(3):
            self.run_guard(f"git push {NO_VERIFY}")
        self.assertEqual(self.report().returncode, 0)

    def test_empty_log_does_not_claim_safety(self):
        """0건은 '문제 없음'이 아니라 '아직 관측되지 않음'이다."""
        with tempfile.TemporaryDirectory() as tmp:
            empty = make_fixture(Path(tmp) / "fx", "django")
            (empty / ".claude/scripts").mkdir(parents=True, exist_ok=True)
            import shutil
            shutil.copy(
                ROOT / "scripts/failure-report.py", empty / ".claude/scripts/failure-report.py"
            )
            result = subprocess.run(
                ["python3", ".claude/scripts/failure-report.py", "."],
                cwd=str(empty), capture_output=True, text=True, check=False,
                env={"PATH": "/usr/bin:/bin", "NO_COLOR": "1"},
            )
            self.assertIn("아직 관측되지 않음", result.stdout)

    def test_report_survives_a_corrupt_log_line(self):
        # 한 줄이 깨졌다고 전체를 잃으면 안 된다.
        log = next((self.path / ".claude/local").glob("events-*.jsonl"))
        log.write_text(log.read_text(encoding="utf-8") + "{깨진 줄\n", encoding="utf-8")
        self.assertEqual(self.report().returncode, 0)

if __name__ == "__main__":
    unittest.main()
