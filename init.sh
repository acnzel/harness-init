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
RED='\033[0;31m'
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

  # 최소 하네스도 정식 설치다. 여기에 버전이 안 남으면 "이 레포에 무엇이 깔렸나"를
  # 물었을 때 답이 없다.
  if [ -f "$SCRIPT_DIR/VERSION" ]; then
    printf '%s\n' "$(cat "$SCRIPT_DIR/VERSION")" > "$TARGET_DIR/.claude/harness-version"
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
#
# 하네스 소유 훅은 -n 이 아니라 **덮어쓴다**. 도메인 지식 도구와 같은 이유다:
# 훅이 조용히 고장나면 아무도 모른 채 "게이트가 걸리겠지"라고 믿고 작업한다.
# 실제로 pre-bash-guard.sh 는 존재하지 않는 $TOOL_INPUT 을 읽어 한 번도 발화하지
# 않았는데, -n 때문에 재실행해도 고쳐진 버전이 전파되지 않았다 (2026-08-03).
# 사용자가 추가한 훅(아래 목록 밖의 .sh)은 -n 이 보존한다.
if [ -d "$TEMPLATE_DIR/django/.claude/hooks" ]; then
  mkdir -p "$TARGET_DIR/.claude/hooks"
  cp -rn "$TEMPLATE_DIR/django/.claude/hooks/"* "$TARGET_DIR/.claude/hooks/" 2>/dev/null || true
  for _owned in _hook-input.sh gate-selftest.sh pre-bash-guard.sh post-bash-notice.sh \
                domain-guard.sh session-knowledge.sh insight-collector.sh notification.sh; do
    [ -f "$TEMPLATE_DIR/django/.claude/hooks/$_owned" ] && \
      cp -f "$TEMPLATE_DIR/django/.claude/hooks/$_owned" "$TARGET_DIR/.claude/hooks/$_owned" 2>/dev/null || true
  done
  chmod +x "$TARGET_DIR/.claude/hooks/"*.sh 2>/dev/null || true
  success "hooks 설치 완료 (하네스 소유 훅은 최신으로 갱신)"
fi

# rules 복사 (CLAUDE.md @imports 참조 대상)
if [ -d "$TEMPLATE_DIR/django/.claude/rules" ]; then
  mkdir -p "$TARGET_DIR/.claude/rules"
  cp -rn "$TEMPLATE_DIR/django/.claude/rules/"* "$TARGET_DIR/.claude/rules/" 2>/dev/null || true
  success "rules 설치 완료"
fi

# 도메인 지식 도구 복사 (.claude/scripts/)
# 다른 템플릿과 달리 -n 이 아니라 덮어쓴다. 이 셋은 사용자가 편집하는 설정이 아니라
# 훅·pre-commit·에이전트가 함께 호출하는 하네스 소유 코드라, 버전이 어긋나면
# 게이트가 조용히 오작동한다. 재실행 시 항상 최신으로 맞춘다.
mkdir -p "$TARGET_DIR/.claude/scripts"
cp "$SCRIPT_DIR/scripts/atomic_write.py" \
   "$SCRIPT_DIR/scripts/domain-extract.py" \
   "$SCRIPT_DIR/scripts/domain-gate.py" \
   "$SCRIPT_DIR/scripts/domain-freshness.py" \
   "$SCRIPT_DIR/scripts/hook-io.py" \
   "$SCRIPT_DIR/scripts/gate-runner.py" \
   "$SCRIPT_DIR/scripts/render-agents.py" \
   "$SCRIPT_DIR/scripts/pr-body.py" \
   "$SCRIPT_DIR/scripts/commit-msg.py" \
   "$TARGET_DIR/.claude/scripts/" 2>/dev/null || true
chmod +x "$TARGET_DIR/.claude/scripts/"*.py 2>/dev/null || true

# 복사가 실패하면 기존 설치가 낡은 판정기를 그대로 쓰면서 설치는 성공으로 보고된다.
# 이 하네스가 없애려는 실패 유형이 정확히 그것이라, 도착했는지 확인하고 알린다.
_missing_tools=""
for _t in atomic_write domain-extract domain-gate domain-freshness hook-io gate-runner render-agents pr-body commit-msg; do
  [ -f "$TARGET_DIR/.claude/scripts/$_t.py" ] || _missing_tools="$_missing_tools $_t.py"
