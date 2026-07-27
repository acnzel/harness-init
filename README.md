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
| 구조 지식 | codegraph 인덱스 | 심볼 위치·호출 경로·영향 범위 (실시간, 문서화하지 않음) |
| 의미 지식 | `DOMAIN.md` + `{app}/DOMAIN.md` | 상태값의 뜻·시그널 부수효과·용어·내부 슬랭 |
| 지식 가드레일 | `.claude/scripts/domain-*.py` | 의미 변화 감지 → 문서 갱신 강제 (훅·pre-commit·CI) |
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
| **coder** | 레이어드 코드 구현 + 새 모델·필드·choices 추가 시 해당 앱 DOMAIN.md 갱신 |
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
6. **구조 지식 계층** — `codegraph-setup.sh`가 인덱싱 + MCP 등록 (`.mcp.json`). codegraph 미설치면 안내 후 건너뜀
7. **의미 지식 계층** — `domain-init.sh`가 AST로 Choices·시그널·db_table을 추출해 스켈레톤 생성. `domain-fill.sh`가 시그널 부수효과만 요약 (Claude Code 필요, 없으면 건너뜀)
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
│   │   ├── session-knowledge.sh       ← codegraph 동기화 + 낡은 DOMAIN.md 경고 (SessionStart)
│   │   ├── domain-guard.sh            ← 의미 변화 감지 → 갱신 지시 (PostToolUse, exit 2)
│   │   ├── insight-collector.sh       ← ★ Insight 블록 자동 수집 → .claude/insights.md
│   │   └── notification.sh            ← 작업 완료 시 OS 알림 (macOS/Linux/터미널 벨)
│   ├── rules/
│   │   ├── architecture.md            ← 레이어드 아키텍처 규칙
│   │   ├── testing.md                 ← 테스트 작성 규칙 (PropertyMock/Factory)
│   │   ├── domain.md                  ← DOMAIN.md 운영 규칙
│   │   ├── agents.md                  ← 에이전트 팀 트리거·파이프라인·_workspace/
│   │   └── hooks.md                   ← 훅 목록·인라인 인사이트 기준
│   ├── scripts/
│   │   ├── domain-extract.py        ← AST로 Choices·시그널·db_table 추출
│   │   ├── domain-gate.py           ← 의미 변화 판정 (훅·pre-commit·CI 공용)
│   │   └── domain-freshness.py      ← DOMAIN.md 신선도 측정
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
│       ├── post-merge-docs.yml      ← 머지 후 API 문서 갱신 이슈 자동 생성
│       └── domain-drift.yml         ← PR에서 의미 변화 대비 DOMAIN.md 미갱신 감지 (LLM 미사용)
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
| `session-knowledge.sh` | SessionStart | codegraph 인덱스 증분 동기화 + 소스보다 뒤처진 DOMAIN.md 목록을 컨텍스트로 주입 |
| `domain-guard.sh` | PostToolUse(Edit/Write) | 편집한 파일 하나만 판정. 의미 변화 감지 시 exit 2로 DOMAIN.md 갱신 지시 |
| `insight-collector.sh` | PostToolUse(Bash/Edit/Write) | Claude 응답의 `★ Insight` 블록을 감지해 `.claude/insights.md`에 자동 저장 |
| `notification.sh` | Notification | 작업 완료 시 macOS 알림 → Linux notify-send → 터미널 벨 순으로 폴백 |

훅은 `git diff --name-only HEAD`로 변경 파일을 감지합니다. 프로젝트별 훅을 추가하려면 `.claude/hooks/`에 `.sh` 파일을 추가하고 `settings.json`의 `hooks` 섹션에 등록하세요.

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

세션 간 교훈 누적 루프(debrief-guardrails + session 훅)는 사용자 전역의 **weekly-retro 체계**로 대체되어, `init.sh`는 더 이상 전역 파일이나 훅을 설치하지 않습니다. 동일한 루프를 두 곳에서 중복 설치하지 않습니다.

전역 체계는 debrief를 지식 베이스에 누적하고, `/weekly-retro` 게이트로 승인된 반복 교훈을 **규칙 레지스트리**(`~/.claude/rules/rules.yaml`)에 티어와 함께 기록합니다. 티어가 전달 방식을 정합니다:

