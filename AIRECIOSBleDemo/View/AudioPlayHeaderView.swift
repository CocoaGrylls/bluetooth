//
//  AudioPlayHeaderView.swift
//  AIRECIOSBleDemo
//
//  Created by Codex on 2026/6/11.
//

import UIKit
import SnapKit

final class AudioPlayHeaderView: UIView {

    private let iconView = UIImageView(image: UIImage(named: "audioicon"))
    private let fileNameLabel = UILabel()
    private let fileTypeLabel = UILabel()
    private let fileDateBadgeLabel = UILabel()
    private let fileSizeBadgeLabel = UILabel()

    init(fileName: String, fileDate: String, fileSize: String) {
        super.init(frame: .zero)
        buildUI()
        configure(fileName: fileName, fileDate: fileDate, fileSize: fileSize)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(fileName: String, fileDate: String, fileSize: String) {
        let trimmedFileName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        fileNameLabel.text = trimmedFileName
        fileNameLabel.isHidden = trimmedFileName.isEmpty
        configureBadgeLabel(fileDateBadgeLabel, imageName: "timeicon", text: fileDate)
        configureBadgeLabel(fileSizeBadgeLabel, imageName: nil, text: fileSize)
    }

    private func buildUI() {
        backgroundColor = .clear

        iconView.contentMode = .scaleAspectFit
        iconView.clipsToBounds = true

        fileNameLabel.font = .systemFont(ofSize: 22, weight: .bold)
        fileNameLabel.textColor = Theme.pageTitleText
        fileNameLabel.textAlignment = .left
        fileNameLabel.numberOfLines = 2

        fileTypeLabel.text = "录音文件"
        fileTypeLabel.font = .systemFont(ofSize: 16, weight: .regular)
        fileTypeLabel.textColor = UIColor(hex: 0x555555)
        fileTypeLabel.textAlignment = .left

        addSubview(iconView)
        addSubview(fileNameLabel)
        addSubview(fileTypeLabel)
        addSubview(fileDateBadgeLabel)
        addSubview(fileSizeBadgeLabel)

        iconView.snp.makeConstraints { make in
            make.left.top.equalToSuperview()
            make.width.height.equalTo(78)
            make.bottom.lessThanOrEqualToSuperview()
        }

        fileNameLabel.snp.makeConstraints { make in
            make.top.equalTo(iconView).offset(4)
            make.left.equalTo(iconView.snp.right).offset(16)
            make.right.equalToSuperview()
        }

        fileTypeLabel.snp.makeConstraints { make in
            make.top.equalTo(fileNameLabel.snp.bottom).offset(6)
            make.left.equalTo(fileNameLabel)
            make.right.equalToSuperview()
        }

        fileDateBadgeLabel.snp.makeConstraints { make in
            make.top.equalTo(fileTypeLabel.snp.bottom).offset(8)
            make.left.equalTo(fileNameLabel)
            make.height.equalTo(26)
            make.bottom.equalToSuperview()
        }

        fileSizeBadgeLabel.snp.makeConstraints { make in
            make.centerY.equalTo(fileDateBadgeLabel)
            make.left.equalTo(fileDateBadgeLabel.snp.right).offset(10)
            make.height.equalTo(26)
            make.right.lessThanOrEqualToSuperview()
        }
    }

    private func configureBadgeLabel(_ label: UILabel, imageName: String?, text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        label.isHidden = trimmedText.isEmpty
        label.font = .systemFont(ofSize: 14)
        label.textColor = UIColor(hex: 0x555555)
        label.backgroundColor = UIColor(hex: 0xF4F6FA)
        label.layer.cornerRadius = 5
        label.clipsToBounds = true

        guard let imageName, let image = UIImage(named: imageName) else {
            label.text = "  \(trimmedText)  "
            return
        }

        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(x: 0, y: -2, width: 14, height: 14)
        let attributed = NSMutableAttributedString(string: " ")
        attributed.append(NSAttributedString(attachment: attachment))
        attributed.append(NSAttributedString(string: " \(trimmedText)  "))
        label.attributedText = attributed
    }
}
