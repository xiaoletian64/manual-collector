import SwiftUI

struct BookCard: View {
    let manual: Manual
    @EnvironmentObject private var theme: MD3Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.colors.primaryContainer.opacity(0.5))
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay(
                    VStack(spacing: 4) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(theme.colors.primary)
                        Text(manual.category.rawValue)
                            .md3LabelSmall()
                            .foregroundStyle(theme.colors.onPrimaryContainer)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(manual.productName)
                    .md3TitleSmall()
                    .foregroundStyle(theme.colors.onSurface)
                    .lineLimit(1)
                if !manual.brand.isEmpty {
                    Text(manual.brand)
                        .md3BodySmall()
                        .foregroundStyle(theme.colors.onSurfaceVariant)
                        .lineLimit(1)
                }
                HStack(spacing: 4) {
                    CompletenessBadge(score: manual.completenessScore, size: 20)
                    Text("\(manual.pageCount) 页")
                        .md3LabelSmall()
                        .foregroundStyle(theme.colors.onSurfaceVariant)
                    Spacer()
                    if manual.cloudSyncStatus == .synced {
                        Image(systemName: "icloud.fill")
                            .font(.caption2)
                            .foregroundStyle(theme.colors.primary)
                    }
                }
            }
        }
        .padding(12)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: theme.colors.shadow.opacity(0.06), radius: 4, y: 2)
    }
}

#Preview {
    BookCard(manual: Manual(productName: "智能电饭煲", brand: "美的", category: .厨电, pageCount: 24, completenessScore: 85))
        .environmentObject(MD3Theme())
        .frame(width: 180)
}
