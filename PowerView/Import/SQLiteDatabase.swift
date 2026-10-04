import Foundation
import SQLite3

/// A minimal read-mostly SQLite wrapper. Queries against tables or columns that don't exist return no rows,
/// because power log schemas vary between iOS versions.
nonisolated final class SQLiteDatabase {

    enum Value {
        case integer(Int64)
        case real(Double)
        case text(String)
        case null

        var double: Double? {
            switch self {
            case .integer(let v): Double(v)
            case .real(let v): v
            case .text(let v): Double(v)
            case .null: nil
            }
        }

        var int: Int? { double.map { Int($0) } }

        var string: String? {
            switch self {
            case .integer(let v): String(v)
            case .real(let v): String(v)
            case .text(let v): v
            case .null: nil
            }
        }
    }

    typealias Row = [Value]

    enum DatabaseError: LocalizedError {
        case cannotOpen(String)

        var errorDescription: String? {
            switch self {
            case .cannotOpen(let message): "The power log couldn't be opened (\(message))."
            }
        }
    }

    private var db: OpaquePointer?
    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(url: URL) throws {
        if sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE, nil) != SQLITE_OK {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            sqlite3_close(db)
            throw DatabaseError.cannotOpen(message)
        }
    }

    deinit { sqlite3_close(db) }

    func tableExists(_ name: String) -> Bool {
        scalar("select count(*) from sqlite_master where type='table' and name=?", name)?.int ?? 0 > 0
    }

    func columns(of table: String) -> Set<String> {
        Set(rows("pragma table_info(\"\(table)\")").compactMap { $0.count > 1 ? $0[1].string : nil })
    }

    func execute(_ sql: String) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    func rows(_ sql: String, _ args: Any...) -> [Row] {
        rows(sql, arguments: args)
    }

    func scalar(_ sql: String, _ args: Any...) -> Value? {
        rows(sql, arguments: args).first?.first
    }

    func rows(_ sql: String, arguments args: [Any]) -> [Row] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        for (index, arg) in args.enumerated() {
            let position = Int32(index + 1)
            switch arg {
            case let v as Double: sqlite3_bind_double(statement, position, v)
            case let v as Int: sqlite3_bind_int64(statement, position, Int64(v))
            case let v as String: sqlite3_bind_text(statement, position, v, -1, SQLITE_TRANSIENT)
            default: sqlite3_bind_null(statement, position)
            }
        }
        var result: [Row] = []
        let count = sqlite3_column_count(statement)
        while sqlite3_step(statement) == SQLITE_ROW {
            var row: Row = []
            row.reserveCapacity(Int(count))
            for column in 0..<count {
                switch sqlite3_column_type(statement, column) {
                case SQLITE_INTEGER: row.append(.integer(sqlite3_column_int64(statement, column)))
                case SQLITE_FLOAT: row.append(.real(sqlite3_column_double(statement, column)))
                case SQLITE_TEXT: row.append(.text(String(cString: sqlite3_column_text(statement, column))))
                default: row.append(.null)
                }
            }
            result.append(row)
        }
        return result
    }
}