done
if [ -n "$_missing_tools" ]; then
  warn "하네스 소유 도구 복사 실패:$_missing_tools"
  warn "  해당 게이트는 동작하지 않습니다. 권한·디스크 상태를 확인하고 재실행하세요."
else
  success "하네스 소유 도구 설치 완료 (.claude/scripts/ — atomic_write/domain-extract/domain-gate/domain-freshness/hook-io/gate-runner/render-agents/pr-body/commit-msg)"
fi

# 게이트 선언은 사용자 소유다. 프로젝트마다 검사 목록이 다르고, 한번 손대면
# 그게 그 팀의 것이 된다. 러너(위)는 덮어쓰고 선언(아래)은 보존한다.
cp -n "$TEMPLATE_DIR/django/.claude/gates.json" \
      "$TARGET_DIR/.claude/gates.json" 2>/dev/null || true

# AGENTS.md — 플랫폼 중립 정본. 사용자가 절대 규칙을 채워 넣는 문서라 보존한다.
# 이미 팀이 쓴 AGENTS.md 가 있으면 그대로 두고, 마커가 없으면 렌더러가 건너뛴다.
cp -n "$TEMPLATE_DIR/django/AGENTS.md" "$TARGET_DIR/AGENTS.md" 2>/dev/null || true

# 기존 설치는 CLAUDE.md(사용자 소유)에 작업 원칙이 남아 있고, 이제 AGENTS.md 에도
# 같은 내용이 생긴다. 조용히 지우면 사용자가 고친 문장까지 날아가므로 알리기만 한다.
if [ -f "$TARGET_DIR/CLAUDE.md" ] && grep -q '^### 1\. 코딩 전에 생각하라' "$TARGET_DIR/CLAUDE.md" 2>/dev/null; then
  warn "CLAUDE.md 의 '코딩 원칙' 이 AGENTS.md 와 중복됩니다."
  warn "  작업 원칙의 정본은 이제 AGENTS.md 입니다. CLAUDE.md 쪽 섹션을 지우세요."
  warn "  (같은 규칙이 두 곳에 있으면 한쪽을 고칠 때 다른 쪽이 조용히 낡습니다.)"
fi

PROJECT_NAME=$(basename "$TARGET_DIR")

# settings.json (없을 때만 생성)
if [ ! -f "$TARGET_DIR/.claude/settings.json" ]; then
  cp "$TEMPLATE_DIR/django/.claude/settings.json" "$TARGET_DIR/.claude/settings.json"
  success "settings.json 생성 완료"
else
  warn ".claude/settings.json 이미 존재, 건너뜀"
fi

# ── 게이트 자가진단 주입 ─────────────────────────────────
# settings.json 은 '없을 때만' 생성되므로, 기존 설치는 훅 파일이 갱신돼도
# 자가진단이 등록되지 않는다. 여기서 멱등 병합한다 (CLAUDE.md 병합 규칙: python3만).
# 함께 하는 일: 죽은 인라인 $TOOL_INPUT 훅을 파일 훅으로 교체 (마이그레이션).
_inject_gate_selftest() {
  python3 - "$TARGET_DIR/.claude/settings.json" << 'PYEOF'
import json, sys

path = sys.argv[1]
try:
    with open(path) as f:
        settings = json.load(f)
except (OSError, ValueError):
    sys.exit(0)

SELFTEST = ".claude/hooks/gate-selftest.sh"
NOTICE = ".claude/hooks/post-bash-notice.sh"
changed = False
hooks = settings.setdefault("hooks", {})


def each_hook():
    for groups in hooks.values():
        if not isinstance(groups, list):
            continue
        for group in groups:
            if not isinstance(group, dict):
                continue
            for hook in group.get("hooks", []):
                if isinstance(hook, dict):
                    yield hook


# 1) SessionStart 최상단에 자가진단 등록. 게이트가 죽었다면 다른 무엇보다 먼저 알아야 한다.
if not any(h.get("command") == SELFTEST for h in each_hook()):
    hooks.setdefault("SessionStart", []).insert(
        0, {"hooks": [{"type": "command", "command": SELFTEST, "timeout": 15}]}
    )
    changed = True

# 2) 존재하지 않는 $TOOL_INPUT 을 읽던 인라인 훅을 파일 훅으로 교체한다.
#    'gh pr create' 를 함께 확인해 하네스가 심은 그 훅만 건드린다 —
#    사용자가 직접 쓴 인라인 훅을 우리 것으로 덮어쓰지 않기 위해서다.
for hook in each_hook():
    command = str(hook.get("command", ""))
    if "$TOOL_INPUT" in command and "gh pr create" in command:
        hook["command"] = NOTICE
        changed = True

if changed:
    with open(path, "w") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("changed")
PYEOF
}

