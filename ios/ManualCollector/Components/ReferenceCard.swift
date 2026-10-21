import SwiftUI

struct ReferenceCard: View {
    let reference: ChatReference
    @EnvironmentObject private var theme: MD3Theme

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("第 \(reference.pageNumber) 页 · 引用")
                    .md3LabelSmall()
                    .foregroundStyle(theme.colors.primary)

                Text(reference.snippet)
                    .md3BodySmall()
                    .foregroundStyle(theme.colors.onSurfaceVariant)
                    .lineLimit(3)

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 8))
                    Text("匹配度 \(Int(reference.confidence * 100))%")
                        .md3LabelSmall()
                        .foregroundStyle(theme.colors.primary.opacity(0.7))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(theme.colors.surfaceVariant.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.colors.outlineVariant.opacity(0.4), lineWidth: 1)
        )
    }
}

#Preview {
    ReferenceCard(reference: ChatReference(pageNumber: 3, snippet: "安装前请确保电源已断开，且插座符合额定电压要求。", confidence: 0.92))
        .environmentObject(MD3Theme())
        .padding()
}
