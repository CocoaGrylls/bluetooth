import Foundation
import AIRECBleKit

// MARK: - 数据库本地音频模型
final class LocalAudioRecord: Identifiable {
    let id: String
    let fileName: String
    let displayName: String
    let fileSize: Int64
    let createTime: String
    let localPath: String
    let isDevice: Bool
    let updatedAt: Int64

    init(
        id: String? = nil,
        fileName: String,
        displayName: String? = nil,
        fileSize: Int64,
        createTime: String,
        localPath: String,
        isDevice: Bool,
        updatedAt: Int64 = Int64(Date().timeIntervalSince1970)
    ) {
        self.id = id ?? Self.makeID(fileName: fileName, createTime: createTime)
        self.fileName = fileName
        self.displayName = displayName ?? fileName
        self.fileSize = fileSize
        self.createTime = createTime
        self.localPath = localPath
        self.isDevice = isDevice
        self.updatedAt = updatedAt
    }

    convenience init(from file: AIRECBleFile, localPath: String) {
        self.init(
            fileName: file.fileName,
            fileSize: file.fileSize,
            createTime: file.createTime,
            localPath: localPath,
            isDevice: true
        )
    }

    var fileExists: Bool {
        FileManager.default.fileExists(atPath: resolvedLocalPath)
    }

    var resolvedLocalPath: String {
        if localPath.hasPrefix("/") {
            return localPath
        }

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent(localPath).path
    }

    var audioItem: AudioItem {
        var item = AudioItem(fileName: fileName, fileSize: fileSize, createTime: createTime, localPath: resolvedLocalPath)
        item.isDevice = isDevice
        return item
    }

    static func makeID(fileName: String, createTime: String) -> String {
        "\(fileName)|\(createTime)"
    }
}
