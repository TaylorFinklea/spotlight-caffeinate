import SwiftUI

struct CaffeinateStatusSnippetView: View {
    let snapshot: CaffeinateSnapshot
    let title: String
    let now: Date

    var body: some View {
        let isRunning = snapshot.isRunning(at: now)
        let remainingFraction = CGFloat(snapshot.remainingFraction(at: now))

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                BoltIconView(fillFraction: remainingFraction, size: 18)

                Text(title)
                    .font(.headline)
            }

            Text(snapshot.statusLine(at: now))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if isRunning {
                if let startedAt = snapshot.startedAt {
                    detailRow(label: "Started", value: timeFormatter.string(from: startedAt))
                }

                if let endsAt = snapshot.endsAt {
                    detailRow(label: "Ending", value: timeFormatter.string(from: endsAt))
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

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }
}
