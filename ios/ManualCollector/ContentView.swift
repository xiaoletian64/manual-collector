import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .library
    @EnvironmentObject private var theme: MD3Theme

    enum AppTab: Hashable {
        case library, scan, ask, profile
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    LibraryView()
                }
                .tabItem {
                    Label("书柜", systemImage: "bookshelf.fill")
                }
                .tag(AppTab.library)

                NavigationStack {
                    ScanView()
                }
                .tabItem {
                    Label("扫描", systemImage: "camera.viewfinder")
                }
                .tag(AppTab.scan)

                NavigationStack {
                    AskView()
                }
                .tabItem {
                    Label("问答", systemImage: "question.bubble")
                }
                .tag(AppTab.ask)

                NavigationStack {
                    ProfileView()
                }
                .tabItem {
                    Label("我", systemImage: "person.circle")
                }
                .tag(AppTab.profile)
            }
            .tint(theme.colors.primary)

            // FAB — 浮在 TabView 之上，居中偏上
            if selectedTab != .scan {
                FloatingActionButton {
                    withAnimation(.spring()) {
                        selectedTab = .scan
                    }
                }
                .padding(.bottom, 56)
                .accessibilityIdentifier("scan_fab")
            }
        }
    }
}

/// 半透明凸起 FAB：居中在底部 Tab 上方
struct FloatingActionButton: View {
    let action: () -> Void
    @EnvironmentObject private var theme: MD3Theme

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(theme.colors.primaryContainer.opacity(0.9))
                    .frame(width: 64, height: 64)
                    .shadow(color: theme.colors.primary.opacity(0.35),
                            radius: 12, x: 0, y: 6)
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(theme.colors.onPrimaryContainer)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .environmentObject(MD3Theme())
}
