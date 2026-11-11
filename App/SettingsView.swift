import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: PlannerStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("dismissedWelcome") private var dismissedWelcome = false
    @State private var resetChoice: ResetChoice?

    private enum ResetChoice: String, Identifiable {
        case empty, examples
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("daylight", systemImage: "sun.max.fill")
                            .font(.system(size: 29, weight: .bold, design: .rounded)).foregroundStyle(Palette.accent)
                        Text("A calmer place for everything you want to make time for.")
                            .font(.subheadline).foregroundStyle(Palette.secondary)
                    }.padding(.vertical, 10)
                }
                Section("Made for a fresh start") {
                    Label("Works completely offline", systemImage: "wifi.slash")
                    Label("No account. No setup.", systemImage: "person.crop.circle.badge.checkmark")
                    Label("Saved automatically on this device", systemImage: "internaldrive")
                }
                Section {
                    Text("Tasks, habits, and focus sessions stay on this device. There are no ads, analytics, or network requests. Deleting the app removes its local data. This version does not sync between devices.")
                        .font(.subheadline).foregroundStyle(Palette.secondary)
                } header: { Text("Your space stays yours") }

                Section {
                    Button("Show the welcome tip") { dismissedWelcome = false; dismiss() }
                    Button("Restore example planner") { resetChoice = .examples }
                    Button("Start with an empty planner", role: .destructive) { resetChoice = .empty }
                } header: { Text("A clean slate") } footer: {
                    Text("Both reset options replace all tasks, habits, focus history, and any active timer. This can’t be undone.")
                }
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0").foregroundStyle(Palette.secondary)
                    }
                }
            }
            .scrollContentBackground(.hidden).background(Palette.background)
            .navigationTitle("A space of your own").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog("Replace all local data?", isPresented: Binding(
                get: { resetChoice != nil },
                set: { if !$0 { resetChoice = nil } }
            ), titleVisibility: .visible, presenting: resetChoice) { choice in
                Button(choice == .examples ? "Replace with examples" : "Delete all data", role: .destructive) {
                    store.resetAll(includeExamples: choice == .examples)
                    dismissedWelcome = choice == .empty
                    resetChoice = nil
                    dismiss()
                }
            } message: { _ in
                Text("All existing tasks, habits, and focus sessions will be permanently removed.")
            }
        }
        .tint(Palette.accent)
    }
}
