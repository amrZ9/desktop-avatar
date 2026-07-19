import Combine
import Foundation

/// The single source of truth for which character is currently active.
/// Both the body window and the control panel observe this; changing it
/// here is what makes the desktop character swap.
@MainActor
final class SelectedCharacterStore: ObservableObject {
    static let shared = SelectedCharacterStore()

    private static let defaultsKey = "selectedCharacterID"

    @Published var selected: CharacterOption {
        didSet {
            UserDefaults.standard.set(selected.id, forKey: Self.defaultsKey)
        }
    }

    private init() {
        let savedID = UserDefaults.standard.string(forKey: Self.defaultsKey)
        selected = CharacterLibrary.all.first { $0.id == savedID } ?? CharacterLibrary.default
    }
}
