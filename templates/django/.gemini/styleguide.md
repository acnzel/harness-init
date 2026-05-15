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
ruff check --fix   # E/F 린트 + I(isort) import 정렬
ruff format        # black-compatible 포매터
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

## KISS / YAGNI / DRY — 리뷰 원칙

Gemini는 아래 원칙에 따라 **과도한 추상화 제안을 자제**해야 합니다.

### 제안하지 말아야 할 것 (SKIP)

| 원칙 | 금지 패턴 | 이유 |
|------|-----------|------|
| **YAGNI** | 1곳에서만 쓰이는 코드에 추상화 추가 | 미래 대비 설계는 지금 필요하지 않음 |
| **YAGNI** | 아직 없는 Factory/Helper 클래스 신규 생성 요구 | 2곳 이상 사용될 때 분리 |
| **YAGNI** | "나중에 필요할 수도 있으니" 방어 설계 제안 | 현재 요구사항만 구현 |
| **KISS** | 단순한 코드를 복잡하게 만드는 리팩토링 제안 | 50줄짜리를 100줄로 만들면 퇴보 |
| **KISS** | 가능한 시나리오가 없는 에러 핸들링 추가 | 불필요한 방어 코드 금지 |
| **DRY** | 중복 제거가 오히려 복잡성을 높이는 경우 | KISS 우선 |

### 헬퍼 클래스 / 상수 분리 기준 (LOW Priority)

헬퍼 클래스나 상수는 **2곳 이상에서 사용될 때** 별도 파일로 분리합니다.
단일 View/Serializer에서만 사용되면 같은 파일에 두어도 됩니다.

```python
# 단일 파일에서만 사용 → 분리 불필요 (YAGNI)
class ErrorCode:
    INVALID = "INVALID"
    NOT_FOUND = "NOT_FOUND"

# 여러 파일에서 사용 → constants.py로 분리 (DRY)
# from {app}.constants import ErrorCode
```

### 기존 코드 재사용 확인 (HIGH Priority)

새 함수를 제안하기 전 **기존 코드베이스에 유사한 기능이 있는지 확인**하세요.
이미 존재하는 유틸리티를 재발명하는 코드는 반드시 지적해야 합니다.

```python
# BAD - 이미 존재하는 기능을 새로 구현
def to_korean_time(dt):
    return dt + timedelta(hours=9)

# GOOD - 기존 유틸리티 재사용
from plab.utils import to_kst
```

### QuerySet 최적화 (HIGH Priority)

```python
# BAD - N+1 쿼리
for item in items:
    print(item.user.name)  # 매번 쿼리

# GOOD - select_related
items = Item.objects.select_related("user").all()

# BAD - 불필요한 전체 조회
if len(Item.objects.filter(status="active")) > 0:

# GOOD - exists()
if Item.objects.filter(status="active").exists():
```

---

## 리뷰 코멘트 레벨

| 레벨 | 설명 |
|------|------|
| **L1 - 요청사항** | 반드시 수정 필요 (보안, 버그, 아키텍처 위반) |
| **L2 - 권고사항** | 강력히 권장 (N+1, 성능 이슈) |
| **L3 - 질문사항** | 의도 확인 필요 |
| **L4 - 변경제안** | 더 나은 방법 제안 |
| **L5 - 참고의견** | 가벼운 제안 (스타일, 네이밍) |
