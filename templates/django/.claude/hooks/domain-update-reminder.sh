#!/bin/bash
# PostToolUse(Edit, Write) 훅
# models.py / services.py / views.py 변경 시 DOMAIN.md 업데이트를 상기시킨다.

MODEL_CHANGED=false
SERVICE_CHANGED=false

# HEAD가 없는 신규 저장소에서는 ls-files를 폴백으로 사용
FILES=$(git diff --name-only HEAD 2>/dev/null || git ls-files -m -o --exclude-standard)

if echo "$FILES" | grep -qE '(^|/)models\.py$'; then
  MODEL_CHANGED=true
fi
if echo "$FILES" | grep -qE '(^|/)(services|views)\.py$'; then
  SERVICE_CHANGED=true
fi

if [ "$MODEL_CHANGED" = true ]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📝 DOMAIN.md 업데이트 필요 확인"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "models.py 가 변경되었습니다. 아래 항목을 확인하고 DOMAIN.md를 갱신하세요:"
  echo ""
  echo "  ✓ 새 필드가 추가되었나요?"
  echo "  ✓ 상태값(choices/status)이 변경되었나요?"
  echo "  ✓ 모델 간 관계(FK/O2O)가 변경되었나요?"
  echo ""
  echo "  갱신 대상: {app}/DOMAIN.md (핵심 모델 · 상태 코드 · 변경 이력)"
  echo "  신규 앱이면: 루트 DOMAIN.md 인덱스 테이블에 행 추가"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

if [ "$SERVICE_CHANGED" = true ]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📋 비즈니스 로직 변경 감지"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "services.py 또는 views.py 가 변경되었습니다."
  echo "비즈니스 로직이 바뀐 경우 DOMAIN.md 갱신을 고려하세요:"
  echo ""
  echo "  ✓ 상태 전이 흐름이 변경되었나요?"
  echo "  ✓ 새 API 엔드포인트가 추가되었나요?"
  echo "  ✓ 기존 동작 방식이 변경되었나요?"
  echo ""
  echo "  갱신 대상: {app}/DOMAIN.md (주요 흐름 · 변경 이력)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi
