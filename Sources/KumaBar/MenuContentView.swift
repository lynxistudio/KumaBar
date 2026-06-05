import AppKit
import SwiftUI

struct MenuContentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel
    @State private var selectedMonitor: MonitorSnapshot?

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            monitorList
            Divider()
            footer
        }
        .frame(width: 360, height: 500)
        .popover(item: $selectedMonitor, arrowEdge: .trailing) { monitor in
            MonitorDetailView(monitor: monitor)
                .environmentObject(model)
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search monitors", text: $model.searchText)
                .textFieldStyle(.plain)
            if !model.searchText.isEmpty {
                Button {
                    model.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 30)
    }

    private var monitorList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if model.filteredMonitors.isEmpty {
                    Text(model.errorMessage ?? "No monitors found")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(10)
                } else {
                    monitorSection("Problems", monitors: model.failedMonitors, kind: .problems)
                    monitorSection("Other", monitors: model.otherMonitors, kind: .other)
                    monitorSection("Healthy", monitors: model.healthyMonitors, kind: .healthy)
                }
            }
        }
    }

    @ViewBuilder
    private func monitorSection(
        _ title: String,
        monitors: [MonitorSnapshot],
        kind: MonitorSectionKind
    ) -> some View {
        if !monitors.isEmpty {
            Section {
                ForEach(monitors) { monitor in
                    MonitorRow(monitor: monitor, sectionKind: kind) {
                        selectedMonitor = monitor
                    }
                }
            } header: {
                HStack {
                    Text("\(title) (\(monitors.count))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(.bar)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            if let error = model.errorMessage {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            Text(lastUpdatedText)
                .font(.system(size: 9))
                .foregroundStyle(model.isDataStale ? .orange : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
            HStack(spacing: 12) {
                Button {
                    model.refreshNow(reason: "manual")
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(model.isRefreshing ? 360 : 0))
                        .animation(
                            model.isRefreshing
                                ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                                : .default,
                            value: model.isRefreshing
                        )
                }
                .buttonStyle(.plain)
                .help("Refresh")

                Button {
                    dismiss()
                    Task { @MainActor in
                        await Task.yield()
                        model.openAddWebsite()
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .help("Add Website")

                Button("Open Dashboard") {
                    model.openDashboard()
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    dismiss()
                    Task { @MainActor in
                        await Task.yield()
                        model.openPreferences()
                    }
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .help("Settings")

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.plain)
                .help("Quit KumaBar")
            }
            .padding(.horizontal, 9)
            .frame(height: 30)
        }
    }

    private var lastUpdatedText: String {
        guard let lastRefreshTime = model.lastRefreshTime else {
            return "Waiting for first update"
        }
        let formatted = lastRefreshTime.formatted(date: .omitted, time: .standard)
        return model.isDataStale ? "Data is stale - last updated \(formatted)" : "Updated \(formatted)"
    }
}

private enum MonitorSectionKind {
    case problems
    case other
    case healthy
}

private struct MonitorRow: View {
    let monitor: MonitorSnapshot
    let sectionKind: MonitorSectionKind
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                Text(monitor.name)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(trailingText)
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .frame(height: 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var trailingText: String {
        if isDisplayedAsProblem {
            return monitor.state.isProblem ? monitor.detailText : "Problem"
        }
        if let ping = monitor.responseTimeMilliseconds {
            return "\(Int(ping.rounded())) ms"
        }
        return monitor.state.label
    }

    private var statusColor: Color {
        if isDisplayedAsProblem {
            return .red
        }
        switch monitor.state {
        case .up:
            return .green
        case .down, .unknown:
            return .red
        case .pending:
            return .orange
        case .maintenance:
            return .blue
        }
    }

    private var isDisplayedAsProblem: Bool {
        sectionKind == .problems || monitor.state.isProblem
    }
}
