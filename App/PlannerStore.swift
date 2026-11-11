import Foundation
import SwiftUI

struct PlannerTask: Identifiable, Codable {
    var id = UUID()
    var title: String
    var notes = ""
    var project: Project = .personal
    var priority: Priority = .medium
    var dueDate = Date()
    var estimatedMinutes = 25
    var completedAt: Date?
    var isComplete: Bool { completedAt != nil }
}

enum Project: String, Codable, CaseIterable, Identifiable {
    case work = "Work", personal = "Personal", wellbeing = "Wellbeing"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .work: return "briefcase.fill"
        case .personal: return "sparkles"
        case .wellbeing: return "leaf.fill"
        }
    }
    var color: Color {
        switch self {
        case .work: return Palette.lavender
        case .personal: return Palette.accent
        case .wellbeing: return Palette.teal
        }
    }
}

enum Priority: String, Codable, CaseIterable, Identifiable {
    case low = "Low", medium = "Medium", high = "High"
    var id: String { rawValue }
    var rank: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }
}

struct Habit: Identifiable, Codable {
    var id = UUID()
    var title: String
    var symbol: String
    var target: String
    var completedDays: Set<String> = []

    func isComplete(on date: Date) -> Bool {
        completedDays.contains(Self.dayKey(date))
    }

    func streak(on date: Date) -> Int {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: date)
        if !isComplete(on: day) {
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        var count = 0
        while isComplete(on: day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    static func dayKey(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}

struct FocusSession: Identifiable, Codable {
    var id = UUID()
    var date = Date()
    var minutes: Int
    var taskTitle: String?
}

struct FocusState: Codable {
    var durationMinutes = 25
    var remainingSeconds: TimeInterval = 1500
    var endDate: Date?
    var hasStarted = false
    var taskID: UUID?
}

struct PlannerSnapshot: Codable {
    var tasks: [PlannerTask]
    var habits: [Habit]
    var sessions: [FocusSession]
    var focus = FocusState()
}

@MainActor
final class PlannerStore: ObservableObject {
    @Published private(set) var tasks: [PlannerTask] = []
    @Published private(set) var habits: [Habit] = []
    @Published private(set) var sessions: [FocusSession] = []
    @Published private(set) var focus = FocusState()
    @Published var storageMessage: String?
    @Published var completedFocusMinutes: Int?

    private let storageURL: URL
    private var canSave = true

    init(storageURL: URL? = nil) {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.storageURL = storageURL ?? directory.appendingPathComponent("daylight-data.json")
        let storageURL = self.storageURL
        if FileManager.default.fileExists(atPath: storageURL.path) {
            do {
                let data = try Data(contentsOf: storageURL)
                let snapshot = try JSONDecoder().decode(PlannerSnapshot.self, from: data)
                tasks = snapshot.tasks
                habits = snapshot.habits
                sessions = snapshot.sessions
                focus = snapshot.focus
            } catch {
                // Preserve the original file rather than overwrite unreadable user data.
                canSave = false
                storageMessage = "Your saved planner couldn’t be opened. The original file has been preserved. Restart the app to retry, or reset local data in Settings."
            }
        } else {
            seedExamples()
            save()
        }
        reconcileFocus()
    }

    func saveTask(_ task: PlannerTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        } else {
            tasks.append(task)
        }
        save()
    }

    func toggleTask(_ task: PlannerTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].completedAt = tasks[index].isComplete ? nil : Date()
        save()
    }

    func deleteTask(_ task: PlannerTask) {
        tasks.removeAll { $0.id == task.id }
        if focus.taskID == task.id { focus.taskID = nil }
        save()
    }

    func addHabit(title: String, target: String, symbol: String) {
        habits.append(Habit(title: title, symbol: symbol, target: target))
        save()
    }

    func deleteHabit(_ habit: Habit) {
        habits.removeAll { $0.id == habit.id }
        save()
    }

    func toggleHabit(_ habit: Habit, on date: Date = Date()) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        let key = Habit.dayKey(date)
        if habits[index].completedDays.contains(key) {
            habits[index].completedDays.remove(key)
        } else {
            habits[index].completedDays.insert(key)
        }
        save()
    }

