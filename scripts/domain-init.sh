#!/bin/bash
# scripts/domain-init.sh
# 기존 Django 프로젝트의 각 앱 디렉토리에 DOMAIN.md 스켈레톤을 생성하고
# 루트 DOMAIN.md에 앱별 참조 인덱스를 구성한다.
#
# 사용법: bash scripts/domain-init.sh [target_dir]

set -e

TARGET_DIR="${1:-$PWD}"
TODAY=$(date +%Y-%m-%d)
PROJECT_NAME=$(basename "$TARGET_DIR")

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[domain-init]${NC} $1"; }
success() { echo -e "${GREEN}[domain-init]${NC} ✓ $1"; }
warn()    { echo -e "${YELLOW}[domain-init]${NC} ⚠ $1"; }

# ── 상대 경로 (macOS/Linux 공용) ───────────────────────
rel_path() {
  python3 -c "import os; print(os.path.relpath('$1', '$TARGET_DIR'))"
}

# ── Django 앱 디렉토리 탐지 ─────────────────────────────
find_django_apps() {
  find "$TARGET_DIR" -name "models.py" \
    ! -path "*/migrations/*" \
    ! -path "*/.venv/*" \
    ! -path "*/venv/*" \
    ! -path "*/env/*" \
    ! -path "*/node_modules/*" \
    ! -path "*/__pycache__/*" \
    ! -path "*/.git/*" \
    ! -path "*/.worktrees/*" \
    2>/dev/null \
  | xargs -I{} dirname {} \
  | sort -u
}

# ── models.py 에서 모델 클래스명 추출 ──────────────────
extract_models() {
  local models_file="$1/models.py"
  [ -f "$models_file" ] || return
  grep -E "^class [A-Z][A-Za-z]+" "$models_file" \
    | sed 's/class \([A-Za-z]*\).*/\1/' \
    | head -20
}

# ── 앱별 DOMAIN.md 스켈레톤 생성 ───────────────────────
generate_app_domain() {
  local app_dir="$1"
  local app_name
  app_name=$(basename "$app_dir")
  local domain_file="$app_dir/DOMAIN.md"

  if [ -f "$domain_file" ]; then
    warn "${app_name}/DOMAIN.md 이미 존재, 건너뜀"
    return
  fi

  # 모델 클래스명 추출
  local models_list
  models_list=$(extract_models "$app_dir")

  # 모델 트리 시작점 (첫 번째 모델)
  local first_model=""
  local tree_body=""
  while IFS= read -r model; do
    [ -z "$model" ] && continue
    if [ -z "$first_model" ]; then
      first_model="$model"
    else
      tree_body="${tree_body}├── ${model}
"
    fi
  done <<< "$models_list"

  # 핵심 모델 섹션 생성
  local model_sections=""
  while IFS= read -r model; do
    [ -z "$model" ] && continue
    model_sections="${model_sections}
### ${model} (\`${app_name}/models.py:${model}\`)

- 설명: <!-- TODO: 모델 설명 -->
- 연결: <!-- TODO: FK/O2O 관계 -->
- 주요 필드:
  - <!-- TODO: 필드 목록 -->
- 메서드:
  - <!-- TODO: 주요 메서드 -->
"
  done <<< "$models_list"

  {
    echo "# ${app_name} 도메인"
    echo ""
    echo "> 최종 업데이트: ${TODAY} | 코드 위치: \`${app_name}/models.py\`, \`${app_name}/services.py\`, \`${app_name}/views.py\`"
    echo ""
    echo "<!-- TODO: 이 도메인의 한 줄 설명 -->"
    echo ""
    echo "## 도메인 계층 구조"
    echo ""
    echo '```'
    if [ -n "$first_model" ]; then
      echo "${first_model}"
      [ -n "$tree_body" ] && printf "%s" "$tree_body"
    else
      echo "<!-- TODO: 모델 계층 구조 트리 -->"
    fi
    echo '```'
    echo ""
    echo "## 핵심 모델"
    if [ -n "$model_sections" ]; then
      printf "%s" "$model_sections"
    else
      echo ""
      echo "<!-- TODO: 핵심 모델 상세 -->"
      echo ""
    fi
    echo ""
    echo "## 상태 코드 / Choices"
    echo ""
    echo "<!-- TODO: 모델별 choices 정리 -->"
    echo ""
    echo "| 상태 | 코드 | 설명 |"
    echo "|-----|------|------|"
    echo "| <!-- TODO --> | \`\` | |"
    echo ""
    echo "## 주요 흐름"
    echo ""
    echo '```'
    echo "<!-- TODO: 핵심 비즈니스 플로우 다이어그램 -->"
    echo '```'
    echo ""
    echo "## 변경 이력"
    echo ""
    echo "| 날짜 | 변경 내용 |"
    echo "|-----|----------|"
    echo "| ${TODAY} | DOMAIN.md 스켈레톤 초기 생성 |"
  } > "$domain_file"

  success "${app_name}/DOMAIN.md 생성"
}

