import Foundation
import AVFoundation
import Observation

enum AmbientSound: String, CaseIterable, Identifiable, Codable {
    case none, white, pink, brown
    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "None"
        case .white: "White Noise"
        case .pink: "Pink Noise"
        case .brown: "Brown Noise"
        }
    }

    var symbol: String {
        switch self {
        case .none: "speaker.slash"
        case .white: "waveform"
        case .pink: "waveform.path.ecg"
        case .brown: "waveform.path"
        }
    }
}

@MainActor
@Observable
final class AmbientSoundService {
    static let shared = AmbientSoundService()

    // Lazy — creating AVAudioEngine at launch pokes the audio HAL and, under
    // App Sandbox on macOS, can trigger an audioanalyticsd mach-lookup that
    // the process isn't authorized to make. We defer until the user actually
    // plays a sound.
    private var engine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private(set) var current: AmbientSound = .none

    var volume: Float = 0.5 {
        didSet { engine?.mainMixerNode.outputVolume = volume }
    }

    private init() {}

    func play(_ sound: AmbientSound) {
        stop()
        guard sound != .none else { current = .none; return }

        let eng = ensureEngine()
        eng.mainMixerNode.outputVolume = volume

        let format = eng.mainMixerNode.outputFormat(forBus: 0)
        let generate = makeGenerator(for: sound)

        let node = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let sample = generate()
                for buffer in abl {
                    let ptr = UnsafeMutableBufferPointer<Float>(buffer)
                    ptr[frame] = sample
                }
            }
            return noErr
        }

        eng.attach(node)
        eng.connect(node, to: eng.mainMixerNode, format: format)

        do {
            #if os(iOS)
            try AVAudioSession.sharedInstance().setActive(true)
            #endif
            try eng.start()
            sourceNode = node
            current = sound
        } catch {
            current = .none
        }
    }

    func stop() {
        if let node = sourceNode, let engine {
            engine.detach(node)
            sourceNode = nil
        }
        if engine?.isRunning == true { engine?.stop() }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        #endif
        current = .none
    }

    private func ensureEngine() -> AVAudioEngine {
        if let engine { return engine }
        let eng = AVAudioEngine()
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(
            .ambient, mode: .default, options: [.mixWithOthers]
        )
        #endif
        engine = eng
        return eng
    }

    private func makeGenerator(for sound: AmbientSound) -> () -> Float {
        switch sound {
        case .none:
            return { 0 }
        case .white:
            return { Float.random(in: -0.3...0.3) }
        case .pink:
            // Paul Kellet's pink noise filter — mutable state per generator instance.
            var b0: Float = 0, b1: Float = 0, b2: Float = 0,
                b3: Float = 0, b4: Float = 0, b5: Float = 0, b6: Float = 0
            return {
                let white = Float.random(in: -1...1)
                b0 = 0.99886 * b0 + white * 0.0555179
                b1 = 0.99332 * b1 + white * 0.0750759
                b2 = 0.96900 * b2 + white * 0.1538520
                b3 = 0.86650 * b3 + white * 0.3104856
                b4 = 0.55000 * b4 + white * 0.5329522
                b5 = -0.7616 * b5 - white * 0.0168980
                let pink = b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362
                b6 = white * 0.115926
                return pink * 0.06
            }
        case .brown:
            var last: Float = 0
            return {
                let white = Float.random(in: -1...1)
                last = (last + 0.02 * white) / 1.02
                return last * 3.5
            }
        }
    }
}
