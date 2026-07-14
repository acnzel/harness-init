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

# ── 환경 선택 ──────────────────────────────────────────
if [ -z "$ENV_TYPE" ]; then
  if [ -t 0 ]; then
    echo ""
    echo -e "${BLUE}  어떤 환경으로 구축 예정이신가요?${NC}"
    echo "  1) Python  (Django / FastAPI / Flask)"
    echo "  2) JS / TS (Next.js / NestJS / Express)"
    echo "  3) 모름    (자동 감지)"
    echo ""
    printf "  선택 [1-3]: "
    read -r ENV_CHOICE || ENV_CHOICE="3"

    case "$ENV_CHOICE" in
      1) ENV_TYPE="python" ;;
      2) ENV_TYPE="js"     ;;
      *) ENV_TYPE="auto"   ;;
    esac
    echo ""
  else
    ENV_TYPE="auto"
  fi
fi

# ── Atlassian MCP 연동 여부 ────────────────────────────
USE_ATLASSIAN_MCP="${USE_ATLASSIAN_MCP:-}"
if [ -z "$USE_ATLASSIAN_MCP" ] && [ -t 0 ]; then
  echo -e "${BLUE}  Atlassian MCP 연동을 설정하시겠어요? (Jira·Confluence 연동)${NC}"
  echo "  1) 예 — settings.json에 MCP 서버 추가"
  echo "  2) 아니오"
  echo ""
  printf "  선택 [1-2]: "
  read -r ATLASSIAN_CHOICE || ATLASSIAN_CHOICE="2"
  case "$ATLASSIAN_CHOICE" in
    1) USE_ATLASSIAN_MCP="yes" ;;
    *) USE_ATLASSIAN_MCP="no"  ;;
  esac
  echo ""
fi

# ── 스택 감지 ──────────────────────────────────────────
STACK=$(bash "$SCRIPT_DIR/scripts/migration.sh" --detect "$TARGET_DIR")
info "감지된 스택: $STACK"

IS_UNKNOWN_ENV() { [ "$ENV_TYPE" = "auto" ] && [ "$STACK" = "unknown" ]; }

# ── 스택 미감지 — 최소 하네스(base-project)만 설치 ────
if IS_UNKNOWN_ENV; then
  info "스택을 감지할 수 없어 최소 하네스를 설치합니다..."
  mkdir -p "$TARGET_DIR/.claude/hooks"

  cp -n "$TEMPLATE_DIR/base-project/CLAUDE.md" \
        "$TARGET_DIR/CLAUDE.md" 2>/dev/null || warn "CLAUDE.md 이미 존재, 건너뜀"
  cp -n "$TEMPLATE_DIR/base-project/.claude/settings.json" \
        "$TARGET_DIR/.claude/settings.json" 2>/dev/null || true
  cp -n "$TEMPLATE_DIR/base-project/.claude/hooks/notification.sh" \
        "$TARGET_DIR/.claude/hooks/" 2>/dev/null || true
  cp -n "$TEMPLATE_DIR/base-project/.claude/hooks/insight-collector.sh" \
        "$TARGET_DIR/.claude/hooks/" 2>/dev/null || true
  chmod +x "$TARGET_DIR/.claude/hooks/"*.sh 2>/dev/null || true

  # .gitignore (base-project 범용 항목만)
  _GITIGNORE="$TARGET_DIR/.gitignore"
  _APPEND="$TEMPLATE_DIR/base-project/.gitignore.append"
  if [ -f "$_GITIGNORE" ]; then
    if ! grep -q ".claude/local/" "$_GITIGNORE"; then
      echo "" >> "$_GITIGNORE"
      cat "$_APPEND" >> "$_GITIGNORE"
      success ".gitignore 업데이트 완료 (base-project)"
    else
      warn ".gitignore 이미 설정됨, 건너뜀"
    fi
  else
    cp "$_APPEND" "$_GITIGNORE"
    success ".gitignore 생성 완료 (base-project)"
  fi

  success "최소 하네스 설치 완료"
  echo ""
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW} 스택 미감지 — 추가 설정 필요${NC}"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "  설치된 항목:"
  echo "  ├── CLAUDE.md         (코딩 원칙 — 스택 무관)"
  echo "  ├── .claude/settings.json"
  echo "  ├── .claude/hooks/    (notification, insight-collector)"
  echo "  └── .gitignore"
  echo ""
  echo "  다음 중 하나 후 init.sh를 다시 실행하세요:"
  echo "  ├── package.json 생성   → Next.js / NestJS / Express 감지"
  echo "  ├── pyproject.toml 생성 → FastAPI / Flask 감지"
  echo "  ├── manage.py 생성      → Django 감지"
  echo "  ├── go.mod 생성         → (현재 미지원 — 수동 설정 필요)"
  echo "  └── ENV_TYPE=python/js bash init.sh  → 명시적 지정"
  echo ""

  SKIP_FULL_INSTALL=true
