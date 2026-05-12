# CLAUDE.md

{project_name} — {stack} (예: Next.js 14 / NestJS / Express) / {deployment_info}

## 코딩 원칙

### 1. 코딩 전에 생각하라
- 가정을 명시적으로 밝히고, 불확실하면 질문하라.
- 여러 해석이 가능하면 조용히 하나를 고르지 말고 선택지를 제시하라.
- 더 단순한 방법이 있으면 말하라. 필요하면 반론하라.
- 혼란스러우면 멈추고, 무엇이 불명확한지 짚어라.

### 2. 단순함 우선
- 요청받은 것만 구현. 추측성 기능, 불필요한 추상화, 불가능한 시나리오의 에러 처리 금지.
- 200줄로 쓴 코드가 50줄로 가능하면 다시 써라.
- "시니어 엔지니어가 과하다고 할까?" — 그렇다면 단순화하라.

### 3. 외과적 변경
- 요청과 직접 관련된 코드만 수정. 인접 코드 "개선", 포맷팅, 리팩토링 금지.
- 기존 스타일에 맞춰라. 본인 스타일이 달라도.
- 내 변경으로 생긴 미사용 import/변수/함수만 제거. 기존 데드코드는 언급만 하고 삭제하지 마라.
- **테스트**: 변경된 모든 줄이 사용자 요청에 직접 연결되어야 한다.

### 4. 목표 기반 실행
- 작업을 검증 가능한 목표로 변환:
  - "검증 추가" → "잘못된 입력 테스트 작성 후 통과시키기"
  - "버그 수정" → "재현 테스트 작성 후 통과시키기"
  - "리팩토링" → "전후 테스트 통과 확인"
- 멀티스텝 작업은 단계별 검증 기준을 명시하라.

## 절대 금지 사항

| 규칙 | 이유 |
|------|------|
| Controller/Route에서 DB 직접 접근 금지 | Service 레이어를 통해서만 접근 |
| Service에서 DB 직접 접근 금지 | Repository/DAO를 통해서만 접근 |
| 레이어 건너뛰기 금지 | Controller → Service → Repository 순서 엄수 |
| `git push --force`, `git reset --hard` 금지 | 이력 손실 위험 |
| `any` 타입 남용 금지 | TypeScript 타입 안전성 훼손 |

## 레이어드 아키텍처

참조 구현(`{reference_module}`)을 기준으로 새 기능을 작성. 의존성 방향은 **Controller → Service → Repository** (역방향/건너뛰기 금지)

**NestJS 예시**
```
{module}/
├── {module}.controller.ts   # HTTP 요청/응답만. Service 호출로 위임
├── {module}.service.ts      # 비즈니스 로직. Repository 호출
├── {module}.repository.ts   # DB 접근 전담. 순수 쿼리만
├── {module}.module.ts       # NestJS 모듈 설정
├── dto/                     # 요청/응답 DTO (비즈니스 로직 금지)
└── entities/                # 엔티티 정의
```

**Next.js App Router 예시**
```
app/
├── {feature}/
│   ├── page.tsx             # RSC — UI 렌더링만
│   └── actions.ts           # Server Actions — Service 호출로 위임
lib/
├── {feature}/
│   ├── service.ts           # 비즈니스 로직
│   └── repository.ts        # DB 접근 (Prisma 등)
```

## 환경 설정

| 환경 | 파일 | 비고 |
|------|------|------|
| local | `.env.local` | git 제외 |
| dev | `.env.development` | |
| prod | `.env.production` | 서버 환경변수 직접 주입 |
| test | `.env.test` | 테스트 전용 DB |

## 테스트 작성 규칙

**CRITICAL**: 테스트 코드 작성 전 반드시 아래 절차를 따를 것.

### Step 1. 의존성 분석 (필수 선행)
대상 모듈의 의존성을 파악하고 mock 대상을 결정한다.

### Step 2. getter/computed 속성 모킹
```typescript
// ✅ getter 모킹 — jest.spyOn 사용
jest.spyOn(instance, 'propName', 'get').mockReturnValue(value);

// ❌ 직접 할당 금지 → readonly 위반
instance.propName = value;
```

### Step 3. 테스트 데이터는 팩토리 함수로
`test/factories/` 또는 `test/fixtures/`에 정의된 팩토리 함수를 사용. DB 인스턴스 직접 생성 최소화.

### 레이어별 테스트 범위

| 레이어 | 무엇을 테스트 | 무엇을 mock |
|-------|-------------|-----------|
| Controller | HTTP 응답 코드/본문, Service 호출 여부 | Service 클래스 |
| Service | 비즈니스 로직 분기, Repository 호출 여부 | Repository 클래스 |
| Repository | 실제 쿼리 결과 | mock 없음 (테스트 DB) |
| DTO/Schema | 직렬화/역직렬화 결과 | mock 없음 |

## 도메인 지식 (DOMAIN.md)

프로젝트 루트의 `DOMAIN.md`는 **AI 에이전트가 코드를 작성하기 전에 반드시 참조**해야 하는 도메인 지식 문서입니다.

### 에이전트별 의무

| 에이전트 | 의무 |
|---------|------|
| **analyst** | 분석 시작 전 `DOMAIN.md` 필수 참조 (엔티티·용어·API 계약 파악) |
| **coder** | 코드 변경 완료 후 `DOMAIN.md` 변경 이력 갱신. 새 엔티티·필드·enum 추가 시 해당 섹션도 갱신 |
| **reviewer** | DOMAIN.md 변경 이력이 이번 작업을 반영하는지 검증. 누락 시 coder에게 보완 요청 |

### 업데이트 규칙

