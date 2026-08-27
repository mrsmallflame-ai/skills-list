---
name: omp-council-swarm
description: Operate the 52-seat omp council / gstack swarm on this machine - queue tasks, write dispatch briefs, handle lock races with the cron loop, monitor rounds, adjudicate RESULT.json, and ship [omp-council] commits.
---

# OMP Council / Swarm Orchestration

Class of work: building software through the Hermes-as-orchestrator + 52-seat omp
council pipeline (control plane `C:/Users/mrsma/swarm/`). Use when asked to "use the
council/swarm", when adding work to LEDGER.json, writing task briefs, convening
`bin/council.js`, or adjudicating gauntlet results.

## The pipeline in one glance

7 rounds run by `bin/council.js` itself: 01-propose (9 seats) → 02-spec →
03-critique (31) → 04-verdict (5) → 05-refine → 06-build (5 builders, disjoint file
ownership) → 07-gauntlet (13 gatekeepers). ~65 worker calls, 45–90 min wall time.
Blackboard: `council/<TASKID>/`, one dir per round, one .md per seat. Verdict lands
in `council/<TASKID>/RESULT.json`.

## Sequence

1. RESUME CHECK first, always: any `council/T*/RUNNING.lock` younger than 3h means a
   run owns that task — do not touch it. Read `logs/cycles.jsonl` last lines.
2. Queue work in `LEDGER.json` (status `queued`, lowest priority number runs first).
3. Write `plans/T00X-brief.md` (see Brief authoring below). MANDATORY: re-read
   `PROMPT_PLAYBOOK.md` first — meta-critic appends rules there over time.
4. Convene (background): `"C:\Program Files\nodejs\node.exe" C:/Users/mrsma/swarm/bin/council.js T00X --parallel=13 > logs/council-T00X.log 2>&1`
5. Monitor via watcher (below); adjudicate RESULT.json; run acceptance yourself;
   ship as separate git calls (`git add -A` then `git commit -m "<T00X>: <title> [omp-council]"`);
   ledger status done + cycles.jsonl append. Never fake a commit.

## Pitfalls (each one bit a real session)

### Cron race — the #1 trap
The `gstack-swarm-loop` cron fires every 2h and picks the lowest-priority `queued`
task AUTONOMOUSLY. If you queue a task at priority 1 and then manually launch the
council minutes later, the cron may already own it: your dispatch exits code 5
(LOCKED) instantly. Worse, both processes redirect to the same
`logs/council-T00X.log` — the second open truncates it while the first holds its
write offset, producing NUL-byte gaps and seemingly impossible interleaved logs.
- Before ANY manual launch: `ls council/*/RUNNING.lock` and stat mtimes.
- After queuing a high-priority task, assume the cron may claim it within minutes.
  Either let the cron-owned run proceed (monitor + adjudicate yourself) or pause the
  cron job first. Exit 5 = someone else owns it; that is success of the safety rail,
  not a failure to retry.

### Process mechanics
- Background bash resolves bare `node` to something broken — always full path
  `/c/Program Files/nodejs/node.exe`.
- Node spawning omp must use `stdio:['ignore','pipe','pipe']` or workers hang forever
  in readPipedInput (already fixed inside council.js — matters only if you rewrite it).
- Skill discovery for workers works from PROJECT cwd, never user-home cwd.
- Piping masks exit codes: `python x.py | head; echo $?` reports HEAD's status.
  When verifying acceptance/error paths, run the command unpiped (or check
  PIPESTATUS). T004 nearly mislabeled a correct exit-2 error path as passing.
- Fuzzy find-and-replace fails on giant single-line JSONL (cycles.jsonl lines are
  1000+ chars). To append a log line: read the whole file, rewrite it complete via
  write_file. Don't fight the matcher.
- Both orchestrator sessions narrate the same race into cycles.jsonl from their own
  POV (cron session logs "stood down", owning session logs completion). That's the
  protocol working, not corruption — reconcile when reading history.

