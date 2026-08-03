#!/bin/bash
# SessionStart 훅 — 게이트 자가진단
#
# 왜 필요한가
# -----------
# 훅은 대부분 fail-open 이다. 깨져도 조용히 exit 0 하고, 세션에는 아무 표시가
# 없다. 그래서 "게이트가 조용하다"를 안전으로 읽게 된다.
#
# 실제로 그랬다. pre-bash-guard.sh 는 존재하지 않는 `$TOOL_INPUT` 을 읽어서
# migrate·DROP TABLE 경고가 한 번도 발화한 적이 없었고, 발화 기록이 없으니
# 아무도 몰랐다 (2026-08-03 실측 확인).
#
# 검사가 0건을 반환하는 것은 안전 신호가 아니라 스캐너가 깨졌다는 신호일 수
# 있다. 그래서 **알려진 양성 케이스 1건이 실제로 잡히는지**로 스캐너 자체를
# 먼저 검증한다.
#
# 판정 방식: positive / negative 쌍
# ---------------------------------
#   positive 가 조용하다 → 게이트 사망 (판정 못 함)
#   negative 가 발화한다 → 게이트 과발화 (아무 때나 떠서 곧 무시당함)
# 둘 다 통과해야 "이 게이트는 구분할 줄 안다"가 증명된다.
# 한쪽만 보면 항상 발화하는 훅도 정상으로 통과한다.
#
# 사용법:
#   bash .claude/hooks/gate-selftest.sh              # 실패만 출력 (SessionStart)
#   bash .claude/hooks/gate-selftest.sh --verbose    # 전 항목 출력 (수동 점검)
set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$HOOK_DIR/../scripts"
VERBOSE=0
[ "${1:-}" = "--verbose" ] && VERBOSE=1

# 자가진단이 주입하는 합성 페이로드가 발화 통계를 오염시키지 않게 한다.
# (hook_event 가 이 변수를 보고 기록을 건너뛴다.)
export HARNESS_SELFTEST=1

FAILURES=""
PASSES=""
SKIPS=""

pass() { PASSES="$PASSES\n  ✓ $1"; }
fail() { FAILURES="$FAILURES\n  ✗ $1"; }
skip() { SKIPS="$SKIPS\n  - $1"; }

payload() {
	# $1 = command 문자열. JSON 이스케이프는 python3 에 맡긴다 — 셸에서
	# 손으로 만들면 따옴표가 든 명령에서 깨진다.
	python3 -c 'import json,sys; print(json.dumps({"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":sys.argv[1]},"session_id":"selftest"}))' "$1"
}

# ── 1. hook-io.py 파싱 왕복 ────────────────────────────
# 파싱이 깨지면 이 파일을 쓰는 모든 훅이 동시에 죽는다. 가장 먼저 본다.
if [ ! -f "$SCRIPTS_DIR/hook-io.py" ]; then
	fail "hook-io.py 없음 — 훅 페이로드 파싱 불가 (전 훅 무력화)"
elif ! command -v python3 >/dev/null 2>&1; then
	fail "python3 없음 — 훅 판정을 수행할 수 없음 (전 훅 무력화)"
else
	MARKER='DROP TABLE selftest_marker'
	MARKER_PAY=$(payload "$MARKER")
	PARSED=$(printf '%s' "$MARKER_PAY" | python3 "$SCRIPTS_DIR/hook-io.py" parse 2>/dev/null)
	if echo "$PARSED" | grep -q "^HOOK_PARSE_OK=1" && echo "$PARSED" | grep -qF "$MARKER"; then
		pass "hook-io.py parse — 페이로드 왕복 정상"
	else
		fail "hook-io.py parse — 페이로드에서 command 를 복원하지 못함"
	fi
fi

# ── 2. pre-bash-guard 발화 판정 ────────────────────────
# DROP TABLE 은 django·js 두 변형 모두가 감지하는 케이스라 스택 무관하다.
GUARD="$HOOK_DIR/pre-bash-guard.sh"
if [ ! -f "$GUARD" ]; then
	skip "pre-bash-guard.sh 미설치"