```
코드 변경 → DOMAIN.md 변경 이력 테이블에 한 줄 추가
새 엔티티 추가 → 도메인 계층 구조 + 핵심 엔티티 섹션 갱신
새 enum/status 추가 → 상태 코드 섹션 갱신
새 API 추가 → API 계약 섹션 갱신
```

## 참고 문서

`docs/` 디렉토리는 카테고리별 서브디렉토리로 관리합니다. 에이전트가 작업 전 관련 문서를 자동 참조하고, 아키텍처·정책 결정 시 자동 생성합니다.

| 디렉토리 | 용도 | 생성 주체 |
|---------|------|---------|
| `docs/architecture/` | 레이어 구조·패턴 가이드 | architect 에이전트 |
| `docs/policies/` | 비즈니스 정책·규칙 | architect 에이전트 |
| `docs/analysis/` | 성능·병목 분석 결과 | architect 에이전트 |
| `docs/deployment/` | 배포·인프라 가이드 | DevOps 담당자 |
| `docs/troubleshooting/` | 장애 대응·버그 수정 이력 | 장애 대응자 |
| `docs/api/` | 엔드포인트 명세 | post-merge-docs.yml 자동화 |

새 문서를 생성하면 이 `CLAUDE.md`의 `## 참고 문서` 테이블에 등록합니다.

### 프로젝트 문서 인덱스

| 문서 | 경로 | 내용 |
|------|------|------|
| (TODO: 아키텍처 결정 문서를 여기에 등록) | | |

## Hooks — 자동 알림

`settings.json`의 PostToolUse 훅이 Edit/Write 직후 자동으로 실행됩니다.

| 훅 | 트리거 | 동작 |
|----|--------|------|
| `domain-update-reminder.sh` | Edit / Write 후 | 스키마 파일 변경 → DOMAIN.md 갱신 체크리스트 출력<br>서비스/컨트롤러 변경 → 흐름 업데이트 권고 |
| `insight-collector.sh` | Bash / Edit / Write 후 | Claude 응답의 `★ Insight` 블록을 감지해 `.claude/insights.md`에 자동 저장 |

## _workspace/ — 에이전트 산출물 디렉토리

오케스트레이터 실행 시 에이전트 간 인수인계 파일이 `_workspace/`에 저장됩니다.

| 파일 | 생성 에이전트 | 내용 |
|------|-------------|------|
| `_workspace/00_input.md` | orchestrator | 티켓 원문 또는 사용자 입력 |
| `_workspace/01_ticket_analysis.md` | analyst | 영향 범위·모델 분석·제약사항 |
| `_workspace/02_architecture.md` | architect | 레이어드 설계·테스트 전략 |
| `_workspace/03_implementation_notes.md` | coder | 구현 완료 파일 목록·결정 사항 |
| `_workspace/04_test_notes.md` | tester | 테스트 파일 목록·실행 결과 |
| `_workspace/05_review_report.md` | reviewer | 리뷰 결과·위반 목록 |

`_workspace/`는 `.gitignore`에 추가하거나 작업 단위로 관리합니다.
새 티켓 실행 시 기존 `_workspace/`는 `_workspace_{YYYYMMDD_HHMMSS}/`로 자동 이동됩니다.

## 하네스 (에이전트 팀)

이 프로젝트에는 JS/TS 백엔드·프론트엔드 전용 5인 에이전트 팀이 구성되어 있다. 기능 개발, 유지보수 작업 시 이 팀을 호출한다.

### 트리거 조건

다음 상황에서 반드시 `orchestrator` 스킬을 실행한다:

- 티켓 번호와 함께 "구현해줘 / 처리해줘 / 작업해줘" 요청
- 기능 추가·수정
- 레이어드 아키텍처 준수가 중요한 유지보수 작업 (버그 수정 포함)
- "하네스 팀 실행", "팀으로 처리" 등 명시적 호출

### 팀 구성 (파이프라인 + 생성-검증 루프)

```
analyst → architect → coder ⇄ tester → reviewer
```

| 팀원 | 파일 | 역할 |
|------|------|------|
| analyst | `.claude/agents/analyst.md` | 영향 범위 식별, 엔티티 선행 분석 |
| architect | `.claude/agents/architect.md` | Controller/Service/Repository 설계, 테스트 전략 |
| coder | `.claude/agents/coder.md` | 실제 코드 작성 (레이어 엄수) |
| tester | `.claude/agents/tester.md` | jest/vitest 기반 테스트 작성 |
| reviewer | `.claude/agents/reviewer.md` | CLAUDE.md 규칙·레이어 경계 검증 (PR 게이트) |

오케스트레이터 스킬: `.claude/skills/orchestrator/SKILL.md`

### 제외 조건 (이 팀을 쓰지 말 것)

- 단순 typo·주석 1~2줄 수정 → 직접 편집
- PR 리뷰만 → `/review` 커맨드

## Inline 인사이트 — 대화 중 자동 학습

작업 중 **이 코드베이스에 특화된 비자명한 패턴**을 발견하면 다음 포맷으로 즉시 출력하라:

```
`★ Insight ─────────────────────────────────────`
  [발견한 원칙 또는 패턴 — 코드 스니펫 포함 가능]
`─────────────────────────────────────────────────`
```

### 출력 기준 (모두 충족해야 함)

| 질문 | 기준 |
|------|------|
| "5분 안에 구글로 찾을 수 있는가?" | **NO** |
| "이 코드베이스에 특화된 내용인가?" | **YES** |
| "실제 분석/디버깅으로 발견했는가?" | **YES** |

### 스킬로 승격

발견한 인사이트가 반복적으로 유용할 것 같으면 `/learn` 슬래시 커맨드로 `.claude/skills/` 에 저장하라.

## 하네스 변경 이력

| 날짜 | 변경 내용 | 대상 | 사유 |
|------|----------|------|------|
