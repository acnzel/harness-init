#!/bin/bash
# PreToolUse(Bash) 훅
# 위험한 Bash 명령 실행 전 경고를 출력한다.
#
# 입력은 stdin JSON 이다. 이전 버전은 `${TOOL_INPUT:-}` 라는 존재하지 않는
# 환경변수를 읽어서 **한 번도 발화한 적이 없었다** (2026-08-03 실측).
# 파싱은 _hook-input.sh 에 위임한다 (django 템플릿에서 함께 설치된다).

_HELPER="$(dirname "${BASH_SOURCE[0]}")/_hook-input.sh"
# 없음·읽기 불가·문법 오류를 한 번에 잡는다. 파일 존재만 확인하면 읽을 수 없거나
# 문법이 깨진 헬퍼를 놓치는데, 그때 source 가 실패해 hook_input_load 가 정의되지
# 않고 다음 줄이 command not found 로 exit 0 이 되어 훅이 조용히 꺼진다.
if ! source "$_HELPER" || ! declare -F hook_input_load >/dev/null; then
	echo "[harness] $_HELPER 를 불러올 수 없습니다 — pre-bash-guard 가 동작하지 않습니다." >&2
	exit 0
fi

hook_input_load || exit 0

CMD="$HOOK_COMMAND"
[ -n "$CMD" ] || exit 0

# 게이트 우회 감지. 판정은 _hook-input.sh 한 곳에 있다 (django 템플릿에서
# 함께 설치되며 양쪽 훅이 공유한다). 여기서 따로 판정하면 한쪽만 낡는다.
hook_report_bypass "$CMD"

FIRED=""

# DROP TABLE / TRUNCATE TABLE 경고
if echo "$CMD" | grep -qiE "(DROP TABLE|TRUNCATE TABLE)"; then
  FIRED="$FIRED drop-table"
  echo ""
  echo "🚨 파괴적 SQL 감지: DROP TABLE / TRUNCATE TABLE"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  이 명령은 데이터를 복구 불가능하게 삭제합니다."
  echo "  반드시 백업 후 실행하세요."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
fi

# WHERE 없는 DELETE 경고
if echo "$CMD" | grep -qiE "DELETE[[:space:]]+FROM[[:space:]]+[a-zA-Z_]+" && ! echo "$CMD" | grep -qi -w "WHERE"; then
  FIRED="$FIRED delete-no-where"
  echo ""
  echo "⚠️  WHERE 절 없는 DELETE 감지 — 테이블 전체 삭제 위험"
  echo ""
fi

# rm -rf node_modules 이외의 rm -rf 경고
if echo "$CMD" | grep -qE "rm\s+-rf?\s+" && ! echo "$CMD" | grep -q "node_modules"; then
  FIRED="$FIRED rm-rf"
  echo ""
  echo "⚠️  rm -rf 감지 — 삭제 대상을 다시 확인하세요."
  echo ""
fi

# prisma migrate 없이 prisma db push (돌이킬 수 없는 스키마 반영)
#
# `--` 로 옵션 파싱을 끊는다. BSD grep(macOS)은 `--accept-data-loss` 를 패턴이 아니라
# 자기 옵션으로 읽어 usage 를 뱉고 실패한다. 그러면 `!` 때문에 면제 플래그를 붙여도
# 경고가 그대로 떠서, 면제가 아예 동작하지 않는다. 훅이 죽어 있던 동안 드러나지
# 않았던 버그다 (2026-08-03).
if echo "$CMD" | grep -q "prisma db push" && ! echo "$CMD" | grep -qE -- "--preview-feature|--accept-data-loss"; then
  FIRED="$FIRED prisma-db-push"
  echo ""
  echo "⚠️  prisma db push 실행 전 체크리스트"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  ✓ 프로덕션 DB가 아닌 개발/테스트 DB인지 확인했나요?"
  echo "  ✓ 데이터 손실 가능한 컬럼 삭제/타입 변경이 없나요?"
  echo "  ✓ 마이그레이션 파일로 관리해야 하는 변경이 아닌가요?"
  echo "  권장: npx prisma migrate dev --name <migration-name>"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
fi

# 발화를 기록한다. 게이트의 침묵이 '안전'인지 '고장'인지는 기록이 있어야 구분된다.
[ -n "$FIRED" ] && hook_event gate_fired pre-bash-guard.sh "$FIRED |$CMD"

exit 0
