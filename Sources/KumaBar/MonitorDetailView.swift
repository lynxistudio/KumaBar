import SwiftUI

struct MonitorDetailView: View {
    @EnvironmentObject private var model: AppModel
    @State private var managementURLDraft = ""
    @State private var managementMessage: String?
    @State private var managementError: String?

    let monitor: MonitorSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                managementLinkRow
            }
            Divider()
            managementEditor
            if let managementError {
                Text(managementError)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }
            if let managementMessage {
                Text(managementMessage)
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
            }
        }
        .font(.system(size: 12))
        .padding(12)
        .frame(width: 340)
        .onAppear {
            managementURLDraft = model.settings.managementURL(for: monitor) ?? ""
        }
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

    @ViewBuilder
    private var managementLinkRow: some View {
        GridRow {
            Text("Management")
                .foregroundStyle(.secondary)
            if let managementURL = model.settings.managementURL(for: monitor),
               let url = URL(string: managementURL) {
                Link(managementURL, destination: url)
                    .lineLimit(2)
            } else {
                Text("Not set")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var managementEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Management URL")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField("https://admin.example.com", text: $managementURLDraft)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
            HStack {
                Button("Clear") {
                    saveManagementURL("")
                }
                .disabled(managementURLDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
                Button("Save") {
                    saveManagementURL(managementURLDraft)
                }
            }
            .font(.system(size: 11))
        }
    }

    private func saveManagementURL(_ value: String) {
        do {
            try model.settings.saveManagementURL(value, for: monitor)
            managementURLDraft = model.settings.managementURL(for: monitor) ?? ""
            managementError = nil
            managementMessage = managementURLDraft.isEmpty ? "Management URL cleared." : "Management URL saved."
        } catch {
            managementMessage = nil
            managementError = error.localizedDescription
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
