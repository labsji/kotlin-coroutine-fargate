# Dual-Repo Rules: Public (GitHub) vs Private (CodeCommit)

## The Two Homes

| Repo | Host | URL | Purpose |
|------|------|-----|---------|
| Public | GitHub | `labsji/kotlin-coroutine-fargate` | Self-service tutorial for learners |
| Private | AWS CodeCommit (via GitLab proxy) | `kotlin-coroutine-fargate` | Kiro-led premium flow + revenue branches |

## What Goes Where

### Public (`main` branch on GitHub)

Everything a self-service learner needs:
- Application code (all labs, endpoints, viz UI)
- Deploy scripts (Beanstalk, Fargate, multi)
- TUTORIAL.md, README.md, PROGRESS.md (blank state)
- SPEC-*.md design docs
- FargateNotes.md troubleshooting
- `.kiro/steering/` files (they help the agent work on the public repo too)
- BACKLOG.md (public tasks only)

### Private Only (CodeCommit branches, never push to GitHub)

| Content | Branch | Why Private |
|---------|--------|-------------|
| `AUTOPILOT-SEED.md` | `express-tutor` | Captured teaching flow — the premium pedagogy |
| `EXPRESS-TUTOR-SPEC.md` | `express-tutor` | Lesson design with exact prompts and sequences |
| `PinLabs.kt` (capstone) | `express-tutor` | Premium lab content (PIN validation) |
| Session notes in PROGRESS.md | `express-tutor` | Student-specific data |
| `.kiro-instructions.md` | gitignored | Per-session Kiro prompts |
| `tutor-main` branch state | `tutor-main` | Fresh student reset point |

## Promotion Flow: Private to Public

When a feature matures in the private repo and is ready for self-service:

1. **Identify public-safe content** — code, docs, scripts (no session data, no teaching scripts)
2. **Cherry-pick or merge** from the private branch into `main`
3. **Strip private markers** — remove any `AUTOPILOT-SEED` references, session notes
4. **Update TUTORIAL.md** — add the new lab as a self-service section
5. **Push `main` to GitHub** — this is the public release

## Rules for the Autonomous Agent

### When working on GitHub (public repo):
- Branch from `main`, PR targets `main`
- All content must be self-service friendly (no "Kiro will do this for you" language)
- No references to AUTOPILOT-SEED, express-tutor, or premium flow
- No student names, session dates, or pricing

### When working on CodeCommit (private repo):
- Can work on any branch (`main`, `tutor-main`, `express-tutor`)
- Can reference internal teaching strategies
- Can include session-specific content
- BACKLOG items marked `[private]` stay on CodeCommit only

### Never Do:
- Push `express-tutor` or `tutor-main` branches to GitHub
- Include AUTOPILOT-SEED.md in any GitHub PR
- Reference specific student names in public content
- Include AWS account IDs, IAM role ARNs, or IP addresses in committed code (use variables)

## Detecting Which Repo You're In

- If remote URL contains `github.com/labsji` → you're on the public repo
- If remote URL contains `gateway.connections` or CodeCommit → you're on the private repo
- Check with: `git remote -v`

## Sync Strategy

The repos are NOT mirrored. They share the same `main` content but diverge on private branches. Sync is manual and intentional — only mature, public-safe content crosses the boundary.
