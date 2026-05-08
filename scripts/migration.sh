#!/bin/bash
# scripts/migration.sh
# 프로젝트의 기술 스택을 감지하고 django 기반 harness를 해당 스택으로 마이그레이션
# 사용법:
#   bash scripts/migration.sh [target_dir]          # 감지 + 마이그레이션
#   bash scripts/migration.sh --detect [target_dir] # 스택명만 출력 (init.sh용)

set -e

TARGET_DIR="${PWD}"
DETECT_ONLY=false

for arg in "$@"; do
  case "$arg" in
    --detect) DETECT_ONLY=true ;;
    *)        TARGET_DIR="$arg" ;;
  esac
done

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[migration]${NC} $1"; }
success() { echo -e "${GREEN}[migration]${NC} ✓ $1"; }
warn()    { echo -e "${YELLOW}[migration]${NC} ⚠ $1"; }

# ──────────────────────────────────────────────────────
# 1. 스택 감지
# ──────────────────────────────────────────────────────
detect_stack() {
  local dir="$1"

  # Django
  if [ -f "$dir/manage.py" ] || \
     { [ -f "$dir/requirements.txt" ] && grep -qi "django"  "$dir/requirements.txt" 2>/dev/null; } || \
     { [ -f "$dir/pyproject.toml" ]   && grep -qi "django"  "$dir/pyproject.toml"   2>/dev/null; }; then
    echo "django"; return
  fi

  # FastAPI
  if { [ -f "$dir/requirements.txt" ] && grep -qi "fastapi" "$dir/requirements.txt" 2>/dev/null; } || \
     { [ -f "$dir/pyproject.toml" ]   && grep -qi "fastapi" "$dir/pyproject.toml"   2>/dev/null; }; then
    echo "fastapi"; return
  fi

  # Flask
  if { [ -f "$dir/requirements.txt" ] && grep -qi "^flask"  "$dir/requirements.txt" 2>/dev/null; } || \
     { [ -f "$dir/pyproject.toml" ]   && grep -qi '"flask"' "$dir/pyproject.toml"   2>/dev/null; }; then
    echo "flask"; return
  fi

  # NestJS (Next.js보다 먼저)
  if [ -f "$dir/package.json" ] && grep -qi '"@nestjs/core"' "$dir/package.json" 2>/dev/null; then
    echo "nestjs"; return
  fi

  # Next.js
  if [ -f "$dir/package.json" ] && grep -qi '"next"' "$dir/package.json" 2>/dev/null; then
    echo "nextjs"; return
  fi

  # Express
  if [ -f "$dir/package.json" ] && grep -qi '"express"' "$dir/package.json" 2>/dev/null; then
    echo "express"; return
  fi

  # Generic Node
  if [ -f "$dir/package.json" ]; then
    echo "node"; return
  fi

  # Rails
  if [ -f "$dir/Gemfile" ] && grep -qi "rails" "$dir/Gemfile" 2>/dev/null; then
    echo "rails"; return
  fi

  # Spring Boot
  if { [ -f "$dir/pom.xml" ]         && grep -qi "spring-boot" "$dir/pom.xml"          2>/dev/null; } || \
     { [ -f "$dir/build.gradle" ]     && grep -qi "spring-boot" "$dir/build.gradle"      2>/dev/null; } || \
     { [ -f "$dir/build.gradle.kts" ] && grep -qi "spring-boot" "$dir/build.gradle.kts"  2>/dev/null; }; then
    echo "springboot"; return
  fi

  echo "unknown"
}

