import AppKit

enum SystemSound {
    case alert
    case questComplete
    case levelUp
    case penalty
    case shadowExtract

    var fileName: String {
        switch self {
        case .alert: "Glass"
        case .questComplete: "Hero"
        case .levelUp: "Blow"
        case .penalty: "Sosumi"
        case .shadowExtract: "Submarine"
        }
    }

    func play() {
        NSSound(named: NSSound.Name(fileName))?.play()
    }
}
