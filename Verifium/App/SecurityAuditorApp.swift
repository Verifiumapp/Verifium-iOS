import SwiftUI
import UserNotifications

@main
struct SecurityAuditorApp: App {
    @StateObject private var vm = AuditViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(vm: vm)
                .preferredColorScheme(.dark)
                .task { await requestBadgePermission() }
                .onChange(of: vm.pendingCount) { _, count in
                    updateBadge(count)
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background {
                        updateBadge(vm.pendingCount)
                    }
                }
        }
    }

    private func requestBadgePermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: .badge)
    }

    private func updateBadge(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count)
    }
}
