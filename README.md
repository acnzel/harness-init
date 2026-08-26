# harness-init

프로젝트에 **Harness Engineering** 환경을 자동으로 셋업하는 도구입니다.

AI 에이전트(Claude Code)가 신뢰할 수 있는 결과물을 생산하도록, 에이전트 팀·규칙·도메인 지식을 프로젝트에 주입합니다.

---

## 개념

**Harness Engineering**이란 AI 에이전트가 일관되게 동작할 수 있는 환경(harness)을 설계하는 방법론입니다.

| 구성 요소 | 파일/디렉토리 | 역할 |
|-----------|-------------|------|
| 공통 정본 | `AGENTS.md` | 모든 에이전트(Claude·Codex·Cursor)가 읽는 작업 원칙·권한·경계. 파이프라인/금지 목록은 설정에서 자동 생성 |
| 지시 아키텍처 | `CLAUDE.md` | Claude Code 전용 보충 — 환경 설정·@import·인사이트 규칙 |
| 에이전트 팀 | `.claude/agents/` | 역할별 전문 에이전트 5인 |
| 실행 스킬 | `.claude/skills/` | 작업 유형별 실행 방법 |
| 슬래시 커맨드 | `.claude/commands/` | `/review` 등 단축 커맨드 |
| 세부 규칙 | `.claude/rules/` | CLAUDE.md @import 모듈 — 아키텍처·테스트·도메인·에이전트·훅 규칙 |
| 아키텍처 기록 | `.claude/decisions/` | ADR로 의사결정 일관성 유지 |
| 구조 지식 | codegraph 인덱스 | 심볼 위치·호출 경로·영향 범위 (실시간, 문서화하지 않음) |
| 의미 지식 | `DOMAIN.md` + `{app}/DOMAIN.md` | 상태값의 뜻·시그널 부수효과·용어·내부 슬랭 |
| 지식 가드레일 | `.claude/scripts/domain-*.py` | 의미 변화 감지 → 문서 갱신 강제 (훅·pre-commit·CI) |
| 게이트 파이프라인 | `.claude/gates.json` + `gate-runner.py` | 시점별 검사 선언. pre-push와 CI가 같은 러너를 써서 드리프트 차단 |
| 게이트 자가진단 | `.claude/hooks/gate-selftest.sh` | 훅이 실제로 발화하는지 매 세션 실측 |
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
3. **하네스 설치** — Django/JS 템플릿 기반으로 `.claude/`, `.github/`, `.coderabbit.yaml` 구성
   (스택을 감지하지 못하면 이 전체 설치 대신 `templates/base-project/` 최소 하네스만 깔린다 — 아래 "지원 환경" 참조)
4. **pre-commit 설치** — Python: ruff, JS·TS: prettier + eslint (자동 설치·등록)
5. **스택 마이그레이션** — 비 Django 스택이면 `migration.sh`가 내용을 해당 스택으로 자동 변환
6. **구조 지식 계층** — `codegraph-setup.sh`가 인덱싱 + MCP 등록 (`.mcp.json`). codegraph 미설치면 안내 후 건너뜀
7. **의미 지식 계층** — `domain-init.sh`가 AST로 Choices·시그널·db_table을 추출해 스켈레톤 생성. `domain-fill.sh`가 시그널 부수효과만 요약 (Claude Code 필요, 없으면 건너뜀)
8. **게이트 파이프라인** — `.claude/gates.json`(스택별 기본값) + `gate-runner.py` 설치, pre-commit 에 pre-push 통합 게이트 등록. 기존 설정이 있으면 `repos:` 뒤에 끼워 넣고 유효하지 않으면 되돌림
9. **문서 정본 계층** — `AGENTS.md` 설치 후 자동 구간(검증 파이프라인·금지 명령)을 `gates.json`·`settings.json` 에서 렌더
10. **PR·커밋 자동화** — CODEOWNERS 골격, 마커 포함 PR 템플릿, commit-msg 티켓 삽입 훅 등록, CI 워크플로를 `gate-runner --stage ci` 로 연결
11. **LSP 설정 주입** — 선택된 언어/감지된 스택에 따라 `settings.json`에 LSP 서버 설정 자동 추가 (Python → `pylsp`, JS/TS → `typescript-language-server`)

> `ENV_TYPE=js bash ~/harness-init/init.sh` 처럼 환경변수로 사전 지정하면 프롬프트 없이 실행됩니다 (CI/CD 등 비대화형 환경 지원).