if [ -f "$TARGET_DIR/.claude/settings.json" ]; then
  if [ -n "$(_inject_gate_selftest)" ]; then
    success "게이트 자가진단 등록 완료 (SessionStart — 훅이 살아있는지 매 세션 실측)"
  fi
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
  HARNESS_OWNS_PYPROJECT=false
  if [ "$PRECOMMIT_YAML" = "$TEMPLATE_DIR/django/.pre-commit-config.yaml" ]; then
    if [ ! -f "$TARGET_DIR/pyproject.toml" ]; then
      sed "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$TEMPLATE_DIR/django/pyproject.toml" > "$TARGET_DIR/pyproject.toml"
      HARNESS_OWNS_PYPROJECT=true
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

      # 기존 설치는 .pre-commit-config.yaml 이 이미 있어 템플릿이 복사되지 않는다.
      # 그러면 pre-push 통합 게이트가 영영 안 들어간다. 없을 때만 덧붙이고,
      # 붙인 결과가 유효하지 않으면 되돌린다 (사용자 설정을 깨뜨리지 않는다).
      PC_CONFIG="$TARGET_DIR/.pre-commit-config.yaml"
      if [ -f "$PC_CONFIG" ] && ! grep -q 'gate-runner-pre-push' "$PC_CONFIG"; then
        cp "$PC_CONFIG" "$PC_CONFIG.harness-bak"
        # 이 스크립트는 set -e 로 돈다. 아래 python 이 exit 1 을 내면 그대로 설치가
        # 중단되고, 정작 알리려던 경고도 못 나온 채 백업 파일만 남는다.
        # `|| _pc_inserted=$?` 로 감싸 종료 상태를 직접 받는다.
        _pc_inserted=0
        # EOF 에 덧붙이지 않고 `repos:` 바로 뒤에 끼운다. 파일 끝이 항상 repos
        # 리스트라는 보장이 없다 — `ci:` 같은 최상위 키가 뒤에 오면 덧붙인
        # 블록이 그 키 밑으로 들어가 YAML 이 깨진다 (실측으로 확인).
        # YAML 을 파싱해 재덤프하지 않는 이유는 주석이 전부 날아가기 때문이다.
        python3 - "$PC_CONFIG" <<'PYEOF' || _pc_inserted=$?
import sys

path = sys.argv[1]
lines = open(path, encoding="utf-8").read().splitlines(keepends=True)
block = """  # harness-init 추가 — 커밋 메시지에 브랜치의 티켓 번호 삽입
  - repo: local
    hooks:
      - id: commit-msg-ticket
        name: 커밋 메시지에 티켓 번호 삽입
        entry: python3 .claude/scripts/commit-msg.py
        language: system
        stages: [commit-msg]

  # harness-init 추가 — AGENTS.md 자동 구간 갱신
  # gates.json·settings.json 을 고치면 문서가 따라온다.
  - repo: local
    hooks:
      - id: render-agents-md
        name: AGENTS.md 자동 구간 갱신
        entry: python3 .claude/scripts/render-agents.py --repo .
        language: system
        pass_filenames: false
        files: '^\\.claude/(gates\\.json|settings\\.json)$|^AGENTS\\.md$'
        stages: [pre-commit]

  # harness-init 추가 — 통합 게이트 (push 직전)
  # 로컬과 CI 가 같은 러너·같은 .claude/gates.json 을 쓴다.
  - repo: local
    hooks:
      - id: gate-runner-pre-push
        name: 통합 게이트 (pre-push)
        entry: python3 .claude/scripts/gate-runner.py --stage pre-push
        language: system
        pass_filenames: false
        always_run: true
        stages: [pre-push]
        verbose: true

"""
# `repos:` 를 못 찾으면 아무것도 쓰지 않고 끝난다. 그 상태로 두면 원본이
# 그대로라 validate-config 가 통과하고, 호출부가 "추가했다"고 보고한다.
# 이 PR 이 없애려는 바로 그 거짓 성공이라, 삽입 여부를 종료 코드로 알린다.
for index, line in enumerate(lines):
    if line.rstrip() == "repos:":
        lines.insert(index + 1, block)
        open(path, "w", encoding="utf-8").writelines(lines)
        sys.exit(0)
