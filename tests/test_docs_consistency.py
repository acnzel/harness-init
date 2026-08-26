"""문서가 실물과 어긋나지 않는지 — 손으로 적은 목록은 반드시 낡는다.

이 레포는 정본을 한 곳에 두고 나머지는 생성하거나 참조하는 규칙을 갖고 있지만,
`CLAUDE.md` 와 `README.md` 의 구조 트리·단계 목록은 여전히 손으로 적는다. 실제로
셋 다 동시에 낡아 있었다.

  CLAUDE.md 트리        `templates/base-project/` 계층 누락, scripts 5개 누락
  CLAUDE.md 단계 목록   6단계로 적혀 있었으나 실제 단계 섹션은 18개
  README.md 트리        같은 base-project 누락

낡았다는 걸 사람이 알아채는 유일한 경로가 "누가 우연히 읽는 것"이면 안 된다.
"""

import re
import unittest
from pathlib import Path

from support import ROOT

CLAUDE_MD = (ROOT / "CLAUDE.md").read_text(encoding="utf-8")
README_MD = (ROOT / "README.md").read_text(encoding="utf-8")
INIT_SH = (ROOT / "init.sh").read_text(encoding="utf-8")


def init_step_markers():
    """init.sh 의 `# ── 제목 ──` 단계 마커. 색상 출력은 단계가 아니다."""
    found = re.findall(r"^# ── (.+?) ─*\s*$", INIT_SH, re.M)
    return [title.strip() for title in found if title.strip() != "색상 출력"]


class StepListTests(unittest.TestCase):
    """CLAUDE.md 의 단계 목록이 init.sh 마커와 순서·문구까지 같아야 한다."""

    def listed_steps(self):
        section = CLAUDE_MD.split("## init.sh 구조 (단계 순서)")[1]
        section = section.split("### 순서가 고정된 지점")[0]
        return re.findall(r"^\d+\.\s+\*\*(.+?)\*\*", section, re.M)

    def test_step_list_matches_init_sh(self):
        self.assertEqual(
            self.listed_steps(),
            init_step_markers(),
            "CLAUDE.md 단계 목록이 init.sh 의 `# ── ` 마커와 어긋난다",
        )

    def test_step_numbers_are_sequential(self):
        """번호가 끊기거나 겹치면 안 된다.

        제목만 비교하면 번호가 망가져도 통과한다. 실제로 단계를 하나 끼워 넣으면서
        뒤 번호를 연쇄 치환하다 15 다음이 19 가 된 적이 있고, 그때 목록 검사는
        초록불이었다.
        """
        section = CLAUDE_MD.split("## init.sh 구조 (단계 순서)")[1]
        section = section.split("### 순서가 고정된 지점")[0]
        numbers = [int(n) for n in re.findall(r"^(\d+)\.\s+\*\*", section, re.M)]
        self.assertEqual(numbers, list(range(1, len(numbers) + 1)), "단계 번호가 끊겼다")

    def test_constraint_table_points_at_real_steps(self):
        """순서 제약 표가 존재하지 않는 단계 번호를 가리키면 안 된다.

        이름까지 대조하지는 않는다. 표는 같은 단계를 더 좁게 부르는 편이
        읽기 좋고("settings.json 생성" vs ".claude 디렉토리 구조 생성"), 문구
        일치를 강제하면 문서를 나쁘게 만들면서 오탐만 낸다. 여기서 잡으려는 건
        단계를 끼워 넣고 표를 안 고쳐 번호가 어긋나는 경우다.
        """
        section = CLAUDE_MD.split("### 순서가 고정된 지점")[1]
        listed = self.listed_steps()
        # 앞 두 열(단계 / 반드시 이 뒤에)만 읽는다. "어기면" 열에는 `sys.exit(0)`
        # 같은 코드가 들어가고, 표 전체를 훑으면 그 0 을 단계 번호로 잡는다.
        referenced = []
        for row in re.findall(r"(?m)^\|(.+)\|$", section):
            cells = [cell.strip() for cell in row.split("|")]
            if len(cells) < 3 or cells[0].startswith("-") or cells[0] == "단계":
                continue
            for cell in cells[:2]:
                referenced += [int(n) for n in re.findall(r"\((\d+)\)\s*$", cell)]
        self.assertTrue(referenced, "순서 제약 표에서 단계 번호를 못 읽었다")
        for number in referenced:
            self.assertTrue(
                1 <= number <= len(listed),
                f"표가 없는 단계 번호를 가리킨다: {number} (단계는 1~{len(listed)})",
            )

    def test_step_list_records_no_line_numbers(self):
        # 줄 번호를 적으면 한 줄만 넣어도 전부 밀려서 다음 사람이 못 믿는다.
        section = CLAUDE_MD.split("## init.sh 구조 (단계 순서)")[1]
        section = section.split("## 템플릿 계층")[0]
        self.assertNotRegex(section, r"init\.sh:\d+", "단계 목록에 줄 번호가 적혀 있다")