### 설치 결과

```
my-project/
├── AGENTS.md                         ← ★ 공통 정본 (전 에이전트) · 자동 구간 포함
├── CLAUDE.md                         ← Claude 전용 보충 (환경·@import·인사이트)
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
│   │       └── coderabbit-review.md ← /workflows:coderabbit-review
│   ├── hooks/
│   │   ├── _hook-input.sh             ← ★ 훅 페이로드 파싱 공용 헬퍼 (source 전용)
│   │   ├── gate-selftest.sh           ← ★ 게이트가 살아있는지 실측 (SessionStart)
│   │   ├── pre-bash-guard.sh          ← migrate/DROP/WHERE없는DELETE 전 경고 (PreToolUse)
│   │   ├── session-knowledge.sh       ← codegraph 동기화 + 낡은 DOMAIN.md 경고 (SessionStart)
│   │   ├── domain-guard.sh            ← 의미 변화 감지 → 갱신 지시 (PostToolUse, exit 2)
│   │   ├── post-bash-notice.sh        ← gh pr create 직후 /review 안내 (PostToolUse)
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
│   │   ├── domain-freshness.py      ← DOMAIN.md 신선도 측정
│   │   ├── hook-io.py               ← 훅 페이로드 파싱 + 발화 기록 (전 훅 공용)
│   │   ├── gate-runner.py           ← ★ 게이트 러너 (pre-push·CI 공용)
│   │   ├── render-agents.py         ← ★ AGENTS.md 자동 구간 렌더
│   │   ├── pr-body.py               ← ★ PR 본문 자동 수집 구간 (LLM 미사용)
│   │   └── commit-msg.py            ← ★ 커밋 메시지에 브랜치 티켓 삽입
│   ├── decisions/
│   │   └── adr-template.md
│   ├── gates.json                     ← ★ 게이트 선언 (pre-push·CI 공용, 프로젝트 소유)
│   └── settings.json
├── .coderabbit.yaml                  ← CodeRabbit 리뷰 설정 (GitHub App 설치 필요)
├── .github/
│   ├── ISSUE_TEMPLATE/
│   ├── CODEOWNERS                 ← ★ 리뷰어 자동 할당 (전부 주석, 채워서 켤 것)
│   ├── pull_request_template.md   ← 자동 수집 마커 포함
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
| `gate-selftest.sh` | SessionStart | 게이트가 실제로 발화하는지 실측. 죽었으면 세션 시작 시 경고 |
| `pre-bash-guard.sh` | PreToolUse(Bash) | `manage.py migrate` · `DROP TABLE` · WHERE 없는 `DELETE` 실행 전 경고 출력 |
| `session-knowledge.sh` | SessionStart | codegraph 인덱스 증분 동기화 + 소스보다 뒤처진 DOMAIN.md 목록을 컨텍스트로 주입 |
| `domain-guard.sh` | PostToolUse(Edit/Write) | 편집한 파일 하나만 판정. 의미 변화 감지 시 exit 2로 DOMAIN.md 갱신 지시 |
| `post-bash-notice.sh` | PostToolUse(Bash) | `gh pr create` 직후 `/review` 안내 |
| `insight-collector.sh` | PostToolUse(Bash/Edit/Write) | Claude 응답의 `★ Insight` 블록을 감지해 `.claude/insights.md`에 자동 저장 |
| `notification.sh` | Notification | 작업 완료 시 macOS 알림 → Linux notify-send → 터미널 벨 순으로 폴백 |

**훅 입력은 stdin JSON 입니다.** Claude Code 는 도구 정보를 환경변수가 아니라 stdin 에
JSON 으로 넘깁니다. 파싱은 `_hook-input.sh` 의 `hook_input_load` 한 곳에 위임하고, 훅에서
직접 파싱하지 마세요.

```bash
source "$(dirname "${BASH_SOURCE[0]}")/_hook-input.sh"
hook_input_load || exit 0
echo "$HOOK_COMMAND" | grep -q '위험패턴' && ...
```

채워지는 변수: `HOOK_PARSE_OK` `HOOK_TOOL` `HOOK_COMMAND` `HOOK_FILE_PATH` `HOOK_SESSION`
`HOOK_CWD` `HOOK_EVENT` `HOOK_RAW`.

프로젝트별 훅을 추가하려면 `.claude/hooks/`에 `.sh` 파일을 추가하고 `settings.json`의
`hooks` 섹션에 등록하세요. 하네스 소유 훅(위 표의 7개 + `_hook-input.sh`)은 재실행 시
**덮어쓰기 대상**이므로 직접 수정하지 말고 별도 파일로 추가하세요.

---

## PR·커밋 자동화

### CI 는 로컬과 같은 게이트를 돈다

`pr-test.yml` 은 테스트 명령을 직접 적지 않고 `gate-runner --stage ci` 를 호출합니다.
검사를 추가하려면 워크플로가 아니라 `.claude/gates.json` 을 고칩니다. 로컬 pre-push 와
CI 가 같은 선언을 읽으므로 갈라질 수 없습니다.

CI 에서는 `--no-fail-fast` 로 실패를 한 번에 다 보여줍니다. 하나씩 고치며 재실행하는
것보다 낫습니다. 로컬 pre-push 는 반대로 fail-fast 가 기본입니다.

이전 워크플로는 `branches: [dev]` 가 하드코딩돼 있어 `main`/`develop` 을 쓰는 대부분의
레포에서 **아예 돌지 않았습니다.** 이제 브랜치를 고정하지 않습니다.

### PR 본문은 마커 사이만 갱신

```markdown
<!-- harness:pr:start -->
(워크플로가 채움: 기준 SHA, 변경 파일, CI 게이트 목록, 하네스 설정 변경 여부)
<!-- harness:pr:end -->

