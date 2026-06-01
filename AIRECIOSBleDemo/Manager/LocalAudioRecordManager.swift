import Foundation
import AIRECBleKit

// MARK: - 数据库本地音频管理
final class LocalAudioRecordManager {
    static let shared = LocalAudioRecordManager()

    private let dbFileName = "airec_local_audio.sqlite"
    private let queue = DispatchQueue(label: "com.airec.local-audio-record-manager")

    private var dbPath: String {
        documentsDirectoryURL.appendingPathComponent(dbFileName).path
    }

    private var documentsDirectoryURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private init() {
        createDatabaseIfNeeded()
    }

    @discardableResult
    func save(file: AIRECBleFile, localPath: String) -> LocalAudioRecord {
        let record = LocalAudioRecord(from: file, localPath: localPath)
        save(record)
        return record
    }

    func save(_ record: LocalAudioRecord) {
        queue.sync {
            withDatabase { db in
                let sql = """
                INSERT INTO local_audio_records (id, file_name, file_size, create_time, local_path, is_device, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    file_name = excluded.file_name,
                    file_size = excluded.file_size,
                    create_time = excluded.create_time,
                    local_path = excluded.local_path,
                    is_device = excluded.is_device,
                    updated_at = excluded.updated_at;
                """
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
                defer { sqlite3_finalize(statement) }

                bindText(statement, 1, record.id)
                bindText(statement, 2, record.fileName)
                sqlite3_bind_int64(statement, 3, record.fileSize)
                bindText(statement, 4, record.createTime)
                bindText(statement, 5, persistentLocalPath(for: record.localPath))
                sqlite3_bind_int(statement, 6, record.isDevice ? 1 : 0)
                sqlite3_bind_int64(statement, 7, Int64(Date().timeIntervalSince1970))
                sqlite3_step(statement)
            }
        }
    }

    func delete(fileName: String, removeFile: Bool = false) {
        queue.sync {
            if removeFile, let path = rawLocalPath(for: fileName) {
                try? FileManager.default.removeItem(atPath: resolveLocalPath(path))
            }

            withDatabase { db in
                let sql = "DELETE FROM local_audio_records WHERE id = ?;"
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
                defer { sqlite3_finalize(statement) }
                bindText(statement, 1, fileName)
                sqlite3_step(statement)
            }
        }
    }

    func fetch(fileName: String, onlyExistingFile: Bool = true) -> LocalAudioRecord? {
        queue.sync {
            var record: LocalAudioRecord?
            withDatabase { db in
                let sql = """
                SELECT id, file_name, file_size, create_time, local_path, is_device, updated_at
                FROM local_audio_records
                WHERE id = ?
                LIMIT 1;
                """
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
                defer { sqlite3_finalize(statement) }

                bindText(statement, 1, fileName)
                if sqlite3_step(statement) == SQLITE_ROW {
                    record = makeRecord(from: statement)
                }
            }

            guard onlyExistingFile else { return record }
            guard let record, record.fileExists else {
                deleteMissingRecord(fileName: fileName)
                return nil
            }
            return record
        }
    }

    func fetchAll(onlyExistingFiles: Bool = true) -> [LocalAudioRecord] {
        queue.sync {
            var records: [LocalAudioRecord] = []
            withDatabase { db in
                let sql = """
                SELECT id, file_name, file_size, create_time, local_path, is_device, updated_at
                FROM local_audio_records
                ORDER BY create_time DESC, file_name DESC;
                """
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
                defer { sqlite3_finalize(statement) }

                while sqlite3_step(statement) == SQLITE_ROW {
                    records.append(makeRecord(from: statement))
                }
            }

            guard onlyExistingFiles else { return records }
            let existingRecords = records.filter { $0.fileExists }
            let missingRecords = records.filter { !$0.fileExists }
            missingRecords.forEach { deleteMissingRecord(fileName: $0.fileName) }
            return existingRecords
        }
    }

    func localPath(for fileName: String) -> String? {
        fetch(fileName: fileName)?.resolvedLocalPath
    }

    private func createDatabaseIfNeeded() {
        try? FileManager.default.createDirectory(at: documentsDirectoryURL, withIntermediateDirectories: true)

        withDatabase { db in
            let sql = """
            CREATE TABLE IF NOT EXISTS local_audio_records (
                id TEXT PRIMARY KEY NOT NULL,
                file_name TEXT NOT NULL,
                file_size INTEGER NOT NULL,
                create_time TEXT NOT NULL,
                local_path TEXT NOT NULL,
                is_device INTEGER NOT NULL DEFAULT 0,
                updated_at INTEGER NOT NULL
            );
            """
            sqlite3_exec(db, sql, nil, nil, nil)
        }
    }

    private func deleteMissingRecord(fileName: String) {
        withDatabase { db in
            let sql = "DELETE FROM local_audio_records WHERE id = ?;"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(statement) }
            bindText(statement, 1, fileName)
            sqlite3_step(statement)
        }
    }

    private func rawLocalPath(for fileName: String) -> String? {
        var path: String?
        withDatabase { db in
            let sql = "SELECT local_path FROM local_audio_records WHERE id = ? LIMIT 1;"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(statement) }
            bindText(statement, 1, fileName)
            if sqlite3_step(statement) == SQLITE_ROW {
                path = textColumn(statement, 0)
            }
        }
        return path
    }

    private func makeRecord(from statement: OpaquePointer?) -> LocalAudioRecord {
        LocalAudioRecord(
            id: textColumn(statement, 0),
            fileName: textColumn(statement, 1),
            fileSize: sqlite3_column_int64(statement, 2),
            createTime: textColumn(statement, 3),
            localPath: textColumn(statement, 4),
            isDevice: sqlite3_column_int(statement, 5) != 0,
            updatedAt: sqlite3_column_int64(statement, 6)
        )
    }

    private func resolveLocalPath(_ path: String) -> String {
        if path.hasPrefix("/") {
            return path
        }

        return documentsDirectoryURL.appendingPathComponent(path).path
    }

    private func persistentLocalPath(for path: String) -> String {
        guard path.hasPrefix("/") else { return path }

        let documentsPath = documentsDirectoryURL.standardizedFileURL.path
        let fileURL = URL(fileURLWithPath: path).standardizedFileURL
        guard fileURL.path.hasPrefix(documentsPath) else { return path }

        return fileURL.path
            .dropFirst(documentsPath.count)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func withDatabase(_ work: (OpaquePointer) -> Void) {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK, let db else { return }
        defer { sqlite3_close(db) }
        work(db)
    }

    private func bindText(_ statement: OpaquePointer?, _ index: Int32, _ text: String) {
        let destructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, index, text, -1, destructor)
    }

    private func textColumn(_ statement: OpaquePointer?, _ index: Int32) -> String {
        guard let value = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: value)
    }
}
