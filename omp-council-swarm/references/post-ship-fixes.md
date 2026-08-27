# Post-Ship Fixes — "fix and debug" after a council task ships

Class trigger: user says "fix and debug" (or similar terse directive) AFTER a task
was already shipped, when the ledger/gauntlet recorded known-polish items. This is
ORCHESTRATOR-done surgical work, not another council run — a 100-minute re-run over
a README wording bug is waste. Validated end-to-end on T004 (commit bc08de7).

## Order of operations

1. CLOSE IN-FLIGHT ATOMIC WORK FIRST if a new mission interrupts mid-repair: never
   leave red/failing tests uncommitted in the shared workspace repo — builders of
   the next council task write into that same tree. Finish green → commit → pivot.
2. Diagnose from the RECORDED findings first (ledger notes, gauntlet seat .md files
   under council/<TASK>/07-gauntlet/). Read the actual source before believing the
   finding's wording — R22's claim was partially wrong (analyze scripts DID handle
   Ctrl-C; only plot_angles.py lacked it) and partially right for an interesting
   reason (WriteError already carried the artifact path; scripts discarded it).
3. RED first (repo's own tdd discipline): add regression tests that fail against
   current code. Confirm red with a scoped pytest run before touching source.
4. GREEN: minimal fixes only. Re-run full suite + live CLI probes unpiped.
5. Commit separately: `<T00X>: <what> [omp-council]`. Update ledger notes so the
   known-polish list reads EMPTY (or whatever remains).

## In-process CLI-contract testing (respects spawn budgets like C24)

Council specs often cap subprocess spawns (e.g. "8 spawns total"). To test error
paths without spawning:

```python
@staticmethod
def _load_script(name: str):
    """Load a scripts/ file as a module without running its __main__ block."""
    spec = importlib.util.spec_from_file_location(f"repair_{name[:-3]}", SCRIPTS / name)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)   # top-level sys.path bootstrap runs here - fine
    return module

def test_write_failure_names_artifact(self, tmp_path, monkeypatch, capsys):
    source = tmp_path / "clip.mp4"; source.write_bytes(b"\x00\x00")  # passes _refuse
    def _boom(source, out_dir, side="right"):
        raise WriteError(Path(out_dir) / "annotated.mp4")
    monkeypatch.setattr("faa.pipeline.analyze_video", _boom)  # scripts import INSIDE main()
    rc = self._load_script("analyze_video.py").main([str(source), "--out", str(tmp_path / "out")])
    assert rc == 2
    assert capsys.readouterr().err.strip() == f"ERROR cannot write {tmp_path / 'out' / 'annotated.mp4'}"
```

Key mechanics:
- Scripts do their heavy imports INSIDE main(), so monkeypatching the package
  attribute (`faa.pipeline.analyze_video`) before calling main() is sufficient —
  the fresh `from ... import` picks up the stub.
- KeyboardInterrupt paths are testable the same way: stub a pure seam
  (`faa.export.plot_series`) to raise KeyboardInterrupt; assert rc==130,
  "Interrupted" in stderr, "Traceback" not in stderr. No matplotlib needed.
- An uncaught KeyboardInterrupt inside code-under-test will ABORT the pytest run
  itself (not just fail one test) — that abort IS your red signal; expect it.

## Docs-vs-CLI drift tripwires (R49 class)

When a README quickstart and a CLI contract can silently diverge, add a mechanical
test: parse the README fence, extract the command line, assert its argument shape
matches the parser contract (`--out` value endswith .png for a file-path flag, etc.).
Cheap, permanent, and converts "docs said X, help said Y" findings into CI failures.

## What does NOT belong in this pattern

- Anything needing a full re-debate (contract changes across many seats) → use the
  council repair-run path instead (see SKILL.md "Repair runs REQUIRE --fresh").
- New feature requests → new ledger task, not a stealth expansion of a shipped one.
