#!/bin/bash
# PostToolUse(Bash, Edit, Write) 훅
# Claude 응답의 ★ Insight 블록을 감지해 .claude/insights.md 에 자동 저장

INSIGHTS_FILE=".claude/insights.md"
STATE_FILE=".claude/local/insight-collector.state"

mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null

# 현재 프로젝트 슬러그 (Claude Code 방식: / → -)
SLUG=$(pwd | sed 's|/|-|g' | sed 's/^-//')
SESSIONS_DIR="$HOME/.claude/projects/$SLUG"

[ -d "$SESSIONS_DIR" ] || exit 0

# 가장 최근 세션 JSONL
LATEST=$(ls -t "$SESSIONS_DIR"/*.jsonl 2>/dev/null | head -1)
[ -f "$LATEST" ] || exit 0

python3 - "$LATEST" "$INSIGHTS_FILE" "$STATE_FILE" << 'PYEOF'
import sys, json, re, os
from datetime import datetime

session_file = sys.argv[1]
insights_file = sys.argv[2]
state_file = sys.argv[3]

# 마지막으로 처리한 세션·라인 복원 (증분 스캔)
last_session = ""
last_line = 0
if os.path.exists(state_file):
    try:
        parts = open(state_file).read().strip().split('\n')
        last_session = parts[0] if parts else ""
        last_line = int(parts[1]) if len(parts) > 1 else 0
    except Exception:
        pass

# 세션이 바뀌면 처음부터 스캔
if last_session != session_file:
    last_line = 0

# ★ Insight 포맷 패턴
# `★ Insight ─────...`
#   내용 (멀티라인 가능)
# `─────...`
pattern = re.compile(
    r'`★ Insight\s*─+`\s*\n(.*?)\n\s*`─+`',
    re.DOTALL
)

# 기존 insights 로드 (중복 방지)
existing = open(insights_file).read() if os.path.exists(insights_file) else ""

new_insights = []
current_line = last_line

try:
    with open(session_file) as f:
        for i, raw in enumerate(f):
            if i < last_line:
                continue
            current_line = i + 1
            try:
                obj = json.loads(raw.strip())
                msg = obj.get('message', {})
                if msg.get('role') != 'assistant':
                    continue
                content = msg.get('content', [])
                if not isinstance(content, list):
                    continue
                for item in content:
                    if not isinstance(item, dict):
                        continue
                    text = item.get('text', '')
                    for m in pattern.finditer(text):
                        body = m.group(1).strip()
                        if body and body not in existing:
                            new_insights.append(body)
                            existing += body
            except Exception:
                pass
except Exception:
    pass

# 상태 저장 (다음 실행 시 증분 스캔)
with open(state_file, 'w') as f:
    f.write(f"{session_file}\n{current_line}")

if not new_insights:
    sys.exit(0)

# 첫 실행 시 헤더 작성
if not os.path.exists(insights_file):
    os.makedirs(os.path.dirname(insights_file) or '.', exist_ok=True)
    with open(insights_file, 'w') as f:
        f.write("# Insights\n\n프로젝트 작업 중 발견된 코드베이스 특화 인사이트.\n")

with open(insights_file, 'a') as f:
    for body in new_insights:
        ts = datetime.now().strftime('%Y-%m-%d %H:%M')
        f.write(f"\n---\n\n**{ts}**\n\n{body}\n")

print(f"\n💡 {len(new_insights)}개의 인사이트가 .claude/insights.md 에 저장됐습니다.")
PYEOF
