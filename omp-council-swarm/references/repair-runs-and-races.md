# Repair Runs, Race Resolution & Acceptance Overrides — worked playbook

Distilled from T004 (Frisbee Angle Analyzer, Aug 2026): 2 council runs, ~230 min
total, commit 3c134bb. Read with SKILL.md § Adjudication ladder.

## 1. When run 1 "passes" but is actually wrong

T004 run1: gauntlet PASS unanimous (12/12 voting seats), yet deliverables were at
WORKSPACE ROOT instead of the brief's `frisbee-angle-analyzer/` directory, CSV
header deviated (`elbow_class` vs `elbow_in_range`, missing `timestamp_s`), docs
deliverables absent. The gauntlet reviewed the diff, not the contract.

Lesson: builders can produce genuinely good code (8 modules, 25 passing tests)
that violates the brief's exact-path/format contracts. The orchestrator's personal
acceptance run — pointing at the CONTRACTUAL path from the brief — is the only
check that catches this. Run it even after unanimous PASS.

Red flags worth a manual look before shipping:
- `git status` shows new files outside the brief's declared layout
- grep for a literal contract string (CSV header, stdout line) comes up empty
- file count wildly below brief's deliverables list

## 2. Repair run, step by step

1. **Gap analysis first.** Enumerate exactly what deviates (layout? formats?
   missing files?) so repair directives are surgical — you want MOVE-and-CONFORM,
   not rewrite. Explicitly PERMIT keeping working internals ("RP2: internal module
   names accepted; do NOT mass-refactor") or builders will churn good code.
2. **Append to `plans/T00X-brief.md`** a `# ⚠️ REPAIR DIRECTIVES — RUN N` section:
   - quote the blocking failure VERBATIM (the exact command + its exact error) —
     playbook R-006: unquoted failures become debates
   - numbered RP items, each one sentence of MUST, mapped back to brief sections
   - an explicit "do not regress" item naming what already works + test counts
   - restate the acceptance command as "the law" and tell the gauntlet to run it
     verbatim before voting
3. **Reset state:** delete `council/T00X/RESULT.json`. Lock is auto-removed on
   dispatcher exit; verify with ls.
4. **Relaunch with --fresh** (mandatory — see trap below), new log filename
   (`council-T00X-repair.log`) so interleaved-run forensics stay possible.
5. Adjudicate run 2 like any other; ship per ladder.

### The no-op trap (cost T004 one investigation cycle)
RESUME logic skips every round whose manifest.json met quorum. After a completed
run that's ALL rounds → plain re-run prints COUNCIL_DONE, exit 0, zero workers,
repair directives never read. --fresh is not optional for repairs.

Cost expectation: full pipeline again (~100–130 min). One repair attempt per task
per session; second FAIL = blocked.

## 3. Minority gauntlet FAILs (run2 shape)

Run2 verdict JSON contains per-seat votes; overall PASS despite R49+R22 FAIL votes
because critical_min was satisfied and P0 seats (R17 security, R29 coverage, R23
edge-cases) all passed. Also seen: a seat dead from provider errors (R23 in run1,
exit=1 post-retry) shrinks voters to 12/13 — quorum math unaffected.

Handling: record minority findings verbatim in ledger notes as known-polish; do
not repair-round them away. If a minority finding is actually a spec violation
(check it against the brief yourself), THAT changes the calculus — then it joins
your acceptance judgment, not the vote count.

## 4. Two-orchestrator races (cron vs interactive session)

Sequence observed end-to-end in T004:
1. Interactive session queues T004 priority 1 → cron loop claims it within minutes.
2. Manual dispatch exits code 5 instantly (LOCKED). This is the rail WORKING.
3. Cron-owned council runs; both processes share one log path → truncation +
   NUL-byte gaps (second open resets length while first keeps write offset).
4. On completion, whichever session holds adjudication ships; the other logs
   stand-down into cycles.jsonl. No double-commit occurred.
5. Both sessions narrate the same race in cycles.jsonl from their own POV — when
   reading history expect two conflicting-sounding lines about one task.

Rules of engagement: never kill a lock-owned run; monitor via filesystem watcher;
if you did NOT launch the running council, do not adjudicate unless the owner
stalled past the 3h stale-lock window.

## 5. Micro-gotchas hit during T004 ops

- `python scripts/x.py badinput | head -2; echo $?` → head's exit code. Verify
  error paths unpiped.
- Appending to giant-line JSONL via fuzzy patch fails twice; rewrite whole file
  via write_file instead (it's tiny).
- `rm -rf` of duplicate skill dirs trips the approval gate even when the dirs are
  identical — duplicates are harmless; leave them unless the user consents.
