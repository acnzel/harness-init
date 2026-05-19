# TypeScript/JavaScript 코드 스타일 가이드

이 문서는 Gemini Code Assist가 코드 리뷰 시 참조할 프로젝트 스타일 가이드입니다.

## Critical Rules (반드시 준수)

### 1. Layered Architecture
**Controllers → Services → Repositories** 의존성 순서 엄수:

```typescript
// Good
@Controller('items')
export class ItemController {
  constructor(private readonly itemService: ItemService) {}

  @Get(':id')
  getItem(@Param('id') id: string) {
    return this.itemService.findById(id);
  }
}

// Bad - Controller에서 직접 DB 접근
@Controller('items')
export class ItemController {
  constructor(private readonly itemRepository: ItemRepository) {} // 금지!
}
```

### 2. Test Data Creation
테스트 데이터 생성 시 `@faker-js/faker` 기반 Factory 사용:

```typescript
// Good
const item = ItemFactory.build({ status: 'active' });

// Bad
const item = await itemRepository.save({ status: 'active' }); // 금지!
```

### 3. Pre-commit Hooks
커밋 전 반드시 통과해야 하는 검사:

```bash
eslint --fix   # 린트 + 자동 수정
prettier --write  # 포매터
```

## Layered Architecture

```
{module}/
├── {module}.controller.ts   # HTTP 요청/응답 처리
├── {module}.service.ts      # 비즈니스 로직 처리
├── {module}.repository.ts   # 데이터베이스 접근
├── {module}.dto.ts          # 요청/응답 데이터 타입
├── {module}.entity.ts       # DB 엔티티 (TypeORM) 또는 schema.prisma
└── {module}.module.ts       # DI 모듈 (NestJS)
```

### 의존성 규칙

**금지 사항**:
1. 역방향 의존성: 하위 레이어가 상위 레이어 호출 금지
2. 레이어 건너뛰기: Controller가 Repository 직접 호출 금지
3. 순환 의존성: 레이어 간 순환 참조 금지

## Type Safety (필수)

모든 함수와 메서드에 타입 명시 필수 (strict mode):

```typescript
// Good
async findById(id: string): Promise<Item | null> {
  return this.itemRepository.findOne({ where: { id } });
}

// Bad
async findById(id) { // 타입 없음 — 금지!
  return this.itemRepository.findOne({ where: { id } });
}
```

## Error Handling

```typescript
// Good — 구체적인 예외 처리
async findById(id: string): Promise<Item> {
  const item = await this.itemRepository.findOne({ where: { id } });
  if (!item) throw new NotFoundException(`Item ${id} not found`);
  return item;
}

// Bad — 예외 무시
catch (e) {
  // 아무것도 안 함 — 금지!
}
```

## 네이밍 컨벤션
- **클래스**: PascalCase (`ItemService`, `ItemRepository`)
- **함수/변수**: camelCase (`findById`, `itemCount`)
- **상수**: UPPER_SNAKE_CASE (`MAX_RETRY_COUNT`)
- **인터페이스**: PascalCase + I prefix 선택 (`IItemService` 또는 `ItemService`)
- **파일명**: kebab-case (`item-service.ts`)

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

### 기존 코드 재사용 확인 (HIGH Priority)

새 함수를 제안하기 전 **기존 코드베이스에 유사한 기능이 있는지 확인**하세요.

## 리뷰 코멘트 레벨

| 레벨 | 설명 |
|------|------|
| **L1 - 요청사항** | 반드시 수정 필요 (보안, 버그, 아키텍처 위반) |
| **L2 - 권고사항** | 강력히 권장 (N+1, 타입 누락, 성능 이슈) |
| **L3 - 질문사항** | 의도 확인 필요 |
| **L4 - 변경제안** | 더 나은 방법 제안 |
| **L5 - 참고의견** | 가벼운 제안 (스타일, 네이밍) |
