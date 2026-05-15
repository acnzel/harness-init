# harness-init

프로젝트에 **Harness Engineering** 환경을 자동으로 셋업하는 도구입니다.

AI 에이전트(Claude Code)가 신뢰할 수 있는 결과물을 생산하도록, 에이전트 팀·규칙·도메인 지식을 프로젝트에 주입합니다.

---

## 개념

**Harness Engineering**이란 AI 에이전트가 일관되게 동작할 수 있는 환경(harness)을 설계하는 방법론입니다.

| 구성 요소 | 파일/디렉토리 | 역할 |
|-----------|-------------|------|
| 지시 아키텍처 | `CLAUDE.md` | 코딩 원칙·레이어 규칙·팀 트리거 조건 |
| 에이전트 팀 | `.claude/agents/` | 역할별 전문 에이전트 5인 |
| 실행 스킬 | `.claude/skills/` | 작업 유형별 실행 방법 |
| 슬래시 커맨드 | `.claude/commands/` | `/review` 등 단축 커맨드 |
| 세부 규칙 | `.claude/rules/` | CLAUDE.md @import 모듈 — 아키텍처·테스트·도메인·에이전트·훅 규칙 |
| 아키텍처 기록 | `.claude/decisions/` | ADR로 의사결정 일관성 유지 |
| 도메인 지식 | `DOMAIN.md` + `{app}/DOMAIN.md` | 앱별 모델·용어·흐름 문서 |
| 참고 문서 | `docs/` | 아키텍처·정책·분석·배포·트러블슈팅·API 문서 (서브디렉토리 구조) |
| CI/CD | `.github/workflows/` | PR 테스트·코드 리뷰·문서화 |

---

## 에이전트 팀 파이프라인

기능 개발·유지보수 시 5인 에이전트 팀이 순차적으로 작업합니다.

```
analyst → architect → coder ⇄ tester → reviewer
```

| 에이전트 | 역할 |
|---------|------|
| **analyst** | 티켓 분석, 영향 범위 식별, docs/ 및 DOMAIN.md 선행 참조, ADR 확인 |
| **architect** | Views/Services/Repositories 설계, ADR 생성, docs/ 문서 생성 |
| **coder** | 레이어드 코드 구현 + 해당 앱 DOMAIN.md 변경 이력 갱신 |
| **tester** | Factory/PropertyMock 기반 pytest 작성 |
| **reviewer** | 레이어 경계·CLAUDE.md 규칙·DOMAIN.md 최신 여부 검증 (PR 게이트) |

팀 실행 트리거:

```
{TICKET-ID} 구현해줘
백엔드 팀 실행해줘
```

---

## 설치

```bash
git clone https://github.com/acnzel/harness-init.git ~/harness-init
```

---

## 사용법

```bash
cd ./my-project
bash ~/harness-init/init.sh
```

실행하면 환경을 선택합니다:

```
  어떤 환경으로 구축 예정이신가요?
  1) Python  (Django / FastAPI / Flask)
  2) JS / TS (Next.js / NestJS / Express)
  3) 모름    (자동 감지)
```

`init.sh`가 자동으로 처리하는 것:

1. **환경 선택** — Python / JS·TS / 자동 감지 중 선택해 스택별 설정 분기
2. **스택 감지** — `manage.py` / `requirements.txt` / `package.json` 등으로 기술 스택 식별
3. **하네스 설치** — Django/JS 템플릿 기반으로 `.claude/`, `.github/`, `.gemini/` 구성
4. **pre-commit 설치** — Python: ruff, JS·TS: prettier + eslint (자동 설치·등록)
5. **스택 마이그레이션** — 비 Django 스택이면 `migration.sh`가 내용을 해당 스택으로 자동 변환
6. **DOMAIN.md 생성** — Python: 기존 앱이면 `domain-init.sh`가 앱별 스켈레톤 생성, JS: 정적 템플릿 복사
7. **DOMAIN.md 자동 채우기** — `domain-fill.sh`가 Claude Code로 각 앱의 `models.py`를 분석해 실제 내용을 채운 뒤, 루트 `DOMAIN.md`까지 통합 합성
8. **LSP 설정 주입** — 선택된 언어/감지된 스택에 따라 `settings.json`에 LSP 서버 설정 자동 추가 (Python → `pylsp`, JS/TS → `typescript-language-server`)

