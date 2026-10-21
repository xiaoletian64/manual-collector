import SwiftUI

struct LibraryView: View {
    @State private var searchText = ""
    @State private var selectedCategory: Category?
    @EnvironmentObject private var theme: MD3Theme

    // Mock data
    @State private var manuals: [Manual] = []

    var filteredManuals: [Manual] {
        manuals.filter { m in
            (searchText.isEmpty || m.productName.localizedCaseInsensitiveContains(searchText))
            && (selectedCategory == nil || m.category == selectedCategory)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            categoryChips
            if manuals.isEmpty {
                emptyState
            } else {
                manualGrid
            }
        }
        .background(theme.colors.background)
        .navigationTitle("我的书柜")
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.colors.onSurfaceVariant)
            TextField("搜索说明书...", text: $searchText)
                .textFieldStyle(.plain)
                .md3BodyLarge()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(theme.colors.surfaceVariant.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Category Chips
    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ChipView(title: "全部", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(Category.allCases, id: \.self) { cat in
                    ChipView(title: cat.rawValue, isSelected: selectedCategory == cat) {
                        selectedCategory = cat
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image("EmptyState", bundle: nil)
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)
                .foregroundStyle(theme.colors.outlineVariant)
            Text("还没有说明书")
                .md3HeadlineMedium()
                .foregroundStyle(theme.colors.onSurface)
            Text("点击下方扫描按钮，\n开始添加你的第一本说明书")
                .md3BodyMedium()
                .foregroundStyle(theme.colors.onSurfaceVariant)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Grid
    private var manualGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(filteredManuals) { manual in
                    NavigationLink {
                        ManualDetailPlaceholder(manual: manual)
                    } label: {
                        BookCard(manual: manual)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Sub-views
struct ChipView: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject private var theme: MD3Theme

    var body: some View {
        Button(action: action) {
            Text(title)
                .md3LabelLarge()
                .foregroundStyle(isSelected ? theme.colors.onPrimaryContainer : theme.colors.onSurfaceVariant)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? theme.colors.primaryContainer : theme.colors.surfaceVariant.opacity(0.3))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct ManualDetailPlaceholder: View {
    let manual: Manual
    var body: some View {
        Text("详情页 — \(manual.productName)")
            .navigationTitle(manual.productName)
    }
}

#Preview {
    NavigationStack {
        LibraryView()
            .environmentObject(MD3Theme())
    }
}
