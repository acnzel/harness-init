#!/bin/bash
# CLAUDE.md를 프로젝트에 주입
# - 기존 파일 있으면 harness 섹션 추가
# - 없으면 새로 생성

TARGET_DIR="$1"
TEMPLATE_DIR="$2"

TEMPLATE_FILE="$TEMPLATE_DIR/django/CLAUDE.md"
TARGET_FILE="$TARGET_DIR/CLAUDE.md"
MARKER="<!-- harness-init: DO NOT REMOVE -->"

if [ -f "$TARGET_FILE" ]; then
  if grep -q "$MARKER" "$TARGET_FILE"; then
    echo -e "\033[1;33m[harness]\033[0m CLAUDE.md 이미 harness 설정 포함, 건너뜀"
    exit 0
  fi
  {
    echo ""
    cat "$TEMPLATE_FILE"
  } >> "$TARGET_FILE"
  echo -e "\033[0;32m[harness]\033[0m ✓ CLAUDE.md 업데이트 완료"
else
  # 마커는 템플릿 첫 줄에 들어 있다. 여기서 따로 찍지 않는 이유는 init.sh 가
  # JS 스택에서 이 파일을 js/CLAUDE.md 로 통째로 덮어쓰기 때문이다. 마커가
  # 템플릿에 있어야 그 경로에서도 살아남고, 재실행 시 "harness 설정 없음"으로
  # 판정해 템플릿을 한 번 더 덧붙이는 일이 없다.
  cp "$TEMPLATE_FILE" "$TARGET_FILE"
  echo -e "\033[0;32m[harness]\033[0m ✓ CLAUDE.md 생성 완료"
fi
