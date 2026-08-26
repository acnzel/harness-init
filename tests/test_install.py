"""설치 결과 회귀 테스트 — 스택별로 무엇이 실제 디스크에 도착하는가.

여기 있는 단언은 전부 과거에 실제로 깨졌던 것이다. 새 검사를 추가할 때는
"이게 깨졌을 때 무슨 일이 일어났는가"를 함께 적을 것. 근거 없는 단언은 다음 사람이
지운다.
"""

import json
import unittest
from pathlib import Path

from support import HarnessTestCase, ROOT, make_fixture, run_init, strip_comments


class DjangoInstallTests(HarnessTestCase):
    stack = "django"
    env_type = "python"

    def test_install_succeeds(self):
        self.assertEqual(self.result.returncode, 0, self.result.stderr[-2000:])

    def test_harness_owned_tools_arrive(self):
        # 복사가 실패해도 설치는 성공으로 보고되던 구간이다. 도착 여부를 직접 본다.
        for name in (
            "domain-extract.py",
            "domain-gate.py",
            "domain-freshness.py",
            "hook-io.py",
            "gate-runner.py",
            "render-agents.py",
            "pr-body.py",
            "commit-msg.py",
        ):
            self.assertInstalled(f".claude/scripts/{name}")

    def test_owned_hooks_arrive_and_are_executable(self):
        for name in (
            "_hook-input.sh",
            "gate-selftest.sh",
            "pre-bash-guard.sh",
            "post-bash-notice.sh",
            "domain-guard.sh",
            "session-knowledge.sh",
        ):
            hook = self.assertInstalled(f".claude/hooks/{name}")
            self.assertTrue(hook.stat().st_mode & 0o111, f"실행 권한 없음: {name}")

    def test_hooks_read_stdin_not_environment(self):
        # pre-bash-guard.sh 가 존재하지 않는 $TOOL_INPUT 을 읽어 한 번도 발화하지
        # 않았다 (2026-08-03 실측). 파싱은 _hook-input.sh 한 곳에만 있어야 한다.
        guard = strip_comments(self.read(".claude/hooks/pre-bash-guard.sh"))
        self.assertNotIn("TOOL_INPUT", guard)
        self.assertIn("hook_input_load", guard)

    def test_settings_registers_gate_selftest_first(self):
        # 게이트가 죽었다면 다른 무엇보다 먼저 알아야 하므로 SessionStart 최상단이다.
        settings = json.loads(self.read(".claude/settings.json"))
        first = settings["hooks"]["SessionStart"][0]["hooks"][0]["command"]
        self.assertIn("gate-selftest.sh", first)

    def test_agents_md_installed_with_marker(self):
        agents = self.read("AGENTS.md")
        self.assertIn("<!-- harness:auto:start -->", agents)
        self.assertIn("<!-- harness:auto:end -->", agents)

    def test_agents_md_auto_section_rendered_from_gates(self):
        # 렌더가 안 돌면 마커 사이가 비어 문서가 설정을 반영하지 못한다.
        agents = self.read("AGENTS.md")
        start = agents.index("<!-- harness:auto:start -->")
        end = agents.index("<!-- harness:auto:end -->")
        self.assertTrue(
            agents[start:end].strip().count("\n") > 0, "자동 구간이 비어 있다"
        )

    def test_pyproject_is_present_for_python(self):
        self.assertInstalled("pyproject.toml")


class JsInstallTests(HarnessTestCase):
    stack = "nextjs"
    env_type = "js"

    def test_install_succeeds(self):
        self.assertEqual(self.result.returncode, 0, self.result.stderr[-2000:])

    def test_js_gates_replace_django_gates(self):
        gates = json.loads(self.read(".claude/gates.json"))
        names = [gate["name"] for gate in gates["gates"]]
        self.assertIn("lint (eslint)", names)
        self.assertNotIn("lint (ruff)", names)

    def test_js_workflows_replace_django_versions(self):
        # templates/js/.github/workflows/post-merge-docs.yml 은 init.sh 에 복사
        # 배선이 없어 한 번도 설치된 적이 없었다. JS 레포에 views.py 를 찾는
        # django 판이 깔려 문서 갱신 이슈가 생길 수 없었다.
        post_merge = self.read(".github/workflows/post-merge-docs.yml")
        self.assertIn("controller", post_merge)
        self.assertNotIn("views.py", post_merge)

    def test_python_only_files_removed(self):
        self.assertFalse((self.path / "pyproject.toml").exists())

    def test_js_pre_bash_guard_has_no_django_migrate_warning(self):
        self.assertNotIn("makemigrations", self.read(".claude/hooks/pre-bash-guard.sh"))


