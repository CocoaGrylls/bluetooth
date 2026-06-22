import UIKit
import SnapKit

final class DeviceSettingDisclosureCell: UITableViewCell {
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let stackView = UIStackView()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .white
        selectionStyle = .gray
        accessoryView = nil

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .systemBlue

        titleLabel.font = .systemFont(ofSize: 16)
        titleLabel.textColor = .black

        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .right
        subtitleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        chevron.tintColor = .systemGray3
        chevron.contentMode = .scaleAspectFit

        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center

        contentView.addSubview(iconImageView)
        contentView.addSubview(stackView)
        contentView.addSubview(chevron)

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)

        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(22)
        }
        stackView.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(10)
            make.trailing.equalTo(chevron.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
        }
        chevron.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.equalTo(8)
            make.height.equalTo(14)
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(icon: String, title: String, subtitle: String) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        iconImageView.image = UIImage(systemName: icon) ?? UIImage()
    }
}