> `ENV_TYPE=js bash ~/harness-init/init.sh` 처럼 환경변수로 사전 지정하면 프롬프트 없이 실행됩니다 (CI/CD 등 비대화형 환경 지원).

### 설치 결과

```
my-project/
├── CLAUDE.md                         ← 코딩 원칙·레이어 규칙·팀 트리거
├── .pre-commit-config.yaml           ← pre-commit-hooks + ruff (자동 설치·등록)
├── DOMAIN.md                         ← 도메인 인덱스 (기존 프로젝트만)
├── {app}/DOMAIN.md                   ← 앱별 도메인 문서 스켈레톤 (기존 프로젝트만)
├── .gitignore                        ← .claude/local/ 등 제외
├── .claude/
│   ├── agents/
│   │   ├── analyst.md
│   │   ├── architect.md
│   │   ├── coder.md
│   │   ├── tester.md
│   │   └── reviewer.md
│   ├── skills/
│   │   ├── orchestrator/SKILL.md    ← /orchestrator (팀 파이프라인)
│   │   ├── explore.md               ← /explore
│   │   ├── implement.md             ← /implement
│   │   ├── debug.md                 ← /debug
│   │   ├── review.md                ← /review
│   │   └── autopilot.md             ← /autopilot
│   ├── commands/
│   │   ├── review.md                ← /review 슬래시 커맨드
│   │   ├── learn.md                 ← /learn (insight → 스킬 저장)
│   │   └── workflows/
│   │       └── gemini-review.md     ← /workflows:gemini-review
│   ├── hooks/
│   │   ├── pre-bash-guard.sh          ← migrate/DROP/WHERE없는DELETE 전 경고 (PreToolUse)
│   │   ├── domain-update-reminder.sh  ← models.py/services.py 변경 시 DOMAIN.md 업데이트 알림
│   │   ├── insight-collector.sh       ← ★ Insight 블록 자동 수집 → .claude/insights.md
│   │   └── notification.sh            ← 작업 완료 시 OS 알림 (macOS/Linux/터미널 벨)
│   ├── rules/
│   │   ├── architecture.md            ← 레이어드 아키텍처 규칙
│   │   ├── testing.md                 ← 테스트 작성 규칙 (PropertyMock/Factory)
│   │   ├── domain.md                  ← DOMAIN.md 운영 규칙
│   │   ├── agents.md                  ← 에이전트 팀 트리거·파이프라인·_workspace/
│   │   └── hooks.md                   ← 훅 목록·인라인 인사이트 기준
│   ├── scripts/
│   │   ├── domain-init.sh           ← DOMAIN.md 스켈레톤 생성 (domain-sync.yml에서 참조)
│   │   └── domain-fill.sh           ← Claude Code로 DOMAIN.md 채우기 (domain-sync.yml에서 참조)
│   ├── decisions/
│   │   └── adr-template.md
│   └── settings.json
├── .gemini/                          ← Gemini Code Assist 설정
├── .github/
│   ├── ISSUE_TEMPLATE/
│   ├── pull_request_template.md
│   └── workflows/
│       ├── claude-code-review.yml   ← PR 자동 리뷰
│       ├── claude.yml               ← Claude 이슈 처리
│       ├── pr-auto-fill.yml         ← PR 설명 자동 생성
│       ├── pr-test.yml              ← PR 테스트 실행
│       ├── post-merge-docs.yml      ← 머지 후 CHANGELOG 갱신 + API 문서 이슈 생성
│       └── domain-sync.yml          ← 머지 후 models.py 변경 감지 → DOMAIN.md 자동 갱신
└── docs/
    ├── architecture/             ← 아키텍처 가이드
    ├── policies/                 ← 비즈니스 정책
    ├── analysis/                 ← 성능 분석
    ├── deployment/               ← 배포 가이드
    ├── troubleshooting/          ← 트러블슈팅 기록
    ├── api/                      ← API 명세 (자동 생성)
    └── DOC-SYNC-POLICY.md
```

---

## Hooks — 자동 알림

`init.sh` 설치 시 두 계층의 훅이 구성됩니다.

### 프로젝트 훅 (`.claude/hooks/`)