| 티어 | 전달 |
|---|---|
| `deny` | 위험한 명령을 PreToolUse 훅이 차단 |
| `advise` | 해당 도구·명령·파일을 만지는 **그 순간에만** 주입 (규칙별 5분 쿨다운) |
| `core` | 항상 로드 — `~/.claude/CLAUDE.md`에 자동 생성, **상한 7개** |
| `archive` | 주입하지 않고 검색용으로만 보존 |

교훈을 전부 항상 로드하면 무관한 규칙이 쌓여 결국 아무것도 지켜지지 않기 때문입니다(희석화). `core` 상한이 있어 새 교훈을 넣으려면 기존 것을 강등해야 합니다.

> **이 체계는 `~/.claude` 저장소가 머신 간에 전파합니다.** 신규 머신을 세팅할 땐 `~/.claude`를 먼저 clone하세요. `harness-init`은 프로젝트별 `.claude/` 스캐폴딩만 담당하며, 전역 규칙 파일이나 훅을 설치하지 않습니다.

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
## 지식 계층 — codegraph + DOMAIN.md

프로젝트 지식을 두 계층으로 나눠 관리합니다. 각 계층은 갱신 방식이 다릅니다.

| | 구조 (Structure) | 의미 (Semantics) |
|---|---|---|
| 질문 | 어디에 있나 / 무엇이 부르나 / 바꾸면 어디가 깨지나 | 무슨 뜻인가 / 왜 이런가 / 언제 전이하나 |
| 출처 | **codegraph** (실시간 인덱스) | **DOMAIN.md** (사람이 쓴 문서) |
| 갱신 | 파일 저장 시 자동, 증분 수백 ms | 사람·에이전트가 직접, 게이트가 강제 |

핵심 원칙은 **코드에서 재도출할 수 있는 것은 문서에 적지 않는다**입니다.
모델 필드 목록, FK 관계, 계층 트리, 호출 경로를 문서에 박제하면 그 순간부터 낡습니다.

### 왜 이렇게 나눴나 — 실측 근거

Django 레포(2,741파일 / 33,483노드 / 90,903엣지)에서 2026-07-27 측정한 결과입니다.

**기존 방식(구조를 문서에 박제)이 실패한 정도**

| 대상 | 소스 커밋 | DOMAIN.md 커밋 | 추종률 |
|------|----------|---------------|-------|
| `web/match` | 866 | 19 | 2.2% |
| `web/order` | 869 | 1 | 0.1% (160일 정지) |
| `web/accounts` | 156 | 1 | 1% (71일 정지) |

문서가 낡은 게 문제가 아니라, **낡았다는 사실을 아무도 몰랐다**는 게 문제였습니다.

**codegraph가 답하지 못하는 영역**

| 항목 | codegraph 조회 결과 |
|------|-------------------|
| 모델 필드 선언 (`ForeignKey` 등) | 심볼로 취급 안 함 — **0건** |
| `Meta.db_table` 문자열 | FTS 검색 불가 — **0건** |
| `@receiver(post_save, ...)` 배선 | 호출 그래프에 엣지 없음 — **0건** |

세 번째가 가장 위험합니다. `MatchApply.save()` 는 `add_matchapply` 핸들러를 통해
정원·프로모션·소진 시각을 바꾸지만, `codegraph impact MatchApply` 결과 528건 어디에도
그 연결이 나타나지 않았습니다. **이 셋이 DOMAIN.md가 담당해야 할 영역의 경계입니다.**

### 3단 자동 가드레일

개발자가 의식하지 않아도 문서가 따라오도록 세 지점에 게이트를 걸었습니다.

| 시점 | 장치 | 동작 |
|------|------|------|
| 세션 시작 | `session-knowledge.sh` | codegraph 동기화 + 뒤처진 DOMAIN.md 목록 주입 |
| 파일 편집 직후 | `domain-guard.sh` | 의미 변화 감지 시 exit 2로 에이전트에 갱신 지시 |
| 커밋 직전 | `domain-gate` (pre-commit) | 문서 미갱신이면 커밋 차단 |
| PR | `domain-drift.yml` | 로컬 게이트 우회분을 CI에서 재검출 (LLM 미사용) |

