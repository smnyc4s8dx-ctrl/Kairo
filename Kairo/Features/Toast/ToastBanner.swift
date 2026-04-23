import SwiftUI

struct ToastBanner: View {
    @Environment(ToastCenter.self) private var center

    var body: some View {
        VStack {
            Spacer()
            if let toast = center.current {
                toastPill(toast)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 90)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.3), value: center.current?.id)
        .allowsHitTesting(center.current != nil)
    }

    private func toastPill(_ toast: ToastCenter.Toast) -> some View {
        HStack(spacing: 12) {
            Text(toast.message)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            if let label = toast.actionLabel, let action = toast.action {
                Button(label) {
                    action()
                    center.dismiss()
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.accentColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule().fill(.regularMaterial)
        )
        .overlay(
            Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
    }
}
