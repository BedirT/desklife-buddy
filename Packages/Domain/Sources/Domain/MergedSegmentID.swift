import Foundation

/// Deterministic merged segment identity (`merged_segment_id_bytes_v1`).
///
/// Encodes only the ordered typed fields — domain literal as NFC UTF-8 with a
/// `UInt32` big-endian byte length, opportunity ID as 16 network-order bytes,
/// segment kind as one `UInt8` byte, identity version as `UInt64`
/// big-endian — with no host names, padding, or trailing bytes. SHA-256 the
/// result, take digest bytes 0 through 15, then set byte 6 to
/// `(byte6 & 0x0f) | 0x80` and byte 8 to `(byte8 & 0x3f) | 0x80` and render
/// lowercase hyphenated UUID text. Every projection uses the same derived ID;
/// no exit-action guard may consume a segment ID before its creation commit.
/// A rebased successor revision retains the same current segment ID.
public struct MergedSegmentID: Equatable, Hashable, Sendable {
    public enum Kind: UInt8, Sendable {
        case visual = 1
        case movement = 2
    }

    /// Fixed segment identity version registered in the ordered fields.
    public static let identityVersion: UInt64 = 1

    /// Domain separation literal registered for this derivation.
    public static let domainLiteral = "cadence.timing-runtime-v2.merged-segment-id.v1"

    public let uuid: UUID
    public let kind: Kind

    private init(uuid: UUID, kind: Kind) {
        self.uuid = uuid
        self.kind = kind
    }

    /// Derives the visual segment ID persisted and projected when merged
    /// accept enters merged visual running.
    public static func visual(for opportunity: OpportunityID) -> MergedSegmentID {
        MergedSegmentID(uuid: derive(opportunityID: opportunity.uuid, kind: .visual), kind: .visual)
    }

    /// Derives the movement segment ID persisted and projected only when the
    /// winning visual exit enters the merged movement offer.
    public static func movement(for opportunity: OpportunityID) -> MergedSegmentID {
        MergedSegmentID(uuid: derive(opportunityID: opportunity.uuid, kind: .movement), kind: .movement)
    }

    private static func derive(opportunityID: UUID, kind: Kind) -> UUID {
        var bytes = [UInt8]()
        let literalBytes = Array(MergedSegmentID.domainLiteral.precomposedStringWithCanonicalMapping.utf8)
        let length = UInt32(literalBytes.count)
        bytes.append(UInt8((length >> 24) & 0xFF))
        bytes.append(UInt8((length >> 16) & 0xFF))
        bytes.append(UInt8((length >> 8) & 0xFF))
        bytes.append(UInt8(length & 0xFF))
        bytes.append(contentsOf: literalBytes)
        bytes.append(contentsOf: networkBytes(of: opportunityID))
        bytes.append(kind.rawValue)
        let version = MergedSegmentID.identityVersion
        for shift in [56, 48, 40, 32, 24, 16, 8, 0] {
            bytes.append(UInt8((version >> shift) & 0xFF))
        }
        var digest = Array(canonicalSHA256(bytes))
        digest[6] = (digest[6] & 0x0F) | 0x80
        digest[8] = (digest[8] & 0x3F) | 0x80
        return UUID(uuid: (
            digest[0], digest[1], digest[2], digest[3],
            digest[4], digest[5], digest[6], digest[7],
            digest[8], digest[9], digest[10], digest[11],
            digest[12], digest[13], digest[14], digest[15],
        ))
    }

    private static func networkBytes(of uuid: UUID) -> [UInt8] {
        let text = uuid.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        var bytes = [UInt8]()
        bytes.reserveCapacity(16)
        var index = text.startIndex
        for _ in 0 ..< 16 {
            let next = text.index(index, offsetBy: 2)
            bytes.append(UInt8(text[index ..< next], radix: 16) ?? 0)
            index = next
        }
        return bytes
    }
}

extension MergedSegmentID: Codable {
    private enum CodingKeys: String, CodingKey {
        case uuid
        case kind
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let text = try container.decode(String.self, forKey: .uuid)
        guard let uuid = UUID(uuidString: text) else {
            throw DecodingError.dataCorruptedError(
                forKey: .uuid,
                in: container,
                debugDescription: "MergedSegmentID requires lowercase hyphenated RFC 4122 text",
            )
        }
        self.uuid = uuid
        let rawKind = try container.decode(UInt8.self, forKey: .kind)
        guard let kind = Kind(rawValue: rawKind) else {
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "MergedSegmentID kind must be 1 (visual) or 2 (movement)",
            )
        }
        self.kind = kind
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lowercaseUUIDText(uuid), forKey: .uuid)
        try container.encode(kind.rawValue, forKey: .kind)
    }
}

