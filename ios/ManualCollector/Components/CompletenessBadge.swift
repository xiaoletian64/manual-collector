import SwiftUI

struct CompletenessBadge: View {
    let score: Int
    var size: CGFloat = 48
    @EnvironmentObject private var theme: MD3Theme

    private var progress: Double { Double(max(0, min(100, score))) / 100.0 }

    private var ringColor: Color {
        switch score {
        case ..<40: return theme.colors.error
        case ..<70: return theme.colors.tertiary
        default:    return theme.colors.primary
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.colors.surfaceVariant, lineWidth: size * 0.1)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: score)

            Text("\(score)")
                .md3LabelLarge()
                .foregroundStyle(ringColor)
                .font(.system(size: size * 0.3, weight: .bold))
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 16) {
        CompletenessBadge(score: 35, size: 48)
        CompletenessBadge(score: 65, size: 48)
        CompletenessBadge(score: 92, size: 48)
    }
    .environmentObject(MD3Theme())
}
