# 문서 동기화 정책

이 문서는 코드베이스와 문서 간의 동기화 정책을 정의합니다.

---

## 0. 문서 카테고리 및 네이밍 규칙

`docs/` 디렉토리는 아래 카테고리로 관리한다. 문서를 생성하면 반드시 `CLAUDE.md`의 `## 참고 문서` 테이블에 등록한다.

```
docs/
├── architecture/      # 아키텍처 가이드
├── policies/          # 비즈니스 정책
├── analysis/          # 성능 분석
├── deployment/        # 배포 가이드
├── troubleshooting/   # 트러블슈팅 기록
├── api/               # API 명세 (자동 생성)
└── DOC-SYNC-POLICY.md
```

| 디렉토리 | 파일명 패턴 | 생성 주체 | 생성 시점 |
|---------|-----------|---------|---------|
| `architecture/` | `{feature}-architecture.md` | architect 에이전트 | 새 레이어 구조·패턴 확정 시 |
| `policies/` | `{domain}-policy.md` | architect 에이전트 | 복잡한 비즈니스 규칙이 코드에 반영될 때 |
| `analysis/` | `{feature}-analysis.md` | architect 에이전트 | 레이턴시·병목 분석 완료 시 |
| `deployment/` | `{env}-deployment.md` | DevOps 담당자 | 배포 방식 변경 시 |
| `troubleshooting/` | `{issue}-fix-plan.md` | 장애 대응자 | 장애 원인·해결책 정리 후 |
| `api/` | `{app}.md` | 자동화 (post-merge-docs.yml) | 엔드포인트 추가·변경 시 |

### 네이밍 규칙

- 영문 소문자 + 하이픈(kebab-case): `match-validation-policy.md`
- 날짜가 의미 있는 분석 문서는 날짜 포함: `api-latency-analysis-2026-01.md`
- 한국어 파일명 허용 (팀 내부 문서): `매니저-정산-정책.md`

---

## 1. 원칙

- **코드가 진실의 원천(source of truth)**: 문서는 코드를 반영해야 하며, 코드와 충돌 시 코드가 우선
- **변경 즉시 반영**: 코드 변경과 문서 갱신은 같은 PR에 포함되는 것을 원칙으로 함
- **자동화 우선**: 반복적인 문서 갱신은 `post-merge-docs.yml` 워크플로우가 담당

---

## 2. 문서 분류 및 책임

| 문서 | 위치 | 갱신 트리거 | 책임 |
|------|------|-----------|------|
| API 엔드포인트 명세 | `docs/api/` | 엔드포인트 추가·수정·삭제 | 구현 PR 작성자 |
| 아키텍처 결정 기록 (ADR) | `.claude/decisions/` | 아키텍처 변경 | 설계 담당자 |
| 코딩 컨벤션 | `CLAUDE.md` | 규칙 변경·예외 추가 | 오케스트레이터 자동 반영 |
| 변경 이력 리뷰 | `reviews/` | 매 티켓 작업 완료 후 | 오케스트레이터 (Phase 8) |
| 배포 가이드 | `docs/deployment.md` | 배포 방식 변경 | DevOps 담당자 |
| 이 문서 | `docs/DOC-SYNC-POLICY.md` | 정책 변경 시 | 팀 합의 후 갱신 |

---

## 3. 동기화 대상 및 주기

### 3-1. 즉시 갱신 (코드 변경과 동시)

- `CLAUDE.md`: 오케스트레이터 Phase 7·8에서 자동 갱신. 수동 변경 시 PR에 포함 필수
- `.claude/decisions/`: ADR은 설계 결정이 확정된 PR에 함께 포함
- `reviews/YYYY-MM-DD-{TICKET-ID}.md`: 오케스트레이터 Phase 8에서 자동 생성

### 3-2. PR 머지 후 자동 갱신 (`post-merge-docs.yml` 담당)

- API 문서 (`docs/api/`): 엔드포인트 변경이 포함된 PR 머지 시 자동 트리거
- 변경 이력 요약 (`docs/CHANGELOG.md`): 매 머지마다 자동 추가

### 3-3. 정기 감사 (월 1회 권장)

- 코드와 문서 간 불일치 탐색
- 오래된 ADR 아카이브 처리
- `DOC-SYNC-POLICY.md` 자체 검토

---

## 4. 갱신 절차 (수동)

1. **코드 변경 확인**: `git diff origin/dev...HEAD --name-only` 로 변경 파일 파악
2. **영향 문서 식별**: 아래 매핑표 참조
3. **문서 갱신**: 변경 내용을 반영하고 코드와 동일 PR에 커밋
4. **리뷰 요청**: PR 설명에 "📄 문서 갱신 포함" 명시

### 코드 → 문서 영향 매핑

| 변경된 코드 위치 | 갱신해야 할 문서 |
|----------------|----------------|
| `{app}/views.py` | `docs/api/{app}.md` |
| `{app}/models.py` | ADR (모델 변경 시) |
| `{app}/services.py` | 비즈니스 로직 변경이 API 동작에 영향 시 `docs/api/` |
| `.claude/agents/*.md` | `CLAUDE.md` 하네스 변경 이력 |
| `requirements/` | `docs/deployment.md` (의존성 변경 시) |
| `CLAUDE.md` | — (이 파일 자체가 문서) |

---

## 5. 자동화 워크플로우

### `post-merge-docs.yml`

- **트리거**: `dev` 또는 `prod` 브랜치에 PR이 머지될 때
- **동작**:
  1. 변경된 파일 목록 분석
  2. views.py 변경 감지 → API 문서 갱신 PR 자동 생성
  3. CHANGELOG.md에 머지 요약 자동 추가
- **설정**: `.github/workflows/post-merge-docs.yml` 참조

---

## 6. 문서 품질 기준

- **정확성**: 문서의 내용이 현재 코드 동작과 일치해야 함
- **간결성**: 불필요한 설명 없이 핵심만 기술
- **최신성**: 6개월 이상 갱신되지 않은 문서는 "검토 필요" 표시
- **접근성**: 새 팀원이 문서만 읽고 독립적으로 작업 가능한 수준

---

## 7. 위반 처리

| 위반 유형 | 처리 방법 |
|----------|---------|
| 코드 변경 후 문서 미갱신 | PR 리뷰어가 반려 후 갱신 요청 |
| 문서와 코드 불일치 발견 | 즉시 이슈 생성 후 당일 수정 |
| 자동화 워크플로우 실패 | Slack 알림 후 수동 갱신으로 대체 |
