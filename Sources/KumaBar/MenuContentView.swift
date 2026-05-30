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
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                if model.filteredMonitors.isEmpty {
                    Text(model.errorMessage ?? "No monitors found")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(10)
                } else {
                    monitorSection("Problems", monitors: model.failedMonitors)
                    monitorSection("Other", monitors: model.otherMonitors)
                    monitorSection("Healthy", monitors: model.healthyMonitors)
                }
            }
        }
    }

    @ViewBuilder
    private func monitorSection(_ title: String, monitors: [MonitorSnapshot]) -> some View {
        if !monitors.isEmpty {
            Section {
                ForEach(monitors) { monitor in
                    MonitorRow(monitor: monitor) {
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
            HStack(spacing: 12) {
                Button {
                    Task { await model.refresh() }
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
}

private struct MonitorRow: View {
    let monitor: MonitorSnapshot
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
        if monitor.state == .down {
            return monitor.detailText
        }
        if let ping = monitor.responseTimeMilliseconds {
            return "\(Int(ping.rounded())) ms"
        }
        return monitor.state.label
    }

    private var statusColor: Color {
        switch monitor.state {
        case .up: .green
        case .down: .red
        case .pending: .orange
        case .maintenance: .blue
        case .unknown: .gray
        }
    }
}