| 훅 파일 | 이벤트 | 동작 |
|--------|--------|------|
| `pre-bash-guard.sh` | PreToolUse(Bash) | `manage.py migrate` · `DROP TABLE` · WHERE 없는 `DELETE` 실행 전 경고 출력 |
| `domain-update-reminder.sh` | PostToolUse(Edit/Write) | `models.py` 변경 시 DOMAIN.md 갱신 체크리스트 출력, `services.py`/`views.py` 변경 시 흐름 업데이트 권고 |
| `insight-collector.sh` | PostToolUse(Bash/Edit/Write) | Claude 응답의 `★ Insight` 블록을 감지해 `.claude/insights.md`에 자동 저장 |
| `notification.sh` | Notification | 작업 완료 시 macOS 알림 → Linux notify-send → 터미널 벨 순으로 폴백 |

훅은 `git diff --name-only HEAD`로 변경 파일을 감지합니다. 프로젝트별 훅을 추가하려면 `.claude/hooks/`에 `.sh` 파일을 추가하고 `settings.json`의 `hooks` 섹션에 등록하세요.

### 전역 훅 (`~/.claude/hooks/`)

`init.sh`는 `~/.claude/hooks/`에 전역 훅도 설치합니다. 이 훅은 모든 프로젝트 세션에 적용됩니다.

| 훅 파일 | 이벤트 | 동작 |
|--------|--------|------|
| `session-stop.sh` | Stop | 세션 종료 시 `~/.claude/debriefs/`에 메타데이터 기록. Claude가 debrief를 작성했으면 git 스냅샷 추가 |
| `session-start-context.sh` | SessionStart | `~/.claude/debrief-guardrails.md` + `$PWD/.claude/debrief-guardrails.md`를 읽어 `[PAST SESSION LESSONS]` 블록으로 컨텍스트 주입 |

---

## LSP — 언어 서버 자동 설정

`init.sh`는 스택에 따라 `settings.json`에 LSP 서버 설정을 자동으로 주입합니다. 단, LSP 서버 바이너리는 별도로 설치해야 합니다.

### Python (pylsp)

```bash
pip install python-lsp-server
```

선택 플러그인 (권장):

```bash
pip install pylsp-mypy          # 타입 체크
pip install python-lsp-ruff     # ruff 연동
pip install pylsp-rope          # 리팩토링
```

### JS / TS (typescript-language-server)

```bash
npm install -g typescript-language-server typescript
```

### 설치 확인

```bash
# Python
pylsp --version

# JS/TS
typescript-language-server --version
```

> LSP 서버가 설치되어 있지 않으면 Claude Code에서 LSP 기능이 비활성화됩니다. 수동으로 설정하려면 `.claude/settings.json`의 `lsp` 키를 직접 편집하세요.

---

## 자기강화 루프 (Self-Reinforcement Loop)

`init.sh`는 Claude가 세션 간에 자신의 실수와 교훈을 기억하는 **자기강화 루프**를 전역으로 설치합니다.

### 작동 원리

```
세션 종료 (Stop hook)
  → ~/.claude/debriefs/YYYY-MM-DD-session-log.md  ← 브랜치·커밋·변경 파일 자동 기록
  → (Claude가 debrief 파일 작성 시) git 스냅샷 추가

다음 세션 시작 (SessionStart hook)
  → ~/.claude/debrief-guardrails.md 읽기         ← 전역 교훈 (모든 프로젝트 공통)
  → $PWD/.claude/debrief-guardrails.md 읽기      ← 프로젝트 교훈 (해당 프로젝트만)
  → [PAST SESSION LESSONS] 블록으로 Claude 컨텍스트에 주입
```

### 두 계층 가드레일

| 파일 | 범위 | 내용 |
|------|------|------|
| `~/.claude/debrief-guardrails.md` | 전역 (모든 프로젝트) | 확인 우선 원칙, 타입 안전성 규칙, AI 리뷰 검증 방법 등 보편적 교훈 |
| `.claude/debrief-guardrails.md` | 프로젝트별 | 도메인 ID 혼동 주의, 코드베이스 특화 패턴, 반복 실수 히스토리 |

### 설치 후 파일 구조

```
~/.claude/
├── debrief-guardrails.md          ← 전역 교훈 누적 (init.sh가 초기 시드 생성)
├── hooks/
│   ├── session-stop.sh            ← 세션 종료 기록 훅
│   └── session-start-context.sh  ← 세션 시작 컨텍스트 주입 훅
└── debriefs/
    ├── YYYY-MM-DD-session-log.md  ← 자동 기록 (Stop 훅)
    └── YYYY-MM-DD-debrief.md      ← Claude가 직접 작성하는 세션 debrief

my-project/
└── .claude/
    └── debrief-guardrails.md      ← 프로젝트 교훈 누적 (init.sh가 PROJECT_NAME 치환)
```

