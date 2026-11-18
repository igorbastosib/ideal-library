# AGENTS.md — rules for AI coding agents in ideal-library

This file is the entry point for any AI agent (Claude Code, Cursor, Copilot, Codex, Gemini CLI, …) working in this repository. Read it fully before changing anything. Human contributors are welcome to follow it too.

## 1. What this repository is

- A Delphi library (mostly FireMonkey/FMX, RAD Studio 10.3 → 12.x) with a few units that also compile on Free Pascal / Lazarus through `{$IFDEF FPC}` branches.
- Consumed by other projects through [Boss](https://github.com/HashLoad/boss) (`boss.json`). Boss pins **git tags**, so a published tag is a contract: do not break public signatures without a deprecation path.
- Main repository: Bitbucket (`origin`). The GitHub repository `igorbastosib/ideal-library` is a mirror with its **own commit history**; release tags (`0.0.x`) currently live only there. Tagging and mirroring are done by the maintainer.
- Every integration (unit under `Api/`) has a demo project under `Demos/`. **Any feature added to an integration must also be shown in its demo** (maintainer rule).

## 2. Read before you start

1. [docs/agents/README.md](docs/agents/README.md) — how the agent documentation folder works.
2. [docs/agents/INDEX.md](docs/agents/INDEX.md) — map of folders, units, demos and their platforms.
3. [docs/agents/CHANGELOG.md](docs/agents/CHANGELOG.md) — what previous agents changed and what they left unverified.
4. Active plans in [docs/agents/plans/](docs/agents/plans/) — if your task belongs to one, follow it and update its status.

## 3. Language

- Code, code comments, XMLDoc, commit messages and repository documentation: **English** (the library is public and international).
- Conversation with the maintainer: **Portuguese (pt-BR)**, unless the maintainer writes in another language.
- Markdown: never hard-wrap lines. One paragraph or one bullet per line.

## 4. Git

- Local commands (`status`, `log`, `diff`, `branch`, `switch`, `add`, `commit`, `merge`, `rebase`, `stash`, `tag` locally, …) are allowed as part of the work.
- Remote commands (`fetch`, `pull`, `push`, `clone`, `ls-remote`, any `gh`/Bitbucket API write) **only when the maintainer explicitly asks for that action**. An approval covers that action only.
- Never commit to `master` directly. Work on a branch named `feature/<slug>`, `fix/<slug>` or `docs/<slug>`.
- Before anything that throws work away (`reset --hard`, `restore`, `clean`, `branch -D`, `stash drop`), check what would be lost and prefer a reversible path (backup branch or stash).
- Never skip hooks (`--no-verify`) or signing.
- Commit message: `type(scope): summary` (types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`), then a body with one bullet per change. The last line of every agent-authored commit message is the attribution trailer:

  ```
  Co-author: <AI product name> <model version>
  ```

  e.g. `Co-author: Claude Code Opus 5.5`. Several agents → several lines, in the order they worked. `Co-authored-by:` is reserved for **people**; never use it for an agent. If the model version is unknown, write `Co-author: <AI product name> (model version unconfirmed — please verify)`.
- When work ends in commits, tell the maintainer which commits, on which branch, and that nothing was pushed.
- Never commit build output or local files: `*.dcu`, `*.exe`, `Win32/`, `Win64/`, `Android/`, `__history/`, `__recovery/`, `*.local`, `*.identcache`, demo `config.json` files (they hold tokens and passwords).

## 5. File encoding and line endings — preserve, never convert

The repository mixes encodings. Converting a file silently corrupts accented characters for Delphi and produces huge diffs. Rules:

| What | Current state (surveyed 2026-11-18) | Rule |
| ---- | ---- | ---- |
| Line endings | `core.autocrlf=true`: index stores LF, working tree has CRLF. No `.gitattributes`. | Keep CRLF in the working tree. New text files: CRLF. Never commit a whole-file line-ending change. |
| `.pas` (most) | plain ASCII (119 files) | Keep them ASCII. Write English text; for non-ASCII characters in string literals use `#$xxxx` codes. |
| `.pas` UTF-8 | 11 files, all **with BOM** (e.g. `IdeaL.Lib.Utils.pas`) | Keep UTF-8 **and** the BOM. Delphi reads a BOM-less UTF-8 file as ANSI. |
| `.pas` ANSI | 8 files in Windows-1252 (`file` reports `iso-8859-1` or `unknown-8bit`, e.g. `Api/Bitcoin/IdeaL.Lib.Api.Bitcoin.DIGPIX.pas`) | Keep Windows-1252. Only use characters that exist in cp1252. Make sure your editing tool does not re-save the file as UTF-8. |
| `.dpr`, `.fmx`, `.lpr`, `.lpi` | ASCII | Keep ASCII. |
| `.dproj`, `.lfm` | UTF-8 (XML / Lazarus form) | Keep UTF-8, keep the existing BOM state. |
| `.md` | UTF-8 without BOM, CRLF | Keep. |
| New `.pas` units | — | ASCII only. If non-ASCII is unavoidable, UTF-8 **with** BOM, and say so in the commit. |

Check before and after every edit:

```
file --mime-encoding <file>        # encoding
file <file>                        # must still say "with CRLF line terminators"
head -c 3 <file> | od -An -tx1     # ef bb bf = BOM
git diff --stat                    # a one-line change must not show the whole file as changed
```

## 6. Delphi / Free Pascal parity

- Units with `{$IFDEF FPC}` branches promise the same behaviour on both compilers. A behaviour change must touch both branches, or the commit and the CHANGELOG must say clearly that the FPC branch was not changed.
- Code outside `{$IFNDEF FPC}` / `{$ELSE}` blocks must compile on FPC (`{$mode objfpc}{$H+}`): no inline `var`, no `for var`, no type inference, no `System.*` unit names, no `TNetHeaders`/`TNameValuePair` unless the unit defines them for FPC.
- FPC/Lazarus is **not installed** on the maintainer's machine (as of 2026-11-18). If you cannot compile the FPC branch, write "FPC branch not compiled" in the commit body and in the CHANGELOG entry. Never claim FPC compatibility you did not verify.
- The compatibility table in `Api/Bitcoin/README.md` must reflect reality.

## 7. Code conventions (as observed in the code base)

- Unit names: `IdeaL.Lib.<Area>.<Name>.pas`; integrations: `IdeaL.Lib.Api.<Area>.<Name>.pas`.
- Types `T…`, exceptions `E…`, fields `F…`, parameters `A…`, locals `L…`, constants `C…`. Two-space indentation.
- Fluent setters return `Self` (e.g. `TAPICoinOS.AuthToken(AValue): TAPICoinOS`).
- Public methods carry XMLDoc (`/// <summary>`, `/// <param name="…">`, `/// <remarks>`). Keep tags balanced.
- Delphi-only code may use inline `var` (the existing style), but only inside Delphi-only blocks (see §6).
- HTTP integrations derive from `TIdeaLApi` (`Api/IdeaL.Lib.Api.pas`). Changes to `TIdeaLApi` affect every integration: compile all of them afterwards (see §9).

## 8. Security and money

- Never put tokens, passwords, PINs, API keys, Lightning invoices or URLs that contain them in exception messages, logs, commit messages, docs or test fixtures. Use the public BOLT 11 spec test vectors for fixtures.
- Never commit credentials. Demo `config.json` files stay local (ignored by `Win32/`).
- Tests that move real funds (CoinOS, Lightning wallets) run only with the maintainer's explicit approval for that run, with small amounts, on accounts created for testing. Record what ran in the plan.
- Payment code must be idempotent-friendly: keep the invoice before paying, never retry with a new invoice while the previous one may still be paid.

## 9. Build and verify

- Delphi 12 (RAD Studio 23.0) command-line compilers are on `PATH`: `dcc32`, `dcc64`.
- Quick compile check of units without the IDE: create a console `.dpr` in a scratch folder that `uses` the units by path, then run

  ```
  dcc32 -B -Q -NSSystem;Winapi -N0<out-dir> -E<out-dir> <Project>.dpr
  ```

  Output (`.dcu`, `.exe`) goes to the scratch folder, never into the repository.
- After touching `TIdeaLApi`, compile every unit that derives from it: CoinOS, Alby, DePIX, DIGPIX, Exchange, ImgBB.
- Report the result honestly: compiled / not compiled / tests passed / tests not run.

## 10. Documentation duties for every change

1. Add an entry to [docs/agents/CHANGELOG.md](docs/agents/CHANGELOG.md) (newest first).
2. Update [docs/agents/INDEX.md](docs/agents/INDEX.md) when files are added, moved or deleted.
3. Update the user-facing README of the area (e.g. `Api/Bitcoin/README.md`) when behaviour visible to library users changes.
4. Update the demo of the integration (see §1).
5. Keep the active plan's status current.

## 11. Deliverables

- Reports, plans, analyses and runbooks are **local Markdown files** inside this repository (normally under `docs/agents/`). Never publish or upload them to a hosted page, artifact, gist or paste service unless the maintainer explicitly asks.
- Stop any background process you started (servers, watchers) as soon as it is no longer needed.
