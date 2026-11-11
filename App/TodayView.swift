import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: PlannerStore
    @AppStorage("dismissedWelcome") private var dismissedWelcome = false
    @State private var editingTask: PlannerTask?
    @State private var addingTask = false
    let openFocus: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let today = context.date
            let tasks = store.tasks(on: today)
            let completed = tasks.filter(\.isComplete).count
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    PageHeading(
                        eyebrow: today.formatted(.dateTime.weekday(.wide).month(.wide).day()),
                        title: greeting(at: today),
                        subtitle: "A little intention. A brighter day."
                    )

                    VStack(alignment: .leading, spacing: 22) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 9) {
                                Text("MAKE SPACE FOR WHAT MATTERS")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .tracking(1.5).foregroundStyle(.white.opacity(0.65))
                                Text("Small steps.\nReal progress.")
                                    .font(.system(size: 29, weight: .medium, design: .serif))
                                    .foregroundStyle(.white)
                            }
                            Spacer(minLength: 8)
                            ZStack {
                                ProgressRing(progress: tasks.isEmpty ? 0 : Double(completed) / Double(tasks.count), color: Color(hex: 0xEBD6A2), lineWidth: 5)
                                VStack(spacing: 3) {
                                    Text("\(completed)/\(tasks.count)").font(.system(size: 22, weight: .medium, design: .rounded))
                                    Text("TASKS").font(.system(size: 8, weight: .medium)).tracking(1)
                                }
                                .foregroundStyle(.white)
                            }
                            .frame(width: 75, height: 75).padding(.top, 12)
                        }
                        HStack {
                            Label("Your pace is the right pace", systemImage: "sparkle")
                                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.8))
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right").foregroundStyle(Color(hex: 0xEBD6A2))
                        }
                    }
                    .padding(23)
                    .background(Palette.teal, in: RoundedRectangle(cornerRadius: 25))

                    HStack(spacing: 10) {
                        stat(value: "\(tasks.filter { !$0.isComplete }.count)", label: "To do today", symbol: "checklist", color: Palette.accent)
                        stat(value: "\(store.focusMinutes(on: today))m", label: "In the zone", symbol: "timer", color: Palette.lavender)
                        stat(value: "\(store.habits.filter { $0.isComplete(on: today) }.count)/\(store.habits.count)", label: "Daily habits", symbol: "leaf", color: Palette.teal)
                    }

                    if !dismissedWelcome {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "hand.wave").foregroundStyle(Palette.accent)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Your fresh start is here.").font(.system(size: 13, weight: .semibold))
                                Text("We added example tasks and habits to explore. Make them yours, or start empty in Settings.")
                                    .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                            }
                            Button { dismissedWelcome = true } label: {
                                Image(systemName: "xmark").font(.system(size: 12)).padding(8)
                            }
                            .tint(Palette.secondary).accessibilityLabel("Dismiss welcome")
                        }
                        .padding(16).background(Color(hex: 0xF0EDE3), in: RoundedRectangle(cornerRadius: 18))
                    }

                    VStack(spacing: 12) {
                        HStack {
                            SectionHeading(title: "Today's priorities", subtitle: "\(completed) of \(tasks.count) done")
                            Button { addingTask = true } label: {
                                Image(systemName: "plus").font(.system(size: 16, weight: .semibold))
                                    .frame(width: 34, height: 34).background(Palette.accent.opacity(0.09), in: Circle())
                            }.accessibilityLabel("Add task")
                        }
                        if tasks.isEmpty {
                            EmptyCard(symbol: "sun.horizon", title: "A little breathing room", message: "Add a task to give your day some direction.")
                        } else {
                            Card(padding: 12) {
                                VStack(spacing: 0) {
                                    ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                                        TaskRow(task: task) { editingTask = task }
                                        if index < tasks.count - 1 { Divider().overlay(Palette.line).padding(.leading, 49) }
                                    }
                                }
                            }
                        }
                    }

                    if !store.habits.isEmpty {
                        VStack(spacing: 14) {
                            SectionHeading(title: "Little rituals", subtitle: "Show up for yourself")
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 10)], spacing: 10) {
                                ForEach(store.habits) { HabitTile(habit: $0, date: today) }
                            }
                        }
                    }

                    Button(action: openFocus) {
                        HStack(spacing: 15) {
                            Image(systemName: "headphones").font(.system(size: 24)).foregroundStyle(Palette.lavender)
                                .frame(width: 48, height: 48).background(Palette.lavender.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                            VStack(alignment: .leading, spacing: 5) {
                                Text("One thing at a time.").font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                                Text("Find your flow with a focus session").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.right").foregroundStyle(Palette.ink)
                        }
                        .padding(16).background(.white, in: RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Text("LESS RUSH. MORE MEANING.")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(2).foregroundStyle(Palette.secondary.opacity(0.7))
                        .frame(maxWidth: .infinity).padding(.vertical, 5)
                }
                .padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 25)
            }
            .background(Palette.background)
            .toolbarBackground(Palette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .sheet(isPresented: $addingTask) { TaskEditor(task: PlannerTask(title: "")) }
        .sheet(item: $editingTask) { TaskEditor(task: $0, isExisting: true) }
    }

    private func greeting(at date: Date) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12: return "Good morning."
        case 12..<17: return "Good afternoon."
        default: return "Good evening."
        }
    }

    private func stat(value: String, label: String, symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol).font(.system(size: 16)).foregroundStyle(color)
            Text(value).font(.system(size: 23, weight: .semibold, design: .rounded)).foregroundStyle(Palette.ink)
            Text(label).font(.system(size: 10)).foregroundStyle(Palette.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(15)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.line, lineWidth: 1))
    }
}
