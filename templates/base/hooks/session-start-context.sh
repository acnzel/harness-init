#!/bin/bash
# SessionStart hook: debrief-guardrails 파일에서 교훈을 꺼내 컨텍스트 주입
# 전역(~/.claude/debrief-guardrails.md) + 프로젝트(.claude/debrief-guardrails.md) 순서로 읽는다

GLOBAL_GUARDRAILS="$HOME/.claude/debrief-guardrails.md"
PROJECT_GUARDRAILS="$(pwd)/.claude/debrief-guardrails.md"

HAS_CONTENT=false
OUTPUT=""

if [ -f "$GLOBAL_GUARDRAILS" ] && [ -s "$GLOBAL_GUARDRAILS" ]; then
  OUTPUT="$OUTPUT$(cat "$GLOBAL_GUARDRAILS")\n"
  HAS_CONTENT=true
fi

if [ -f "$PROJECT_GUARDRAILS" ] && [ -s "$PROJECT_GUARDRAILS" ]; then
  OUTPUT="$OUTPUT\n$(cat "$PROJECT_GUARDRAILS")\n"
  HAS_CONTENT=true
fi

if [ "$HAS_CONTENT" = true ]; then
  echo "[PAST SESSION LESSONS]"
  echo "과거 세션에서 누적된 가드레일. 이번 세션에서 같은 실수를 반복하지 말 것."
  echo ""
  printf "%b\n" "$OUTPUT"
fi
