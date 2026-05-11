# DOMAIN.md — {project_name}

> **AI 에이전트 필독**: 코드 작성 전 반드시 이 문서를 참조하라.
> 도메인 모델·용어·내부 슬랭을 파악하지 않으면 잘못된 가정으로 구현한다.

## 프로젝트 개요

| 항목 | 값 |
|------|-----|
| 스택 | {stack} (예: Next.js 14 / NestJS / Express) |
| 런타임 | Node.js {version} |
| 데이터 레이어 | {orm} (예: Prisma / Mongoose / TypeORM / Drizzle) |
| 배포 | {deployment} (예: Vercel / AWS ECS / Railway) |

---

## 도메인 계층 구조

> 핵심 엔티티 간 의존 방향을 표시. 아래는 예시.

```
{RootEntity}
├── {ChildEntity}
│   └── {GrandchildEntity}
└── {SiblingEntity}
```

---

## 핵심 엔티티

> 각 엔티티마다 아래 섹션을 복사해 채운다.

### {EntityName}

**역할**: (이 엔티티가 담당하는 비즈니스 개념 한 줄 설명)

**스키마 위치**: `{경로}/schema.ts` 또는 `prisma/schema.prisma`

| 필드 | 타입 | 설명 |
|------|------|------|
| id | string (UUID) | PK |
| createdAt | DateTime | 생성 시각 |
| updatedAt | DateTime | 수정 시각 |
| {field} | {type} | {설명} |

**주요 관계**:
- `{EntityName}` → `{RelatedEntity}` (1:N / N:M / 1:1)

**비즈니스 규칙**:
- TODO: 이 엔티티에 적용되는 제약 조건 기술

---

## 상태 코드 / Enum

> `status`, `type`, `role` 등 선택지가 고정된 필드는 여기에 정리.

### {EntityName}.status

| 값 | 의미 | 전이 가능 상태 |
|----|------|--------------|
| `DRAFT` | 임시저장 | `PUBLISHED`, `DELETED` |
| `PUBLISHED` | 공개 | `ARCHIVED`, `DELETED` |
| `ARCHIVED` | 보관 | — |
| `DELETED` | 삭제(soft) | — |

---

## API 계약

> 외부에 노출되는 핵심 엔드포인트와 응답 형식.

### {GET /api/resource}

**역할**: {한 줄 설명}

**Request**
```typescript
// Query params / Body
{
  page?: number;
  limit?: number;
}
```

**Response**
```typescript
{
  data: {EntityName}[];
  meta: { total: number; page: number };
}
```

---

## 내부 용어 / 슬랭

> 코드베이스에서 관용적으로 쓰이는 단어와 정확한 의미.

| 용어 | 의미 |
|------|------|
| {term} | {definition} |

---

## 아키텍처 패턴

> 이 프로젝트에서 지키는 레이어·패턴 규칙.

**예시 (NestJS)**
```
Controller → Service → Repository
```

**예시 (Next.js App Router)**
```
Page (RSC) → Server Action → Service → DB (Prisma)
```

실제 패턴: (TODO: 팀 규칙 기재)

---

## 변경 이력

| 날짜 | 변경 내용 | 대상 엔티티 | 작성자 |
|------|----------|-----------|--------|
| {YYYY-MM-DD} | 초기 작성 | — | — |
