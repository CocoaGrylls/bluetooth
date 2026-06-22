//
//  AudioPlayHeaderView.swift
//  AIRECIOSBleDemo
//
//  Created by Codex on 2026/6/11.
//

import UIKit
import SnapKit

final class AudioPlayHeaderView: UIView {

    private let fileIconContainer: UIView = {
        let container = UIView()
        container.layer.cornerRadius = 12
        container.clipsToBounds = true
        container.backgroundColor = Theme.audioBlue
        return container
    }()

    private let iconView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "waveform"))
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let fileNameLabel = UILabel()
    private let fileTypeLabel = UILabel()
    private let fileDateBadgeLabel = UILabel()

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
    }

    private func buildUI() {
        backgroundColor = .clear

        iconView.clipsToBounds = true

        fileNameLabel.font = .systemFont(ofSize: 22, weight: .bold)
        fileNameLabel.textColor = Theme.pageTitleText
        fileNameLabel.textAlignment = .left
        fileNameLabel.numberOfLines = 2

        fileTypeLabel.text = "录音文件"
        fileTypeLabel.font = .systemFont(ofSize: 16, weight: .regular)
        fileTypeLabel.textColor = UIColor(hex: 0x555555)
        fileTypeLabel.textAlignment = .left

        addSubview(fileIconContainer)
        fileIconContainer.addSubview(iconView)
        addSubview(fileNameLabel)
        addSubview(fileTypeLabel)
        addSubview(fileDateBadgeLabel)

        fileIconContainer.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.top.equalTo(10)
            make.width.height.equalTo(50)
        }

        iconView.snp.makeConstraints { make in
            make.center.equalTo(fileIconContainer)
            make.width.height.equalTo(24)
        }

        fileNameLabel.snp.makeConstraints { make in
            make.top.equalTo(fileIconContainer)
            make.left.equalTo(fileIconContainer.snp.right).offset(16)
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
