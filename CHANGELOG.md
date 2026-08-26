# CHANGELOG

harness-init 은 남의 레포에 주입되고 재실행으로 갱신된다. 그래서 대상 레포에서
"지금 깔린 게 어느 판인가"를 알 수 있어야 한다. 설치 시 `.claude/harness-version`
에 이 파일의 최신 버전이 기록된다.

버전은 **대상 레포에 도착하는 것**을 기준으로 매긴다.

- MAJOR: 기존 설치의 수동 조치가 필요한 변경 (파일 이동, 설정 형식 변경)
- MINOR: 새 게이트·훅·스크립트 추가. 재실행하면 자동으로 따라온다
- PATCH: 동작이 같은 수정. 문서, 주석, 내부 정리

---

## 1.2.0

kimsuhanmu 레포에 실제로 설치해 보고 발견한 세 가지 결함을 고쳤다. 전부 "재실행하면
자동으로 따라온다"는 원칙대로, 기존 설치를 다시 실행하기만 하면 반영된다.

### 수정

- **JS 스택에서 기존 CLAUDE.md 를 통째로 지우던 결함.** `merge-claude-md.sh` 가
  마커 앞에 보존한 프로젝트 고유 내용(서비스 정체성·절대 규칙·진행 상황)을, 그
  직후 JS 오버라이드 단계가 `cp -f templates/js/CLAUDE.md` 로 다시 덮어써
  {project_name} 같은 플레이스홀더투성이 템플릿으로 완전히 사라지게 했다
  (kimsuhanmu 레포 실측 — 통계 기반 작명 서비스라는 정체성과 D9~D18 결정 이력이
  통째로 날아갔다). 이제 마커 이전 구간(사용자 소유)만 보존하고 이후(harness
  소유)만 JS 판으로 교체한다.
- **JS 판 `.gitignore.append` 에 `.codegraph/`·`.claude/scripts/__pycache__/` 가
  빠져 있던 결함.** django 판에만 있었다. 두 판이 같은 범용 블록(harness·AI 도구·
  IDE·macOS·다이어그램·SQL 덤프 등)을 각각 통째로 들고 있던 게 원인이라, 한쪽만
  고치면 다른 쪽이 조용히 낡았다. 범용 항목은 `templates/base-project/.gitignore.append`
  하나로 합치고, django/js 는 스택 고유 델타만 갖는다.

### 변경

- **Gemini Code Assist → CodeRabbit.** Gemini Code Assist 는 개인 사용자 무료
  제공이 끝나 더 이상 쓸 수 없다. `.gemini/config.yaml` + `.gemini/styleguide.md`
  를 `.coderabbit.yaml` 하나로 합쳐 대체했다 (`path_filters` + `path_instructions`).
  `/workflows:gemini-review` 커맨드도 `/workflows:coderabbit-review` 로 교체
  (봇 계정 식별자, 재실행 시 `@coderabbitai resolve` 안내 추가). 1.2.0 이전 설치를
  재실행하면 harness 가 심었던 `.gemini/`·`gemini-review.md` 를 지문으로 식별해
  자동으로 지운다 — 사용자가 직접 만든 동명 설정은 건드리지 않는다.
  (PR 자동 코드 리뷰 워크플로 `claude-code-review.yml` 은 Gemini 가 아니라
  `anthropics/claude-code-action` 기반이라 이번 변경과 무관하다.)

---

## 1.1.0

실패 수집. 지금까지 `.claude/local/events-*.jsonl` 에 쌓이던 건 `gate_fired` 하나,
곧 게이트가 **잘 작동한** 순간의 기록뿐이었다. "무엇이 실제로 방해가 되는가"를
만들 재료가 없었다.

### 추가

- **우회 기록** (`bypass_used`). `git commit/push --no-verify` 와 `SKIP=` 을 감지해
  남긴다. 레포는 이미 "게이트 우회는 금지가 아니라 표면화 대상"이라고 선언하고
  있었는데(AGENTS.md 자동 구간), 표면화하는 코드가 없어 아무도 모르게 우회됐다.
  **막지 않는다.** 막으면 우회의 우회를 학습시킨다.
