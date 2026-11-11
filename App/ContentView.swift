import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: PlannerStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = 0
    @State private var showingSettings = false

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                TodayView(openFocus: { tab = 2 })
                    .toolbar { brandToolbar }
            }
            .tabItem { Label("Today", systemImage: "square.grid.2x2") }.tag(0)

            NavigationStack {
                PlannerView().toolbar { brandToolbar }
            }
            .tabItem { Label("Planner", systemImage: "calendar") }.tag(1)

            NavigationStack {
                FocusView().toolbar { brandToolbar }
            }
            .tabItem { Label("Focus", systemImage: "timer") }.tag(2)

            NavigationStack {
                InsightsView().toolbar { brandToolbar }
            }
            .tabItem { Label("Insights", systemImage: "chart.bar.xaxis") }.tag(3)
        }
        .tint(Palette.accent)
        .preferredColorScheme(.light)
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .alert("Local storage", isPresented: Binding(
            get: { store.storageMessage != nil },
            set: { if !$0 { store.storageMessage = nil } }
        )) {
            Button("OK") { store.storageMessage = nil }
        } message: { Text(store.storageMessage ?? "") }
        .alert("A little more progress.", isPresented: Binding(
            get: { store.completedFocusMinutes != nil },
            set: { if !$0 { store.completedFocusMinutes = nil } }
        )) {
            Button("Lovely") { store.completedFocusMinutes = nil }
        } message: {
            Text("Your \(store.completedFocusMinutes ?? 0)-minute focus session is saved. Take a breath and enjoy a short break.")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.reconcileFocus() }
        }
    }

    @ToolbarContentBuilder
    private var brandToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            HStack(spacing: 7) {
                Image(systemName: "sun.max.fill").font(.system(size: 22)).foregroundStyle(Palette.accent)
                Text("daylight").font(.system(size: 22, weight: .bold, design: .rounded)).tracking(-0.8).foregroundStyle(Palette.ink)
            }
            .accessibilityElement(children: .combine)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { showingSettings = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17)).foregroundStyle(Palette.ink)
                    .frame(width: 38, height: 38)
                    .background(.white, in: Circle())
                    .overlay(Circle().strokeBorder(Palette.line, lineWidth: 1))
            }
            .accessibilityLabel("Settings")
        }
    }
}