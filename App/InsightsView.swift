import SwiftUI
import Charts

struct InsightsView: View {
    @EnvironmentObject private var store: PlannerStore
    @State private var weekOffset = 0

    private var weekStart: Date {
        let calendar = Calendar.current
        let current = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return calendar.date(byAdding: .weekOfYear, value: weekOffset, to: current) ?? current
    }
    private var days: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekStart) }
    }
    private var weekEnd: Date {
        Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
    }
    private var completedTasks: [PlannerTask] {
        store.tasks.filter {
            guard let date = $0.completedAt else { return false }
            return date >= weekStart && date < weekEnd
        }
    }
    private var focusMinutes: Int {
        store.sessions.filter { $0.date >= weekStart && $0.date < weekEnd }.reduce(0) { $0 + $1.minutes }
    }
    private var habitCheckIns: Int {
        days.reduce(0) { count, day in count + store.habits.filter { $0.isComplete(on: day) }.count }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(eyebrow: "Look how far you’ve come", title: "Progress, not perfect.", subtitle: "The little things add up. Here’s your proof.")
                HStack {
                    Button { weekOffset -= 1 } label: {
                        Image(systemName: "chevron.left").frame(width: 40, height: 44)
                    }.accessibilityLabel("Previous week")
                    Spacer()
                    VStack(spacing: 4) {
                        Text(weekOffset == 0 ? "This week" : "Your week in review").font(.subheadline.weight(.semibold))
                        Text("\(weekStart.formatted(.dateTime.month(.abbreviated).day())) – \((days.last ?? weekStart).formatted(.dateTime.month(.abbreviated).day()))")
                            .font(.caption).foregroundStyle(Palette.secondary)
                    }
                    Spacer()
                    Button { weekOffset += 1 } label: {
                        Image(systemName: "chevron.right").frame(width: 40, height: 44)
                    }.disabled(weekOffset >= 0).accessibilityLabel("Next week")
                }
                .foregroundStyle(Palette.ink)

                HStack(spacing: 12) {
                    metric("\(completedTasks.count)", title: "Tasks completed", symbol: "checkmark.circle", color: Palette.teal)
                    metric("\(focusMinutes)", title: "Minutes of focus", symbol: "timer", color: Palette.lavender)
                }

                Card {
                    VStack(alignment: .leading, spacing: 24) {
                        SectionHeading(title: "A little, every day", subtitle: "Completed tasks")
                        Chart(days, id: \.self) { day in
                            BarMark(
                                x: .value("Day", day, unit: .day),
                                y: .value("Tasks", completedTasks.filter { task in
                                    guard let completed = task.completedAt else { return false }
                                    return Calendar.current.isDate(completed, inSameDayAs: day)
                                }.count)
                            )
                            .foregroundStyle(Calendar.current.isDateInToday(day) ? Palette.accent : Palette.teal.opacity(0.55))
                            .cornerRadius(5)
                        }
                        .chartXScale(domain: weekStart...weekEnd)
                        .chartYScale(domain: 0...max(4, maximumDailyTasks))
                        .chartXAxis {
                            AxisMarks(values: days) { _ in
                                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading, values: .stride(by: 1)) { _ in
                                AxisGridLine().foregroundStyle(Palette.line)
                                AxisValueLabel()
                            }
                        }
                        .frame(height: 180)
                        Text(completedTasks.isEmpty ? "A fresh week of possibility. Complete a task to see it here." : "Each finished task is a little promise kept to yourself.")
                            .font(.caption).foregroundStyle(Palette.secondary)
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 18) {
                        SectionHeading(title: "Rituals, repeated", subtitle: "\(habitCheckIns) check-ins")
                        if store.habits.isEmpty {
                            Text("Add a daily ritual in Planner to start seeing your consistency.")
                                .font(.subheadline).foregroundStyle(Palette.secondary)
                        }
                        ForEach(store.habits) { habit in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Label(habit.title, systemImage: habit.symbol).font(.system(size: 13, weight: .medium))
                                    Spacer()
                                    Text("\(habit.streak(on: Date())) day streak").font(.system(size: 10)).foregroundStyle(Palette.teal)
                                }
                                HStack(spacing: 8) {
                                    ForEach(days, id: \.self) { day in
                                        VStack(spacing: 7) {
                                            Image(systemName: habit.isComplete(on: day) ? "checkmark" : "minus")
                                                .font(.system(size: 12, weight: .semibold))
                                                .frame(maxWidth: .infinity).frame(height: 32)
                                                .foregroundStyle(habit.isComplete(on: day) ? .white : Palette.secondary.opacity(0.35))
                                                .background(habit.isComplete(on: day) ? Palette.teal : Palette.background, in: RoundedRectangle(cornerRadius: 8))
                                            Text(day.formatted(.dateTime.weekday(.narrow))).font(.system(size: 9)).foregroundStyle(Palette.secondary)
                                        }
                                        .accessibilityElement(children: .ignore)
                                        .accessibilityLabel("\(day.formatted(date: .abbreviated, time: .omitted)): \(habit.isComplete(on: day) ? "completed" : "not completed")")
                                    }
                                }
                            }
                            if habit.id != store.habits.last?.id { Divider() }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeading(title: "Where your energy went")
                    ForEach(Project.allCases) { project in
                        let count = completedTasks.filter { $0.project == project }.count
                        Card(padding: 15) {
                            HStack(spacing: 12) {
                                Image(systemName: project.symbol).foregroundStyle(project.color)
                                    .frame(width: 34, height: 34).background(project.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                                Text(project.rawValue).font(.subheadline)
                                Spacer()
                                Text("\(count) completed").font(.caption).foregroundStyle(Palette.secondary)
                            }
                        }
                    }
                }
                Text("Your worth isn’t measured in checkmarks.\nRest is part of the process, too.")
                    .font(.system(size: 18, design: .serif)).foregroundStyle(Palette.teal)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 10)
            }
            .padding(22).padding(.bottom, 12)
        }
        .background(Palette.background)
    }

    private var maximumDailyTasks: Int {
        days.map { day in
            completedTasks.filter { task in
                guard let date = task.completedAt else { return false }
                return Calendar.current.isDate(date, inSameDayAs: day)
            }.count
        }.max() ?? 0
    }

    private func metric(_ value: String, title: String, symbol: String, color: Color) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: symbol).font(.title3).foregroundStyle(color)
                Text(value).font(.system(size: 34, weight: .semibold, design: .rounded)).foregroundStyle(Palette.ink)
                Text(title).font(.system(size: 11)).foregroundStyle(Palette.secondary)
            }
        }
    }
}
