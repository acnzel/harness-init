#!/bin/bash
# PostToolUse(Bash) 훅 — gh pr create 직후 리뷰 안내
#
# 이 안내는 원래 settings.json 에 인라인 셸로 박혀 있었고 `$TOOL_INPUT` 을
# 읽었다. 그 환경변수는 존재하지 않으므로 안내가 출력된 적이 없다.
# 파싱은 _hook-input.sh 한 곳에 위임한다 — 인라인으로 다시 옮기지 말 것.

_HELPER="$(dirname "${BASH_SOURCE[0]}")/_hook-input.sh"
# 없음·읽기 불가·문법 오류를 한 번에 잡는다. source 가 실패하면 hook_input_load 가
# 정의되지 않고, 다음 줄이 command not found 로 exit 0 이 되어 훅이 조용히 꺼진다.
if ! source "$_HELPER" || ! declare -F hook_input_load >/dev/null; then
	echo "[harness] $_HELPER 를 불러올 수 없습니다 — post-bash-notice 가 동작하지 않습니다." >&2
	exit 0
fi

hook_input_load || exit 0

case "$HOOK_COMMAND" in
*"gh pr create"*)
	echo ""
	echo "📋 PR이 생성되었습니다. /review 를 실행하여 종합 코드 리뷰를 수행하세요."
	hook_event gate_fired post-bash-notice.sh "pr-created"
	;;
esac

exit 0