**오탐이 없는 이유**: 정규식으로 파일 종류를 보는 게 아니라, AST 추출 결과의 지문을
변경 전후로 비교합니다. 주석 추가·리팩토링·포맷 변경에는 발화하지 않고,
Choices 값·시그널 배선·`db_table`이 실제로 달라졌을 때만 발화합니다.
편집 중 구문 오류 상태에서는 판정을 보류합니다.

이전 훅은 `git diff --name-only HEAD`로 워킹트리 전체를 봤기 때문에 `models.py`를
한 번 건드리면 이후 모든 편집마다 같은 배너가 떴고, 그래서 무시당했습니다.
지금은 편집한 파일 하나만 판정합니다.

### 도메인 지식 도구

`init.sh` 실행 시 `.claude/scripts/` 에 설치됩니다. 사용자 설정이 아니라 하네스 소유
코드이므로, 재실행 시 항상 최신 버전으로 덮어씁니다 (버전이 어긋나면 게이트가 오작동).

```bash
# Choices·시그널·db_table 추출 (stdlib ast — LLM 미사용, 환각 없음)
python3 .claude/scripts/domain-extract.py . --app web/match --format md

# 지금 무엇이 게이트에 걸리는지
python3 .claude/scripts/domain-gate.py --staged

# 문서가 소스보다 며칠 뒤처졌는지
python3 .claude/scripts/domain-freshness.py .
```

### 설치 시 생성되는 것

```bash
bash ~/harness-init/scripts/domain-init.sh   # 의미 스켈레톤 생성 (값은 AST가 채움)
bash ~/harness-init/scripts/domain-fill.sh   # 시그널 부수효과만 LLM이 요약 (선택)
```

`domain-init.sh` 는 **codegraph가 못 보는 것만** 스켈레톤화합니다.

```markdown
# {app} 도메인
## 한 줄 요약          ← TODO (사람)
## 비즈니스 규칙        ← TODO (사람)
## 변경 시 주의사항      ← TODO (사람) — 과거 사고 지점
#### 모델 → 테이블 매핑  ← AST 자동 추출
#### 상태값 / Choices   ← 값·라벨은 AST 자동 / '의미' 열만 TODO
#### 시그널 부수효과     ← 배선은 AST 자동 / '부수효과' 열만 TODO
```

`domain-fill.sh` 는 시그널 핸들러 본문을 읽어 **무엇을 변경하는지 사실만** 요약합니다.
비즈니스 규칙·내부 슬랭·주의사항은 코드에 없는 지식이라 의도적으로 비워둡니다.
LLM이 쓰면 그럴듯한 창작이 되기 때문입니다.

### codegraph는 선택 의존성

harness-init은 남의 레포에 주입되는 도구이므로 팀원 전원에게 바이너리 설치를
강요하지 않습니다. 없으면 안내만 하고 건너뛰며, 에이전트 rules에 Grep/Read 폴백
경로가 명시되어 있습니다.

```bash
curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh
bash ~/harness-init/scripts/codegraph-setup.sh   # 인덱싱 + MCP 등록 (.mcp.json, 팀 공유)
```

인덱스(`.codegraph/`)는 대형 레포에서 100MB를 넘으므로 `.gitignore`에 자동 추가됩니다.
팀원은 각자 `codegraph init .` 을 한 번 돌리면 됩니다 (2,741파일 기준 19초).

### 업데이트 사이클

| 단계 | 에이전트 | 동작 |
|------|---------|------|
| 분석 | analyst | 영향 범위는 codegraph 조회. 모델 변경 시 시그널 표 확인 필수 |
| 구현 | coder | 의미가 바뀌면 같은 커밋에서 DOMAIN.md 갱신 |
| 검증 | reviewer | `domain-gate.py --staged` 실행으로 판정 (BLOCKER, PASS 불가) |

### 게이트 우회

