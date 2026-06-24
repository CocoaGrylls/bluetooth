import UIKit
import AIRECBleKit
import SnapKit

// MARK: - Row Model
private enum SettingRow {
    case info(icon: String, title: String, value: String)
    case disclosure(icon: String, title: String, subtitle: String)
    case disclosureWithHint(icon: String, title: String, subtitle: String, hint: String)
    case toggle(icon: String, title: String, isOn: Bool)
    case actionButton(title: String, style: UIAlertAction.Style)
}

private struct SettingSection {
    let header: String?
    var rows: [SettingRow]
    let footer: String?
}

// MARK: - View Controller
class DeviceSettingsViewController: UIViewController {

    private var lastDevice: AIRECBleDevice?

    // 开关状态
    private var usbSwitchOn = false
    private var autoRecordSwitchOn = false
    private var autoTransferSwitchOn = false
    private var decibelSwitchOn = false
    private var keyStartSwitchOn = false

    // 选择器值（分钟）
    private var segmentMinutes = 0
    private var idleMinutes = 0
    private var micGainValue = 3

    private var firmwareVersionText = "读取中..."
    private var deviceName = "--"
    private var deviceSN = "--"
    private var batteryText = "0%"
    private var storageText = "-- / --"

    private let tableView = UITableView(frame: .zero, style: .grouped)
    private var sections: [SettingSection] = []

    private let infoCellId = "infoCell"
    private let disclosureCellId = "disclosureCell"
    private let disclosureHintCellId = "disclosureHintCell"
    private let toggleCellId = "toggleCell"
    private let buttonCellId = "buttonCell"

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "我的设备"
        view.backgroundColor = UIColor(red: 0.95, green: 0.93, blue: 0.97, alpha: 1.0)

