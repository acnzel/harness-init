<!-- harness-init: DO NOT REMOVE -->

# CLAUDE.md

{project_name} — Django {version} / {deployment_info}

## 작업 원칙

작업 원칙(코딩 전 사고, 단순함 우선, 외과적 변경, 검증 가능한 목표)과 권한·경계,
검증 파이프라인은 [`AGENTS.md`](./AGENTS.md)가 정본이다. 여기에 다시 적지 않는다 —
요약이 원본과 어긋나는 드리프트를 막기 위해서다.

이 문서는 Claude Code 전용 보충 자료이며, AGENTS.md 의 권한·경계 규칙을 완화하지 않는다.


## 환경 설정

| 환경 | 모듈 | 비고 |
|------|------|------|
| local | `{project}.settings.local` | |
| dev | `{project}.settings.dev` | |
| prod | `{project}.settings.prod` | |
| test | `{project}.settings.test` | SQLite 메모리 DB |

## 상세 규칙

@.claude/rules/knowledge.md
@.claude/rules/architecture.md
@.claude/rules/testing.md
@.claude/rules/domain.md
@.claude/rules/agents.md
@.claude/rules/hooks.md