### 교훈 누적 방법

**전역 교훈** (`~/.claude/debrief-guardrails.md`에 추가):
```markdown
## 섹션명

- [교훈 내용] — [근거 또는 발생 배경]
```

**프로젝트 교훈** (`.claude/debrief-guardrails.md`의 반복 실수 히스토리에 추가):
```markdown
## 반복 실수 히스토리

- YYYY-MM-DD: [실수 내용] → [올바른 접근]
```

같은 실수가 2회 이상 반복되면 해당 섹션으로 승격해 클래스화합니다.

### Insight 자동 수집

Claude가 작업 중 코드베이스 특화 패턴을 발견하면 다음 포맷으로 인라인 출력합니다:

```
`★ Insight ─────────────────────────────────────`
  [발견한 원칙 또는 패턴]
`─────────────────────────────────────────────────`
```

`insight-collector.sh` 훅이 다음 도구 호출 직후 세션 JSONL을 증분 스캔해 `.claude/insights.md`에 자동 저장합니다. 새 insight가 저장되면 터미널에 `💡 N개의 인사이트가 .claude/insights.md 에 저장됐습니다.` 알림이 출력됩니다.

insight를 수동으로 스킬로 승격하려면 `/learn` 슬래시 커맨드를 사용합니다:

```
/learn                        # 자동으로 스킬명 생성
/learn django-db-table-naming # 스킬명 지정
```

결과는 `.claude/skills/{skill-name}.md`로 저장됩니다.

---

## pre-commit — 자동 코드 품질 게이트

`init.sh` 실행 시 `.pre-commit-config.yaml` 생성 + `pre-commit install`까지 자동 완료합니다.

### 기본 포함 훅

| 훅 | 역할 |
|----|------|
| `pre-commit-hooks` | trailing-whitespace, end-of-file-fixer, check-yaml/json/toml, check-merge-conflict, debug-statements, large-files |
| `ruff` | Python 린팅 + 자동 수정 (`--fix`) |
| `ruff-format` | Python 코드 포맷팅 (black 호환) |

### 버전 업데이트

```bash
pre-commit autoupdate   # 모든 훅을 최신 버전으로 업데이트
```

### 수동 전체 실행

```bash
pre-commit run --all-files
```

---

## DOMAIN.md — 도메인 지식 관리

기존 프로젝트에 harness를 설치하면 앱별 도메인 문서가 자동 생성되고 내용까지 채워집니다.

### 자동 생성 + 채우기 (init.sh)

```bash
bash ~/harness-init/init.sh
```

내부적으로 3단계가 순서대로 실행됩니다:

| 단계 | 스크립트 | 결과 |
|------|---------|------|
| 1. 스켈레톤 생성 | `domain-init.sh` | 앱별 `DOMAIN.md` 빈 틀 + 루트 인덱스 |
| 2. 앱별 채우기 | `domain-fill.sh` | Claude Code가 `models.py` 분석 → 필드·Choices·관계 자동 주입 |
| 3. 루트 통합 합성 | `domain-fill.sh` (마지막 단계) | 모든 앱 DOMAIN.md를 읽어 Quick Reference·관계 다이어그램·앱 설명 합성 |

신규 프로젝트는 앱 개발 후 단계별로 직접 실행:

```bash
bash ~/harness-init/scripts/domain-init.sh   # 스켈레톤 생성
bash ~/harness-init/scripts/domain-fill.sh   # Claude Code로 내용 채우기 (Claude Code 설치 필요)
```

### domain-fill.sh 상세 동작

```
1. models.py가 있는 앱을 순회
   └→ claude -p로 models.py 분석 → 앱별 DOMAIN.md에 필드/Choices/관계 주입

2. 모든 앱 완료 후 루트 DOMAIN.md 통합 합성
   └→ 앱 설명 (인덱스 테이블 TODO 교체)
   └→ Quick Reference 10개 이상 용어 추출
   └→ 슬랭/내부 용어 패턴 정리
   └→ 앱 간 FK/M2M/O2O 관계 다이어그램 생성
```

> Claude Code가 설치되어 있지 않으면 domain-fill.sh는 자동으로 건너뜁니다.

### 업데이트 사이클

