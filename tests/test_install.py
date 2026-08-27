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

    def test_agents_md_empty_rules_section_points_agents_at_claude_md(self):
        # AGENTS.md 의 절대 규칙은 항상 빈 채로 깔린다(LLM 이 창작하면 안 되므로).
        # 기존 프로젝트는 그 규칙이 CLAUDE.md 쪽에 이미 있을 수 있는데, Codex·Cursor
        # 처럼 AGENTS.md 만 읽는 도구는 이 안내가 없으면 그 내용을 영영 못 본다.
        agents = self.read("AGENTS.md")
        self.assertIn(
            "CLAUDE.md", agents.split("## 절대 규칙")[1].split("## 권한과 경계")[0]
        )

    def test_agents_md_auto_section_rendered_from_gates(self):
        # 렌더가 안 돌면 마커 사이가 비어 문서가 설정을 반영하지 못한다.
        agents = self.read("AGENTS.md")
        start = agents.index("<!-- harness:auto:start -->")
        end = agents.index("<!-- harness:auto:end -->")
        self.assertTrue(
            agents[start:end].strip().count("\n") > 0, "자동 구간이 비어 있다"
        )

    def test_version_is_stamped(self):
        # 재실행으로 갱신되는 도구라, 대상 레포에서 어느 판이 깔렸는지 알아야
        # 버그를 고쳤을 때 그 레포가 따라왔는지 확인할 수 있다.
        stamped = self.read(".claude/harness-version").strip()
        self.assertEqual(
            stamped, (ROOT / "VERSION").read_text(encoding="utf-8").strip()
        )

    def test_pyproject_is_present_for_python(self):
        self.assertInstalled("pyproject.toml")

    def test_coderabbit_config_installed_and_gemini_removed(self):
        # Gemini Code Assist 는 개인 사용자 무료 제공이 끝나 CodeRabbit 으로 대체했다
        # (harness-init 1.2.0). 재발 방지: .gemini/ 가 다시 깔리면 안 된다.
        self.assertInstalled(".coderabbit.yaml")
        self.assertFalse((self.path / ".gemini").exists())
        self.assertInstalled(".claude/commands/workflows/coderabbit-review.md")


class JsInstallTests(HarnessTestCase):
    stack = "nextjs"
    env_type = "js"

    def test_install_succeeds(self):
        self.assertEqual(self.result.returncode, 0, self.result.stderr[-2000:])

    def test_agents_md_empty_rules_section_points_agents_at_claude_md(self):
        # AGENTS.md 는 JS 스택에서도 django 판을 그대로 재사용한다 — 오버라이드가
        # 안 걸린 채 이 안내문이 남아 있는지는 별도로 확인해야 한다.
        agents = self.read("AGENTS.md")
        self.assertIn(
            "CLAUDE.md", agents.split("## 절대 규칙")[1].split("## 권한과 경계")[0]
        )

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

    def test_coderabbit_config_is_js_flavored_and_gemini_removed(self):
        self.assertFalse((self.path / ".gemini").exists())
        coderabbit = self.read(".coderabbit.yaml")
        self.assertIn('path: "**/*.{ts,tsx}"', coderabbit)
        self.assertNotIn('path: "**/*.py"', coderabbit)

    def test_gitignore_has_both_shared_and_js_entries(self):
        # base-project/.gitignore.append 와 js/.gitignore.append 가 각각 통째로
        # 중복 관리되던 시절, js 판에만 `.codegraph/` 가 빠진 채로 낡아 있었다
        # (kimsuhanmu 레포에서 실측 — 100MB+ codegraph 인덱스가 커밋 대상이 될 뻔함).
        gitignore = self.read(".gitignore")
        self.assertIn(".codegraph/", gitignore)
        self.assertIn(".claude/scripts/__pycache__/", gitignore)
        self.assertIn("node_modules/", gitignore)


class NestjsInstallTests(HarnessTestCase):
    """STACK=nestjs 는 nextjs 전용 오버라이드의 영향을 받지 않아야 한다.

    templates/nextjs/ 를 추가하면서 STACK=nextjs 에만 걸리게 가드했다 — 이 클래스는
    그 가드가 실제로 nestjs/express/node 를 건드리지 않는지 확인한다. 걸렸다면
    NestJS 백엔드 프로젝트에 Controller 레이어가 없는 App Router 템플릿이 깔려
    같은 문제가 반대 방향으로 재발한 것이다.
    """

    stack = "nestjs"
    env_type = "js"

    def test_install_succeeds(self):
        self.assertEqual(self.result.returncode, 0, self.result.stderr[-2000:])

    def test_controller_service_repository_architecture_kept(self):
        architecture = self.read(".claude/rules/architecture.md")
        self.assertIn("Controllers → Services → Repositories", architecture)

    def test_agents_reference_controller_not_app_router(self):
        architect = self.read(".claude/agents/architect.md")
        self.assertIn("Controller", architect)
        self.assertNotIn("Route Handler", architect)


