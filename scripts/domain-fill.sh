#!/bin/bash
# domain-fill.sh: Claude Code를 활용해 DOMAIN.md 스켈레톤을 실제 코드 내용으로 채운다
# 사용법: bash domain-fill.sh <TARGET_DIR>
#
# 동작: models.py를 가진 Django 앱마다 claude -p를 호출해
#       필드·관계·Choices를 DOMAIN.md에 자동 주입한다.

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

# ── 대상 앱 탐색 ────────────────────────────────────────
APPS=$(find "$TARGET_DIR" -name "models.py" \
  ! -path "*/migrations/*" \
  ! -path "*/.venv/*" \
  ! -path "*/venv/*" \
  ! -path "*/env/*" \
  ! -path "*/__pycache__/*" \
  ! -path "*/.git/*" \
  2>/dev/null)

if [ -z "$APPS" ]; then
  warn "models.py를 가진 Django 앱이 없습니다. 건너뜁니다."
  exit 0
fi

APP_COUNT=$(echo "$APPS" | wc -l | tr -d ' ')
info "Claude Code로 DOMAIN.md 자동 채우기 시작 (${APP_COUNT}개 앱)"
info "앱별로 Claude Code를 호출합니다. 잠시 기다려 주세요..."
echo ""

FAILED_APPS=""

while IFS= read -r models_file; do
  app_dir=$(dirname "$models_file")
  app_name=$(basename "$app_dir")
  domain_file="$app_dir/DOMAIN.md"

  if [ ! -f "$domain_file" ]; then
    warn "  $app_name/DOMAIN.md 없음 — 건너뜀 (domain-init.sh 먼저 실행하세요)"
    continue
  fi

  info "  → $app_name 분석 중..."

  PROMPT="You are filling in a DOMAIN.md skeleton for the Django app '${app_name}'.

Step 1: Read the file '${app_name}/models.py' carefully.
Step 2: Read the current '${app_name}/DOMAIN.md' to understand its structure.
Step 3: Fill in the following sections of '${app_name}/DOMAIN.md' using ONLY information found in models.py:

## 도메인 계층 구조
- Draw a text tree showing model hierarchy.
- Base models at the top, child models (FK targets, OneToOne, proxy) indented below.
- Format example:
  ParentModel
  ├── ChildModel (FK: parent)
  └── AnotherChild (OneToOne)

## 핵심 모델
- For EACH Model class, write a markdown table with columns: | 필드 | 타입 | 설명 |
- Use the actual Django field type (CharField, IntegerField, ForeignKey(ModelName), etc.)
- For ForeignKey: write 'FK → ModelName'
- For choices field: note '→ 상태 코드 참조'
- Description: brief one-line description based on field name; leave as TODO if unclear

## 상태 코드 / Choices
- Find ALL Choices, TextChoices, IntegerChoices definitions in models.py
- For each, write: entity name, a table of (값, 의미, 전이 가능 상태)
- '전이 가능 상태' can be left as '—' unless obvious from code

## 주요 관계
- List FK / M2M / OneToOne relationships between models as bullet points

Rules:
- Extract ONLY from the actual code. Do not invent fields.
- For '역할', '비즈니스 규칙', '주요 흐름' — write 'TODO' if not clear from the code.
- Preserve the existing Markdown headings and structure of ${app_name}/DOMAIN.md.
- Only replace placeholder/TODO content with real extracted data.
- Write the result directly to '${app_name}/DOMAIN.md'."

  if (cd "$TARGET_DIR" && claude --dangerously-skip-permissions -p "$PROMPT" </dev/null 2>/dev/null); then
    success "  $app_name DOMAIN.md 채우기 완료"
  else
    warn "  $app_name 채우기 실패 — 수동으로 채우거나 재실행하세요"
    FAILED_APPS="$FAILED_APPS $app_name"
  fi

  echo ""
done < <(find "$TARGET_DIR" -name "models.py" \
  ! -path "*/migrations/*" \
  ! -path "*/.venv/*" \
  ! -path "*/venv/*" \
  ! -path "*/env/*" \
  ! -path "*/__pycache__/*" \
  ! -path "*/.git/*" \
  2>/dev/null)

# ── 완료 요약 ────────────────────────────────────────────
echo ""
if [ -z "$FAILED_APPS" ]; then
  success "모든 앱 DOMAIN.md 자동 채우기 완료"
else
  warn "일부 앱 실패:$FAILED_APPS"
  warn "재실행: bash ~/harness-init/scripts/domain-fill.sh"
fi
