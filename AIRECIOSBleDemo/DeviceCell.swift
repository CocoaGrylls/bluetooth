import UIKit
import AIRECBleKit

class DeviceCell: UITableViewCell {
    static let reuseId = "DeviceCell"

    private let nameLabel  = UILabel()
    private let rssiLabel  = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        nameLabel.font = .systemFont(ofSize: 16, weight: .medium)
        rssiLabel.font = .systemFont(ofSize: 13)
        rssiLabel.textColor = .secondaryLabel
        rssiLabel.textAlignment = .right

        let stack = UIStackView(arrangedSubviews: [nameLabel, rssiLabel])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(device: AIRECBleDevice) {
        nameLabel.text = device.name
        rssiLabel.text = "\(device.rssi) dBm"
    }
}
