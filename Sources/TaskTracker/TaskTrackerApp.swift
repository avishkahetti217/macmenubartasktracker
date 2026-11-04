import SwiftUI
import AppKit

@main
struct TaskTrackerApp: App {
    @StateObject private var store = TaskStore()

    init() {
        // Menu-bar only: no Dock icon (also set via LSUIElement in Info.plist).
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(store)
        } label: {
            MenuBarLabel()
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)

        Window("Task History", id: "history") {
            HistoryView()
                .environmentObject(store)
        }
        .defaultSize(width: 480, height: 560)
    }
}

struct MenuBarLabel: View {
    @EnvironmentObject var store: TaskStore

    var body: some View {
        // Icon only; it switches to an hourglass while a task is running.
        Image(systemName: store.activeTask == nil ? "checklist" : "hourglass")
    }
}
