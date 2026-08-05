#!/bin/bash
# 훅 공용 헬퍼 — source 해서 쓴다. 단독 실행용이 아니다.
#
# Claude Code 훅은 도구 정보를 stdin 에 JSON 으로 넘긴다. 환경변수가 아니다.
# 이 파일이 생기기 전 pre-bash-guard.sh 는 `${TOOL_INPUT:-}` 를 읽어서
# 아무것도 감지하지 못한 채 조용히 통과하고 있었다 (2026-08-03 실측).
#
# 파싱을 훅마다 각자 하면 같은 불일치가 또 생긴다. 여기 한 곳에만 둔다.
#
# 제공하는 것:
#   hook_input_load   stdin 을 소비하고 HOOK_* 변수를 채운다
#   hook_event        발화를 .claude/local/events-YYYY-MM.jsonl 에 기록한다
#
# 사용 예:
#   source "$(dirname "${BASH_SOURCE[0]}")/_hook-input.sh"
#   hook_input_load
#   [ "$HOOK_PARSE_OK" = 1 ] || exit 0
#   echo "$HOOK_COMMAND" | grep -q ...

# 판정기 경로는 CLAUDE_PROJECT_DIR 가 아니라 **이 스크립트 자신의 위치**에서
# 찾는다. 그 변수는 비어 있거나 다른 곳을 가리킬 수 있고, 그러면 헬퍼를 못 찾은
# 채 조용히 통과한다 — 바로 이 파일이 고치려는 실패 유형이다.
_HARNESS_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_HARNESS_HOOK_IO="$_HARNESS_HOOK_DIR/../scripts/hook-io.py"

HOOK_PARSE_OK=0
HOOK_EVENT=""
HOOK_TOOL=""
HOOK_COMMAND=""
HOOK_FILE_PATH=""
HOOK_SESSION=""
HOOK_CWD=""
HOOK_RAW=""

hook_input_load() {
	HOOK_RAW="$(cat)"

	if ! command -v python3 >/dev/null 2>&1; then
		echo "[harness] python3 없음 — 훅 판정을 수행할 수 없습니다. 차단을 믿지 마세요." >&2
		HOOK_PARSE_OK=0
		return 1
	fi

	if [ ! -f "$_HARNESS_HOOK_IO" ]; then
		echo "[harness] hook-io.py 없음 ($_HARNESS_HOOK_IO) — 훅 판정 불가." >&2
		HOOK_PARSE_OK=0
		return 1
	fi

	# parse 는 실패해도 HOOK_PARSE_OK=0 대입문을 내보낸다. eval 결과로 항상
	# 변수가 갱신되므로 이전 값이 남아 오판하는 일이 없다.
	eval "$(printf '%s' "$HOOK_RAW" | python3 "$_HARNESS_HOOK_IO" parse)"
	[ "$HOOK_PARSE_OK" = 1 ]
}

hook_event() {
	# $1=event $2=source $3=detail
	# 계측 실패가 게이트를 막아서는 안 된다 — 항상 성공으로 끝낸다.
	#
	# 자가진단이 주입하는 합성 페이로드는 기록하지 않는다. 기록하면 실제 발화
	# 통계가 세션 수만큼 부풀어 "이 게이트가 얼마나 쓸모 있나"를 못 읽는다.
	[ -n "${HARNESS_SELFTEST:-}" ] && return 0
	[ -f "$_HARNESS_HOOK_IO" ] || return 0
	command -v python3 >/dev/null 2>&1 || return 0
	python3 "$_HARNESS_HOOK_IO" event \
		--event "$1" \
		--source "$2" \
		--tool "${HOOK_TOOL:-}" \
		--session "${HOOK_SESSION:-}" \
		--detail "${3:-}" \
		--repo "${CLAUDE_PROJECT_DIR:-$PWD}" >/dev/null 2>&1 || true
	return 0
}
