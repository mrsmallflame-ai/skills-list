# Hermes Skill Bundle — OMP Swarm / Council / GStack

A portable, installable collection of Hermes Agent skills for running the
OMP worker swarm and the 52-seat council pipeline, plus the Garry Tan gstack
role suite and the mattpocock council editions (mp-*).

## What's inside

| Package | Contents |
|---|---|
| `gstack` / `gstack-*` (53 dirs) | gstack role system generated via `bun run gen:skill-docs` — propose, spec, critique, verdict, build, gauntlet, land-and-deploy, qa, design, etc. |
| `omp-council-swarm` | Orchestrate the 52-seat omp council on the `C:/Users/mrsma/swarm/` control plane: queue LEDGER.json, write briefs, handle cron lock races, monitor rounds, adjudicate RESULT.json, ship `[omp-council]` commits. Latest T002–T005 lessons baked in (repair `--fresh`, orchestrator exception, probe-driven debugging, vote parsing, timeout calibration). |
| `swarm` / `build-swarms` / `money-swarm-ops` / `strawberry-swarm-ops` | Swarm orchestration variants (build taskboards, x402 money ops). |
| `agent-councils` | Council umbrella + `references/third-party-skill-adaptation.md`. |
| `mp-*` (8 skills) | mattpocock/skills council editions (tdd, implement, to-spec, code-review, codebase-design, domain-modeling, diagnosing-bugs, writing-for-agents) with non-interactive COUNCIL MODE overrides. |

## Install

Copy the skill dirs you want into Hermes' skills tree. Location depends on host:

- **Windows (default profile):** `C:\Users\<you>\AppData\Local\hermes\skills\`
- **VPS / Linux gateway:** `~/.hermes/skills/`

Append each top-level dir under the first-level of that tree, e.g.:

```bash
mkdir -p ~/.hermes/skills
cp -r gstack gstack-* agent-councils omp-council-swarm swarm build-swarms \
      money-swarm-ops strawberry-swarm-ops mp-* ~/.hermes/skills/
# named sub-packages (gstack-* already top-level); the rest are top-level here.
```

Restart the Hermes session (or `/skills` rescan) for discovery to pick them up.

> Note: `omp-council-swarm`'s SKILL.md references the local control plane
> `C:/Users/mrsma/swarm/` — paths inside may need adjusting when run on a
> non-Windows host.