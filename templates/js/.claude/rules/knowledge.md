# 지식 계층 — 무엇을 어디서 얻는가

이 프로젝트의 지식은 두 계층으로 나뉜다. **어느 계층에 물어야 하는지 먼저 판단하고 움직인다.**
잘못된 계층에 물으면 낡은 답을 얻거나, 얻을 수 없는 답을 지어내게 된다.

| | 구조 (Structure) | 의미 (Semantics) |
|---|---|---|
| 질문 | 어디에 있나 / 무엇이 부르나 / 바꾸면 어디가 깨지나 | 무슨 뜻인가 / 왜 이런가 / 언제 전이하나 |
| 출처 | **codegraph** (실시간 인덱스) | **DOMAIN.md** (사람이 쓴 문서) |
| 갱신 | 파일 저장 시 자동 (증분 수백 ms) | 사람·에이전트가 직접, 게이트가 강제 |
| 신뢰도 | 코드가 곧 진실 | 문서가 낡았을 수 있음 → 신선도 경고 확인 |

## 구조 질문 → codegraph

파일을 훑어서 구조를 재구성하지 마라. 한 번에 물어보면 된다.

```bash
codegraph explore "<자연어 질문>"   # 관련 심볼 + 소스 + 호출 경로 + 영향 범위
codegraph node <심볼>               # 한 심볼의 소스와 호출 관계
codegraph callers <심볼>            # 누가 호출하나
codegraph impact <심볼>             # 이걸 바꾸면 어디가 영향받나
codegraph affected <파일...>        # 이 파일이 바뀌면 어떤 테스트가 영향받나
```

MCP 도구 `codegraph_explore` 로도 같은 결과를 얻는다.

**codegraph가 없으면** Grep/Read로 폴백한다. 하네스는 codegraph 없이도 동작한다.

## 의미 질문 → DOMAIN.md

여기에만 있는 것:

- enum · `as const` 상수 · 리터럴 union 값이 **각각 무슨 뜻이고 언제 전이하는가**
- 미들웨어 · ORM 훅 · 이벤트 리스너 · 큐 컨슈머가 **무슨 부수효과를 내는가**
- 도메인 용어와 팀 내부 슬랭
- 여러 모듈에 흩어진 비즈니스 규칙
- 과거 사고 지점 (변경 시 주의사항)

**구조를 DOMAIN.md에 적지 마라.** 엔티티 필드 목록, 관계, 계층 트리는 스키마 파일이
진실의 원천이고, 문서에 박제하면 그 순간부터 낡는다.

## 정적 분석 사각지대

명시적 호출이 없는 것은 호출 그래프에 나타나지 않는다. Prisma middleware, ORM 훅,
DB 트리거, 이벤트 리스너, 큐 컨슈머가 여기 해당한다. `codegraph impact` 가 깨끗해
보여도 부수효과가 딸려 나갈 수 있으니, 스키마·엔티티를 건드릴 때는 DOMAIN.md의
'부수효과' 표를 반드시 함께 읽는다.

## 자동 가드레일

개발자가 신경 쓰지 않아도 돌아가도록 세 지점에 게이트가 걸려 있다.

| 시점 | 장치 | 동작 |
|------|------|------|
| 세션 시작 | `session-knowledge.sh` | codegraph 인덱스 동기화 + 낡은 DOMAIN.md 경고 주입 |
| 파일 편집 직후 | `domain-guard.sh` | 의미 변화 감지 시 exit 2 로 갱신 지시 |
| 커밋 직전 | `domain-gate` (pre-commit) | DOMAIN.md 미갱신이면 커밋 차단 |

감지 대상은 **의미가 실제로 바뀐 경우로 한정**된다. 선언 블록의 지문을 변경 전후로
비교하므로 리팩토링에는 발화하지 않는다. 발화했다면 진짜 바뀐 것이다.

판정 대상: TS enum · Prisma enum · `as const` 상수 객체 키 · 문자열 리터럴 union 타입 ·
Prisma `@@map`.

게이트가 `domain-gate: ... 로딩 실패` 로 커밋을 막으면 도메인 위반이 아니라
**판정기 자체가 고장난 것**이다. `.claude/scripts/` 에 `domain-extract.py` 와
`domain-gate.py` 가 함께 있는지 확인한다. 우회하지 말고 고쳐야 한다.

```bash
python3 .claude/scripts/domain-gate.py --staged         # 지금 무엇이 걸리는지
python3 .claude/scripts/domain-freshness.py .           # 문서 신선도 점검
```

## 게이트 우회

`git commit` 에 `--no-verify` 를 붙이면 넘길 수 있지만 **표면화 대상**이다.
우회했으면 PR 설명에 사유를 남긴다. 게이트를 조용히 낮추는 것은 해결이 아니다.
