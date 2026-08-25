# CLAUDE.md — harness-init

harness-init 자체 개발 가이드. `init.sh` 수정, 템플릿 추가, 훅 작성 시 참조한다.

---

## 프로젝트 목적

AI 에이전트(Claude Code)가 신뢰할 수 있는 결과물을 생산하도록, **에이전트 팀·규칙·도메인 지식·자기강화 루프**를 프로젝트에 주입하는 셋업 도구.

---

## 디렉토리 구조

```
harness-init/
├── init.sh                 ← 메인 실행 진입점. 스택 감지 → 분기 → 설치 순서
├── templates/
│   ├── base-project/       ← 스택 미감지 시의 최소 하네스 (django/js 와 섞이지 않는다)
│   ├── django/             ← Django/Python 전용 하네스 + 모든 스택의 베이스
│   └── js/                 ← JS/TS 오버라이드 (django/ 위에 덮어쓰기)
└── scripts/
    ├── domain-init.sh      ← DOMAIN.md 스켈레톤 생성
    ├── domain-fill.sh      ← Claude Code로 DOMAIN.md 채우기
    ├── domain-extract.py   ← Choices·db_table·시그널 AST 추출 (stdlib ast, LLM 미사용)
    ├── domain-gate.py      ← 의미 변화 감지 게이트 (pre-commit·PostToolUse, 하네스 소유)
    ├── domain-freshness.py ← DOMAIN.md 신선도 리포트 (SessionStart 주입, 하네스 소유)
    ├── hook-io.py          ← 훅 페이로드 파싱 + 발화 기록 (전 훅 공용, 하네스 소유)
    ├── gate-runner.py      ← 선언된 게이트를 시점별 실행 (pre-push·CI 공용, 하네스 소유)
    ├── render-agents.py    ← AGENTS.md 자동 구간 렌더 (하네스 소유)
    ├── pr-body.py          ← PR 본문 자동 수집 구간 (하네스 소유)
    ├── commit-msg.py       ← 커밋 메시지 티켓 삽입 (하네스 소유)
    ├── lint-baseline.py    ← 기존 레포에 ruff 를 처음 켤 때의 규칙 단위 유예 생성
    ├── codegraph-setup.sh  ← 구조 지식 계층 배선 (선택 의존성, 없으면 안내만)
    ├── migration.sh        ← 스택 감지 + 비 Django 스택 마이그레이션
    └── merge-claude-md.sh  ← CLAUDE.md 주입 헬퍼
```

---

## init.sh 구조 (단계 순서)

1. **환경 선택** — Python / JS·TS / 자동 감지
2. **스택 감지** — `manage.py`, `package.json` 등으로 기술 스택 판별
3. **하네스 설치** — `templates/django/` 또는 `templates/js/` 복사
4. **pre-commit 설치** — Python: ruff, JS·TS: prettier + eslint
5. **스택 마이그레이션** — `migration.sh`로 비 Django 스택 적응
6. **DOMAIN.md 생성** — `domain-init.sh` + `domain-fill.sh`

> 단계를 추가할 때는 반드시 기존 단계 번호 순서를 유지하고, 완료 메시지를 출력하라.

---

## 템플릿 계층

| 계층 | 경로 | 적용 방식 |
|------|------|----------|
| 최소 하네스 | `templates/base-project/` | 스택 미감지 시에만. CLAUDE.md·settings.json·훅 2개·.gitignore 로 끝내고 전체 설치를 건너뛴다 |
| Python 공통 | `templates/django/` | 프로젝트 루트에 복사 |
| JS 오버라이드 | `templates/js/` | `templates/django/` 위에 덮어쓰기 |

`base-project/` 는 오버라이드 계층이 아니라 **분기**다. 스택을 못 찾았을 때 `init.sh` 가
여기까지만 깔고 `SKIP_FULL_INSTALL` 로 빠져나간다. 감지되는 스택에는 쓰이지 않는다.

`js/` 는 오버라이드라 **`js/` 에 없는 파일은 `django/` 것이 그대로 간다**. 그래서
`AGENTS.md` 와 `.claude/settings.json` 은 `templates/js/` 에 두지 않는다. settings.json 의
JS 차이는 `migration.sh` 의 `migrate_settings()` 가 Django 전용 deny 항목을 걷어내고
`init.sh` 가 LSP 설정을 주입하는 것으로 처리한다. JS 에서만 다른 파일이 아니면 `js/` 에
복사본을 만들지 말 것.

**단, `js/` 에 파일을 두는 것만으로는 설치되지 않는다.** `.claude/agents`·`rules` 는
디렉터리 통째로 복사되지만 `.github/workflows/` 는 파일마다 `init.sh` 의 JS 오버라이드
구간에 `cp -f` 한 줄을 명시해야 한다. 빠뜨리면 그 템플릿은 죽은 파일이 되고 대상 레포에는
django 판이 깔린 채 조용히 오작동한다 (`post-merge-docs.yml` 이 실제로 그 상태였다).

새 스택을 추가할 때는 `templates/{stack}/`을 만들고 `migration.sh`의 `configure_stack()` 함수에 분기를 추가한다.

