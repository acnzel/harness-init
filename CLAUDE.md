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
├── VERSION                 ← 대상 레포의 .claude/harness-version 에 기록되는 값
├── CHANGELOG.md            ← 대상 레포에 도착하는 것 기준으로 버전을 매긴다
├── tests/                  ← 회귀 스위트. 임시 레포에 실제로 init.sh 를 돌린다
├── .github/workflows/      ← 자체 CI (test.yml)
├── templates/
│   ├── base-project/       ← 스택 미감지 시의 최소 하네스 (django/js 와 섞이지 않는다)
│   ├── django/             ← Django/Python 전용 하네스 + 모든 스택의 베이스
│   └── js/                 ← JS/TS 오버라이드 (django/ 위에 덮어쓰기)
└── scripts/
    ├── atomic_write.py     ← 원자적 파일 교체 (사람이 쓴 파일을 덮어쓰는 셋이 공용, 하네스 소유)
    ├── failure-report.py   ← 실패 이벤트를 재발 패턴으로 묶는다 (하네스 소유)
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

각 단계는 `# ── 제목 ──` 마커로 구분된다. 아래 목록의 굵은 글씨가 그 마커 문구다.
줄 번호는 적지 않는다 — 한 줄만 넣어도 전부 밀려서 다음 사람이 못 믿는다.
위치를 찾을 때는 `grep -n '^# ── ' init.sh`.

### 공통 (항상 실행)

1. **환경 선택** — Python / JS·TS / 자동 감지. 비대화형이면 `auto`
2. **Atlassian MCP 연동 여부** — Jira·Confluence MCP 서버를 settings.json 에 넣을지
3. **스택 감지** — `migration.sh --detect` 가 `manage.py`·`package.json` 등으로 판별

### 분기 A — 스택 미감지 (`ENV_TYPE=auto` + `STACK=unknown`)

4. **스택 미감지 — 최소 하네스(base-project)만 설치** — CLAUDE.md·settings.json·훅
   2개·.gitignore 만 깔고 `SKIP_FULL_INSTALL=true` 로 아래 전체를 건너뛴다

### 분기 B — 전체 설치 (`SKIP_FULL_INSTALL` 가드 안)

5. **CLAUDE.md 생성/업데이트** — `merge-claude-md.sh`
6. **.claude 디렉토리 구조 생성** — skills·agents·commands·hooks·rules·scripts·
   gates.json·AGENTS.md·settings.json. 소유권에 따라 `-n` 과 `-f` 가 갈린다 (아래 멱등성 절)
7. **게이트 자가진단 주입** — settings.json 멱등 병합. 기존 설치의 죽은 인라인 훅도 교체
8. **LSP 설정 주입** — 언어별 LSP. 이어서 Atlassian MCP 설정과
   `.coderabbit.yaml`·`.github`·`docs`·`DOMAIN.md` 복사가 같은 구간에 있다
9. **.gitignore 업데이트** — 스택별 `.gitignore.append` 를 추가 (이미 있으면 건너뜀)
10. **pre-commit 설정** — Python: ruff / JS·TS: prettier + eslint. lint baseline 포함
11. **비 Django 스택이면 harness 마이그레이션** — `migration.sh` 가 템플릿 문구를 스택에 맞게 치환
12. **JS 환경 전용 파일 오버라이드** — agents·rules·워크플로·CLAUDE.md·gates.json 등을 JS 판으로
13. **CI 게이트 연결 확인** — 어느 워크플로도 `gate-runner` 를 안 부르면 전용 파일을 하나 추가
14. **버전 기록** — `VERSION` 을 `.claude/harness-version` 에 남긴다. 대상 레포에서
    어느 판이 깔렸는지 확인할 수 있어야 갱신 여부를 판정할 수 있다
15. **AGENTS.md 자동 구간 렌더** — `render-agents.py`
16. **구조 지식 계층 (codegraph)** — 선택 의존성. 없으면 안내만
17. **의미 지식 계층 (DOMAIN.md)** — `domain-init.sh` + `domain-fill.sh`
18. **완료 메시지**
19. **설치 직후 게이트 실측** — `gate-runner --stage pre-push` 를 한 번 돌려 현실을 보여준다

