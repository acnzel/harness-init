# Hooks & 인사이트

## 자동 훅 목록

`settings.json`의 훅이 자동으로 실행된다.

| 이벤트 | 훅 | 동작 |
|--------|-----|------|
| PreToolUse(Bash) | `pre-bash-guard.sh` | migrate/DROP/WHERE없는DELETE 전 경고 출력 |
| PostToolUse(Edit/Write) | `domain-update-reminder.sh` | `models.py` 변경 → DOMAIN.md 갱신 체크리스트 |
| PostToolUse(Edit/Write/Bash) | `insight-collector.sh` | `★ Insight` 블록 감지 → `.claude/insights.md` 저장 |
| Notification | `notification.sh` | 작업 완료 시 OS 알림 (macOS/Linux/터미널 벨) |

추가 훅은 `.claude/hooks/*.sh`로 추가하고 `settings.json`의 `hooks` 섹션에 등록하라.

## Inline 인사이트 — 대화 중 자동 학습

작업 중 **이 코드베이스에 특화된 비자명한 패턴**을 발견하면 즉시 출력하라:

```
★ Insight ─────────────────────────────────────
  [발견한 원칙 또는 패턴 — 코드 스니펫 포함 가능]
─────────────────────────────────────────────────
```

### 출력 기준 (모두 충족해야 함)

| 질문 | 기준 |
|------|------|
| "5분 안에 구글로 찾을 수 있는가?" | **NO** |
| "이 코드베이스에 특화된 내용인가?" | **YES** |
| "실제 분석/디버깅으로 발견했는가?" | **YES** |

출력하지 말아야 할 때:
- Django ORM, DRF 등 일반 라이브러리 사용법
- 팀이 이미 DOMAIN.md 또는 CLAUDE.md에 기록한 내용

반복적으로 유용할 것 같으면 `/learn` 슬래시 커맨드로 `.claude/skills/`에 저장하라.