### Approval gate during swarm ops
Unattended/background `pip install`, and any `rm -rf` (even deduping two identical
skill dirs), hit the consent gate and block. Design around it:
- Never make acceptance depend on packages you have not pre-installed WITH the user's
  blessing. Fence heavy deps behind lazy imports + graceful exit codes; tests pass on
  the minimal installed set; real deps go in requirements.txt.
- clarify() with an empty response = still no consent. Do not retry gated commands,
  rephrased or otherwise.

## Brief authoring (quality bar)

Playbook R-001..R-006 condensed: one goal per task; acceptance = shell one-liner
exercising real behavior with expected exit code; specify observable formats EXACTLY
(column names, stdout lines, exit codes) or the council burns debate rounds on
punctuation; fence dependencies explicitly; Windows/git-bash is home turf (UTF-8,
newline="", BGR-not-RGB, ASCII console text); quote the human's stated preferences
VERBATIM — unquoted preferences become 30-way debates.

Force multipliers proven in T004:
- Embed external skill mandates directly in the brief (a "APPLIED ENGINEERING SKILLS"
  section mapping each seat role → skill name + what it must enforce). Never rely on
  workers discovering skills themselves.
- Pre-agree test seams with independent-literal expected values; ban tautological and
  implementation-coupled tests in writing.
- Give builders disjoint file ownership + integration order; name the last finisher
  as integrator who runs acceptance.
- Dependency fencing pattern: core modules pure (numpy/cv2 only), mediapipe/matplotlib
  lazily imported in scripts/adapters with clear error + exit code 3 if missing. This
  keeps gauntlet/acceptance green regardless of what the machine has installed.
- Seed domain glossary + landmark indices + color constants numerically in the brief
  so zero rounds are spent deciding them.

Use `templates/council-brief.md` in this skill as the starting skeleton. For
repair-run mechanics, race resolution case law, and acceptance-override handling
see `references/repair-runs-and-races.md`. For post-ship "fix and debug" work
(closing gauntlet known-polish items TDD-style without a council re-run, in-process
CLI-contract tests under spawn budgets, README-vs-help drift tripwires) see
`references/post-ship-fixes.md`.

## Monitoring without babysitting

Background watcher loop (terminal background=true + notify_on_complete=true):
```
BB=<control>/council/T00X
while true; do
  [ -f "$BB/RESULT.json" ] && { echo RESULT-READY; cat "$BB/RESULT.json"; break; }
  [ ! -f "$BB/RUNNING.lock" ] && { echo LOCK-GONE-WITHOUT-RESULT; break; }
  sleep 45
done
```
Wakes you exactly once on verdict (or on abnormal death). Do NOT poll manually on a
schedule; do NOT kill a cron-owned run mid-flight.

## Adjudication ladder

PASS → run acceptance command yourself in workspace/. Exit 0 → ship. Non-zero →
treat as FAIL. FAIL → read blocking_failures; ONE repair attempt (append
`### REPAIR DIRECTIVES` quoting failures verbatim, delete RESULT.json, re-run).
Second FAIL → blocked. ABORTED.txt → find starved round in logs, mark blocked,
max one retry per session. Worker failure ladder: dispatcher retry → one council
re-run → blocked. Never hammer a failing provider (429 lesson).

### Repair runs REQUIRE --fresh (the no-op trap)
`bin/council.js` RESUME logic SKIPS any round whose `manifest.json` already shows
quorum met. After a completed run, ALL rounds are satisfied — so the naive
"delete RESULT.json and re-run" prints `COUNCIL_DONE` and exits 0 without a single
worker call. Builders never see your REPAIR DIRECTIVES. A real repair needs:
```
rm council/T00X/RESULT.json          # reset verdict
node.exe bin/council.js T00X --parallel=13 --fresh > logs/council-T00X-repair.log 2>&1
```
--fresh wipes prior round outputs so every seat re-convenes against the amended
brief (which the dispatcher re-stages to 00-brief.md at launch). Expect another
full ~100–130 min. Validated twice (T002, T004).