sys.exit(1)
PYEOF
        # 삽입 자체가 안 됐으면 파일은 원본 그대로다. 그 상태로 validate-config 를
        # 돌리면 당연히 통과하고, 아무것도 안 했는데 "추가했다"고 보고하게 된다.
        # 인자 없는 validate-config 는 아무것도 검사하지 않고 0 을 돌려주므로
        # 파일명도 반드시 넘긴다 (이걸 빼서 깨진 YAML 을 통과시킨 적이 있다).
        if [ "$_pc_inserted" -ne 0 ]; then
          rm -f "$PC_CONFIG.harness-bak"
          warn "pre-commit 설정에서 'repos:' 줄을 찾지 못해 게이트를 넣지 못했습니다."
          warn "  (repos: [] 한 줄 형태이거나 뒤에 주석이 붙은 경우입니다.)"
          warn "  .pre-commit-config.yaml 의 repos 목록에 아래를 직접 추가하세요:"
          warn "    - repo: local"
          warn "      hooks:"
          warn "        - id: gate-runner-pre-push"
          warn "          entry: python3 .claude/scripts/gate-runner.py --stage pre-push"
          warn "          language: system"
          warn "          pass_filenames: false"
          warn "          always_run: true"
          warn "          stages: [pre-push]"
        elif (cd "$TARGET_DIR" && pre-commit validate-config .pre-commit-config.yaml >/dev/null 2>&1); then
          rm -f "$PC_CONFIG.harness-bak"
          success "pre-push 통합 게이트를 기존 .pre-commit-config.yaml 에 추가"
        else
          mv "$PC_CONFIG.harness-bak" "$PC_CONFIG"
          warn "pre-push 게이트 자동 추가 실패 — 설정을 되돌렸습니다."
          warn "  .pre-commit-config.yaml 에 아래를 직접 추가하세요:"
          warn "    - repo: local"
          warn "      hooks:"
          warn "        - id: gate-runner-pre-push"
          warn "          entry: python3 .claude/scripts/gate-runner.py --stage pre-push"
          warn "          language: system"
          warn "          pass_filenames: false"
          warn "          always_run: true"
          warn "          stages: [pre-push]"
        fi
      fi

      # push 직전 통합 게이트. 별도 hook-type 이라 이 줄이 없으면 pre-push 는
      # 설정에만 있고 실제로는 돌지 않는다 (조용히 없는 게이트가 된다).
      (cd "$TARGET_DIR" && pre-commit install --hook-type pre-push) \
        && success "pre-push 통합 게이트 등록 완료"
      # commit-msg 도 별도 hook-type 이다. 빼먹으면 설정에만 있고 돌지 않는다.
      (cd "$TARGET_DIR" && pre-commit install --hook-type commit-msg) \
        && success "commit-msg 티켓 삽입 등록 완료"
    fi
  else
    warn "git 저장소가 아닙니다. 'git init' 후 'pre-commit install' 수동 실행 필요"
  fi

  # ── lint baseline ──────────────────────────────────
  # 이미 개발이 진행된 레포에 ruff를 처음 켜면 레거시 위반이 쏟아져 모든 커밋이 막힌다.
  # 그러면 DOMAIN.md 갱신 커밋도 통과하지 못해 지식 루프 자체가 멈춘다.
  # 기존 위반을 규칙 단위로 유예해 루프를 살리고, 무엇을 유예했는지는 항상 노출한다.
  if [ "$HARNESS_OWNS_PYPROJECT" = true ]; then
    python3 "$SCRIPT_DIR/scripts/lint-baseline.py" "$TARGET_DIR" --apply
  elif [ -f "$TARGET_DIR/pyproject.toml" ]; then
    # 기존 pyproject.toml 은 남의 설정이다. 건드리지 않고 보고만 한다.
    python3 "$SCRIPT_DIR/scripts/lint-baseline.py" "$TARGET_DIR"
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

  # post-merge-docs.yml 오버라이드 (views.py 감지 → 라우트/컨트롤러 감지)
  # 이 복사가 없던 동안 JS 프로젝트에는 django 판이 깔려 views.py 를 찾고 있었다.
  # JS 레포에 그 파일이 있을 리 없으니 문서 갱신 이슈가 한 번도 생기지 않았다.
  # templates/js/ 에 파일만 두고 여기 배선을 빠뜨리면 그 템플릿은 죽은 파일이 된다.
  if [ -f "$TEMPLATE_DIR/js/.github/workflows/post-merge-docs.yml" ]; then
    cp -f "$TEMPLATE_DIR/js/.github/workflows/post-merge-docs.yml" "$TARGET_DIR/.github/workflows/post-merge-docs.yml"
    success "JS post-merge-docs.yml 적용 완료"
  fi

  # CLAUDE.md 오버라이드 (Django 아키텍처 규칙 → JS/TS 아키텍처 규칙)
  if [ -f "$TEMPLATE_DIR/js/CLAUDE.md" ]; then
    cp -f "$TEMPLATE_DIR/js/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
    success "JS CLAUDE.md 적용 완료"
  fi

  # pyproject.toml 제거 (Python 전용 — JS 프로젝트에 불필요)
  rm -f "$TARGET_DIR/pyproject.toml"
  success "pyproject.toml 제거 완료"

  # pre-bash-guard.sh 오버라이드 (Django migrate 경고 제거)
  # 게이트 선언도 스택별로 다르다. 사용자 소유라 이미 있으면 보존한다
  # (django 기본이 먼저 깔렸어도 사용자가 손댔으면 그게 우선이다).
  if [ -f "$TEMPLATE_DIR/js/.claude/gates.json" ]; then
    if [ ! -f "$TARGET_DIR/.claude/gates.json" ] || \
       grep -q '"lint (ruff)"' "$TARGET_DIR/.claude/gates.json" 2>/dev/null; then
      cp -f "$TEMPLATE_DIR/js/.claude/gates.json" "$TARGET_DIR/.claude/gates.json"
      success "gates.json JS 버전으로 교체"
    fi
  fi

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

