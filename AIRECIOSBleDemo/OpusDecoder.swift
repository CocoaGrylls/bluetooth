import Foundation

/// libopus 解码器的 Swift 封装
/// 将 Opus 编码帧解码为 16-bit PCM 数据
final class OpusDecoderWrapper {
    private var decoder: OpaquePointer?
    let sampleRate: Int32
    let channels: Int32

    init?(sampleRate: Int32 = 16000, channels: Int32 = 1) {
        self.sampleRate = sampleRate
        self.channels = channels
        var error: Int32 = 0
        decoder = opus_decoder_create(sampleRate, channels, &error)
        guard error == 0, decoder != nil else {
            print("OpusDecoder: 创建失败, error=\(error)")
            return nil
        }
    }

    deinit { if let d = decoder { opus_decoder_destroy(d) } }

    /// 解码单个 Opus 帧 → PCM Int16 数组
    /// frameSize: 每声道的样本数（16kHz 20ms = 320）
    func decode(opusData: [UInt8], frameSize: Int32 = 320) -> [Int16]? {
        guard let d = decoder else { return nil }
        var pcm = [Int16](repeating: 0, count: Int(frameSize * channels))
        let ret = opusData.withUnsafeBufferPointer { buf -> Int32 in
            opus_decode(d, buf.baseAddress, Int32(opusData.count),
                        &pcm, frameSize, 0)
        }
        guard ret > 0 else { return nil }
        return Array(pcm.prefix(Int(ret * channels)))
    }
}
