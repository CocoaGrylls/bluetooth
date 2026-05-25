import UIKit
import SnapKit

class EmptyAIRECDeviceCell: UITableViewCell {

    static let reuseId = "EmptyAIRECDeviceCell"

    private let emptyLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        selectionStyle = .none
        emptyLabel.text = "暂无可用AIREC设备"
        emptyLabel.font = .systemFont(ofSize: 16)
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        contentView.addSubview(emptyLabel)
        emptyLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }
    }
}
