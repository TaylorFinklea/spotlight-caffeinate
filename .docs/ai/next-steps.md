# Next Steps

## Immediate

- [ ] Plan M1 (Quality Hardening) in detail. User said they will switch Claude into planning mode for this after the roadmap/backlog update is committed. Brief lives at `.docs/ai/phases/M1-quality-hardening.md`.

## M1 execution queue (after plan is approved)

- [ ] Add `os.Logger` failure logging to `Services/AutomationService.swift` evaluation + execution paths.
- [ ] Introduce `Clock` / `DateProvider` protocol in `Support/` and thread it through `CaffeinateService` + `AutomationService`.
- [ ] Add error-path test coverage for `CaffeinateService` and `AutomationService` (invalid preset, calendar auth denial, invalid automation parameters, file-permission failures, corrupted JSON).
- [ ] Build CLI end-to-end integration tests that spawn `spotlight-caffeinate-cli` against an isolated storage context, covering every command including `watch`.
- [ ] Remove the 200 ms `Task.sleep` in the notification enable flow.

## M2 execution queue (after M1 is closed)

- [ ] Full signed `/Applications` release-checklist pass.
- [ ] App Store Connect: screenshots, pricing, App Privacy answers, App Review notes.
- [ ] Upload App Store archive via Xcode Organizer or Transporter.
- [ ] Configure `HOMEBREW_TAP_PAT` repo secret.
- [ ] Establish `CHANGELOG.md` with the 1.0 entry.
- [ ] Cut `v1.0.0` GitHub release; verify cask + formula installs both work; refresh GitHub Pages site.

## Ongoing

- [ ] Keep `.docs/ai/current-state.md`, `.docs/ai/next-steps.md`, and `.docs/ai/decisions.md` current at the end of each session.
- [ ] When a Haiku/Sonnet backlog item is picked up, follow the claim protocol: flip `- [ ]` → `- [~]` and commit, then `- [x]` on completion.
