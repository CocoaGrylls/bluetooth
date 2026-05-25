import UIKit
import SnapKit

class ScanRippleView: UIView {

    private let bluetoothIcon = UIImageView()
    private let rippleLayerCount = 3
    private var rippleLayers: [CAShapeLayer] = []
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
        bluetoothIcon.image = UIImage(named: "bluetooth")
        bluetoothIcon.contentMode = .scaleAspectFit
        addSubview(bluetoothIcon)
        bluetoothIcon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(30)
        }

        setupRippleLayers()
    }

    private func setupRippleLayers() {
        rippleLayers.forEach { $0.removeFromSuperlayer() }
        rippleLayers.removeAll()

        for _ in 0..<rippleLayerCount {
            let rippleLayer = CAShapeLayer()
            rippleLayer.fillColor = UIColor.systemBlue.cgColor
            rippleLayer.opacity = 0
            layer.insertSublayer(rippleLayer, below: bluetoothIcon.layer)
            rippleLayers.append(rippleLayer)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = min(bounds.width, bounds.height) * 0.45
        let path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: size, height: size))
        let center = CGPoint(x: bluetoothIcon.frame.midX, y: bluetoothIcon.frame.midY)

        rippleLayers.forEach { rippleLayer in
            rippleLayer.path = path.cgPath
            rippleLayer.bounds = CGRect(x: 0, y: 0, width: size, height: size)
            rippleLayer.position = center
        }
    }

    // MARK: - 动画控制
    func startAnimation() {
        guard !isAnimating else { return }
        isAnimating = true

        rippleLayers.enumerated().forEach { index, rippleLayer in
            let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
            scaleAnimation.fromValue = 1.0
            scaleAnimation.toValue = 2.5

            let opacityAnimation = CABasicAnimation(keyPath: "opacity")
            opacityAnimation.fromValue = 0.35
            opacityAnimation.toValue = 0.0

            let group = CAAnimationGroup()
            group.animations = [scaleAnimation, opacityAnimation]
            group.duration = 2.5
            group.repeatCount = .infinity
            group.timingFunction = CAMediaTimingFunction(name: .easeOut)
            group.beginTime = CACurrentMediaTime() + Double(index) * 0.8

            rippleLayer.add(group, forKey: "ripple")
        }
    }

    func stopAnimation() {
        isAnimating = false
        rippleLayers.forEach { rippleLayer in
            rippleLayer.removeAllAnimations()
            rippleLayer.opacity = 0
        }
    }
}
