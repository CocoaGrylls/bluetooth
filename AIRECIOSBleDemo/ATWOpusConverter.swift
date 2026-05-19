import Foundation
import AudioToolbox
import AVFoundation

/// ATW 芯片私有 Opus 格式 → 标准 OGG Opus 文件转换器
/// ATW 格式：帧以 5B 50 分隔，每帧为 Opus 编码数据，16000Hz 单声道
/// KA 格式：设备固件新格式，帧以 4B 41 分隔，编码方式相同
final class ATWOpusConverter {

    private static let sampleRate: Int32 = 16000
    private static let channels: UInt8   = 1
    private static let frameSize: Int    = 320  // 20ms @ 16kHz

    /// 检测是否为支持的私有格式（ATW 或 KA）
    static func isSupportedPrivateFormat(path: String) -> (supported: Bool, format: String?) {
        guard let fh = FileHandle(forReadingAtPath: path) else { return (false, nil) }
        defer { try? fh.close() }
        guard let data = try? fh.read(upToCount: 2), data.count >= 2 else { return (false, nil) }
        let bytes = [UInt8](data)
        if bytes[0] == 0x5B && bytes[1] == 0x50 { return (true, "ATW") }
        if bytes[0] == 0x4B && bytes[1] == 0x41 { return (true, "KA") }
        return (false, nil)
    }

    /// 转换 ATW/KA 文件为 OGG Opus + CAF Opus，返回 CAF 路径
    static func convert(srcPath: String) -> String? {
        let cafPath = srcPath + ".caf"
        let oggPath = srcPath + ".opus"
        if FileManager.default.fileExists(atPath: cafPath) { return cafPath }

        do {
            let formatCheck = isSupportedPrivateFormat(path: srcPath)
            guard formatCheck.supported else {
                print("ATWOpusConverter: 不支持的格式: \(formatCheck.format ?? "未知")")
                return nil
            }
            print("ATWOpusConverter: 检测到 \(formatCheck.format!) 格式，开始转换...")

            let frames = try extractFrames(from: srcPath, format: formatCheck.format!)
            guard !frames.isEmpty else { return nil }
            print("ATWOpusConverter: 提取到 \(frames.count) 帧")

            try writeOggOpus(frames: frames, to: oggPath)
            try writeCafOpus(frames: frames, to: cafPath)
            return cafPath
        } catch {
            print("ATWOpusConverter: 转换失败 - \(error)")
            try? FileManager.default.removeItem(atPath: cafPath)
            if FileManager.default.fileExists(atPath: oggPath) { return oggPath }
            return nil
        }
    }

    // MARK: - Frame Extraction
    private static func extractFrames(from path: String, format: String) throws -> [[UInt8]] {
        print("ATWOpusConverter: 开始读取文件: \(path)")
        guard let data = FileManager.default.contents(atPath: path) else {
            throw NSError(domain: "ATW", code: 1, userInfo: [NSLocalizedDescriptionKey: "文件读取失败"])
        }
        print("ATWOpusConverter: 文件读取完成，大小: \(data.count) bytes")

        let raw = [UInt8](data)
        var frames: [[UInt8]] = []
        var i = 0
        let sep1: UInt8 = format == "ATW" ? 0x5B : 0x4B
        let sep2: UInt8 = format == "KA"  ? 0x41 : 0x50
        print("ATWOpusConverter: 开始扫描帧，分隔符=\(String(format:"%02X",sep1)) \(String(format:"%02X",sep2))")

        while i < raw.count - 1 {
            if raw[i] == sep1 && raw[i + 1] == sep2 {
                i += 2
                let start = i
                while i < raw.count - 1 {
                    if raw[i] == sep1 && raw[i + 1] == sep2 { break }
                    i += 1
                }
                if i > start {
                    frames.append(Array(raw[start..<i]))
                }
            } else {
                i += 1
            }
        }
        // 处理文件末尾可能无分隔符的残余帧
        if frames.count > 0 {
            var dataEnd = 0
            for f in frames { dataEnd += f.count + 2 }
            if dataEnd < raw.count {
                frames.append(Array(raw[dataEnd..<raw.count]))
            }
        }

        print("ATWOpusConverter: 扫描完成，找到 \(frames.count) 帧")
        return frames
    }

