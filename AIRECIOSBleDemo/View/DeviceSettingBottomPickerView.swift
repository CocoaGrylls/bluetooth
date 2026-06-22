import UIKit
import SnapKit

final class DeviceSettingBottomPickerView: UIView {

    private let dimView = UIView()
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let separatorLine = UIView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let cancelButton = UIButton(type: .system)
    private let buttonSeparator = UIView()

    private var items: [String] = []
    private var defaultIndex: Int = -1
    private var didSelect: ((Int, String) -> Void)?
    private var didCancel: (() -> Void)?
    private var rowHeight: CGFloat = 52

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupSubviews() {
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        dimView.alpha = 0
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissTapped))
        dimView.addGestureRecognizer(tap)

        containerView.backgroundColor = UIColor(white: 0.97, alpha: 1.0)
        containerView.layer.cornerRadius = 14
        containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        containerView.clipsToBounds = true

        titleLabel.font = .systemFont(ofSize: 15)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center

        separatorLine.backgroundColor = UIColor(white: 0.88, alpha: 1.0)
        buttonSeparator.backgroundColor = UIColor(white: 0.88, alpha: 1.0)

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.rowHeight = rowHeight
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(DeviceSettingPickerCell.self, forCellReuseIdentifier: "pickerRow")

        cancelButton.setTitle("取消", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.backgroundColor = .white
        cancelButton.layer.cornerRadius = 12
    }

    private func layout(in superview: UIView) {
        if dimView.superview == nil {
            addSubview(dimView)
            addSubview(containerView)
        }
        containerView.addSubview(titleLabel)
        containerView.addSubview(separatorLine)
        containerView.addSubview(tableView)
        containerView.addSubview(buttonSeparator)
        containerView.addSubview(cancelButton)

        snp.makeConstraints { make in
            make.edges.equalTo(superview)
        }
        dimView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let maxHeight = superview.bounds.height * 0.72
        let contentH = CGFloat(items.count) * rowHeight
        let headerH: CGFloat = 48
        let cancelH: CGFloat = 56
        let total = headerH + contentH + cancelH
        let containerH = min(total, maxHeight)
        let tableScroll = total > maxHeight

        containerView.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(containerH)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(6)
            make.height.equalTo(30)
        }

        separatorLine.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom)
            make.height.equalTo(1)
        }

        tableView.isScrollEnabled = tableScroll

        tableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(separatorLine.snp.bottom)
            make.bottom.equalTo(cancelButton.snp.top)
        }

        buttonSeparator.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(1)
            make.bottom.equalTo(cancelButton.snp.top)
        }

        cancelButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().offset(-12)
            make.bottom.equalToSuperview().offset(-14)
            make.height.equalTo(cancelH)
        }
    }

    func configure(title: String, items: [String],
                   defaultIndex: Int = -1,
                   didSelect: @escaping (Int, String) -> Void,
                   didCancel: (() -> Void)? = nil) {
        titleLabel.text = title
        self.items = items
        self.defaultIndex = (defaultIndex >= 0 && defaultIndex < items.count) ? defaultIndex : -1
        self.didSelect = didSelect
        self.didCancel = didCancel
        tableView.reloadData()
    }

    func show(in parent: UIView, animated: Bool = true) {
        translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(self)
        layout(in: parent)
        parent.layoutIfNeeded()

        let originalFrame = containerView.frame
        containerView.frame = originalFrame.offsetBy(dx: 0, dy: originalFrame.height)
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: {
                self.containerView.frame = originalFrame
                self.dimView.alpha = 1.0
            }, completion: { _ in
                if self.defaultIndex >= 0 {
                    self.tableView.scrollToRow(at: IndexPath(row: self.defaultIndex, section: 0),
                                               at: .middle, animated: true)
                }
            })
        } else {
            dimView.alpha = 1.0
            if defaultIndex >= 0 {
                tableView.scrollToRow(at: IndexPath(row: defaultIndex, section: 0),
                                      at: .middle, animated: false)
            }
        }
    }

    func dismiss(animated: Bool = true) {
        let originalFrame = containerView.frame
        if animated {
            UIView.animate(withDuration: 0.22, delay: 0, options: .curveEaseIn, animations: {
                self.containerView.frame = originalFrame.offsetBy(dx: 0, dy: originalFrame.height)
                self.dimView.alpha = 0
            }, completion: { _ in
                self.removeFromSuperview()
            })
        } else {
            removeFromSuperview()
        }
    }

    @objc private func dismissTapped() {
        didCancel?()
        dismiss()
    }

    @objc private func cancelTapped() {
        didCancel?()
        dismiss()
    }
}

extension DeviceSettingBottomPickerView: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "pickerRow", for: indexPath) as! DeviceSettingPickerCell
        cell.configure(title: items[indexPath.row], highlighted: indexPath.row == defaultIndex)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let title = items[indexPath.row]
        didSelect?(indexPath.row, title)
        dismiss()
    }
}

// 内部使用的行 Cell
private final class DeviceSettingPickerCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let checkImageView = UIImageView(image: UIImage(systemName: "checkmark"))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        titleLabel.font = .systemFont(ofSize: 18)
        titleLabel.textColor = .systemBlue
        titleLabel.textAlignment = .center
        contentView.addSubview(titleLabel)

        checkImageView.tintColor = .systemBlue
        checkImageView.isHidden = true
        contentView.addSubview(checkImageView)

        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.bottom.equalToSuperview()
        }

        checkImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, highlighted: Bool) {
        titleLabel.text = title
        checkImageView.isHidden = !highlighted
        titleLabel.font = highlighted
            ? .systemFont(ofSize: 18, weight: .semibold)
            : .systemFont(ofSize: 18)
    }
}
