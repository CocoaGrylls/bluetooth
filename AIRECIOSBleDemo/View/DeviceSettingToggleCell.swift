import UIKit
import SnapKit

final class DeviceSettingToggleCell: UITableViewCell {
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    let toggleSwitch = UISwitch()
    private var toggleHandler: ((Bool) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .white
        selectionStyle = .none

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .systemBlue

        titleLabel.font = .systemFont(ofSize: 16)
        titleLabel.textColor = .black

        toggleSwitch.onTintColor = .systemRed
        toggleSwitch.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)

        contentView.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(toggleSwitch)

        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(22)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(10)
            make.centerY.equalToSuperview()
        }
        toggleSwitch.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(icon: String, title: String, isOn: Bool, handler: @escaping (Bool) -> Void) {
        titleLabel.text = title
        iconImageView.image = UIImage(systemName: icon) ?? UIImage()
        toggleSwitch.isOn = isOn
        toggleHandler = handler
    }

    @objc private func toggleChanged() {
        toggleHandler?(toggleSwitch.isOn)
    }
}
