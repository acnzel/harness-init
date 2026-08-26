"""실패 패턴 보고서 — 쌓인 이벤트를 "무엇이 반복해서 방해하는가"로 묶는다.

왜 이 파일이 있나
-----------------
기록만 하고 아무도 안 읽는 로그는 없는 것과 같다. `.claude/local/events-*.jsonl`
에는 이미 게이트 발화·차단·우회·실행 결과가 쌓이지만, 사람이 jsonl 을 직접 읽지는
않는다. 여기서 읽을 수 있는 형태로 바꾼다.

무엇을 세는가
-------------
    bypass_used      게이트를 우회했다. 하네스가 방해가 됐다는 가장 강한 신호
    gate_blocked     게이트가 실제로 막았다
    gate_run         pre-push·CI 통합 게이트의 pass/fail/skip
    gate_fired       경고성 훅이 발화했다
    selftest_failed  게이트 자체가 고장났다

1회는 데이터가 아니다
---------------------
반복 근거 없이 규칙을 만들면 그 프로젝트에만 맞는 임시방편이 된다. 그래서 2회 이상
재발한 것만 "규칙 후보"로 올리고, 1회는 별도로 표시만 한다. 사용자 전역의
`/weekly-retro` 가 debrief 2건 이상 재발을 승격 조건으로 두는 것과 같은 기준이다.

이 보고서는 규칙을 만들지 않는다. 무엇이 반복되는지만 보여준다. 승격 판단은
사람이 하고, 규칙 레지스트리는 전역(`~/.claude/rules/rules.yaml`)이 소유한다.
하네스는 프로젝트에서 관측한 사실만 공급한다.

사용법:
    python3 failure-report.py [repo] [--since YYYY-MM] [--format text|json]
"""

import argparse
import json
import os
import sys
from collections import Counter, defaultdict

RECURRENCE_THRESHOLD = 2

GREEN, YELLOW, RED, BLUE, DIM, RESET = (
    "\033[0;32m",
    "\033[1;33m",
    "\033[0;31m",
    "\033[0;34m",
    "\033[2m",
    "\033[0m",
)
if not sys.stdout.isatty() or os.environ.get("NO_COLOR"):
    GREEN = YELLOW = RED = BLUE = DIM = RESET = ""


def load_events(root, since=None):
    """events-*.jsonl 을 읽는다. 깨진 줄은 건너뛴다 — 한 줄 때문에 전체를 잃지 않는다."""
    directory = os.path.join(root, ".claude", "local")
    events = []
    if not os.path.isdir(directory):
        return events
    for name in sorted(os.listdir(directory)):
        if not (name.startswith("events-") and name.endswith(".jsonl")):
            continue
        if since and name[len("events-") : -len(".jsonl")] < since:
            continue
        try:
            with open(os.path.join(directory, name), encoding="utf-8") as handle:
                for line in handle:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        events.append(json.loads(line))
                    except ValueError:
                        continue
        except OSError:
            continue
    return events


def label(detail):
    """detail 의 앞부분이 무엇이 발화했는지를 담는다: "no-verify |git commit ..."."""
    if not detail:
        return "(미상)"
    head = detail.split("|", 1)[0].strip()
    return head or "(미상)"


def summarize(events):
    """이벤트를 종류별 카운터로 접는다."""
    counts = defaultdict(Counter)
    failed_gates = Counter()
    timeline = defaultdict(list)

    for event in events:
        kind = event.get("event", "")
        stamp = event.get("ts", "")[:10]
        if kind == "gate_run":
            try:
                payload = json.loads(event.get("detail", "{}"))
            except ValueError:
                continue
            for name in payload.get("fail", []):
                failed_gates[name] += 1
                timeline[f"gate_failed::{name}"].append(stamp)
            continue
        if kind in ("bypass_used", "gate_blocked", "gate_fired", "selftest_failed"):
            name = label(event.get("detail", ""))
            counts[kind][name] += 1
            timeline[f"{kind}::{name}"].append(stamp)

    return counts, failed_gates, timeline


SECTIONS = [
    (
        "bypass_used",
        "게이트 우회",
        RED,
        "하네스가 방해가 됐다는 신호. 반복되면 그 게이트가 과차단하는지 본다.",
    ),
    (
        "gate_blocked",
        "게이트 차단",
        YELLOW,
        "실제로 막은 횟수. 정상 작동이지만, 같은 게 계속 막히면 안내가 부족한 것이다.",
    ),
    (
        "selftest_failed",
        "자가진단 실패",
        RED,
        "게이트 자체가 고장났다. 무음 통과 중이므로 최우선.",
    ),
    (
        "gate_fired",
        "경고 발화",
        BLUE,
        "차단 없이 경고만 한 것. 반복되면 차단으로 올릴 후보.",
    ),
]


