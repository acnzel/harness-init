"""재실행 안전성 — 같은 레포에 두 번 깔아도 사용자 것이 안 깨져야 한다.

harness-init 은 주입 도구라 재실행이 정상 사용이다. 버그를 고치면 재실행으로
전파되어야 하고, 동시에 그 팀이 손댄 설정은 남아야 한다. 두 요구가 충돌하므로
소유권으로 가른다.

  하네스 소유 (`cp -f`)  훅·스크립트처럼 여럿이 함께 호출하는 코드. 항상 최신으로.
  사용자 소유 (`cp -n`)  gates.json·AGENTS.md 처럼 팀이 채우는 선언. 보존.

이 구분이 무너지면 둘 중 하나가 조용히 일어난다. `-n` 이면 고친 버그가 기존 설치에
영원히 전파되지 않고(실제로 `$TOOL_INPUT` 버그가 그랬다), `-f` 면 팀이 쓴 내용이
사라진다. 후자는 되돌릴 수 없다.
"""

import json
import tempfile
import unittest
from pathlib import Path

from support import make_fixture, run_init, tree_snapshot


class ReinstallTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.path = make_fixture(Path(self._tmp.name) / "fx", "django")
        first = run_init(self.path, env_type="python")
        self.assertEqual(first.returncode, 0, first.stderr[-2000:])

    def tearDown(self):
        self._tmp.cleanup()

    def test_reinstall_is_byte_identical(self):
        before = tree_snapshot(self.path)
        again = run_init(self.path, env_type="python")
        self.assertEqual(again.returncode, 0, again.stderr[-2000:])
        after = tree_snapshot(self.path)

        added = sorted(set(after) - set(before))
        removed = sorted(set(before) - set(after))
        changed = sorted(
            name for name in set(before) & set(after) if before[name] != after[name]
        )
        self.assertEqual(added, [], f"재실행이 파일을 추가했다: {added}")
        self.assertEqual(removed, [], f"재실행이 파일을 지웠다: {removed}")
        self.assertEqual(changed, [], f"재실행이 파일을 바꿨다: {changed}")

    def test_user_owned_declaration_survives(self):
        # gates.json 은 사용자 소유다. 팀이 게이트를 빼면 그 결정이 남아야 한다.
        gates_path = self.path / ".claude/gates.json"
        gates = json.loads(gates_path.read_text(encoding="utf-8"))
        gates["gates"] = [
            gate for gate in gates["gates"] if gate["name"] != "lint (ruff)"
        ]
        gates["_mine"] = "우리 팀이 고친 것"
        gates_path.write_text(json.dumps(gates, indent=2), encoding="utf-8")

        run_init(self.path, env_type="python")

        after = json.loads(gates_path.read_text(encoding="utf-8"))
        self.assertEqual(
            after.get("_mine"), "우리 팀이 고친 것", "사용자 선언이 덮어써졌다"
        )
        self.assertNotIn("lint (ruff)", [gate["name"] for gate in after["gates"]])

    def test_user_edited_agents_md_survives(self):
        # AGENTS.md 는 절대 규칙을 사람이 채우는 문서다. 마커 밖은 보존해야 한다.
        agents_path = self.path / "AGENTS.md"
        marked = (
            agents_path.read_text(encoding="utf-8")
            + "\n## 우리 팀 규칙\n결제 경로 금지\n"
        )
        agents_path.write_text(marked, encoding="utf-8")

        run_init(self.path, env_type="python")

        after = agents_path.read_text(encoding="utf-8")
        self.assertIn("## 우리 팀 규칙", after)
        self.assertIn("결제 경로 금지", after)

    def test_harness_owned_tool_is_refreshed(self):
        # 반대 방향. 하네스 소유 코드는 낡은 채로 남으면 안 된다.
        tool = self.path / ".claude/scripts/gate-runner.py"
        tool.write_text("# 낡은 버전\n", encoding="utf-8")

        run_init(self.path, env_type="python")

        refreshed = tool.read_text(encoding="utf-8")
        self.assertNotEqual(
            refreshed.strip(), "# 낡은 버전", "하네스 소유 코드가 갱신되지 않았다"
        )
        self.assertIn("gates.json", refreshed)

    def test_harness_owned_hook_is_refreshed(self):
        hook = self.path / ".claude/hooks/pre-bash-guard.sh"
        hook.write_text("#!/bin/bash\nexit 0\n", encoding="utf-8")

        run_init(self.path, env_type="python")

        self.assertIn("hook_input_load", hook.read_text(encoding="utf-8"))

    def test_user_added_hook_is_preserved(self):
        # _owned 목록 밖의 .sh 는 그 팀이 추가한 훅이다. 건드리면 안 된다.
        mine = self.path / ".claude/hooks/our-own-hook.sh"
        mine.write_text("#!/bin/bash\necho 우리것\n", encoding="utf-8")

        run_init(self.path, env_type="python")

        self.assertTrue(mine.is_file(), "사용자 훅이 사라졌다")
        self.assertIn("우리것", mine.read_text(encoding="utf-8"))


class UnknownStackReinstallTests(unittest.TestCase):
    """미감지 경로도 재실행이 안전해야 한다. 여기서 CLAUDE.md 가 두 번 붙던 전례가 있다."""

    def test_reinstall_is_byte_identical(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = make_fixture(Path(tmp) / "fx", "unknown")
            run_init(path, env_type="auto")
            before = tree_snapshot(path)
            run_init(path, env_type="auto")
            self.assertEqual(tree_snapshot(path), before)


if __name__ == "__main__":
    unittest.main()