else
	# 페이로드를 먼저 변수에 담는다. 파이프로 바로 물리면 죽은 훅(stdin 을
	# 읽지 않는 훅)이 즉시 종료하면서 생산자 쪽에 SIGPIPE 가 떠서, 정작
	# 진단해야 할 상황에서 BrokenPipeError 노이즈가 결과를 덮는다.
	POS_PAY=$(payload 'mysql -e "DROP TABLE users;"')
	NEG_PAY=$(payload 'git status --short')
	POS_OUT=$(printf '%s' "$POS_PAY" | bash "$GUARD" 2>/dev/null)
	NEG_OUT=$(printf '%s' "$NEG_PAY" | bash "$GUARD" 2>/dev/null)

	if [ -z "$POS_OUT" ]; then
		fail "pre-bash-guard.sh — DROP TABLE 이 통과됨 (게이트 사망: 무음 통과 중)"
	elif [ -n "$NEG_OUT" ]; then
		fail "pre-bash-guard.sh — 'git status' 에도 발화함 (과발화: 곧 무시당함)"
	else
		pass "pre-bash-guard.sh — 위험 명령 감지, 안전 명령 무시"
	fi
fi

# ── 3. domain-gate 로딩 ────────────────────────────────
# 여기서는 '판정이 맞는가'가 아니라 '실행은 되는가'만 본다. 의미 변화 판정에는
# git 리비전 상태가 필요해 세션 시작 시점에 재현할 수 없다. 커밋 시점의
# pre-commit 이 실제 판정을 담당한다.
GATE="$SCRIPTS_DIR/domain-gate.py"
if [ ! -f "$GATE" ]; then
	skip "domain-gate.py 미설치"
elif python3 "$GATE" --help >/dev/null 2>&1; then
	pass "domain-gate.py — 로딩 정상"
elif [ ! -f "$SCRIPTS_DIR/domain-extract.py" ]; then
	# 가장 흔한 실패다. domain-gate 는 옆의 domain-extract.py 를 파일 경로로
	# 로드하므로, 하나만 복사된 부분 설치에서 조용히 종료 코드 2가 된다.
	fail "domain-gate.py — 짝인 domain-extract.py 가 없어 로딩 실패 (부분 설치)"
else
	fail "domain-gate.py — 실행 실패 (의미 변화 게이트가 무력화됨)"
fi

# ── 결과 ───────────────────────────────────────────────
if [ -n "$FAILURES" ]; then
	echo ""
	echo "🚨 [게이트 자가진단 실패]"
	# shellcheck disable=SC2059
	printf "$FAILURES\n"
	echo ""
	echo "  위 게이트는 무음 통과 중입니다. 차단이 걸릴 것으로 믿고 작업하지 마세요."
	echo "  복구: harness-init 을 재실행하면 하네스 소유 훅이 최신으로 갱신됩니다."
	echo "        bash <harness-init 경로>/init.sh"
	echo "  확인: bash .claude/hooks/gate-selftest.sh --verbose"
	echo ""
	python3 "$SCRIPTS_DIR/hook-io.py" event \
		--event selftest_failed --source gate-selftest.sh \
		--detail "$(printf "%b" "$FAILURES" | tr '\n' ';')" \
		--repo "$PROJECT_DIR" >/dev/null 2>&1 || true
fi

if [ "$VERBOSE" = 1 ]; then
	echo ""
	echo "[게이트 자가진단]"
	[ -n "$PASSES" ] && printf "$PASSES\n"
	[ -n "$SKIPS" ] && printf "$SKIPS\n"
	[ -z "$FAILURES" ] && echo "" && echo "  전 항목 통과."
	echo ""
fi

# SessionStart 를 막지 않는다. 진단 실패는 알리되 세션은 계속되어야 한다.
exit 0
