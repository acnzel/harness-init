#!/bin/bash

# harness-init: 프로젝트에 Harness Engineering 환경 셋업
# 사용법: bash init.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/templates"
TARGET_DIR="${PWD}"

# ── 색상 출력 ──────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[harness]${NC} $1"; }
success() { echo -e "${GREEN}[harness]${NC} ✓ $1"; }
warn()    { echo -e "${YELLOW}[harness]${NC} $1"; }

# ── 스택 감지 ──────────────────────────────────────────
STACK=$(bash "$SCRIPT_DIR/scripts/migration.sh" --detect "$TARGET_DIR")
info "감지된 스택: $STACK"

# ── CLAUDE.md 생성/업데이트 ────────────────────────────
bash "$SCRIPT_DIR/scripts/merge-claude-md.sh" "$TARGET_DIR" "$TEMPLATE_DIR"

# ── .claude 디렉토리 구조 생성 ─────────────────────────
info ".claude 디렉토리 구성 중..."

mkdir -p "$TARGET_DIR/.claude/tasks"
mkdir -p "$TARGET_DIR/.claude/decisions"
mkdir -p "$TARGET_DIR/.claude/skills"
mkdir -p "$TARGET_DIR/.claude/agents"
mkdir -p "$TARGET_DIR/.claude/commands"

# skills 복사 (서브디렉토리 포함: orchestrator/)
cp -rn "$TEMPLATE_DIR/django/.claude/skills/"* "$TARGET_DIR/.claude/skills/" 2>/dev/null || true
success "skills 설치 완료"

# ADR 템플릿 복사
cp -n "$TEMPLATE_DIR/django/.claude/decisions/adr-template.md" "$TARGET_DIR/.claude/decisions/" 2>/dev/null || true

# agents 복사
cp -rn "$TEMPLATE_DIR/django/.claude/agents/"* "$TARGET_DIR/.claude/agents/" 2>/dev/null || true
success "agents 설치 완료"

# commands 복사
cp -rn "$TEMPLATE_DIR/django/.claude/commands/"* "$TARGET_DIR/.claude/commands/" 2>/dev/null || true
success "commands 설치 완료"

# hooks 복사
if [ -d "$TEMPLATE_DIR/django/.claude/hooks" ]; then
  mkdir -p "$TARGET_DIR/.claude/hooks"
  cp -rn "$TEMPLATE_DIR/django/.claude/hooks/"* "$TARGET_DIR/.claude/hooks/" 2>/dev/null || true
  chmod +x "$TARGET_DIR/.claude/hooks/"*.sh 2>/dev/null || true
  success "hooks 설치 완료"
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

# docs 복사
if [ -d "$TEMPLATE_DIR/django/docs" ]; then
  mkdir -p "$TARGET_DIR/docs"
  cp -rn "$TEMPLATE_DIR/django/docs/"* "$TARGET_DIR/docs/" 2>/dev/null || true
  success "docs 설치 완료"
fi

# ── .gitignore 업데이트 ────────────────────────────────
GITIGNORE="$TARGET_DIR/.gitignore"
APPEND_FILE="$TEMPLATE_DIR/django/.gitignore.append"

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

# ── pre-commit 설정 ────────────────────────────────────
PRECOMMIT_YAML="$TEMPLATE_DIR/django/.pre-commit-config.yaml"
if [ -f "$PRECOMMIT_YAML" ]; then
  if [ ! -f "$TARGET_DIR/.pre-commit-config.yaml" ]; then
    cp "$PRECOMMIT_YAML" "$TARGET_DIR/.pre-commit-config.yaml"
    success ".pre-commit-config.yaml 생성 완료"
  else
    warn ".pre-commit-config.yaml 이미 존재, 건너뜀"
  fi

  # pre-commit 설치 확인 및 자동 설치
  if ! command -v pre-commit &>/dev/null; then
    info "pre-commit 미설치 — pip으로 설치 중..."
    if command -v pip &>/dev/null; then
      pip install pre-commit -q
    elif command -v pip3 &>/dev/null; then
      pip3 install pre-commit -q
    else
      warn "pip을 찾을 수 없습니다. 수동으로 'pip install pre-commit' 후 'pre-commit install' 실행 필요"
    fi
  fi

  # git 저장소이면 훅 등록 (pre-commit 설치 확인 후 실행)
  if git -C "$TARGET_DIR" rev-parse --git-dir &>/dev/null; then
    if command -v pre-commit &>/dev/null; then
      (cd "$TARGET_DIR" && pre-commit install) && success "pre-commit 훅 등록 완료"
    fi
  else
    warn "git 저장소가 아닙니다. 'git init' 후 'pre-commit install' 수동 실행 필요"
  fi
fi

# ── 비 Django 스택이면 harness 마이그레이션 ───────────
if [ "$STACK" != "django" ]; then
  info "비 Django 스택 감지 — harness 마이그레이션 실행..."
  bash "$SCRIPT_DIR/scripts/migration.sh" "$TARGET_DIR"
fi

# ── 기존 프로젝트이면 DOMAIN.md 스켈레톤 생성 ──────────
# models.py 가 마이그레이션 외에 존재하면 기개발 프로젝트로 판단
EXISTING_MODELS=$(find "$TARGET_DIR" -name "models.py" \
  ! -path "*/migrations/*" \
  ! -path "*/.venv/*" \
  ! -path "*/venv/*" \
  ! -path "*/env/*" \
  ! -path "*/__pycache__/*" \
  ! -path "*/.git/*" \
  2>/dev/null | head -1)

if [ -n "$EXISTING_MODELS" ]; then
  info "기존 Django 앱 감지 — DOMAIN.md 스켈레톤 생성 중..."
  bash "$SCRIPT_DIR/scripts/domain-init.sh" "$TARGET_DIR"
fi

# ── 완료 메시지 ────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN} Harness Engineering 환경 셋업 완료! [$STACK]${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  생성된 파일:"
echo "  ├── CLAUDE.md"
echo "  ├── .gitignore"
echo "  ├── .pre-commit-config.yaml   (pre-commit-hooks + ruff)"
echo "  ├── .claude/tasks/"
echo "  ├── .claude/decisions/"
echo "  ├── .claude/skills/          (explore/implement/debug/review/autopilot + orchestrator)"
echo "  ├── .claude/agents/          (analyst/architect/coder/tester/reviewer)"
echo "  ├── .claude/commands/        (/review, /workflows:gemini-review 슬래시 커맨드)"
echo "  ├── .claude/hooks/           (domain-update-reminder.sh — Edit/Write PostToolUse)"
echo "  ├── .claude/settings.json"
echo "  ├── .gemini/                 (Gemini Code Assist 설정)"
echo "  ├── .github/                 (이슈 템플릿, PR 템플릿, 워크플로우)"
echo "  ├── docs/DOC-SYNC-POLICY.md  (문서 동기화 정책)"
  if [ -n "$EXISTING_MODELS" ]; then
    echo "  └── DOMAIN.md + 앱별 DOMAIN.md  (기존 프로젝트 — TODO 항목 채우기 필요)"
  else
    echo "  └── (DOMAIN.md: 신규 프로젝트 — 앱 개발 후 domain-init.sh 실행)"
  fi
echo ""
echo "  에이전트 팀 (orchestrator 스킬):"
echo "  analyst → architect → coder ⇄ tester → reviewer"
echo ""
echo "  슬래시 커맨드:"
echo "  /orchestrator   /review   /explore   /implement   /debug   /autopilot"
echo ""
echo "  GitHub Actions:"
echo "  claude-code-review · claude · pr-auto-fill · pr-test · post-merge-docs"
echo ""
