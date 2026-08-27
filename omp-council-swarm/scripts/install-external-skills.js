#!/usr/bin/env node
/**
 * install-external-skills.js — install a third-party agent-skill pack as
 * NON-INTERACTIVE "council editions" into BOTH Hermes' and omp workers' skill
 * dirs. Generalized from the validated mattpocock/skills installer (T003).
 *
 * Usage:  node install-external-skills.js
 * Edit PACK below: source repo path + relative skill dirs + per-skill override.
 *
 * Mechanics that matter (learned the hard way):
 * - The COUNCIL MODE OVERRIDE block is inserted AFTER the YAML frontmatter
 *   (inserting before breaks frontmatter parsing).
 * - Frontmatter `name:` is rewritten to the prefixed name; description gains an
 *   `autonomous-council-edition: true` marker line.
 * - Companion .md files are copied alongside SKILL.md.
 * - Installs into both destinations so Hermes and omp workers share one truth.
 */
const fs = require("fs");
const path = require("path");

const SRC = process.env.SKILL_PACK_SRC || "C:/Users/mrsma/mp-skills/skills";
const DESTS = [
  path.join(process.env.LOCALAPPDATA || "C:/Users/mrsma/AppData/Local", "hermes", "skills"),
  path.join(process.env.USERPROFILE || "C:/Users/mrsma", ".omp", "agent", "skills"),
];

// rel-dir → {name (prefixed), extra (override text inserted after frontmatter)}
const OVERRIDES = {
  "engineering/tdd": {
    name: "mp-tdd",
    extra:
      "COUNCIL PRE-AGREED SEAMS: The orchestrator task brief (plans/<TASKID>-brief.md) " +
      "and the Chief Architect spec are the confirmed seam agreement. Treat the brief's " +
      "Test Plan section and the spec's Public Contract + Test Plan sections as the " +
      "user-confirmed seams. Do not ask a human to confirm seams.",
  },
  // Add more entries following the same shape; trim to your stack.
};

function splitFrontmatter(text) {
  const norm = text.replace(/\r\n/g, "\n");
  if (!norm.startsWith("---")) return { fm: "", body: norm };
  const end = norm.indexOf("\n---", 3);
  if (end === -1) return { fm: "", body: norm };
  return { fm: norm.slice(0, end + 4), body: norm.slice(end + 4) };
}

let installed = 0;
for (const [rel, cfg] of Object.entries(OVERRIDES)) {
  const srcDir = path.join(SRC, rel);
  const skillPath = path.join(srcDir, "SKILL.md");
  if (!fs.existsSync(skillPath)) { console.error("MISSING", skillPath); continue; }
  const { fm, body } = splitFrontmatter(fs.readFileSync(skillPath, "utf8"));
  const fmNew = fm
    .replace(/^name:\s*.*$/m, "name: " + cfg.name)
    .replace(/^(description:.*)$/m, "$1\nautonomous-council-edition: true");
  const out =
    fmNew +
    "\n<!-- council edition of an external skill pack -->\n\n" +
    "## NON-INTERACTIVE COUNCIL MODE (baked answers)\n" + cfg.extra + "\n\n" +
    "---\n# Original skill follows. Every human-question is answered by the brief.\n" + body;
  for (const dest of DESTS) {
    const dir = path.join(dest, cfg.name);
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(dir, "SKILL.md"), out);
    for (const f of fs.readdirSync(srcDir)) {
      if (f === "SKILL.md" || !f.endsWith(".md")) continue;
      fs.copyFileSync(path.join(srcDir, f), path.join(dir, f));
    }
    installed++;
  }
  console.log("installed", cfg.name);
}
console.log("DONE:", installed, "copies");
