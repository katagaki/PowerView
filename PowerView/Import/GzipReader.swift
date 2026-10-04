import Compression
import Foundation

/// Streams the decompressed bytes of a gzip file without loading it into memory.
/// Supports multi-member gzip files. Uses the Compression framework's raw DEFLATE decoder.
nonisolated final class GzipReader: ByteReader {

    enum GzipError: LocalizedError {
        case notGzip
        case corrupt
        case truncated

        var errorDescription: String? {
            switch self {
            case .notGzip: "The file is not a gzip archive."
            case .corrupt: "The archive is damaged and can't be decompressed."
            case .truncated: "The archive ended unexpectedly. It may not have finished copying."
            }
        }
    }

    private enum State { case header, body, done }

    private let handle: FileHandle
    private let inputCapacity = 1 << 20
    private let input: UnsafeMutablePointer<UInt8>
    private var inStart = 0
    private var inEnd = 0
    private var inputEOF = false
    private var state = State.header
    private var membersRead = 0
    private let stream = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
    private var streamActive = false

    /// Compressed bytes consumed so far, for progress reporting.
    private(set) var compressedBytesRead: UInt64 = 0

    init(url: URL) throws {
        handle = try FileHandle(forReadingFrom: url)
        input = .allocate(capacity: inputCapacity)
    }

    deinit {
        if streamActive { compression_stream_destroy(stream) }
        stream.deallocate()
        input.deallocate()
        try? handle.close()
    }

    static func isGzip(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        let magic = (try? handle.read(upToCount: 2)) ?? Data()
        return magic == Data([0x1f, 0x8b])
    }

    func read(into buffer: UnsafeMutablePointer<UInt8>, count: Int) throws -> Int {
        while true {
            switch state {
            case .done:
                return 0
            case .header:
                guard try readHeader() else {
                    state = .done
                    return 0
                }
                guard compression_stream_init(stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB) == COMPRESSION_STATUS_OK else {
                    throw GzipError.corrupt
                }
                streamActive = true
                state = .body
            case .body:
                if inStart == inEnd && !inputEOF { try refill() }
                let available = inEnd - inStart
                stream.pointee.src_ptr = UnsafePointer(input + inStart)
                stream.pointee.src_size = available
                stream.pointee.dst_ptr = buffer
                stream.pointee.dst_size = count
                let flags = (inputEOF && available == 0) ? Int32(COMPRESSION_STREAM_FINALIZE.rawValue) : 0
                let status = compression_stream_process(stream, flags)
                inStart = inEnd - stream.pointee.src_size
                let produced = count - stream.pointee.dst_size
                switch status {
                case COMPRESSION_STATUS_END:
                    compression_stream_destroy(stream)
                    streamActive = false
                    try skipInput(8) // CRC32 + ISIZE
                    membersRead += 1
                    state = .header
                case COMPRESSION_STATUS_OK:
                    if produced == 0 && inputEOF && inStart == inEnd { throw GzipError.truncated }
                default:
                    throw GzipError.corrupt
                }
                if produced > 0 { return produced }
            }
        }
    }

    // MARK: - Input

    private func refill() throws {
        if inStart > 0 {
            let remaining = inEnd - inStart
            if remaining > 0 { input.update(from: input + inStart, count: remaining) }
            inStart = 0
            inEnd = remaining
        }
        let data = try handle.read(upToCount: inputCapacity - inEnd) ?? Data()
        if data.isEmpty {
            inputEOF = true
            return
        }
        data.copyBytes(to: input + inEnd, count: data.count)
        inEnd += data.count
        compressedBytesRead += UInt64(data.count)
    }

    private func nextInputByte() throws -> UInt8? {
        if inStart == inEnd {
            if inputEOF { return nil }
            try refill()
            if inStart == inEnd { return nil }
        }
        defer { inStart += 1 }
        return input[inStart]
    }

    private func requireByte() throws -> UInt8 {
        guard let byte = try nextInputByte() else { throw GzipError.truncated }
        return byte
    }

    private func skipInput(_ count: Int) throws {
        for _ in 0..<count { _ = try requireByte() }
    }

    /// Parses a gzip member header. Returns false at a clean end of input.
    private func readHeader() throws -> Bool {
        guard let id1 = try nextInputByte() else {
            if membersRead == 0 { throw GzipError.notGzip }
            return false
        }
        let id2 = try nextInputByte()
        guard id1 == 0x1f, id2 == 0x8b else {
            // Trailing padding after the last member is common; anything else on the first member is an error.
            if membersRead == 0 { throw GzipError.notGzip }
            return false
        }
        guard try requireByte() == 8 else { throw GzipError.corrupt } // CM = deflate
        let flags = try requireByte()
        try skipInput(6) // MTIME, XFL, OS
        if flags & 0x04 != 0 {
            let low = Int(try requireByte()), high = Int(try requireByte())
            try skipInput(low | high << 8)
        }
        if flags & 0x08 != 0 { while try requireByte() != 0 {} }
        if flags & 0x10 != 0 { while try requireByte() != 0 {} }
        if flags & 0x02 != 0 { try skipInput(2) }
        return true
    }
}

/// A pull-based source of bytes.
nonisolated protocol ByteReader: AnyObject {
    /// Reads up to `count` bytes. Returns 0 at end of stream.
    func read(into buffer: UnsafeMutablePointer<UInt8>, count: Int) throws -> Int
}

/// Reads an uncompressed file.
nonisolated final class FileByteReader: ByteReader {
    private let handle: FileHandle
    private(set) var bytesRead: UInt64 = 0

    init(url: URL) throws {
        handle = try FileHandle(forReadingFrom: url)
    }

    deinit { try? handle.close() }

    func read(into buffer: UnsafeMutablePointer<UInt8>, count: Int) throws -> Int {
        let data = try handle.read(upToCount: count) ?? Data()
        data.copyBytes(to: buffer, count: data.count)
        bytesRead += UInt64(data.count)
        return data.count
    }
}