### Minority gauntlet FAILs are not a FAIL verdict
Overall verdict = PASS when critical_min is met and no P0 seat (R17/R29/R23) fails,
EVEN with individual FAIL votes. T004 run2: PASS 11/13 with R49+R22 dissenting.
Do NOT burn a repair round on minority polish items — record them verbatim in the
ledger notes as known-polish for a follow-up task. Conversely: a seat dying to
provider errors (exit=1 after retry) just shrinks the voter pool (12/13); quorum
math still holds. The check that actually protects quality is YOUR acceptance run:
T004 run1 passed the gauntlet unanimously while deliverables sat in the wrong
directory with a deviating CSV contract — the orchestrator's own acceptance
command caught it. Run acceptance personally even after unanimous PASS.

### Builder-seat death & the orchestrator exception (T005)
A builder seat can die twice (`exit=1, sentinel=false`, stderr tail `Deadline
exceeded` — the seat's task list exceeded its --max-time budget). The remaining
seats build around the corpse and the tree lands HALF-INTEGRATED. Death signature:
cross-seat NameErrors (missing import at the seam two seats share), stale binary
artifacts vs upgraded code (shipped 16-dim model.npz vs FEATURE_DIM=21 code),
promised assets absent (demo clip), guard-module migration done for some scripts
only, orphaned scratch dirs (`build_r13_*`). Gauntlet then fails ~12/13 with P0s.
Ladder extension: after BOTH council attempts fail AND the task is critical-path
(user asked for it directly), invoke the ORCHESTRATOR EXCEPTION — take over the
dead seat manually: survey tree, fix seams, regenerate artifacts through the
project's own scripts (dogfooding proves them), amend only defective-oracle tests
(never weaken gates), full suite green, commit `[omp-fix]`. A third blind council
run over precisely-specified integration surgery is malpractice. Keep ledger status
in-progress with an exception note until shipped.

### Regenerating assets wakes DORMANT tests mid-repair (budget for them)
Suites may ship with tests gated on an asset sentinel (e.g. `skipif(not
_assets_regenerated())` keyed on a sidecar version field). When your takeover
finally regenerates the artifact through the project's own scripts, those dormant
gates wake up INSTANTLY and their floors become binding — discovered at commit
time, that forces another full cycle. Before declaring the remaining-failure list,
grep for sentinel predicates; regenerate assets EARLY in the takeover (training /
generation is often the slowest step), and count newly-activated failures as part
of the current pass. Validated T005: landing the v2 model sidecar activated three
previously-skipped asset gates in the same run.

### Repair directives must PRESCRIBE, not just forbid
Quoting failures verbatim is necessary but insufficient — builders given only
"make X pass" will weaken tests. Proven directive set (T005):
- **RP0 prime directive first**: "Fix the SYSTEM, not the ruler" — any commit that
  relaxes a test assertion, lowers a gate in tests, or edits goldens to match
  broken behavior = automatic FAIL.
- Mandate root-cause instrumentation BEFORE coding (per-stage stats written to
  docs/REPAIR_LOG.md: proposal/gt-coincidence %, score histograms per class).
- Prescribe the engineering levers (data hard-negative mining round, feature
  components, threshold-by-sweep) and an explicit SHIP GATE recorded in the
  sidecar artifact; include an HONEST-STOP clause ("if floors unreachable after
  honest effort, STOP and say so — never fake the metric").
- Carry post-ship lessons into the NEXT task's brief from birth (exit-code
  taxonomy incl Ctrl-C→130, artifact-naming write errors, paste-and-run quickstart
  tripwires) — cheaper than repairing them later.

### Probe-driven debugging during takeover (validated T005 integration)
Never guess-fix a failing tree — MEASURE first, cheapest probe first:
1. Decompose full-suite failures by root cause (all-NameError = dead-seat
   seam; all-bookkeeping = a law changed under shape-tests).
2. Labeling bugs: measure proposal/gt-coincidence rate. ~100% coincidence +
   negative labels = unlearnable contradiction (AUC can stay 0.98 while
   accuracy caps at 0.75). Fix = overlap-positive labeling; expect instant
   accuracy jump if that was the only defect.
3. "Verifier innocent" proof: if hit vs miss score distributions are nearly
   IDENTICAL (p50 0.84 vs 0.83), stop tuning the model — the bug is
   downstream (association/span policy).
4. Span autopsy + frame-by-frame rejection table for tracker losses: large
   dropped-after-close counts = frozen-prediction amputation; widen the
   assignment gate per consecutive coast miss (Kalman-honest: P_cov grows on
   predict-only steps), arm it from miss >= 2 to keep misses=1 boundary laws
   intact.
5. A refusing ship-gate line IS free telemetry — its printed floors
   (accuracy / detection / median error / carried) are before-and-after metrics
   for every tuning run. Change ONE lever per run (accumulator window, proposal
   threshold, association law), rerun the gate, diff the line. When an experiment
   regresses, REVERT to the last passing config immediately and record the
   warning in the constant's docstring — a plausible mechanism that lowers the
   metric is still a regression (T005: widening the re-acquisition gate to
   12/90px let the tracker swallow echo blobs; detection FELL 0.865 → 0.843).
Class-level traps: `cv2.absdiff` returns uint8 — assigning it straight into
an accumulator silently drops uint16 promotion and wraps sums at 255;
equal-weight rolling-energy sums keep lagged "ghost" blobs hot and drag
nearest-wins association onto echoes (recency-weight the pairs instead).
Test-editing discipline: defective ORACLES (first-tie max() where the
contract is plateau-last-tie; fixture blockers never materialized; value
regexes that cannot match legal outputs like `1.000`) may be fixed with an
impossibility argument logged in REPAIR_LOG.md — but NEVER touch substantive
floors/acceptance commands. Update shape-tests only alongside the law change
that superseded them. One tuning lever at a time; revert instantly if the
failure count rises. Full ladder + CV traps: see
`references/probe-driven-debugging.md`.

Case detail (double-FAIL T005, manual integration surgery, defective-oracle test
repairs): see `references/t005-manual-integration.md`.

## Applying an external skills repo to the swarm

Pattern (validated with github.com/mattpocock/skills → omp workers):
1. Shallow-clone to a scratch dir; enumerate SKILL.md files + descriptions.
2. Triage by RELEVANCE to the actual stack (TS-specific skills are dead weight for a
   Python project); aim ≤10 installed.
3. Copy whole skill DIRS (they carry companion references) into the workers' global
   skills dir `~/.omp/agent/skills/` — global beats project-level for cwd-independence.
4. ALSO embed the chosen skills' mandates in the task brief (see Brief authoring) —
   discovery alone is unreliable; instructions beat availability.
5. Watch for stale duplicate installs (e.g., older `mp-*` prefixed copies); duplicates
   are harmless but noisy — dedupe only with user consent since rm hits the gate.

### Non-interactive editions for human-gated packs
Many third-party skills gate on ask-the-human steps (mattpocock `/tdd`: "confirm
seams with the user"). For swarm use, bake a COUNCIL MODE OVERRIDE block in right
AFTER the YAML frontmatter (never before — frontmatter parsing breaks): state that
the orchestrator brief/spec is the authoritative "user", every ask-the-human step is
pre-answered by it, and undecidable points resolve per the brief's stated preferences.
Rename with a prefix (`mp-tdd`) to avoid collisions, install into BOTH Hermes' and
workers' skill dirs, and copy companion `.md` references alongside. Reusable
installer: `C:\Users\mrsma\swarm\bin\install-mp-skills.js`, packaged here as
`scripts/install-external-skills.js` (edit the OVERRIDES table per pack; it
inserts overrides AFTER frontmatter, rewrites `name:`, and copies companion .mds
into both destinations). The full Windows-spawning quoting saga that bit during
these installs lives in `references/windows-spawn-quotes.md`.

### Ship checklist addition: reserved-name & debris sweep
Builders leave Windows-hostile artifacts (`NUL` files/dirs, probe `.mjs`, `x.log`,
`SUB`). Before pushing:
- Delete reserved names via Node: `fs.rmSync('\\\\?\\C:\\abs\\path\\NUL', {recursive:true})`
  (plain rm/cmd del fail on them).
- Grep README for drift vs actual behavior — round-6/8 gauntlets both failed partly on
  inverted trust-contract claims and undocumented test commands.
- `gh repo rename <correct-name> -R owner/wrong-name --yes` fixes a typo'd repo name
post-create without losing history.
- Publishing a NEW repo from an existing local history is ONE call (validated
  twice): `/c/tools/gh.exe repo create <name> --private --source . --remote origin
  --push --description "..."` — creates the private repo, wires `origin`, and
  pushes master in a single command. `--private` is the safe default; flip with
  `gh repo edit <name> --visibility public` later if wanted.

### Timeout calibration (validated T002/T003 — do not re-learn)
roles.json round timeouts that survived six real gauntlet rounds on this machine's
provider latency: 01-propose 8m · 02-spec **30m** (Chief Architect reads all
proposals + writes full spec; 12m deadline-failed twice) · 03-critique 8m ·
04-verdict 20m · 05-refine **20–26m** · 06-build **45m** (builders writing code +
tests + self-verify blew 25m three consecutive times; 45m landed first try) ·
07-gauntlet **15m** (seats run your test suite; 8m deadline-failed most seats).
Dispatcher adds +2m to omp's own --max-time and hard-kills at +5m. Failure
signatures: `Deadline exceeded` = seat needs more time → raise that round;
`server_error: JSON error injected into SSE stream` / exit=1 fast = upstream
transient → retry ladder handles it; exit=4294967295 = something SIGKILLed it.

### Vote parsing & verdict rules inside council.js
GAUNTLET_VERDICT must be parsed with matchAll + LAST occurrence — workers echo
template instruction examples (`GAUNTLET_VERDICT: FAIL: <one sentence>`) earlier
in their output, and first-match regex counted echoed examples as real FAIL votes
(T002 false-FAIL bug). Absent P0 votes don't veto (only voted FAILs); 12/13
reports still meets quorum when one seat exhausts retries.

### Cron report delivery is unreliable — always double-write
`deliver=origin` on cron jobs has failed with "no delivery target resolved" while
last_status still says ok. Every autonomous session must ALSO append its final
report as a JSON line to `logs/reports.jsonl` so nothing is lost. Check
`logs/reports.jsonl` before believing "nothing happened".

### Security-redesign governance (T003 DeskPilot, 6 gauntlet rounds)
When critics reject a hardening as off-spec even after you demoed the exploit, the
fix route is a marked REPAIR ADDENDUM appended to the frozen spec output (ratified by
you as orchestrator), then re-run the gauntlet — never silently keep the redesign,
and never weaken a P0 veto to force PASS. Expect seat-vs-seat contradictions across
rounds (one demands closing a hole, another rejects the closure as off-spec); resolve
via the addendum, track blocker-count trend (converging = keep going; identical
blockers repeating twice = escalate to human). Windows path guards will get probed
with case variants, NTFS 8.3 short names, `::$DATA` streams, `\\?\` device prefixes,
and separate-value flags (`git -C <dir> daemon`) — harden with realpathSync +
case-normalized comparison + prefix stripping + explicit token refusals, and pin the
acceptance command to ONE owned string across brief/package.json/README/spec.

### After orchestrator-built fixes: gauntlet-only re-judgment (validated DeskPilot rounds 6–8)
When YOU applied the repairs yourself (orchestrator exception above), builders have
nothing left to do — do NOT re-run the full council (~100 min wasted re-voting
already-passed rounds). Clear ONLY the verdict artifacts and re-convene the 13
gatekeepers against your patched code:
```
rm council/T00X/07-gauntlet/manifest.json council/T00X/RESULT.json
SWARM_WORKSPACE=<repo> "/c/Program Files/nodejs/node.exe" bin/council.js T00X --rounds=07-gauntlet --parallel=13
```
~12–16 min per judgment. Loop shape that converged on T003: fix findings → clear
→ re-gauntlet → repeat; blocker counts fell monotonically (8→8→5→4→0) across six
rounds. Pair EVERY fix with a regression test in the same pass so later rounds
cannot regress it. Exit codes: 0 = PASS/done · 3 = quorum abort · 4 = FAIL verdict
· 5 = lock held. If identical blockers repeat two rounds unchanged, stop looping
and escalate — more gauntlets will not help.

### Verify fuzzy patches on long markdown BEFORE dispatching workers
Find-and-replace on 100+-line markdown (briefs, specs, test files) can land
mid-bullet-list, join two lines into one, or duplicate-nest a block (one session
produced `if (exe === "git") { if (exe === "git") {` double-nesting in tools.js
and a joined assertion line in cli.test.js). After ANY patch to a brief, spec, or
test file that workers will consume: cat the edited region back, and syntax-check
code (`node --check`, `pytest --collect-only -q`) BEFORE launching the council —
workers inherit the mangled file verbatim via @file prompts. Code files bite
differently: near-identical repeated lines (quantization casts, per-frame
boilerplate) make the fuzzy matcher hit the WRONG occurrence and silently delete
or duplicate a neighbor — one session lost a `frame0 = np.clip(...)` cast to a
misanchored `frame2 = copy()` insert and only found it via UnboundLocalError at
test time. When old_string matches more than one location or neighboring lines
look alike, anchor on unique multi-line context, and re-run that file's own tests
IMMEDIATELY after the edit instead of batching several patches first.

### Identifier transcription drift — copy, never retype (bit TWICE in one session)
Long identifiers that differ by one letter from a real word (`deskpilot`) WILL be
retyped wrong somewhere in a long session. Both failure modes occurred back-to-back:
1. `gh repo create owner/deskpiot ...` — wrong repo name CREATED (fix:
   `gh repo rename <correct> -R owner/<wrong> --yes`, history preserved).
2. `SWARM_WORKSPACE='C:/Users/mrsma/deskpiot'` on a council dispatch — dispatcher
   crashed fast on the nonexistent path (harmless, but wasted a preflight cycle).
Rule: paste project paths/names from a canonical source (LEDGER.json entry,
`git remote -v`) into every command; never retype them by hand. If a launch
command contains a path you typed from memory, `ls` it inside the same command
chain BEFORE the expensive binary runs.

### Post-ship GitHub issues are the next cycle's backlog source
After shipping + applying an external skills pass, the open issues (#N with
slice descriptions and priorities) ARE the next dispatch brief: read them, group
into ONE goal-themed task (R-001 tension acknowledged — note the shared theme in
the goal line and declare an explicit priority order so partial ships degrade
gracefully), map each issue to a vertical slice with disjoint file ownership,
and quote the acceptance command verbatim in BINDING. Validated: deskpilot
issues #1–#4 → T006 brief slices 1–4 with priorities 1–4.

### Stale completion notifications fire for killed processes too
Hermes delivers `[IMPORTANT: Background process completed]` notices even for
background launches you deliberately killed minutes ago (exit code preserved).
Before reacting to any completion notice, match its session_id/pid against YOUR
current live run — the stale one is history, not news.