---

## 전역 자기강화 루프 (제거됨)

세션 교훈 루프(debrief-guardrails + session 훅)는 사용자 전역의 weekly-retro 체계로 대체되어 harness-init은 더 이상 `~/.claude/`에 파일·훅을 설치하지 않는다. **같은 루프를 두 곳에서 설치하는 기능을 재도입하지 말 것.**

전역 체계는 규칙 레지스트리 구조다:

- 교훈은 `~/.claude/rules/rules.yaml` 한 곳에서 관리된다. `/weekly-retro`가 승인된 교훈을 **티어**와 함께 기록한다.
- 티어는 전달 방식을 정한다 — `deny`(PreToolUse 차단) / `advise`(해당 도구를 쓰는 순간에만 주입, 5분 쿨다운) / `core`(항상 로드, **상한 7개**) / `archive`(보존만).
- `~/.claude/CLAUDE.md`의 `반복 교훈` 블록은 `core` 티어에서 **자동 생성**된다. **직접 편집하지 말 것** — `build`가 덮어쓴다.
- 전달은 `~/.claude/hooks/rules-dispatcher.py`(PreToolUse)가 담당한다.

**harness-init은 이 중 무엇도 설치하지 않는다.** 전역 체계는 `~/.claude` 저장소가 머신 간에 전파하고, harness-init은 프로젝트별 `.claude/` 스캐폴딩만 담당한다. 이 경계를 넘지 말 것 — 넘는 순간 같은 규칙이 두 곳에서 배달된다.

### 훅 작성 규칙

**훅 입력은 stdin JSON 이다.** `$TOOL_INPUT` 같은 환경변수는 존재하지 않는다. 이걸 읽는
훅은 조용히 아무것도 감지하지 못한 채 통과하며, 발화 기록이 없으면 아무도 모른다
(pre-bash-guard.sh 가 실제로 그 상태였다 — 2026-08-03 실측 확인).

- 파싱은 `_hook-input.sh` 의 `hook_input_load` 에만 둔다. 훅에서 직접 JSON 을 까지 말 것 —
  훅마다 각자 파싱하면 같은 불일치가 재발한다.
- `settings.json` 에 **인라인 셸 훅을 넣지 말 것**. JSON 이스케이프 안에서는 stdin 파싱이
  불가능해 필연적으로 환경변수를 읽게 된다. 파일 훅으로 만들고 경로만 등록한다.
- 새 게이트를 추가하면 `gate-selftest.sh` 에 **positive/negative 쌍**을 함께 추가한다.
  한쪽만 검사하면 항상 발화하는 훅도 정상으로 통과한다. 발화 증명 없는 게이트는
  없는 게이트와 같다.
- 판정기·헬퍼 경로는 `CLAUDE_PROJECT_DIR` 이 아니라 **스크립트 자신의 위치**에서 찾는다
  (`$(dirname "${BASH_SOURCE[0]}")`). 그 변수는 비어 있거나 다른 곳을 가리킬 수 있고,
  그러면 헬퍼를 못 찾은 채 조용히 통과한다.
- 계측(`hook_event`)은 실패해도 게이트를 막지 않는다. 항상 `|| true` 로 끝낸다.

### 문서 정본 규칙

- 같은 규칙을 두 파일에 적지 않는다. 정본 한 곳을 두고 나머지는 **참조**한다.
- 참조가 불가능한 소비자(파일 참조를 못 따라가는 리뷰 봇 등)에게는 **생성**으로 준다.
  손으로 옮겨 적는 것은 마지막 수단이고, 그때는 정본 관계를 파일 상단에 명시한다.
- `AGENTS.md` = 전 에이전트 공통 정본 / `CLAUDE.md` = Claude 전용 보충.
  플랫폼 파일에만 중요한 안전 규칙을 새로 만들지 않는다 — 다른 에이전트가 못 읽는다.
- 자동 구간에 항목을 추가하려면 `scripts/render-agents.py` 를 고친다. 그 구간을 손으로
  편집하면 다음 커밋에서 덮어쓰인다.
- 마커를 다루는 코드는 **한 쌍이 아니면 덮어쓰지 않는다**. 잘못 자르면 사람이 쓴 내용이
  유실되고, 그건 되돌릴 수 없다.

### 게이트 파이프라인 규칙

검사는 시점(stage)별로 주인이 하나씩이다. 새 검사를 추가할 때 어디에 둘지 먼저 정한다.

- **pre-commit** — 파일 단위·빠름·자동수정. `.pre-commit-config.yaml` 이 담당한다.
- **pre-push / ci** — 레포 단위·느려도 됨·수정 안 함. `.claude/gates.json` 이 담당한다.

이 구분이 없으면 커밋마다 전체 테스트가 돌아 아무도 안 쓴다.

- pre-push 와 ci 는 **같은 러너·같은 선언**을 쓴다. 한쪽에만 검사를 추가하지 말 것 —
  그 순간 "로컬은 통과했는데 CI 가 깨지는" 드리프트가 시작된다.