    // MARK: - OGG Opus Writer
    private static func writeOggOpus(frames: [[UInt8]], to outPath: String) throws {
        print("ATWOpusConverter writeOggOpus: 开始写入，帧数=\(frames.count)")
        var output = Data()
        let serialNo: UInt32 = 0x12345678
        var granulePos: Int64 = 0
        var seqNo: Int32 = 0

        let opusHead = buildOpusHead()
        output.append(buildOggPage(packets: [opusHead], serialNo: serialNo, granulePos: 0, seqNo: &seqNo, bos: true, eos: false))

        let opusTags = buildOpusTags()
        output.append(buildOggPage(packets: [opusTags], serialNo: serialNo, granulePos: 0, seqNo: &seqNo, bos: false, eos: false))

        var i = 0
        while i < frames.count {
            // OGG 页最多 255 个 segment，需要根据实际 lacing 计算每页能放多少帧
            var pageFrameCount = 0
            var segCount = 0
            while pageFrameCount < frames.count - i {
                let frameSegs = (frames[i + pageFrameCount].count / 255) + 1
                if segCount + frameSegs > 255 { break }
                segCount += frameSegs
                pageFrameCount += 1
            }
            if pageFrameCount == 0 { pageFrameCount = 1 }  // 至少放一帧
            granulePos += Int64(pageFrameCount * frameSize)
            let isLast = (i + pageFrameCount >= frames.count)
            let pageFrames = Array(frames[i..<(i + pageFrameCount)])
            output.append(buildOggPage(packets: pageFrames, serialNo: serialNo, granulePos: granulePos, seqNo: &seqNo, bos: false, eos: isLast))
            i += pageFrameCount
        }
        print("ATWOpusConverter writeOggOpus: 打包完成，output大小=\(output.count)，开始写入文件...")
        try output.write(to: URL(fileURLWithPath: outPath))
        // 验证前3页的头
        let bytes = [UInt8](output)
        var pageStart = 0
        for pageIdx in 0..<min(3, 10) {
            guard pageStart + 27 < bytes.count,
                  bytes[pageStart] == 0x4F, bytes[pageStart+1] == 0x67 else { break }
            let numSegs = Int(bytes[pageStart + 26])
            guard pageStart + 27 + numSegs <= bytes.count else { break }
            var dataLen = 0
            for s in 0..<numSegs { dataLen += Int(bytes[pageStart + 27 + s]) }
            let pageLen = 27 + numSegs + dataLen
            let hdr = bytes[pageStart..<min(pageStart+28+numSegs, bytes.count)]
            print("ATWOpusConverter: page[\(pageIdx)] offset=\(pageStart) len=\(pageLen) segs=\(numSegs) hdr=\(hdr.prefix(32).map{String(format:"%02X",$0)}.joined(separator:" "))")
            if pageIdx == 0 {
                // 打印 OpusHead 内容
                let opusStart = pageStart + 27 + numSegs
                let opusEnd = min(opusStart + dataLen, bytes.count)
                print("ATWOpusConverter: OpusHead=\(bytes[opusStart..<opusEnd].map{String(format:"%02X",$0)}.joined(separator:" "))")
            }
            pageStart += pageLen
        }
        print("ATWOpusConverter writeOggOpus: 文件写入完成")
    }

