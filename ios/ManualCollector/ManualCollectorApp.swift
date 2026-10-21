import SwiftUI

@main
struct ManualCollectorApp: App {
    @StateObject private var theme = MD3Theme()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(theme)
                .preferredColorScheme(theme.colorScheme)
        }
    }
}
