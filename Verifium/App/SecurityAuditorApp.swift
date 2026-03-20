import SwiftUI

@main
struct SecurityAuditorApp: App {
    @State private var vm = AuditViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(vm: vm)
                .preferredColorScheme(.dark)
                .task { await vm.requestBadgePermission() }
        }
    }
}
