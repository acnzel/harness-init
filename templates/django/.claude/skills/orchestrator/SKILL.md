---
name: orchestrator
description: "django 백엔드 전용 에이전트 팀을 조율하여 기능 개발/유지보수 작업을 수행한다. 티켓({TICKET-ID}) 또는 요구사항을 입력받아 analyst → architect → coder ↔ tester → reviewer 파이프라인을 실행한다. 트리거: '백엔드 팀 실행', 'django 백엔드 구현', '{TICKET-ID} 팀으로 처리', '하네스 팀 실행', '기능 개발', '유지보수 작업'. 후속: 결과 수정, 부분 재실행, 리뷰 재시도, 설계 수정 요청 시에도 이 스킬 사용."
---

# Django Backend Team Orchestrator

django 백엔드의 **기능 개발/유지보수 작업을 전담하는 5인 전문 팀**을 조율하는 오케스트레이터 스킬.

## 실행 모드: 에이전트 팀

5명 이상의 에이전트 협업이며 파이프라인 중간에 생성-검증 루프가 있어 `TeamCreate` + `SendMessage` + `TaskCreate` 방식이 필수.

## 에이전트 구성

| 팀원 | 에이전트 타입 | 역할 | 출력 |
|------|-------------|------|------|
| analyst | 커스텀 (Explore 기반) | 티켓 분석, 영향 범위 식별, 모델 선행 분석 | `_workspace/01_ticket_analysis.md` |
| architect | 커스텀 (Plan 기반) | Views/Services/Repositories 설계, 테스트 전략 | `_workspace/02_architecture.md` |
| coder | 커스텀 (general-purpose) | 실제 코드 작성 | 소스 파일 + `_workspace/03_implementation_notes.md` |
| tester | 커스텀 (general-purpose) | pytest 테스트 작성 (Factory + PropertyMock) | 테스트 파일 + `_workspace/04_test_notes.md` |
| reviewer | 커스텀 (Explore 기반) | CLAUDE.md 규칙/레이어 경계 검증 | `_workspace/05_review_report.md` |

## 워크플로우

### Phase 0: 컨텍스트 확인

1. `_workspace/` 디렉토리 존재 여부 확인
2. 실행 모드 결정:
   - **미존재** → 초기 실행. Phase 1로 진행
   - **존재 + 부분 수정 요청** ("테스트 다시 써", "리뷰 재실행" 등) → 해당 에이전트만 재호출
   - **존재 + 새 티켓** → 기존 `_workspace/`를 `_workspace_{YYYYMMDD_HHMMSS}/`로 이동 후 Phase 1

### Phase 1: 준비

1. 사용자 입력 분석 — 티켓 번호 추출 또는 자연어 요구사항 정리
2. **티켓 자동 조회** (티켓 번호 입력 시):
   - `which jira` 로 jira CLI 설치 여부 확인
   - CLI 존재 시 `jira issue view {TICKET-ID}` 로 조회
   - CLI 미존재 시 사용자에게 티켓 내용 직접 입력 요청
3. `_workspace/` 생성 + `_workspace/00_input.md`에 입력 원문 저장

### Phase 2: 팀 구성

```
TeamCreate(
  team_name: "django-backend-team",
  members: [
    { name: "analyst", agent_type: "analyst", model: "opus" },
    { name: "architect", agent_type: "architect", model: "opus" },
    { name: "coder", agent_type: "coder", model: "opus" },
    { name: "tester", agent_type: "tester", model: "opus" },
    { name: "reviewer", agent_type: "reviewer", model: "opus" }
  ]
)
```

### Phase 3: 작업 등록

```
TaskCreate(tasks: [
  { title: "티켓 분석 및 영향 범위 식별", assignee: "analyst" },
  { title: "레이어드 설계 문서 작성", assignee: "architect" },
  { title: "Views/Services/Repositories 구현 + 해당 앱 DOMAIN.md 업데이트", assignee: "coder" },
  { title: "pytest 테스트 작성 및 실행", assignee: "tester" },
  { title: "레이어 규칙 및 CLAUDE.md 준수 리뷰", assignee: "reviewer" }
])
```

### Phase 4: 파이프라인 실행 + 생성-검증 루프

**파이프라인 (순차)**:
1. analyst → SendMessage(to: architect)
2. architect → SendMessage(to: coder)
3. coder ↔ tester (양방향 생성-검증 루프, 최대 3회)
   - **루프 완료 직후**: coder가 변경된 앱의 `DOMAIN.md` 변경 이력 업데이트 여부 자체 확인
4. reviewer → DOMAIN.md 체크리스트 E 포함하여 검증 → PASS 시 리더에게 "PR 제출 가능" 보고

**리뷰 게이트**:
- FAIL 시: 담당 에이전트에게 SendMessage로 재작업 요청. 최대 2회 루프
- 위반 10건 이상: architect로 설계 재검토 에스컬레이션

**모델 변경 에스컬레이션**:
- coder가 마이그레이션 필요 감지 → 즉시 작업 중단, 리더에게 SendMessage
- 대안(annotated field, cached_property, QuerySet 활용) 검토 → 대안 불가 시 경고 명시하고 계속

