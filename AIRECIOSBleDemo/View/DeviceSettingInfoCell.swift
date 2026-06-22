import UIKit
import SnapKit

final class DeviceSettingInfoCell: UITableViewCell {
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .white
        selectionStyle = .none
        contentView.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)

        titleLabel.font = .systemFont(ofSize: 16)
        titleLabel.textColor = .black

        valueLabel.font = .systemFont(ofSize: 15)
        valueLabel.textColor = .black
        valueLabel.textAlignment = .right

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .systemBlue

        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(22)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(10)
            make.centerY.equalToSuperview()
        }
        valueLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8)
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(icon: String, title: String, value: String) {
        titleLabel.text = title
        valueLabel.text = value
        iconImageView.image = UIImage(systemName: icon) ?? UIImage()
    }
}