        AIRECBleChannel.shared.addObserver(self)
        buildTableView()
        reloadSections()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AIRECBleChannel.shared.activate()
        if AIRECBleChannel.shared.isConnected {
            // 先用缓存渲染一次 UI，避免进入页面空值
            reloadWithDeviceInfo()
            // 发起蓝牙请求拉取最新；设备回复会走 didUpdateDeviceInfo
            AIRECBleChannel.shared.fetchDeviceInfo()
            AIRECBleChannel.shared.fetchFirmwareVersion()
        }
    }

    deinit {
        AIRECBleChannel.shared.removeObserver(self)
    }

    private func buildTableView() {
        tableView.backgroundColor = UIColor(red: 0.95, green: 0.93, blue: 0.97, alpha: 1.0)
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 48, bottom: 0, right: 0)
        tableView.separatorColor = UIColor(white: 0.9, alpha: 1.0)
        tableView.rowHeight = 56
        tableView.estimatedRowHeight = 100
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 16))
        tableView.sectionHeaderHeight = 0
        tableView.sectionFooterHeight = 12

        tableView.dataSource = self
        tableView.delegate = self

        tableView.register(DeviceSettingInfoCell.self, forCellReuseIdentifier: infoCellId)
        tableView.register(DeviceSettingDisclosureCell.self, forCellReuseIdentifier: disclosureCellId)
        tableView.register(DeviceSettingDisclosureWithHintCell.self, forCellReuseIdentifier: disclosureHintCellId)
        tableView.register(DeviceSettingToggleCell.self, forCellReuseIdentifier: toggleCellId)
        tableView.register(DeviceSettingButtonCell.self, forCellReuseIdentifier: buttonCellId)

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
        }
    }

    private func reloadSections() {
        sections = [
            SettingSection(
                header: nil,
                rows: [
                    .info(icon: "b.circle", title: "蓝牙名称", value: deviceName),
                    .info(icon: "number.circle", title: "设备SN", value: deviceSN),
                    .info(icon: "battery.100", title: "电量", value: batteryText)
                ],
                footer: nil
            ),
            SettingSection(
                header: nil,
                rows: [
                    .disclosureWithHint(icon: "lock.shield",
                                         title: "安全码",
                                         subtitle: "",
                                         hint: "设置安全码后，其他账号连接本设备时，必须校验安全码才能连接。")
                ],
                footer: nil
            ),
            SettingSection(
                header: nil,
                rows: [
                    .info(icon: "internaldrive", title: "空间管理", value: storageText),
                    .disclosure(icon: "trash", title: "磁盘格式化", subtitle: "")
                ],
                footer: nil
            ),
            SettingSection(
                header: nil,
                rows: [
                    .toggle(icon: "phone.connection", title: "来电自动录音", isOn: autoRecordSwitchOn),
                    .toggle(icon: "cable.connector", title: "USB支持", isOn: usbSwitchOn),
                    .toggle(icon: "power", title: "开机录音", isOn: false),
                    .toggle(icon: "speaker.wave.2", title: "分贝检测", isOn: decibelSwitchOn),
                    .disclosureWithHint(icon: "list.bullet.rectangle",
                                         title: "分段录音",
                                         subtitle: segmentLabel(segmentMinutes),
                                         hint: "设定后，将根据您选择的时长分段保存录音。"),
                    .disclosureWithHint(icon: "mic.circle",
                                         title: "按键启动",
                                         subtitle: "仅录音",
                                         hint: "设定后，连接APP过程中，通过机器开启录音将进行。")
                ],
                footer: nil
            ),
            SettingSection(
                header: nil,
                rows: [
                    .disclosureWithHint(icon: "moon.zzz",
                                         title: "空闲关机",
                                         subtitle: idleLabel(idleMinutes),
                                         hint: "设定后，机器如无任何操作，将根据您选择的时长自动关机。")
                ],
                footer: nil
            ),
            SettingSection(
                header: nil,
                rows: [
                    .disclosureWithHint(icon: "slider.horizontal.3",
                                         title: "麦克风增益",
                                         subtitle: "\(micGainValue)",
                                         hint: "当增益调高时，麦克风能捕捉到更微弱的声音（比如远处的声音、轻声说话），但同时也可能放大环境中的杂音；当增益调低时，声音信号放大幅度小，能减少杂音，但需要说话者离麦克风更近才能被清晰收录。")
                ],
                footer: nil
            ),
            SettingSection(
                header: nil,
                rows: [
                    .disclosure(icon: "arrow.up.circle", title: "固件升级", subtitle: firmwareVersionText)
                ],
                footer: nil
            ),
            SettingSection(
                header: nil,
                rows: [
                    .actionButton(title: "断开连接", style: .destructive),
                    .actionButton(title: "解除绑定", style: .cancel)
                ],
                footer: nil
            )
        ]
        tableView.reloadData()
    }

    private func reloadWithDeviceInfo() {
        let mgr = AIRECBleChannel.shared
        if let dev = mgr.getConnectedDevice() {
            lastDevice = dev
            deviceName = dev.name
            firmwareVersionText = dev.firmwareVersion.isEmpty ? "读取中..." : dev.firmwareVersion
            print("[DeviceSettings] storageUsed=\(dev.storageUsed), storageTotal=\(dev.storageTotal), storageStr=\(dev.storageStr)")
        }
        deviceSN = mgr.macAddress.isEmpty ? "--" : mgr.macAddress
        batteryText = "\(lastDevice?.battery ?? 0)%"
        storageText = preferredStorageText()

        usbSwitchOn = mgr.usbSwitch
        autoRecordSwitchOn = mgr.ledSwitch
        segmentMinutes = mgr.segmentDuration
        idleMinutes = mgr.idleShutdown
        micGainValue = mgr.micGain
        reloadSections()
    }
}

// MARK: - UITableViewDataSource & Delegate
extension DeviceSettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]
        switch row {
        case .info(let icon, let title, let value):
            let cell = tableView.dequeueReusableCell(withIdentifier: infoCellId, for: indexPath) as! DeviceSettingInfoCell
            cell.configure(icon: icon, title: title, value: value)
            return cell
        case .disclosure(let icon, let title, let subtitle):
            let cell = tableView.dequeueReusableCell(withIdentifier: disclosureCellId, for: indexPath) as! DeviceSettingDisclosureCell
            cell.configure(icon: icon, title: title, subtitle: subtitle)
            return cell
        case .disclosureWithHint(let icon, let title, let subtitle, let hint):
            let cell = tableView.dequeueReusableCell(withIdentifier: disclosureHintCellId, for: indexPath) as! DeviceSettingDisclosureWithHintCell
            cell.configure(icon: icon, title: title, subtitle: subtitle, hint: hint)
            return cell
        case .toggle(let icon, let title, let isOn):
            let cell = tableView.dequeueReusableCell(withIdentifier: toggleCellId, for: indexPath) as! DeviceSettingToggleCell
            cell.configure(icon: icon, title: title, isOn: isOn) { [weak self] new in
                self?.handleSwitchChange(title: title, isOn: new)
            }
            return cell
        case .actionButton(let title, let style):
            let cell = tableView.dequeueReusableCell(withIdentifier: buttonCellId, for: indexPath) as! DeviceSettingButtonCell
            cell.configure(title: title, style: style) { [weak self] in
                self?.handleActionButton(title: title)
            }
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = sections[indexPath.section].rows[indexPath.row]
        switch row {
        case .disclosure(_, let title, _), .disclosureWithHint(_, let title, _, _):
            handleDisclosure(title: title)
        default:
            break
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let row = sections[indexPath.section].rows[indexPath.row]
        if case .disclosureWithHint = row {
            return UITableView.automaticDimension
        }
        return 56
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 12
    }
}

