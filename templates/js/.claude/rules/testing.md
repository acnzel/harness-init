# 테스트 작성 규칙

**CRITICAL**: 테스트 코드 작성 전 반드시 아래 절차를 따를 것.

## Step 1. 타입/스키마 분석 (필수 선행)

대상 모듈의 엔티티·DTO·인터페이스에서 readonly 속성과 computed getter를 목록화하고
mock 가능 여부를 확인.

## Step 2. 의존성 모킹

```typescript
// ✅ Jest mock — 모듈 단위 모킹
jest.mock('../service/user.service');
const mockUserService = jest.mocked(UserService);

// ✅ 인스턴스 메서드 모킹
jest.spyOn(userService, 'findOne').mockResolvedValue(mockUser);

// ❌ 직접 할당 금지 (readonly 속성)
instance.readonlyProp = value;
```

## Step 3. 테스트 데이터는 Factory/Builder만 사용

`test/factories/` 또는 `test/builders/`에 정의된 팩토리 함수만 사용.
`new Entity()` 또는 DB 직접 삽입 금지 (통합 테스트 제외).

## 레이어별 테스트 범위

| 레이어 | 무엇을 테스트 | 무엇을 mock |
|-------|-------------|-----------|
| Controller | HTTP 응답 코드/본문, Service 호출 여부 | Service 클래스 |
| Service | 비즈니스 로직 분기, Repository 호출 여부 | Repository 클래스 |
| Repository | 실제 쿼리 결과 | mock 없음 (인메모리 DB 또는 testcontainers) |
| DTO/Schema | 유효성 검사 통과/실패 | mock 없음 |

## 실행

```bash
# Jest
npx jest --coverage

# Vitest
npx vitest run
```