fi

# ── CLAUDE.md 생성/업데이트 ────────────────────────────
if [ "${SKIP_FULL_INSTALL:-false}" != "true" ]; then
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

# rules 복사 (CLAUDE.md @imports 참조 대상)
if [ -d "$TEMPLATE_DIR/django/.claude/rules" ]; then
  mkdir -p "$TARGET_DIR/.claude/rules"
  cp -rn "$TEMPLATE_DIR/django/.claude/rules/"* "$TARGET_DIR/.claude/rules/" 2>/dev/null || true
  success "rules 설치 완료"
fi

PROJECT_NAME=$(basename "$TARGET_DIR")

# scripts 복사 (domain-sync GitHub Actions에서 참조)
mkdir -p "$TARGET_DIR/.claude/scripts"
cp "$SCRIPT_DIR/scripts/domain-init.sh" "$TARGET_DIR/.claude/scripts/domain-init.sh"
cp "$SCRIPT_DIR/scripts/domain-fill.sh" "$TARGET_DIR/.claude/scripts/domain-fill.sh"
chmod +x "$TARGET_DIR/.claude/scripts/"*.sh
success "scripts 설치 완료"

# settings.json (없을 때만 생성)
if [ ! -f "$TARGET_DIR/.claude/settings.json" ]; then
  cp "$TEMPLATE_DIR/django/.claude/settings.json" "$TARGET_DIR/.claude/settings.json"
  success "settings.json 생성 완료"
else
  warn ".claude/settings.json 이미 존재, 건너뜀"
fi

# ── LSP 설정 주입 ────────────────────────────────────────
# 언어에 따라 settings.json에 LSP 서버 설정 추가 (이미 lsp 키가 있으면 건너뜀)
SETTINGS_FILE="$TARGET_DIR/.claude/settings.json"
_inject_lsp_python() {
  python3 - "$SETTINGS_FILE" << 'PYEOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    s = json.load(f)
if "python" not in s.setdefault("lsp", {}):
    s["lsp"]["python"] = {"command": "pylsp"}
    with open(path, "w") as f:
        json.dump(s, f, indent=2, ensure_ascii=False)
        f.write("\n")
PYEOF
}
_inject_lsp_js() {
  python3 - "$SETTINGS_FILE" << 'PYEOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    s = json.load(f)
lsp = s.setdefault("lsp", {})
if "typescript" not in lsp or "javascript" not in lsp:
    lsp.update({
        "typescript": {"command": "typescript-language-server", "args": ["--stdio"]},
        "javascript": {"command": "typescript-language-server", "args": ["--stdio"]}
    })
    with open(path, "w") as f:
        json.dump(s, f, indent=2, ensure_ascii=False)
        f.write("\n")
PYEOF
}

case "$ENV_TYPE" in
  python)
    _inject_lsp_python && success "LSP 설정 완료 (Python: pylsp)"
    ;;
  js)
    _inject_lsp_js && success "LSP 설정 완료 (JS/TS: typescript-language-server)"
    ;;
  auto)
    case "$STACK" in
      django|fastapi|flask)
        _inject_lsp_python && success "LSP 설정 완료 (Python: pylsp)"
        ;;
      nextjs|nestjs|express|node)
        _inject_lsp_js && success "LSP 설정 완료 (JS/TS: typescript-language-server)"
        ;;
      *)
        warn "LSP: 스택을 인식하지 못해 LSP 설정을 건너뜁니다 (수동으로 settings.json에 추가하세요)"
        ;;
    esac
    ;;