class UnknownStackInstallTests(HarnessTestCase):
    stack = "unknown"
    env_type = "auto"

    def test_install_succeeds(self):
        self.assertEqual(self.result.returncode, 0, self.result.stderr[-2000:])

    def test_only_minimal_harness_lands(self):
        for name in ("CLAUDE.md", ".claude/settings.json", ".gitignore"):
            self.assertInstalled(name)
        for name in ("notification.sh", "insight-collector.sh"):
            self.assertInstalled(f".claude/hooks/{name}")

    def test_full_harness_is_skipped(self):
        # SKIP_FULL_INSTALL 가드가 풀리면 스택을 모르는 레포에 Django 하네스가 깔린다.
        for name in ("AGENTS.md", "pyproject.toml", ".claude/gates.json"):
            self.assertFalse(
                (self.path / name).exists(), f"미감지 경로에서 깔리면 안 됨: {name}"
            )


class OptionalDependencyTests(unittest.TestCase):
    """선택 의존성이 하나도 없는 기계에서도 설치가 끝나야 한다."""

    def test_install_completes_without_optional_tools(self):
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            path = make_fixture(Path(tmp) / "fx", "django")
            result = run_init(path, env_type="python", strip_path=True)
            self.assertEqual(result.returncode, 0, result.stderr[-2000:])
            # 필수 산출물은 선택 의존성과 무관하게 도착해야 한다.
            self.assertTrue((path / ".claude/gates.json").is_file())
            self.assertTrue((path / ".claude/scripts/gate-runner.py").is_file())


class WorkflowContractTests(unittest.TestCase):
    """템플릿 워크플로가 지켜야 할 계약. 대상 레포의 기본 브랜치를 알 수 없다."""

    workflows = sorted(ROOT.glob("templates/*/.github/workflows/*.yml"))

    def test_fixtures_exist(self):
        self.assertTrue(self.workflows, "워크플로 템플릿을 하나도 못 찾았다")

    def test_no_hardcoded_branch_filter(self):
        # `branches: [dev]` 하드코딩 때문에 PR 워크플로가 통째로 안 돌던 전례가 있다.
        for workflow in self.workflows:
            stripped = strip_comments(workflow.read_text(encoding="utf-8"))
            self.assertNotRegex(
                stripped,
                r"(?m)^\s*branches:",
                f"{workflow.relative_to(ROOT)} 가 브랜치를 고정하고 있다",
            )

    def test_pull_request_target_is_never_used(self):
        # fork PR 에서 시크릿이 노출된다. 주석에서 "쓰지 않는다"고 설명하는 것은
        # 위반이 아니므로 판정 전에 주석을 걷어낸다.
        for workflow in self.workflows:
            body = strip_comments(workflow.read_text(encoding='utf-8'))
            self.assertNotIn("pull_request_target", body, workflow.name)


class SelfCiTests(unittest.TestCase):
    """이 도구는 남에게 CI 를 심어주면서 자기 자신은 CI 가 없었다.

    없어진 걸 사람이 알아채는 유일한 경로가 "누가 우연히 보는 것"이면 안 된다.
    워크플로 파일과 그 안의 테스트 실행 단계를 함께 고정한다.
    """

    workflow = ROOT / ".github/workflows/test.yml"

    def test_workflow_exists(self):
        self.assertTrue(self.workflow.is_file(), "자체 CI 워크플로가 없다")

    def test_workflow_runs_the_regression_suite(self):
        body = self.workflow.read_text(encoding="utf-8")
        self.assertIn("unittest discover", body, "CI 가 회귀 스위트를 돌리지 않는다")
        self.assertIn("-s tests", body)

    def test_workflow_checks_shell_syntax(self):
        self.assertIn("bash -n", self.workflow.read_text(encoding="utf-8"))

    def test_workflow_installs_no_optional_dependency(self):
        """CI 에 pre-commit·ruff 를 깔면 '깨끗한 기계에서 도는가'를 못 보게 된다.

        OptionalDependencyTests 가 그 경로를 고정하고 있는데, 러너에 도구를 미리
        깔아 두면 그 테스트가 실제로는 아무것도 확인하지 않게 된다.
        """
        body = strip_comments(self.workflow.read_text(encoding="utf-8"))
        for tool in ("pip install pre-commit", "pipx install", "install ruff"):
            self.assertNotIn(tool, body, f"CI 가 선택 의존성을 설치한다: {tool}")


if __name__ == "__main__":
    unittest.main()
