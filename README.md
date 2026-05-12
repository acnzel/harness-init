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
3. **하네스 설치** — Django 템플릿 기반으로 `.claude/`, `.github/`, `.gemini/` 구성
4. **pre-commit 설치** — Python: ruff, JS·TS: prettier + eslint (자동 설치·등록)
5. **스택 마이그레이션** — 비 Django 스택이면 `migration.sh`가 내용을 해당 스택으로 자동 변환
6. **DOMAIN.md 생성** — Python: 기존 앱이면 `domain-init.sh`가 앱별 스켈레톤 생성, JS: 정적 템플릿 복사

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
│   │   ├── domain-update-reminder.sh  ← models.py/services.py 변경 시 DOMAIN.md 업데이트 알림
│   │   └── insight-collector.sh       ← ★ Insight 블록 자동 수집 → .claude/insights.md
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
│       └── post-merge-docs.yml      ← 머지 후 문서 동기화
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

`init.sh` 설치 시 `.claude/hooks/`와 `settings.json`에 PostToolUse 훅이 구성됩니다.

| 훅 파일 | 트리거 | 동작 |
|--------|--------|------|
| `domain-update-reminder.sh` | Edit / Write 후 | `models.py` 변경 시 DOMAIN.md 갱신 체크리스트 출력, `services.py`/`views.py` 변경 시 흐름 업데이트 권고 |
| `insight-collector.sh` | Bash / Edit / Write 후 | Claude 응답의 `★ Insight` 블록을 감지해 `.claude/insights.md`에 자동 저장 |

훅은 `git diff --name-only HEAD`로 변경 파일을 감지합니다. 프로젝트별 훅을 추가하려면 `.claude/hooks/`에 `.sh` 파일을 추가하고 `settings.json`의 `hooks` 섹션에 등록하세요.

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

기존 프로젝트에 harness를 설치하면 앱별 도메인 문서가 자동 생성됩니다.

### 자동 생성 (init.sh)

```bash
bash ~/harness-init/init.sh
# → models.py가 있는 Django 앱마다 {app}/DOMAIN.md 스켈레톤 생성
# → 루트 DOMAIN.md에 전체 앱 인덱스 + 업데이트 정책 생성
```

신규 프로젝트는 앱 개발 후 직접 실행:

```bash
bash ~/harness-init/scripts/domain-init.sh
```

### 업데이트 사이클

| 단계 | 에이전트 | 동작 |
|------|---------|------|
| 분석 | analyst | 관련 앱 `DOMAIN.md` 선행 참조 |
| 구현 | coder | 코드 변경 후 변경 이력 + 수정 섹션 갱신 |
| 검증 | reviewer | DOMAIN.md 최신 여부 체크 (체크리스트 E) |

### 앱별 DOMAIN.md 구조

```markdown
# {app} 도메인
## 도메인 계층 구조   ← 모델 트리 (자동 추출)
## 핵심 모델          ← 모델별 필드·메서드 (TODO 채우기)
## 상태 코드 / Choices
## 주요 흐름
## 변경 이력          ← coder가 매 작업 후 갱신
```

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

## 템플릿 구조

```
harness-init/
├── README.md
├── init.sh                       ← 메인 실행 스크립트
├── templates/
│   └── django/                   ← harness 템플릿 (타 스택으로 자동 마이그레이션)
│       ├── CLAUDE.md
│       ├── .claude/
│       │   ├── agents/           ← analyst/architect/coder/tester/reviewer
│       │   ├── skills/           ← orchestrator + 5개 단독 스킬
│       │   ├── commands/
│       │   ├── hooks/            ← domain-update-reminder.sh
│       │   └── decisions/
│       ├── .gemini/
│       ├── .github/
│       └── docs/
└── scripts/
    ├── domain-init.sh            ← 앱별 DOMAIN.md 스켈레톤 생성
    ├── migration.sh              ← 스택 감지 + 비 Django 하네스 적응
    └── merge-claude-md.sh        ← CLAUDE.md 주입
```

---

## 커스터마이징

| 대상 | 파일 |
|------|------|
| 코딩 원칙·레이어 규칙 | `templates/django/CLAUDE.md` |
| 에이전트 역할·원칙 | `templates/django/.claude/agents/*.md` |
| 팀 파이프라인 | `templates/django/.claude/skills/orchestrator/SKILL.md` |
| 비 Django 스택 설정 | `scripts/migration.sh` → `configure_stack()` |
