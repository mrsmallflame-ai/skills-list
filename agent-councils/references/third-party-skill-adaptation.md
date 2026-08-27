# Adapting human-in-the-loop skill packs for autonomous agents

Third-party skill packs (e.g. mattpocock/skills, garrytan/gstack) assume an
interactive human. Autonomous councils need the questions pre-answered.

## Non-interactive edition recipe

For each adopted skill, insert an override section AFTER the YAML frontmatter
(never before — breaks parsing), then copy into every worker's skill dir:

```markdown
## NON-INTERACTIVE COUNCIL MODE (baked answers)
<per-skill answers: what replaces "ask the user", where outputs go,
which authority document (brief/spec) counts as user confirmation>
```

Worked examples installed Aug 2026 (mp-* prefixed, both Hermes and omp dirs):

| Skill | Baked answer |
|---|---|
| tdd | seams = orchestrator brief's Test Plan; build red-green at those seams |
| implement | spec = council 05-refine output; no committing (orchestrator ships) |
| code-review | target = current diff; end with GAUNTLET_VERDICT line |
| diagnosing-bugs | proceed to fix once root cause reproduced; log causal chain |

Installer pattern: small Node script reading a config of {src, name, extra}
entries, splitting frontmatter, splicing the override, writing to each host's
skill dir. Live copy: `C:\Users\mrsma\swarm\bin\install-mp-skills.js`.

## Multi-host install gotchas

- gstack-style packs: `bun run gen:skill-docs --host <name>` emits host-flavored
  copies (tool-name rewrites per host config). Claude-flavored SKILL.md maps
  1:1 onto omp tool names; Hermes needs its own rewrites.
- Keep one canonical source repo (`~/gstack`, `~/mp-skills`) and regenerate on
  upgrade — never hand-edit generated copies.
- Prefix third-party skills (`gstack-*`, `mp-*`) to avoid namespace collisions.
