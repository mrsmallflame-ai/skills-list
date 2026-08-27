---
name: agent-councils
description: "Orchestrate a multi-seat council of coding-agent CLI workers (omp, codex, claude) that propose, critique, judge, build, and re-review each other's work through structured rounds on a shared file blackboard."
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [multi-agent, swarm, orchestration, code-review, quality-gates]
    related: [autonomous-ai-agents, agentic-business-loops]
---

# Agent Councils

One orchestrator + N role-specialized agent workers that debate each other
through structured rounds before any code ships. The point is **one-shot
accuracy**: every defect the critics can find pre-build is a defect that never
reaches production.

## When to use

- Task quality matters more than latency or token cost.
- A single builder+reviewer pair has already produced repeated rework.
- The work decomposes into roles with genuinely different expertise.

Skip it for typo fixes and one-file edits — a single print-mode call wins there.

## Architecture in one paragraph

A **roster** (JSON: role id, name, charter, angle, squad) defines seats. A
**dispatcher** (Node/bash script) runs fixed ROUNDS; within a round all
convening seats run **in parallel** against a shared **blackboard** directory
(`council/<TASK>/NN-round/<seat>.md`). Later rounds read earlier outputs, so
agents "talk" through files, not chat. Rounds end in verdicts with quorum gates;
only the orchestrator commits.

Canonical round ladder (tune counts to task size):

```
01-propose   ~9 seats blind-parallel  → proposals from distinct expertises
02-spec      chief architect          → merge into ONE buildable spec (+ownership map)
03-critique  ~30 critics parallel     → BLOCKER/MAJOR/MINOR findings, stay in lane
04-verdict   jury + eng manager       → uphold/overturn findings, bind amendments
05-refine    chief architect          → final spec v2 incorporating upheld items
06-build     ~5 builders parallel     → implement under EXCLUSIVE path ownership
07-gauntlet  ~13 gatekeepers          → PASS/FAIL per seat against the real diff
```

Ship rule used in production: any P0-designated seat FAIL blocks; otherwise ≥⅓
FAIL votes block. P0 seats are the ones whose domain failures corrupt users
(security, test coverage, edge cases).

## Design rules that survived live runs

1. **Stdout is the blackboard.** For analysis rounds, capture worker stdout to
   the seat's file — workers need zero write permissions. Only builders get
   write tools.
2. **Sentinel validation.** Templates end with `END_ROLE_OUTPUT <id>`; dispatcher
   retries (once) when missing. Workers echo template examples — parse verdicts
   by LAST occurrence, never first.
3. **Quorum gates between rounds.** If fewer than `critical_min` seats report,
   abort with ABORTED.txt rather than synthesize on thin data.
4. **Resume must be idempotent.** Persist a per-round manifest; on relaunch skip
   rounds whose manifest met quorum. Guard with a lock file (stale after ~3h)
   so a cron relaunch can't double-run a live pipeline.
5. **Exclusive ownership per builder.** The eng-manager seat ratifies a
   path→builder map in the spec; builders refusing outside-owned paths is what
   makes parallel assembly merge-free.
6. **Sequential across tasks/rounds, parallel only inside a round**, and cap
   concurrency (`--parallel`) below provider reality even if the budget is
   infinite — retries absorb 429/EINVAL/SSE hiccups better than raw parallelism.
7. **Spec discipline beats orchestrator instinct.** If the gauntlet rejects an
   off-spec hardening the orchestrator added, REVERT and amend the spec through
   the addendum mechanism instead of arguing with critics via silent edits.
8. **Fallback tier.** Keep a documented lite mode (single builder + reviewer)
   for when council infrastructure is broken, logged distinctly.

## Windows / Node-child gotchas

- Spawned CLI agents hang forever on stdin unless spawned with
  `stdio: ['ignore','pipe','pipe']`.
- Background shells resolve bare interpreters badly ("stdin is not a tty") —
  always absolute paths (`"/c/Program Files/nodejs/node.exe"`).
- `.cmd/.bat` targets on patched Node v24: direct spawn = EINVAL; ComSpec
  inner-only quoting mangles space-paths. Working form:
  `["/d","/s","/c", '"<abs>" args']` with `windowsVerbatimArguments: true`
  (double-outer-quote trick). Builtins keep `/d /s /c <line>` unwrapped.
- Long synthesis calls legitimately need big caps — tune per round
  (spec/refine ≈ 25–30 min; critics ≈ 8–15 min), not one global timeout.

## Meta-critic pattern

Run a SECOND autonomous session (separate cron) whose only job is auditing the
first: read past briefs + transcripts + outcome logs, then append evidence-
dated rules to a PROMPT_PLAYBOOK.md the orchestrator must consult before
writing briefs. Template/spec-level flaws go to recommendations file, not
direct edits. This closes the loop on orchestration quality itself.

## Live instance

Production example (roster of 52 seats, dispatcher with resume/locks/quorum/
gauntlet tallying): `C:\Users\mrsma\swarm\` — `council/roles.json`,
`bin/council.js`, `CYCLE.md`, `PROMPT_PLAYBOOK.md`, `MANUAL.md`. Copy and adapt
rather than reinventing.

## Repair-loop convergence & adjudication (multi-gauntlet runs)

When a gauntlet fails, repairs re-run, and it fails again — read the trend
before choosing a response:

- **Track blocker count AND character across rounds.** Converging (7→5→4) with
  security seats flipping PASS = keep iterating. Identical blockers repeating
  twice unchanged = the repair approach itself is wrong, not the code.
- **Minority FAIL votes are not a FAIL verdict.** Overall PASS when quorum met,
  no P0 seat voted FAIL, and your own acceptance command exits 0. Record
  minority findings verbatim as known-polish instead of burning a repair round.
- **A seat dying to provider errors shrinks the voter pool honestly** — treat it
  as absent, not abstention-for-you; quorum math still protects quality.
- **Run the acceptance command YOURSELF even after unanimous PASS.** Production
  case: gauntlet passed unanimously while deliverables sat in the wrong directory
  with a deviating output contract — only the orchestrator's independent run
  caught it.
- **Stop rule**: after a repair pass produces zero NEW findings (only repeats of
  previously-raised items), the code is stable; remaining blockers are scope
  decisions for the human, not engineering defects. Escalate rather than loop.

## References

- `references/third-party-skill-adaptation.md` — converting human-in-the-loop
  skill packs (mattpocock/skills, gstack) into non-interactive editions for
  autonomous workers.
