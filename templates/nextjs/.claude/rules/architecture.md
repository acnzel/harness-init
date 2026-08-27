# App Router 레이어드 아키텍처 규칙

참조 구현 기능(`{reference_feature}`)을 기준으로 새 기능을 작성한다.
의존성: **Page / Route Handler / Server Action → Service → Repository** (역방향/건너뛰기 금지)

**예외: 크론/배치 스크립트** — 직접 DB 접근을 허용하며, 기존 배치 스크립트 패턴을 따른다.

```text
app/
├── {feature}/
│   ├── page.tsx              # RSC. UI 렌더링 + 읽기 전용 Service 호출만
│   └── actions.ts            # Server Actions — 쓰기는 Service 호출로 위임
├── api/
│   └── {endpoint}/
│       └── route.ts          # Route Handler — 외부/클라이언트 호출용. Service 호출만 허용
lib/
├── {feature}/
│   ├── service.ts            # 비즈니스 로직. Repository 호출만 허용
│   └── repository.ts         # DB 접근 전담 (Prisma/Drizzle/Supabase client 등). 순수 쿼리만
└── types/                     # 공유 타입 정의
```

이 프로젝트는 별도 백엔드 서버(NestJS/Express) 없이 Next.js App Router만으로 API와
UI를 함께 서빙한다는 전제다. 하이브리드 구성(별도 백엔드 병행)이면 이 문서 대신
프로젝트 루트 `CLAUDE.md`에 실제 구조를 적을 것 — 이 파일은 harness 소유 규칙이라
`init.sh`를 재실행하면 이 판으로 다시 덮어써진다.

## 절대 금지

| 규칙 | 이유 |
|------|------|
| Page(RSC)/Route Handler/Server Action에서 DB 직접 접근 금지 | Service 레이어를 통해서만 접근 |
| Service에서 DB 직접 접근 금지 | Repository를 통해서만 접근 |
| 레이어 건너뛰기 금지 | Page/Route Handler/Server Action → Service → Repository 순서 엄수 |
| `any` 타입 사용 금지 | 명시적 타입 또는 `unknown` 사용 |
| Repository 외 레이어에서 직접 DB 쿼리 금지 | Repository 테스트는 테스트 DB/DB 클라이언트 mock 사용, 그 외는 Mock/Stub |