    private static func buildOggPage(packets: [[UInt8]], serialNo: UInt32, granulePos: Int64, seqNo: inout Int32, bos: Bool, eos: Bool) -> Data {
        // 构建 segment table（与 Android writeOggPageRaw 完全一致）
        var segTable: [UInt8] = []
        var allData: [Data] = []
        for pkt in packets {
            var remaining = pkt.count
            var offset = 0
            while remaining >= 255 {
                segTable.append(255)
                allData.append(Data(pkt[offset..<(offset+255)]))
                offset += 255; remaining -= 255
            }
            segTable.append(UInt8(remaining))
            allData.append(Data(pkt[offset..<(offset+remaining)]))
        }

        let numSegs = segTable.count
        // 组装页头（与 Android ByteBuffer.allocate(27 + numSegs) 完全一致）
        var headerBytes = [UInt8](repeating: 0, count: 27 + numSegs)
        // capture pattern "OggS"
        headerBytes[0] = 0x4F; headerBytes[1] = 0x67; headerBytes[2] = 0x67; headerBytes[3] = 0x53
        // version = 0
        headerBytes[4] = 0
        // header type
        var htype: UInt8 = 0
        if bos { htype |= 0x02 }
        if eos { htype |= 0x04 }
        headerBytes[5] = htype
        // granule position (int64 LE)
        let gp = UInt64(bitPattern: granulePos)
        for i in 0..<8 { headerBytes[6 + i] = UInt8((gp >> (i * 8)) & 0xFF) }
        // serial number (int32 LE)
        for i in 0..<4 { headerBytes[14 + i] = UInt8((serialNo >> (i * 8)) & 0xFF) }
        // page sequence number (int32 LE)
        let sn = UInt32(bitPattern: seqNo)
        for i in 0..<4 { headerBytes[18 + i] = UInt8((sn >> (i * 8)) & 0xFF) }
        // CRC placeholder (int32 LE) = 0
        headerBytes[22] = 0; headerBytes[23] = 0; headerBytes[24] = 0; headerBytes[25] = 0
        // number of segments
        headerBytes[26] = UInt8(numSegs)
        // segment table
        for i in 0..<numSegs { headerBytes[27 + i] = segTable[i] }

        // 合并 header + data
        var pageData = Data(headerBytes)
        for d in allData { pageData.append(d) }

        // 计算 CRC
        let crc = oggCrc32([UInt8](pageData))
        pageData[22] = UInt8(crc & 0xFF)
        pageData[23] = UInt8((crc >> 8) & 0xFF)
        pageData[24] = UInt8((crc >> 16) & 0xFF)
        pageData[25] = UInt8((crc >> 24) & 0xFF)

        seqNo += 1
        return pageData
    }

    private static func buildOpusHead() -> [UInt8] {
        // 标准 OpusHead = 19 bytes（与 Android ByteBuffer.allocate(19) 一致）
        var buf = Data()
        buf.append(contentsOf: "OpusHead".utf8)   // magic "OpusHead" (8 bytes)
        buf.append(1)                              // version = 1
        buf.append(channels)                       // channels = 1
        buf.appendLE16(UInt16(312))               // pre-skip
        buf.appendLE32(Int32(sampleRate))          // input sample rate = 16000
        buf.appendLE16(UInt16(0))                 // output gain = 0
        buf.append(0)                              // channel mapping family = 0
        return [UInt8](buf)
    }

    private static func buildOpusTags() -> [UInt8] {
        let vendor = "AIREC"
        var buf = Data()
        buf.append(contentsOf: "OpusTags".utf8)
        buf.appendLE32(Int32(vendor.count))
        buf.append(contentsOf: vendor.utf8)
        buf.appendLE32(0)
        return [UInt8](buf)
    }

    // MARK: - CAF Opus Writer（带 uuid chunk）
    private static func writeCafOpus(frames: [[UInt8]], to outPath: String) throws {
        var output = Data()

        // CAF Header: 'caff' + version(1) + flags(1)
        output.append(contentsOf: "caff".utf8)
        output.appendBE16(1); output.appendBE16(0)

        // DESC chunk - AudioStreamBasicDescription (32 bytes, big-endian)
        // mSampleRate(8) + mFormatID(4) + mFormatFlags(4) + mBytesPerPacket(4)
        // + mFramesPerPacket(4) + mChannelsPerFrame(4) + mBitsPerChannel(4)
        var desc = Data()
        desc.appendBEDouble(Double(sampleRate))       // mSampleRate: 16000.0
        desc.append(contentsOf: "opus".utf8)          // mFormatID: 'opus'
        desc.appendBE32(0)                            // mFormatFlags: 0 (interleaved Opus packets)
        desc.appendBE32(0)                            // mBytesPerPacket: variable
        desc.appendBE32(UInt32(frameSize))            // mFramesPerPacket: 320 @ 16kHz
        desc.appendBE32(UInt32(channels))            // mChannelsPerFrame: 1
        desc.appendBE32(0)                           // mBitsPerChannel: 0 (compressed)
        output.append(contentsOf: "desc".utf8)
        output.appendBE64(Int64(desc.count)); output.append(desc)

        // UUID chunk（必须！iOS 解码 Opus 的关键）
        let opusUUID = Data([
            0x8E, 0x7D, 0x6C, 0x5B, 0x4A, 0x3F, 0x47, 0xC8,
            0x9E, 0x8F, 0x7A, 0x6B, 0x5D, 0x4C, 0x3E, 0x2F
        ])
        output.append(contentsOf: "uuid".utf8)
        output.appendBE64(Int64(opusUUID.count)); output.append(opusUUID)

        // KUKI chunk: OpusHead
        let opusHead = Data(buildOpusHead())
        output.append(contentsOf: "kuki".utf8)
        output.appendBE64(Int64(opusHead.count)); output.append(opusHead)

        // PAKT chunk: packet table
        var pakt = Data()
        let totalValidFrames = Int64(frames.count) * Int64(frameSize)
        pakt.appendBE64(Int64(frames.count))
        pakt.appendBE64(totalValidFrames)
        pakt.appendBE32(0); pakt.appendBE32(0)
        for frame in frames { pakt.append(contentsOf: encodeVarLen(UInt32(frame.count))) }
        output.append(contentsOf: "pakt".utf8)
        output.appendBE64(Int64(pakt.count)); output.append(pakt)

        // DATA chunk
        var audioData = Data()
        for frame in frames { audioData.append(contentsOf: frame) }
        output.append(contentsOf: "data".utf8)
        output.appendBE64(Int64(audioData.count) + 4)
        output.appendBE32(0); output.append(audioData)

        try output.write(to: URL(fileURLWithPath: outPath))
    }

