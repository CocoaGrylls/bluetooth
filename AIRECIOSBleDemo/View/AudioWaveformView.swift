import UIKit

final class AudioWaveformView: UIView {

    var onSeekProgress: ((CGFloat) -> Void)?

    private var amplitudes: [CGFloat] = []
    private var progress: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        layer.cornerRadius = 0
        layer.borderWidth = 0
        clipsToBounds = true

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
        addGestureRecognizer(tapGesture)

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
        addGestureRecognizer(panGesture)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setAmplitudes(_ amplitudes: [CGFloat]) {
        self.amplitudes = amplitudes
        setNeedsDisplay()
    }

    func setProgress(_ progress: CGFloat) {
        self.progress = max(0, min(1, progress))
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.clear(rect)

        let values = amplitudes.isEmpty ? placeholderAmplitudes(count: 64) : amplitudes
        let horizontalInset: CGFloat = 28
        let verticalInset: CGFloat = 20
        let drawRect = rect.insetBy(dx: horizontalInset, dy: verticalInset)
        guard drawRect.width > 0, drawRect.height > 0 else { return }

        let spacing: CGFloat = 2
        let barCount = values.count
        let barWidth = max(2, (drawRect.width - CGFloat(barCount - 1) * spacing) / CGFloat(barCount))
        let progressX = drawRect.minX + drawRect.width * progress

        for (index, amplitude) in values.enumerated() {
            let x = drawRect.minX + CGFloat(index) * (barWidth + spacing)
            let height = max(4, drawRect.height * amplitude)
            let y = drawRect.midY - height / 2
            let barRect = CGRect(x: x, y: y, width: barWidth, height: height)
            let color = barRect.midX <= progressX ? Theme.audioBlue : UIColor(hex: 0xFFFFFF, alpha: 0.46)
            color.setFill()
            UIBezierPath(roundedRect: barRect, cornerRadius: barWidth / 2).fill()
        }
    }

    @objc private func handleGesture(_ gesture: UIGestureRecognizer) {
        let location = gesture.location(in: self)
        let progress = max(0, min(1, location.x / max(1, bounds.width)))
        setProgress(progress)
        onSeekProgress?(progress)
    }

    private func placeholderAmplitudes(count: Int) -> [CGFloat] {
        (0..<count).map { index in
            let angle = Double(index) / Double(count) * Double.pi * 4
            return CGFloat(0.22 + 0.18 * abs(sin(angle)))
        }
    }
}