# ── 루트 DOMAIN.md 생성 또는 인덱스 섹션 추가 ──────────
generate_root_domain() {
  local root_file="$TARGET_DIR/DOMAIN.md"
  local exists=false
  [ -f "$root_file" ] && exists=true

  # 인덱스 테이블 행 생성
  local index_rows=""
  for app_dir in "$@"; do
    local app_name
    app_name=$(basename "$app_dir")
    local rel
    rel=$(rel_path "$app_dir")
    index_rows="${index_rows}| ${app_name} | [\`${rel}/DOMAIN.md\`](${rel}/DOMAIN.md) | <!-- TODO: 한 줄 설명 --> |
"
  done

  if $exists; then
    warn "루트 DOMAIN.md 이미 존재 — 앱 인덱스 섹션을 파일 끝에 추가합니다"
    {
      echo ""
      echo "---"
      echo ""
      echo "## 앱별 DOMAIN.md (domain-init.sh 자동 생성)"
      echo ""
      echo "> 새 앱이 추가되면 이 테이블에 행을 추가하세요."
      echo ""
      echo "| 도메인 | 파일 위치 | 설명 |"
      echo "|-------|----------|------|"
      printf "%s" "$index_rows"
    } >> "$root_file"
    success "루트 DOMAIN.md 업데이트 (인덱스 추가)"
    return
  fi

  {
    echo "# DOMAIN.md - ${PROJECT_NAME} 도메인 지식 사전"
    echo ""
    echo "> 최종 업데이트: ${TODAY} | AI LLM이 이 프로젝트의 도메인 지식을 빠르게 파악하기 위한 문서"
    echo ""
    echo "## 업데이트 정책"
    echo ""
    echo "이 파일과 각 앱의 DOMAIN.md는 **코드 변경과 함께** 항상 최신 상태를 유지해야 합니다."
    echo ""
    echo "### 업데이트 트리거"
    echo "- 새 모델 추가 또는 필드 변경 시 → 해당 앱 DOMAIN.md 업데이트"
    echo "- 새로운 비즈니스 로직 또는 status / choices 추가 시"
    echo "- 도메인 용어 정의 추가/수정 시"
    echo "- 앱 신규 생성 시 → 이 파일 인덱스 테이블에 행 추가"
    echo ""
    echo "### 에이전트별 책임"
    echo "- **analyst**: 티켓 분석 시 관련 앱 DOMAIN.md를 \`필수\` 선행 참조"
    echo "- **coder**: 코드 변경 후 해당 앱 DOMAIN.md 변경 이력 업데이트"
    echo "- **reviewer**: 코드 리뷰 시 DOMAIN.md 누락/오래된 내용 경고"
    echo ""
    echo "---"
    echo ""
    echo "## 도메인 문서 구조"
    echo ""
    echo "도메인 지식은 **앱별로 분리**되어 관리됩니다. 상세 내용은 각 앱의 DOMAIN.md를 참조하세요."
    echo ""
    echo "| 도메인 | 파일 위치 | 설명 |"
    echo "|-------|----------|------|"
    printf "%s" "$index_rows"
    echo ""
    echo "---"
    echo ""
    echo "## Quick Reference (빠른 검색용)"
    echo ""
    echo "<!-- TODO: 프로젝트 주요 용어를 아래 테이블에 정리하세요 -->"
    echo ""
    echo "| 용어 | 영문/코드 | 도메인 | 바로가기 |"
    echo "|-----|----------|-------|---------|"
    echo "| <!-- TODO --> | | | |"
    echo ""
    echo "---"
    echo ""
    echo "## 슬랭 / 내부 용어"
    echo ""
    echo "<!-- TODO: 팀 내부에서 쓰는 비공식 용어, 줄임말, 별칭 등을 정리하세요 -->"
    echo ""
    echo "| 슬랭 | 정식명칭 | 의미 | 관련 코드 |"
    echo "|-----|---------|-----|----------|"
    echo "| <!-- TODO --> | | | \`\` |"
    echo ""
    echo "---"
    echo ""
    echo "## 핵심 관계 다이어그램"
    echo ""
    echo "<!-- TODO: 도메인 간 주요 FK/O2O 관계를 다이어그램으로 표현하세요 -->"
    echo ""
    echo '```'
    echo "<!-- 예:"
    echo "User"
    echo "├── 1:1 → Profile"
    echo "├── 1:N → Order"
    echo "└── 1:N → ..."
    echo "-->"
    echo '```'
    echo ""
    echo "---"
    echo ""
    echo "## 변경 이력"
    echo ""
    echo "| 날짜 | 변경 내용 |"
    echo "|-----|----------|"
    echo "| ${TODAY} | DOMAIN.md 초기 생성 (domain-init.sh) |"
  } > "$root_file"

  success "루트 DOMAIN.md 생성"
}

# ── 메인 ───────────────────────────────────────────────
info "Django 앱 탐색 중... ($TARGET_DIR)"

APP_DIRS=()
while IFS= read -r app_dir; do
  [ -n "$app_dir" ] && APP_DIRS+=("$app_dir")
done < <(find_django_apps)

if [ ${#APP_DIRS[@]} -eq 0 ]; then
  warn "Django 앱을 찾지 못했습니다 (models.py 없음). 건너뜀"
  exit 0
fi

info "${#APP_DIRS[@]}개 앱 발견"

for app_dir in "${APP_DIRS[@]}"; do
  generate_app_domain "$app_dir"
done

generate_root_domain "${APP_DIRS[@]}"

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN} DOMAIN.md 스켈레톤 생성 완료${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  다음 작업 (TODO 항목 채우기):"
echo "  ├── 각 앱 DOMAIN.md — 모델 설명, FK 관계, choices"
echo "  ├── 루트 DOMAIN.md  — Quick Reference 테이블"
echo "  └── 루트 DOMAIN.md  — 슬랭/내부 용어 목록"
echo ""
