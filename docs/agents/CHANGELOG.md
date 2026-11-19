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

## 2026-11-19 — Fix "Error adding header (12150)" on CoinOS login with an empty x-api-key

- Agent: Claude Code Opus 5.5
- Branch / commits: `feature/coinos-safe-lnaddress-payment` — see `git log` (fix commit after `c572ee6`). Nothing pushed.
- Plan: [plans/2026-11-18-coinos-safe-lnaddress-payment.md](plans/2026-11-18-coinos-safe-lnaddress-payment.md)
- Changed:
  - `Api/IdeaL.Lib.Api.pas`: headers with an empty value are no longer sent (Delphi and FPC). WinHTTP reads "Name:" with an empty value as "remove header" and fails with 12150 when it is absent; the demo always passes the x-api-key edit, so login failed whenever it was empty. Reproduced with the 0.0.6 code from `master` too: the bug predates this branch.
  - `Demos/Api/Bitcoin/CoinOS/Unit1.pas`: when CoinOS answers 401 "failed captcha", the demo explains that API logins need a captcha or a CoinOS x-api-key and points to the exported token.
  - `Api/Bitcoin/README.md`: note about the captcha on API logins (coinos-server `routes/users.ts`, `login` → `verifyRecaptcha`: bypass only with a registered x-api-key, allowlisted user or user agent, .onion host, or a valid reCAPTCHA token).
  - Tests: `EmptyHeaderValues_AreNotSent_AndDoNotRaise` (base), `PostLogin_EmptyXApiKey_DoesNotRaise` (CoinOS), `PostLogin_EmptyXApiKey` (FPC).
- Verified: DUnitX 122/122, fpcunit 25/25; demo compiles (dcc32, dcc64). Live, with the maintainer's test account and no money moved: the login request now reaches CoinOS, which answers 401 "failed captcha" (server policy, see above).
- Not done / not verified: authenticated live calls (GET /me, payments) need the exported token from coinos.io.

## 2026-11-19 — Alby, DePIX, DIGPIX and Exchange: compile on Delphi and FPC, characterisation tests

- Agent: Claude Code Opus 5.5
- Branch / commits: `fix/bitcoin-siblings-compile` (cut from `feature/coinos-safe-lnaddress-payment` at `c572ee6`, because the test runners and the FPC build of `TIdeaLApi` exist only there) — `a47f8ac` (seam + DUnitX characterisation tests), `19af9b6` (Exchange), `58f3082` (FPC fixes + fpcunit tests), plus the docs commit that adds this entry. Nothing pushed.
- Plan: none (fixes of compile errors that already existed on `master`, listed as known failures in the previous entry).
- Changed:
  - `Api/Bitcoin/IdeaL.Lib.Api.Bitcoin.Exchange.pas`: `Post` (Delphi) no longer sends `Authorization: Bearer FAuthToken`. Evidence: `TAPIExchange` never declared `FAuthToken` (not since the unit was created in `2894576`, 2024-09-08) and `TIdeaLApi` never had it, so the unit never compiled on Delphi; all its endpoints are public; `7175dfe` ("Removing Authorization from Exchange API", 2025-07-06) commented the same header out of `Get` and missed `Post`. Added `{$mode objfpc}{$H+}`.
  - `IdeaL.Lib.Api.Bitcoin.Alby.pas`, `.DePIX.pas`, `.DIGPIX.pas`: `{$mode objfpc}{$H+}`, `openssl`/`opensslsockets` (and `DateUtils` for Alby) in the FPC uses; inline vars in shared code (DePIX `GetDeposits(TDate)`, DIGPIX `GetQrCode`) replaced by declared vars; Alby: misplaced `{$ENDIF}` that hid six methods from FPC, `..Add` typos, FPC `PostWebWebHook` body completed (`url`, `filter_types`), `AuthToken(AValue)` returns `Self` (Result was unassigned, on Delphi too); DePIX: undeclared `ALightning` removed, FPC `Post` accepts any 2xx; DIGPIX: `EmtpyStr`/`LJSONObj` typos, FPC sends `X-API-Key` like Delphi (Delphi moved from Bearer in `6c5424f`, FPC was left behind).
  - FPC transport of the four units: `HTTPMethod(..., [])` into a `TStringStream` instead of `TFPHttpClient.Get/Post/Delete` into a `TStrings`, so the units' own status checks decide (before, FPC `Get` raised `EHTTPClient` on anything but 200, which `IsTransportError` reports as "no answer"), results have no extra trailing line break, and error messages use the Delphi format. Exchange's FPC branch compiled before: for FPC users of Exchange this changes the exception class/message on errors and removes the trailing line break.
  - Protected `Get`/`Post` (and Alby `Del`) of the four units are now `virtual` (test seam; descendants can intercept requests).
  - Tests: `Tests/Delphi/Test.IdeaL.Lib.Api.Bitcoin.{Alby,DePIX,DIGPIX,Exchange}.pas`, `Tests/FPC/TestBitcoinApisFpc.pas`; `TLocalHttpServer.Rebase`, `RaisedMessage`; `TestServerFpc` records `Content-Type`/`X-Async`/`X-Nonce`, `TestRebase`.
  - Docs: compatibility table in `Api/Bitcoin/README.md`, `docs/agents/INDEX.md`, `AGENTS.md` §9 (known failures line).
- Verified:
  - The Alby, DePIX and DIGPIX DUnitX tests were written first and passed (148/148 with the existing suite) on the unchanged request code; they stayed unchanged and green after the fixes.
  - Each of Alby, DePIX, DIGPIX, Exchange (and CoinOS, LnurlPay, Bolt11) compiles on its own with dcc32, dcc64 and `C:\FPC\3.2.2\bin\i386-win32\fpc.exe` (no `-M` option needed now).
  - DUnitX (Win64): 153/153. fpcunit (FPC 3.2.2 i386-win32): 44/44.
- Not done / not verified:
  - No call to the real Alby, Eulen, VemPraDig or price APIs; only the local test servers.
  - Demos (`Demos/Api/Bitcoin/{Alby,DePIX,DIGPIX}`) not rebuilt; no public signature changed except the `virtual` seam and the Alby `AuthToken` result.
  - Left as found (follow-ups): DePIX `constructor Create` hides the virtual `TIdeaLApi.Create` (W1010 / FPC warning) and does not call `inherited`; DePIX `splitFee` uses the global `FormatSettings`, so on a pt-BR locale `'2.5'` fails `StrToFloat` and a value like `'2,5'` is sent as `"2,50%"`; DIGPIX's Delphi `GetNetHttpRequestLocal` still sets `Authorization: Bearer` (unused by the unit itself); FPC still sends `Content-Type: application/json` without `charset=utf-8` and a 30 s connect timeout in DePIX/DIGPIX; these units do not use the `TIdeaLApi` timeout overloads or `EIdeaLApiError`.
  - FPC Unix targets and Lazarus not built.

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