// MARK: - Actions
extension DeviceSettingsViewController {

    private func handleSwitchChange(title: String, isOn: Bool) {
        let mgr = AIRECBleChannel.shared
        switch title {
        case "来电自动录音":
            autoRecordSwitchOn = isOn
            mgr.sendLedSwitch(isOn)
        case "USB支持":
            usbSwitchOn = isOn
            mgr.sendUsbSwitch(isOn)
        case "开机录音":
            mgr.sendPowerOnRecord(isOn)
        case "自动传输":
            autoTransferSwitchOn = isOn
        case "分贝检测":
            decibelSwitchOn = isOn
        case "按键启动":
            keyStartSwitchOn = isOn
        default:
            break
        }
    }

    private func handleActionButton(title: String) {
        switch title {
        case "断开连接":
            disconnectTapped()
        case "解除绑定":
            unbindTapped()
        default:
            break
        }
    }

    private func handleDisclosure(title: String) {
        switch title {
        case "安全码":
            showCodeInput(title: "安全码", hint: "请输入安全码")
        case "磁盘格式化":
            formatTapped()
        case "分段录音":
            segmentTapped()
        case "按键启动":
            break
        case "空闲关机":
            idleTapped()
        case "麦克风增益":
            micGainTapped()
        case "固件升级":
            firmwareTapped()
        default:
            break
        }
    }

