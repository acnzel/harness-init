# 레이어드 아키텍처 규칙

참조 구현 앱(`{reference_app}`)을 기준으로 새 기능을 작성한다.
의존성: **Views → Services → Repositories** (역방향/건너뛰기 금지)

**예외: 크론/배치 함수** — 직접 ORM 접근을 허용하며, 기존 크론 함수 패턴을 따른다.

```
{app_name}/
├── views.py          # HTTP 요청/응답만. Service 호출만 허용
├── services.py       # 비즈니스 로직. Repository 호출만 허용
├── repositories.py   # DB 접근 전담. 순수 쿼리만
├── serializers.py    # 직렬화/역직렬화만. 비즈니스 로직 금지
├── models.py
└── urls.py
```

## 절대 금지

| 규칙 | 이유 |
|------|------|
| Views에서 DB 직접 접근 금지 | Service 레이어를 통해서만 접근 |
| Services에서 DB 직접 접근 금지 | Repository를 통해서만 접근 |
| 레이어 건너뛰기 금지 | Views → Services → Repositories 순서 엄수 |
| `Model.objects.create()` 테스트 금지 | `utils/factories.py`의 Factory만 사용 |
