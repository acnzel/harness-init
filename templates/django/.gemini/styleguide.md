# Django 백엔드 코드 스타일 가이드

이 문서는 Gemini Code Assist가 코드 리뷰 시 참조할 프로젝트 스타일 가이드입니다.

## Critical Rules (반드시 준수)

### 1. Layered Architecture
**Views → Services → Repositories** 의존성 순서 엄수:

```python
# Good
class MyView(APIView):
    service = MyService()

    def get(self, request):
        return self.service.get_data(request.user)

# Bad - View에서 직접 DB 접근
class MyView(APIView):
    def get(self, request):
        return MyModel.objects.filter(user=request.user)  # 금지!
```

### 2. Test Data Creation
테스트 데이터 생성 시 반드시 `utils/factories.py`의 Factory 사용:

```python
# Good
item = ItemFactory(status="active")

# Bad
item = Item.objects.create(status="active")  # 금지!
```

### 3. Pre-commit Hooks
커밋 전 반드시 통과해야 하는 검사:

```bash
isort --profile black
black
mypy --strict
```

## Layered Architecture

```
{app_name}/
├── views.py          # HTTP 요청/응답 처리
├── services.py       # 비즈니스 로직 처리
├── repositories.py   # 데이터베이스 접근
├── serializers.py    # 데이터 직렬화/역직렬화
├── models.py
└── urls.py
```

### 의존성 규칙

**금지 사항**:
1. 역방향 의존성: 하위 레이어가 상위 레이어 호출 금지
2. 레이어 건너뛰기: Views가 Repositories 직접 호출 금지
3. 순환 의존성: 레이어 간 순환 참조 금지

## Type Hints (필수)

모든 함수와 메서드에 타입 힌트 필수 (mypy strict mode):

```python
# Good
def get_item_by_id(self, item_id: int) -> Item:
    pass

# Bad
def get_item_by_id(self, item_id):  # mypy 에러 발생
    pass
```

## Validator 패턴

복잡한 비즈니스 검증 로직은 별도 Validator 클래스로 분리:

```python
class ItemValidator:
    def __init__(self, item: Item, user: User) -> None:
        self.item = item
        self.user = user

    def validate(self) -> None:
        if self._상태가_유효하지_않은가():
            raise ValidationError("상태가 유효하지 않습니다.")

    def _상태가_유효하지_않은가(self) -> bool:
        return self.item.status not in ["active", "pending"]
```

## Error Handling

```python
# Good - 구체적인 예외 처리
try:
    item = Item.objects.get(pk=pk)
except Item.DoesNotExist:
    return Response({"message": "존재하지 않습니다."}, status=400)

# Bad - 예외 무시
except Item.DoesNotExist:
    pass  # 금지!
```

## QuerySet 최적화

```python
# Good - N+1 문제 해결
items = Item.objects.select_related('user').all()

# Bad - N+1 문제 발생
items = Item.objects.all()
for item in items:
    print(item.user.email)  # 매번 추가 쿼리 발생
```

## 네이밍 컨벤션
- **클래스**: PascalCase (`ItemService`, `ItemRepository`)
- **함수/메서드**: snake_case (`get_item_by_id`)
- **상수**: UPPER_SNAKE_CASE (`MAX_RETRY_COUNT`)
- **private 메서드**: underscore prefix (`_validate_input`)
- **복잡한 private 메서드**: 한글 사용 가능 (`_상태가_유효하지_않은가`)

## 커밋 메시지 형식

```
[{TICKET-ID}] type: 설명

예시:
[DEV-1234] feat: 아이템 조회 API 추가
[DEV-1234] fix: N+1 쿼리 문제 해결
[DEV-1234] refactor: 리뷰 피드백 반영
[DEV-1234] test: 경계값 테스트 케이스 추가
```

## 리뷰 코멘트 레벨

| 레벨 | 설명 |
|------|------|
| **L1 - 요청사항** | 반드시 수정 필요 (보안, 버그, 아키텍처 위반) |
| **L2 - 권고사항** | 강력히 권장 (N+1, 성능 이슈) |
| **L3 - 질문사항** | 의도 확인 필요 |
| **L4 - 변경제안** | 더 나은 방법 제안 |
| **L5 - 참고의견** | 가벼운 제안 (스타일, 네이밍) |