### Phase 5: 통합 보고

1. 모든 작업 완료 확인 (TaskGet)
2. `_workspace/` 내 5개 산출물 Read
3. 리더가 사용자 보고서 작성
4. TeamDelete

### Phase 6: 하네스 자기 점검 (자동)

| 점검 항목 | 자동 진화 트리거 기준 |
|----------|---------------------|
| 어떤 에이전트가 가장 많이 재작업했나? | 재작업 2회 이상 → 해당 에이전트 지시 보완 |
| 생성-검증 루프가 3회를 넘었나? | 초과 시 → architect 설계 단계 강화 |
| 동일한 규칙 위반이 2회 이상 반복됐나? | 반복 시 → 에이전트 원칙에 명시 |
| 사용자가 직접 개입한 지점이 있나? | 개입 시 → 해당 단계 자동화/명시화 |

### Phase 7: 하네스 자동 진화

트리거 기준 해당 시 사용자 확인 없이 리더가 직접 하네스 파일 수정:

| 피드백 유형 | 수정 대상 |
|------------|----------|
| 결과 품질 문제 | 에이전트 스킬/원칙 |
| 에이전트 역할 부재 | 에이전트 정의 추가 |
| 워크플로우 순서 문제 | 오케스트레이터 스킬 |
| 트리거 키워드 누락 | 스킬 description |

수정 절차:
1. 피드백을 일반화 — 특정 사례만 고치지 말고 패턴으로 반영
2. `.claude/agents/*.md` 또는 `.claude/skills/orchestrator/SKILL.md` 수정
3. CLAUDE.md `### 하네스 변경 이력`에 날짜·내용·대상·사유 기록

### Phase 8: 변경사항 문서화 (Compounding)

`reviews/YYYY-MM-DD-{TICKET-ID}.md` 파일 생성:

```markdown
# {TICKET-ID}: [작업 제목]
- **Date**: YYYY-MM-DD
- **Branch**: feature/{TICKET-ID}

## 해결한 문제
## 적용한 패턴
## 가장 어려웠던 결정
## 발견한 예외/주의사항
## 변경 파일
## 하네스 변경
```

패턴 발견 시 CLAUDE.md 즉시 반영:
- 새로운 아키텍처 예외
- 반복되는 버그 패턴 (2회 이상)
- 기존 규칙의 모호함

### Phase 9: 자동 커밋 및 PR 생성

1. 피처 브랜치 생성: `feature/{TICKET-ID}`
2. 커밋 대상: 구현 코드 + 하네스 파일 (Phase 7 수정 시) + `reviews/` 문서
3. 커밋 메시지: `[{TICKET-ID}] type: 설명`
4. PR 생성: `gh pr create --base dev`

## 사용자 보고서 형식

```markdown
# 실행 결과: {TICKET-ID}

## 요약
- **분석**: (analyst 요점)
- **설계**: (핵심 레이어 구조)
- **구현**: (변경 파일 N개)
- **테스트**: (추가 테스트 M건, 실행 결과)
- **리뷰**: PASS / FAIL (위반 N건)

## 변경 파일 목록
## DOMAIN.md 업데이트
- (변경된 앱 + 업데이트 내용, 없으면 "없음")
## PR
- **브랜치**: feature/{TICKET-ID} → dev
- **PR URL**: (자동 생성된 PR 링크)
- **하네스 변경**: (Phase 7 수정 파일 목록, 없으면 "없음")
```

## 에러 핸들링

- **팀원 응답 없음**: 리더가 상태 확인 후 재개 또는 재시작
- **리뷰 FAIL 루프 3회 초과**: 작업 중단, 사용자에게 직접 보고
- **모델 변경 필요**: 즉시 중단 후 "마이그레이션 필요" 경고 명시
- **새 패키지 필요**: requirements 파일 편집 후 "pip-compile 필요" 명시. 작업 계속

## 데이터 흐름

```
[사용자 입력]
    ↓
[리더: orchestrator]
    ├→ TeamCreate + TaskCreate
    ├→ analyst ──→ _workspace/01_ticket_analysis.md
    ├→ architect ──→ _workspace/02_architecture.md
    ├→ coder ←→ tester (생성-검증 루프)
    ├→ reviewer ──→ _workspace/05_review_report.md
    ├→ [Phase 6: 자기 점검]
    ├→ [Phase 7: 하네스 진화]
    ├→ [Phase 8: 문서화 → reviews/]
    └→ [Phase 9: 커밋 + PR → dev]
```

## 트리거 조건

**이 스킬을 사용해야 하는 경우**:
1. 티켓 번호와 함께 "구현해줘", "처리해줘", "작업해줘" 요청
2. Django 앱에 기능을 추가하거나 수정하는 작업
3. 레이어드 아키텍처 준수가 중요한 유지보수 작업
4. 이전 실행 결과를 수정/재실행/보완하는 요청

**이 스킬을 사용하지 않아야 하는 경우**:
- 단순한 typo 수정, 주석 추가 등 1~2줄 변경
- PR 리뷰만 필요한 경우 (`/review` 사용)
