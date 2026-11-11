import SwiftUI

struct FocusView: View {
    @EnvironmentObject private var store: PlannerStore
    @State private var confirmReset = false
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                PageHeading(eyebrow: "Protect your attention", title: "Find your quiet.", subtitle: "One thing. A little time. Your full attention.")
                HStack(spacing: 10) {
                    ForEach([15, 25, 45, 60], id: \.self) { minutes in
                        Button { store.setFocusDuration(minutes) } label: {
                            Text("\(minutes) min").font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .foregroundStyle(store.focus.durationMinutes == minutes ? .white : Palette.secondary)
                                .background(store.focus.durationMinutes == minutes ? Palette.teal : .white, in: Capsule())
                        }
                        .buttonStyle(.plain).disabled(store.focus.hasStarted)
                    }
                }

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = store.remainingFocus(at: context.date)
                    ZStack {
                        Circle().fill(Palette.teal.opacity(0.035))
                        ProgressRing(progress: 1 - remaining / Double(store.focus.durationMinutes * 60), color: Palette.teal, lineWidth: 8)
                        VStack(spacing: 15) {
                            Image(systemName: "leaf").font(.system(size: 25, weight: .light)).foregroundStyle(Palette.teal)
                            Text(timeString(remaining))
                                .font(.system(size: 62, weight: .light, design: .rounded)).monospacedDigit()
                                .foregroundStyle(Palette.ink).minimumScaleFactor(0.6).lineLimit(1)
                            Text(store.focus.endDate != nil ? "IN YOUR OWN LITTLE WORLD" : (store.focus.hasStarted ? "TAKE A BREATH" : "READY WHEN YOU ARE"))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .tracking(1.5).foregroundStyle(Palette.secondary)
                        }.padding(25)
                    }
                    .frame(maxWidth: 285).aspectRatio(1, contentMode: .fit)
                    .padding(.vertical, 14).padding(.horizontal, 12)
                    .accessibilityElement(children: .combine)
                }

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("MAKE TIME FOR").font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.5).foregroundStyle(Palette.secondary)
                        Picker("Focus task", selection: Binding(
                            get: { store.focus.taskID },
                            set: { store.selectFocusTask($0) }
                        )) {
                            Text("Just a little space to think").tag(nil as UUID?)
                            ForEach(store.tasks.filter { !$0.isComplete || $0.id == store.focus.taskID }) { task in
                                Text(task.title).tag(Optional(task.id))
                            }
                        }
                        .tint(Palette.ink).labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
                        .disabled(store.focus.hasStarted)
                    }
                }

                VStack(spacing: 14) {
                    PrimaryButton(
                        title: store.focus.endDate != nil ? "Pause session" : (store.focus.hasStarted ? "Resume your focus" : "Begin focus session"),
                        symbol: store.focus.endDate != nil ? "pause.fill" : "play.fill"
                    ) {
                        if store.focus.endDate != nil { store.pauseFocus() } else { store.startFocus() }
                    }
                    if store.focus.hasStarted {
                        Button("End without saving") { confirmReset = true }
                            .font(.caption).foregroundStyle(Palette.secondary).padding(8)
                    }
                }

                Text("“Almost everything will work again if you unplug it for a few minutes, including you.”")
                    .font(.system(size: 19, weight: .regular, design: .serif))
                    .multilineTextAlignment(.center).foregroundStyle(Palette.secondary)
                    .padding(.horizontal, 14)
                Text("ANNE LAMOTT").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(2).foregroundStyle(Palette.secondary)

                if !store.sessions.isEmpty {
                    VStack(spacing: 12) {
                        SectionHeading(title: "Time well spent", subtitle: "Recent sessions")
                        ForEach(Array(store.sessions.sorted { $0.date > $1.date }.prefix(5))) { session in
                            Card(padding: 15) {
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.seal").foregroundStyle(Palette.teal)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(session.taskTitle ?? "A little space to think").font(.system(size: 13, weight: .medium))
                                        Text(session.date.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundStyle(Palette.secondary)
                                    }
                                    Spacer()
                                    Text("\(session.minutes)m").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.teal)
                                }
                            }
                        }
                    }
                }
                Text("Your timer keeps time when you leave the app. Completed sessions are saved when you return. No notification permissions needed.")
                    .font(.caption).foregroundStyle(Palette.secondary).multilineTextAlignment(.center)
            }
            .padding(22).padding(.bottom, 12)
        }
        .background(Palette.background)
        .onReceive(tick) { _ in store.reconcileFocus() }
        .confirmationDialog("End this session? Your time won’t be recorded.", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("End session", role: .destructive) { store.resetFocus() }
        }
    }

    private func timeString(_ interval: TimeInterval) -> String {
        let seconds = Int(ceil(max(0, interval)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