## 리뷰어에게      ← 사람이 쓴 것, 절대 안 건드림
```

이전 버전은 본문을 **통째로 덮어썼습니다.** 템플릿을 채워 PR 을 열면 그 내용이 사라졌습니다.
마커가 없으면 앞에 붙이고 나머지는 보존하며, 마커가 손상되면 잘라내지 않고 덧붙입니다.

**LLM 을 쓰지 않습니다.** 이전에는 OpenAI 로 diff 를 요약했는데, 리뷰어는 diff 를 직접
읽을 수 있어 얻는 게 적고 환각 위험만 남았습니다. 지금은 git 과 `gates.json` 에서
기계적으로 얻는 사실만 적습니다 (`domain-drift` 가 LLM 을 뺀 것과 같은 판단). API 키가
필요 없습니다.

하네스 설정(`gates.json`·`settings.json`·훅·`AGENTS.md`)이 바뀌면 본문에 표시합니다.
게이트를 약화시키는 변경은 diff 두 줄이라 눈에 잘 안 띄기 때문입니다.

### 커밋 메시지에 티켓 번호

브랜치명에서 `ABC-123` 꼴을 찾아 커밋 제목에 넣습니다. 브랜치는 머지 후 사라지므로
티켓은 커밋에 남아야 합니다.

```
feature/DEV-1234-알림  +  "feat: 발송 복원"   →   "feat: [DEV-1234] 발송 복원"
```

설정이 없습니다. 프로젝트 키를 물어보면 설정 파일이 하나 늘고 그 파일이 낡습니다.

**티켓이 없어도 막지 않습니다.** hotfix·문서 수정처럼 티켓 없는 커밋은 정상이고, 차단하면
`--no-verify` 를 학습시켜 다른 게이트까지 같이 꺼집니다. merge·revert·fixup 커밋과 이미
티켓이 있는 메시지도 건드리지 않습니다.

### CODEOWNERS

`.github/CODEOWNERS` 를 **전부 주석 처리된 상태**로 깝니다. 존재하지 않는 핸들을 넣으면
GitHub 이 오류를 표시하므로, 팀 핸들을 채운 뒤 `#` 을 지워 켜세요.

첫 항목이 하네스 자체(`AGENTS.md`, `.claude/`, 워크플로, pre-commit 설정)입니다. 게이트는
조용히 약해집니다. 검사 하나를 빼는 변경은 diff 두 줄이라 눈에 안 띄므로, 하네스를 리뷰
대상에 넣어야 그 변경이 사람 눈을 거칩니다.

---

## 문서 정본 계층 — 복제하지 않고 생성한다

에이전트 도구마다 읽는 파일이 다릅니다. 같은 규칙을 여러 파일에 옮겨 적으면 한쪽을 고칠 때
다른 쪽이 조용히 낡습니다. 이 레포에도 실제로 그런 중복이 있었습니다.

