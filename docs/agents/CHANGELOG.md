# Agent CHANGELOG

Changes made to this repository by AI agents, newest first. One entry per work session. Format:

```
## YYYY-MM-DD — <short title>
- Agent: <product> <model>
- Branch / commits: <branch> — <short hashes>
- Plan: <link or "none">
- Changed: <files and what changed>
- Verified: <what was compiled/tested and how>
- Not done / not verified: <honest list>
```

## 2026-11-18 — Agent setup and CoinOS three-step payment plan

- Agent: Claude Code Opus 5.5
- Branch / commits: `feature/coinos-safe-lnaddress-payment` — see `git log master..feature/coinos-safe-lnaddress-payment`
- Plan: [plans/2026-11-18-coinos-safe-lnaddress-payment.md](plans/2026-11-18-coinos-safe-lnaddress-payment.md)
- Changed:
  - Added `AGENTS.md` (rules for AI agents: git, encodings, Delphi/FPC parity, security, build, documentation duties) and `CLAUDE.md` (imports `AGENTS.md`).
  - Added `docs/agents/` with `README.md`, `INDEX.md` (repository map), this `CHANGELOG.md`, `plans/_TEMPLATE.md` and the CoinOS plan.
  - No library, demo or build file changed.
- Verified:
  - Local `master` equals `origin/master` on Bitbucket after `git fetch` (0 ahead / 0 behind).
  - Baseline Delphi 12 build of `IdeaL.Lib.Api` + `IdeaL.Lib.Api.Bitcoin.CoinOS` compiles (scratch console project, output outside the repo).
  - Each claim of the external request checked against coinos-server `c0a0f5c`, the live CoinOS API, BOLT 11, LUD-06/12/16 and the Delphi 12 RTL; results in the plan §3–§5.
- Not done / not verified:
  - FPC/Lazarus not installed: the suspected FPC build break (plan F1) is from code reading only.
  - Implementation not started; waiting for the maintainer's answers (plan §8).
