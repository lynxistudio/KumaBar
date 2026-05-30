import SwiftUI

struct AddWebsiteView: View {
    @EnvironmentObject private var model: AppModel
    @State private var draft: AddWebsiteDraft
    @State private var errorMessage: String?
    @State private var successMessage: String?
    let onClose: () -> Void

    init(draft: AddWebsiteDraft, onClose: @escaping () -> Void) {
        _draft = State(initialValue: draft)
        self.onClose = onClose
    }

    var body: some View {
        Form {
            Section("Website") {
                TextField("Name", text: $draft.name, prompt: Text("Optional"))
                TextField("URL", text: $draft.url, prompt: Text("https://example.com"))
                Picker("Check Every", selection: $draft.interval) {
                    Text("60 seconds").tag(60)
                    Text("120 seconds").tag(120)
                    Text("300 seconds").tag(300)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if let successMessage {
                Text(successMessage)
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            HStack {
                Spacer()
                Button("Close") {
                    onClose()
                }
                Button("Add Website") {
                    Task {
                        errorMessage = nil
                        successMessage = nil
                        do {
                            try await model.addWebsite(draft)
                            RuntimeLog.write("add website success displayed")
                            successMessage = "Website added. Monitor status will update automatically."
                            draft = model.makeAddWebsiteDraft()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.isAddingWebsite)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 470, height: 340)
    }
}
