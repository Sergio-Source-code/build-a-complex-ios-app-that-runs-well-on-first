import SwiftUI

struct PlannerView: View {
    @EnvironmentObject private var store: PlannerStore
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var search = ""
    @State private var project: Project?
    @State private var showCompleted = true
    @State private var addingTask = false
    @State private var editingTask: PlannerTask?
    @State private var addingHabit = false

    private var displayedTasks: [PlannerTask] {
        let source = search.isEmpty ? store.tasks(on: selectedDate) : store.tasks.sorted { $0.dueDate < $1.dueDate }
        return source.filter { task in
            (project == nil || task.project == project) &&
            (showCompleted || !task.isComplete) &&
            (search.isEmpty || task.title.localizedCaseInsensitiveContains(search) || task.notes.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(eyebrow: "A little more intentional", title: "Your days, designed.", subtitle: "Give your ideas a place to become plans.")
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(Palette.secondary)
                    TextField("Search all tasks", text: $search).font(.subheadline)
                    if !search.isEmpty {
                        Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .tint(Palette.secondary).accessibilityLabel("Clear search")
                    }
                }
                .padding(15).background(.white, in: RoundedRectangle(cornerRadius: 15))

                if search.isEmpty {
                    Card {
                        VStack(spacing: 16) {
                            HStack {
                                Text(selectedDate.formatted(.dateTime.month(.wide).year())).font(.headline)
                                Spacer()
                                Button("Today") { selectedDate = Calendar.current.startOfDay(for: Date()) }.font(.caption.weight(.semibold))
                            }
                            DatePicker("Choose a day", selection: $selectedDate, displayedComponents: .date)
                                .datePickerStyle(.compact).font(.subheadline)
                            HStack(spacing: 3) {
                                ForEach(weekDates, id: \.self) { date in
                                    dayButton(date)
                                }
                            }
                        }
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterPill("All", color: Palette.ink, selected: project == nil) { project = nil }
                        ForEach(Project.allCases) { item in
                            filterPill(item.rawValue, color: item.color, selected: project == item) { project = item }
                        }
                    }
                }

                VStack(spacing: 12) {
                    HStack {
                        SectionHeading(title: search.isEmpty ? "The plan" : "Search results", subtitle: "\(displayedTasks.count) tasks")
                        Menu {
                            Toggle("Show completed", isOn: $showCompleted)
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease").frame(width: 32, height: 32)
                        }.accessibilityLabel("Task display options")
                    }
                    if displayedTasks.isEmpty {
                        EmptyCard(symbol: "tray", title: search.isEmpty ? "A fresh page" : "Nothing found", message: search.isEmpty ? "Add a task, or try another day or filter." : "Try a different title or a word from your notes.")
                    } else {
                        Card(padding: 12) {
                            VStack(spacing: 0) {
                                ForEach(displayedTasks) { task in
                                    VStack(alignment: .leading, spacing: 0) {
                                        if !search.isEmpty {
                                            Text(task.dueDate.formatted(date: .abbreviated, time: .omitted))
                                                .font(.caption2).foregroundStyle(Palette.secondary).padding(.leading, 49).padding(.top, 8)
                                        }
                                        TaskRow(task: task) { editingTask = task }
                                        if task.id != displayedTasks.last?.id { Divider().padding(.leading, 49) }
                                    }
                                }
                            }
                        }
                    }
                    PrimaryButton(title: "Add a task", symbol: "plus") { addingTask = true }
                }

                VStack(spacing: 14) {
                    HStack {
                        SectionHeading(title: "Your daily rituals")
                        Button { addingHabit = true } label: { Image(systemName: "plus").frame(width: 36, height: 36) }
                            .accessibilityLabel("Add habit")
                    }
                    Text("Habits repeat daily. Tap to check off today; touch and hold to remove.")
                        .font(.caption).foregroundStyle(Palette.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 12) {
                            ForEach(store.habits) { habit in
                                HabitTile(habit: habit, date: context.date)
                                    .contextMenu {
                                        Button("Delete habit", role: .destructive) { store.deleteHabit(habit) }
                                    }
                            }
                        }
                    }
                    if store.habits.isEmpty {
                        EmptyCard(symbol: "leaf", title: "Start small", message: "Add one simple habit you’d like to practice each day.")
                    }
                }
            }
            .padding(22).padding(.bottom, 12)
        }
        .background(Palette.background)
        .sheet(isPresented: $addingTask) { TaskEditor(task: PlannerTask(title: "", dueDate: selectedDate)) }
        .sheet(item: $editingTask) { TaskEditor(task: $0, isExisting: true) }
        .sheet(isPresented: $addingHabit) { HabitEditor() }
    }

    private var weekDates: [Date] {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private func dayButton(_ date: Date) -> some View {
        let selected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        return Button { selectedDate = date } label: {
            VStack(spacing: 10) {
                Text(date.formatted(.dateTime.weekday(.narrow))).font(.system(size: 10, weight: .medium))
                Text(date.formatted(.dateTime.day())).font(.system(size: 16, weight: .semibold, design: .rounded))
                Circle().fill(store.tasks(on: date).isEmpty ? .clear : (selected ? .white : Palette.accent)).frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .foregroundStyle(selected ? .white : Palette.ink)
            .background(selected ? Palette.accent : .clear, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func filterPill(_ title: String, color: Color, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 12, weight: .semibold)).padding(.horizontal, 18).padding(.vertical, 10)
                .foregroundStyle(selected ? .white : color)
                .background(selected ? color : color.opacity(0.08), in: Capsule())
        }.buttonStyle(.plain)
    }
}

struct TaskEditor: View {
    @EnvironmentObject private var store: PlannerStore
    @Environment(\.dismiss) private var dismiss
    @State var task: PlannerTask
    var isExisting = false
    @State private var confirmDelete = false

    private var validTitle: String { task.title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section("The important thing") {
                    TextField("What would you like to do?", text: $task.title, axis: .vertical)
                    TextField("Notes, ideas, a first step…", text: $task.notes, axis: .vertical).lineLimit(3...6)
                }
                Section("Make a little space") {
                    DatePicker("Day", selection: $task.dueDate, displayedComponents: .date)
                    Picker("Area", selection: $task.project) {
                        ForEach(Project.allCases) { Label($0.rawValue, systemImage: $0.symbol).tag($0) }
                    }
                    Picker("Priority", selection: $task.priority) {
                        ForEach(Priority.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Stepper("Estimate: \(task.estimatedMinutes) minutes", value: $task.estimatedMinutes, in: 5...240, step: 5)
                }
                if isExisting {
                    Section {
                        Toggle("Completed", isOn: Binding(
                            get: { task.isComplete },
                            set: { task.completedAt = $0 ? Date() : nil }
                        ))
                        Button("Delete task", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .scrollContentBackground(.hidden).background(Palette.background)
            .navigationTitle(isExisting ? "Edit task" : "A new intention")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        task.title = validTitle
                        store.saveTask(task)
                        dismiss()
                    }.fontWeight(.semibold).disabled(validTitle.isEmpty)
                }
            }
            .confirmationDialog("Delete this task?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete task", role: .destructive) { store.deleteTask(task); dismiss() }
            }
        }
        .tint(Palette.accent)
    }
}

struct HabitEditor: View {
    @EnvironmentObject private var store: PlannerStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var target = ""
    @State private var symbol = "leaf.fill"
    private let symbols = ["leaf.fill", "drop.fill", "figure.walk", "book.closed.fill", "heart.fill", "sun.max.fill", "pencil", "bed.double.fill"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Small is a good place to start") {
                    TextField("Habit name", text: $title)
                    TextField("Daily goal (e.g. 10 pages)", text: $target)
                }
                Section("Choose an icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 55))], spacing: 12) {
                        ForEach(symbols, id: \.self) { item in
                            Button { symbol = item } label: {
                                Image(systemName: item).font(.title3).frame(width: 50, height: 50)
                                    .foregroundStyle(symbol == item ? .white : Palette.teal)
                                    .background(symbol == item ? Palette.teal : Palette.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.plain)
                            .accessibilityLabel(item.replacingOccurrences(of: ".fill", with: "").replacingOccurrences(of: ".", with: " "))
                            .accessibilityAddTraits(symbol == item ? .isSelected : [])
                        }
                    }.padding(.vertical, 8)
                }
            }
            .scrollContentBackground(.hidden).background(Palette.background)
            .navigationTitle("A new daily ritual").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.addHabit(title: title.trimmingCharacters(in: .whitespacesAndNewlines), target: target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "A little every day" : target, symbol: symbol)
                        dismiss()
                    }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }.tint(Palette.accent)
    }
}
