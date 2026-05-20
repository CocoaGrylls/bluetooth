import UIKit
import SnapKit

class ScanPeripheralView: UIView {

    private let imageView = UIImageView()
    private let pulseLayer = CAShapeLayer()
    private let animationGroup = CAAnimationGroup()
    private var isAnimating = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        // 蓝牙图标
        imageView.image = UIImage(named: "bluetooth")
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(48)
        }

        // 雷达脉冲层
        pulseLayer.fillColor = UIColor.systemBlue.withAlphaComponent(0.2).cgColor
        layer.insertSublayer(pulseLayer, below: imageView.layer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let radius = min(bounds.width, bounds.height) / 2 - 10
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let path = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        pulseLayer.path = path.cgPath
        pulseLayer.frame = bounds
    }

    // MARK: - 动画控制
    func startAnimation() {
        guard !isAnimating else { return }
        isAnimating = true

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.7
        scale.toValue = 1.2

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0.6
        opacity.toValue = 0.0

        animationGroup.animations = [scale, opacity]
        animationGroup.duration = 1.2
        animationGroup.repeatCount = .infinity
        animationGroup.timingFunction = CAMediaTimingFunction(name: .easeOut)

        pulseLayer.add(animationGroup, forKey: "radar")
    }

    func stopAnimation() {
        isAnimating = false
        pulseLayer.removeAllAnimations()
    }
}
