#!/bin/bash
# PreToolUse(Bash) 훅
# 위험한 Bash 명령 실행 전 경고를 출력한다.
#
# 입력은 stdin JSON 이다. 이전 버전은 `${TOOL_INPUT:-}` 라는 존재하지 않는
# 환경변수를 읽어서 **한 번도 발화한 적이 없었다** (2026-08-03 실측: stdin
# JSON 을 넣으면 무음 exit 0, TOOL_INPUT 을 강제 주입해야만 경고가 나왔다).
# 파싱은 _hook-input.sh 에 위임한다 — 훅마다 각자 파싱하면 같은 일이 반복된다.

_HELPER="$(dirname "${BASH_SOURCE[0]}")/_hook-input.sh"
# 없음·읽기 불가·문법 오류를 한 번에 잡는다. source 가 실패하면 hook_input_load 가
# 정의되지 않고, 다음 줄이 command not found 로 exit 0 이 되어 훅이 조용히 꺼진다.
if ! source "$_HELPER" || ! declare -F hook_input_load >/dev/null; then
	echo "[harness] $_HELPER 를 불러올 수 없습니다 — pre-bash-guard 가 동작하지 않습니다." >&2
	exit 0
fi

hook_input_load || exit 0

CMD="$HOOK_COMMAND"
[ -n "$CMD" ] || exit 0

FIRED=""

# manage.py migrate (--check/--plan/--fake/--list 없이) → 체크리스트 출력
if echo "$CMD" | grep -q "manage.py migrate" && ! echo "$CMD" | grep -qE "(--check|--plan|--fake|--list)"; then
  FIRED="$FIRED migrate"
  echo ""
  echo "⚠️  마이그레이션 실행 전 체크리스트"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  ✓ 변경된 마이그레이션 파일을 검토했나요?"
  echo "  ✓ staging에서 먼저 테스트했나요?"
  echo "  ✓ 되돌릴 수 없는 스키마 변경(컬럼 삭제 등)이 있나요?"
  echo "  먼저 확인: python manage.py migrate --check"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
fi

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

# pytest 없이 테스트 실행 시 힌트
if echo "$CMD" | grep -q "python manage.py test" && ! echo "$CMD" | grep -q "pytest"; then
  FIRED="$FIRED pytest-hint"
  echo ""
  echo "💡 힌트: pytest를 사용하면 더 빠르고 상세한 결과를 얻을 수 있습니다."
  echo "  python -m pytest --tb=short -q"
  echo ""
fi

# 게이트 우회 감지. 판정은 _hook-input.sh 한 곳에 있다 (양쪽 훅이 공유).
hook_report_bypass "$CMD"

# 발화를 기록한다. 게이트의 침묵이 '안전'인지 '고장'인지는 기록이 있어야 구분된다.
[ -n "$FIRED" ] && hook_event gate_fired pre-bash-guard.sh "$FIRED |$CMD"

exit 0