`git commit --no-verify` 로 넘길 수 있지만 표면화 대상입니다. 우회했으면 PR 설명에
사유를 남깁니다. CI(`domain-drift.yml`)가 PR 단계에서 다시 잡습니다.

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
| Django / FastAPI / Flask | `templates/django/` | pytest + Factory + PropertyMock | ruff + ruff-format + domain-gate | stdlib `ast` (정밀) |
| Next.js / NestJS / Express | `templates/js/` | jest/vitest + factory functions + jest.spyOn | prettier + eslint + domain-gate | 선언 블록 지문 (TS enum / `as const` / 리터럴 union / Prisma) |

JS/TS 환경은 Django 공통 파일(skills, commands, .gemini, docs)을 그대로 재사용하고, 에이전트·hooks·CLAUDE.md·PR 테스트 워크플로우만 JS 전용으로 교체됩니다.

---

## 템플릿 구조

```
harness-init/
├── README.md
├── CLAUDE.md                     ← harness-init 자체 개발 가이드
├── init.sh                       ← 메인 실행 스크립트
├── templates/
│   ├── django/                   ← Django/Python 전용 템플릿
│   │   ├── CLAUDE.md             ← 레이어드 아키텍처 규칙 (Views→Services→Repositories)
│   │   ├── .claude/
│   │   │   ├── agents/           ← analyst/architect/coder/tester/reviewer (pytest 기반)
│   │   │   ├── skills/           ← orchestrator + 5개 단독 스킬
│   │   │   ├── commands/
│   │   │   ├── hooks/            ← session-knowledge / pre-bash-guard / domain-guard / insight-collector / notification
│   │   │   ├── rules/            ← knowledge / architecture / testing / domain / agents / hooks (CLAUDE.md @imports)
│   │   │   └── decisions/
│   │   ├── .gemini/
│   │   ├── .github/
│   │   └── docs/
│   └── js/                       ← JS/TS 전용 오버라이드 템플릿
│       ├── CLAUDE.md             ← Controller/Service/Repository + TypeScript 규칙
│       ├── DOMAIN.md             ← JS ORM 스키마 안내 (Prisma/TypeORM/Mongoose/Drizzle)
│       ├── .claude/
│       │   ├── agents/           ← analyst/architect/coder/tester/reviewer (jest 기반)
│       │   ├── rules/            ← architecture / testing / domain / agents / hooks (JS/TS 전용)
│       └── .github/workflows/
│           ├── pr-test.yml               ← Node.js 20 + npm ci + npm test
│           └── post-merge-docs.yml       ← 머지 후 API 문서 갱신 이슈 자동 생성
└── scripts/
    ├── domain-extract.py         ← AST로 Choices·시그널·db_table 추출 (LLM 미사용)
    ├── domain-gate.py            ← 의미 변화 판정, 훅·pre-commit·CI 공용
    ├── domain-freshness.py       ← DOMAIN.md가 소스보다 며칠 뒤처졌는지 측정
    ├── domain-init.sh            ← 앱별 DOMAIN.md 의미 스켈레톤 생성
    ├── domain-fill.sh            ← 시그널 핸들러 본문을 읽어 부수효과만 요약
    ├── codegraph-setup.sh        ← codegraph 인덱싱 + MCP 등록 (선택 의존성)
    ├── lint-baseline.py          ← 기존 레포의 레거시 ruff 위반을 규칙 단위로 유예
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
| 지식 2계층 규칙 | `templates/django/.claude/rules/knowledge.md` |
| 도메인 지식 운영 규칙 | `templates/django/.claude/rules/domain.md` |
| 의미 변화 감지 대상 | `scripts/domain-extract.py` → `CHOICE_BASES` / `ENUM_BASES` / `SIGNAL_NAMES` |
| JS/TS 판정 패턴 | `scripts/domain-gate.py` → `_js_fingerprint()` |
| 에이전트 팀 규칙 | `templates/django/.claude/rules/agents.md` |
| 훅·인사이트 규칙 | `templates/django/.claude/rules/hooks.md` |
| 에이전트 역할·원칙 | `templates/django/.claude/agents/*.md` |
| 팀 파이프라인 | `templates/django/.claude/skills/orchestrator/SKILL.md` |
| 비 Django 스택 설정 | `scripts/migration.sh` → `configure_stack()` |
