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
#   hook_report_bypass 게이트 우회를 감지해 기록한다 (막지는 않는다)
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


# ── 게이트 우회 감지 ───────────────────────────────────
# 우회는 금지가 아니라 **표면화 대상**이다. 이 문장은 AGENTS.md 자동 구간,
# domain-gate 차단 메시지, 양쪽 rules/knowledge.md 까지 다섯 곳에 적혀 있었는데
# 기록하는 코드가 없었다. 그래서 우회가 일어났어도 남지 않는다.
#
# 여기 한 곳에만 둔다. django·js pre-bash-guard 가 각자 판정하면 한쪽만 고쳐지고
# 다른 쪽이 조용히 낡는다 — 이 파일이 stdin 파싱을 한 곳에 모은 것과 같은 이유다.
# (실제로 우회 감지를 django 판에만 넣었다가 js 가 빠진 적이 있다.)
#
# 막지 않는다. 막으면 우회의 우회를 학습시킨다.
#
# 사용: hook_report_bypass "$CMD"   → 감지 시 안내를 출력하고 기록, 항상 0 반환
hook_report_bypass() {
	local cmd="$1"
	local bypass=""

	[ -n "$cmd" ] || return 0

	# 커밋·푸시 게이트를 건너뛰는 플래그만 본다. `-n` 은 수많은 명령의 평범한
	# 플래그라 git commit/push 문맥에서만 우회로 친다.
	case "$cmd" in
	*git\ commit*|*git\ push*)
		case "$cmd" in
		*--no-verify*|*" -n "*|*" -n") bypass="no-verify" ;;
		esac
		;;
	esac

	# pre-commit 의 훅 선택적 건너뛰기.
	case "$cmd" in
	SKIP=*|*" SKIP="*) bypass="${bypass:+$bypass,}pre-commit-SKIP" ;;
	esac

	# --no-gpg-sign 은 게이트를 건너뛰지 않는다. 여기서 걸리지 않도록 둔다.

	[ -n "$bypass" ] || return 0

	echo ""
	echo "📝 게이트 우회 기록됨: $bypass"
	echo "   막지는 않습니다. 다만 PR 설명에 사유를 남기세요."
	echo "   누적 확인: python3 .claude/scripts/failure-report.py"
	echo ""
	hook_event bypass_used pre-bash-guard.sh "$bypass |$cmd" || true
	return 0
}
