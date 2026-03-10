# Spotlight Caffeinate

`Spotlight Caffeinate` is a small macOS 26 menu bar app that exposes `caffeinate` through Spotlight using App Intents.

The repo is intentionally focused on one command instead of being a generic terminal wrapper. That keeps the Spotlight action names clear, keeps the process model simple, and avoids turning the app into a privileged command launcher. The internal service layer is small and isolated, so it can be generalized later if there is a real need.

## Features

- Start `caffeinate` from Spotlight for a custom number of minutes
- Stop the current run from Spotlight or the menu bar
- Check current run status from Spotlight
- See active state and time remaining in a native menu bar extra

## Spotlight Flows

After the app is built and installed in `/Applications`, invoke Spotlight with `Cmd-Space` and try:

- `start spotlight caffeinate`
- `stop spotlight caffeinate`
- `check spotlight caffeinate status`

When Spotlight selects the start action, tab into the `Minutes` field, type a duration such as `5`, and press `Return`.

## Build

1. Generate the Xcode project:

   ```bash
   xcodegen generate
   ```

2. Open the generated project:

   ```bash
   open SpotlightCaffeinate.xcodeproj
   ```

3. Build and run the `SpotlightCaffeinate` scheme.
4. Copy the built `.app` into `/Applications` so Spotlight can index it reliably.

## Install With Homebrew

If you want the Homebrew path, use the custom tap cask:

```bash
brew install --cask TaylorFinklea/tap/spotlight-caffeinate
```

Because the current release artifacts are not Developer ID signed or notarized, macOS may still prompt on first launch. If Gatekeeper blocks the app after install, remove quarantine and try again:

```bash
xattr -dr com.apple.quarantine "/Applications/Spotlight Caffeinate.app"
```

## Notes

- The app tracks only the `caffeinate` process it starts itself.
- The current implementation runs `caffeinate -t <seconds>`.
- Status is shared between the menu bar UI and App Intents through a small JSON state file in Application Support.

## License

This project is licensed under the GNU General Public License v3.0. See [LICENSE](LICENSE).