# ──────────────────────────────────────────────────────
# 2. 스택별 설정
# ──────────────────────────────────────────────────────
configure_stack() {
  case "$1" in
    fastapi)
      STACK_LABEL="FastAPI";         LANG="Python"
      LAYER_PATTERN="Routers → Services → Repositories"; LAYER_TOP="Routers"
      TEST_TOOL="pytest";            TEST_CMD="pytest"
      FACTORY_DESC="factoryboy 기반 Factory"
      ;;
    flask)
      STACK_LABEL="Flask";           LANG="Python"
      LAYER_PATTERN="Views → Services → Repositories";   LAYER_TOP="Views"
      TEST_TOOL="pytest";            TEST_CMD="pytest"
      FACTORY_DESC="factoryboy 기반 Factory"
      ;;
    express)
      STACK_LABEL="Express.js";      LANG="TypeScript"
      LAYER_PATTERN="Controllers → Services → Repositories"; LAYER_TOP="Controllers"
      TEST_TOOL="Jest";              TEST_CMD="npm test"
      FACTORY_DESC="@faker-js/faker 기반 Factory"
      ;;
    nextjs)
      STACK_LABEL="Next.js";         LANG="TypeScript"
      LAYER_PATTERN="Route Handlers → Services → Data Layer"; LAYER_TOP="Route Handlers"
      TEST_TOOL="Jest + Testing Library"; TEST_CMD="npm test"
      FACTORY_DESC="@faker-js/faker 기반 Factory"
      ;;
    nestjs)
      STACK_LABEL="NestJS";          LANG="TypeScript"
      LAYER_PATTERN="Controllers → Services → Repositories"; LAYER_TOP="Controllers"
      TEST_TOOL="Jest";              TEST_CMD="npm test"
      FACTORY_DESC="@nestjs/testing 기반 Factory"
      ;;
    node)
      STACK_LABEL="Node.js";         LANG="JavaScript/TypeScript"
      LAYER_PATTERN="Controllers → Services → Data Layer"; LAYER_TOP="Controllers"
      TEST_TOOL="Jest";              TEST_CMD="npm test"
      FACTORY_DESC="faker 기반 Factory"
      ;;
    rails)
      STACK_LABEL="Ruby on Rails";   LANG="Ruby"
      LAYER_PATTERN="Controllers → Services → ActiveRecord"; LAYER_TOP="Controllers"
      TEST_TOOL="RSpec";             TEST_CMD="bundle exec rspec"
      FACTORY_DESC="FactoryBot 기반 Factory"
      ;;
    springboot)
      STACK_LABEL="Spring Boot";     LANG="Java/Kotlin"
      LAYER_PATTERN="Controllers → Services → Repositories"; LAYER_TOP="Controllers"
      TEST_TOOL="JUnit 5";           TEST_CMD="./gradlew test"
      FACTORY_DESC="TestEntityManager 기반 Fixture"
      ;;
    *)
      STACK_LABEL="Unknown";         LANG="Unknown"
      LAYER_PATTERN="Controllers → Services → Data Layer"; LAYER_TOP="Controllers"
      TEST_TOOL="{test_tool}";       TEST_CMD="{test_command}"
      FACTORY_DESC="{factory_pattern}"
      ;;
  esac
}

# ──────────────────────────────────────────────────────
# 3. 파일 내 Django 참조 교체 (perl - Linux/macOS 공용)
# ──────────────────────────────────────────────────────
replace_in_file() {
  local file="$1"
  [ -f "$file" ] || return

  perl -pi -e "
    s|Django 백엔드|${STACK_LABEL} 백엔드|g;
    s|django 백엔드|${STACK_LABEL} 백엔드|g;
    s|Django \{version\}|${STACK_LABEL} {version}|g;
    s|Django 앱|${STACK_LABEL} 모듈|g;
    s|Views → Services → Repositories|${LAYER_PATTERN}|g;
    s|Views에서 DB|${LAYER_TOP}에서 DB|g;
    s|Views에서 비즈니스|${LAYER_TOP}에서 비즈니스|g;
    s|utils/factories\\.py의 Factory|${FACTORY_DESC}|g;
    s|Factory/PropertyMock 기반 pytest|${FACTORY_DESC} 기반 ${TEST_TOOL}|g;
    s|\\bpytest\\b|${TEST_TOOL}|g;
    s|python manage\\.py test|${TEST_CMD}|g;
  " "$file" 2>/dev/null || true
}

# ──────────────────────────────────────────────────────
# 4. 각 구성 요소 마이그레이션
# ──────────────────────────────────────────────────────
migrate_claude_md() {
  replace_in_file "$TARGET_DIR/CLAUDE.md"
  success "CLAUDE.md"
}