class NextjsAppRouterInstallTests(HarnessTestCase):
    """STACK=nextjs 는 Controller/Service/Repository 가 아니라 App Router 레이어로 채워져야 한다.

    kimsuhanmu 레포 실측: 백엔드 서버(NestJS) 가 없는 순수 Next.js App Router
    프로젝트에 Controller/Service/Repository 템플릿이 그대로 깔려, 존재하지 않는
    레이어(`*.controller.ts`)를 에이전트가 만들려는 문제가 있었다.
    """

    stack = "nextjs"
    env_type = "js"

    def test_install_succeeds(self):
        self.assertEqual(self.result.returncode, 0, self.result.stderr[-2000:])

    def test_architecture_rule_is_app_router_not_controller(self):
        architecture = self.read(".claude/rules/architecture.md")
        self.assertIn(
            "Page / Route Handler / Server Action → Service → Repository", architecture
        )
        self.assertNotIn("Controller → Service → Repository", architecture)
        self.assertNotIn("NestJS 예시", architecture)

    def test_agents_reference_app_router_not_controller(self):
        for name in ("analyst", "architect", "coder", "tester", "reviewer"):
            content = self.read(f".claude/agents/{name}.md")
            self.assertNotIn(
                ".controller.ts", content, f"{name}.md 에 controller 레이어 잔재"
            )
            self.assertNotIn("NestJS", content, f"{name}.md 에 NestJS 잔재")

    def test_doc_sync_policy_maps_route_ts_not_controller_ts(self):
        policy = self.read("docs/DOC-SYNC-POLICY.md")
        self.assertIn("route.ts", policy)
        self.assertNotIn(".controller.ts", policy)

    def test_coderabbit_critical_rules_is_app_router(self):
        coderabbit = self.read(".coderabbit.yaml")
        self.assertIn("Page/Route Handler/Server Action", coderabbit)


class JsClaudeMdPreservationTests(unittest.TestCase):
    """JS 오버라이드가 기존 프로젝트 CLAUDE.md 를 지우면 안 된다.

    harness-init 1.1.0 은 JS 스택에서 `cp -f templates/js/CLAUDE.md` 로 통째로
    덮어써, 이미 있던 프로젝트 고유 내용(서비스 정체성·절대 규칙·진행 상황)이
    {project_name} 같은 플레이스홀더투성이 템플릿으로 완전히 사라졌다
    (kimsuhanmu 레포에서 실측). 재발 방지 회귀 테스트.

    STACK=nextjs 픽스처를 쓰므로, JS 오버라이드 위에 다시 얹히는 Next.js
    App Router 오버라이드까지 마커 보존 로직을 함께 통과하는지도 검증한다.
    """

    @classmethod
    def setUpClass(cls):
        import tempfile

        cls._tmp = tempfile.TemporaryDirectory()
        cls.path = make_fixture(Path(cls._tmp.name) / "fixture", "nextjs")
        cls.marker_text = "이 서비스는 김수한무 — 사주 안 봄이 절대 규칙이다"
        (cls.path / "CLAUDE.md").write_text(
            f"# 기존 프로젝트 CLAUDE.md\n\n{cls.marker_text}\n", encoding="utf-8"
        )
        cls.result = run_init(cls.path, env_type="js")

    @classmethod
    def tearDownClass(cls):
        cls._tmp.cleanup()

    def read(self, relative):
        return (self.path / relative).read_text(encoding="utf-8")

    def test_install_succeeds(self):
        self.assertEqual(self.result.returncode, 0, self.result.stderr[-2000:])

    def test_existing_project_content_survives(self):
        self.assertIn(self.marker_text, self.read("CLAUDE.md"))

    def test_nextjs_harness_section_still_applied(self):
        # Next.js App Router 하네스 섹션이 여전히 붙어야 한다 — 사용자 내용을
        # 보존하려다 harness 섹션 자체가 안 붙는 회귀도 함께 잡는다. 아키텍처
        # 본문은 architecture.md 로 옮겨졌으므로(중복 제거) 참조 링크로 확인한다.
        content = self.read("CLAUDE.md")
        self.assertIn("레이어드 아키텍처 (App Router)", content)
        self.assertIn(".claude/rules/architecture.md", content)

    def test_reinstall_keeps_single_copy_of_user_content(self):
        run_init(self.path, env_type="js")
        content = self.read("CLAUDE.md")
        self.assertEqual(content.count(self.marker_text), 1)