/// Minimal SHA-256 over raw bytes (FIPS 180-4). Kept inside Domain so the
/// deterministic segment derivation never depends on platform crypto or host
/// struct layout; the contract known vectors prove the bytes.
func canonicalSHA256(_ message: [UInt8]) -> [UInt8] {
    var bytes = message
    let bitLength = UInt64(bytes.count) * 8
    bytes.append(0x80)
    while bytes.count % 64 != 56 {
        bytes.append(0x00)
    }
    for shift in [56, 48, 40, 32, 24, 16, 8, 0] {
        bytes.append(UInt8((bitLength >> shift) & 0xFF))
    }
    var h: [UInt32] = [
        0x6A09_E667, 0xBB67_AE85, 0x3C6E_F372, 0xA54F_F53A,
        0x510E_527F, 0x9B05_688C, 0x1F83_D9AB, 0x5BE0_CD19,
    ]
    let k: [UInt32] = [
        0x428A_2F98, 0x7137_4491, 0xB5C0_FBCF, 0xE9B5_DBA5, 0x3956_C25B, 0x59F1_11F1, 0x923F_82A4, 0xAB1C_5ED5,
        0xD807_AA98, 0x1283_5B01, 0x2431_85BE, 0x550C_7DC3, 0x72BE_5D74, 0x80DE_B1FE, 0x9BDC_06A7, 0xC19B_F174,
        0xE49B_69C1, 0xEFBE_4786, 0x0FC1_9DC6, 0x240C_A1CC, 0x2DE9_2C6F, 0x4A74_84AA, 0x5CB0_A9DC, 0x76F9_88DA,
        0x983E_5152, 0xA831_C66D, 0xB003_27C8, 0xBF59_7FC7, 0xC6E0_0BF3, 0xD5A7_9147, 0x06CA_6351, 0x1429_2967,
        0x27B7_0A85, 0x2E1B_2138, 0x4D2C_6DFC, 0x5338_0D13, 0x650A_7354, 0x766A_0ABB, 0x81C2_C92E, 0x9272_2C85,
        0xA2BF_E8A1, 0xA81A_664B, 0xC24B_8B70, 0xC76C_51A3, 0xD192_E819, 0xD699_0624, 0xF40E_3585, 0x106A_A070,
        0x19A4_C116, 0x1E37_6C08, 0x2748_774C, 0x34B0_BCB5, 0x391C_0CB3, 0x4ED8_AA4A, 0x5B9C_CA4F, 0x682E_6FF3,
        0x748F_82EE, 0x78A5_636F, 0x84C8_7814, 0x8CC7_0208, 0x90BE_FFFA, 0xA450_6CEB, 0xBEF9_A3F7, 0xC671_78F2,
    ]
    var offset = 0
    while offset < bytes.count {
        var w = [UInt32](repeating: 0, count: 64)
        for i in 0 ..< 16 {
            let base = offset + i * 4
            w[i] = (UInt32(bytes[base]) << 24) | (UInt32(bytes[base + 1]) << 16)
                | (UInt32(bytes[base + 2]) << 8) | UInt32(bytes[base + 3])
        }
        for i in 16 ..< 64 {
            let s0 = ((w[i - 15] >> 7) | (w[i - 15] << 25))
                ^ ((w[i - 15] >> 18) | (w[i - 15] << 14)) ^ (w[i - 15] >> 3)
            let s1 = ((w[i - 2] >> 17) | (w[i - 2] << 15))
                ^ ((w[i - 2] >> 19) | (w[i - 2] << 13)) ^ (w[i - 2] >> 10)
            w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
        }
        var (a, b, c, d, e, f, g, hh) = (h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7])
        for i in 0 ..< 64 {
            let s1 = ((e >> 6) | (e << 26)) ^ ((e >> 11) | (e << 21)) ^ ((e >> 25) | (e << 7))
            let ch = (e & f) ^ (~e & g)
            let t1 = hh &+ s1 &+ ch &+ k[i] &+ w[i]
            let s0 = ((a >> 2) | (a << 30)) ^ ((a >> 13) | (a << 19)) ^ ((a >> 22) | (a << 10))
            let maj = (a & b) ^ (a & c) ^ (b & c)
            let t2 = s0 &+ maj
            hh = g
            g = f
            f = e
            e = d &+ t1
            d = c
            c = b
            b = a
            a = t1 &+ t2
        }
        h[0] = h[0] &+ a
        h[1] = h[1] &+ b
        h[2] = h[2] &+ c
        h[3] = h[3] &+ d
        h[4] = h[4] &+ e
        h[5] = h[5] &+ f
        h[6] = h[6] &+ g
        h[7] = h[7] &+ hh
        offset += 64
    }
    var digest = [UInt8]()
    digest.reserveCapacity(32)
    for word in h {
        digest.append(UInt8((word >> 24) & 0xFF))
        digest.append(UInt8((word >> 16) & 0xFF))
        digest.append(UInt8((word >> 8) & 0xFF))
        digest.append(UInt8(word & 0xFF))
    }
    return digest
}
