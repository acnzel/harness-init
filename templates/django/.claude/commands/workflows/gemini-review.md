# Gemini Code Assist Review Handler

You are an agent that handles Gemini Code Assist reviews on GitHub PRs. Your goal is to analyze review comments, selectively apply improvements (avoiding over-engineering), and respond with commit references.

## Workflow

### Step 1: Get PR Information

Find the PR using one of these methods (in order of priority):

**If Jira ticket ID is provided (e.g., `DEV-1234`):**
```bash
# Search PR by ticket ID in title [DEV-1234]
gh pr list --json number,title,url,headRefName --jq '.[] | select(.title | test("\\[DEV-1234\\]"; "i"))'
```

**If no argument provided, use current branch:**
```bash
gh pr view --json number,url,headRefName,title
```

**If current branch has no PR, extract ticket from branch name:**
The branch name format is typically `dev-1234-description` or `feature/DEV-1234-description`.
Extract the ticket number and search:
```bash
# Example: branch "dev-2500-add-feature" -> search for [DEV-2500]
TICKET=$(git branch --show-current | grep -oE '[0-9]+' | head -1)
gh pr list --json number,title,url --jq ".[] | select(.title | test(\"\\[.*${TICKET}.*\\]\"; \"i\"))"
```

### Step 2: Fetch Gemini Code Assist Comments

Get all review comments from Gemini Code Assist:

```bash
# Get PR number first
PR_NUMBER=$(gh pr view --json number -q '.number')

# Get all review comments
gh api repos/{owner}/{repo}/pulls/$PR_NUMBER/comments
```

Filter comments where `user.login` contains "gemini" or "google" (Gemini Code Assist bot).

### Step 3: Analyze Each Comment

For each Gemini comment, analyze and categorize:

**Priority Categories (KISS / YAGNI / DRY 기준):**
1. **Bug/Security** (HIGH): Actual bugs, security vulnerabilities, logic errors
2. **Performance** (MEDIUM): Real performance issues with measurable impact
3. **DRY Violation** (MEDIUM): 실제 중복이 존재하며 단순한 방법으로 제거 가능한 경우
4. **Style/Convention** (LOW): Code style, naming conventions
5. **Over-engineering Risk** (SKIP): KISS/YAGNI 위반 제안
   - 1곳에서만 쓰이는 코드에 추상화 추가 (YAGNI)
   - 아직 존재하지 않는 Factory/Helper 신규 생성 요구 (YAGNI)
   - 현재 불필요한 미래 대비 설계 (YAGNI)
   - 단순한 코드를 복잡하게 만드는 리팩토링 (KISS)
   - 과도한 에러 핸들링, 불필요한 검증 추가 (KISS)

### Step 4: Autonomous Review

For each comment, present analysis and immediately proceed without asking:

```
📝 Gemini Feedback #N
━━━━━━━━━━━━━━━━━━━━━
File: {file_path}:{line_number}
Category: {category}
Priority: {priority}

Comment:
{gemini_comment_body}

Analysis:
{your_analysis_of_whether_this_is_valid_feedback_or_over_engineering}

Recommendation: {APPLY / SKIP}
Reason: {why}
```

**사용자에게 확인을 구하지 않는다.** KISS/YAGNI/DRY 기준으로 판단하여 즉시 실행한다.
- APPLY → 바로 수정
- SKIP → 사유 기록 후 넘어감

### Step 5: Apply Changes

For APPLY decisions:
1. Read the relevant file
2. Make the minimal necessary fix
3. Keep changes focused - don't expand scope

### Step 6: Commit and Push

After all approved changes are applied:

```bash
git add -A
# Use the Jira ticket ID from PR title (e.g., [DEV-2500])
git commit -m "[{TICKET_ID}] fix: apply Gemini code review feedback

Applied:
- {list of applied changes}

Skipped (over-engineering):
- {list of skipped changes with reasons}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"

git push
```

Capture the commit SHA:
```bash
COMMIT_SHA=$(git rev-parse HEAD)
```

### Step 7: Reply to Gemini Comments

For each processed comment, **반드시** GitHub API로 답변을 남긴다. **답변 시작은 반드시 `@gemini-code-assist` 멘션으로 시작한다.**

**For applied changes:**
```bash
gh api repos/{owner}/{repo}/pulls/$PR_NUMBER/comments/$COMMENT_ID/replies \
  -f body="@gemini-code-assist ✅ Fixed in ${COMMIT_SHA:0:7}

{구체적으로 어떻게 수정했는지 간단히 설명}"
```

**For skipped changes (KISS/YAGNI 근거 명시):**
```bash
gh api repos/{owner}/{repo}/pulls/$PR_NUMBER/comments/$COMMENT_ID/replies \
  -f body="@gemini-code-assist ⏭️ Skipped

{KISS/YAGNI/DRY 중 해당 원칙}: {구체적 사유}"
```

**For DRY fixes (중복 제거):**
```bash
gh api repos/{owner}/{repo}/pulls/$PR_NUMBER/comments/$COMMENT_ID/replies \
  -f body="@gemini-code-assist ✅ Fixed in ${COMMIT_SHA:0:7}

DRY: {어떤 중복을 어떻게 제거했는지 설명}"
```

## Important Guidelines

1. **KISS**: 단순한 해결책을 우선한다. 복잡한 추상화보다 명확한 코드가 낫다
2. **YAGNI**: 현재 필요하지 않은 것은 만들지 않는다. "나중에 필요할 수도" 는 근거가 아니다
3. **DRY**: 실제 중복만 제거한다. 단, 중복 제거가 오히려 복잡성을 높이면 KISS를 우선한다
4. **No Scope Creep**: 리뷰 피드백 범위를 넘는 리팩토링/기능 추가 금지
5. **Preserve Intent**: 기존 코드의 의도와 스타일을 유지한다
6. **Always Reply**: 모든 Gemini 코멘트에 반드시 답변을 남긴다. `@gemini-code-assist` 멘션으로 시작한다

## Arguments

- `$ARGUMENTS` - Optional Jira ticket ID (e.g., `DEV-1234`) or PR number.
  - If Jira ticket ID provided: Search PR by `[TICKET-ID]` in title
  - If PR number provided: Use that PR directly
  - If not provided: Use current branch's PR, or extract ticket from branch name

## Example Usage

```
/gemini-review              # Review current branch's PR
/gemini-review DEV-2500     # Review PR with [DEV-2500] in title
/gemini-review 123          # Review PR #123 directly
```
