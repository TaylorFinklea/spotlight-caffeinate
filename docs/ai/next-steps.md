# Next Steps

- [ ] Finish App Store Connect execution work:
  - screenshots
  - pricing
  - App Privacy answers
  - App Review notes
- [ ] Run the full signed `/Applications` release checklist before submission:
  - menu bar validation
  - confirm the launch-time privacy prompt no longer appears
  - confirm the machine can sleep again after a timer-backed session expires
  - notifications
  - launch at login
  - bundled CLI sync
- [ ] Upload the App Store archive from Xcode Organizer or Transporter and complete submission.
- [ ] Add the `HOMEBREW_TAP_PAT` repo secret so `.github/workflows/update-homebrew-tap.yml` can push tap updates automatically on future releases.
- [ ] Continue maintaining `docs/ai/current-state.md`, `docs/ai/next-steps.md`, and `docs/ai/decisions.md` at the end of each work session.