# ── CI 게이트 연결 확인 ────────────────────────────────
# 워크플로는 사용자 소유라 cp -rn 이 기존 파일을 보존한다. 그래서 기존 설치는 로컬
# pre-push 만 러너를 쓰고 CI 는 옛 명령을 돌리는 상태가 된다. 그러면 AGENTS.md 가
# "CI 에서 이 게이트들이 돈다"고 적어놓고 실제로는 안 도는, 문서가 거짓말하는 상태가 된다.
# (stadiumDjango 실측에서 실제로 이 상태가 나왔다.)
# 어느 워크플로도 러너를 부르지 않으면 전용 파일을 하나 추가한다. 기존 워크플로는
# 건드리지 않는다 — 팀이 손댄 CI 를 말없이 바꾸는 건 더 나쁘다.
if [ -d "$TARGET_DIR/.github/workflows" ]; then
  if ! grep -rql 'gate-runner' "$TARGET_DIR/.github/workflows" 2>/dev/null; then
    _tpl="$TEMPLATE_DIR/django/.github/workflows/pr-test.yml"
    [ "$ENV_TYPE" = "js" ] && [ -f "$TEMPLATE_DIR/js/.github/workflows/pr-test.yml" ] \
      && _tpl="$TEMPLATE_DIR/js/.github/workflows/pr-test.yml"
    if [ -f "$_tpl" ]; then
      cp -f "$_tpl" "$TARGET_DIR/.github/workflows/harness-gates.yml"
      success "CI 통합 게이트 워크플로 추가 (.github/workflows/harness-gates.yml)"
      warn "  기존 워크플로는 그대로 뒀습니다. 테스트가 중복 실행되면"
      warn "  기존 것을 지우거나 gate-runner 호출로 바꾸세요."
    fi
  fi
