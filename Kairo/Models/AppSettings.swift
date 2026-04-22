import Foundation
import Observation

@Observable
@MainActor
final class AppSettings {
    static let shared = AppSettings()

    private let d = UserDefaults.standard

    var focusDurationMinutes: Int {
        didSet { d.set(focusDurationMinutes, forKey: Keys.focus) }
    }
    var shortBreakMinutes: Int {
        didSet { d.set(shortBreakMinutes, forKey: Keys.shortBreak) }
    }
    var longBreakMinutes: Int {
        didSet { d.set(longBreakMinutes, forKey: Keys.longBreak) }
    }
    var wavesUntilLongBreak: Int {
        didSet { d.set(wavesUntilLongBreak, forKey: Keys.wavesUntilLong) }
    }
    var notificationsEnabled: Bool {
        didSet { d.set(notificationsEnabled, forKey: Keys.notifs) }
    }
    var iCloudSyncEnabled: Bool {
        didSet { d.set(iCloudSyncEnabled, forKey: Keys.cloudkit) }
    }
    var ambientSoundValue: String {
        didSet { d.set(ambientSoundValue, forKey: Keys.sound) }
    }
    var ambientSoundVolume: Double {
        didSet { d.set(ambientSoundVolume, forKey: Keys.soundVol) }
    }
    var autoStartBreak: Bool {
        didSet { d.set(autoStartBreak, forKey: Keys.autoBreak) }
    }
    var autoStartNextWave: Bool {
        didSet { d.set(autoStartNextWave, forKey: Keys.autoNext) }
    }

    private init() {
        d.register(defaults: [
            Keys.focus: 25,
            Keys.shortBreak: 5,
            Keys.longBreak: 15,
            Keys.wavesUntilLong: 4,
            Keys.notifs: true,
            Keys.cloudkit: false,
            Keys.sound: AmbientSound.none.rawValue,
            Keys.soundVol: 0.5,
            Keys.autoBreak: true,
            Keys.autoNext: false,
        ])
        self.focusDurationMinutes = d.integer(forKey: Keys.focus)
        self.shortBreakMinutes = d.integer(forKey: Keys.shortBreak)
        self.longBreakMinutes = d.integer(forKey: Keys.longBreak)
        self.wavesUntilLongBreak = d.integer(forKey: Keys.wavesUntilLong)
        self.notificationsEnabled = d.bool(forKey: Keys.notifs)
        self.iCloudSyncEnabled = d.bool(forKey: Keys.cloudkit)
        self.ambientSoundValue = d.string(forKey: Keys.sound) ?? AmbientSound.none.rawValue
        self.ambientSoundVolume = d.double(forKey: Keys.soundVol)
        self.autoStartBreak = d.bool(forKey: Keys.autoBreak)
        self.autoStartNextWave = d.bool(forKey: Keys.autoNext)
    }

    var ambientSound: AmbientSound {
        get { AmbientSound(rawValue: ambientSoundValue) ?? .none }
        set { ambientSoundValue = newValue.rawValue }
    }

    private enum Keys {
        static let focus = "focusDurationMinutes"
        static let shortBreak = "shortBreakMinutes"
        static let longBreak = "longBreakMinutes"
        static let wavesUntilLong = "wavesUntilLongBreak"
        static let notifs = "notificationsEnabled"
        static let cloudkit = "iCloudSyncEnabled"
        static let sound = "ambientSoundValue"
        static let soundVol = "ambientSoundVolume"
        static let autoBreak = "autoStartBreak"
        static let autoNext = "autoStartNextWave"
    }
}
