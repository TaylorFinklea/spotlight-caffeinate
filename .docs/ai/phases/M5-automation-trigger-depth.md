# M5 — Automation Trigger Depth

**Status:** stub. Fill in when prior milestones are complete.

## Goal

More ways to start a caffeinate session automatically, still inside current scope. No general shell-execution triggers and no external webhooks.

## Candidate work

- App-running trigger: start a session while app X is running (poll `NSWorkspace.runningApplications`).
- Network trigger: connected to a specified SSID; VPN on/off.
- Location trigger.
- Focus filter as a trigger source, tied to the platform Focus integration from M6 if that ships first.
- Quiet hours / do-not-trigger windows that apply across all trigger types.

## Design notes

- Any new trigger must round-trip through `AutomationTrigger`'s `Codable` without breaking existing rules (migration matters).
- Evaluation must stay bounded — today the automation loop ticks every second and is gated to minute boundaries for schedule/calendar. New triggers should stay in that budget.

## Open questions

- Do we require app-running triggers to specify a bundle identifier, or allow process-name matching?
- Does "connected to SSID" need Location Services on newer macOS versions? That changes the entitlement story.
