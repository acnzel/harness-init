# CHANGELOG

harness-init 은 남의 레포에 주입되고 재실행으로 갱신된다. 그래서 대상 레포에서
"지금 깔린 게 어느 판인가"를 알 수 있어야 한다. 설치 시 `.claude/harness-version`
에 이 파일의 최신 버전이 기록된다.

버전은 **대상 레포에 도착하는 것**을 기준으로 매긴다.

- MAJOR: 기존 설치의 수동 조치가 필요한 변경 (파일 이동, 설정 형식 변경)
- MINOR: 새 게이트·훅·스크립트 추가. 재실행하면 자동으로 따라온다
- PATCH: 동작이 같은 수정. 문서, 주석, 내부 정리

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
