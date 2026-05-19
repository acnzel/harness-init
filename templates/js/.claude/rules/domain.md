# DOMAIN.md 운영 규칙

프로젝트 루트의 `DOMAIN.md`와 각 모듈의 `{module}/DOMAIN.md`는
**AI 에이전트가 코드 작성 전 반드시 참조**해야 하는 도메인 지식 문서다.

## 에이전트별 의무

| 에이전트 | 의무 |
|---------|------|
| **analyst** | 분석 시작 전 관련 모듈 `DOMAIN.md` 필수 참조 (엔티티 계층·용어·내부 슬랭 파악) |
| **coder** | 코드 변경 완료 후 새 엔티티·필드·enum 추가 시 해당 모듈 `DOMAIN.md` 관련 섹션 갱신 |
| **reviewer** | DOMAIN.md가 현재 코드 상태를 반영하는지 검증. 누락 시 coder에게 보완 요청 |

## 업데이트 규칙

```
새 엔티티 추가       → 도메인 계층 구조 + 핵심 엔티티 섹션 갱신
새 enum/상수 추가    → 상태 코드 섹션 갱신
신규 모듈 추가       → 루트 DOMAIN.md 인덱스 테이블에 행 추가
```

## DOMAIN.md가 없는 경우

```bash
bash ~/harness-init/scripts/domain-init.sh
```