    private func disconnectTapped() {
        let alert = UIAlertController(title: "断开连接", message: "确认断开蓝牙连接？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "断开", style: .destructive) { [weak self] _ in
            self?.lastDevice = nil
            AIRECBleChannel.shared.disconnect()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    private func unbindTapped() {
        let alert = UIAlertController(title: "解除绑定", message: "确认解除设备绑定？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
            self?.showToast("已解除绑定")
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    private func firmwareTapped() {
        let alert = UIAlertController(title: "固件升级",
            message: "当前固件版本：\(firmwareVersionText)\n\n升级步骤：\n1. 将固件文件(.bin)放入设备存储根目录\n2. 重命名为 update.bin\n3. 重启设备，设备将自动完成升级",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    // MARK: - 自定义 PickerView

    private func segmentTapped() {
        let values = [0, 5, 10, 15, 30, 60, 120, 180, 240, 480]
        let labels = values.map(segmentLabel)
        showPicker(title: "分段录音时间", items: labels) { [weak self] index, _ in
            guard let self = self else { return }
            let min = values[index]
            AIRECBleChannel.shared.sendSegmentDuration(min)
            self.segmentMinutes = min
            self.reloadSections()
        }
    }

    private func idleTapped() {
        let values = [0, 3, 5, 10, 15, 30, 60, 120, 240]
        let labels = values.map(idleLabel)
        showPicker(title: "空闲关机时间", items: labels) { [weak self] index, _ in
            guard let self = self else { return }
            let min = values[index]
            AIRECBleChannel.shared.sendIdleShutdown(min)
            self.idleMinutes = min
            self.reloadSections()
        }
    }

    private func micGainTapped() {
        let labels = (1...7).map { "增益 \($0)" }
        showPicker(title: "麦克风增益", items: labels) { [weak self] index, _ in
            guard let self = self else { return }
            let gain = index + 1
            AIRECBleChannel.shared.sendMicGain(gain)
            self.micGainValue = gain
            self.reloadSections()
        }
    }

    private func showPicker(title: String, items: [String],
                            didSelect: @escaping (Int, String) -> Void) {
        guard let container = view else { return }
        let picker = DeviceSettingBottomPickerView(frame: container.bounds)
        picker.configure(title: title, items: items, didSelect: didSelect)
        picker.show(in: container)
    }

    private func showCodeInput(title: String, hint: String) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = hint }
        alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
            let val = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces) ?? ""
            if !val.isEmpty { self?.showToast("\(title)已设置: \(val)") }
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    private func formatTapped() {
        let alert = UIAlertController(title: "⚠️ 格式化存储", message: "此操作将清除设备上所有录音文件，且不可恢复。\n\n确定要继续吗？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定格式化", style: .destructive) { [weak self] _ in
            guard let self = self else { return }

            let hud = UIAlertController(title: nil, message: "正在格式化...\n\n", preferredStyle: .alert)
            let spinner = UIActivityIndicatorView(style: .large)
            spinner.translatesAutoresizingMaskIntoConstraints = false
            spinner.startAnimating()
            hud.view.addSubview(spinner)
            NSLayoutConstraint.activate([
                spinner.centerXAnchor.constraint(equalTo: hud.view.centerXAnchor),
                spinner.bottomAnchor.constraint(equalTo: hud.view.bottomAnchor, constant: -20)
            ])
            self.present(hud, animated: true)

            AIRECBleChannel.shared.sendFormatDisk()
            AIRECBleChannel.shared.onFormatResult = { [weak self] success, msg in
                guard let self = self else { return }
                hud.dismiss(animated: true) {
                    self.showToast(success ? "✅ \(msg)" : "❌ \(msg)")
                    if success {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            AIRECBleChannel.shared.fetchDeviceInfo()
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            AIRECBleChannel.shared.fetchFileList()
                        }
                    }
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak hud] in
                if hud?.presentingViewController != nil {
                    hud?.dismiss(animated: true) {
                        self.showToast("格式化超时，请重试")
                    }
                }
            }
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    private func segmentLabel(_ min: Int) -> String {
        if min <= 0 { return "不分段" }
        if min < 60 { return "\(min)分钟" }
        return "\(min / 60)小时\(min % 60 > 0 ? "\(min % 60)分" : "")"
    }

    private func idleLabel(_ min: Int) -> String {
        if min <= 0 { return "不关机" }
        if min < 60 { return "\(min)分钟" }
        return "\(min / 60)小时\(min % 60 > 0 ? "\(min % 60)分" : "")"
    }
}

// MARK: - AIRECBleDelegate
extension DeviceSettingsViewController: AIRECBleDelegate {
    func bleManager(_ manager: AIRECBleManager, didConnect device: AIRECBleDevice) {
        lastDevice = device
        reloadWithDeviceInfo()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self, AIRECBleChannel.shared.isConnected else { return }
            AIRECBleChannel.shared.fetchAllDeviceInfo()
            AIRECBleChannel.shared.fetchFirmwareVersion()
        }
    }

    func bleManager(_ manager: AIRECBleManager, didDisconnect device: AIRECBleDevice?, reason: String) {
        lastDevice = nil
        showToast("设备已断开")
        navigationController?.popViewController(animated: true)
    }

    func bleManager(_ manager: AIRECBleManager, didUpdateDeviceInfo device: AIRECBleDevice) {
        print("didUpdateDeviceInfo")
        reloadWithDeviceInfo()
    }

    func bleManager(_ manager: AIRECBleManager, didChangeBluetoothState enabled: Bool) {
        if !enabled {
            lastDevice = nil
            showToast("蓝牙已关闭")
            navigationController?.popViewController(animated: true)
        }
    }
}

// MARK: - Storage Format Helpers
/// 把「KB 或 MB」的原始值格式化为友好显示。
/// SDK 在不同容量的设备上可能返回不同单位：
///   - 大容量设备（64GB）：storageTotal ≈ 59638 → 单位 MB
///   - 小容量设备：storageTotal ≈ 59638 → 单位 KB
/// 策略：若 total > 1024 * 1024 认为是 KB，否则认为是 MB。
private func normalizedBytes(_ value: Int64, total: Int64) -> Int64 {
    if total > 1024 * 1024 {
        return value * 1024          // KB → 字节
    } else {
        return value * 1024 * 1024   // MB → 字节
    }
}

private func humanSizeString(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
    formatter.countStyle = .binary
    formatter.isAdaptive = true
    return formatter.string(fromByteCount: bytes)
}

private func storageDisplayText(used: Int64, total: Int64) -> String {
    let usedBytes = normalizedBytes(used, total: total)
    let totalBytes = normalizedBytes(total, total: total)
    return "\(humanSizeString(usedBytes)) / \(humanSizeString(totalBytes))"
}

private func preferredStorageText() -> String {
    guard let dev = AIRECBleChannel.shared.getConnectedDevice() else {
        return "-- / --"
    }
    let used = dev.storageUsed
    let total = dev.storageTotal
    if total <= 0 {
        return dev.storageStr.isEmpty ? "-- / --" : dev.storageStr
    }
    return storageDisplayText(used: used, total: total)
}
