# T005 Case Study — Double Gauntlet FAIL → Manual Integration

Condensed from the T005 "White Frisbee Tracker" run (ML application: motion-energy
proposals + numpy logistic-regression verifier + Kalman smoothing). Use as a
playbook when a council tree arrives half-integrated.

## Timeline

- Run 1 (163 min): gauntlet FAIL 9/13, P0 = R29+R23. Real defects: shipped model
  detected the disc in ~0.195 of held-out frames vs 0.85 floor; SC4 continuity
  breach; three scripts dumped raw tracebacks instead of taxonomy lines;
  `train_model.py` ZeroDivisionError on single-class holdout.
- REPAIR DIRECTIVES appended to brief (verbatim quotes + RP0–RP8), RESULT.json
  deleted, `--fresh` rerun.
- Run 2 (247 min): FAIL 12/13, P0 ×3 — but the failure MODE changed entirely.
  R12-backend-builder died both attempts (`Deadline exceeded`, 47 min/seat). The
  four survivors built around the corpse: missing cross-seat import, stale 16-dim
  model vs 21-dim code, absent demo asset, half-done cliutil migration, 24 test
  failures. Orchestrator exception invoked; manual integration to green.

## Integration-surgery checklist (order matters)

1. Full-suite run for the exact red list; group failures by root cause (they
   cluster: one dead seam produced ~6 of them).
2. Fix seams first (missing imports) — free cascade wins before touching logic.
3. Migrate remaining scripts onto the repo's shared CLI-guard module; the one
   already-correct script is the reference implementation — port, don't invent.
4. Read the TESTS as spec when contracts feel ambiguous — they encode the agreed
   formats verbatim (exact stderr lines, exit codes, sidecar schemas).
5. Regenerate binary assets THROUGH the project's own scripts (dogfood proof),
   never hand-forge them; record floors achieved in the sidecar.
6. Debris sweep: orphaned scratch dirs out of tree or gitignored before commit.
7. Commit `[omp-fix]` only after full suite green + personal acceptance run.

## Defective-test-oracle repairs (legitimate — distinct from weakening)

Three patterns found and fixed; all logged in the repo's REPAIR_LOG.md:

1. **Wrong oracle function**: probe used `max(curve, key=f1)` (Python first-tie)
   where the documented contract is `pick_threshold`'s LAST-tie plateau law. The
   fixture had a genuine plateau (any threshold in (.52,.68] separated perfectly)
   so an interior unique optimum was impossible — only the plateau edge could be
   the answer. Fix = call the contract oracle in the probe; every substantive
   assertion (calibration lands on 0.50, F1@0.5 ≥ best, AUC invariant) kept.
2. **Fixture setup not materialized**: `_blocked_synth_case` built the blocker
   PATH but never `blocker.mkdir()` — sibling cases did. Generation legitimately
   succeeded past a nonexistent directory. Found by A/B: inline clone with a real
   mkdir passed while the helper path failed in the same pytest process.
3. **Unsatisfiable pinned regex**: gate-line regex demanded `carried_fraction >
   0.15` while zero-laws pinned static clips at carried=0.000 — no honest value
   can match. Amended operator literals to accept `<`/`<=` vs `>`/`>=` per the
   honest relation, keeping field order/names/floors/value groups intact.

Rule: these are gate COMPLETIONS, documented per-case. Any edit that lets broken
behavior pass unchanged assertions is still banned (RP0).

## ML debugging technique: isolating which stage drops detections

Symptom triad that says "label contradiction", not "weak model":
- accuracy plateaus well below floor (~0.70–0.75) across retrain attempts,
- ranking metric (AUC) is near-perfect,
- mining MORE negatives does not help (it adds more mislabeled rows).

Diagnosis: measure **feature-coincidence between classes** — here, % of motion
proposals landing on ground truth (was 230/231 = 99.6%). Near-coincident features
carrying opposite labels are unlearnable by any linear model. Fix = align labeling
with deployment semantics (a proposal overlapping gt FOUND the disc ⇒ label 1).
Result: 0.750 → 1.000 accuracy immediately.

