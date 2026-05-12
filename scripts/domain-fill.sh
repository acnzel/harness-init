#!/bin/bash
# domain-fill.sh: Claude Code /goal을 활용해 DOMAIN.md 스켈레톤을 실제 코드 내용으로 채운다
# 사용법: bash domain-fill.sh <TARGET_DIR>
#
# 동작: /goal 조건을 설정해 Claude가 모든 앱 DOMAIN.md를 완료될 때까지 자동 루프한다.

TARGET_DIR="${1:-$PWD}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[harness]${NC} $1"; }
success() { echo -e "${GREEN}[harness]${NC} ✓ $1"; }
warn()    { echo -e "${YELLOW}[harness]${NC} $1"; }

# ── Claude Code 설치 확인 ───────────────────────────────
if ! command -v claude &>/dev/null; then
  warn "Claude Code 미설치 — DOMAIN.md 자동 채우기를 건너뜁니다."
  warn "  설치 후 직접 실행: bash ~/harness-init/scripts/domain-fill.sh"
  warn "  설치 안내: https://claude.ai/code"
  exit 0
fi

# ── DOMAIN.md 존재 여부 확인 ────────────────────────────
if ! find "$TARGET_DIR" -name "DOMAIN.md" \
    ! -path "*/migrations/*" ! -path "*/.venv/*" ! -path "*/venv/*" \
    ! -path "*/env/*" ! -path "*/__pycache__/*" ! -path "*/.git/*" | grep -q .; then
  warn "DOMAIN.md 파일이 없습니다. domain-init.sh를 먼저 실행하세요."
  exit 0
fi

info "Claude Code /goal로 DOMAIN.md 자동 채우기 시작..."

GOAL="프로젝트의 모든 Django 앱(migrations, venv, env, __pycache__, .git 제외)의 DOMAIN.md 스켈레톤이 없으면 생성하고, 해당 models.py의 실제 필드·관계·Choices로 채운 뒤, 루트 DOMAIN.md의 앱 인덱스·Quick Reference·관계 다이어그램을 업데이트할 것. 각 앱 완료 시 반드시 '✓ {앱명} DOMAIN.md 완료'를 출력할 것. 코드에 없는 내용은 절대 추가하지 말 것. or stop after 50 turns"

(cd "$TARGET_DIR" && claude --dangerously-skip-permissions -p "/goal $GOAL" </dev/null)
EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
  success "모든 DOMAIN.md 자동 채우기 완료"
else
  warn "DOMAIN.md 채우기 중 오류 발생 — 수동으로 확인하거나 재실행하세요"
  warn "재실행: bash ~/harness-init/scripts/domain-fill.sh"
fi