migrate_agents() {
  local dir="$TARGET_DIR/.claude/agents"
  [ -d "$dir" ] || { warn ".claude/agents 없음, 건너뜀"; return; }
  for f in "$dir"/*.md; do replace_in_file "$f"; done
  success "agents"
}

migrate_skills() {
  local dir="$TARGET_DIR/.claude/skills"
  [ -d "$dir" ] || { warn ".claude/skills 없음, 건너뜀"; return; }
  find "$dir" -name "*.md" | while read -r f; do replace_in_file "$f"; done
  success "skills"
}

migrate_pr_test() {
  local f="$TARGET_DIR/.github/workflows/pr-test.yml"
  [ -f "$f" ] || { warn "pr-test.yml 없음, 건너뜀"; return; }

  case "$STACK" in
    fastapi|flask)
      cat > "$f" << 'EOF'
name: PR Test
on:
  pull_request:
    branches: [dev]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v4
        with:
          python-version: "3.11"
      - uses: actions/cache@v3
        with:
          path: ~/.cache/pip
          key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements*.txt') }}
          restore-keys: ${{ runner.os }}-pip-
      - run: pip install -r requirements.txt
      - run: pytest
        env:
          PYTHONUNBUFFERED: 1
EOF
      ;;
    express|nextjs|nestjs|node)
      cat > "$f" << 'EOF'
name: PR Test
on:
  pull_request:
    branches: [dev]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: npm
      - run: npm ci
      - run: npm test
EOF
      ;;
    rails)
      cat > "$f" << 'EOF'
name: PR Test
on:
  pull_request:
    branches: [dev]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: "3.3"
          bundler-cache: true
      - run: bundle exec rspec
EOF
      ;;
    springboot)
      cat > "$f" << 'EOF'
name: PR Test
on:
  pull_request:
    branches: [dev]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: "21"
          distribution: temurin
      - run: ./gradlew test
EOF
      ;;
    *)
      warn "pr-test.yml: 알 수 없는 스택, CI 명령어를 수동으로 채워주세요"
      return
      ;;
  esac
  success "pr-test.yml 재생성"
}

migrate_settings() {
  local f="$TARGET_DIR/.claude/settings.json"
  [ -f "$f" ] || { warn "settings.json 없음, 건너뜀"; return; }

  case "$STACK" in
    fastapi|flask)
      perl -pi -e 's/.*makemigrations.*\n//; s/.*manage\.py migrate.*\n//;' "$f" 2>/dev/null || true
      ;;
    express|nextjs|nestjs|node|rails|springboot|unknown)
      perl -pi -e '
        s/.*makemigrations.*\n//;
        s/.*manage\.py migrate.*\n//;
        s/.*pip install.*\n//;
        s/.*pip-compile.*\n//;
        s/.*zappa.*\n//;
      ' "$f" 2>/dev/null || true
      ;;
  esac
  success "settings.json deny list 정리"
}

# ──────────────────────────────────────────────────────
# 메인
# ──────────────────────────────────────────────────────
STACK=$(detect_stack "$TARGET_DIR")

if $DETECT_ONLY; then
  echo "$STACK"
  exit 0
fi

info "감지된 스택: $STACK"

if [ "$STACK" = "django" ]; then
  info "Django 스택 — 마이그레이션 불필요"
  exit 0
fi

configure_stack "$STACK"
info "$STACK_LABEL 기준으로 harness 마이그레이션 시작..."

migrate_claude_md
migrate_agents
migrate_skills
migrate_pr_test
migrate_settings

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN} Harness 마이그레이션 완료! [$STACK_LABEL]${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  수동 확인 필요:"
echo "  ├── CLAUDE.md — 프로젝트명, 버전, 환경 설정 플레이스홀더 채우기"
echo "  ├── .claude/agents/*.md — 스택별 세부 규칙 검토"
echo "  └── .github/workflows/ — CI 명령어/버전 실제 환경에 맞게 조정"
echo ""
