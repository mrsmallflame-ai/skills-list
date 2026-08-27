# T00X BRIEF — <one-line title>

## 1. GOAL (one goal)
<single sentence; R-001: one goal per task>

## 2. THE HUMAN'S STATED REQUIREMENTS (verbatim — do not reinterpret)
> <quote product goal / constraints verbatim>
Success criteria that bind this build:
- **X.Y (P#):** <verbatim criterion> — <testable implication for the build>

## 3. DOMAIN LANGUAGE (seed CONTEXT.md with exactly these terms)
- **Term**: definition. <resolve every ambiguous noun here, not in debate>

## 4. FILES (allowed layout — builders own disjoint subsets)
```
<tree with one-line purpose comments per file>
```
<fixed constants live HERE: index maps, color values, default ranges>

## 5. BEHAVIOR SPEC (exact observable formats)
### Core functions (pure, no heavy imports)
- `fn(args)` → return type: contract incl. rounding/range/units.
### CLI contracts
- `python scripts/x.py ...` → exact stdout line templates, exit codes
  (2 = bad input, 3 = missing optional dep), --help before heavy imports.

## 6. TEST SEAMS (pre-agreed — tests live ONLY here)
Test-time deps: <minimal installed set ONLY>.
- S1 `<file>`: <literal expected values, never recomputed geometry>
- S7 meta-test pattern where useful (e.g., every public fn has docstring).
Anti-patterns banned: implementation-coupled, tautological, horizontal slicing.

## 7. DOCS DELIVERABLES
CONTEXT.md (glossary only) / docs/adr/0001-*.md / docs/RESEARCH.md (primary sources,
cite only what you are confident exists; `[TODO verify]` over fabrication) /
AGENTS.md / SUCCESS_CRITERIA mapping.

## 8. DEPENDENCY FENCE
Runtime deps allowed: <list>. Test-time deps allowed: <minimal list>. Nothing else.
No network at runtime. Heavy deps lazy-imported in scripts/adapters only;
core modules NEVER import them at module level. Do NOT pip install during build.

## 9. WINDOWS NOTES (home turf)
encoding="utf-8" everywhere; csv newline=""; pathlib; ASCII console text;
BGR order for cv2 colors; `python -m pytest`, never bare pytest.

## 10. ACCEPTANCE COMMAND (exact — must exit 0)
```
cd <workspace>/<project> && python -m pytest tests -q
```

## 11. APPLIED ENGINEERING SKILLS (installed worker-side — load per role)
| Seat/round | Skill | Must enforce |
|---|---|---|
| 02-spec | to-spec + codebase-design | formats EXACT; deep modules, adapters hide heavy deps |
| 03-critique | grill-with-docs | underspecified format = blocking finding, not assumption |
| 06-build | implement + tdd | red-green at S-seams only; run suite each slice |
| 07-gauntlet | code-review | two axes: Standards (fences §8/§9, naming smells) + Spec (§5 literal) |
| any debugging | diagnosing-bugs | root cause before patch |

## 12. BUILD SEAT PARTITION HINT (architect may refine, keep disjoint)
- B1: <files+tests> … B5: <docs>
Integration order: … Last finisher = integrator: run acceptance, fix cross-seat breaks.

## 13. OUT OF SCOPE (do not build)
<explicit neighbor list>

## 14. RISKS / NOTES
<absent-deps plan, runtime caps on test suite, anything the meta-critic flagged>
