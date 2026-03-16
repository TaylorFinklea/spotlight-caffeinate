import SwiftUI

struct AutomationManagerView: View {
    @Bindable var controller: CaffeinateController

    @State private var selectedRuleID: UUID?
    @State private var draft = AutomationRuleDraft.newRule()

    var body: some View {
        HSplitView {
            ruleList
            editorPanel
        }
        .padding(20)
        .frame(minWidth: 860, minHeight: 560)
        .onAppear {
            Task {
                await controller.refreshAutomationCalendars()
            }

            if selectedRuleID == nil, let first = controller.automationRules.first {
                selectedRuleID = first.id
                draft = .init(rule: first)
            }
        }
        .onChange(of: selectedRuleID) { _, newValue in
            guard let newValue, let rule = controller.automationRules.first(where: { $0.id == newValue }) else {
                return
            }

            draft = .init(rule: rule)
        }
        .onChange(of: controller.automationRules) { _, rules in
            guard let selectedRuleID else {
                if let first = rules.first {
                    self.selectedRuleID = first.id
                    draft = .init(rule: first)
                }
                return
            }

            guard let rule = rules.first(where: { $0.id == selectedRuleID }) else {
                self.selectedRuleID = nil
                draft = .newRule()
                return
            }

            draft = .init(rule: rule)
        }
    }

    private var ruleList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Automations")
                    .font(.title3.weight(.semibold))

                Spacer()

