# harness-init

새 프로젝트에 **Harness Engineering** 환경을 자동으로 셋업하는 템플릿 도구입니다.

AI 에이전트(Claude Code)가 신뢰할 수 있는 결과물을 생산하도록, 에이전트를 둘러싼 환경을 프로젝트 시작 시점에 구성합니다.

---

## 개념

**Harness Engineering**이란 AI 에이전트가 일할 수 있는 환경(harness)을 설계하는 방법론입니다.

| 구성 요소 | 이 도구에서 | 역할 |
|-----------|------------|------|
| 지시 아키텍처 | `CLAUDE.md` | 에이전트에게 프로젝트 맥락 제공 |
| 실행 절차 | `.claude/skills/` | 작업 유형별 실행 방법 정의 |
| 컨텍스트 관리 | `.claude/tasks/`, `docs/superpowers/` | 장기 작업 상태 유지 |
| 아키텍처 기록 | `.claude/decisions/` | ADR로 의사결정 누적 |
| 품질 강제 | `.gitignore` | 로컬 임시 파일 git 제외 |

---

## 워크플로우

```
1. 브레인스토밍       →  docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md
   /brainstorm

2. 계획 작성          →  docs/superpowers/plans/YYYY-MM-DD-<feature>.md
   /writing-plans

3. 자율 실행          →  위 두 파일을 읽고 완성까지 루프
   /autopilot
```

---

## 설치

```bash
# 아무 위치에 clone
git clone https://github.com/yourname/harness-init.git ~/harness-init

# (선택) PATH에 추가
echo 'export PATH="$HOME/harness-init:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

---

## 사용법

### 기본 (스택 자동 감지)

```bash
cd ./my-new-project
bash ~/harness-init/init.sh
```

`requirements.txt` / `pyproject.toml` / `manage.py` → Django 자동 감지. 그 외는 base로 폴백.

### 스택 명시

```bash
bash ~/harness-init/init.sh django
bash ~/harness-init/init.sh base   # 스택 무관 공통만
```

### 실행 결과

```
my-new-project/
├── CLAUDE.md                    ← 생성 또는 업데이트
├── .gitignore                   ← .claude/local/ 추가
└── .claude/
    ├── tasks/                   ← 작업 상태 파일 저장소
    ├── decisions/               ← ADR 문서 저장소
    │   └── adr-template.md
    └── skills/
        ├── explore.md           ← /explore
        ├── implement.md         ← /implement
        ├── debug.md             ← /debug
        ├── review.md            ← /review
        └── autopilot.md        ← /autopilot
```

---

## 스킬 사용법

초기화 후 Claude Code에서 아래 명령어를 사용할 수 있습니다.

### `/explore`
코드베이스 구조 파악이 필요할 때.
```
코드베이스를 /explore 해줘
```

### `/implement`
새 기능 구현 시 체계적인 절차로 진행.
```
결제 모듈을 /implement 해줘
```

### `/debug`
버그나 오류 발생 시 근본 원인 추적.
```
로그인이 안 되는 문제를 /debug 해줘
```

### `/review`
코드 변경 후 검토.
```
방금 작성한 코드를 /review 해줘
```

### `/autopilot`
PRD와 구현 계획이 있을 때 완성까지 자율 실행.
```
/autopilot

또는

docs/superpowers/plans/2026-03-28-auth.md 읽고 /autopilot으로 완성해줘
```

---

## ADR 작성법

아키텍처 결정 사항은 `.claude/decisions/`에 기록합니다.

```bash
# 템플릿 복사
cp .claude/decisions/adr-template.md .claude/decisions/001-auth-strategy.md
```

ADR이 누적되면 에이전트가 과거 결정을 참고해 일관된 방향으로 작업합니다.

---

## 전체 워크플로우 예시

```bash
# 1. 새 프로젝트 생성
mkdir my-saas && cd my-saas
git init

# 2. harness 초기화

# 3. Claude Code 실행 후 브레인스토밍
# > /brainstorm
# → docs/superpowers/specs/2026-03-28-my-feature-design.md 저장됨

# 4. 구현 계획 작성
# > /writing-plans
# → docs/superpowers/plans/2026-03-28-my-feature.md 저장됨

# 5. 자율 실행
# > /autopilot
# → 계획의 모든 체크박스 완료 + 빌드 통과까지 루프
```

---

## 템플릿 구조

```
harness-init/
├── README.md
├── init.sh                      # 메인 실행 스크립트
├── templates/
│   ├── base/                    # 스택 무관 공통 템플릿
│   └── django/                  # Django 추가 내용
└── scripts/
    ├── detect-stack.sh          # 스택 자동 감지
    └── merge-claude-md.sh       # CLAUDE.md 합치기
```

---

## 커스터마이징

`templates/base/CLAUDE.md`를 수정하면 모든 새 프로젝트에 적용됩니다.
스택별 내용은 `templates/django/CLAUDE.md`를 수정하세요.
