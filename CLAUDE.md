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
│   ├── django/             ← Django/Python 전용 하네스
│   └── js/                 ← JS/TS 전용 하네스 (django/ 위에 오버라이드)
└── scripts/
    ├── domain-init.sh      ← DOMAIN.md 스켈레톤 생성
    ├── domain-fill.sh      ← Claude Code로 DOMAIN.md 채우기
    ├── migration.sh        ← 비 Django 스택 마이그레이션
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
| Python 공통 | `templates/django/` | 프로젝트 루트에 복사 |
| JS 오버라이드 | `templates/js/` | `templates/django/` 위에 덮어쓰기 |

새 스택을 추가할 때는 `templates/{stack}/`을 만들고 `migration.sh`의 `configure_stack()` 함수에 분기를 추가한다.

---

## 전역 자기강화 루프 (제거됨)

세션 교훈 루프(debrief-guardrails + session 훅)는 사용자 전역의 weekly-retro 체계로 대체되어 harness-init은 더 이상 `~/.claude/`에 파일·훅을 설치하지 않는다. **같은 루프를 두 곳에서 설치하는 기능을 재도입하지 말 것.**

전역 체계는 2026-07-14에 규칙 레지스트리 구조로 바뀌었다:

- 교훈은 `~/.claude/rules/rules.yaml` 한 곳에 산다. `/weekly-retro`가 승인된 교훈을 **티어**와 함께 기록한다.
- 티어는 전달 방식을 정한다 — `deny`(PreToolUse 차단) / `advise`(해당 도구를 쓰는 순간에만 주입, 5분 쿨다운) / `core`(항상 로드, **상한 7개**) / `archive`(보존만).
- `~/.claude/CLAUDE.md`의 `반복 교훈` 블록은 `core` 티어에서 **자동 생성**된다. 손으로 쓰지 않는다.
- 전달은 `~/.claude/hooks/rules-dispatcher.py`(PreToolUse)가 담당한다.

**harness-init은 이 중 무엇도 설치하지 않는다.** 전역 체계는 `~/.claude` 저장소가 머신 간에 전파하고, harness-init은 프로젝트별 `.claude/` 스캐폴딩만 담당한다. 이 경계를 넘지 말 것 — 넘는 순간 같은 규칙이 두 곳에서 배달된다.

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
- 모든 파일 복사는 `-n` (no-overwrite) 플래그 사용. 재실행 시 기존 설정 파괴 금지.
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
