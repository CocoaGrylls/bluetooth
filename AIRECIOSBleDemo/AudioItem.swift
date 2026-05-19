import Foundation
import AIRECBleKit

// MARK: - 统一音频条目模型
struct AudioItem: Codable, Identifiable {
    let id: String          // 唯一标识 = fileName
    let fileName: String
    let fileSize: Int64
    let createTime: String  // "yyyy-MM-dd HH:mm:ss"
    var localPath: String?  // 本地路径，nil 表示未下载

    var isLocal: Bool { localPath != nil && FileManager.default.fileExists(atPath: localPath ?? "") }
    var isDevice: Bool = true  // 是否在设备上

    var fileSizeStr: String {
        if fileSize < 1024 { return "\(fileSize) B" }
        if fileSize < 1024 * 1024 { return String(format: "%.1f KB", Double(fileSize) / 1024) }
        return String(format: "%.1f MB", Double(fileSize) / (1024 * 1024))
    }

    // 从 AIRECBleFile 构建
    init(from file: AIRECBleFile, localPath: String? = nil) {
        self.id = file.fileName
        self.fileName = file.fileName
        self.fileSize = file.fileSize
        self.createTime = file.createTime
        self.localPath = localPath
        self.isDevice = true
    }

    // 纯本地条目
    init(fileName: String, fileSize: Int64, createTime: String, localPath: String) {
        self.id = fileName
        self.fileName = fileName
        self.fileSize = fileSize
        self.createTime = createTime
        self.localPath = localPath
        self.isDevice = false
    }
}

// MARK: - 本地音频持久化存储
final class AudioStore {
    static let shared = AudioStore()
    private init() {}

    private let key = "airec_local_audio_items"

    // 读取所有本地已下载条目
    func loadLocalItems() -> [AudioItem] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let items = try? JSONDecoder().decode([AudioItem].self, from: data) else { return [] }
        // 过滤掉文件已被删除的条目
        return items.filter { item in
            guard let path = item.localPath else { return false }
            return FileManager.default.fileExists(atPath: path)
        }
    }

    // 保存/更新一条本地条目
    func save(_ item: AudioItem) {
        var items = loadLocalItems()
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx] = item
        } else {
            items.append(item)
        }
        persist(items)
    }

    // 删除一条本地条目（同时删除文件）
    func delete(id: String) {
        var items = loadLocalItems()
        if let idx = items.firstIndex(where: { $0.id == id }) {
            if let path = items[idx].localPath {
                try? FileManager.default.removeItem(atPath: path)
            }
            items.remove(at: idx)
        }
        persist(items)
    }

    // 获取某文件的本地路径
    func localPath(for fileName: String) -> String? {
        loadLocalItems().first(where: { $0.id == fileName })?.localPath
    }

    private func persist(_ items: [AudioItem]) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - 过滤类型
enum AudioFilter: Int {
    case all = 0, device, local
    var title: String {
        switch self { case .all: return "全部"; case .device: return "设备音频"; case .local: return "本地音频" }
    }
}
