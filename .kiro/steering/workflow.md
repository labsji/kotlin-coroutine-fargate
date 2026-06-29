# Workflow: Autonomous Agent Rules

## How to Pick Work

1. Read `BACKLOG.md` in the repo root
2. Pick the **top unchecked item** from the highest priority section
3. Implement it fully (code + docs + any script changes)
4. Open a PR — do NOT merge

## Branching

- Create a feature branch from `main`: `auto/<short-description>`
- Examples: `auto/pin-lab-endpoint`, `auto/readme-troubleshooting`, `auto/fix-viz-dropdown`
- Never commit directly to `main`, `tutor-main`, or `express-tutor`

## Commit Style

- Single logical commit per task (squash if needed before PR)
- Format: `[BACKLOG] <short description>`
- Examples:
  - `[BACKLOG] add PIN validation endpoint (Lab 5)`
  - `[BACKLOG] fix: viz UI missing PIN lab option`
  - `[BACKLOG] docs: add troubleshooting section to README`

## Pull Request Conventions

- **Title:** Same as commit message
- **Description:** What was done, what was tested, any caveats
- **Mark the BACKLOG item** `[x]` in your PR's changes to BACKLOG.md
- Target branch: `main` (unless the task says otherwise)

## Build & Verify

Before opening a PR, verify the build passes:

```bash
cd /projects/sandbox/kotlin-coroutine-fargate
./gradlew build --no-daemon -q
```

If the task modifies Kotlin source, the build MUST succeed. If it only modifies docs/scripts, build verification is optional.

## What NOT to Do

- Do NOT deploy to AWS (no `deploy-*.sh` execution) — those cost money
- Do NOT modify `.kiro-instructions.md` (private, gitignored)
- Do NOT touch `tutor-main` or `express-tutor` branches from this workflow
- Do NOT add test frameworks — the app is its own test harness
- Do NOT upgrade dependencies unless the BACKLOG item explicitly says to
- Do NOT run the application server (it blocks execution)

## File Conventions

| Type | Convention |
|------|-----------|
| New endpoint | Add to `Application.kt` routing block, or create a new file if >50 lines |
| New Kotlin file | Package `dev.labsji.coroutinelab`, same `src/main/kotlin/...` path |
| New spec | `SPEC-<feature>.md` in repo root |
| New script | Bash, `#!/bin/bash`, `set -e`, region defaults to `${AWS_REGION:-ap-south-1}` |
| Documentation | Update relevant `.md` file; add to TUTORIAL.md if it's a new lab |

## JSON Response Format for Lab Endpoints

All lab endpoints return JSON:

```json
{
  "lab": 5,
  "frames": 100,
  "parallelism": 4,
  "durationMs": 340,
  "fps": 294,
  "availableProcessors": 2
}
```

Include whichever fields are relevant. Always include `lab` and `durationMs`.

## When Blocked

If a task cannot be completed (missing dependency, unclear spec, needs AWS access):
1. Create the PR anyway with whatever progress exists
2. Add `[BLOCKED]` prefix to the PR title
3. Document the blocker in the PR description
4. Do NOT mark the BACKLOG item as done