esac

# Atlassian MCP 설정 주입
if [ "$USE_ATLASSIAN_MCP" = "yes" ]; then
  if ! command -v python3 &>/dev/null; then
    warn "python3가 설치되어 있지 않아 Atlassian MCP 설정을 주입할 수 없습니다. 수동으로 설정해 주세요."
  else
    SETTINGS_FILE="$TARGET_DIR/.claude/settings.json"
    python3 - "$SETTINGS_FILE" <<'PYEOF'
import json, sys

path = sys.argv[1]
try:
    with open(path) as f:
        cfg = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    cfg = {}

cfg.setdefault("mcpServers", {})["atlassian"] = {
    "command": "npx",
    "args": ["-y", "@atlassian/mcp-atlassian"],
    "env": {
        "ATLASSIAN_SITE_URL": "",
        "ATLASSIAN_USER_EMAIL": "",
        "ATLASSIAN_API_TOKEN": ""
    }
}

with open(path, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
    f.write("\n")
PYEOF
    success "Atlassian MCP 설정 주입 완료"
  fi
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

# DOMAIN.md 복사 (JS: 정적 템플릿 / Python: domain-init.sh가 동적 생성)
IS_JS_ENV() { [ "$ENV_TYPE" = "js" ] || { [ "$ENV_TYPE" = "auto" ] && [[ "$STACK" =~ ^(nextjs|nestjs|express|node)$ ]]; }; }
IS_PYTHON_ENV() { [ "$ENV_TYPE" = "python" ] || { [ "$ENV_TYPE" = "auto" ] && [[ "$STACK" =~ ^(django|fastapi|flask)$ ]]; }; }
if IS_JS_ENV; then
  if [ ! -f "$TARGET_DIR/DOMAIN.md" ]; then
    cp "$TEMPLATE_DIR/js/DOMAIN.md" "$TARGET_DIR/DOMAIN.md"
    success "DOMAIN.md 템플릿 생성 완료 (JS용 — TODO 항목 채우기 필요)"
  else
    warn "DOMAIN.md 이미 존재, 건너뜀"
  fi
fi

# ── .gitignore 업데이트 ────────────────────────────────
GITIGNORE="$TARGET_DIR/.gitignore"
if IS_JS_ENV && [ -f "$TEMPLATE_DIR/js/.gitignore.append" ]; then
  APPEND_FILE="$TEMPLATE_DIR/js/.gitignore.append"
else
  APPEND_FILE="$TEMPLATE_DIR/django/.gitignore.append"
fi

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
# ENV_TYPE 우선, 그 외에는 스택 자동 감지 (java/spring 계열은 생략)
case "$ENV_TYPE" in
  python)
    PRECOMMIT_YAML="$TEMPLATE_DIR/django/.pre-commit-config.yaml"
    ;;
  js)
    PRECOMMIT_YAML="$TEMPLATE_DIR/js/.pre-commit-config.yaml"
    ;;
  *)
    case "$STACK" in
      nextjs|nestjs|express|node)
        PRECOMMIT_YAML="$TEMPLATE_DIR/js/.pre-commit-config.yaml"
        ;;
      django|fastapi|flask)
        PRECOMMIT_YAML="$TEMPLATE_DIR/django/.pre-commit-config.yaml"
        ;;
      *)
        PRECOMMIT_YAML=""
        ;;
    esac
    ;;
esac

