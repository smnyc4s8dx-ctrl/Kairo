import SwiftUI

struct CircularProgressView: View {
    let progress: Double
    let lineWidth: CGFloat
    let tint: Color

    init(progress: Double, lineWidth: CGFloat = 8, tint: Color = .accentColor) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.tint = tint
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.15), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.smooth(duration: 0.6), value: progress)
        }
    }
}

#Preview {
    CircularProgressView(progress: 0.35)
        .frame(width: 200, height: 200)
        .padding()
}
