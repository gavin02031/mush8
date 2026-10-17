import Foundation

/// Reads only the unencrypted PFS0 container directory. It never decrypts, extracts,
/// copies, uploads, or executes the selected game file.
struct NSPInspectionReport: Codable {
    let schemaVersion: Int
    let container: String
    let totalBytes: UInt64
    let entryCount: Int
    let ncaCount: Int
    let ncaPayloadBytes: UInt64
    let hasTicket: Bool
    let hasCertificate: Bool
    let titleId: String?
    let packageRole: String
    let recognizedGame: String?
    let gameVersion: String
    let executableModulesInspected: Bool
    let assessment: String
}

enum NSPInspector {
    enum InspectionError: LocalizedError {
        case invalidContainer(String)

        var errorDescription: String? {
            switch self {
            case .invalidContainer(let reason):
                return "Cannot inspect this NSP: \(reason)"
            }
        }
    }

    private static func uint32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(bytes[offset]) |
            (UInt32(bytes[offset + 1]) << 8) |
            (UInt32(bytes[offset + 2]) << 16) |
            (UInt32(bytes[offset + 3]) << 24)
    }

    private static func uint64(_ bytes: [UInt8], _ offset: Int) -> UInt64 {
        UInt64(uint32(bytes, offset)) | (UInt64(uint32(bytes, offset + 4)) << 32)
    }

    private static func readExactly(_ handle: FileHandle, count: Int) throws -> [UInt8] {
        var result = Data()
        while result.count < count {
            let chunk = try handle.read(upToCount: min(65_536, count - result.count)) ?? Data()
            guard !chunk.isEmpty else {
                throw InspectionError.invalidContainer("the container header is incomplete")
            }
            result.append(chunk)
        }
        return [UInt8](result)
    }

    static func inspect(_ url: URL) throws -> NSPInspectionReport {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let length = try handle.seekToEnd()
        try handle.seek(toOffset: 0)

        guard length >= 16 else {
            throw InspectionError.invalidContainer("file is too small")
        }
        let header = try readExactly(handle, count: 16)
        guard Array(header.prefix(4)) == Array("PFS0".utf8) else {
            throw InspectionError.invalidContainer("no PFS0 signature found")
        }

        let count = Int(uint32(header, 4))
        let stringsLength = Int(uint32(header, 8))
        guard count > 0 && count <= 4096 else {
            throw InspectionError.invalidContainer("unsupported entry count")
        }
        guard stringsLength > 0 && stringsLength <= 8 * 1024 * 1024 else {
            throw InspectionError.invalidContainer("unsupported filename table size")
        }

        let tableLength = count * 24
        let dataStart = UInt64(16 + tableLength + stringsLength)
        guard dataStart <= length else {
            throw InspectionError.invalidContainer("directory extends beyond end of file")
        }

        // Metadata is bounded to roughly 8 MiB; payload data is never read.
        let metadata = try readExactly(handle, count: tableLength + stringsLength)
        let stringTableStart = tableLength
        var ncaCount = 0
        var ncaBytes: UInt64 = 0
        var hasTicket = false
        var hasCertificate = false
        var detectedTitle: UInt64?

        for i in 0..<count {
            let entry = i * 24
            let fileOffset = uint64(metadata, entry)
            let fileSize = uint64(metadata, entry + 8)
            let nameOffset = Int(uint32(metadata, entry + 16))

            guard nameOffset < stringsLength else {
                throw InspectionError.invalidContainer("filename offset is invalid")
            }
            guard fileOffset <= length - dataStart &&
                    fileSize <= length - dataStart - fileOffset else {
                throw InspectionError.invalidContainer("file entry exceeds container bounds")
            }

            let nameStart = stringTableStart + nameOffset
            let tableEnd = stringTableStart + stringsLength
            guard let nameEnd = metadata[nameStart..<tableEnd].firstIndex(of: 0),
                  let name = String(bytes: metadata[nameStart..<nameEnd], encoding: .utf8) else {
                throw InspectionError.invalidContainer("invalid file entry name")
            }

            let lower = name.lowercased()
            if lower.hasSuffix(".nca") {
                ncaCount += 1
                guard ncaBytes <= UInt64.max - fileSize else {
                    throw InspectionError.invalidContainer("NCA sizes overflow")
                }
                ncaBytes += fileSize
            } else if lower.hasSuffix(".tik") {
                hasTicket = true
                let filename = lower.split(separator: "/").last.map(String.init) ?? lower
                let prefix = String(filename.prefix(16))
                if prefix.count == 16, let candidate = UInt64(prefix, radix: 16) {
                    detectedTitle = candidate
                }
            } else if lower.hasSuffix(".cert") {
                hasCertificate = true
            }
        }

        let titleId = detectedTitle.map { String(format: "%016llX", $0) }
        let gameId = detectedTitle.map { $0 & ~UInt64(0xFFF) }
        let role: String
        if let tid = detectedTitle {
            switch tid & 0xFFF {
            case 0: role = "Base game"
            case 0x800: role = "Game update"
            default: role = "Add-on or other content"
            }
        } else {
            role = "Unknown (no readable ticket title ID)"
        }

        return NSPInspectionReport(
            schemaVersion: 1,
            container: "NSP/PFS0",
            totalBytes: length,
            entryCount: count,
            ncaCount: ncaCount,
            ncaPayloadBytes: ncaBytes,
            hasTicket: hasTicket,
            hasCertificate: hasCertificate,
            titleId: titleId,
            packageRole: role,
            recognizedGame: gameId == 0x0100000000010000 ? "Super Mario Odyssey" : nil,
            gameVersion: "Unknown; requires parsing game control metadata",
            executableModulesInspected: false,
            assessment: "Header-only inspection: NCA files were not decrypted or executed. No compatibility or performance claim is made. Report contains no game payload, console keys or file paths."
        )
    }
}
