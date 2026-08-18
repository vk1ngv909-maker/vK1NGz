---
name: delegate-to-codex
description: Use for any long, heavy, or repetitive coding task in this repo - multi-file changes, bulk refactors, boilerplate, test suites, migrations. Claude plans and verifies; Codex does the writing. Also use when the user says "delegate", "give it to codex", "use codex", or asks to conserve tokens on a big job.
---

# Delegate to Codex

Claude is the brain: plan, verify, decide. Codex is the hands: write the code.
Keeps Claude's context small — the heavy transcript stays on disk.

## Loop

1. **Plan** (Claude). Decide what changes, which files, how it will be checked.
   Do not write implementation code.
2. **Spec** (Claude). Write the plan to `codex-specs/<task>.md`: goal, files in
   scope, constraints, and the exact command that proves it works.
3. **Execute** (Codex). `bash scripts/codex-run.sh codex-specs/<task>.md`
4. **Verify** (Claude). **Never trust the report.** Run the check yourself:
   `git diff`, the test command, the linter. Codex claiming success is not
   evidence.
5. **Iterate**. Failed? Write a new spec naming the exact failure and loop.
   Passed? Report to the user with the evidence.

## Spec template

```markdown
# Goal
<one sentence>

# In scope
<files / dirs Codex may touch>

# Constraints
- Do not change <X>
- Match existing style

# Done when
<exact command that must pass, e.g. `pytest -q`>
```

## Rules

- Verification is Claude's job and is never delegated. Step 4 always runs.
- Keep specs concrete. Vague specs burn a full Codex run for nothing.
- Read the tail from `codex-run.sh`, not the whole report. Open the full file
  only when the tail is insufficient.
- Escalate to the user after 3 failed loops rather than looping forever.
- Small, one-file, or exploratory edits: just do them directly. The handoff
  costs more than it saves below roughly a few hundred lines.
