---
description: 현재 대화에서 발견한 인사이트를 프로젝트 스킬로 저장한다
argument-hint: "[skill-name]"
---

# /learn — 인사이트를 스킬로 저장

대화 중 발견한 비자명한 패턴이나 이 코드베이스 특화 인사이트를 `.claude/skills/` 에 영구 저장한다.

## 실행 절차

### 1. 인사이트 식별

현재 대화에서 다음 기준을 모두 충족하는 인사이트를 찾는다:
- 5분 안에 구글로 찾을 수 없는 내용
- 이 코드베이스에 특화된 내용
- 실제 디버깅/분석으로 발견한 내용

기준을 충족하는 인사이트가 없으면 사용자에게 알리고 종료.

### 2. 스킬 이름 결정

- 인수가 제공된 경우: `$ARGUMENTS` 를 소문자-하이픈(kebab-case) 형식으로 변환하여 스킬명으로 사용
- 인수가 없는 경우: 인사이트 내용에서 소문자-하이픈 형식으로 이름 생성
  - 예: `django-db-table-naming`, `permission-layer-split`, `cash-lock-state-mismatch`

### 3. 스킬 파일 작성

`.claude/skills/{skill-name}.md` 에 저장:
- 동일 이름 파일이 이미 존재하면 기존 내용을 보여주고 덮어쓸지 사용자에게 확인한 후 진행

```markdown
---
name: {skill-name}
description: {한 줄 설명}
triggers:
  - {관련 코드 패턴 (예: 함수명, 데코레이터, 에러 메시지 일부)}
  - {특정 파일 경로 또는 핵심 도메인 용어}
---

# {스킬 제목}

## The Insight
발견한 원칙 — 코드가 아닌 멘탈 모델 중심으로 기술.

## Why This Matters
이것을 모르면 어떤 문제가 생기는가? 어떤 증상으로 여기까지 왔는가?

## Recognition Pattern
이 스킬이 언제 적용되는가? 어떤 신호가 있는가?

## The Approach
의사결정 휴리스틱 — 동일한 상황에 다시 적용할 수 있도록.

## Example (선택)
원칙을 보여주는 코드 예시 (copy-paste가 아닌 설명용).
```

### 4. 저장 완료 보고

```
✓ 스킬 저장 완료: .claude/skills/{skill-name}.md
  트리거: {trigger-1}, {trigger-2}
  다음 대화부터 관련 패턴 발견 시 자동 참조됩니다.
```
