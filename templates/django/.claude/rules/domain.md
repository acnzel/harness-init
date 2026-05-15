# DOMAIN.md 운영 규칙

프로젝트 루트의 `DOMAIN.md`와 각 앱의 `{app}/DOMAIN.md`는
**AI 에이전트가 코드 작성 전 반드시 참조**해야 하는 도메인 지식 문서다.

## 에이전트별 의무

| 에이전트 | 의무 |
|---------|------|
| **analyst** | 분석 시작 전 관련 앱 `DOMAIN.md` 필수 참조 (모델 계층·용어·내부 슬랭 파악) |
| **coder** | 코드 변경 완료 후 해당 앱 `DOMAIN.md` 변경 이력 갱신. 새 모델·필드·choices 추가 시 해당 섹션도 갱신 |
| **reviewer** | DOMAIN.md 변경 이력이 이번 작업을 반영하는지 검증. 누락 시 coder에게 보완 요청 |

## 업데이트 규칙

```
코드 변경       → {app}/DOMAIN.md 변경 이력 테이블에 한 줄 추가
새 모델 추가    → 도메인 계층 구조 + 핵심 모델 섹션 갱신
새 choices 추가 → 상태 코드 섹션 갱신
신규 앱 추가    → 루트 DOMAIN.md 인덱스 테이블에 행 추가
```

## DOMAIN.md가 없는 경우

```bash
bash ~/harness-init/scripts/domain-init.sh
```
