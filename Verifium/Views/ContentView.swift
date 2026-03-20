import SwiftUI

struct ContentView: View {
    var vm: AuditViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var showWelcome = false

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            TabView(selection: $selectedTab) {
                DashboardView(vm: vm, selectedTab: $selectedTab)
                    .tabItem {
                        Label(NSLocalizedString("tab.dashboard", comment: ""),
                              systemImage: "shield.lefthalf.filled")
                    }
                    .tag(0)

                CheckListView(vm: vm)
                    .tabItem {
                        Label(NSLocalizedString("tab.checks", comment: ""),
                              systemImage: "list.bullet.clipboard")
                    }
                    .tag(1)
                    .badge(vm.pendingCount > 0 ? vm.pendingCount : 0)

                LeaderboardView(vm: vm)
                    .tabItem {
                        Label(NSLocalizedString("tab.leaderboard", comment: ""),
                              systemImage: "trophy.fill")
                    }
                    .tag(2)

                SettingsView(vm: vm)
                    .tabItem {
                        Label(NSLocalizedString("tab.settings", comment: ""),
                              systemImage: "gearshape")
                    }
                    .tag(3)
            }
            .tint(AppColors.teal)
        }
        .task {
            // Only auto-scan if the user already dismissed the welcome screen
            if hasSeenWelcome {
                await vm.runScan()
            }
        }
        .onAppear {
            if !hasSeenWelcome {
                showWelcome = true
            }
        }
        .onChange(of: vm.completionTrigger) { _, trigger in
            guard trigger != nil else { return }
            selectedTab = 0
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .active {
                vm.refreshAppBadge()
            }
        }
        .sheet(isPresented: $showWelcome) {
            WelcomeDisclaimerView {
                hasSeenWelcome = true
                showWelcome = false
                Task { await vm.runScan() }
            }
            .interactiveDismissDisabled(true)
        }
    }
}