fi

# ── 버전 기록 ──────────────────────────────────────────
# 이 하네스는 재실행으로 갱신된다. 대상 레포에서 "지금 깔린 게 어느 판인가"를
# 알 수 없으면, 버그를 고쳐도 그 레포가 갱신됐는지 확인할 방법이 없다.
if [ -f "$SCRIPT_DIR/VERSION" ]; then
  printf '%s\n' "$(cat "$SCRIPT_DIR/VERSION")" > "$TARGET_DIR/.claude/harness-version"
  success "하네스 버전 기록 ($(cat "$SCRIPT_DIR/VERSION"))"
fi

# ── AGENTS.md 자동 구간 렌더 ───────────────────────────
# gates.json 과 settings.json 이 모두 자리를 잡은 뒤에 돌려야 한다 (JS 오버라이드가
# gates.json 을 바꾸므로 그 뒤). 정본에서 생성하므로 문서가 설정과 어긋날 수 없다.
if [ -f "$TARGET_DIR/.claude/scripts/render-agents.py" ]; then
  python3 "$TARGET_DIR/.claude/scripts/render-agents.py" --repo "$TARGET_DIR" >/dev/null 2>&1 \
    && success "AGENTS.md 자동 구간 렌더 완료 (파이프라인·금지 명령)"
fi

# ── 구조 지식 계층 (codegraph) ─────────────────────────
# 선택 의존성. 없으면 안내만 하고 넘어간다 — 하네스는 codegraph 없이도 동작하고,
# 에이전트 rules에 Grep/Read 폴백 경로가 명시되어 있다.
bash "$SCRIPT_DIR/scripts/codegraph-setup.sh" "$TARGET_DIR"

# ── 의미 지식 계층 (DOMAIN.md) ─────────────────────────
# 구조(모델 목록·필드·관계·호출 경로)는 codegraph가 실시간으로 답하므로 문서화하지 않는다.
# 여기서는 codegraph가 못 보는 것 — Choices 값, db_table 매핑, 시그널 부수효과 — 만
# AST로 추출해 스켈레톤을 만든다.
EXISTING_MODELS=$(find "$TARGET_DIR" -name "models.py" \
  ! -path "*/migrations/*" \
  ! -path "*/.venv/*" \
  ! -path "*/venv/*" \
  ! -path "*/env/*" \
  ! -path "*/__pycache__/*" \
  ! -path "*/.git/*" \
  2>/dev/null | head -1)

if IS_PYTHON_ENV; then
  info "의미 지식 스켈레톤 생성 중..."
  bash "$SCRIPT_DIR/scripts/domain-init.sh" "$TARGET_DIR"

  # 앱을 찾지 못했으면(신규 프로젝트 등) 루트에 기본 템플릿만 둔다.
  if [ ! -f "$TARGET_DIR/DOMAIN.md" ]; then
    sed "s|{project_name}|${PROJECT_NAME//&/\\&}|g" \
      "$TEMPLATE_DIR/django/DOMAIN.md" > "$TARGET_DIR/DOMAIN.md"
    success "DOMAIN.md 기본 템플릿 생성 완료"
  fi

  # 시그널 핸들러 본문을 읽어 '무슨 부수효과를 내나' 열만 채운다 (Claude Code 필요).
  if [ -n "$EXISTING_MODELS" ]; then
    bash "$SCRIPT_DIR/scripts/domain-fill.sh" "$TARGET_DIR"
  fi
fi

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
echo "  ├── .claude/hooks/           (session-knowledge — SessionStart / pre-bash-guard — PreToolUse / domain-guard, insight-collector, notification)"
echo "  ├── .claude/scripts/         (domain-extract / domain-gate / domain-freshness — 의미 지식 도구)"
echo "  ├── .claude/rules/           (knowledge / architecture / testing / domain / agents / hooks — CLAUDE.md @imports)"
echo "  ├── .claude/settings.json"
echo "  ├── .gemini/                 (Gemini Code Assist 설정)"
echo "  ├── .github/                 (이슈 템플릿, PR 템플릿, 워크플로우)"
echo "  ├── docs/DOC-SYNC-POLICY.md  (문서 동기화 정책)"
  if IS_JS_ENV; then
    echo "  └── DOMAIN.md  (JS 템플릿 — 의미 TODO 채우기 필요)"
  elif [ -n "$EXISTING_MODELS" ]; then
    echo "  └── DOMAIN.md + 앱별 DOMAIN.md  (값·위치는 AST로 채워짐 / '의미' TODO는 사람 몫)"
  elif IS_PYTHON_ENV; then
    echo "  └── DOMAIN.md  (Python 기본 템플릿 — 의미 TODO 채우기 필요)"
  else
    echo "  └── (DOMAIN.md: 신규 프로젝트 — 코드 작성 후 domain-init.sh 실행)"
  fi
