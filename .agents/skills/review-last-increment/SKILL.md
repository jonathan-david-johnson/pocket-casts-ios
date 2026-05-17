---
name: review-last-increment
description: Retrospective on the most recent chunk of completed work. Identifies missteps, ambiguities, wasted tool calls, repo additions that would have prevented friction, and repetitive user actions that could become skills.
user-invocable: true
---

# Review Last Increment

A meta / retrospective skill. Run after finishing a chunk of work to learn from how the chunk went — what was inefficient, what was ambiguous, what could have been written down in the repo so the next chunk goes smoother.

## When to invoke

User says any of:
- "review last increment"
- "review the last bit"
- "/review-last-increment"
- "retro on what we just did"
- "what could we have done better"

## Step 1 — Define the increment

The "increment" is the **last natural chunk of work** in this conversation. Usually one of:

- The work between two commits.
- The work for one milestone or feature.
- The work between a "start" instruction and the most recent "ship it" / "commit" / "push" / "done" moment.

**Default boundary** (preferred): from the most recent push/commit/"ship it" moment backwards to the previous one. If only one such moment exists, go back to the start of the session.

If the increment is **ambiguous** (multiple plausible boundaries, or no clear shipping moment), do NOT guess. Ask the user to confirm. Present candidates as:

```
Which increment do you want reviewed?

1. "<first ~6 words of prompt that started chunk A>"   started <timestamp>   duration ~<HH:MM>
2. "<first ~6 words of prompt that started chunk B>"   started <timestamp>   duration ~<HH:MM>
3. <some other option>
```

Pick the answer, then proceed.

### Where to get timestamps and durations

- The session transcript is at `~/.claude/projects/<encoded-cwd>/<session-uuid>.jsonl`. Encoded cwd replaces `/` with `-` and is prefixed with `-`. Example: `/Users/jdj/Documents/code/PocketRadio/pocket-casts-ios` → `-Users-jdj-Documents-code-PocketRadio-pocket-casts-ios`.
- Each line has `timestamp` field (ISO 8601) and `type` (`user` / `assistant` / `tool_use_result`).
- Duration of an increment = last assistant message timestamp − first user prompt timestamp of the chunk.
- Tool-use durations: agent tool results include `<usage>... duration_ms: N ...</usage>` blocks; sum or report largest for context.

If you cannot locate the session log, fall back to conversation context — first/last few words and rough sequence position are enough.

## Step 2 — Walk the increment

For each user prompt in the chunk and the assistant work that followed, look for:

### Missteps (things that went wrong and had to be redone)
- Wrong agent names / tool names invoked.
- File paths that didn't exist; searches that turned up empty and had to be widened.
- Build failures from incomplete planning (e.g. missed call sites of a removed symbol).
- Agent tool calls that exceeded the agent's stated scope and had to be restarted with broader authorization.
- Shell commands that needed a second attempt due to syntax/escaping issues.
- Anything committed and then immediately amended.

### Ambiguities (questions the assistant had to guess at)
- Instructions that left implementation details to assistant judgement when user had a preference.
- Names for new files, classes, or properties not specified.
- File location / project structure left unclear.
- Test-vs-no-test, commit-vs-no-commit, push-vs-no-push left implicit.
- Whether output should be inline reply, file, or both.

### Wasted tool calls
- Bash calls that could have been one of: Edit, Read, Grep via Bash, or skipped entirely.
- Repeated Reads of the same file.
- Agent spawns that overlapped work the main thread had already done.
- `find` calls rooted in the wrong directory.

## Step 3 — Identify repo-level fixes

For each friction point, ask: **could a one-time addition to the repo have prevented this?** Common candidates:

- New entry in project `CLAUDE.md` / `AGENTS.md` (conventions, gotchas, file location maps).
- New entry in `README.md` for human-shared facts (e.g. simulator UDIDs, bundle IDs).
- New helper command in `Makefile` for a build/run sequence that was constructed ad-hoc.
- New `.claude/settings.json` permission entry to drop a recurring prompt.
- New `additionalDirectories` entry so a sibling docs directory is reachable.
- New skill (see Step 4).

Each suggestion gets:
- **What** — concrete addition (one sentence).
- **Why** — the specific friction it prevents.
- **Cost** — rough effort to add it now (lines / files touched).

## Step 4 — Spot repetitive user actions worth a skill

Scan the user's prompts across this increment AND look back further if memory or transcript permits. Flag any user action that:

- Recurred ≥2 times in this increment, OR
- Followed a stereotyped sequence the user typed out manually each time, OR
- Could be encoded as a parametrized template.

Examples (don't suggest these unless they actually occurred):
- "commit + push when tests green" repeated → could be a `/ship` skill.
- "run sim + smoke test list X" → could be a `/manual-smoke` skill.
- "summarize this and write to current_milestone.md" → could be a `/plan-milestone` skill.

Each suggestion gets:
- **Trigger phrase** — what the user would type.
- **What it does** — one-paragraph sketch.
- **Why now** — frequency observed.

## Step 5 — Output format

Keep it scannable. Suggested layout:

```
# Increment review: <one-line summary of the chunk>

Scope: <first ~6 words of starting prompt> → <last shipping moment>
Started: <timestamp> · Duration: <HH:MM> · Tool uses: <N>

## Missteps
- file_or_topic — what went wrong — what would have prevented it.

## Ambiguities
- short label — what was unclear — what the user could have specified.

## Wasted tool calls
- type/count — context — cheaper alternative.

## Repo-level fixes worth considering
- [What] — Why — Cost.

## New skills worth considering
- /trigger-phrase — what it does — observed frequency.

## Net efficiency estimate
~N tool calls of ~M total were avoidable. Biggest single ROI: <one item>.
```

End with a one-sentence recommendation. No fluff, no praise.

## Anti-patterns to avoid

- Do NOT write a "what we built" recap — that's a status report, not a retrospective. The user knows what was built.
- Do NOT propose process changes that don't tie to a concrete observed friction.
- Do NOT suggest skills for one-off tasks that won't recur.
- Do NOT propose adding everything to `CLAUDE.md` — the goal is signal, not bloat. If a fact appears in fewer than ~3 plausible future sessions, it doesn't earn a memory line.
- Do NOT moralize. Stick to mechanics: what happened, what would have been faster.

## Constraints

- No code edits during a review. The skill is read-only against the codebase. The output is a report; the user decides what to act on.
- If the user explicitly asks for fixes after the report, that's a separate turn.
