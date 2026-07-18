import Foundation
import simd

/// VRMKit only loads a character's shape and skeleton — it has no support
/// for `.vrma` motion files. This is our own minimal VRMA parser: it reads
/// the embedded glTF animation channels and resolves each animated bone
/// via the VRMC_vrm_animation extension, so any standard-compliant `.vrma`
/// clip can drive our character, not just ones some other engine baked in.
struct VRMAAnimation {
    struct BoneTrack {
        /// Raw VRMC_vrm_animation bone name (e.g. "leftUpperArm"). Kept as a
        /// plain string rather than `Humanoid<Node>.Bones` because that
        /// nested type is tied to whichever `Node` specialization resolves
        /// it — a `Humanoid<Never>.Bones` won't type-match `Humanoid<Entity>`.
        let bone: String
        let times: [Float]
        let rotations: [simd_quatf]?
        let translations: [SIMD3<Float>]?
        /// This node's static rest rotation/translation, as authored in the
        /// .vrma's own node hierarchy — the reference pose the animated
        /// values are relative to. Needed to retarget onto a different
        /// character's own rest pose rather than pasting values verbatim.
        let sourceRestRotation: simd_quatf
        let sourceRestTranslation: SIMD3<Float>
    }

    let duration: Float
    let tracks: [BoneTrack]

    static func load(contentsOf url: URL) throws -> VRMAAnimation {
        try load(data: Data(contentsOf: url))
    }

    static func load(data: Data) throws -> VRMAAnimation {
        guard let glb = GLTFBinary(data: data) else {
            throw VRMAError.invalidContainer
        }
        let gltf = try JSONSerialization.jsonObject(with: glb.jsonChunk) as? [String: Any] ?? [:]
        guard let animations = gltf["animations"] as? [[String: Any]], let animation = animations.first else {
            throw VRMAError.noAnimation
        }

        let boneNameByNode = Self.boneNamesByNode(in: gltf)
        let nodes = gltf["nodes"] as? [[String: Any]] ?? []
        let accessors = gltf["accessors"] as? [[String: Any]] ?? []
        let bufferViews = gltf["bufferViews"] as? [[String: Any]] ?? []
        let samplers = animation["samplers"] as? [[String: Any]] ?? []
        let channels = animation["channels"] as? [[String: Any]] ?? []

        var tracks: [BoneTrack] = []
        var duration: Float = 0

        for channel in channels {
            guard let target = channel["target"] as? [String: Any],
                  let nodeIndex = target["node"] as? Int,
                  let path = target["path"] as? String,
                  let bone = boneNameByNode[nodeIndex],
                  let samplerIndex = channel["sampler"] as? Int,
                  samplers.indices.contains(samplerIndex)
            else { continue }

            let sampler = samplers[samplerIndex]
            guard let inputIndex = sampler["input"] as? Int,
                  let outputIndex = sampler["output"] as? Int else { continue }

            let times = Self.floats(accessorIndex: inputIndex, accessors: accessors, bufferViews: bufferViews, glb: glb)
            duration = max(duration, times.max() ?? 0)
            let values = Self.floats(accessorIndex: outputIndex, accessors: accessors, bufferViews: bufferViews, glb: glb)
            let restRotation = Self.restRotation(ofNode: nodeIndex, in: nodes)
            let restTranslation = Self.restTranslation(ofNode: nodeIndex, in: nodes)

            switch path {
            case "rotation":
                let rotations = stride(from: 0, to: values.count, by: 4).map {
                    simd_quatf(vector: SIMD4(values[$0], values[$0 + 1], values[$0 + 2], values[$0 + 3]))
                }
                tracks.append(BoneTrack(
                    bone: bone, times: times, rotations: rotations, translations: nil,
                    sourceRestRotation: restRotation, sourceRestTranslation: restTranslation
                ))
            case "translation":
                let translations = stride(from: 0, to: values.count, by: 3).map {
                    SIMD3<Float>(values[$0], values[$0 + 1], values[$0 + 2])
                }
                tracks.append(BoneTrack(
                    bone: bone, times: times, rotations: nil, translations: translations,
                    sourceRestRotation: restRotation, sourceRestTranslation: restTranslation
                ))
            default:
                continue
            }
        }

        return VRMAAnimation(duration: duration, tracks: tracks)
    }

