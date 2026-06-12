import AVFoundation
import CoreGraphics
import Foundation

final class AudioWaveformAnalyzer {

    private init() {}

    static func analyze(path: String, sampleCount: Int = 96, completion: @escaping ([CGFloat]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let samples = makeSamples(path: path, sampleCount: sampleCount)
            DispatchQueue.main.async {
                completion(samples)
            }
        }
    }

    private static func makeSamples(path: String, sampleCount: Int) -> [CGFloat] {
        do {
            let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
            let totalFrames = max(1, Int(file.length))
            let targetCount = max(24, sampleCount)
            let bucketSize = max(1.0, Double(totalFrames) / Double(targetCount))
            var peaks = Array(repeating: Float(0), count: targetCount)

            let readSize: AVAudioFrameCount = 4096
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: readSize) else {
                return placeholderSamples(count: targetCount)
            }

            var globalFrame = 0
            while globalFrame < totalFrames {
                try file.read(into: buffer, frameCount: min(readSize, AVAudioFrameCount(totalFrames - globalFrame)))
                let frameLength = Int(buffer.frameLength)
                guard frameLength > 0 else { break }

                if let channelData = buffer.floatChannelData {
                    let channelCount = max(1, Int(buffer.format.channelCount))
                    for frameIndex in 0..<frameLength {
                        var value = Float(0)
                        for channel in 0..<channelCount {
                            value = max(value, abs(channelData[channel][frameIndex]))
                        }
                        let bucket = min(targetCount - 1, Int(Double(globalFrame + frameIndex) / bucketSize))
                        peaks[bucket] = max(peaks[bucket], value)
                    }
                }
                globalFrame += frameLength
            }

            let maxPeak = max(peaks.max() ?? 0, 0.0001)
            return peaks.map { peak in
                let normalized = CGFloat(peak / maxPeak)
                return max(0.08, min(1, normalized))
            }
        } catch {
            return placeholderSamples(count: sampleCount)
        }
    }

    private static func placeholderSamples(count: Int) -> [CGFloat] {
        let targetCount = max(24, count)
        return (0..<targetCount).map { index in
            let angle = Double(index) / Double(targetCount) * Double.pi * 4
            return CGFloat(0.22 + 0.18 * abs(sin(angle)))
        }
    }
}
