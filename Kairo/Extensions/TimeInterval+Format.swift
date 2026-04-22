import Foundation

extension TimeInterval {
    var mmss: String {
        let total = Int(rounded())
        let m = total / 60, s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
