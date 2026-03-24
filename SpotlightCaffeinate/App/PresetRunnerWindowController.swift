import AppKit
import SwiftUI

@MainActor
final class PresetRunnerWindowController: NSWindowController, NSWindowDelegate {
    static let shared = PresetRunnerWindowController()
    private let hostingController: NSHostingController<PresetRunnerView>

    private init() {
        hostingController = NSHostingController(rootView: PresetRunnerView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Run Preset"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 420, height: 320))
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        hostingController.rootView = PresetRunnerView()
        let previousPolicy = NSApplication.shared.activationPolicy()
        if previousPolicy != .regular {
            NSApplication.shared.setActivationPolicy(.regular)
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)

        if previousPolicy != .regular {
            NSApplication.shared.setActivationPolicy(previousPolicy)
        }
    }

    func closePicker() {
        close()
    }
}

private struct PresetRunnerView: View {
    @State private var presets: [CaffeinatePreset] = []
    @State private var selectedPresetID: UUID?
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var isStarting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose a preset")
                .font(.title3.weight(.semibold))

            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if presets.isEmpty {
                    ContentUnavailableView(
                        "No Presets",
                        systemImage: "bookmark.slash",
                        description: Text("Create a preset in Spotlight Caffeinate first.")
                    )
                } else {
                    List(selection: $selectedPresetID) {
                        ForEach(presets) { preset in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name)
                                Text("\(preset.minutes)m • \(preset.powerMode.title)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(preset.id)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    PresetRunnerWindowController.shared.closePicker()
                }
                .keyboardShortcut(.cancelAction)

                Button(isStarting ? "Starting..." : "Start Preset") {
                    startSelectedPreset()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(selectedPresetID == nil || isStarting || presets.isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 320)
        .task {
            await loadPresets()
        }
    }

    private func loadPresets() async {
        isLoading = true

        do {
            let loadedPresets = try await CaffeinateService.shared.presets()
            presets = loadedPresets
            selectedPresetID = loadedPresets.first?.id
            errorMessage = nil
        } catch {
            presets = []
            selectedPresetID = nil
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func startSelectedPreset() {
        guard let selectedPresetID else {
            return
        }

        isStarting = true
        errorMessage = nil

        Task {
            do {
                _ = try await CaffeinateService.shared.startPreset(id: selectedPresetID, source: .spotlight)
                await MainActor.run {
                    isStarting = false
                    PresetRunnerWindowController.shared.closePicker()
                }
            } catch {
                await MainActor.run {
                    isStarting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