if [ -n "$PRECOMMIT_YAML" ] && [ -f "$PRECOMMIT_YAML" ]; then
  if [ ! -f "$TARGET_DIR/.pre-commit-config.yaml" ]; then
    cp "$PRECOMMIT_YAML" "$TARGET_DIR/.pre-commit-config.yaml"
    success ".pre-commit-config.yaml 생성 완료"
  else
    warn ".pre-commit-config.yaml 이미 존재, 건너뜀"
  fi

  # pyproject.toml — ruff 설정 (Python 스택만, 없을 때만)
  if [ "$PRECOMMIT_YAML" = "$TEMPLATE_DIR/django/.pre-commit-config.yaml" ]; then
    if [ ! -f "$TARGET_DIR/pyproject.toml" ]; then
      sed "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$TEMPLATE_DIR/django/pyproject.toml" > "$TARGET_DIR/pyproject.toml"
      success "pyproject.toml 생성 완료 (ruff: E/F/I 규칙, black-compatible)"
    else
      warn "pyproject.toml 이미 존재, 건너뜀"
    fi
  fi

  # pre-commit 설치 확인 및 자동 설치 (brew → pipx → pip 순으로 시도)
  if ! command -v pre-commit &>/dev/null; then
    info "pre-commit 미설치 — 설치 시도 중..."
    if command -v brew &>/dev/null; then
      brew install pre-commit -q && success "pre-commit 설치 완료 (brew)"
    elif command -v pipx &>/dev/null; then
      pipx install pre-commit && success "pre-commit 설치 완료 (pipx)"
    elif command -v pip &>/dev/null; then
      pip install pre-commit -q && success "pre-commit 설치 완료 (pip)"
    elif command -v pip3 &>/dev/null; then
      pip3 install pre-commit -q && success "pre-commit 설치 완료 (pip3)"
    else
      warn "pre-commit 자동 설치 실패. 수동으로 설치 후 'pre-commit install' 실행하세요:"
      warn "  brew install pre-commit  또는  pipx install pre-commit"
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

# ── JS 환경 전용 파일 오버라이드 ───────────────────────
# migration.sh가 Django 기반으로 변환한 내용을 JS 전용 버전으로 덮어쓴다
if IS_JS_ENV; then
  info "JS/TS 환경 전용 파일 적용 중..."

  # agents 오버라이드 (Django → JS/TS 레이어 패턴)
  if [ -d "$TEMPLATE_DIR/js/.claude/agents" ]; then
    cp -rf "$TEMPLATE_DIR/js/.claude/agents/"* "$TARGET_DIR/.claude/agents/" 2>/dev/null || true
    success "JS agents 적용 완료"
  fi

  # hooks 오버라이드 (models.py 감지 → schema/entity 파일 감지)
  if [ -d "$TEMPLATE_DIR/js/.claude/hooks" ]; then
    cp -f "$TEMPLATE_DIR/js/.claude/hooks/"* "$TARGET_DIR/.claude/hooks/" 2>/dev/null || true
    chmod +x "$TARGET_DIR/.claude/hooks/"*.sh 2>/dev/null || true
    success "JS hooks 적용 완료"
  fi

  # rules 오버라이드 (Django 아키텍처 규칙 → JS/TS 아키텍처 규칙)
  if [ -d "$TEMPLATE_DIR/js/.claude/rules" ]; then
    mkdir -p "$TARGET_DIR/.claude/rules"
    cp -f "$TEMPLATE_DIR/js/.claude/rules/"* "$TARGET_DIR/.claude/rules/" 2>/dev/null || true
    success "JS rules 적용 완료"
  fi

  # GitHub Actions 오버라이드 (pytest → npm test)
  if [ -f "$TEMPLATE_DIR/js/.github/workflows/pr-test.yml" ]; then
    cp -f "$TEMPLATE_DIR/js/.github/workflows/pr-test.yml" "$TARGET_DIR/.github/workflows/pr-test.yml"
    success "JS pr-test.yml 적용 완료"
  fi

  # CLAUDE.md 오버라이드 (Django 아키텍처 규칙 → JS/TS 아키텍처 규칙)
  if [ -f "$TEMPLATE_DIR/js/CLAUDE.md" ]; then
    cp -f "$TEMPLATE_DIR/js/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
    success "JS CLAUDE.md 적용 완료"
  fi

  # pyproject.toml 제거 (Python 전용 — JS 프로젝트에 불필요)
  rm -f "$TARGET_DIR/pyproject.toml"
  success "pyproject.toml 제거 완료"

  # domain-sync.yml 오버라이드 (models.py → entity/schema 감지)
  if [ -f "$TEMPLATE_DIR/js/.github/workflows/domain-sync.yml" ]; then
    cp -f "$TEMPLATE_DIR/js/.github/workflows/domain-sync.yml" "$TARGET_DIR/.github/workflows/domain-sync.yml"
    success "JS domain-sync.yml 적용 완료"
  fi

  # pre-bash-guard.sh 오버라이드 (Django migrate 경고 제거)
  if [ -f "$TEMPLATE_DIR/js/.claude/hooks/pre-bash-guard.sh" ]; then
    cp -f "$TEMPLATE_DIR/js/.claude/hooks/pre-bash-guard.sh" "$TARGET_DIR/.claude/hooks/pre-bash-guard.sh"
    chmod +x "$TARGET_DIR/.claude/hooks/pre-bash-guard.sh"
    success "JS pre-bash-guard.sh 적용 완료"
  fi

  # .gemini/styleguide.md 오버라이드 (Django → TypeScript/JS)
  if [ -f "$TEMPLATE_DIR/js/.gemini/styleguide.md" ]; then
    mkdir -p "$TARGET_DIR/.gemini"
    cp -f "$TEMPLATE_DIR/js/.gemini/styleguide.md" "$TARGET_DIR/.gemini/styleguide.md"
    success "JS Gemini 스타일 가이드 적용 완료"
  fi

  # docs/DOC-SYNC-POLICY.md 오버라이드 (views.py → controller.ts 매핑)
  if [ -f "$TEMPLATE_DIR/js/docs/DOC-SYNC-POLICY.md" ]; then
    mkdir -p "$TARGET_DIR/docs"
    cp -f "$TEMPLATE_DIR/js/docs/DOC-SYNC-POLICY.md" "$TARGET_DIR/docs/DOC-SYNC-POLICY.md"
    success "JS DOC-SYNC-POLICY.md 적용 완료"
  fi
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

