import SwiftUI

struct ScanConfirmView: View {
    @State private var report: CompletenessReport?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: MD3Theme

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                completenessScoreSection
                detectedSectionsSection
                missingSectionsSection
                actionButtons
            }
            .padding(24)
        }
        .background(theme.colors.background)
        .navigationTitle("完整性评估")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await evaluate()
        }
    }

    private var completenessScoreSection: some View {
        VStack(spacing: 8) {
            CompletenessBadge(score: report?.overallScore ?? 0, size: 120)
            Text("完整性评分")
                .md3TitleMedium()
                .foregroundStyle(theme.colors.onSurface)
            if let report {
                FiveDimensionBars(scores: report.dimensionScores)
            }
        }
    }

    private var detectedSectionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("已检测章节")
                .md3TitleSmall()
                .foregroundStyle(theme.colors.onSurface)
            FlowLayout(spacing: 8) {
                ForEach(report?.detectedSections ?? [], id: \.self) { sec in
                    Text(sec)
                        .md3LabelLarge()
                        .foregroundStyle(theme.colors.onSecondaryContainer)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(theme.colors.secondaryContainer)
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var missingSectionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("疑似缺失")
                .md3TitleSmall()
                .foregroundStyle(theme.colors.error)
            ForEach(report?.missingSections ?? [], id: \.self) { sec in
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(theme.colors.error)
                    Text(sec)
                        .md3BodyMedium()
                        .foregroundStyle(theme.colors.onSurface)
                }
            }
            if let suggestions = report?.suggestions, !suggestions.isEmpty {
                Text("建议")
                    .md3TitleSmall()
                    .foregroundStyle(theme.colors.onSurfaceVariant)
                    .padding(.top, 4)
                ForEach(suggestions, id: \.self) { s in
                    Text("·  \(s)")
                        .md3BodySmall()
                        .foregroundStyle(theme.colors.onSurfaceVariant)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button(action: { dismiss() }) {
                Label("补拍", systemImage: "camera")
                    .frame(maxWidth: .infinity)
                    .md3LabelLarge()
            }
            .buttonStyle(.bordered)
            .tint(theme.colors.primary)

            Button(action: saveToLibrary) {
                Label("保存到书柜", systemImage: "bookshelf.fill")
                    .frame(maxWidth: .infinity)
                    .md3LabelLarge()
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.colors.primary)
        }
    }

    private func evaluate() async {
        // TODO: call CompletenessEvaluator
        report = CompletenessReport(
            manualID: UUID(),
            overallScore: 78,
            dimensionScores: DimensionScores(
                structuralIntegrity: 82,
                textClarity: 75,
                pageCompleteness: 70,
                sectionDiversity: 80,
                imageQuality: 85
            ),
            detectedSections: ["安全须知", "安装步骤", "功能介绍", "参数规格"],
            missingSections: ["故障排除", "保修说明"],
            suggestions: ["建议补充"故障排除"章节", "建议拍摄保修卡页"]
        )
    }

    private func saveToLibrary() {
        // TODO: save Manual to local store
        dismiss()
    }
}

struct FiveDimensionBars: View {
    let scores: DimensionScores
    @EnvironmentObject private var theme: MD3Theme

    private var items: [(String, Int)] {
        [("结构完整性", scores.structuralIntegrity),
         ("文字清晰度", scores.textClarity),
         ("页面完整度", scores.pageCompleteness),
         ("章节多样性", scores.sectionDiversity),
         ("图像质量", scores.imageQuality)]
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(items, id: \.0) { label, score in
                HStack {
                    Text(label)
                        .md3BodySmall()
                        .foregroundStyle(theme.colors.onSurfaceVariant)
                        .frame(width: 80, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(theme.colors.surfaceVariant)
                                .frame(height: 8)
                            Capsule()
                                .fill(theme.colors.primary)
                                .frame(width: geo.size.width * CGFloat(score) / 100, height: 8)
                        }
                    }
                    .frame(height: 8)
                    Text("\(score)")
                        .md3LabelSmall()
                        .foregroundStyle(theme.colors.onSurfaceVariant)
                        .frame(width: 28, alignment: .trailing)
                }
            }
        }
    }
}

/// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0; y += size.height + spacing
            }
            x += size.width + spacing
            height = max(height, y + size.height)
        }
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX; y += size.height + spacing
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
        }
    }
}

#Preview {
    NavigationStack {
        ScanConfirmView()
            .environmentObject(MD3Theme())
    }
}
