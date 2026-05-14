# Project Debrief Guardrails — {{PROJECT_NAME}}

이 프로젝트 코드베이스에만 적용되는 주의사항.
세션에서 발견한 프로젝트 특화 교훈을 누적한다.

---

## 도메인 ID / 타입 혼동 주의

<!-- 예시:
- `managers/<pk>/` → Manager.id (Manager 모델 PK)
- `managers/profile/<pk>/` → ManagerProfile.id (ManagerProfile 모델 PK)
- 훅 인자로 받는 `id`가 어떤 모델의 ID인지 항상 fetch URL로 역추적
-->

---

## 코드베이스 특화 패턴

<!-- 예시:
- 레이어 경계: Views → Services → Repositories (건너뛰기 금지)
- 테스트 데이터는 반드시 Factory 사용 (Model.objects.create() 금지)
-->

---

## 반복 실수 히스토리

<!-- 날짜와 함께 기록. 같은 실수 2회 이상이면 위 섹션으로 승격
- YYYY-MM-DD: [실수 내용] → [올바른 접근]
-->
