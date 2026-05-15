# 에이전트 팀 (하네스)

Django 백엔드 전용 5인 에이전트 팀. 기능 개발 및 유지보수 작업 시 호출한다.

## 파이프라인

```
analyst → architect → coder ⇄ tester → reviewer
```

| 팀원 | 파일 | 역할 |
|------|------|------|
| analyst | `.claude/agents/analyst.md` | 영향 범위 식별, 모델 선행 분석 |
| architect | `.claude/agents/architect.md` | Views/Services/Repositories 설계, 테스트 전략 |
| coder | `.claude/agents/coder.md` | 실제 코드 작성 (레이어 엄수) |
| tester | `.claude/agents/tester.md` | Factory/PropertyMock 기반 pytest 작성 |
| reviewer | `.claude/agents/reviewer.md` | CLAUDE.md 규칙·레이어 경계 검증 (PR 게이트) |

오케스트레이터 스킬: `.claude/skills/orchestrator/SKILL.md`

## 트리거 조건

다음 상황에서 반드시 `orchestrator` 스킬을 실행한다:

- 티켓 번호와 함께 "구현해줘 / 처리해줘 / 작업해줘" 요청
- Django 앱의 기능 추가·수정
- 레이어드 아키텍처 준수가 중요한 유지보수 작업 (버그 수정 포함)
- "하네스 팀 실행", "백엔드 팀으로 처리" 등 명시적 호출
- 이전 실행 결과를 수정·재실행·보완하는 요청

## 제외 조건

- 단순 typo·주석 1~2줄 수정 → 직접 편집
- PR 리뷰만 → `/review` 커맨드

## _workspace/ — 에이전트 산출물 디렉토리

| 파일 | 생성 에이전트 | 내용 |
|------|-------------|------|
| `_workspace/00_input.md` | orchestrator | 티켓 원문 또는 사용자 입력 |
| `_workspace/01_ticket_analysis.md` | analyst | 영향 범위·모델 분석·제약사항 |
| `_workspace/02_architecture.md` | architect | 레이어드 설계·테스트 전략 |
| `_workspace/03_implementation_notes.md` | coder | 구현 완료 파일 목록·결정 사항 |
| `_workspace/04_test_notes.md` | tester | 테스트 파일 목록·실행 결과 |
| `_workspace/05_review_report.md` | reviewer | 리뷰 결과·위반 목록 |

`_workspace/`는 `.gitignore`에 추가하거나 작업 단위로 관리한다.
새 티켓 실행 시 기존 `_workspace/`는 `_workspace_{YYYYMMDD_HHMMSS}/`로 자동 이동된다.
