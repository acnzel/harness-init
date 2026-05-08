## 절대 금지 사항

| 규칙 | 이유 |
|------|------|
| Views에서 DB 직접 접근 금지 | Service 레이어를 통해서만 접근 |
| Services에서 DB 직접 접근 금지 | Repository를 통해서만 접근 |
| 레이어 건너뛰기 금지 | Views → Services → Repositories 순서 엄수 |
| `Model.objects.create()` 테스트 금지 | `utils/factories.py`의 Factory만 사용 |
| `git push --force`, `git reset --hard` 금지 | 이력 손실 위험 |

## 레이어드 아키텍처

참조 구현 앱을 기준으로 새 기능을 작성. 의존성: **Views → Services → Repositories** (역방향/건너뛰기 금지)

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

## 하네스 변경 이력

| 날짜 | 변경 내용 | 대상 | 사유 |
|------|----------|------|------|
