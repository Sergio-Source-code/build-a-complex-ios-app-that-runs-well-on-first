import SwiftUI

 enum Palette {
    static let background = Color(hex: 0xF7F7F2)
    static let ink = Color(hex: 0x242B29)
    static let secondary = Color(hex: 0x7C817B)
    static let accent = Color(hex: 0xD75D39)
    static let teal = Color(hex: 0x487C6A)
    static let lavender = Color(hex: 0x8071A8)
    static let line = Color(hex: 0xE8E9E1)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}

struct Card<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Palette.line, lineWidth: 1))
    }
}

struct SectionHeading: View {
    let title: String
    var subtitle: String?
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(Palette.ink)
            Spacer()
            if let subtitle {
                Text(subtitle).font(.caption).foregroundStyle(Palette.secondary)
            }
        }
    }
}

struct PageHeading: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2.5).foregroundStyle(Palette.accent)
            Text(title).font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(Palette.ink)
            Text(subtitle).font(.subheadline).foregroundStyle(Palette.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PrimaryButton: View {
    let title: String
    var symbol: String?
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(Palette.ink, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

struct EmptyCard: View {
    let symbol: String
    let title: String
    let message: String
    var body: some View {
        Card {
            VStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 30)).foregroundStyle(Palette.teal)
                Text(title).font(.headline).foregroundStyle(Palette.ink)
                Text(message).font(.subheadline).multilineTextAlignment(.center).foregroundStyle(Palette.secondary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 20)
        }
    }
}

struct ProgressRing: View {
    let progress: Double
    var color: Color = Palette.accent
    var lineWidth: CGFloat = 7
    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.13), lineWidth: lineWidth)
            Circle().trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(.easeInOut(duration: 0.35), value: progress)
        .accessibilityHidden(true)
    }
}

struct TaskRow: View {
    @EnvironmentObject private var store: PlannerStore
    let task: PlannerTask
    let edit: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            Button {
                withAnimation { store.toggleTask(task) }
            } label: {
                Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(task.isComplete ? Palette.teal : Palette.line.opacity(1))
                    .frame(width: 36, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isComplete ? "Mark \(task.title) incomplete" : "Complete \(task.title)")

            Button(action: edit) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(task.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(task.isComplete ? Palette.secondary : Palette.ink)
                        .strikethrough(task.isComplete)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 8) {
                        Circle().fill(task.project.color).frame(width: 5, height: 5)
                        Text(task.project.rawValue)
                        Text("·")
                        Text("\(task.estimatedMinutes) min")
                        if task.priority == .high && !task.isComplete {
                            Image(systemName: "flag.fill").foregroundStyle(Palette.accent)
                        }
                    }
                    .font(.system(size: 11)).foregroundStyle(Palette.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Edit task")
        }
        .padding(.vertical, 4)
    }
}

struct HabitTile: View {
    @EnvironmentObject private var store: PlannerStore
    let habit: Habit
    let date: Date
    var body: some View {
        let done = habit.isComplete(on: date)
        Button {
            withAnimation { store.toggleHabit(habit, on: date) }
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: habit.symbol).font(.system(size: 19)).foregroundStyle(Palette.teal)
                    Spacer(minLength: 0)
                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(done ? Palette.teal : Palette.secondary.opacity(0.3))
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(habit.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
                    Text(done ? "Done for today" : habit.target).font(.system(size: 10)).foregroundStyle(Palette.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
            .background(done ? Palette.teal.opacity(0.09) : .white, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(done ? Palette.teal.opacity(0.25) : Palette.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(habit.title), \(done ? "completed" : "not completed")")
        .accessibilityHint("Tap to toggle completion")
    }
}
