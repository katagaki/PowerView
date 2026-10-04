import Foundation

/// Walks a tar stream entry by entry. Supports ustar, GNU long names and pax path/size overrides.
nonisolated final class TarReader {

    struct Entry {
        let path: String
        let size: Int
        let isFile: Bool
    }

    enum Action {
        case skip
        case extract(to: URL)
    }

    enum TarError: LocalizedError {
        case corrupt

        var errorDescription: String? { "The archive's file list is damaged." }
    }

    private let source: ByteReader
    private let bufferSize = 1 << 20
    private let buffer: UnsafeMutablePointer<UInt8>

    init(source: ByteReader) {
        self.source = source
        buffer = .allocate(capacity: bufferSize)
    }

    deinit { buffer.deallocate() }

    /// Calls `decide` for every regular file and writes the ones it asks for.
    func forEachEntry(_ decide: (Entry) throws -> Action) throws {
        var longName: String?
        var paxPath: String?
        var paxSize: Int?

        while true {
            guard let header = try readBlock() else { return }
            if header.allSatisfy({ $0 == 0 }) { return }
            guard isValidChecksum(header) else { throw TarError.corrupt }

            let type = header[156]
            var size = parseNumber(header[124..<136])
            if let paxSize { size = paxSize }

            switch type {
            case UInt8(ascii: "L"):
                let data = try readData(size)
                longName = String(decoding: data.prefix { $0 != 0 }, as: UTF8.self)
                continue
            case UInt8(ascii: "x"):
                let records = parsePax(try readData(size))
                paxPath = records["path"]
                paxSize = records["size"].flatMap { Int($0) }
                continue
            case UInt8(ascii: "g"):
                _ = try readData(size)
                continue
            default:
                break
            }

            var path = cString(header[0..<100])
            if header[257..<262].elementsEqual("ustar".utf8) {
                let prefix = cString(header[345..<500])
                if !prefix.isEmpty { path = prefix + "/" + path }
            }
            if let longName { path = longName }
            if let paxPath { path = paxPath }
            longName = nil
            paxPath = nil
            paxSize = nil

            let isFile = type == 0 || type == UInt8(ascii: "0") || type == UInt8(ascii: "7")
            let entry = Entry(path: path, size: size, isFile: isFile)
            let action = isFile ? try decide(entry) : .skip
            switch action {
            case .skip:
                try discard(size)
            case .extract(let url):
                try write(size, to: url)
            }
            try discard(padding(for: size))
        }
    }

    // MARK: - Reading

    private func padding(for size: Int) -> Int { (512 - size % 512) % 512 }

    private func readExactly(_ count: Int, into pointer: UnsafeMutablePointer<UInt8>) throws -> Bool {
        var filled = 0
        while filled < count {
            let n = try source.read(into: pointer + filled, count: count - filled)
            if n == 0 {
                if filled == 0 { return false }
                throw GzipReader.GzipError.truncated
            }
            filled += n
        }
        return true
    }

    private func readBlock() throws -> [UInt8]? {
        var block = [UInt8](repeating: 0, count: 512)
        let ok = try block.withUnsafeMutableBufferPointer { try readExactly(512, into: $0.baseAddress!) }
        return ok ? block : nil
    }

    private func readData(_ size: Int) throws -> Data {
        var data = Data(count: size)
        if size > 0 {
            let ok = try data.withUnsafeMutableBytes {
                try readExactly(size, into: $0.bindMemory(to: UInt8.self).baseAddress!)
            }
            if !ok { throw GzipReader.GzipError.truncated }
        }
        try discard(padding(for: size))
        return data
    }

    private func discard(_ size: Int) throws {
        var remaining = size
        while remaining > 0 {
            let chunk = min(remaining, bufferSize)
            guard try readExactly(chunk, into: buffer) else { throw GzipReader.GzipError.truncated }
            remaining -= chunk
        }
    }

    private func write(_ size: Int, to url: URL) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let out = try FileHandle(forWritingTo: url)
        defer { try? out.close() }
        var remaining = size
        while remaining > 0 {
            let chunk = min(remaining, bufferSize)
            guard try readExactly(chunk, into: buffer) else { throw GzipReader.GzipError.truncated }
            try out.write(contentsOf: Data(bytesNoCopy: buffer, count: chunk, deallocator: .none))
            remaining -= chunk
        }
    }

    // MARK: - Parsing

    private func isValidChecksum(_ header: [UInt8]) -> Bool {
        let stored = parseNumber(header[148..<156])
        let sum = header.enumerated().reduce(0) { $0 + ((148..<156).contains($1.offset) ? 32 : Int($1.element)) }
        return stored == sum
    }

    private func cString(_ bytes: ArraySlice<UInt8>) -> String {
        String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
    }

    private func parseNumber(_ bytes: ArraySlice<UInt8>) -> Int {
        // GNU base-256 encoding for large sizes.
        if let first = bytes.first, first & 0x80 != 0 {
            return bytes.dropFirst().reduce(Int(first & 0x7f)) { $0 << 8 | Int($1) }
        }
        let text = cString(bytes).trimmingCharacters(in: .whitespaces)
        return Int(text, radix: 8) ?? 0
    }

    private func parsePax(_ data: Data) -> [String: String] {
        var result: [String: String] = [:]
        for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
            guard let space = line.firstIndex(of: " ") else { continue }
            let record = line[line.index(after: space)...]
            guard let equals = record.firstIndex(of: "=") else { continue }
            result[String(record[..<equals])] = String(record[record.index(after: equals)...])
        }
        return result
    }
}