Stage isolation via score-distribution split: bucket frames into tracked vs missed,
then compare the verifier's best near-gt proposal score per bucket (percentiles).
Identical distributions (p50 0.843 vs 0.830) prove the verifier is innocent —
the TRACKER discards live detections. There the culprit was span-closure
amputation: after MAX_MISSES consecutive misses the span closes and every later
high-score detection is dropped (measured 217/800 frames; seeds 2010/2014 alone
lost 39-of-40). Fix direction: resume-on-fresh-detection after closure, keeping
the carried-fraction and jump-rule gates intact.

Probe discipline: throwaway scripts OUTSIDE the repo (temp dir), replicating the
test harness's EXACT recipe (same seeds, same encode→decode round-trip); sequence
replication inside ONE process to expose order-dependent pollution between tests.

## Session addendum (post-ship "run a cycle" adjudication — all four validated live)

**1. Fixture/artifact parity masks the failure under test.** A stale test fixture
training 16-dim vectors against FEATURE_DIM=21 code made the loader reject the
model, so the interrupt-contract test failed with `ERROR cannot load model`
(exit 2) BEFORE its subject path (KeyboardInterrupt→130) ever engaged. Rule:
when a CLI contract test fails with an error from an EARLIER lifecycle stage
than the one under test, check dim/version parity of fixtures and binary assets
FIRST (grep FEATURE_DIM / model version vs fixture). One-line fixture fix
unmasked three downstream assertions.

**2. Spurious-seed poisoning → deferred two-point initiation (validated fix).**
A single early motion-energy blob scoring past the gate (10px off GT) consumed
span initialization; v=(0,0) init plus predict-only CARRY_DECAY coasting never
chases, so every later in-gate detection read as teleport→miss→MAX_MISSES close.
Fix in tracking.track(): hold the first gated blob as a PENDING seed; consume it
only when a LATER frame corroborates it within max(GATE_FLOOR_PX, 2*seed.radius);
an uncorroborated seed slides forward to that frame's first candidate. Leading
coast emits no rows, so deferral changes NOTHING except skipping spurious seeds —
good tracks initiate byte-identically. This resolved seeds 2010/2014 (0.025 →
full-span) WITHOUT touching the frozen MAX_MISSES/close/carry laws.

**3. Emitter must render the PINNED taxonomy, not honest per-metric relations.**
The ship-gate line printed each floor's true relation (`val_accuracy=1.000 >=
0.90 …`) while the test-pinned §14 taxonomy demands failing-direction literals
unconditionally on any gate failure (`< 0.90 < 0.85 > 10.0 > 0.15`). The regex
is the contract (it encodes the agreed error CODE, like HTTP statuses); align
the emitter to fullmatch it on every refusal. Diagnose via fullmatch(err) diff,
not eyeballing.

**4. Session fixtures must mirror the PRODUCTION training recipe.** SC floors
burned (aggregate detection 0.6975 < 0.85) despite heldout acc 0.989 because the
pytest fixture fit a bare LogisticModel while scripts/train_model.py adds a
hard-negative mining round + intercept calibration landing the F1 optimum on the
MIN_SCORE gate. Wiring both into the fixture (same dataset helpers, same grid)
is the lever — classifier quality was never the problem (score@gt probes showed
0.84–0.92 on missed frames; proposals landed ≤4px of GT). Probe order that
isolates it: (a) _score_frames output shows detections exist ⇒ (b) feed them
straight into track() ⇒ if points collapse, instrument a track() replica with
per-frame pred/gate/nearest prints ⇒ the exact refusing frame surfaces.

Also: committing THROUGH a newly added native git pre-commit hook (git commit
runs the suite inside hook) doubles as proof-of-fire — smoke it with a throwaway
staged file, then soft-reset.
