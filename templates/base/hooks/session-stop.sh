#!/bin/bash
# Stop hook: 세션 종료 시 ~/.claude/debriefs/에 세션 로그 기록
# Claude가 debrief를 작성했으면 git 스냅샷을 추가한다

DEBRIEF_DIR="$HOME/.claude/debriefs"
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H:%M)

CWD=$(pwd)
PROJECT=$(basename "$CWD")
BRANCH=$(git branch --show-current 2>/dev/null || echo "N/A")
LAST_COMMIT=$(git log -1 --pretty="%h %s" 2>/dev/null || echo "N/A")
CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD 2>/dev/null | head -10 | sed 's/^/    - /' || echo "    - N/A")
CHANGED_COUNT=$(git diff --name-only HEAD~1 HEAD 2>/dev/null | wc -l | tr -d ' ' 2>/dev/null || echo "0")
RECENT_COMMITS=$(git log -3 --pretty="%h %s" 2>/dev/null | sed 's/^/    - /' || echo "    - N/A")

mkdir -p "$DEBRIEF_DIR"

# ── session-log: 항상 기록되는 경량 메타데이터 ──
LOG_FILE="$DEBRIEF_DIR/$DATE-session-log.md"

if [ ! -f "$LOG_FILE" ]; then
  cat > "$LOG_FILE" << LOGEOF
# Session Log — $DATE

LOGEOF
fi

cat >> "$LOG_FILE" << LOGEOF

## $TIME — $PROJECT

- **브랜치**: \`$BRANCH\`
- **마지막 커밋**: \`$LAST_COMMIT\`
- **변경 파일 수**: $CHANGED_COUNT
- **최근 커밋**:
$RECENT_COMMITS
- **변경 파일**:
$CHANGED_FILES
LOGEOF

# ── debrief: Claude가 작성한 파일이 있으면 git 스냅샷 추가 ──
DEBRIEF_FILE="$DEBRIEF_DIR/$DATE-debrief.md"

if [ -f "$DEBRIEF_FILE" ]; then
  cat >> "$DEBRIEF_FILE" << DEBRIEFEOF

---
### Git 스냅샷 ($TIME) — $PROJECT

- **브랜치**: \`$BRANCH\`
- **마지막 커밋**: \`$LAST_COMMIT\`
- **변경 파일**:
$CHANGED_FILES
DEBRIEFEOF
fi
