#!/bin/bash
# Notification 훅
# Claude 작업 완료 시 macOS 알림 / Linux 알림 / 터미널 벨 순으로 시도한다.

TITLE="${NOTIFICATION_TITLE:-Claude Code}"
MSG="${NOTIFICATION_MESSAGE:-작업이 완료되었습니다}"

if command -v osascript &>/dev/null; then
  osascript -e "display notification \"$MSG\" with title \"$TITLE\" sound name \"Glass\"" 2>/dev/null || true
elif command -v notify-send &>/dev/null; then
  notify-send "$TITLE" "$MSG" 2>/dev/null || true
else
  printf '\a'
fi
