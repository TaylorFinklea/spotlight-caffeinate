# M1 — Quality Hardening (1.0 gate)

## Goal

Raise the test and observability floor so 1.0 can ship without silent regressions. This milestone exists because the user explicitly chose to gate 1.0 on hardening over shipping current code as-is.

## Why it blocks 1.0

- Automation rule evaluation errors are caught and dropped in `Services/AutomationService.swift`. A rule that stops firing because calendar access was revoked or because a stored trigger is malformed today produces zero signal to the user or the developer.
- Only parser tests and service unit tests exist for the CLI. There is no test that spawns the built binary against an isolated storage context, so the actual CLI execution path is unverified.
- `CaffeinateController`'s notification enable flow races a 200 ms `Task.sleep` against app activation. If activation is slow (cold launch, login hook), notifications can be scheduled before authorization, which fails silently on some paths.
- Error paths in `CaffeinateService` and `AutomationService` (invalid presets, calendar auth denial, bad automation params, corrupted JSON) are not systematically covered.

## Scope

**In**

- Structured logging for `AutomationService` evaluation and execution failures using `os.Logger`. Dedicated subsystem; log rule id, trigger kind, failure reason. No user data (event titles, calendar names) at info level.
- CLI end-to-end integration tests: build the CLI, spawn it in tests with `XDG`-style env to point storage at a temporary App Group fallback directory, verify persisted state matches expected output for every command including JSON output format. `watch` covered with a cancellation check.
- Error-path tests for `CaffeinateService` and `AutomationService`: at least invalid preset lookup, calendar auth denial, invalid automation parameters, file-permission failures on the storage directory, corrupted JSON recovery.
- Remove the 200 ms sleep in the notification enable flow and replace it with an explicit async signal tied to app activation.
- Land `Clock` / `DateProvider` protocol in `Support/` and thread it through services so test date injection is consistent.

**Out**

- Full refactor of `CaffeinateController` (553 lines). Call that out as an Opus backlog item; don't do it here unless it is the only way to remove the sleep.
- Adding any new user-visible feature.
- Changing storage layout or migration rules.

## Exit criteria

Matches the M1 exit criteria in `.docs/ai/roadmap.md`. Every bullet must be demonstrably met in the merged PR.

## Owner

User-directed for Claude despite repo-level `tier3_owner: codex`. User said at the start of the 2026-04-19 session that Claude will plan this milestone. If that changes, reassign and hand off via `/handoff-prompt`.

## Open questions

- Do we want a feature flag / env var to disable automation error logging in CLI output, or is it always on via `os.Logger`? Default proposed: always on via `os.Logger`; not printed to stderr from the CLI.
- Integration test strategy for `watch`: spawn + short wait + kill signal, or inject a cancellation token? Default proposed: spawn + kill signal, since that is what end users see.