def render_text(counts, failed_gates, timeline, total, threshold=RECURRENCE_THRESHOLD):
    lines = []
    add = lines.append

    add("")
    add(f"{BLUE}━━━ 실패 패턴 보고서 ━━━{RESET}")
    add(f"  이벤트 {total}건")
    add("")

    candidates = []
    anything = False

    for kind, title, color, note in SECTIONS:
        bucket = counts.get(kind)
        if not bucket:
            continue
        anything = True
        add(f"{color}▸ {title}{RESET}")
        add(f"  {DIM}{note}{RESET}")
        for name, count in bucket.most_common():
            days = len(set(timeline.get(f"{kind}::{name}", [])))
            mark = "★" if count >= threshold else " "
            add(f"    {mark} {name}  {count}회 ({days}일)")
            if count >= threshold:
                candidates.append((title, name, count, days))
        add("")

    if failed_gates:
        anything = True
        add(f"{RED}▸ 통합 게이트 실패{RESET}")
        add(
            f"  {DIM}pre-push·CI 에서 떨어진 게이트. 자주 떨어지면 기준이 현실과 다르다.{RESET}"
        )
        for name, count in failed_gates.most_common():
            days = len(set(timeline.get(f"gate_failed::{name}", [])))
            mark = "★" if count >= threshold else " "
            add(f"    {mark} {name}  {count}회 ({days}일)")
            if count >= threshold:
                candidates.append(("통합 게이트 실패", name, count, days))
        add("")

    if not anything:
        add(f"  {DIM}기록된 실패 이벤트가 없습니다.{RESET}")
        add(f"  {DIM}0건은 '문제 없음'이 아니라 '아직 관측되지 않음'입니다.{RESET}")
        add(
            f"  {DIM}훅이 살아 있는지: bash .claude/hooks/gate-selftest.sh --verbose{RESET}"
        )
        add("")
        return "\n".join(lines)

    add(f"{GREEN}━━━ 규칙 후보 ({threshold}회 이상 재발) ━━━{RESET}")
    if candidates:
        for title, name, count, days in sorted(candidates, key=lambda row: -row[2]):
            add(f"  ★ [{title}] {name} — {count}회 / {days}일")
        add("")
        add(
            f"  {DIM}이 보고서는 규칙을 만들지 않습니다. 승격은 사람이 판단하고,{RESET}"
        )
        add(
            f"  {DIM}규칙 레지스트리는 전역(~/.claude/rules/rules.yaml)이 소유합니다.{RESET}"
        )
    else:
        add(
            f"  {DIM}아직 없습니다. 1회는 데이터가 아닙니다 — 반복 근거 없이 규칙을{RESET}"
        )
        add(f"  {DIM}만들면 이 프로젝트에만 맞는 임시방편이 됩니다.{RESET}")
    add("")
    return "\n".join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("repo", nargs="?", default=".")
    parser.add_argument("--since", help="YYYY-MM 이후의 월별 파일만 읽는다")
    parser.add_argument("--format", choices=("text", "json"), default="text")
    parser.add_argument(
        "--threshold",
        type=int,
        default=RECURRENCE_THRESHOLD,
        help="규칙 후보로 올릴 재발 횟수 (기본 2)",
    )
    args = parser.parse_args(argv)
    threshold = args.threshold

    events = load_events(args.repo, args.since)
    counts, failed_gates, timeline = summarize(events)

    if args.format == "json":
        payload = {
            "total_events": len(events),
            "threshold": threshold,
            "counts": {kind: dict(bucket) for kind, bucket in counts.items()},
            "failed_gates": dict(failed_gates),
            "candidates": sorted(
                (
                    {"kind": kind, "name": name, "count": count}
                    for kind, bucket in counts.items()
                    for name, count in bucket.items()
                    if count >= threshold
                ),
                key=lambda row: -row["count"],
            ),
        }
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        print(render_text(counts, failed_gates, timeline, len(events), threshold))

    # 보고서는 진단이지 게이트가 아니다. 실패가 있어도 0 으로 끝난다.
    return 0


if __name__ == "__main__":
    sys.exit(main())
