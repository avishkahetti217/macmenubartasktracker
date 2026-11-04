import SwiftUI
import AppKit

struct MenuContentView: View {
    @EnvironmentObject var store: TaskStore
    @Environment(\.openWindow) private var openWindow
    @State private var newTitle = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            currentSection

            Divider()

            todaySection

            Divider()

            CalendarToggle(calendar: store.calendar)
            LaunchAtLoginToggle()

            Divider()

            HStack {
                Button {
                    openWindow(id: "history")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("View History…", systemImage: "calendar")
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .frame(width: 340)
        .onAppear { fieldFocused = store.activeTask == nil }
    }

    // MARK: Current task

    @ViewBuilder
    private var currentSection: some View {
        if let task = store.activeTask {
            VStack(alignment: .leading, spacing: 8) {
                Text("WORKING ON").font(.caption).foregroundStyle(.secondary)
                Text(task.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Image(systemName: "clock")
                    Text(Fmt.duration(store.now.timeIntervalSince(task.startedAt)))
                        .monospacedDigit()
                    Text("since \(Fmt.time.string(from: task.startedAt))")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .font(.subheadline)

                HStack {
                    Button(role: .destructive) {
                        store.discardActive()
                    } label: {
                        Text("Discard")
                    }
                    .help("Cancel this task without saving it")
                    Spacer()
                    Button {
                        store.end()
                        fieldFocused = true
                    } label: {
                        Label("End Task", systemImage: "stop.fill")
                    }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("WHAT ARE YOU WORKING ON?").font(.caption).foregroundStyle(.secondary)
                HStack {
                    TextField("e.g. Review pull request", text: $newTitle)
                        .textFieldStyle(.roundedBorder)
                        .focused($fieldFocused)
                        .onSubmit(startTask)
                    Button(action: startTask) {
                        Label("Start", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func startTask() {
        store.start(newTitle)
        newTitle = ""
    }

    // MARK: Today

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("DONE TODAY").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if !store.todayTasks.isEmpty {
                    Text("\(store.todayTasks.count) tasks · \(Fmt.shortDuration(store.todayTasks.reduce(0) { $0 + $1.duration }))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if store.todayTasks.isEmpty {
                Text("No completed tasks yet.")
                    .font(.callout).foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(store.todayTasks.reversed()) { task in
                            TaskRow(task: task)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
    }
}

struct CalendarToggle: View {
    @EnvironmentObject var store: TaskStore
    @ObservedObject var calendar: CalendarService

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Include Apple Calendar events", isOn: $store.includeCalendar)
                .toggleStyle(.checkbox)
            if store.includeCalendar && calendar.access == .denied {
                HStack(spacing: 4) {
                    Text("Calendar access is off.")
                        .foregroundStyle(.secondary)
                    Button("Open Settings") { calendar.openPrivacySettings() }
                        .buttonStyle(.link)
                }
                .font(.caption)
            }
        }
    }
}

struct TaskRow: View {
    let task: TaskRecord

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    if task.isCalendarEvent {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                            .help("From Apple Calendar")
                    }
                    Text(task.title).lineLimit(2)
                }
                if let end = task.endedAt {
                    Text("\(Fmt.time.string(from: task.startedAt)) – \(Fmt.time.string(from: end))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(Fmt.shortDuration(task.duration))
                .font(.callout).monospacedDigit().foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
