# Windows child-process spawning from Node — the quoting saga

Class-level reference: spawning `.cmd`/.bat` scripts and arbitrary command lines
on Windows via `node:child_process`. Validated across six gauntlet rounds of
DeskPilot (T003) plus T002's live probes. Every wrong form below was
demonstrated broken live; the final form is live-verified.

## The three broken forms (do not use)

| Form | Failure |
|---|---|
| Direct spawn: `spawn("C:\\...\\npm.cmd", ["-v"], {shell:false})` | Patched Node (v18.20+/20.12+/21.7+/24) **rejects** .cmd/.bat with `spawn EINVAL` — CVE hardening. Not "safely escaped": flat-out refused. |
| ComSpec inner-only quotes: `spawn(ComSpec, ["/d","/s","/c", '"C:\\...\\npm.cmd" -v'], {shell:false})` | cmd's /S rule sees 4+ quotes → old strip rule removes only FIRST quote → cmd parses `C:\Program` then chokes → `'"C:\...npm.cmd"' is not recognized` or "network path not found". |
| Whole-line wrap kept under `/S`: `[... , '"<inner>"']` where inner itself has quotes | node argv-escaping turns intentional quotes into `\"` before cmd ever sees them; builtins break too (`'"echo hello world"' is not recognized`). |

Also remember: bare `delete env.OPENROUTER_API_KEY` misses mixed-case env keys —
Windows env is case-insensitive; scrub by lowercased key name.

## The canonical working forms

```js
// True cmd builtins (dir/type/echo): literal line, no inner quotes needed.
spawn(ComSpec, ["/d", "/s", "/c", tokens.join(" ")], { shell:false, cwd });

// Resolved .cmd/.bat targets: build the line YOURSELF, wrap once more, mark
// windowsVerbatimArguments so node passes it through unescaped:
const rebuilt = `"${abs}" ${args.join(" ")}`;
spawn(ComSpec, ["/d", "/s", "/c", `"${rebuilt}"`],
      { shell:false, windowsVerbatimArguments:true, cwd });
// /S strips exactly the outer pair at exec time; the inner quoted exe survives.
```

Everything else (real .exe): direct argv-array spawn, `shell:false`.

## Safety coupling

Any shell-involved route is only injection-safe if a charset/refusal gate has
already rejected metacharacters (`& | > ; < > ( ) ^` newlines, NUL) AND
subcommand/flag evasions (npm aliases add/x/t/tst/it; git -C/--upload-pack/
receive-pack/config/ext::) BEFORE routing. Gate order is normative — see
DeskPilot lib/tools.js runCommand for the reference implementation.

## Diagnosing which failure you have

| Symptom | Cause |
|---|---|
| `spawn EINVAL`, instant | direct .cmd/.bat on patched Node → route via ComSpec |
| `'\"C:\...\"' is not recognized` | quotes survived into the token → missing verbatim flag or double-wrap |
| `The network path was not found.` | first-token quote stripped wrongly → space in path hit the old strip rule |
| Child hangs forever in readPipedInput (omp-specific) | spawned with piped stdin that never closes → `stdio:['ignore','pipe','pipe']` |
| Works interactively, dies in background bash ("stdin is not a tty") | background shells resolve shims differently → absolute exe path |