if ! IS_JS_ENV && [ -n "$EXISTING_MODELS" ]; then
  info "기존 Python 앱 감지 — DOMAIN.md 스켈레톤 생성 중..."
  bash "$SCRIPT_DIR/scripts/domain-init.sh" "$TARGET_DIR"

  # Claude Code로 스켈레톤을 실제 코드 내용으로 채운다
  bash "$SCRIPT_DIR/scripts/domain-fill.sh" "$TARGET_DIR"
elif IS_PYTHON_ENV; then
  # non-Django Python 프로젝트 — 기본 템플릿 복사 후 domain-fill로 채우기
  if [ ! -f "$TARGET_DIR/DOMAIN.md" ]; then
    sed "s|{project_name}|${PROJECT_NAME//&/\\&}|g" \
      "$TEMPLATE_DIR/django/DOMAIN.md" > "$TARGET_DIR/DOMAIN.md"
    success "DOMAIN.md 기본 템플릿 생성 완료"
  fi
  bash "$SCRIPT_DIR/scripts/domain-fill.sh" "$TARGET_DIR"
fi

fi # SKIP_FULL_INSTALL

# 전역 자기강화 루프(debrief-guardrails + session 훅)는 ~/.claude 전역의 weekly-retro
# 체계(debrief 누적 + /weekly-retro 승격 게이트 → rules/rules.yaml 규칙 레지스트리 →
# hooks/rules-dispatcher.py 가 PreToolUse 에서 차단·주입)로 대체되어 설치하지 않는다.
# 전역 체계는 ~/.claude 저장소가 전파한다. 여기서 규칙 파일·훅을 설치하면 이중 배달이 된다.

