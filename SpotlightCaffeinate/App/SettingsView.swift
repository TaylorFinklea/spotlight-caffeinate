import SwiftUI

struct SettingsView: View {
    @Bindable var controller: CaffeinateController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                settingsCard(title: "Menu Bar Appearance") {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Glyph style")
                                .font(.subheadline)

                            Picker(
                                "Glyph style",
                                selection: Binding(
                                    get: { controller.glyphStyle },
                                    set: { controller.setGlyphStyle($0) }
                                )
                            ) {
                                ForEach(GlyphStyle.allCases) { style in
                                    Text(style.title).tag(style)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()

                            Text(controller.glyphStyle.detailText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Picker(
                                "Near-expiry pulse",
                                selection: Binding(
                                    get: { controller.pulseThreshold },
                                    set: { controller.setPulseThreshold($0) }
                                )
                            ) {
                                ForEach(PulseThreshold.allCases) { threshold in
                                    Text(threshold.title).tag(threshold)
                                }
                            }

                            Text("The bolt softly fades when remaining time falls below this threshold.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                settingsCard(
                    title: "Launch at Login",
                    status: controller.launchAtLoginStatus,
                    statusIsError: controller.launchAtLoginStatusIsError
                ) {
                    Toggle(
                        "Open Spotlight Caffeinate at login",
                        isOn: Binding(
                            get: { controller.launchAtLoginEnabled },
                            set: { controller.setLaunchAtLoginEnabled($0) }
                        )
                    )
                }

                settingsCard(
                    title: "Notifications",
                    status: controller.notificationStatus,
                    statusIsError: controller.notificationStatusIsError
                ) {
                    if controller.notificationAuthorizationState == .granted {
                        Toggle(
                            "Notify when caffeinate ends",
                            isOn: Binding(
                                get: { controller.notificationsEnabled },
                                set: { controller.setNotificationsEnabled($0) }
                            )
                        )
                    } else {
                        Button("Enable Notifications", action: requestNotifications)
                            .buttonStyle(.borderedProminent)

                        Button("Open Notification Settings", action: openNotificationSettings)
                            .buttonStyle(.link)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 420, minHeight: 320)
    }

    private func settingsCard<Content: View>(
        title: String,
        status: String? = nil,
        statusIsError: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            content()

            if let status {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(statusIsError ? .red : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            .quaternary.opacity(0.3),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private func requestNotifications() {
        controller.requestNotificationAuthorization()
    }

    private func openNotificationSettings() {
        controller.openNotificationSettings()
    }
}