class GeminiMigrationTests(unittest.TestCase):
    """1.2.0 이전 설치(Gemini Code Assist)를 재실행하면 잔재가 지워져야 한다.

    cp -rn/-n 은 새 파일만 추가하고 낡은 파일을 지우지 않는다. 정리 로직이 없으면
    `.gemini/` 와 `/workflows:gemini-review` 가 CodeRabbit 설정과 나란히 영원히
    남아, "재실행하면 자동으로 따라온다"는 이 하네스의 원칙이 깨진다.
    """

    @classmethod
    def setUpClass(cls):
        import tempfile

        cls._tmp = tempfile.TemporaryDirectory()
        cls.path = make_fixture(Path(cls._tmp.name) / "fixture", "nextjs")
        gemini_dir = cls.path / ".gemini"
        gemini_dir.mkdir()
        (gemini_dir / "styleguide.md").write_text(
            "이 문서는 Gemini Code Assist가 코드 리뷰 시 참조할 프로젝트 스타일 "
            "가이드입니다.\n\n> 이 파일은 Gemini Code Assist 전용 파생본이다.\n",
            encoding="utf-8",
        )
        cls.config_yaml_content = (
            "have_fun: false\n# 우리 팀이 comment_severity_threshold 를 손으로 낮췄다\n"
        )
        (gemini_dir / "config.yaml").write_text(
            cls.config_yaml_content, encoding="utf-8"
        )
        commands_dir = cls.path / ".claude" / "commands" / "workflows"
        commands_dir.mkdir(parents=True)
        (commands_dir / "gemini-review.md").write_text(
            "You are an agent that handles Gemini Code Assist reviews on GitHub PRs.\n",
            encoding="utf-8",
        )
        cls.result = run_init(cls.path, env_type="js")

    @classmethod
    def tearDownClass(cls):
        cls._tmp.cleanup()

    def test_install_succeeds(self):
        self.assertEqual(self.result.returncode, 0, self.result.stderr[-2000:])

    def test_gemini_styleguide_removed(self):
        self.assertFalse((self.path / ".gemini/styleguide.md").exists())

    def test_user_modified_config_yaml_preserved(self):
        # 지문은 styleguide.md 에만 있다. config.yaml 까지 같이 지우면(1.2.0 최초
        # 릴리스의 실제 버그 — CodeRabbit PR #30 리뷰로 발견) 사용자가 손으로 고친
        # 값(comment_severity_threshold 등)이 백업 없이 사라진다.
        config = self.path / ".gemini/config.yaml"
        self.assertTrue(config.exists(), "지문 없는 config.yaml 이 함께 삭제됐다")
        self.assertEqual(config.read_text(encoding="utf-8"), self.config_yaml_content)

    def test_gemini_review_command_removed(self):
        self.assertFalse(
            (self.path / ".claude/commands/workflows/gemini-review.md").exists()
        )

    def test_coderabbit_review_command_installed(self):
        self.assertTrue(
            (self.path / ".claude/commands/workflows/coderabbit-review.md").is_file()
        )


class UserOwnedGeminiConfigSurvivesTests(unittest.TestCase):
    """지문이 없는 `.gemini/` 는 harness 가 심은 게 아니라 사용자 소유일 수 있다.

    지문 검사 없이 이름만 보고 지우면 harness 와 무관한 사용자 설정을 삭제하는
    회귀가 생긴다. GeminiMigrationTests(지문 있음 → 삭제)와 짝을 이루는 반대쪽
    사례: 지문 없음 → 보존.
    """

    @classmethod
    def setUpClass(cls):
        import tempfile

        cls._tmp = tempfile.TemporaryDirectory()
        cls.path = make_fixture(Path(cls._tmp.name) / "fixture", "nextjs")
        gemini_dir = cls.path / ".gemini"
        gemini_dir.mkdir()
        cls.user_content = "이건 harness 와 무관한 내 개인 Gemini CLI 설정이다.\n"
        (gemini_dir / "styleguide.md").write_text(cls.user_content, encoding="utf-8")
        cls.result = run_init(cls.path, env_type="js")

    @classmethod
    def tearDownClass(cls):
        cls._tmp.cleanup()

    def test_install_succeeds(self):
        self.assertEqual(self.result.returncode, 0, self.result.stderr[-2000:])

    def test_user_owned_gemini_file_is_not_touched(self):
        target = self.path / ".gemini" / "styleguide.md"
        self.assertTrue(target.exists(), "지문 없는 사용자 파일이 삭제됐다")
        self.assertEqual(target.read_text(encoding="utf-8"), self.user_content)


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

    def test_version_is_stamped_on_the_minimal_path_too(self):
        # 최소 하네스도 정식 설치다. 여기만 버전이 없으면 "무엇이 깔렸나"에 답이 없다.
        stamped = self.read(".claude/harness-version").strip()
        self.assertEqual(
            stamped, (ROOT / "VERSION").read_text(encoding="utf-8").strip()
        )

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
            body = strip_comments(workflow.read_text(encoding="utf-8"))
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

    def test_yaml_step_declares_its_dependency(self):
        """PyYAML 은 표준 라이브러리가 아니고 러너에도 없다.

        이 사실은 gates.json 이 YAML 대신 JSON 을 쓰는 이유로 레포에 이미 적혀
        있는데, CI 를 쓰면서 그대로 밟았다. 검사 단계와 설치 단계가 짝이 아니면
        같은 실패가 반복된다.
        """
        body = self.workflow.read_text(encoding="utf-8")
        if "import yaml" in body or "yaml.safe_load" in body:
            self.assertIn(
                "pip install --quiet pyyaml", body, "yaml 을 쓰면서 설치하지 않는다"
            )

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