| 단계 | 에이전트 | 동작 |
|------|---------|------|
| 분석 | analyst | 관련 앱 `DOMAIN.md` 선행 참조 |
| 구현 | coder | 코드 변경 후 변경 이력 + 수정 섹션 갱신 |
| 검증 | reviewer | DOMAIN.md 최신 여부 체크 (체크리스트 E) |

### 앱별 DOMAIN.md 구조

```markdown
# {app} 도메인
## 도메인 계층 구조   ← 모델 트리 (domain-fill.sh 자동 추출)
## 핵심 모델          ← 모델별 필드·타입 테이블 (domain-fill.sh 자동 주입)
## 상태 코드 / Choices ← TextChoices/IntegerChoices 자동 추출
## 주요 관계          ← FK/M2M/O2O 관계 목록 (domain-fill.sh 자동 추출)
## 변경 이력          ← coder가 매 작업 후 갱신
```

### 루트 DOMAIN.md 구조

```markdown
# DOMAIN.md - {project} 도메인 지식 사전
## 도메인 문서 구조   ← 앱별 링크 + 설명 (domain-fill.sh 자동 채우기)
## Quick Reference    ← 프로젝트 핵심 용어 10개+ (domain-fill.sh 자동 추출)
## 슬랭 / 내부 용어  ← 팀 내부 축약어·패턴 (domain-fill.sh 자동 감지)
## 핵심 관계 다이어그램 ← 앱 간 크로스 관계 (domain-fill.sh 자동 생성)
## 변경 이력
```

---

## GitHub Actions — domain-sync.yml

PR이 `dev` / `prod` 브랜치에 머지될 때 `models.py` 변경이 감지되면 자동으로 DOMAIN.md를 갱신합니다.

### 동작 흐름

```
PR 머지 (dev/prod)
  └→ models.py 변경 여부 확인
       └→ (변경 있음) Claude Code CLI 설치
            └→ domain-init.sh   ← 새 앱 스켈레톤 생성
            └→ domain-fill.sh   ← 앱별 + 루트 DOMAIN.md 채우기
            └→ git commit & push  ← "docs: DOMAIN.md 자동 업데이트"
```

### 사전 설정 (1회)

GitHub 저장소 → **Settings → Secrets → Actions**에 시크릿 추가:

| 시크릿 이름 | 값 |
|------------|---|
| `ANTHROPIC_API_KEY` | Anthropic API 키 |

> `init.sh` 실행 시 `.claude/scripts/domain-init.sh`와 `.claude/scripts/domain-fill.sh`가 자동으로 복사되므로 별도 설정 불필요.

---

## docs/ — 참고 문서 관리

`docs/` 디렉토리는 카테고리별 서브디렉토리로 관리합니다. 에이전트가 작업 전 관련 문서를 자동 참조하고, 새로운 아키텍처·정책 결정 시 자동 생성합니다.

| 디렉토리 | 용도 | 생성 주체 |
|---------|------|---------|
| `architecture/` | 레이어 구조·패턴 가이드 | architect 에이전트 |
| `policies/` | 비즈니스 정책·규칙 | architect 에이전트 |
| `analysis/` | 성능·병목 분석 결과 | architect 에이전트 |
| `deployment/` | 배포·인프라 가이드 | DevOps 담당자 |
| `troubleshooting/` | 장애 대응·버그 수정 이력 | 장애 대응자 |
| `api/` | 엔드포인트 명세 | post-merge-docs.yml (이슈 생성 자동화) |

새 문서를 생성하면 `CLAUDE.md`의 `## 참고 문서` 테이블에 등록합니다. 동기화 정책 전문은 `docs/DOC-SYNC-POLICY.md`를 참조하세요.

---

## ADR — 아키텍처 의사결정 기록

아키텍처 결정은 `.claude/decisions/`에 누적합니다.

```bash
cp .claude/decisions/adr-template.md .claude/decisions/001-auth-strategy.md
```

- **analyst**: 분석 전 기존 ADR을 읽어 제약사항 파악
- **architect**: 설계 시 ADR 확인 + 새 결정은 신규 ADR 작성
- ADR이 쌓일수록 에이전트가 과거 결정과 일관된 방향으로 작업

---

## 지원 스택

`init.sh`는 아래 스택을 자동 감지해 harness 내용을 해당 스택 기준으로 변환합니다.

