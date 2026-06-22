import UIKit
import SnapKit

/// 上方为配置行（图标 + 标题 + 副标题 + 箭头），下方为说明文字
final class DeviceSettingDisclosureWithHintCell: UITableViewCell {
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let stackView = UIStackView()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let hintLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .white
        selectionStyle = .gray

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

        hintLabel.font = .systemFont(ofSize: 15)
        hintLabel.textColor = .secondaryLabel
        hintLabel.numberOfLines = 0

        contentView.addSubview(iconImageView)
        contentView.addSubview(stackView)
        contentView.addSubview(chevron)
        contentView.addSubview(hintLabel)

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)

        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(14)
            make.width.height.equalTo(22)
        }
        stackView.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(10)
            make.trailing.equalTo(chevron.snp.leading).offset(-8)
            make.centerY.equalTo(iconImageView)
        }
        chevron.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalTo(iconImageView)
            make.width.equalTo(8)
            make.height.equalTo(14)
        }
        hintLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.top.equalTo(iconImageView.snp.bottom).offset(10)
            make.bottom.equalToSuperview().offset(-14)
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(icon: String, title: String, subtitle: String, hint: String) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        iconImageView.image = UIImage(systemName: icon) ?? UIImage()
        hintLabel.text = hint
    }
}
