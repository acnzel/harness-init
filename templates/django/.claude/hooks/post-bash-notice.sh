#!/bin/bash
# PostToolUse(Bash) 훅 — gh pr create 직후 리뷰 안내
#
# 이 안내는 원래 settings.json 에 인라인 셸로 박혀 있었고 `$TOOL_INPUT` 을
# 읽었다. 그 환경변수는 존재하지 않으므로 안내가 출력된 적이 없다.
# 파싱은 _hook-input.sh 한 곳에 위임한다 — 인라인으로 다시 옮기지 말 것.

source "$(dirname "${BASH_SOURCE[0]}")/_hook-input.sh"

hook_input_load || exit 0

case "$HOOK_COMMAND" in
*"gh pr create"*)
	echo ""
	echo "📋 PR이 생성되었습니다. /review 를 실행하여 종합 코드 리뷰를 수행하세요."
	hook_event gate_fired post-bash-notice.sh "pr-created"
	;;
esac

exit 0