class DirectoryTreeTests(unittest.TestCase):
    """문서의 구조 트리가 실제 디렉터리·파일과 같아야 한다."""

    def actual_scripts(self):
        return sorted(
            item.name for item in (ROOT / "scripts").iterdir() if item.is_file()
        )

    def actual_template_layers(self):
        return sorted(
            item.name for item in (ROOT / "templates").iterdir() if item.is_dir()
        )

    def documented_scripts(self, document):
        block = document.split("└── scripts/")[1].split("```")[0]
        return sorted(set(re.findall(r"[a-z][a-z_-]*\.(?:sh|py)", block)))

    def test_claude_md_lists_every_script(self):
        self.assertEqual(self.documented_scripts(CLAUDE_MD), self.actual_scripts())

    def test_readme_lists_every_script(self):
        self.assertEqual(self.documented_scripts(README_MD), self.actual_scripts())

    def test_both_documents_mention_every_template_layer(self):
        for name, document in (("CLAUDE.md", CLAUDE_MD), ("README.md", README_MD)):
            for layer in self.actual_template_layers():
                self.assertIn(
                    f"{layer}/",
                    document,
                    f"{name} 에 templates/{layer}/ 계층이 없다",
                )


class OrderingConstraintTests(unittest.TestCase):
    """CLAUDE.md 가 적어 둔 순서 제약이 init.sh 에서 실제로 지켜지는가."""

    def position(self, marker):
        index = init_step_markers().index(marker)
        return index

    def test_gate_selftest_injection_follows_settings_creation(self):
        self.assertLess(
            self.position(".claude 디렉토리 구조 생성"),
            self.position("게이트 자가진단 주입"),
        )

    def test_agents_render_follows_js_override(self):
        # JS 오버라이드가 gates.json 을 바꾸므로 렌더는 그 뒤여야 한다.
        self.assertLess(
            self.position("JS 환경 전용 파일 오버라이드"),
            self.position("AGENTS.md 자동 구간 렌더"),
        )

    def test_gate_measurement_is_last(self):
        self.assertEqual(init_step_markers()[-1], "설치 직후 게이트 실측")


class ChecklistTests(unittest.TestCase):
    """PR 템플릿 체크리스트가 실재하는 경로를 가리켜야 한다."""

    def test_pr_template_layers_exist(self):
        template = (ROOT / ".github/pull_request_template.md").read_text(
            encoding="utf-8"
        )
        for layer in re.findall(r"`(base|base-project|django|js)/`", template):
            resolved = "base-project" if layer == "base" else layer
            self.assertTrue(
                (ROOT / "templates" / resolved).is_dir(),
                f"PR 템플릿이 없는 계층을 가리킨다: {layer}",
            )


if __name__ == "__main__":
    unittest.main()
