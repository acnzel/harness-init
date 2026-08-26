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
  # 마커는 템플릿 첫 줄에 들어 있다. init.sh 는 JS 스택에서 이 파일을 다시 한 번
  # 건드리지만(js/CLAUDE.md 로 교체), 마커 이전 구간만 보존하고 이후만 바꾸므로
  # 지금 막 생성한 이 파일(내용 전체가 마커 이후)은 그대로 교체 대상이 된다.
  # 마커가 템플릿에 있어야 재실행 시에도 "harness 설정 없음"으로 오판해 템플릿을
  # 한 번 더 덧붙이는 일이 없다.
  cp "$TEMPLATE_FILE" "$TARGET_FILE"
  echo -e "\033[0;32m[harness]\033[0m ✓ CLAUDE.md 생성 완료"
fi
