import SwiftUI

struct WaveEndSheet: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.accentColor)
                .padding(.top, 8)

            Text("Wave complete")
                .font(.title2.weight(.semibold))

            if let task = engine.activeTask {
                VStack(spacing: 4) {
                    Text("Active task")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(task.title)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
            } else {
                Text("No task was attached.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                Button {
                    engine.markElapsedWaveComplete()
                    dismiss()
                } label: {
                    Label("Mark Complete", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(engine.activeTask == nil)

                Button {
                    engine.markElapsedWaveCarryOver()
                    dismiss()
                } label: {
                    Label("Carry Over", systemImage: "arrow.uturn.forward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(engine.activeTask == nil)

                if engine.activeTask == nil {
                    Button {
                        engine.markElapsedWaveCarryOver()
                        dismiss()
                    } label: {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal)
        }
        .padding(24)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled()
    }
}
