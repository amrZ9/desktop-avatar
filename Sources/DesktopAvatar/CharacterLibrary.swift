import Foundation

/// One selectable character. Today these are placeholders (Elmer plus two
/// free VRMKit test models) — adding a real custom character later is just
/// adding another entry that points at a bundled `.vrm` file.
struct CharacterOption: Identifiable, Equatable {
    let id: String
    let displayName: String
    let vrmResourceName: String
    let rarity: String
}

enum CharacterLibrary {
    static let all: [CharacterOption] = [
        CharacterOption(id: "elmer", displayName: "Elmer", vrmResourceName: "Elmer", rarity: "Placeholder"),
        CharacterOption(id: "alicia", displayName: "Alicia", vrmResourceName: "AliciaSolid", rarity: "Test Model"),
        CharacterOption(id: "seedsan", displayName: "Seed-san", vrmResourceName: "Seed-san", rarity: "Test Model"),
    ]

    static var `default`: CharacterOption { all[0] }
}
