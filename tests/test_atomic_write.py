"""원자적 쓰기 — 중단돼도 사람이 쓴 파일이 살아남아야 한다.

이전 구현은 `open(path, "w").write(...)` 였다. 먼저 잘라내고 그다음에 쓰므로, 그
사이에 죽으면 원본은 사라지고 새 내용은 안 들어간다. 대상은 AGENTS.md·커밋
메시지·pyproject.toml 이라 전부 되돌릴 수 없는 유실이다.

여기서는 쓰기 도중 예외를 강제로 일으켜 원본이 그대로인지 확인한다. 성공 경로만
보면 이 회귀를 못 잡는다.
"""

import os
import stat
import sys
import tempfile
import unittest
from unittest import mock
from pathlib import Path

from support import ROOT

sys.path.insert(0, str(ROOT / "scripts"))
import atomic_write  # noqa: E402
from atomic_write import atomic_write_text  # noqa: E402


class AtomicWriteTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.path = Path(self._tmp.name) / "AGENTS.md"

    def tearDown(self):
        self._tmp.cleanup()

    def test_replaces_content(self):
        self.path.write_text("옛 내용\n", encoding="utf-8")
        atomic_write_text(self.path, "새 내용\n")
        self.assertEqual(self.path.read_text(encoding="utf-8"), "새 내용\n")

    def test_creates_missing_file(self):
        atomic_write_text(self.path, "처음\n")
        self.assertEqual(self.path.read_text(encoding="utf-8"), "처음\n")

    def test_original_survives_a_write_failure(self):
        # 디스크가 차면 fsync 가 터진다. 이 시점에 원본이 이미 잘려 있으면 유실이다.
        original = "팀이 쓴 절대 규칙\n"
        self.path.write_text(original, encoding="utf-8")

        with mock.patch.object(atomic_write.os, "fsync", side_effect=OSError("ENOSPC")):
            with self.assertRaises(OSError):
                atomic_write_text(self.path, "새 내용\n")

        self.assertEqual(
            self.path.read_text(encoding="utf-8"), original,
            "쓰기 실패 후 원본이 훼손됐다",
        )

    def test_original_survives_a_replace_failure(self):
        original = "팀이 쓴 절대 규칙\n"
        self.path.write_text(original, encoding="utf-8")

        with mock.patch.object(atomic_write.os, "replace", side_effect=OSError("EACCES")):
            with self.assertRaises(OSError):
                atomic_write_text(self.path, "새 내용\n")

        self.assertEqual(self.path.read_text(encoding="utf-8"), original)

    def test_failed_write_leaves_no_stray_file(self):
        self.path.write_text("원본\n", encoding="utf-8")
        directory = self.path.parent
        before = set(directory.iterdir())

        with mock.patch.object(atomic_write.os, "fsync", side_effect=OSError("ENOSPC")):
            with self.assertRaises(OSError):
                atomic_write_text(self.path, "x")

        self.assertEqual(set(directory.iterdir()), before, "임시 파일이 남았다")

    def test_preserves_permissions(self):
        self.path.write_text("x\n", encoding="utf-8")
        os.chmod(self.path, 0o640)
        atomic_write_text(self.path, "y\n")
        self.assertEqual(stat.S_IMODE(self.path.stat().st_mode), 0o640)

    def test_follows_symlink_instead_of_replacing_it(self):
        # 팀이 AGENTS.md 를 다른 곳으로 링크해 뒀을 때 링크를 실체 파일로 바꿔
        # 버리면 그쪽 구조가 조용히 깨진다.
        real = self.path.parent / "real.md"
        real.write_text("원본\n", encoding="utf-8")
        self.path.symlink_to(real)

        atomic_write_text(self.path, "갱신\n")

        self.assertTrue(self.path.is_symlink(), "심볼릭 링크가 실체 파일로 바뀌었다")
        self.assertEqual(real.read_text(encoding="utf-8"), "갱신\n")

    def test_temporary_file_lands_in_target_directory(self):
        # /tmp 를 쓰면 파일시스템이 달라져 os.replace 가 원자적 rename 이 아니게 된다.
        source = (ROOT / "scripts/atomic_write.py").read_text(encoding="utf-8")
        self.assertIn("dir=directory", source)


class ShippedWithHarnessTests(unittest.TestCase):
    """atomic_write.py 가 안 따라가면 이걸 import 하는 세 스크립트가 대상 레포에서 죽는다."""

    def test_init_copies_and_verifies_atomic_write(self):
        init = (ROOT / "init.sh").read_text(encoding="utf-8")
        self.assertIn("scripts/atomic_write.py", init, "복사 목록에 없다")
        self.assertIn("for _t in atomic_write ", init, "도착 검증 목록에 없다")

    def test_importers_declare_the_dependency(self):
        for name in ("render-agents.py", "commit-msg.py", "lint-baseline.py"):
            body = (ROOT / "scripts" / name).read_text(encoding="utf-8")
            self.assertIn("from atomic_write import atomic_write_text", body, name)
            self.assertNotIn(
                'open(path, "w"', body, f"{name} 에 truncate 쓰기가 남아 있다"
            )


if __name__ == "__main__":
    unittest.main()
