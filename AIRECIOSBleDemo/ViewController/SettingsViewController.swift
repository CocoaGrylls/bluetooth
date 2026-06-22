//
//  SettingsViewController.swift
//  AIRECIOSBleDemo
//
//  Created by Codex on 2026/5/28.
//

import UIKit
import AIRECBleKit

final class SettingsViewController: UITableViewController {

    private enum Section: Int, CaseIterable {
        case device
        case app

        var title: String {
            switch self {
            case .device:
                return "设备"
            case .app:
                return "应用"
            }
        }
    }

    private enum DeviceRow: Int, CaseIterable {
        case connection
        case lastDevice
        case deviceSettings

        var title: String {
            switch self {
            case .connection:
                return "连接状态"
            case .lastDevice:
                return "上次连接设备"
            case .deviceSettings:
                return "我的设备"
            }
        }
    }

    private enum AppRow: Int, CaseIterable {
        case version

        var title: String {
            switch self {
            case .version:
                return "当前版本"
            }
        }
    }

    override init(style: UITableView.Style) {
        super.init(style: style)
    }

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "设置"
        setupView()
        AIRECBleChannel.shared.addObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupNavigationBar()
        tableView.reloadData()
    }

    deinit {
        AIRECBleChannel.shared.removeObserver(self)
    }

    private func setupView() {
        view.backgroundColor = Theme.pageBackground
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .singleLine
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingsCell")
    }

    private func setupNavigationBar() {
        guard let navigationBar = navigationController?.navigationBar else { return }
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Theme.navigationBarBackground
        appearance.shadowColor = Theme.pageControlBorder
        appearance.titleTextAttributes = [
            .foregroundColor: Theme.pageTitleText,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.tintColor = Theme.pageTitleText
        navigationBar.isTranslucent = false
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        switch section {
        case .device:
            return DeviceRow.allCases.count
        case .app:
            return AppRow.allCases.count
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        Section(rawValue: section)?.title
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)
        cell.backgroundColor = Theme.pageControlBackground
        cell.textLabel?.textColor = Theme.pageTitleText
        cell.detailTextLabel?.textColor = Theme.pageSecondaryText

        var content = cell.defaultContentConfiguration()
        content.textProperties.color = Theme.pageTitleText
        content.secondaryTextProperties.color = Theme.pageSecondaryText
        content.secondaryTextProperties.alignment = .natural

        if let section = Section(rawValue: indexPath.section) {
            switch section {
            case .device:
                if let row = DeviceRow(rawValue: indexPath.row), row == .deviceSettings {
                    cell.selectionStyle = AIRECBleChannel.shared.isConnected ? .default : .none
                } else {
                    cell.selectionStyle = .none
                }
                configureDeviceCellContent(&content, row: DeviceRow(rawValue: indexPath.row))
            case .app:
                cell.selectionStyle = .none
                configureAppCellContent(&content, row: AppRow(rawValue: indexPath.row))
            }
        }

        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let section = Section(rawValue: indexPath.section), section == .device else { return }
        guard let row = DeviceRow(rawValue: indexPath.row), row == .deviceSettings else { return }
        guard AIRECBleChannel.shared.isConnected else { return }
        let vc = DeviceSettingsViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    private func configureDeviceCellContent(_ content: inout UIListContentConfiguration, row: DeviceRow?) {
        guard let row else { return }
        let channel = AIRECBleChannel.shared

        content.text = row.title
        switch row {
        case .connection:
            content.secondaryText = channel.isConnected ? (channel.getConnectedDevice()?.name ?? "已连接") : "未连接"
            content.image = UIImage(systemName: channel.isConnected ? "checkmark.circle.fill" : "xmark.circle")
            content.imageProperties.tintColor = channel.isConnected ? Theme.audioGreen : Theme.pageSecondaryText
        case .lastDevice:
            content.secondaryText = channel.lastConnectedDeviceIdentifier ?? "暂无"
            content.image = UIImage(systemName: "clock.arrow.circlepath")
            content.imageProperties.tintColor = Theme.audioBlue
        case .deviceSettings:
            content.secondaryText = channel.isConnected ? "点击进入" : "未连接"
            content.image = UIImage(systemName: "gear")
            content.imageProperties.tintColor = channel.isConnected ? Theme.audioBlue : Theme.pageSecondaryText
            content.textProperties.color = channel.isConnected ? Theme.pageTitleText : Theme.pageSecondaryText
        }
    }

    private func configureAppCellContent(_ content: inout UIListContentConfiguration, row: AppRow?) {
        guard let row else { return }

        content.text = row.title
        switch row {
        case .version:
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
            if let version, let build {
                content.secondaryText = "\(version) (\(build))"
            } else {
                content.secondaryText = version ?? build ?? "未知"
            }
            content.image = UIImage(systemName: "info.circle")
            content.imageProperties.tintColor = Theme.audioBlue
        }
    }
}

extension SettingsViewController: AIRECBleDelegate {

    func bleManager(_ manager: AIRECBleManager, didConnect device: AIRECBleDevice) {
        tableView.reloadSections(IndexSet(integer: Section.device.rawValue), with: .none)
    }

    func bleManager(_ manager: AIRECBleManager, didDisconnect device: AIRECBleDevice?, reason: String) {
        tableView.reloadSections(IndexSet(integer: Section.device.rawValue), with: .none)
    }

    func bleManager(_ manager: AIRECBleManager, didUpdateDeviceInfo device: AIRECBleDevice) {
        tableView.reloadSections(IndexSet(integer: Section.device.rawValue), with: .none)
    }

    func bleManager(_ manager: AIRECBleManager, didChangeBluetoothState enabled: Bool) {
        tableView.reloadSections(IndexSet(integer: Section.device.rawValue), with: .none)
    }
}