    private static func boneNamesByNode(in gltf: [String: Any]) -> [Int: String] {
        guard let ext = gltf["extensions"] as? [String: Any],
              let vrmAnim = ext["VRMC_vrm_animation"] as? [String: Any],
              let humanoid = vrmAnim["humanoid"] as? [String: Any],
              let humanBones = humanoid["humanBones"] as? [String: Any]
        else { return [:] }

        var result: [Int: String] = [:]
        for (name, value) in humanBones {
            if let entry = value as? [String: Any], let node = entry["node"] as? Int {
                result[node] = name
            }
        }
        return result
    }

    private static func restRotation(ofNode index: Int, in nodes: [[String: Any]]) -> simd_quatf {
        guard nodes.indices.contains(index), let r = nodes[index]["rotation"] as? [Double], r.count == 4 else {
            return simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        }
        return simd_quatf(ix: Float(r[0]), iy: Float(r[1]), iz: Float(r[2]), r: Float(r[3]))
    }

    private static func restTranslation(ofNode index: Int, in nodes: [[String: Any]]) -> SIMD3<Float> {
        guard nodes.indices.contains(index), let t = nodes[index]["translation"] as? [Double], t.count == 3 else {
            return .zero
        }
        return SIMD3<Float>(Float(t[0]), Float(t[1]), Float(t[2]))
    }

    private static func floats(accessorIndex: Int, accessors: [[String: Any]], bufferViews: [[String: Any]], glb: GLTFBinary) -> [Float] {
        guard accessors.indices.contains(accessorIndex) else { return [] }
        let accessor = accessors[accessorIndex]
        guard let bufferViewIndex = accessor["bufferView"] as? Int, bufferViews.indices.contains(bufferViewIndex) else { return [] }
        let bufferView = bufferViews[bufferViewIndex]

        let componentsPerElement: Int
        switch accessor["type"] as? String {
        case "SCALAR": componentsPerElement = 1
        case "VEC3": componentsPerElement = 3
        case "VEC4": componentsPerElement = 4
        default: componentsPerElement = 1
        }
        let count = (accessor["count"] as? Int ?? 0) * componentsPerElement
        let accessorByteOffset = accessor["byteOffset"] as? Int ?? 0
        let viewByteOffset = bufferView["byteOffset"] as? Int ?? 0
        let start = viewByteOffset + accessorByteOffset

        return glb.binChunk.withUnsafeBytes { raw -> [Float] in
            let base = raw.baseAddress!.advanced(by: start).assumingMemoryBound(to: Float.self)
            return (0..<count).map { base[$0] }
        }
    }
}

enum VRMAError: Error {
    case invalidContainer
    case noAnimation
}

/// Shared minimal GLB (binary glTF) chunk reader.
struct GLTFBinary {
    let jsonChunk: Data
    let binChunk: Data

    init?(data: Data) {
        guard data.count >= 12, data[0..<4] == Data("glTF".utf8) else { return nil }
        var offset = 12
        var json: Data?
        var bin: Data?
        while offset + 8 <= data.count {
            let chunkLength = Int(data.readUInt32LE(at: offset))
            let chunkType = data[offset + 4..<offset + 8]
            let chunkStart = offset + 8
            let chunkEnd = chunkStart + chunkLength
            guard chunkEnd <= data.count else { break }
            let chunk = data[chunkStart..<chunkEnd]
            if chunkType == Data("JSON".utf8) {
                json = chunk
            } else if chunkType == Data("BIN\0".utf8) {
                bin = chunk
            }
            offset = chunkEnd
        }
        guard let json else { return nil }
        jsonChunk = json
        binChunk = bin ?? Data()
    }
}

private extension Data {
    func readUInt32LE(at offset: Int) -> UInt32 {
        let bytes = self[offset..<offset + 4]
        return bytes.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
    }
}
