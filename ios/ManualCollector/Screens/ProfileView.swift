import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var theme: MD3Theme

    var body: some View {
        List {
            // MARK: - Account section
            Section {
                HStack(spacing: 16) {
                    Circle()
                        .fill(theme.colors.primaryContainer)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.title2)
                                .foregroundStyle(theme.colors.onPrimaryContainer)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("用户")
                            .md3TitleMedium()
                        Text("登录后可同步至云盘")
                            .md3BodySmall()
                            .foregroundStyle(theme.colors.onSurfaceVariant)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(theme.colors.outlineVariant)
                }
            }

            // MARK: - Cloud Drive
            Section("云服务") {
                NavigationLink {
                    // TODO: CloudDriveView
                    Text("网盘管理")
                } label: {
                    Label("百度网盘", systemImage: "cloud.fill")
                }
                NavigationLink {
                    // TODO: SubscriptionView
                    Text("订阅管理")
                } label: {
                    Label("订阅", systemImage: "creditcard")
                }
            }

            // MARK: - Settings
            Section("设置") {
                Toggle(isOn: .constant(true)) {
                    Label("自动同步", systemImage: "arrow.triangle.2.circlepath")
                }

                Toggle(isOn: .constant(false)) {
                    Label("仅Wi-Fi上传", systemImage: "wifi")
                }

                NavigationLink {
                    // TODO: ThemeSettings
                    Text("主题设置")
                } label: {
                    Label("外观", systemImage: "sun.max")
                }

                NavigationLink {
                    // TODO: AboutView
                    Text("关于")
                } label: {
                    Label("关于", systemImage: "info.circle")
                }
            }

            // MARK: - Stats
            Section("统计") {
                HStack {
                    Label("说明书数量", systemImage: "bookshelf.fill")
                    Spacer()
                    Text("0")
                        .foregroundStyle(theme.colors.onSurfaceVariant)
                }
                HStack {
                    Label("已扫描页数", systemImage: "doc.text")
                    Spacer()
                    Text("0")
                        .foregroundStyle(theme.colors.onSurfaceVariant)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.colors.background)
        .navigationTitle("我")
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(MD3Theme())
    }
}
