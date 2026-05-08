# /review — 종합 코드 리뷰 오케스트레이터

이 슬래시 커맨드는 현재 브랜치의 변경사항을 `dev` 브랜치 기준으로 종합 코드 리뷰합니다.
아래 지침을 순서대로 정확히 따르세요.

---

## Step 1: 변경사항 수집

```bash
git fetch origin dev
git diff origin/dev...HEAD --name-only
git diff origin/dev...HEAD
```

변경된 파일이 없으면 "변경사항이 없습니다"를 출력하고 중단합니다.

---

## Step 2: 4개 에이전트를 단일 메시지로 병렬 디스패치

**반드시 하나의 메시지에서 Agent 도구를 4번 동시 호출하여 병렬로 실행. 순차 실행 금지.**

각 에이전트에게 Step 1에서 수집한 전체 diff 텍스트를 프롬프트에 포함하여 전달합니다.

---

### Agent 1: Architecture Review

```
당신은 Django 레이어드 아키텍처 전문 리뷰어입니다.
이 프로젝트는 Views → Services → Repositories 레이어 순서를 엄격히 강제합니다.

체크리스트:
1. [Blocker] Views에서 DB 직접 접근: views.py에서 `.objects.` 직접 호출
2. [Blocker] Services에서 DB 직접 접근: services.py에서 `.objects.` 직접 호출
3. [Blocker] 레이어 건너뛰기: View에서 Repository 직접 호출
4. [Critical] Serializer에 비즈니스 로직 포함
5. [Warning] 프로젝트 참조 구현 앱 패턴과의 불일치

심각도: Blocker(머지 차단) / Critical(수정 강력 권고) / Warning(개선 권고) / Info(참고)

이슈 형식:
### [심각도] 이슈 제목
- **파일**: 파일경로:라인번호
- **내용**: 구체적 설명
- **권고**: 권장 수정 방법

--- DIFF START ---
[전체 diff 삽입]
--- DIFF END ---
```

### Agent 2: Security Review

```
당신은 Django 보안 전문 리뷰어입니다.

체크리스트:
1. [Blocker] SQL 인젝션: raw(), extra(), RawSQL() 사용
2. [Blocker] 인증/권한 누락: permission_classes 미설정 또는 AllowAny 남용
3. [Critical] 하드코딩된 시크릿: API 키, 비밀번호, 토큰이 코드에 직접 포함
4. [Critical] XSS, SSRF, 안전하지 않은 역직렬화 취약점
5. [Warning] Django 보안 설정 변경 (ALLOWED_HOSTS, CORS, DEBUG 등)

--- DIFF START ---
[전체 diff 삽입]
--- DIFF END ---
```

### Agent 3: Performance Review

```
당신은 Django 성능 전문 리뷰어입니다.

체크리스트:
1. [Critical] N+1 쿼리: 루프 안에서 ORM 호출, select_related/prefetch_related 누락
2. [Warning] 전체 테이블 스캔: 필터 없는 Model.objects.all()
3. [Warning] DB 인덱스 누락: 자주 조회되는 필드에 db_index 미설정
4. [Info] 직렬화 오버헤드: 불필요하게 많은 필드를 직렬화

--- DIFF START ---
[전체 diff 삽입]
--- DIFF END ---
```

### Agent 4: Code Style Review

```
당신은 Django 코드 스타일 및 품질 전문 리뷰어입니다.

체크리스트:
1. [Warning] CLAUDE.md 코딩 규칙 위반: 외과적 변경 원칙 위반, 관련 없는 코드 수정
2. [Critical] 테스트 규칙 위반: Factory 미사용, PropertyMock 미사용
3. [Info] Django/DRF 컨벤션 위반: 네이밍, 구조, 패턴
4. [Warning] 불필요한 추상화, 과도한 에러 처리, 추측성 기능 추가

--- DIFF START ---
[전체 diff 삽입]
--- DIFF END ---
```

---

## Step 3: 결과 취합 및 리포트 저장

```bash
mkdir -p reviews
```

파일명: `reviews/YYYY-MM-DD-HH-MM-review.md`

```markdown
# Code Review Report
- **Branch**: [브랜치명]
- **Base**: dev
- **Date**: [날짜시간]
- **Files Changed**: [변경 파일 수]

## Summary
| 영역 | Blocker | Critical | Warning | Info |
|------|---------|----------|---------|------|
| Architecture | 0 | 0 | 0 | 0 |
| Security | 0 | 0 | 0 | 0 |
| Performance | 0 | 0 | 0 | 0 |
| Code Style | 0 | 0 | 0 | 0 |

## Blocker / Critical Issues
[없으면 "없음"]

## Architecture
## Security
## Performance
## Code Style
```

---

## Step 4: PR 코멘트 게시

```bash
gh pr view --json number,url 2>/dev/null
```

PR이 있으면 Summary 테이블 + Blocker/Critical 이슈를 코멘트로 게시.
PR이 없으면 건너뜁니다.

---

## Step 5: 터미널 요약 출력

1. Summary 테이블
2. Blocker/Critical 이슈 목록
3. 저장된 리포트 파일 경로
4. PR 코멘트 게시 여부