# ── 완료 메시지 ────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN} Harness Engineering 환경 셋업 완료! [$STACK]${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  생성된 파일:"
echo "  ├── CLAUDE.md"
echo "  ├── .gitignore"
echo "  ├── .pre-commit-config.yaml   (python: ruff / js: prettier+eslint)"
echo "  ├── pyproject.toml            (python only: ruff E/F/I + black-compatible format)"
echo "  ├── .claude/tasks/"
echo "  ├── .claude/decisions/"
echo "  ├── .claude/skills/          (explore/implement/debug/review/autopilot + orchestrator)"
echo "  ├── .claude/agents/          (analyst/architect/coder/tester/reviewer)"
echo "  ├── .claude/commands/        (/review, /workflows:gemini-review 슬래시 커맨드)"
echo "  ├── .claude/hooks/           (pre-bash-guard.sh — PreToolUse / domain-update-reminder.sh, insight-collector.sh, notification.sh — PostToolUse·Notification)"
echo "  ├── .claude/rules/           (architecture / testing / domain / agents / hooks — CLAUDE.md @imports)"
echo "  ├── .claude/settings.json"
echo "  ├── .gemini/                 (Gemini Code Assist 설정)"
echo "  ├── .github/                 (이슈 템플릿, PR 템플릿, 워크플로우)"
echo "  ├── docs/DOC-SYNC-POLICY.md  (문서 동기화 정책)"
  if IS_JS_ENV; then
    echo "  └── DOMAIN.md  (JS 템플릿 — TODO 항목 채우기 필요)"
  elif [ -n "$EXISTING_MODELS" ]; then
    echo "  └── DOMAIN.md + 앱별 DOMAIN.md  (기존 Python 프로젝트 — TODO 항목 채우기 필요)"
  elif IS_PYTHON_ENV; then
    echo "  └── DOMAIN.md  (Python 기본 템플릿 — TODO 항목 채우기 필요)"
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
echo "  claude-code-review · claude · pr-auto-fill · pr-test · post-merge-docs · domain-sync"
echo ""

RED='\033[0;31m'
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${RED}  ⚠  필수 설정 — 하지 않으면 Harness가 동작하지 않습니다${NC}"
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  GitHub 저장소 → Settings → Secrets and variables → Actions"
echo "  아래 시크릿을 추가하세요:"
echo ""
echo "  ┌─────────────────────────┬──────────────────────────────┐"
echo "  │ 시크릿 이름             │ 설명                         │"
echo "  ├─────────────────────────┼──────────────────────────────┤"
echo "  │ ANTHROPIC_API_KEY       │ Claude AI API 키             │"
echo "  │                         │ (domain-sync · claude-code-review · claude 워크플로우) │"
echo "  └─────────────────────────┴──────────────────────────────┘"
echo ""
echo "  ANTHROPIC_API_KEY 없이는:"
echo "  · PR 머지 후 DOMAIN.md 자동 갱신 불가 (domain-sync)"
echo "  · PR 자동 코드 리뷰 불가 (claude-code-review)"
echo "  · 이슈 자동 처리 불가 (claude)"
echo ""
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ "$USE_ATLASSIAN_MCP" = "yes" ]; then
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}  🔗 Atlassian MCP 연동 설정 필요${NC}"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "  .claude/settings.json → mcpServers.atlassian.env 에 아래 값을 채우세요:"
  echo ""
  echo "  ┌──────────────────────────┬──────────────────────────────────────┐"
  echo "  │ 환경 변수                │ 값                                   │"
  echo "  ├──────────────────────────┼──────────────────────────────────────┤"
  echo "  │ ATLASSIAN_SITE_URL       │ https://your-domain.atlassian.net    │"
  echo "  │ ATLASSIAN_USER_EMAIL     │ your-email@example.com               │"
  echo "  │ ATLASSIAN_API_TOKEN      │ Atlassian API 토큰                   │"
  echo "  └──────────────────────────┴──────────────────────────────────────┘"
  echo ""
  echo "  API 토큰 발급: https://id.atlassian.com/manage-profile/security/api-tokens"
  echo ""
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
fi

if IS_JS_ENV; then
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}  📝 DOMAIN.md 작성 가이드 (JS/TS 환경)${NC}"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "  DOMAIN.md 에 사용 중인 ORM/스키마 라이브러리의 도메인 지식을 채워두세요."
  echo "  AI 에이전트가 코드 작성 전 이 문서를 참조합니다."
  echo ""
  echo "  라이브러리별 스키마 위치 힌트:"
  echo "  · Prisma    → prisma/schema.prisma"
  echo "  · TypeORM   → src/**/*.entity.ts"
  echo "  · Mongoose  → src/**/*.schema.ts"
  echo "  · Drizzle   → src/db/schema.ts"
  echo ""
  echo "  자동화 힌트 (스크립트로 스켈레톤 생성하고 싶다면):"
  echo "  Django용 자동 생성 스크립트를 참고해 ORM에 맞게 응용하세요:"
  echo "  → $(dirname "$0")/scripts/domain-init.sh"
  echo ""
fi
