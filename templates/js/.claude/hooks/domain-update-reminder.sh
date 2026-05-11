#!/bin/bash
# PostToolUse(Edit, Write) 훅
# 스키마/엔티티 파일 변경 시 DOMAIN.md 업데이트를 상기시킨다.

SCHEMA_CHANGED=false
SERVICE_CHANGED=false

# HEAD가 없는 신규 저장소에서는 ls-files를 폴백으로 사용
FILES=$(git diff --name-only HEAD 2>/dev/null || git ls-files -m -o --exclude-standard)

# Prisma schema, TypeORM entity, Mongoose schema, Drizzle schema 감지
if echo "$FILES" | grep -qE '(^|/)(schema\.prisma|\.entity\.ts|\.schema\.ts|drizzle\.ts|db/schema\.ts)$'; then
  SCHEMA_CHANGED=true
fi
# Service, Controller, Server Actions 변경 감지
if echo "$FILES" | grep -qE '(^|/)(\.service\.ts|\.controller\.ts|actions\.ts|route\.ts)$'; then
  SERVICE_CHANGED=true
fi

if [ "$SCHEMA_CHANGED" = true ]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📝 DOMAIN.md 업데이트 필요 확인"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "스키마/엔티티 파일이 변경되었습니다. 아래 항목을 확인하고 DOMAIN.md를 갱신하세요:"
  echo ""
  echo "  ✓ 새 필드가 추가되었나요?"
  echo "  ✓ enum/status 값이 변경되었나요?"
  echo "  ✓ 엔티티 간 관계(1:N/N:M)가 변경되었나요?"
  echo ""
  echo "  갱신 대상: DOMAIN.md (핵심 엔티티 · 상태 코드 · 변경 이력)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

if [ "$SERVICE_CHANGED" = true ]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📋 비즈니스 로직 변경 감지"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "서비스/컨트롤러/액션 파일이 변경되었습니다."
  echo "비즈니스 로직이 바뀐 경우 DOMAIN.md 갱신을 고려하세요:"
  echo ""
  echo "  ✓ 상태 전이 흐름이 변경되었나요?"
  echo "  ✓ 새 API 엔드포인트가 추가되었나요?"
  echo "  ✓ 기존 동작 방식이 변경되었나요?"
  echo ""
  echo "  갱신 대상: DOMAIN.md (API 계약 · 주요 흐름 · 변경 이력)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi
