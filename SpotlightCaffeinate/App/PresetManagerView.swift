import SwiftUI

struct PresetManagerView: View {
    @Bindable var controller: CaffeinateController

    @State private var selectedPresetID: UUID?
    @State private var draft = PresetDraft.newPreset()

    var body: some View {
        HSplitView {
            presetList
            editorPanel
        }
        .padding(20)
        .frame(minWidth: 720, minHeight: 430)
        .onAppear {
            if selectedPresetID == nil, let first = controller.presets.first {
                selectedPresetID = first.id
                draft = .init(preset: first)
            }
        }
        .onChange(of: selectedPresetID) { _, newValue in
            guard let newValue, let preset = controller.presets.first(where: { $0.id == newValue }) else {
                return
            }

            draft = .init(preset: preset)
        }
        .onChange(of: controller.presets) { _, presets in
            guard let selectedPresetID else {
                if let first = presets.first {
                    self.selectedPresetID = first.id
                    draft = .init(preset: first)
                }
                return
            }

            guard let preset = presets.first(where: { $0.id == selectedPresetID }) else {
                self.selectedPresetID = nil
                draft = .newPreset()
                return
            }

            draft = .init(preset: preset)
        }
    }

    private var presetList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Presets")
                    .font(.title3.weight(.semibold))

                Spacer()

                Button("New Preset") {
                    selectedPresetID = nil
                    draft = .newPreset()
                }
                .buttonStyle(.borderedProminent)
            }

            List(selection: $selectedPresetID) {
                ForEach(controller.presets) { preset in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.name)
                            Text("\(preset.minutes) minutes • \(preset.powerMode.title)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if preset.isPinned {
                            Image(systemName: "pin.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(preset.id)
                }
            }
        }
        .frame(minWidth: 300)
    }

    private var editorPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(draft.id == nil ? "New Preset" : "Edit Preset")
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 12) {
                TextField("Preset Name", text: $draft.name)

                Stepper(value: $draft.minutes, in: 1...480) {
                    Text("\(draft.minutes) minutes")
                }

                Picker("Power Mode", selection: $draft.powerMode) {
                    ForEach(PowerMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Pin in Quick Start", isOn: $draft.isPinned)
            }

            Text("System mode uses `caffeinate -s`, which macOS only honors while the Mac is on AC power.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button(draft.id == nil ? "Create Preset" : "Save Changes") {
                    Task {
                        let savedID = await controller.savePreset(
                            id: draft.id,
                            name: draft.name,
                            minutes: draft.minutes,
                            powerMode: draft.powerMode,
                            isPinned: draft.isPinned
                        )

                        if let savedID {
                            selectedPresetID = savedID
                        }
                    }
                }
                .buttonStyle(.borderedProminent)

                if let id = draft.id {
                    Button("Delete") {
                        Task {
                            await controller.deletePreset(id: id)
                            selectedPresetID = controller.presets.first?.id
                        }
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Move Up") {
                        Task {
                            await controller.movePreset(id: id, direction: .up)
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Move Down") {
                        Task {
                            await controller.movePreset(id: id, direction: .down)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }

            if let lastError = controller.lastError {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
        .frame(minWidth: 320, alignment: .topLeading)
    }
}

private struct PresetDraft: Equatable {
    var id: UUID?
    var name: String
    var minutes: Int
    var powerMode: PowerMode
    var isPinned: Bool

    init(id: UUID?, name: String, minutes: Int, powerMode: PowerMode, isPinned: Bool) {
        self.id = id
        self.name = name
        self.minutes = minutes
        self.powerMode = powerMode
        self.isPinned = isPinned
    }

    init(preset: CaffeinatePreset) {
        id = preset.id
        name = preset.name
        minutes = preset.minutes
        powerMode = preset.powerMode
        isPinned = preset.isPinned
    }

    static func newPreset() -> PresetDraft {
        PresetDraft(id: nil, name: "", minutes: 15, powerMode: .full, isPinned: true)
    }
}
