import UIKit
import SnapKit

final class DeviceSettingButtonCell: UITableViewCell {
    let button = UIButton(type: .system)
    private var buttonHandler: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        button.layer.cornerRadius = 10
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        button.addTarget(self, action: #selector(btnTapped), for: .touchUpInside)

        contentView.addSubview(button)
        button.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.top.equalToSuperview().offset(6)
            make.bottom.equalToSuperview().offset(-6)
            make.height.equalTo(44)
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, style: UIAlertAction.Style, handler: @escaping () -> Void) {
        button.setTitle(title, for: .normal)
        buttonHandler = handler
        switch style {
        case .destructive:
            button.backgroundColor = .systemRed
            button.setTitleColor(.white, for: .normal)
        case .cancel:
            button.backgroundColor = .white
            button.setTitleColor(.systemGray, for: .normal)
        default:
            button.backgroundColor = .white
            button.setTitleColor(.systemBlue, for: .normal)
        }
    }

    @objc private func btnTapped() {
        buttonHandler?()
    }
}
