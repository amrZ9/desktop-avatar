import Foundation

/// Real-world .vrm exports don't always populate every field our loader
/// treats as required, even when the field is cosmetic (e.g. first-person
/// camera exclusion lists). This patches known gaps in the embedded glTF
/// JSON before handing the file to VRMKit, so a file being "technically
/// incomplete" doesn't block loading the character entirely.
///
/// Extend `patch(json:)` as new incompatibilities are discovered.
enum VRMCompatibility {
    static func makeLoadable(_ data: Data) -> Data {
        guard let glb = GLBContainer(data: data) else { return data }
        guard var json = try? JSONSerialization.jsonObject(with: glb.jsonChunk) as? [String: Any] else {
            return data
        }
        patch(json: &json)
        guard let patchedJSON = try? JSONSerialization.data(withJSONObject: json) else { return data }
        return glb.rebuilding(jsonChunk: patchedJSON)
    }

    private static func patch(json: inout [String: Any]) {
        guard var extensions = json["extensions"] as? [String: Any] else { return }
        for key in ["VRMC_vrm", "VRM"] where extensions[key] != nil {
            patchFirstPerson(inExtension: key, extensions: &extensions)
        }
        json["extensions"] = extensions
    }

    private static func patchFirstPerson(inExtension key: String, extensions: inout [String: Any]) {
        guard var ext = extensions[key] as? [String: Any],
              var firstPerson = ext["firstPerson"] as? [String: Any]
        else { return }
        if firstPerson["meshAnnotations"] == nil {
            firstPerson["meshAnnotations"] = []
        }
        ext["firstPerson"] = firstPerson
        extensions[key] = ext
    }
}

/// Minimal reader/writer for the binary glTF (.glb / .vrm) container format:
/// a 12-byte header followed by a JSON chunk and (usually) one binary chunk.
private struct GLBContainer {
    let jsonChunk: Data
    private let trailingChunks: Data

    init?(data: Data) {
        guard data.count >= 12, data[0..<4] == Data("glTF".utf8) else { return nil }
        let jsonChunkLength = Int(data.readUInt32LE(at: 12))
        let jsonStart = 20
        let jsonEnd = jsonStart + jsonChunkLength
        guard data.count >= jsonEnd else { return nil }
        jsonChunk = data[jsonStart..<jsonEnd]
        trailingChunks = data[jsonEnd...]
    }

    func rebuilding(jsonChunk newJSON: Data) -> Data {
        var padded = newJSON
        while padded.count % 4 != 0 { padded.append(0x20) } // glTF pads JSON chunks with spaces

        var result = Data()
        result.appendUInt32LE(UInt32(padded.count))
        result.append(Data("JSON".utf8))
        result.append(padded)
        result.append(trailingChunks)

        var header = Data()
        header.append(Data("glTF".utf8))
        header.appendUInt32LE(2)
        header.appendUInt32LE(UInt32(12 + result.count))
        return header + result
    }
}

private extension Data {
    func readUInt32LE(at offset: Int) -> UInt32 {
        let bytes = self[offset..<offset + 4]
        return bytes.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}
