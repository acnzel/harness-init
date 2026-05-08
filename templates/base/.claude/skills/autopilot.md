---
name: autopilot
description: PRD/설계 문서와 구현 계획을 바탕으로 완성까지 자율 실행
triggers: ["/autopilot"]
---

# Autopilot — 자율 개발 루프

## 목적

`docs/superpowers/` 하위의 설계 문서와 구현 계획을 읽고,
모든 태스크가 완료될 때까지 구현 → 검증 → 수정 루프를 반복합니다.

## 사전 조건

아래 중 하나 이상이 존재해야 합니다.

- `docs/superpowers/plans/` 에 구현 계획 파일 (writing-plans 결과)
- `docs/superpowers/specs/` 에 설계 문서 (brainstorming 결과)

없다면 먼저 `/brainstorm` → `/writing-plans` 순서로 진행하세요.

## 실행 절차

### 1단계: 컨텍스트 로드

```
1. CLAUDE.md 읽기 (아키텍처 규칙, 개발 명령어)
2. docs/superpowers/plans/ 에서 최신 plan 파일 읽기
3. docs/superpowers/specs/ 에서 관련 design 파일 읽기
4. .claude/decisions/ 에서 ADR 읽기
5. .claude/tasks/ 에서 기존 작업 상태 확인
```

### 2단계: 태스크 분해 및 상태 파일 생성

plan 파일의 체크박스 기반으로 `.claude/tasks/[feature].md` 생성:

```markdown
# [기능명] 작업 상태

**소스:** docs/superpowers/plans/YYYY-MM-DD-feature.md
**시작:** YYYY-MM-DD
**상태:** 진행 중

## 완료
- [x] Task 1: ...

## 진행 중
- [ ] Task 2: ...

## 대기
- [ ] Task 3: ...

## 결정 사항
- 결정한 내용 기록
```

### 3단계: 구현 루프

각 태스크에 대해:

```
1. plan의 해당 태스크 상세 읽기
2. 관련 기존 코드 확인 (/explore 참고)
3. 구현
4. 빌드/린트/테스트 실행
5. 실패 시 → 오류 분석 후 수정 (/debug 참고)
6. 성공 시 → 태스크 상태 파일 업데이트, 다음 태스크로
```

### 4단계: 완료 조건 확인

아래 모두 충족 시 종료:

- [ ] plan의 모든 체크박스 완료
- [ ] 빌드 통과
- [ ] 린트 오류 없음
- [ ] specs의 요구사항과 대조 확인

### 5단계: 완료 리포트

```
## Autopilot 완료 리포트

**구현된 태스크:** N개
**소요 시간:** -
**생성/수정 파일:** [목록]
**미완료 항목:** [있으면 이유와 함께 기록]
```

## 중단 조건

아래 상황에서는 사용자에게 확인 요청:

- 설계 문서에 없는 큰 아키텍처 결정이 필요한 경우
- 외부 서비스 연동 (API 키, 환경변수 등)이 필요한 경우
- 기존 코드를 대규모로 변경해야 하는 경우
- 동일한 오류가 3회 이상 반복되는 경우
