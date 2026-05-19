# 레이어드 아키텍처 규칙

참조 구현 모듈(`{reference_module}`)을 기준으로 새 기능을 작성한다.
의존성: **Controllers → Services → Repositories** (역방향/건너뛰기 금지)

**예외: 크론/배치 함수** — 직접 DB 접근을 허용하며, 기존 크론 함수 패턴을 따른다.

```
{module_name}/
├── {module}.controller.ts   # HTTP 요청/응답만. Service 호출만 허용
├── {module}.service.ts      # 비즈니스 로직. Repository 호출만 허용
├── {module}.repository.ts   # DB 접근 전담. 순수 쿼리만
├── {module}.dto.ts          # 요청/응답 DTO. 비즈니스 로직 금지
├── {module}.entity.ts       # 엔티티/스키마 정의
└── {module}.module.ts
```

### Next.js 프로젝트 구조 (App Router 기준)

```
app/
├── (route)/
│   ├── page.tsx             # UI 렌더링만. Server Component 기본
│   └── layout.tsx
├── api/
│   └── {endpoint}/
│       └── route.ts         # API 핸들러. Service 호출만 허용
lib/
├── services/                # 비즈니스 로직
├── repositories/            # DB 접근 전담
└── types/                   # 공유 타입 정의
```

## 절대 금지

| 규칙 | 이유 |
|------|------|
| Controller/Route에서 DB 직접 접근 금지 | Service 레이어를 통해서만 접근 |
| Service에서 DB 직접 접근 금지 | Repository를 통해서만 접근 |
| 레이어 건너뛰기 금지 | Controllers → Services → Repositories 순서 엄수 |
| `any` 타입 사용 금지 | 명시적 타입 또는 `unknown` 사용 |
| 테스트에서 직접 DB 쿼리 금지 | Mock/Stub 또는 인메모리 DB 사용 |
