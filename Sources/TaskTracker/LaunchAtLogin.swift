import SwiftUI
import ServiceManagement

/// Registers the app as a Login Item (System Settings → General → Login Items).
struct LaunchAtLoginToggle: View {
    @State private var enabled = SMAppService.mainApp.status == .enabled
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Open at Login", isOn: Binding(
                get: { enabled },
                set: { set($0) }
            ))
            .toggleStyle(.checkbox)

            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            } else if SMAppService.mainApp.status == .requiresApproval {
                HStack(spacing: 4) {
                    Text("Needs approval in Login Items.").foregroundStyle(.secondary)
                    Button("Open Settings") { SMAppService.openSystemSettingsLoginItems() }
                        .buttonStyle(.link)
                }
                .font(.caption)
            }
        }
        .onAppear { enabled = SMAppService.mainApp.status == .enabled }
    }

    private func set(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            error = nil
        } catch {
            self.error = "Couldn't change Login Item: \(error.localizedDescription)"
        }
        enabled = SMAppService.mainApp.status == .enabled
    }
}