- **차단 기록** (`gate_blocked`). `domain-guard.sh` 가 exit 2 로 막을 때 남긴다.
  무엇이 몇 번 막았는지를 알아야 과차단하는 게이트를 찾는다.
- **실패 패턴 보고서** (`scripts/failure-report.py`). 쌓인 이벤트를 재발 횟수로
  묶는다. **2회 이상 재발한 것만** 규칙 후보로 올리고 1회는 표시만 한다. 반복
  근거 없이 규칙을 만들면 그 프로젝트에만 맞는 임시방편이 되기 때문이다.

보고서는 규칙을 만들지 않는다. 무엇이 반복되는지만 보여준다. 규칙 레지스트리는
전역(`~/.claude/rules/rules.yaml`)이 소유하고, 하네스는 프로젝트에서 관측한 사실만
공급한다. 이 경계를 넘으면 같은 규칙이 두 곳에서 배달된다.

`gate-runner.py` 는 이미 `gate_run` 에 실패 게이트 목록을 담고 있어 코드 변경이
없다. 보고서가 그 데이터를 함께 읽는다.

우회 판정은 `_hook-input.sh` 의 `hook_report_bypass` 한 곳에 있고 django·js
`pre-bash-guard.sh` 가 함께 부른다. 처음에는 django 판에만 넣어 js 가 빠졌는데,
그게 정확히 이 레포가 파싱을 한 곳에 모은 이유와 같은 실패라 판정도 옮겼다.

---

## 1.0.0

첫 버전 표기. 이전까지는 "최신 main 이 곧 버전"이라 대상 레포에서 무엇이 깔렸는지
알 방법이 없었다.

### 추가

- **회귀 테스트 스위트** (`tests/`). 임시 레포에 실제로 `init.sh` 를 돌리고 디스크에
  남은 결과만 본다. 설치를 흉내 내는 테스트는 "설치했다고 보고했지만 안 깔린" 실패를
  그대로 통과시키기 때문이다.
- **자체 CI** (`.github/workflows/test.yml`). 이 도구는 남에게 CI 를 심어주면서
  정작 자기 자신은 CI 가 없었다.
- **원자적 파일 쓰기** (`scripts/atomic_write.py`). `render-agents.py`,
  `commit-msg.py`, `lint-baseline.py` 가 전부 `open(path, "w")` 로 먼저 잘라내고
  쓰고 있었다. 셋 다 사람이 쓴 파일(AGENTS.md, 커밋 메시지, pyproject.toml)이
  대상이라 중단 시 유실이 되돌릴 수 없다.
- **로컬 훅 부트스트랩 검사** (`gate-selftest.sh`). `.pre-commit-config.yaml` 은
  커밋되지만 `.git/hooks/` 는 전파되지 않아, 새로 clone 한 사람은 설정을 다 받고도
  로컬 게이트 없이 커밋한다. 강제할 방법이 없으므로 크게 알리고 복구 명령을 준다.
- **버전 표기** (`VERSION`, `.claude/harness-version`).

### 수정

- `post-merge-docs.yml` 이 `branches: [dev, prod]` 를 고정해 `main` 을 쓰는 레포에서
  아예 돌지 않았다. 필터를 job 조건으로 옮기고 기준을 `repository.default_branch` 로
  런타임에 읽는다.
- `templates/js/.github/workflows/post-merge-docs.yml` 에 복사 배선이 없어 한 번도
  설치된 적이 없었다. JS 레포에 `views.py` 를 찾는 django 판이 깔려 있었다.

### 문서

- `CLAUDE.md` 디렉토리 트리에 `templates/base-project/` 계층과 scripts 5개가 빠져
  있었다. `README.md` 도 같은 누락.
- `CLAUDE.md` 의 init.sh 단계 목록이 6단계로 적혀 있었으나 실제 단계는 18개.
  순서 제약 표를 추가했다.

위 문서 항목은 전부 `tests/test_docs_consistency.py` 가 고정한다. 손으로 적은 목록은
반드시 낡으므로, 낡았다는 걸 사람이 우연히 읽어서 알아채는 구조를 없앴다.