### 순서가 고정된 지점

번호는 참조용이고, 진짜 제약은 아래 네 개다. 새 단계는 이 제약을 깨지 않는 자리에 넣는다.

| 단계 | 반드시 이 뒤에 | 어기면 |
|---|---|---|
| 게이트 자가진단 주입(7) | settings.json 생성(6) | 읽을 파일이 없어 `sys.exit(0)` 으로 조용히 건너뛴다 |
| CI 게이트 연결 확인(13) | `.github` 워크플로 복사(8) | `workflows/` 가 없어 조건문 전체를 지나친다 |
| AGENTS.md 렌더(15) | gates.json 확정(12) | 문서가 JS 교체 전 게이트 목록을 박제한다 |
| 게이트 실측(19) | gates.json 확정(12) | 교체 전 목록으로 돌려 실제와 다른 결과를 보여준다 |

넷 다 **조용한 실패**다. 순서를 어겨도 `init.sh` 는 exit 0 으로 끝나고 완료
메시지까지 출력한다. 새 단계를 넣을 때 위치를 눈으로만 고르지 말 것.

> 단계를 추가하면 이 목록에 함께 적고, 완료 메시지를 출력한다.
> 목록과 `grep -n '^# ── ' init.sh` 결과가 어긋나면 목록이 틀린 것이다 — 이 절은 실제로
> 6단계로 낡아 있었고, 그동안 "번호 순서를 유지하라"는 지시가 가리킬 대상이 없었다.

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
- **여러 스택이 공유하는 판정도 같은 자리에 둔다.** django·js 가 각각 `pre-bash-guard.sh`
  를 갖고 있어서, 한쪽에만 넣으면 다른 쪽이 조용히 낡는다. 우회 감지를 django 판에만
  넣었다가 js 가 빠진 적이 있다 (`hook_report_bypass` 가 그래서 `_hook-input.sh` 에 있다).
  `_hook-input.sh` 는 django 템플릿에서 한 번만 설치되어 양쪽이 함께 쓴다.
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

## 테스트

```bash
python3 -m unittest discover -s tests -t tests -p 'test_*.py'
```

의존성 없이 stdlib 만 쓴다. 스위트는 임시 디렉터리에 **실제로 `init.sh` 를 돌리고**
디스크에 남은 결과만 본다. 설치를 흉내 내면 이 하네스가 없애려는 실패("설치했다고
보고했지만 안 깔린")를 그대로 통과시키기 때문이다.

| 파일 | 고정하는 것 |
|---|---|
| `test_install.py` | 스택별로 무엇이 실제로 도착하는가, 워크플로 계약, 자체 CI |
| `test_idempotency.py` | 재실행 시 사용자 소유 보존 / 하네스 소유 갱신 |
| `test_docs_consistency.py` | 문서의 트리·단계 목록이 실물과 같은가 |
| `test_atomic_write.py` | 쓰기 중단 시 사람이 쓴 파일이 살아남는가 |
| `test_bootstrap.py` | 새 클론에서 로컬 게이트 부재가 발화하는가 |
| `test_failure_collection.py` | 우회·차단이 기록되는가, 보고서가 재발을 가려내는가 |

**새 검사를 추가할 때는 뮤테이션으로 확인한다.** 가드를 되돌렸을 때 실제로 빨간불이
뜨는지 보지 않으면, 아무것도 검증하지 않는 테스트가 초록불로 남는다. 실제로 단계
번호를 망가뜨렸는데 목록 검사가 통과한 적이 있다 (제목만 비교하고 있었다).

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
- [ ] `tests/` 에 회귀 테스트 추가, **뮤테이션으로 발화 확인**
- [ ] 단계를 추가했으면 `CLAUDE.md` 단계 목록과 번호를 함께 갱신 (테스트가 잡는다)
- [ ] `CHANGELOG.md` 에 항목 추가, 필요하면 `VERSION` 증가