| 파일 | 누가 읽나 | 무엇을 담나 |
|---|---|---|
| `AGENTS.md` | 모든 에이전트 (Claude·Codex·Cursor·OpenCode) | 작업 원칙, 절대 규칙, 권한·경계 |
| `CLAUDE.md` | Claude Code | 환경 설정, `@import`, 인사이트 규칙 |
| `.claude/rules/*.md` | 정본을 참조하는 모두 | 아키텍처·테스트·도메인·훅 상세 |
| `.coderabbit.yaml` | CodeRabbit | 리뷰 기준. `knowledge_base.code_guidelines.filePatterns` 로 `.claude/rules/*` 를 참조(파생본 아님) |

`CLAUDE.md` 는 작업 원칙을 다시 적지 않고 `AGENTS.md` 를 가리킵니다.

### 자동 구간

드리프트를 검사로 잡는 것보다 **드리프트할 대상을 없애는 것**이 쌉니다. `AGENTS.md` 의
일부는 손으로 쓰지 않고 설정에서 생성합니다.

```markdown
<!-- harness:auto:start -->
### 검증 파이프라인     ← .claude/gates.json 에서 생성
### 금지 명령           ← .claude/settings.json 의 permissions.deny 에서 생성
<!-- harness:auto:end -->
```

`gates.json` 을 고치면 pre-commit 훅이 `AGENTS.md` 를 다시 렌더합니다. 문서가 설정과
어긋날 수 없습니다. 세션 시작 시 자가진단도 신선도를 확인합니다.

```bash
python3 .claude/scripts/render-agents.py --repo .           # 갱신
python3 .claude/scripts/render-agents.py --repo . --check    # 낡았으면 exit 1
```

마커가 한 쌍이 아니거나 순서가 뒤집혀 있으면 **덮어쓰지 않고 실패**합니다. 잘못 자르면
사람이 쓴 내용이 유실되기 때문입니다.

**금지 명령을 렌더하는 이유**: `settings.json` 의 `deny` 는 Claude Code 에만 적용됩니다.
Codex·Cursor 는 그 파일을 읽지 않으므로 `AGENTS.md` 에 글로도 있어야 전달됩니다. 중복이
아니라 다른 청중을 위한 유일한 경로라서, 손으로 옮겨 적는 대신 같은 원본에서 생성합니다.

### CodeRabbit 참조 (더 이상 중복 아님)

