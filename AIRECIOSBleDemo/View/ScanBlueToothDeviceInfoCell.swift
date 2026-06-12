import UIKit
import AIRECBleKit
import SnapKit

class ScanBlueToothDeviceInfoCell: UITableViewCell {
    static let reuseId = "DeviceCell"
    //block: 连接按钮点击事件回调
    var connectButtonTapped: (() -> Void)?

    private let iconView = UIImageView()
    private let nameLabel = UILabel()
    private let signalLabel = UILabel()
    let connectButton = UIButton(type: .system)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        // 麦克风图片
        iconView.image = UIImage(named: "micphone")
        iconView.backgroundColor = UIColor.lightGray
        iconView.layer.cornerRadius = 30
        iconView.clipsToBounds = true
        iconView.contentMode = .center
        contentView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(60)
        }

        // 设备名称
        nameLabel.font = .systemFont(ofSize: 16, weight: .medium)
        nameLabel.textColor = .label

        // 信号
        signalLabel.font = .systemFont(ofSize: 13)
        signalLabel.textColor = .secondaryLabel

        // 垂直堆叠
        let vStack = UIStackView(arrangedSubviews: [nameLabel, signalLabel])
        vStack.axis = .vertical
        vStack.spacing = 2
        contentView.addSubview(vStack)
        vStack.snp.makeConstraints { make in
            make.left.equalTo(iconView.snp.right).offset(12)
            make.centerY.equalToSuperview()
        }

        // 连接按钮
        connectButton.setTitle("连接", for: .normal)
        connectButton.setTitleColor(.systemBlue, for: .normal)
        connectButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        connectButton.layer.cornerRadius = 6
        connectButton.layer.borderWidth = 1
        connectButton.layer.borderColor = UIColor.systemBlue.cgColor
        contentView.addSubview(connectButton)
        connectButton.addTarget(self, action: #selector(connectTapped), for: .touchUpInside)
        connectButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.equalTo(60)
            make.height.equalTo(32)
            make.left.greaterThanOrEqualTo(vStack.snp.right).offset(8)
        }
    }

    @objc private func connectTapped() {
        // Handle connect button tap
        print("Connect button tapped")
        connectButtonTapped?()
    }

    func configure(device: AIRECBleDevice) {
        nameLabel.text = device.name
        signalLabel.text = "信号: \(convertRSSIToStrength(rssi: device.rssi))"
    }
    //转换信号device.rssi为强度
    private func convertRSSIToStrength(rssi: Int) -> String {
        switch rssi {
        case -100...(-80):
            return "弱"
        case -79...(-60):
            return "中"
        case -59...0:
            return "强"
        default:
            return "未知"
        }
    }

}
