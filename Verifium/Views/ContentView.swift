import SwiftUI

struct ContentView: View {
    @ObservedObject var vm: AuditViewModel
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
            }
            .tint(AppColors.teal)

            // Confetti overlay
            if vm.showCompletionCelebration {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .task {
            await vm.runScan()
        }
        .onAppear {
            if !hasSeenWelcome {
                showWelcome = true
            }
        }
        .onChange(of: vm.completionTrigger) { _, trigger in
            guard trigger != nil else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                selectedTab = 0
            }
            // Auto-dismiss confetti after 3.5 seconds
            if vm.showCompletionCelebration {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 3_500_000_000)
                    withAnimation { vm.showCompletionCelebration = false }
                }
            }
        }
        .sheet(isPresented: $showWelcome) {
            WelcomeDisclaimerView {
                hasSeenWelcome = true
                showWelcome = false
            }
            .interactiveDismissDisabled(true)
        }
    }
}