`.coderabbit.yaml` 은 예전에 `path_instructions` 에 `.claude/rules/architecture.md`·
`testing.md` 의 레이어·테스트 규칙을 통째로 옮겨 적었습니다(PR #30, CodeRabbit 리뷰가
직접 지적). CodeRabbit 은 `CLAUDE.md`·`AGENTS.md` 는 자동으로 인식하지만
[`.claude/rules/*` 는 그 자동 인식 목록에 없어서](https://docs.coderabbit.ai/knowledge-base/code-guidelines)
`knowledge_base.code_guidelines.filePatterns` 로 명시적으로 참조를 걸어 둡니다 — 옮겨
적지 않고 가리키기만 하므로 규칙 문서를 고쳐도 이 파일은 따로 손댈 필요가 없습니다.

`path_instructions` 에는 저 두 문서에 없는, CodeRabbit 리뷰 전용 지침(KISS/YAGNI/DRY
억제 기준, 리뷰 코멘트 레벨 등)만 남아 있습니다. 이건 중복이 아니라 "금지 명령"과
같은 이유입니다 — CodeRabbit 만 필요로 하는 내용이라 다른 문서로 옮길 대상이 없습니다.

---

## 게이트 파이프라인 — 언제 무엇이 도는가

검사는 실패를 가장 이른 시점에 잡도록 배열합니다. 각 시점에 주인이 하나씩 있습니다.

| 시점 | 무엇이 도는가 | 담당 | 실패하면 |
|---|---|---|---|
| 세션 시작 | 게이트 자가진단, 낡은 DOMAIN.md 목록 | `gate-selftest.sh`, `session-knowledge.sh` | 경고 후 진행 |
| 편집 직후 | 의미 변화 판정 | `domain-guard.sh` | 갱신 지시 (exit 2) |
| 커밋 직전 | 포맷·린트 자동수정, 문서 미갱신 | `.pre-commit-config.yaml` | 커밋 차단 |
| **push 직전** | **레포 단위 통합 검사** | **`gate-runner --stage pre-push`** | **push 차단** |
| CI | 같은 통합 검사 | `gate-runner --stage ci` | 머지 불가 |

핵심은 마지막 두 줄이 **같은 러너와 같은 `.claude/gates.json`** 을 쓴다는 점입니다. 구현이
하나라서 "로컬은 통과했는데 CI가 깨지는" 드리프트가 구조적으로 생기지 않습니다.

### 역할 분담

- **pre-commit**: 파일 단위, 빠름, 자동수정. 변경된 파일만 봅니다.
- **pre-push / CI**: 레포 단위, 느려도 됨, 수정 안 함. 전체를 봅니다.

이 구분이 없으면 커밋마다 전체 테스트가 돌아 아무도 안 씁니다.

### 게이트 선언

`.claude/gates.json` 한 곳에만 씁니다. 스택에 맞는 기본값을 `init.sh`가 깔고, 이후는
프로젝트 것입니다 (재실행해도 덮어쓰지 않습니다).

```json
{
  "gates": [
    {
      "name": "lint (ruff)",
      "cmd": "ruff check .",
      "stages": ["pre-push", "ci"],
      "requires": "ruff",
      "requires_file": "tests",
      "note": "사람이 읽는 설명"
    }
  ]
}
```

| 필드 | 뜻 |
|---|---|
| `stages` | `pre-commit` / `pre-push` / `ci` 중 실행할 시점 |
| `requires` | 이 실행 파일이 없으면 SKIP |
| `requires_file` | 이 경로가 없으면 SKIP (문자열 또는 배열) |
| `allow_failure` | true면 실패해도 계속 |

```bash
python3 .claude/scripts/gate-runner.py --list                    # 목록
python3 .claude/scripts/gate-runner.py --stage pre-push          # 실행
python3 .claude/scripts/gate-runner.py --stage ci --no-fail-fast # 전부 실행
```

**JSON인 이유**: PyYAML은 표준 라이브러리가 아닙니다. 하네스는 남의 레포에 들어가므로,
인터프리터 업그레이드 한 번에 사라질 수 있는 의존성을 게이트 경로에 둘 수 없습니다.
실제로 `~/.claude`의 규칙 레지스트리가 brew python 3.14 업그레이드로 PyYAML을 잃고
전 규칙이 무음 통과한 사례가 있습니다. 주석을 못 쓰는 불편은 `note` 필드로 갚습니다.

### SKIP은 PASS가 아닙니다

도구가 없어 건너뛴 검사를 통과로 세면, 아무것도 설치 안 된 환경에서 전 항목 초록불이
뜹니다. SKIP은 별도로 세고 요약에서 이름까지 다시 부릅니다.

```
  PASS 0 · FAIL 0 · SKIP 3   (총 0.0초)
  ⚠ SKIP 3건은 통과가 아닙니다: lint (ruff), format check (ruff), tests (pytest)
  ⚠ 실행된 게이트가 없습니다 — 이 push 는 아무것도 검증되지 않았습니다.
```

전부 SKIP이면 종료 코드는 0이지만 아무것도 검사하지 않은 것입니다. 도구 없는 머신에서
push를 통째로 막는 건 과하므로 통과시키되, 이 상태를 조용히 넘기지는 않습니다.

### 종료 코드

| 코드 | 뜻 |
|---|---|
| 0 | 전 게이트 통과 (SKIP 포함) |
| 1 | 게이트 실패 — 고쳐야 함 |
| 2 | `gates.json` 손상 등 내부 오류 — 하네스가 깨진 것 |

우회는 `git push --no-verify`로 가능하지만 표면화 대상입니다. 우회했으면 PR 설명에 사유를
남기고, CI에서 같은 게이트가 다시 잡습니다.

---

## 게이트 자가진단 — "조용한 게이트"를 신뢰하지 않기

훅은 대부분 fail-open 입니다. 깨져도 조용히 `exit 0` 하고 세션에는 아무 표시가 없습니다.
그래서 게이트가 조용한 것을 안전으로 읽게 됩니다.

실제로 그랬습니다. `pre-bash-guard.sh` 는 존재하지 않는 `$TOOL_INPUT` 환경변수를 읽고
있었고, `migrate` · `DROP TABLE` · WHERE 없는 `DELETE` 경고가 **한 번도 발화한 적이
없었습니다**. 발화 기록이 없으니 아무도 몰랐습니다.

2026-08-03 실측:

| 입력 방식 | 결과 |
|---|---|
| stdin JSON (Claude Code 실제 방식) | 무음, `exit 0` — 죽어 있음 |
| `TOOL_INPUT` 환경변수 강제 주입 | 경고 정상 출력 — 로직은 멀쩡, 배선만 틀림 |

검사가 0건을 반환하는 것은 안전 신호가 아니라 **스캐너가 깨졌다는 신호일 수 있습니다.**
그래서 세션 시작마다 알려진 케이스로 게이트 자체를 검증합니다.

### positive / negative 쌍으로 판정

한쪽만 보면 안 됩니다. 항상 발화하는 훅도 positive 만으로는 정상 통과합니다.

| 케이스 | 기대 | 위반 시 진단 |
|---|---|---|
| `DROP TABLE ...` | 발화 | 게이트 사망 (무음 통과 중) |
| `git status --short` | 침묵 | 과발화 (아무 때나 떠서 곧 무시당함) |

둘 다 통과해야 "이 게이트는 구분할 줄 안다"가 증명됩니다.

검사 항목은 세 가지입니다.

| 항목 | 판정 |
|---|---|
| `hook-io.py parse` | 페이로드 왕복 — 실패하면 전 훅이 동시에 죽습니다 |
| `pre-bash-guard.sh` | positive/negative 쌍 |
| `domain-gate.py` | 로딩 가능 여부 (짝인 `domain-extract.py` 누락 = 부분 설치 감지) |

실패하면 세션 시작 시 이렇게 뜹니다.

```
🚨 [게이트 자가진단 실패]

  ✗ pre-bash-guard.sh — DROP TABLE 이 통과됨 (게이트 사망: 무음 통과 중)

  위 게이트는 무음 통과 중입니다. 차단이 걸릴 것으로 믿고 작업하지 마세요.
```

통과하면 아무것도 출력하지 않습니다. 수동 점검은 `--verbose` 로 전 항목을 봅니다.

```bash
bash .claude/hooks/gate-selftest.sh --verbose
```

### 발화 기록

게이트의 침묵이 '안전'인지 '고장'인지는 기록이 있어야 구분됩니다. 발화·진단 실패를
`.claude/local/events-YYYY-MM.jsonl` 에 append 합니다 (`.gitignore` 대상, 월별 분할).

```json
{"ts": "2026-08-03T05:34:33+00:00", "event": "gate_fired", "source": "pre-bash-guard.sh",
 "tool": "Bash", "session": "...", "detail": " drop-table |mysql -e \"DROP TABLE users;\""}
```

계측 실패가 게이트를 막아서는 안 되므로 모든 기록 경로는 실패해도 통과합니다.
자가진단이 주입하는 합성 페이로드는 기록하지 않습니다 (실제 발화 통계 오염 방지).

```bash
# 이번 달 무엇이 몇 번 발화했나
python3 -c "import json,collections,sys;print(collections.Counter(json.loads(l)['source'] for l in open(sys.argv[1])))" \
  .claude/local/events-$(date +%Y-%m).jsonl
```

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

JS/TS 환경은 Django 공통 파일(skills, commands, hooks, docs)을 그대로 재사용하고,
에이전트·rules·CLAUDE.md·DOMAIN.md·.coderabbit.yaml·pre-commit·워크플로우(`pr-test.yml`, `post-merge-docs.yml`)만
JS 전용으로 교체됩니다. (`pre-bash-guard.sh` 만 Django migrate 경고를 뺀 JS 버전으로 바뀝니다.)

스택을 감지하지 못하면 위 두 계층 대신 `templates/base-project/` 의 최소 하네스만 깔고
끝냅니다. CLAUDE.md, settings.json, 훅 2개, .gitignore 가 전부이며, 에이전트·게이트·지식
계층은 설치되지 않습니다. `package.json` 이나 `manage.py` 를 만든 뒤 다시 실행하거나
`ENV_TYPE=python|js` 로 명시하면 전체 설치로 넘어갑니다.

훅은 스택 무관입니다. `domain-guard.sh` 가 `domain-gate.py` 에 위임하고, 그 안에서
확장자에 따라 판정 방식이 갈립니다.

---

## 템플릿 구조

```
harness-init/
├── README.md
├── CLAUDE.md                     ← harness-init 자체 개발 가이드
├── CHANGELOG.md                  ← 대상 레포에 도착하는 것 기준의 변경 이력
├── VERSION                       ← 설치 시 .claude/harness-version 에 기록
├── init.sh                       ← 메인 실행 스크립트
├── tests/                        ← 회귀 스위트 (임시 레포에 실제로 init.sh 를 돌린다)
├── templates/
│   ├── base-project/             ← 스택 미감지 시의 최소 하네스 (CLAUDE.md·settings.json·훅 2개)
│   ├── django/                   ← Django/Python 전용 템플릿
│   │   ├── CLAUDE.md             ← 레이어드 아키텍처 규칙 (Views→Services→Repositories)
│   │   ├── .claude/
│   │   │   ├── agents/           ← analyst/architect/coder/tester/reviewer (pytest 기반)
│   │   │   ├── skills/           ← orchestrator + 5개 단독 스킬
│   │   │   ├── commands/
│   │   │   ├── hooks/            ← session-knowledge / pre-bash-guard / domain-guard / insight-collector / notification
│   │   │   ├── rules/            ← knowledge / architecture / testing / domain / agents / hooks (CLAUDE.md @imports)
│   │   │   └── decisions/
│   │   ├── .coderabbit.yaml
│   │   ├── .github/
│   │   └── docs/
│   └── js/                       ← JS/TS 전용 오버라이드 템플릿
│       ├── CLAUDE.md             ← Controller/Service/Repository + TypeScript 규칙
│       ├── DOMAIN.md             ← JS ORM 스키마 안내 (Prisma/TypeORM/Mongoose/Drizzle)
│       ├── .coderabbit.yaml      ← path_instructions 를 JS/TS 규칙으로 교체 (django 판 그대로면)
│       ├── .claude/
│       │   ├── agents/           ← analyst/architect/coder/tester/reviewer (jest 기반)
│       │   ├── rules/            ← architecture / testing / domain / agents / hooks (JS/TS 전용)
│       └── .github/workflows/
│           ├── pr-test.yml               ← Node.js 20 + npm ci + npm test
│           └── post-merge-docs.yml       ← 머지 후 API 문서 갱신 이슈 자동 생성
└── scripts/
    ├── atomic_write.py           ← 원자적 파일 교체 (render-agents·commit-msg·lint-baseline 공용)
    ├── failure-report.py         ← 우회·차단·게이트 실패를 재발 패턴으로 묶는다
    ├── domain-extract.py         ← AST로 Choices·시그널·db_table 추출 (LLM 미사용)
    ├── domain-gate.py            ← 의미 변화 판정, 훅·pre-commit·CI 공용
    ├── domain-freshness.py       ← DOMAIN.md가 소스보다 며칠 뒤처졌는지 측정
    ├── domain-init.sh            ← 앱별 DOMAIN.md 의미 스켈레톤 생성
    ├── domain-fill.sh            ← 시그널 핸들러 본문을 읽어 부수효과만 요약
    ├── codegraph-setup.sh        ← codegraph 인덱싱 + MCP 등록 (선택 의존성)
    ├── lint-baseline.py          ← 기존 레포의 레거시 ruff 위반을 규칙 단위로 유예
    ├── hook-io.py                ← 훅 페이로드 파싱(parse) + 발화 기록(event)
    ├── gate-runner.py            ← 선언된 게이트를 시점별 실행 (pre-push·CI 공용)
    ├── render-agents.py          ← AGENTS.md 자동 구간을 설정에서 렌더
    ├── pr-body.py                ← PR 본문 자동 수집 구간 생성·병합
    ├── commit-msg.py             ← 브랜치의 티켓 번호를 커밋 메시지에 삽입
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
| 공통 정본 (절대 규칙·권한) | 대상 레포의 `AGENTS.md` |
| 공통 정본 템플릿 | `templates/django/AGENTS.md` (JS도 이걸 씀) |
| 게이트 목록 (pre-push·CI) | 대상 레포의 `.claude/gates.json` |
| 게이트 기본값 (Python) | `templates/django/.claude/gates.json` |
| 게이트 기본값 (JS/TS) | `templates/js/.claude/gates.json` |
| 리뷰어 할당 | 대상 레포의 `.github/CODEOWNERS` |
| PR 본문 자동 수집 항목 | `scripts/pr-body.py` |
| 비 Django 스택 설정 | `scripts/migration.sh` → `configure_stack()` |
