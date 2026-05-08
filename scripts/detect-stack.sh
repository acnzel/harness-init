#!/bin/bash

# 프로젝트 디렉토리에서 스택 자동 감지
# 출력: django | base

TARGET_DIR="${1:-$PWD}"

if [ -f "$TARGET_DIR/requirements.txt" ] || \
   [ -f "$TARGET_DIR/pyproject.toml" ] || \
   [ -f "$TARGET_DIR/manage.py" ]; then
  if grep -qi "django" "$TARGET_DIR/requirements.txt" 2>/dev/null || \
     grep -qi "django" "$TARGET_DIR/pyproject.toml" 2>/dev/null || \
     [ -f "$TARGET_DIR/manage.py" ]; then
    echo "django"
    exit 0
  fi
fi

echo "base"