    func tasks(on date: Date) -> [PlannerTask] {
        tasks.filter { Calendar.current.isDate($0.dueDate, inSameDayAs: date) }
            .sorted {
                if $0.isComplete != $1.isComplete { return !$0.isComplete }
                if $0.priority.rank != $1.priority.rank { return $0.priority.rank > $1.priority.rank }
                return $0.dueDate < $1.dueDate
            }
    }

    func focusMinutes(on date: Date) -> Int {
        sessions.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .reduce(0) { $0 + $1.minutes }
    }

    func setFocusDuration(_ minutes: Int) {
        guard !focus.hasStarted else { return }
        focus.durationMinutes = minutes
        focus.remainingSeconds = TimeInterval(minutes * 60)
        save()
    }

    func selectFocusTask(_ id: UUID?) {
        focus.taskID = id
        save()
    }

    func remainingFocus(at date: Date = Date()) -> TimeInterval {
        if let endDate = focus.endDate { return max(0, endDate.timeIntervalSince(date)) }
        return max(0, focus.remainingSeconds)
    }

    func startFocus() {
        guard focus.endDate == nil else { return }
        focus.hasStarted = true
        focus.endDate = Date().addingTimeInterval(focus.remainingSeconds)
        save()
    }

    func pauseFocus() {
        reconcileFocus()
        guard focus.endDate != nil else { return }
        focus.remainingSeconds = remainingFocus()
        focus.endDate = nil
        save()
    }

    func resetFocus() {
        focus.endDate = nil
        focus.hasStarted = false
        focus.remainingSeconds = TimeInterval(focus.durationMinutes * 60)
        save()
    }

    func reconcileFocus() {
        guard let end = focus.endDate, end <= Date() else { return }
        let title = tasks.first { $0.id == focus.taskID }?.title
        sessions.append(FocusSession(date: end, minutes: focus.durationMinutes, taskTitle: title))
        completedFocusMinutes = focus.durationMinutes
        resetFocus()
    }

    func resetAll(includeExamples: Bool) {
        tasks = []
        habits = []
        sessions = []
        focus = FocusState()
        completedFocusMinutes = nil
        canSave = true
        if includeExamples { seedExamples() }
        save()
    }

    private func save() {
        guard canSave else { return }
        do {
            try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let snapshot = PlannerSnapshot(tasks: tasks, habits: habits, sessions: sessions, focus: focus)
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            storageMessage = "Your latest changes are in memory but couldn’t be saved to this device. Please free up storage and try again."
        }
    }

    private func seedExamples() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: today) ?? today
        }
        tasks = [
            PlannerTask(title: "Make room for your best work", notes: "Choose one meaningful thing to move forward today. Break it into a small first step.", project: .work, priority: .high, dueDate: today, estimatedMinutes: 45),
            PlannerTask(title: "Get outside for a little while", notes: "A short walk, a clear mind. Leave your phone in your pocket.", project: .wellbeing, dueDate: today, estimatedMinutes: 20),
            PlannerTask(title: "Plan something to look forward to", project: .personal, priority: .low, dueDate: today, estimatedMinutes: 15),
            PlannerTask(title: "Set an intention for the day", project: .personal, dueDate: today, estimatedMinutes: 5, completedAt: Date()),
            PlannerTask(title: "Map out the next big idea", project: .work, priority: .high, dueDate: day(1), estimatedMinutes: 50),
            PlannerTask(title: "Check in with a friend", project: .personal, dueDate: day(1), estimatedMinutes: 15),
            PlannerTask(title: "Make time for a good book", project: .wellbeing, priority: .low, dueDate: day(2), estimatedMinutes: 30)
        ]
        habits = [
            Habit(title: "Stay hydrated", symbol: "drop.fill", target: "Drink 8 glasses"),
            Habit(title: "Move your body", symbol: "figure.walk", target: "20 minutes outside"),
            Habit(title: "Read a little", symbol: "book.closed.fill", target: "10 pages, any book")
        ]
        // Examples are clearly labeled in the UI; historical progress starts empty.
    }
}
