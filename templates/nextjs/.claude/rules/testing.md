# 테스트 작성 규칙

**CRITICAL**: 테스트 코드 작성 전 반드시 아래 절차를 따를 것.

## Step 1. 레이어/의존성 분석 (필수 선행)

대상 기능의 Service·Repository 의존성과, 외부 호출(fetch/DB client/써드파티 SDK)을
목록화하고 mock 대상을 결정한다.

## Step 2. 모듈 단위 모킹

```typescript
// ✅ 모듈 모킹 — vi.mock / jest.mock
vi.mock('@/lib/user/repository');
const mockRepository = vi.mocked(userRepository);

// ✅ 함수 모킹
vi.spyOn(userService, 'findOne').mockResolvedValue(mockUser);

// ❌ 전역 상태·모듈 캐시를 테스트 간 공유하지 않는다 — 각 테스트가 독립적으로 mock 재설정
```

## Step 3. 테스트 데이터는 팩토리 함수로

`test/factories/` 또는 `test/fixtures/`에 정의된 팩토리 함수를 사용. DB 인스턴스 직접 생성 최소화.

## 레이어별 테스트 범위

| 레이어 | 무엇을 테스트 | 무엇을 mock |
|-------|-------------|-----------|
| Page (RSC) | 렌더된 내용·데이터 페칭 결과 | Service 함수 (unit) / 없음 (e2e) |
| Route Handler / Server Action | 응답 코드·본문, Service 호출 여부 | Service 함수 |
| Service | 비즈니스 로직 분기, Repository 호출 여부 | Repository 함수 |
| Repository | 실제 쿼리 결과 | mock 없음 (테스트 DB) |

## RSC(Server Component)는 unit 테스트가 어렵다

Server Component는 async 함수라 jsdom 기반 렌더러(RTL 등)로 직접 단위 테스트하기
까다롭다. `page.tsx`의 검증은 아래 중 하나로 대체한다:

- 데이터 페칭·가공 로직을 `lib/{feature}/service.ts`로 분리해 그쪽을 unit 테스트
- 실제 렌더 결과(레이아웃·상호작용)는 Playwright 등 e2e로 검증

## 실행

```bash
# Vitest
npx vitest run

# Jest
npx jest --coverage

# e2e (Playwright 사용 시)
npx playwright test
```
