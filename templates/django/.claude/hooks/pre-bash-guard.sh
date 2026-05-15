#!/bin/bash
# PreToolUse(Bash) 훅
# 위험한 Bash 명령 실행 전 경고를 출력한다.

CMD="${TOOL_INPUT:-}"

# manage.py migrate (--check/--plan/--fake/--list 없이) → 체크리스트 출력
if echo "$CMD" | grep -q "manage.py migrate" && ! echo "$CMD" | grep -qE "(--check|--plan|--fake|--list)"; then
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
  echo ""
  echo "⚠️  WHERE 절 없는 DELETE 감지 — 테이블 전체 삭제 위험"
  echo ""
fi

# pytest 없이 테스트 실행 시 힌트
if echo "$CMD" | grep -q "python manage.py test" && ! echo "$CMD" | grep -q "pytest"; then
  echo ""
  echo "💡 힌트: pytest를 사용하면 더 빠르고 상세한 결과를 얻을 수 있습니다."
  echo "  python -m pytest --tb=short -q"
  echo ""
fi
