# CLAUDE.md

{project_name} — Django {version} / {deployment_info}

## 코딩 원칙

### 1. 코딩 전에 생각하라
- 가정을 명시적으로 밝히고, 불확실하면 질문하라.
- 여러 해석이 가능하면 조용히 하나를 고르지 말고 선택지를 제시하라.
- 더 단순한 방법이 있으면 말하라. 필요하면 반론하라.
- 혼란스러우면 멈추고, 무엇이 불명확한지 짚어라.

### 2. 단순함 우선
- 요청받은 것만 구현. 추측성 기능, 불필요한 추상화, 불가능한 시나리오의 에러 처리 금지.
- 200줄로 쓴 코드가 50줄로 가능하면 다시 써라.
- "시니어 엔지니어가 과하다고 할까?" — 그렇다면 단순화하라.

### 3. 외과적 변경
- 요청과 직접 관련된 코드만 수정. 인접 코드 "개선", 포맷팅, 리팩토링 금지.
- 기존 스타일에 맞춰라. 본인 스타일이 달라도.
- 내 변경으로 생긴 미사용 import/변수/함수만 제거. 기존 데드코드는 언급만 하고 삭제하지 마라.
- **테스트**: 변경된 모든 줄이 사용자 요청에 직접 연결되어야 한다.

### 4. 목표 기반 실행
- 작업을 검증 가능한 목표로 변환:
  - "검증 추가" → "잘못된 입력 테스트 작성 후 통과시키기"
  - "버그 수정" → "재현 테스트 작성 후 통과시키기"
  - "리팩토링" → "전후 테스트 통과 확인"
- 멀티스텝 작업은 단계별 검증 기준을 명시하라.

## 절대 금지 사항

| 규칙 | 이유 |
|------|------|
| Views에서 DB 직접 접근 금지 | Service 레이어를 통해서만 접근 |
| Services에서 DB 직접 접근 금지 | Repository를 통해서만 접근 |
| 레이어 건너뛰기 금지 | Views → Services → Repositories 순서 엄수 |
| `Model.objects.create()` 테스트 금지 | `utils/factories.py`의 Factory만 사용 |
| `git push --force`, `git reset --hard` 금지 | 이력 손실 위험 |

## 레이어드 아키텍처

참조 구현 앱(`{reference_app}`)을 기준으로 새 기능을 작성. 의존성: **Views → Services → Repositories** (역방향/건너뛰기 금지)

**예외: 크론/배치 함수** — 크론 함수는 레이어드 아키텍처를 따르지 않는다. 직접 ORM 접근을 허용하며, 기존 크론 함수 패턴을 따른다.

```
{app_name}/
├── views.py          # HTTP 요청/응답만. Service 호출만 허용
├── services.py       # 비즈니스 로직. Repository 호출만 허용
├── repositories.py   # DB 접근 전담. 순수 쿼리만
├── serializers.py    # 직렬화/역직렬화만. 비즈니스 로직 금지
├── models.py
└── urls.py
```

## 환경 설정

| 환경 | 모듈 | 비고 |
|------|------|------|
| local | `{project}.settings.local` | |
| dev | `{project}.settings.dev` | |
| prod | `{project}.settings.prod` | |
| test | `{project}.settings.test` | SQLite 메모리 DB |

## 테스트 작성 규칙

**CRITICAL**: 테스트 코드 작성 전 반드시 아래 절차를 따를 것.

### Step 1. 모델 분석 (필수 선행)
대상 앱의 모든 모델에서 `@property`, `@cached_property`, annotated field를 목록화하고 writable/read-only 여부를 확인.

### Step 2. Read-only 속성 모킹
```python
# ✅ read-only property → PropertyMock 사용
with patch.object(type(instance), 'prop_name', new_callable=PropertyMock, return_value=val):
    ...

# ❌ 직접 할당 금지 → AttributeError 발생
instance.prop_name = val
```

### Step 3. 테스트 데이터는 Factory만 사용
`utils/factories.py`에 정의된 Factory 클래스만 사용. `Model.objects.create()` 직접 사용 금지.

### 레이어별 테스트 범위

| 레이어 | 무엇을 테스트 | 무엇을 mock |
|-------|-------------|-----------|
| Views | HTTP 응답 코드/본문, Service 호출 여부 | Service 클래스 |
| Services | 비즈니스 로직 분기, Repository 호출 여부 | Repository 클래스 |
| Repositories | 실제 쿼리 결과 | mock 없음 (SQLite 메모리 DB) |
| Serializers | 직렬화/역직렬화 결과 | mock 없음 |

## 하네스 (에이전트 팀)

이 프로젝트에는 Django 백엔드 전용 5인 에이전트 팀이 구성되어 있다. 기능 개발, 유지보수 작업 시 이 팀을 호출한다.

### 트리거 조건

다음 상황에서 반드시 `orchestrator` 스킬을 실행한다:

- 티켓 번호와 함께 "구현해줘 / 처리해줘 / 작업해줘" 요청
- Django 앱의 기능 추가·수정
- 레이어드 아키텍처 준수가 중요한 유지보수 작업 (버그 수정 포함)
- "하네스 팀 실행", "백엔드 팀으로 처리" 등 명시적 호출
- 이전 실행 결과를 수정·재실행·보완하는 요청 (예: "테스트 다시 써", "리뷰 재실행")

### 팀 구성 (파이프라인 + 생성-검증 루프)

```
analyst → architect → coder ⇄ tester → reviewer
```

| 팀원 | 파일 | 역할 |
|------|------|------|
| analyst | `.claude/agents/analyst.md` | 영향 범위 식별, 모델 선행 분석 |
| architect | `.claude/agents/architect.md` | Views/Services/Repositories 설계, 테스트 전략 |
| coder | `.claude/agents/coder.md` | 실제 코드 작성 (레이어 엄수) |
| tester | `.claude/agents/tester.md` | Factory/PropertyMock 기반 pytest 작성 |
| reviewer | `.claude/agents/reviewer.md` | CLAUDE.md 규칙·레이어 경계 검증 (PR 게이트) |

오케스트레이터 스킬: `.claude/skills/orchestrator/SKILL.md`

### 제외 조건 (이 팀을 쓰지 말 것)

- 단순 typo·주석 1~2줄 수정 → 직접 편집
- PR 리뷰만 → `/review` 커맨드

## 하네스 변경 이력

| 날짜 | 변경 내용 | 대상 | 사유 |
|------|----------|------|------|