    private static func encodeVarLen(_ value: UInt32) -> [UInt8] {
        if value < 0x80 { return [UInt8(value)] }
        if value < 0x4000 { return [0x80 | UInt8(value >> 7), UInt8(value & 0x7F)] }
        if value < 0x200000 { return [0x80 | UInt8(value >> 14), 0x80 | UInt8((value >> 7) & 0x7F), UInt8(value & 0x7F)] }
        return [0x80 | UInt8(value >> 21), 0x80 | UInt8((value >> 14) & 0x7F), 0x80 | UInt8((value >> 7) & 0x7F), UInt8(value & 0x7F)]
    }

    // MARK: - 转码导出

    /// 转换 ATW/KA 文件为 OGG Opus，返回 .opus 文件路径
    /// AVPlayer 原生支持 OGG Opus（iOS 11+），无需转码
    static func convertToOggOpus(srcPath: String, completion: @escaping (String?) -> Void) {
        let oggPath = srcPath + ".ogg"

        DispatchQueue.global(qos: .userInitiated).async {
            // 超时保护：30秒后强制结束
            let timeoutWorkItem = DispatchWorkItem {
                print("ATWOpusConverter: ⚠️ 转换超时，强制结束")
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 30, execute: timeoutWorkItem)

            // 强制删除旧缓存重新生成（之前版本可能有 segment 溢出等问题）
            if FileManager.default.fileExists(atPath: oggPath) {
                try? FileManager.default.removeItem(atPath: oggPath)
            }

            do {
                let formatCheck = isSupportedPrivateFormat(path: srcPath)
                print("ATWOpusConverter: 格式检测结果 = \(formatCheck)")
                guard formatCheck.supported else {
                    print("ATWOpusConverter: 格式不支持")
                    timeoutWorkItem.cancel()
                    DispatchQueue.main.async { completion(nil) }; return
                }

                let frames = try extractFrames(from: srcPath, format: formatCheck.format!)
                print("ATWOpusConverter: 提取帧完成，frameCount=\(frames.count)")
                guard !frames.isEmpty else {
                    print("ATWOpusConverter: 帧为空")
                    timeoutWorkItem.cancel()
                    DispatchQueue.main.async { completion(nil) }; return
                }

                print("ATWOpusConverter: 开始写入 OGG: \(oggPath)")
                try writeOggOpus(frames: frames, to: oggPath)
                print("ATWOpusConverter: OGG 写入完成")

                timeoutWorkItem.cancel()
                let exists = FileManager.default.fileExists(atPath: oggPath)
                print("ATWOpusConverter: OGG 文件存在: \(exists)")
                DispatchQueue.main.async { completion(exists ? oggPath : nil) }
            } catch {
                print("ATWOpusConverter: OGG 转换失败 - \(error)")
                timeoutWorkItem.cancel()
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    /// ATW/KA → M4A (AAC)，依赖 ExtAudioFile Opus 解码器
    /// ⚠️ 注意：iOS 上 ExtAudioFile 的 Opus 解码器有 bug（AudioCodecInitialize failed），
    ///          在部分设备/iOS版本上不可用，建议改用 convertToOggOpus + AVPlayer
    static func convertToM4A(srcPath: String, completion: @escaping (String?) -> Void) {
        let cafPath = srcPath + ".caf"
        let m4aPath = srcPath + ".m4a"

        DispatchQueue.global(qos: .userInitiated).async {
            if !FileManager.default.fileExists(atPath: cafPath) {
                let formatCheck = isSupportedPrivateFormat(path: srcPath)
                guard formatCheck.supported,
                      let frames = try? extractFrames(from: srcPath, format: formatCheck.format!),
                      !frames.isEmpty else { DispatchQueue.main.async { completion(nil) }; return }
                guard (try? writeCafOpus(frames: frames, to: cafPath)) != nil else { DispatchQueue.main.async { completion(nil) }; return }
            }
            transcodeCAF(cafPath, to: m4aPath, format: .m4a) { ok in
                DispatchQueue.main.async { completion(ok ? m4aPath : nil) }
            }
        }
    }

    /// ATW/KA → WAV (PCM)，使用 libopus 直接解码 Opus 帧
    /// 不依赖任何 iOS 系统 Opus 解码器，100% 可靠
    static func convertToWAV(srcPath: String, completion: @escaping (String?) -> Void) {
        let wavPath = srcPath + ".wav"

        DispatchQueue.global(qos: .userInitiated).async {
            let formatCheck = isSupportedPrivateFormat(path: srcPath)
            guard formatCheck.supported,
                  let format = formatCheck.format else {
                print("ATWOpusConverter: 格式不支持")
                DispatchQueue.main.async { completion(nil) }; return
            }

            // 直接读取原始文件，按 airecdev 的方式提取帧（帧数据包含分隔符头）
            guard let fileData = FileManager.default.contents(atPath: srcPath) else {
                DispatchQueue.main.async { completion(nil) }; return
            }
            let raw = [UInt8](fileData)
            let sep0: UInt8 = format == "ATW" ? 0x5B : 0x4B
            let sep1: UInt8 = format == "ATW" ? 0x50 : 0x41

            // 与 airecdev reDecodeOpusToWav 完全一致的帧提取方式
            var frames: [[UInt8]] = []
            var start = 0
            for i in 0..<(raw.count - 1) {
                if raw[i] == sep0 && raw[i + 1] == sep1 {
                    if i > start {
                        // 每帧前面加上分隔符头（与 airecdev 一致）
                        var chunk = [sep0, sep1]
                        chunk.append(contentsOf: raw[start..<i])
                        frames.append(chunk)
                    }
                    start = i + 2
                }
            }
            // 最后一帧
            if start < raw.count {
                var chunk = [sep0, sep1]
                chunk.append(contentsOf: raw[start..<raw.count])
                frames.append(chunk)
            }

            guard !frames.isEmpty else {
                print("ATWOpusConverter: 帧提取失败")
                DispatchQueue.main.async { completion(nil) }; return
            }

            print("ATWOpusConverter: 开始 libopus 解码 \(frames.count) 帧...")
            guard let decoder = OpusDecoderWrapper(sampleRate: 16000, channels: 1) else {
                print("ATWOpusConverter: libopus 解码器创建失败")
                DispatchQueue.main.async { completion(nil) }; return
            }

            var allPCM = Data()
            var decodedCount = 0
            for frame in frames {
                if frame.count <= 4 { continue }  // 跳过太短的帧（与 airecdev 一致）
                if let pcm = decoder.decode(opusData: frame, frameSize: 320) {
                    if pcm.count == 320 {  // 只接受完整帧（与 airecdev pcm.length == 640 bytes = 320 samples × 2 一致）
                        for sample in pcm {
                            var s = sample
                            allPCM.append(Data(bytes: &s, count: 2))
                        }
                        decodedCount += 1
                    }
                }
            }

            guard decodedCount > 0 else {
                print("ATWOpusConverter: libopus 解码全部失败")
                DispatchQueue.main.async { completion(nil) }; return
            }

            print("ATWOpusConverter: libopus 解码完成, \(decodedCount)/\(frames.count) 帧, PCM=\(allPCM.count) bytes")

            // 写 WAV 文件
            try? FileManager.default.removeItem(atPath: wavPath)
            FileManager.default.createFile(atPath: wavPath, contents: nil)
            guard let wavFile = FileHandle(forWritingAtPath: wavPath) else {
                DispatchQueue.main.async { completion(nil) }; return
            }

            let sr: UInt32 = 16000
            let ch: UInt16 = 1
            let bitsPerSample: UInt16 = 16
            let byteRate = sr * UInt32(ch) * UInt32(bitsPerSample / 8)
            let blockAlign = ch * (bitsPerSample / 8)
            let dataSize = UInt32(allPCM.count)
            let fileSize = dataSize + 36

            var header = Data(count: 44)
            header.replaceSubrange(0..<4, with: "RIFF".utf8)
            header[4] = UInt8(fileSize & 0xFF); header[5] = UInt8((fileSize >> 8) & 0xFF)
            header[6] = UInt8((fileSize >> 16) & 0xFF); header[7] = UInt8((fileSize >> 24) & 0xFF)
            header.replaceSubrange(8..<12, with: "WAVE".utf8)
            header.replaceSubrange(12..<16, with: "fmt ".utf8)
            header[16] = 16; header[17] = 0; header[18] = 0; header[19] = 0
            header[20] = 1; header[21] = 0
            header[22] = UInt8(ch & 0xFF); header[23] = UInt8((ch >> 8) & 0xFF)
            header[24] = UInt8(sr & 0xFF); header[25] = UInt8((sr >> 8) & 0xFF)
            header[26] = UInt8((sr >> 16) & 0xFF); header[27] = UInt8((sr >> 24) & 0xFF)
            header[28] = UInt8(byteRate & 0xFF); header[29] = UInt8((byteRate >> 8) & 0xFF)
            header[30] = UInt8((byteRate >> 16) & 0xFF); header[31] = UInt8((byteRate >> 24) & 0xFF)
            header[32] = UInt8(blockAlign & 0xFF); header[33] = UInt8((blockAlign >> 8) & 0xFF)
            header[34] = UInt8(bitsPerSample & 0xFF); header[35] = UInt8((bitsPerSample >> 8) & 0xFF)
            header.replaceSubrange(36..<40, with: "data".utf8)
            header[40] = UInt8(dataSize & 0xFF); header[41] = UInt8((dataSize >> 8) & 0xFF)
            header[42] = UInt8((dataSize >> 16) & 0xFF); header[43] = UInt8((dataSize >> 24) & 0xFF)

            wavFile.write(header)
            wavFile.write(allPCM)
            wavFile.closeFile()

            let wavSize = (try? FileManager.default.attributesOfItem(atPath: wavPath)[.size] as? Int) ?? 0
            let duration = allPCM.count / Int(byteRate)
            print("ATWOpusConverter: WAV 写入成功: \(wavSize) bytes, 时长≈\(duration)s")
            DispatchQueue.main.async { completion(wavPath) }
        }
    }

    private enum OutputFormat { case m4a, wav }

    private static func transcodeCAF(_ cafPath: String, to outPath: String, format: OutputFormat, completion: @escaping (Bool) -> Void) {
        let srcURL = URL(fileURLWithPath: cafPath) as CFURL
        let dstURL = URL(fileURLWithPath: outPath) as CFURL
        try? FileManager.default.removeItem(atPath: outPath)

        var srcFile: ExtAudioFileRef?
        var status = ExtAudioFileOpenURL(srcURL, &srcFile)
        guard status == noErr, let src = srcFile else { completion(false); return }

        var srcDesc = AudioStreamBasicDescription()
        var descSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        status = ExtAudioFileGetProperty(src, kExtAudioFileProperty_FileDataFormat, &descSize, &srcDesc)
        guard status == noErr else { ExtAudioFileDispose(src); completion(false); return }

        let sr = srcDesc.mSampleRate > 0 ? srcDesc.mSampleRate : Double(sampleRate)
        let ch = srcDesc.mChannelsPerFrame > 0 ? srcDesc.mChannelsPerFrame : UInt32(channels)

        var clientDesc = AudioStreamBasicDescription(
            mSampleRate: sr, mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 2 * ch, mFramesPerPacket: 1,
            mBytesPerFrame: 2 * ch, mChannelsPerFrame: ch,
            mBitsPerChannel: 16, mReserved: 0
        )
        status = ExtAudioFileSetProperty(src, kExtAudioFileProperty_ClientDataFormat,
                                         UInt32(MemoryLayout<AudioStreamBasicDescription>.size), &clientDesc)
        guard status == noErr else { ExtAudioFileDispose(src); completion(false); return }

        var dstFileType: AudioFileTypeID
        var dstDesc: AudioStreamBasicDescription

        switch format {
        case .wav:
            dstFileType = kAudioFileWAVEType
            dstDesc = clientDesc
        case .m4a:
            dstFileType = kAudioFileM4AType
            dstDesc = AudioStreamBasicDescription(
                mSampleRate: sr, mFormatID: kAudioFormatMPEG4AAC,
                mFormatFlags: 0, mBytesPerPacket: 0, mFramesPerPacket: 1024,
                mBytesPerFrame: 0, mChannelsPerFrame: ch, mBitsPerChannel: 0, mReserved: 0
            )
        }

        var dstFile: ExtAudioFileRef?
        status = ExtAudioFileCreateWithURL(dstURL, dstFileType, &dstDesc, nil, AudioFileFlags.eraseFile.rawValue, &dstFile)
        guard status == noErr, let dst = dstFile else { ExtAudioFileDispose(src); completion(false); return }

        if format == .m4a {
            status = ExtAudioFileSetProperty(dst, kExtAudioFileProperty_ClientDataFormat,
                                             UInt32(MemoryLayout<AudioStreamBasicDescription>.size), &clientDesc)
            guard status == noErr else { ExtAudioFileDispose(src); ExtAudioFileDispose(dst); completion(false); return }
        }

        let bufFrames: UInt32 = 4096
        let bufSize = Int(bufFrames * clientDesc.mBytesPerFrame)
        let rawBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        defer { rawBuf.deallocate() }

        var done = false
        while !done {
            var bufList = AudioBufferList(
                mNumberBuffers: 1,
                mBuffers: AudioBuffer(mNumberChannels: ch, mDataByteSize: UInt32(bufSize), mData: rawBuf)
            )
            var frameCount = bufFrames
            status = ExtAudioFileRead(src, &frameCount, &bufList)
            if status != noErr || frameCount == 0 { done = true; break }
            bufList.mBuffers.mDataByteSize = frameCount * clientDesc.mBytesPerFrame
            status = ExtAudioFileWrite(dst, frameCount, &bufList)
            if status != noErr { done = true }
        }

        ExtAudioFileDispose(src); ExtAudioFileDispose(dst)
        completion(FileManager.default.fileExists(atPath: outPath) && status == noErr)
    }

    // MARK: - CRC
    private static let crcTable: [UInt32] = {
        var table = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var crc = UInt32(i) << 24
            for _ in 0..<8 { crc = (crc & 0x80000000) != 0 ? (crc << 1) ^ 0x04c11db7 : crc << 1 }
            table[i] = crc
        }
        return table
    }()

    private static func oggCrc32(_ data: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0
        for b in data { crc = (crc << 8) ^ crcTable[Int((crc >> 24) ^ UInt32(b)) & 0xFF] }
        return crc
    }
}

// MARK: - Data helpers
private extension Data {
    mutating func appendLE16(_ v: UInt16) { append(UInt8(v & 0xFF)); append(UInt8((v >> 8) & 0xFF)) }
    mutating func appendLE32(_ v: Int32) {
        let u = UInt32(bitPattern: v)
        append(UInt8(u & 0xFF)); append(UInt8((u >> 8) & 0xFF)); append(UInt8((u >> 16) & 0xFF)); append(UInt8((u >> 24) & 0xFF))
    }
    mutating func appendLE64(_ v: Int64) {
        let u = UInt64(bitPattern: v)
        for shift in stride(from: 0, to: 64, by: 8) { append(UInt8((u >> shift) & 0xFF)) }
    }
    mutating func appendBE16(_ v: UInt16) { append(UInt8((v >> 8) & 0xFF)); append(UInt8(v & 0xFF)) }
    mutating func appendBE32(_ v: UInt32) {
        append(UInt8((v >> 24) & 0xFF)); append(UInt8((v >> 16) & 0xFF))
        append(UInt8((v >> 8) & 0xFF)); append(UInt8(v & 0xFF))
    }
    mutating func appendBE64(_ v: Int64) {
        let u = UInt64(bitPattern: v)
        for shift in stride(from: 56, through: 0, by: -8) { append(UInt8((u >> shift) & 0xFF)) }
    }
    mutating func appendBEDouble(_ v: Double) { appendBE64(Int64(bitPattern: v.bitPattern)) }
}