- `.pre-commit-config.yaml` 에 `default_stages: [pre-commit]` 을 반드시 유지한다.
  pre-commit 3.x 부터 stages 미지정 훅은 pre-push 를 포함한 모든 시점에서 돈다.
- pre-push 훅에는 `verbose: true` 를 유지한다. pre-commit 은 성공한 훅의 stdout 을
  삼키므로, 이게 없으면 "SKIP 은 통과가 아니다" 경고가 전달되지 않는다.
- 기본 게이트는 **첫날 초록불이 뜨는 것**으로만 구성한다. 깔자마자 빨간불이면 사람들이
  하네스를 통째로 끈다. 대상이 없는 검사는 `requires`·`requires_file` 로 SKIP 시킨다.
- 게이트 선언(`gates.json`)은 사용자 소유, 러너(`gate-runner.py`)는 하네스 소유다.

### PR·CI 자동화 규칙

- CI 워크플로에 검사 명령을 직접 적지 않는다. `gate-runner --stage ci` 만 부르고
  목록은 `gates.json` 에 둔다. 워크플로에 적는 순간 로컬과 갈라진다.
- 워크플로의 `branches:` 를 고정하지 않는다. 주입 대상의 기본 브랜치를 알 수 없다.
  `[dev]` 하드코딩 때문에 PR 워크플로가 통째로 안 돌던 전례가 있다.
- PR 본문·문서를 **덮어쓰지 않는다**. 마커 사이만 갱신하고, 마커가 손상되면 잘라내지
  말고 덧붙인다. 사람이 쓴 내용의 유실은 되돌릴 수 없다.
- 자동 생성에 LLM 을 쓰지 않는다. git·설정에서 얻는 사실만 적는다. 환각이 섞이면
  자동 구간 전체의 신뢰가 사라진다.
- 커밋을 막는 훅은 신중하게 넣는다. 정상 작업을 막으면 `--no-verify` 를 학습시키고,
  그러면 그 훅만이 아니라 같은 단계의 모든 게이트가 함께 꺼진다.
- `pull_request_target` 은 쓰지 않는다. fork PR 에서 시크릿이 노출된다. 권한이 필요하면
  fork 여부로 건너뛴다.

### settings.json 병합 규칙

프로젝트 `.claude/settings.json`에 훅/LSP 설정을 추가할 때 `python3`으로 JSON 병합:
- 기존 hooks 배열이 있으면 append (중복 체크 필수)
- 파일이 없으면 최소 구조로 신규 생성
- `jq` 의존성 금지 — `python3`만 사용

---

## 코딩 원칙

### 외과적 변경
- `init.sh` 수정 시 해당 단계만 수정. 다른 단계 포맷·변수명 정리 금지.
- 기존 변수명과 함수명 스타일을 따른다.

### 멱등성 (Idempotency)
- **사용자 소유** 파일 복사는 `-n` (no-overwrite). 재실행 시 기존 설정 파괴 금지.
- **하네스 소유** 파일은 반대로 `cp -f` 로 덮어쓴다. 사용자가 편집하는 설정이 아니라
  훅·pre-commit·에이전트가 함께 호출하는 코드라, 버전이 어긋나면 게이트가 조용히
  오작동한다. `-n` 이면 버그를 고쳐도 기존 설치에 영원히 전파되지 않는다 —
  실제로 pre-bash-guard.sh 의 `$TOOL_INPUT` 버그가 그렇게 방치됐다 (2026-08-03).
  - `.claude/scripts/*.py` 전부
  - `.claude/hooks/` 중 init.sh 의 `_owned` 목록에 있는 것
  - 목록 밖의 `.sh` 는 사용자가 추가한 훅이므로 `-n` 이 보존한다
- settings.json 처럼 사용자 편집과 하네스 등록이 섞이는 파일은 덮어쓰지 말고
  python3 로 **멱등 병합**한다 (`_inject_gate_selftest` 참조).
- 디렉토리 생성은 `mkdir -p` 사용.

### 에러 처리
- 필수 도구(git, python3) 없으면 명확한 메시지 출력 후 종료.
- Claude Code CLI 없어도 domain-fill.sh 건너뛰고 계속 진행 (선택 기능).

### 의존성
- `bash`, `git`, `python3` — 필수
- `pre-commit`, `claude` CLI — 선택 (없으면 해당 단계 skip)
- `jq` — 금지 (python3으로 대체)

---

## 새 기능 추가 체크리스트

- [ ] `init.sh`에 단계 추가 (번호 순서 유지)
- [ ] 해당 템플릿 파일을 `templates/` 적절한 계층에 배치
- [ ] README.md의 "설치 결과" 트리와 "템플릿 구조" 섹션 업데이트
- [ ] README.md에 기능 설명 섹션 추가
- [ ] CLAUDE.md(harness-init 자체)의 관련 섹션 업데이트
- [ ] 멱등성 확인 (재실행해도 안전한지)
- [ ] 게이트·훅을 추가했으면 `gate-selftest.sh` 에 positive/negative 쌍 추가
- [ ] 기존 설치에도 전파되는지 확인 (하네스 소유면 `cp -f`, settings.json 이면 멱등 병합)
