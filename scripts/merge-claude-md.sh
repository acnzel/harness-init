#!/bin/bash

# base/CLAUDE.md + {stack}/CLAUDE.md 를 합쳐 프로젝트에 주입
# 기존 CLAUDE.md가 있으면 harness 섹션만 추가, 없으면 새로 생성

TARGET_DIR="$1"
STACK="$2"
TEMPLATE_DIR="$3"

BASE_TEMPLATE="$TEMPLATE_DIR/base/CLAUDE.md"
STACK_TEMPLATE="$TEMPLATE_DIR/$STACK/CLAUDE.md"
TARGET_FILE="$TARGET_DIR/CLAUDE.md"

MARKER="<!-- harness-init: DO NOT REMOVE -->"

if [ -f "$TARGET_FILE" ]; then
  # 이미 주입된 경우 스킵
  if grep -q "$MARKER" "$TARGET_FILE"; then
    echo -e "\033[1;33m[harness]\033[0m CLAUDE.md 이미 harness 설정 포함, 건너뜀"
    exit 0
  fi

  # 기존 파일에 harness 섹션 추가
  echo "" >> "$TARGET_FILE"
  echo "$MARKER" >> "$TARGET_FILE"
  echo "" >> "$TARGET_FILE"
  cat "$BASE_TEMPLATE" >> "$TARGET_FILE"

  if [ -f "$STACK_TEMPLATE" ]; then
    echo "" >> "$TARGET_FILE"
    cat "$STACK_TEMPLATE" >> "$TARGET_FILE"
  fi

  echo -e "\033[0;32m[harness]\033[0m ✓ CLAUDE.md 업데이트 완료 ($STACK 섹션 추가)"
else
  # 새로 생성
  cat "$BASE_TEMPLATE" > "$TARGET_FILE"

  if [ -f "$STACK_TEMPLATE" ]; then
    echo "" >> "$TARGET_FILE"
    echo "$MARKER" >> "$TARGET_FILE"
    echo "" >> "$TARGET_FILE"
    cat "$STACK_TEMPLATE" >> "$TARGET_FILE"
  fi

  echo -e "\033[0;32m[harness]\033[0m ✓ CLAUDE.md 생성 완료"
fi
