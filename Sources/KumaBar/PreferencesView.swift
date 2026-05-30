import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var draft = PreferencesDraft()
    @State private var saveMessage: String?
    @State private var managementUsername = ""
    @State private var managementPassword = ""
    @State private var managementLoginMessage: String?
    @State private var isSavingManagementLogin = false

    var body: some View {
        Form {
            Section("Uptime Kuma") {
                TextField("URL", text: $draft.baseURL, prompt: Text("https://status.example.com"))
                Picker("Authentication", selection: $draft.authenticationMode) {
                    ForEach(AuthenticationMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                if draft.authenticationMode == .apiKey {
                    SecureField("API Key", text: $draft.apiKey, prompt: Text("<INSERT_API_KEY_HERE>"))
                } else {
                    TextField("Username", text: $draft.username)
                    SecureField("Password", text: $draft.password)
                }
                if draft.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                    .hasPrefix("http://") {
                    Text("HTTP is supported for self-hosted servers, but HTTPS is recommended when available.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("Behavior") {
                Picker("Refresh Interval", selection: $draft.refreshInterval) {
                    ForEach(RefreshInterval.allCases) { interval in
                        Text(interval.label).tag(interval)
                    }
                }
                Toggle("Launch at Login", isOn: $draft.launchAtLogin)
                Text("Install KumaBar in Applications before enabling Launch at Login.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Notifications", isOn: $draft.notificationsEnabled)
            }

            Section("Management Login") {
                TextField("Username", text: $managementUsername)
                SecureField("Password", text: $managementPassword)
                Text("Required only for adding websites. KumaBar saves a local login token after verification.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let managementLoginMessage {
                    Text(managementLoginMessage)
                        .font(.caption)
                        .foregroundStyle(
                            managementLoginMessage == "Management login saved."
                                ? Color.secondary
                                : Color.red
                        )
                }
                HStack {
                    Spacer()
                    Button("Save Management Login") {
                        isSavingManagementLogin = true
                        Task {
                            do {
                                try await model.saveManagementLogin(
                                    username: managementUsername,
                                    password: managementPassword
                                )
                                managementLoginMessage = "Management login saved."
                            } catch {
                                managementLoginMessage = error.localizedDescription
                            }
                            isSavingManagementLogin = false
                        }
                    }
                    .disabled(isSavingManagementLogin)
                }
            }

            Text("Credentials are stored in this Mac user account's local app settings. KumaBar does not use Keychain, which avoids repeated macOS password prompts.")
                .font(.caption)
                .foregroundStyle(.orange)

            if let saveMessage {
                Text(saveMessage)
                    .font(.caption)
                    .foregroundStyle(messageColor)
            }

            HStack {
                Spacer()
                Button("Save") {
                    do {
                        try model.savePreferences(draft)
                        saveMessage = model.settings.launchAtLoginMessage ?? "Saved."
                        draft = model.settings.draft
                        Task { await model.refresh() }
                    } catch {
                        saveMessage = error.localizedDescription
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 470, height: 560)
        .onAppear {
            draft = model.settings.draft
            if let credentials = try? model.settings.managementCredentials() {
                managementUsername = credentials.username
            }
        }
    }

    private var messageColor: Color {
        guard let saveMessage else { return .secondary }
        return saveMessage == "Saved." || saveMessage.hasPrefix("Settings were saved")
            ? .secondary
            : .red
    }
}
