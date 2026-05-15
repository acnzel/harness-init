# 테스트 작성 규칙

**CRITICAL**: 테스트 코드 작성 전 반드시 아래 절차를 따를 것.

## Step 1. 모델 분석 (필수 선행)

대상 앱의 모든 모델에서 `@property`, `@cached_property`, annotated field를 목록화하고
writable/read-only 여부를 확인.

## Step 2. Read-only 속성 모킹

```python
# ✅ read-only property → PropertyMock 사용
with patch.object(type(instance), 'prop_name', new_callable=PropertyMock, return_value=val):
    ...

# ❌ 직접 할당 금지 → AttributeError 발생
instance.prop_name = val
```

## Step 3. 테스트 데이터는 Factory만 사용

`utils/factories.py`에 정의된 Factory 클래스만 사용. `Model.objects.create()` 직접 사용 금지.

## 레이어별 테스트 범위

| 레이어 | 무엇을 테스트 | 무엇을 mock |
|-------|-------------|-----------|
| Views | HTTP 응답 코드/본문, Service 호출 여부 | Service 클래스 |
| Services | 비즈니스 로직 분기, Repository 호출 여부 | Repository 클래스 |
| Repositories | 실제 쿼리 결과 | mock 없음 (SQLite 메모리 DB) |
| Serializers | 직렬화/역직렬화 결과 | mock 없음 |

## 실행

```bash
python -m pytest --tb=short -q
```
