import UIKit
import AIRECBleKit

protocol FileCellDelegate: AnyObject {
    func fileCellDidTapDownload(_ cell: FileCell)
    func fileCellDidTapPlay(_ cell: FileCell)
    func fileCellDidTapDelete(_ cell: FileCell)
}
extension FileCellDelegate {
    func fileCellDidTapDelete(_ cell: FileCell) {}
}

class FileCell: UITableViewCell {
    static let reuseId = "FileCell"
    weak var delegate: FileCellDelegate?

    private let nameLabel   = UILabel()
    private let infoLabel   = UILabel()
    private let tagLabel    = UILabel()   // "设备" / "本地"
    private let progressBar = UIProgressView(progressViewStyle: .default)
    private let downloadBtn = UIButton(type: .system)
    private let playBtn     = UIButton(type: .system)

    enum State { case idle, downloading(Int), done, error }
    private(set) var cellState: State = .idle

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        nameLabel.font = .systemFont(ofSize: 15, weight: .medium)
        nameLabel.numberOfLines = 1

        infoLabel.font = .systemFont(ofSize: 12)
        infoLabel.textColor = .secondaryLabel

        tagLabel.font = .systemFont(ofSize: 10, weight: .medium)
        tagLabel.layer.cornerRadius = 4; tagLabel.clipsToBounds = true
        tagLabel.textAlignment = .center
        tagLabel.widthAnchor.constraint(equalToConstant: 36).isActive = true
        tagLabel.heightAnchor.constraint(equalToConstant: 18).isActive = true

        progressBar.isHidden = true; progressBar.tintColor = .systemBlue

        downloadBtn.setImage(UIImage(systemName: "arrow.down.circle"), for: .normal)
        downloadBtn.addTarget(self, action: #selector(downloadTapped), for: .touchUpInside)

        playBtn.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
        playBtn.tintColor = .systemGreen; playBtn.isHidden = true
        playBtn.addTarget(self, action: #selector(playTapped), for: .touchUpInside)

        let btnStack = UIStackView(arrangedSubviews: [downloadBtn, playBtn])
        btnStack.axis = .horizontal; btnStack.spacing = 8

        let topRow = UIStackView(arrangedSubviews: [nameLabel, tagLabel])
        topRow.axis = .horizontal; topRow.spacing = 6; topRow.alignment = .center

        let textStack = UIStackView(arrangedSubviews: [topRow, infoLabel, progressBar])
        textStack.axis = .vertical; textStack.spacing = 4

        let row = UIStackView(arrangedSubviews: [textStack, btnStack])
        row.axis = .horizontal; row.spacing = 8; row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            btnStack.widthAnchor.constraint(equalToConstant: 72),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(item: AudioItem, state: State) {
        nameLabel.text = item.fileName
        infoLabel.text = "\(item.fileSizeStr)  \(item.createTime)"
        cellState = state

        // 标签
        if item.isLocal && item.isDevice {
            tagLabel.text = "已下载"; tagLabel.backgroundColor = .systemGreen.withAlphaComponent(0.15)
            tagLabel.textColor = .systemGreen; tagLabel.isHidden = false
        } else if item.isLocal {
            tagLabel.text = "本地"; tagLabel.backgroundColor = .systemBlue.withAlphaComponent(0.15)
            tagLabel.textColor = .systemBlue; tagLabel.isHidden = false
        } else {
            tagLabel.text = "设备"; tagLabel.backgroundColor = .systemOrange.withAlphaComponent(0.15)
            tagLabel.textColor = .systemOrange; tagLabel.isHidden = false
        }

        switch state {
        case .idle:
            progressBar.isHidden = true
            downloadBtn.isHidden = item.isLocal  // 本地音频不显示下载按钮
            downloadBtn.isEnabled = true
            downloadBtn.setImage(UIImage(systemName: "arrow.down.circle"), for: .normal)
            downloadBtn.tintColor = .systemBlue
            playBtn.isHidden = !item.isLocal
        case .downloading(let p):
            progressBar.isHidden = false; progressBar.progress = Float(p) / 100.0
            downloadBtn.isHidden = true; playBtn.isHidden = true
        case .done:
            progressBar.isHidden = true; downloadBtn.isHidden = true; playBtn.isHidden = false
        case .error:
            progressBar.isHidden = true
            downloadBtn.isHidden = false; downloadBtn.isEnabled = true
            downloadBtn.setImage(UIImage(systemName: "arrow.down.circle.fill"), for: .normal)
            downloadBtn.tintColor = .systemRed; playBtn.isHidden = true
        }
    }

    @objc private func downloadTapped() { delegate?.fileCellDidTapDownload(self) }
    @objc private func playTapped()     { delegate?.fileCellDidTapPlay(self) }
}
