import Foundation

final class AudioFormatDetector {

    private init() {}

    static func getAudioIdentifyType(path: String) -> String? {
        guard let fileHandle = FileHandle(forReadingAtPath: path),
              let headerData = try? fileHandle.read(upToCount: 12),
              headerData.count >= 8 else {
            return nil
        }
        try? fileHandle.close()

        let bytes = [UInt8](headerData)
        if bytes[0] == 0x63 && bytes[1] == 0x61 && bytes[2] == 0x66 && bytes[3] == 0x66 { return ".caf" }
        if bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33 { return ".mp3" }
        if bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0 { return ".mp3" }
        if bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 { return ".wav" }
        if bytes[0] == 0x4F && bytes[1] == 0x67 && bytes[2] == 0x67 && bytes[3] == 0x53 { return ".opus" }
        if bytes[0] == 0xFF && (bytes[1] & 0xF0) == 0xF0 { return ".aac" }
        if bytes[0] == 0x66 && bytes[1] == 0x4C && bytes[2] == 0x61 && bytes[3] == 0x43 { return ".flac" }
        if bytes[0] == 0x23 && bytes[1] == 0x21 && bytes[2] == 0x41 && bytes[3] == 0x4D { return ".amr" }
        if bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70 { return ".m4a" }
        if bytes[0] == 0x5B && bytes[1] == 0x50 { return ".atw" }
        if bytes[0] == 0x4B && bytes[1] == 0x41 { return ".ka" }
        return nil
    }
}
