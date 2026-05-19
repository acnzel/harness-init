#!/bin/bash
# PreToolUse(Bash) 훅
# 위험한 Bash 명령 실행 전 경고를 출력한다.

CMD="${TOOL_INPUT:-}"

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

# rm -rf node_modules 이외의 rm -rf 경고
if echo "$CMD" | grep -qE "rm\s+-rf?\s+" && ! echo "$CMD" | grep -q "node_modules"; then
  echo ""
  echo "⚠️  rm -rf 감지 — 삭제 대상을 다시 확인하세요."
  echo ""
fi

# prisma migrate 없이 prisma db push (돌이킬 수 없는 스키마 반영)
if echo "$CMD" | grep -q "prisma db push" && ! echo "$CMD" | grep -q "--preview-feature\|--accept-data-loss"; then
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
