# Probe-driven debugging of council-built trees

Condensed from T005 (white-frisbee-tracker): a dead backend seat left a
half-integrated ML tracker; the gauntlet failed 12/13 and the remaining
failures resisted guess-fixes. Everything below was learned by MEASURING
before editing. Use this ladder whenever a built tree fails its own
acceptance floor and the cause is not obvious from the traceback.

## The probe ladder (cheapest first, always in this order)

1. **Full-suite failure decomposition.** Group the failing tests by module
   and read the assertion diffs. Failures cluster by ROOT CAUSE, not by
   file: e.g. "all NameError" = dead-seat seam; "all assert N==M bookkeeping"
   = a law legitimately changed underneath shape-tests.
2. **Coincidence / overlap measurement** (labeling bugs). If training data
   labels candidates negative while structural rows at the SAME location are
   positive, measure the coincidence rate first:
   `proposals within gt-radius / total proposals`. At 99.6% coincidence,
   negative-labeling is mathematically unlearnable REGARDLESS of model
   capacity (AUC can stay 0.98 while accuracy caps at ~0.75 - high AUC +
   low gated accuracy = label contradiction, not weak features).
   Fix: overlap-positive law (a proposal overlapping gt trains as positive -
   identical to deployment semantics where any such detection becomes a
   tracked point). Expect accuracy to jump to 1.0 immediately if this was
   the only defect.
3. **Score-distribution A/B ("verifier innocent" proof)**. For every missed
   frame record the best near-gt proposal score; do the same for hits. If
   p50(hit) ~= p50(miss) (~0.84 vs ~0.83 here) the VERIFIER IS NOT THE
   BUG - stop tuning features/thresholds and look DOWNSTREAM (association,
   span policy). This single measurement kills whole wrong-hypothesis
   branches.
4. **Span autopsy.** For tracker losses, print per-seed:
   span length, last-consumed frame, carried count, and detections-dropped-
   after-span-close. Large dropped counts = closure amputation; the trigger
   is usually a frozen prediction (velocity decayed to 0 during coast) plus
   a tight assignment gate - the disc resumes OUTSIDE the gate and is
   teleport-rejected forever.
5. **Frame-by-frame rejection table.** For one pathological seed: per frame,
   #detections, their positions/radii/scores, the emitted state, and for
   carried frames the distance candidate-vs-coast-point. This exposes
   periodic patterns instantly (tracked-every-kth-frame = window/gate
   resonance) and gives exact distances to size any gate widening.

## Ghost echoes in motion energy (class-level CV pitfall)

A rolling-energy SUM over a window keeps the LAGGED blob (where the disc WAS
two frames ago) nearly as hot as the true blob. Nearest-to-prediction
assignment then chases the echo, the Kalman velocity estimate INVERTS, the
prediction freezes behind reality, and the tracker oscillates. Fix: weight
pairs by recency (newest pair full, older pair >>1) so ghosts decay below
threshold. Two traps when implementing:
- `cv2.absdiff` on uint8 returns **uint8**. Assigning the accumulator
  directly (`acc = absdiff(...)`) silently drops the uint16 promotion the old
  zeros-initialization provided; sums then wrap at 255 and downstream dtype
  validation explodes across the whole suite. Cast explicitly:
  `.astype(np.uint16)` on every absdiff result.
- Any golden test pinning the old arithmetic (300 == 150+150) must be
  updated WITH the law change and its docstring rewritten to state the new
  weighting - keep the overflow-stress assertions intact.

## Defective-oracle vs gate-weakening (the editing discipline)

When a test fails after a legitimate system fix, classify BEFORE editing:

- **Defective oracle** (fixable): the test uses first-tie `max(curve, key=f1)`
  where the documented contract is plateau-last-tie `pick_threshold()`; a
  fixture "blocker" whose `.mkdir()` was never called (nothing actually
  blocks); value regexes that cannot match legal outputs (`0\.\d{3}` vs a
  perfect `1.000`). Fixing these preserves the gate's substance - every
  substantive assertion stays. Cite the impossibility argument in a comment
  and log it in docs/REPAIR_LOG.md.
- **Shape/bookkeeping tests of a superseded law** (update with the law):
  byte-multiset tests asserting "exactly one positive per energy frame"
  must be recomputed when the labeling law changes. Update the ORACLE
  helper (recompute expected rows through public APIs), keep all
  substantive assertions.
- **Substantive gates** (NEVER touch): acceptance commands, floor numbers,
  golden behavior contracts, exit-code tables. RP0 applies.

Also watch for stale assumptions INSIDE substantive tests: a static-corpus
ship-gate test asserted accuracy<0.90 because the OLD contradictory labeling
made degenerate data unlearnable; under honest labeling static clips
separate trivially (acc=1.000) and the DETECTION floor is what refuses.
Move the assertion to the floor that actually fires.

## One-lever-at-a-time with instant revert

Tuning constants (proposal threshold, carry decay) ripple into UNRELATED
pinned tests (blur-burst windows, e2e metrics). Change ONE lever, run the
suite, and if the failure count goes UP revert immediately - a speculative
tuning that breaks 4 tests to maybe-fix 1 is a net loss. Keep the reverted
idea in REPAIR_LOG as a considered-and-rejected branch with the measured
delta.

## Dead-seat takeover workflow (context for the above)

Survey tree -> full suite -> decompose failures -> fix seams (imports,
call-signatures) -> fix contracts (taxonomy lines, gate formats) -> probe
the algorithmic core -> amend defective oracles -> regenerate shipped
artifacts THROUGH the project's own scripts -> README quickstart executed
literally -> gitignore debris dirs -> full suite green -> commit [omp-fix].
