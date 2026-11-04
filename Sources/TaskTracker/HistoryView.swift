import SwiftUI
import AppKit

struct HistoryView: View {
    @EnvironmentObject var store: TaskStore
    @State private var day = Date()
    @State private var tasks: [TaskRecord] = []

    private var total: TimeInterval { tasks.reduce(0) { $0 + $1.duration } }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                DatePicker("", selection: $day, in: ...Date(), displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.field)
                Button { shift(1) } label: { Image(systemName: "chevron.right") }
                    .disabled(Calendar.current.isDateInToday(day))
                Button("Today") { day = Date() }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("\(tasks.count) tasks").font(.headline)
                    Text(Fmt.shortDuration(total) + " total").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding()

            Divider()

            if tasks.isEmpty {
                ContentUnavailableView("No tasks", systemImage: "tray",
                                       description: Text("Nothing was completed on this day."))
            } else {
                List {
                    ForEach(tasks) { task in
                        TaskRow(task: task)
                            .contextMenu {
                                Button("Copy Title") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(task.title, forType: .string)
                                }
                                Button("Delete", role: .destructive) {
                                    store.delete(task)
                                    reload()
                                }
                            }
                    }
                }
            }

            Divider()
            HStack {
                Spacer()
                Button("Copy Day as Text") { copyDay() }
                    .disabled(tasks.isEmpty)
            }
            .padding(10)
        }
        .frame(minWidth: 420, minHeight: 400)
        .onAppear(perform: reload)
        .onChange(of: day) { reload() }
        .onChange(of: store.todayTasks) { reload() }
    }

    private func shift(_ days: Int) {
        if let d = Calendar.current.date(byAdding: .day, value: days, to: day), d <= Date() { day = d }
    }

    private func reload() { tasks = store.tasks(on: day) }

    private func copyDay() {
        let header = DateFormatter.localizedString(from: day, dateStyle: .full, timeStyle: .none)
        let lines = tasks.map { t in
            "- \(Fmt.time.string(from: t.startedAt))–\(Fmt.time.string(from: t.endedAt ?? Date()))  \(t.title) (\(Fmt.shortDuration(t.duration)))"
        }
        let text = ([header] + lines + ["Total: \(Fmt.shortDuration(total))"]).joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