echo ""
echo -e "${BLUE}  지식 계층${NC}"
echo "  ├── 구조 (어디에 뭐가 있나·뭐가 뭘 부르나)  → codegraph, 실시간 인덱스"
echo "  └── 의미 (무슨 뜻인가·왜 이런가)            → DOMAIN.md, 게이트가 최신 강제"
echo ""
echo -e "${BLUE}  자동 가드레일 3단${NC}"
echo "  ├── 세션 시작   session-knowledge.sh  인덱스 동기화 + 낡은 문서 경고"
echo "  ├── 편집 직후   domain-guard.sh       의미 변화 감지 → 갱신 지시 (exit 2)"
echo "  └── 커밋 직전   domain-gate           문서 미갱신이면 커밋 차단"
echo ""
echo "  에이전트 팀 (orchestrator 스킬):"
echo "  analyst → architect → coder ⇄ tester → reviewer"
echo ""
echo "  슬래시 커맨드:"
echo "  /orchestrator   /review   /explore   /implement   /debug   /autopilot"
echo ""
echo "  GitHub Actions:"
echo "  claude-code-review · claude · pr-auto-fill · pr-test · post-merge-docs · domain-drift"
echo ""

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
echo "  │                         │ (claude-code-review · claude 워크플로우)      │"
echo "  └─────────────────────────┴──────────────────────────────┘"
echo ""
echo "  ANTHROPIC_API_KEY 없이는:"
echo "  · PR 자동 코드 리뷰 불가 (claude-code-review)"
echo "  · 이슈 자동 처리 불가 (claude)"
echo ""
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ── 설치 직후 게이트 실측 ──────────────────────────────
# 어떤 게이트가 이 레포에서 통과하는지는 **추측하면 안 된다**. 이미 개발이 진행된
# 레포에서는 repo-wide 검사가 첫날부터 빨간불일 수 있고, 그러면 첫 push 가 막힌 채
# 원인을 모른다. 실제로 stadiumDjango 에서 포맷 검사가 44/176 파일로 걸렸다.
#
# 여기서 한 번 돌려 현실을 보여준다. 자동으로 게이트를 끄지는 않는다 — 무엇을 포기할지는
# 사람이 정한다. 덤으로 pre-push 가 앞으로 얼마나 걸릴지도 이때 드러난다.
if [ -f "$TARGET_DIR/.claude/scripts/gate-runner.py" ] && [ -f "$TARGET_DIR/.claude/gates.json" ]; then
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  게이트 실측 — 지금 이 레포에서 무엇이 통과하는가${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  if (cd "$TARGET_DIR" && python3 .claude/scripts/gate-runner.py --stage pre-push --no-fail-fast); then
    echo ""
    success "현재 상태에서 pre-push 게이트가 통과합니다."
  else
    echo ""
    warn "위 게이트가 지금 실패합니다 — 이 상태로는 첫 push 가 막힙니다."
    warn "  둘 중 하나를 하세요:"
    warn "   1) 코드를 고쳐 통과시킨다"
    warn "   2) .claude/gates.json 에서 해당 게이트를 빼거나 조건을 좁힌다"
    warn "  게이트를 빼는 것은 후퇴가 아닙니다. 첫날부터 빨간불이면 팀이 하네스를"
    warn "  통째로 끄고, 그러면 나머지 게이트까지 같이 사라집니다."
  fi
  echo ""
fi

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
  echo "  → $SCRIPT_DIR/scripts/domain-init.sh"
  echo ""
fi

fi # SKIP_FULL_INSTALL — 스택 미감지 시에는 위 최소 하네스 안내로 끝낸다
