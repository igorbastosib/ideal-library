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

## 2026-11-18 — CoinOS trackable payments: implementation (steps S0–S6)

- Agent: Claude Code Opus 5.5
- Branch / commits: `feature/coinos-safe-lnaddress-payment` — `9c8d1ec` (characterisation tests), `8481b78` (base class + BOLT 11), `fbc7444` (CoinOS), `9706c9b` (LNURL-pay), `ca24f4b` (FPC tests), `31e723c` (demo), plus the docs commit that adds this entry. Nothing pushed.
- Plan: [plans/2026-11-18-coinos-safe-lnaddress-payment.md](plans/2026-11-18-coinos-safe-lnaddress-payment.md) (decisions in §8.1, progress in §11)
- Changed:
  - `Api/IdeaL.Lib.Api.pas`: timeout overloads (old signatures delegate with 60 s), 2xx on POST, `EIdeaLApiError`, `IsTransportError`, `FollowRedirects`, wall-clock deadline on Delphi, FPC build fixed.
  - `Api/Bitcoin/IdeaL.Lib.Api.Bitcoin.CoinOS.pas`: `PostPayment(fee, memo, pin)` (no more `maxfee`), `GetPayment`, `GetPaymentState`, `NormalizeInvoice`, `PostLightningQuote`, `GetDecode`, `BaseUrl`, `PaymentTimeout`, consistent headers, `PostPaymentLnAddress` fee-0 fix and PIN, doc comments, FPC build.
  - New `Api/Bitcoin/IdeaL.Lib.Bitcoin.Bolt11.pas` and `Api/Bitcoin/IdeaL.Lib.Api.Bitcoin.LnurlPay.pas`.
  - New `Tests/` (DUnitX, fpcunit, shared vectors); `.gitignore` for test output.
  - `Demos/Api/Bitcoin/CoinOS`: three-step box, fee cap/memo/PIN/check on the invoice box, PIN on the one-call box.
  - `Api/Bitcoin/README.md`: safe-payment section, compatibility table rewritten from real compiles; `AGENTS.md` §6/§9 and `docs/agents/INDEX.md` updated.
- Verified:
  - DUnitX (Win64): 120/120, including the 13 characterisation tests of the 0.0.6 base class, unchanged since before the base class was touched.
  - fpcunit (FPC 3.2.2 i386-win32): 24/24.
  - Compiles: all `Api/` units with dcc32 and dcc64 (except Exchange, which already failed on `master`); LnurlPay also with dcclinux64 (compile only, no SDK to link); base, CoinOS, Bolt11, LnurlPay, Exchange with FPC.
  - The FMX demo compiles (Win32, Win64) and its Win64 exe starts and shows the form.
  - Found while testing: WinHTTP does not always honour `THTTPClient.ResponseTimeout` before the response headers (reproduced with an Indy and a Python server); hence the deadline in the base class.
- Not done / not verified:
  - No call to the real CoinOS API with money yet (plan S7, waiting for the test accounts).
  - Lazarus demo not updated (no Lazarus/LCL on this machine); FPC Unix branch of LnurlPay not compiled.
  - Pre-existing compile errors left as they were: Exchange on Delphi, Alby/DePIX/DIGPIX on FPC.
  - Release (boss.json 0.0.7, tag) not done: maintainer's step.

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
