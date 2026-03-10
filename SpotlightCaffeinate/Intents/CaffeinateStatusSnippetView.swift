import SwiftUI

struct CaffeinateStatusSnippetView: View {
    let snapshot: CaffeinateSnapshot
    let title: String
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: snapshot.menuBarSymbolName(at: now))
                .font(.headline)

            Text(snapshot.statusLine(at: now))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if snapshot.isRunning(at: now) {
                if let startedAt = snapshot.startedAt {
                    detailRow(label: "Started", value: startedFormatter.string(from: startedAt))
                }

                if let minutesRequested = snapshot.minutesRequested {
                    detailRow(label: "Duration", value: "\(minutesRequested) minute\(minutesRequested == 1 ? "" : "s")")
                }
            }
        }
        .frame(minWidth: 260, alignment: .leading)
        .padding(14)
    }

    @ViewBuilder
    private func detailRow(label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
        }
        .font(.caption)
    }

    private var startedFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }
}