                Button("New Automation") {
                    selectedRuleID = nil
                    draft = .newRule()
                }
                .buttonStyle(.borderedProminent)
            }

            List(selection: $selectedRuleID) {
                ForEach(controller.automationRules) { rule in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(rule.name)
                            Spacer()
                            if rule.enabled {
                                Image(systemName: "bolt.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(ruleSummary(rule))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(rule.id)
                }
            }
        }
        .frame(minWidth: 320)
    }

    private var editorPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(draft.id == nil ? "New Automation" : "Edit Automation")
                    .font(.title3.weight(.semibold))

                VStack(alignment: .leading, spacing: 12) {
                    TextField("Automation Name", text: $draft.name)

                    Picker("Preset", selection: $draft.presetID) {
                        ForEach(controller.presets) { preset in
                            Text("\(preset.name) • \(preset.minutes)m • \(preset.powerMode.title)")
                                .tag(Optional(preset.id))
                        }
                    }

                    Toggle("Enabled", isOn: $draft.enabled)

                    Picker("Trigger", selection: $draft.triggerKind) {
                        ForEach(AutomationTriggerKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                triggerEditor

                if let lastRun = selectedRunRecord {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Latest Run")
                            .font(.headline)

                        Text(lastRun.outcome.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(lastRun.outcome.isError ? .red : .green)

                        Text(lastRun.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(lastRun.firedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Automation Runs")
                        .font(.headline)

                    if controller.automationRunHistory.isEmpty {
                        Text("No automation runs yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(controller.automationRunHistory) { record in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(record.ruleName)
                                    Spacer()
                                    Text(record.outcome.title)
                                        .foregroundStyle(record.outcome.isError ? .red : .green)
                                }
                                .font(.caption.weight(.semibold))

                                Text(record.message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(record.firedAt.formatted(date: .omitted, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button(draft.id == nil ? "Create Automation" : "Save Changes") {
                        Task {
                            guard let presetID = draft.presetID else {
                                controller.lastError = "Choose a preset for this automation."
                                return
                            }

                            let savedID = await controller.saveAutomationRule(
                                id: draft.id,
                                name: draft.name,
                                presetID: presetID,
                                trigger: draft.trigger,
                                enabled: draft.enabled
                            )

                            if let savedID {
                                selectedRuleID = savedID
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    if let id = draft.id {
                        Button("Delete") {
                            Task {
                                await controller.deleteAutomationRule(id: id)
                                selectedRuleID = controller.automationRules.first?.id
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
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var triggerEditor: some View {
        switch draft.triggerKind {
        case .weekly:
            VStack(alignment: .leading, spacing: 10) {
                Text("Weekly Schedule")
                    .font(.headline)

                HStack(spacing: 8) {
                    ForEach(AutomationWeekday.allCases) { weekday in
                        weekdayButton(weekday)
                    }
                }

                DatePicker(
                    "Run At",
                    selection: $draft.timeOfDay,
                    displayedComponents: .hourAndMinute
                )
            }

        case .power:
            VStack(alignment: .leading, spacing: 10) {
                Text("Power Change")
                    .font(.headline)

                Picker("When", selection: $draft.powerEvent) {
                    ForEach(AutomationPowerEvent.allCases) { event in
                        Text(event.title).tag(event)
                    }
                }
                .pickerStyle(.segmented)
            }

        case .calendar:
            VStack(alignment: .leading, spacing: 10) {
                Text("Calendar Event")
                    .font(.headline)

                if controller.calendarAuthorizationState != .granted {
                    VStack(alignment: .leading, spacing: 8) {
                        if let status = controller.calendarStatus {
                            Text(status)
                                .font(.caption)
                                .foregroundStyle(controller.calendarStatusIsError ? .red : .secondary)
                        }

                        Button("Enable Calendar Access") {
                            controller.requestCalendarAccess()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Calendars")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if controller.availableCalendars.isEmpty {
                            Text("No calendars are currently available.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(controller.availableCalendars) { calendar in
                                Toggle(
                                    isOn: Binding(
                                        get: { draft.selectedCalendarIDs.contains(calendar.id) },
                                        set: { isSelected in
                                            if isSelected {
                                                draft.selectedCalendarIDs.insert(calendar.id)
                                            } else {
                                                draft.selectedCalendarIDs.remove(calendar.id)
                                            }
                                        }
                                    )
                                ) {
                                    Text(calendar.sourceTitle.map { "\(calendar.title) (\($0))" } ?? calendar.title)
                                }
                            }
                        }
                    }

                    Stepper(value: $draft.startsBeforeMinutes, in: 0...240) {
                        Text("Start \(draft.startsBeforeMinutes) minute\(draft.startsBeforeMinutes == 1 ? "" : "s") before the event")
                    }

                    TextField("Title contains (optional)", text: $draft.titleContains)
                }
            }
        }
    }

    private var selectedRunRecord: AutomationRunRecord? {
        guard let selectedRuleID else {
            return nil
        }

        return controller.automationRunHistory.first(where: { $0.ruleID == selectedRuleID })
    }

    private func weekdayButton(_ weekday: AutomationWeekday) -> some View {
        Button {
            if draft.weekdays.contains(weekday) {
                draft.weekdays.remove(weekday)
            } else {
                draft.weekdays.insert(weekday)
            }
        } label: {
            Text(weekday.shortLabel)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(draft.weekdays.contains(weekday) ? .accentColor : .gray.opacity(0.45))
    }

    private func ruleSummary(_ rule: AutomationRule) -> String {
        let presetName = controller.presets.first(where: { $0.id == rule.presetID })?.name ?? "Missing preset"
        return "\(presetName) • \(triggerSummary(rule.trigger))"
    }

    private func triggerSummary(_ trigger: AutomationTrigger) -> String {
        switch trigger {
        case .weekly(let schedule):
            let days = schedule.normalizedWeekdays.map(\.shortLabel).joined(separator: ", ")
            let components = DateComponents(hour: schedule.hour, minute: schedule.minute)
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let time = Calendar.current.date(from: components).map { formatter.string(from: $0) } ?? "\(schedule.hour):\(String(format: "%02d", schedule.minute))"
            return "\(days) at \(time)"
        case .power(let event):
            return event.title
        case .calendar(let trigger):
            let count = trigger.calendarIdentifiers.count
            let filter = trigger.normalizedTitleContains.map { " • '\($0)'" } ?? ""
            return "\(count) calendar\(count == 1 ? "" : "s") • \(trigger.startsBeforeMinutes)m before\(filter)"
        }
    }
}

private struct AutomationRuleDraft: Equatable {
    var id: UUID?
    var name: String
    var presetID: UUID?
    var enabled: Bool
    var triggerKind: AutomationTriggerKind
    var weekdays: Set<AutomationWeekday>
    var timeOfDay: Date
    var powerEvent: AutomationPowerEvent
    var selectedCalendarIDs: Set<String>
    var startsBeforeMinutes: Int
    var titleContains: String

    var trigger: AutomationTrigger {
        switch triggerKind {
        case .weekly:
            let components = Calendar.current.dateComponents([.hour, .minute], from: timeOfDay)
            return .weekly(
                WeeklyAutomationTrigger(
                    weekdays: Array(weekdays),
                    hour: components.hour ?? 9,
                    minute: components.minute ?? 0
                )
            )
        case .power:
            return .power(powerEvent)
        case .calendar:
            return .calendar(
                CalendarAutomationTrigger(
                    calendarIdentifiers: Array(selectedCalendarIDs),
                    startsBeforeMinutes: startsBeforeMinutes,
                    titleContains: titleContains
                )
            )
        }
    }

    init(
        id: UUID?,
        name: String,
        presetID: UUID?,
        enabled: Bool,
        triggerKind: AutomationTriggerKind,
        weekdays: Set<AutomationWeekday>,
        timeOfDay: Date,
        powerEvent: AutomationPowerEvent,
        selectedCalendarIDs: Set<String>,
        startsBeforeMinutes: Int,
        titleContains: String
    ) {
        self.id = id
        self.name = name
        self.presetID = presetID
        self.enabled = enabled
        self.triggerKind = triggerKind
        self.weekdays = weekdays
        self.timeOfDay = timeOfDay
        self.powerEvent = powerEvent
        self.selectedCalendarIDs = selectedCalendarIDs
        self.startsBeforeMinutes = startsBeforeMinutes
        self.titleContains = titleContains
    }

    init(rule: AutomationRule) {
        id = rule.id
        name = rule.name
        presetID = rule.presetID
        enabled = rule.enabled

        switch rule.trigger {
        case .weekly(let trigger):
            triggerKind = .weekly
            weekdays = Set(trigger.weekdays)
            timeOfDay = Calendar.current.date(from: DateComponents(hour: trigger.hour, minute: trigger.minute)) ?? .now
            powerEvent = .connected
            selectedCalendarIDs = []
            startsBeforeMinutes = 0
            titleContains = ""
        case .power(let event):
            triggerKind = .power
            weekdays = [.monday]
            timeOfDay = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? .now
            powerEvent = event
            selectedCalendarIDs = []
            startsBeforeMinutes = 0
            titleContains = ""
        case .calendar(let trigger):
            triggerKind = .calendar
            weekdays = [.monday]
            timeOfDay = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? .now
            powerEvent = .connected
            selectedCalendarIDs = Set(trigger.calendarIdentifiers)
            startsBeforeMinutes = trigger.startsBeforeMinutes
            titleContains = trigger.normalizedTitleContains ?? ""
        }
    }

    static func newRule() -> AutomationRuleDraft {
        AutomationRuleDraft(
            id: nil,
            name: "",
            presetID: nil,
            enabled: true,
            triggerKind: .weekly,
            weekdays: [.monday, .tuesday, .wednesday, .thursday, .friday],
            timeOfDay: Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? .now,
            powerEvent: .connected,
            selectedCalendarIDs: [],
            startsBeforeMinutes: 5,
            titleContains: ""
        )
    }
}
