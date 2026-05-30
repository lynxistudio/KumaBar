import SwiftUI

struct MonitorDetailView: View {
    let monitor: MonitorSnapshot

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 7) {
            detailRow("Monitor", monitor.name)
            detailRow("Status", monitor.state.label)
            detailRow("Response", responseTime)
            detailRow("Last Check", monitor.lastCheckTime.formatted(date: .abbreviated, time: .standard))
            if let days = monitor.sslDaysRemaining {
                detailRow("SSL Expiration", "\(Int(days.rounded(.down))) days remaining")
            }
            if let target = monitor.target, !target.isEmpty {
                targetRow(target)
            }
        }
        .font(.system(size: 12))
        .padding(12)
        .frame(width: 300)
    }

    @ViewBuilder
    private func targetRow(_ target: String) -> some View {
        GridRow {
            Text("Target")
                .foregroundStyle(.secondary)
            if let url = URL(string: target), url.scheme != nil {
                Link(target, destination: url)
                    .lineLimit(2)
            } else {
                Text(target)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
        }
    }

    private var responseTime: String {
        guard let response = monitor.responseTimeMilliseconds else { return "Unavailable" }
        return "\(Int(response.rounded())) ms"
    }

    @ViewBuilder
    private func detailRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .lineLimit(2)
                .textSelection(.enabled)
        }
    }
}
