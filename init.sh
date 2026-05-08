#!/bin/bash

# harness-init: 프로젝트에 Harness Engineering 환경 셋업
# 사용법: bash init.sh [django|base]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/templates"
TARGET_DIR="${PWD}"
STACK="${1:-}"

# ── 색상 출력 ──────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[harness]${NC} $1"; }
success() { echo -e "${GREEN}[harness]${NC} ✓ $1"; }
warn()    { echo -e "${YELLOW}[harness]${NC} $1"; }

# ── 스택 감지 ──────────────────────────────────────────
if [ -z "$STACK" ]; then
  STACK=$(bash "$SCRIPT_DIR/scripts/detect-stack.sh" "$TARGET_DIR")
  info "스택 자동 감지: $STACK"
else
  info "스택 지정: $STACK"
fi

# ── CLAUDE.md 생성/업데이트 ────────────────────────────
bash "$SCRIPT_DIR/scripts/merge-claude-md.sh" "$TARGET_DIR" "$STACK" "$TEMPLATE_DIR"

# ── .claude 디렉토리 구조 생성 ─────────────────────────
info ".claude 디렉토리 구성 중..."

mkdir -p "$TARGET_DIR/.claude/tasks"
mkdir -p "$TARGET_DIR/.claude/decisions"
mkdir -p "$TARGET_DIR/.claude/skills"

# base skills 복사 (flat *.md)
cp -n "$TEMPLATE_DIR/base/.claude/skills/"*.md "$TARGET_DIR/.claude/skills/" 2>/dev/null || true

# ADR 템플릿 복사
cp -n "$TEMPLATE_DIR/base/.claude/decisions/adr-template.md" "$TARGET_DIR/.claude/decisions/" 2>/dev/null || true

success "base skills 설치 완료"

# ── 스택별 추가 설치 ───────────────────────────────────
if [ "$STACK" = "django" ]; then
  info "django 전용 환경 구성 중..."

  # agents 복사
  if [ -d "$TEMPLATE_DIR/django/.claude/agents" ]; then
    mkdir -p "$TARGET_DIR/.claude/agents"
    cp -rn "$TEMPLATE_DIR/django/.claude/agents/"* "$TARGET_DIR/.claude/agents/" 2>/dev/null || true
    success "agents 설치 완료"
  fi

  # commands 복사
  if [ -d "$TEMPLATE_DIR/django/.claude/commands" ]; then
    mkdir -p "$TARGET_DIR/.claude/commands"
    cp -rn "$TEMPLATE_DIR/django/.claude/commands/"* "$TARGET_DIR/.claude/commands/" 2>/dev/null || true
    success "commands 설치 완료"
  fi

  # skills (서브디렉토리 포함: orchestrator/)
  if [ -d "$TEMPLATE_DIR/django/.claude/skills" ]; then
    cp -rn "$TEMPLATE_DIR/django/.claude/skills/"* "$TARGET_DIR/.claude/skills/" 2>/dev/null || true
    success "django skills 설치 완료"
  fi

  # settings.json (없을 때만 생성)
  if [ ! -f "$TARGET_DIR/.claude/settings.json" ]; then
    cp "$TEMPLATE_DIR/django/.claude/settings.json" "$TARGET_DIR/.claude/settings.json"
    success "settings.json 생성 완료"
  else
    warn ".claude/settings.json 이미 존재, 건너뜀"
  fi

  # .gemini 복사
  if [ -d "$TEMPLATE_DIR/django/.gemini" ]; then
    mkdir -p "$TARGET_DIR/.gemini"
    cp -rn "$TEMPLATE_DIR/django/.gemini/"* "$TARGET_DIR/.gemini/" 2>/dev/null || true
    success ".gemini 설치 완료"
  fi

  # .github 복사
  if [ -d "$TEMPLATE_DIR/django/.github" ]; then
    mkdir -p "$TARGET_DIR/.github"
    cp -rn "$TEMPLATE_DIR/django/.github/"* "$TARGET_DIR/.github/" 2>/dev/null || true
    success ".github 설치 완료"
  fi

  # docs (DOC_SYNC_POLICY.md 등)
  if [ -d "$TEMPLATE_DIR/django/docs" ]; then
    mkdir -p "$TARGET_DIR/docs"
    cp -rn "$TEMPLATE_DIR/django/docs/"* "$TARGET_DIR/docs/" 2>/dev/null || true
    success "docs 설치 완료"
  fi
fi

# ── .gitignore 업데이트 ────────────────────────────────
GITIGNORE="$TARGET_DIR/.gitignore"
APPEND_FILE="$TEMPLATE_DIR/base/.gitignore.append"

if [ -f "$GITIGNORE" ]; then
  if ! grep -q ".claude/local/" "$GITIGNORE"; then
    echo "" >> "$GITIGNORE"
    cat "$APPEND_FILE" >> "$GITIGNORE"
    success ".gitignore 업데이트 완료"
  else
    warn ".gitignore 이미 설정됨, 건너뜀"
  fi
else
  cp "$APPEND_FILE" "$GITIGNORE"
  success ".gitignore 생성 완료"
fi


# ── 완료 메시지 ────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN} Harness Engineering 환경 셋업 완료! [$STACK]${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  생성된 파일:"
echo "  ├── CLAUDE.md"
echo "  ├── .gitignore (.claude/local/ 추가)"
echo "  ├── .claude/tasks/"
echo "  ├── .claude/decisions/"
echo "  ├── .claude/skills/"
if [ "$STACK" = "django" ]; then
echo "  ├── .claude/agents/         (5인 전문 에이전트 팀)"
echo "  ├── .claude/commands/       (/review 슬래시 커맨드)"
echo "  ├── .claude/settings.json"
echo "  ├── .gemini/                (Gemini Code Assist 설정)"
echo "  ├── .github/                (이슈 템플릿, PR 템플릿, 워크플로우)"
echo "  ├── docs/DOC-SYNC-POLICY.md  (문서 동기화 정책)"
fi
echo ""
if [ "$STACK" = "django" ]; then
echo "  에이전트 팀 (orchestrator 스킬):"
echo "  analyst → architect → coder ⇄ tester → reviewer"
echo ""
echo "  슬래시 커맨드:"
echo "  /orchestrator   /review   /explore   /implement   /debug"
echo ""
echo "  GitHub Actions:"
echo "  claude-code-review · claude · pr-auto-fill · pr-test · post-merge-docs"
echo ""
fi