| 스택 | 감지 기준 |
|------|----------|
| Django | `manage.py`, `requirements.txt`에 django |
| FastAPI | `requirements.txt`에 fastapi |
| Flask | `requirements.txt`에 flask |
| NestJS | `package.json`에 @nestjs/core |
| Next.js | `package.json`에 next |
| Express | `package.json`에 express |
| Rails | `Gemfile`에 rails |
| Spring Boot | `pom.xml` / `build.gradle`에 spring-boot |

---

## 지원 환경

| 환경 | 템플릿 | 에이전트 | 테스트 | pre-commit |
|------|--------|---------|-------|-----------|
| Django / FastAPI / Flask | `templates/django/` | pytest + Factory + PropertyMock | ruff | ruff + ruff-format |
| Next.js / NestJS / Express | `templates/js/` | jest/vitest + factory functions + jest.spyOn | prettier + eslint | prettier + eslint |

JS/TS 환경은 Django 공통 파일(skills, commands, .gemini, docs)을 그대로 재사용하고, 에이전트·hooks·CLAUDE.md·PR 테스트 워크플로우만 JS 전용으로 교체됩니다.

---

## 템플릿 구조

```
harness-init/
├── README.md
├── CLAUDE.md                     ← harness-init 자체 개발 가이드
├── init.sh                       ← 메인 실행 스크립트
├── templates/
│   ├── base/                     ← 스택 무관 전역 공통 파일
│   │   ├── debrief-guardrails.md          ← 전역 가드레일 초기 시드
│   │   ├── project-debrief-guardrails.md  ← 프로젝트 가드레일 템플릿 ({{PROJECT_NAME}} placeholder)
│   │   └── hooks/
│   │       ├── session-stop.sh            ← 세션 종료 기록 훅
│   │       └── session-start-context.sh  ← 세션 시작 컨텍스트 주입 훅
│   ├── django/                   ← Django/Python 전용 템플릿
│   │   ├── CLAUDE.md             ← 레이어드 아키텍처 규칙 (Views→Services→Repositories)
│   │   ├── .claude/
│   │   │   ├── agents/           ← analyst/architect/coder/tester/reviewer (pytest 기반)
│   │   │   ├── skills/           ← orchestrator + 5개 단독 스킬
│   │   │   ├── commands/
│   │   │   ├── hooks/            ← pre-bash-guard.sh / domain-update-reminder.sh / notification.sh
│   │   │   ├── rules/            ← architecture / testing / domain / agents / hooks (CLAUDE.md @imports)
│   │   │   └── decisions/
│   │   ├── .gemini/
│   │   ├── .github/
│   │   └── docs/
│   └── js/                       ← JS/TS 전용 오버라이드 템플릿
│       ├── CLAUDE.md             ← Controller/Service/Repository + TypeScript 규칙
│       ├── DOMAIN.md             ← JS ORM 스키마 안내 (Prisma/TypeORM/Mongoose/Drizzle)
│       ├── .claude/
│       │   ├── agents/           ← analyst/architect/coder/tester/reviewer (jest 기반)
│       │   └── hooks/            ← domain-update-reminder.sh (schema.prisma/entity.ts 감지)
│       └── .github/workflows/
│           └── pr-test.yml       ← Node.js 20 + npm ci + npm test
└── scripts/
    ├── domain-init.sh            ← 앱별 DOMAIN.md 스켈레톤 생성
    ├── domain-fill.sh            ← Claude Code로 DOMAIN.md 실제 내용 채우기 + 루트 합성
    ├── migration.sh              ← 스택 감지 + 비 Django 하네스 적응
    └── merge-claude-md.sh        ← CLAUDE.md 주입
```

---

## 커스터마이징

| 대상 | 파일 |
|------|------|
| 코딩 원칙 (상위) | `templates/django/CLAUDE.md` |
| 레이어드 아키텍처 규칙 | `templates/django/.claude/rules/architecture.md` |
| 테스트 작성 규칙 | `templates/django/.claude/rules/testing.md` |
| 도메인 지식 운영 규칙 | `templates/django/.claude/rules/domain.md` |
| 에이전트 팀 규칙 | `templates/django/.claude/rules/agents.md` |
| 훅·인사이트 규칙 | `templates/django/.claude/rules/hooks.md` |
| 에이전트 역할·원칙 | `templates/django/.claude/agents/*.md` |
| 팀 파이프라인 | `templates/django/.claude/skills/orchestrator/SKILL.md` |
| 비 Django 스택 설정 | `scripts/migration.sh` → `configure_stack()` |
