import Foundation
import AIRECBleKit
import GRDB

// MARK: - 数据库本地音频管理
final class LocalAudioRecordManager {
    static let shared = LocalAudioRecordManager()

    private let dbFileName = "airec_local_audio.sqlite"
    private let dbQueue: DatabaseQueue

    private var dbPath: String {
        documentsDirectoryURL.appendingPathComponent(dbFileName).path
    }

    private var documentsDirectoryURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private init() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let databasePath = documentsURL.appendingPathComponent(dbFileName).path
        try? FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        dbQueue = try! DatabaseQueue(path: databasePath)
        createDatabaseIfNeeded()
    }

    @discardableResult
    func save(file: AIRECBleFile, localPath: String) -> LocalAudioRecord {
        let record = LocalAudioRecord(from: file, localPath: localPath)
        save(record)
        return record
    }

    func save(_ record: LocalAudioRecord) {
        do {
            try dbQueue.write { db in
                try db.execute(
                    sql: """
                    INSERT INTO local_audio_records (id, file_name, display_name, file_size, create_time, local_path, is_device, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                        file_name = excluded.file_name,
                        display_name = excluded.display_name,
                        file_size = excluded.file_size,
                        create_time = excluded.create_time,
                        local_path = excluded.local_path,
                        is_device = excluded.is_device,
                        updated_at = excluded.updated_at;
                    """,
                    arguments: [
                        record.id,
                        record.fileName,
                        record.displayName,
                        record.fileSize,
                        record.createTime,
                        persistentLocalPath(for: record.localPath),
                        record.isDevice,
                        Int64(Date().timeIntervalSince1970)
                    ]
                )
            }
        } catch {
            print("LocalAudioRecordManager save error: \(error)")
        }
    }

    func delete(fileName: String, removeFile: Bool = false) {
        do {
            if removeFile, let path = rawLocalPath(for: fileName) {
                try? FileManager.default.removeItem(atPath: resolveLocalPath(path))
            }

            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM local_audio_records WHERE id = ? OR file_name = ?;", arguments: [fileName, fileName])
            }
        } catch {
            print("LocalAudioRecordManager delete error: \(error)")
        }
    }

    func fetch(fileName: String, onlyExistingFile: Bool = true) -> LocalAudioRecord? {
        do {
            let record = try dbQueue.read { db in
                try Row.fetchOne(
                    db,
                    sql: """
                    SELECT id, file_name, display_name, file_size, create_time, local_path, is_device, updated_at
                    FROM local_audio_records
                    WHERE id = ? OR file_name = ?
                    LIMIT 1;
                    """,
                    arguments: [fileName, fileName]
                ).map(makeRecord)
            }

            guard onlyExistingFile else { return record }
            guard let record, record.fileExists else {
                deleteMissingRecord(fileName: record?.id ?? fileName)
                return nil
            }
            return record
        } catch {
            print("LocalAudioRecordManager fetch error: \(error)")
            return nil
        }
    }

    func fetchAll(onlyExistingFiles: Bool = true) -> [LocalAudioRecord] {
        do {
            let records = try dbQueue.read { db in
                try Row.fetchAll(
                    db,
                    sql: """
                    SELECT id, file_name, display_name, file_size, create_time, local_path, is_device, updated_at
                    FROM local_audio_records
                    ORDER BY create_time DESC, file_name DESC;
                    """
                ).map(makeRecord)
            }

            guard onlyExistingFiles else { return records }
            let existingRecords = records.filter { $0.fileExists }
            let missingRecords = records.filter { !$0.fileExists }
            missingRecords.forEach { deleteMissingRecord(fileName: $0.id) }
            return existingRecords
        } catch {
            print("LocalAudioRecordManager fetchAll error: \(error)")
            return []
        }
    }

    func localPath(for fileName: String) -> String? {
        fetch(fileName: fileName)?.resolvedLocalPath
    }

    func updateDisplayName(id: String, displayName: String) {
        do {
            try dbQueue.write { db in
                try db.execute(
                    sql: "UPDATE local_audio_records SET display_name = ?, updated_at = ? WHERE id = ?;",
                    arguments: [displayName, Int64(Date().timeIntervalSince1970), id]
                )
            }
        } catch {
            print("LocalAudioRecordManager update display name error: \(error)")
        }
    }

    private func createDatabaseIfNeeded() {
        do {
            try dbQueue.write { db in
                try db.create(table: "local_audio_records", ifNotExists: true) { table in
                    table.column("id", .text).notNull().primaryKey()
                    table.column("file_name", .text).notNull()
                    table.column("display_name", .text).notNull()
                    table.column("file_size", .integer).notNull()
                    table.column("create_time", .text).notNull()
                    table.column("local_path", .text).notNull()
                    table.column("is_device", .boolean).notNull().defaults(to: false)
                    table.column("updated_at", .integer).notNull()
                }
                try addDisplayNameColumnIfNeeded(db)
                try migrateLegacyIDsIfNeeded(db)
            }
        } catch {
            print("LocalAudioRecordManager create database error: \(error)")
        }
    }

    private func addDisplayNameColumnIfNeeded(_ db: Database) throws {
        let columnRows = try Row.fetchAll(db, sql: "PRAGMA table_info(local_audio_records);")
        let hasDisplayName = columnRows.contains { row in
            let name: String = row["name"]
            return name == "display_name"
        }

        guard !hasDisplayName else { return }
        try db.execute(sql: "ALTER TABLE local_audio_records ADD COLUMN display_name TEXT;")
        try db.execute(sql: "UPDATE local_audio_records SET display_name = file_name WHERE display_name IS NULL OR display_name = '';")
    }

    private func migrateLegacyIDsIfNeeded(_ db: Database) throws {
        let rows = try Row.fetchAll(
            db,
            sql: "SELECT id, file_name, create_time FROM local_audio_records WHERE id = file_name;"
        )

        for row in rows {
            let id: String = row["id"]
            let fileName: String = row["file_name"]
            let createTime: String = row["create_time"]
            let newID = LocalAudioRecord.makeID(fileName: fileName, createTime: createTime)
            guard id != newID else { continue }

            try db.execute(
                sql: """
                UPDATE local_audio_records
                SET id = ?
                WHERE id = ?
                  AND NOT EXISTS (SELECT 1 FROM local_audio_records WHERE id = ?);
                """,
                arguments: [newID, id, newID]
            )
        }
    }

    private func deleteMissingRecord(fileName: String) {
        do {
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM local_audio_records WHERE id = ?;", arguments: [fileName])
            }
        } catch {
            print("LocalAudioRecordManager delete missing record error: \(error)")
        }
    }

    private func rawLocalPath(for fileName: String) -> String? {
        do {
            return try dbQueue.read { db in
                try String.fetchOne(
                    db,
                    sql: "SELECT local_path FROM local_audio_records WHERE id = ? OR file_name = ? LIMIT 1;",
                    arguments: [fileName, fileName]
                )
            }
        } catch {
            print("LocalAudioRecordManager raw local path error: \(error)")
            return nil
        }
    }

    private func makeRecord(from row: Row) -> LocalAudioRecord {
        let displayName: String? = row["display_name"]
        return LocalAudioRecord(
            id: row["id"],
            fileName: row["file_name"],
            displayName: displayName,
            fileSize: row["file_size"],
            createTime: row["create_time"],
            localPath: row["local_path"],
            isDevice: row["is_device"],
            updatedAt: row["updated_at"]
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

}
