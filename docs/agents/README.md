# docs/agents — working folder for AI agents

This folder holds everything an AI agent (or a human reviewing agent work) needs to continue work safely across sessions. The rules themselves are in [/AGENTS.md](../../AGENTS.md).

| Path | Purpose | Who updates it |
| ---- | ---- | ---- |
| [INDEX.md](INDEX.md) | Map of the repository: folders, units, demos, platforms, encodings worth knowing. | Any agent that adds, moves or deletes files. |
| [CHANGELOG.md](CHANGELOG.md) | One entry per agent work session that changed the repository: what, why, where, how it was verified, what was left undone. Newest first. | Every agent, every change. |
| [plans/](plans/) | One file per task that needs analysis before code: verified facts, design decisions, steps, test plan, open questions. | The agent that plans the task; later agents update its status. |
| [plans/_TEMPLATE.md](plans/_TEMPLATE.md) | Skeleton for new plans. | — |

## Conventions

- Plan file name: `YYYY-MM-DD-<short-slug>.md` (date the plan was started). Never rename a plan after other files link to it; mark it `Superseded by …` instead.
- Every plan starts with a status block (`Status`, `Branch`, `Owner`, `Last update`). Status values: `Draft` → `Approved` → `In progress` → `Done` (or `Abandoned` / `Superseded`).
- A plan records **evidence**, not memory: link to files and line numbers, quote command output, give dates. Facts taken from third-party sources must say where and when they were checked.
- CHANGELOG entries describe what agents did. The library's user-facing release notes (if any) are written by the maintainer.
- Markdown here follows the repository rules: UTF-8 without BOM, CRLF, no hard-wrapped lines, English.
