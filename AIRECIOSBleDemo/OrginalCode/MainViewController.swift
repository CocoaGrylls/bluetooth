import UIKit
import AIRECBleKit

private let audioExts: Set<String> = ["wav","mp3","aac","m4a","ogg","opus","flac","pcm","amr"]

class MainViewController: UIViewController {

    // MARK: - State
    private var isRecording        = false
    private var isPaused           = false
    private var initialInfoFetched = false
    private var lastDevice: AIRECBleDevice?
    // 文件列表 - 统一模型
    private var fileStates: [String: FileCell.State] = [:]
    private var allItems:   [AudioItem] = []   // 全量（设备+本地），已排序
    private var filteredItems: [AudioItem] = [] // 过滤后
    private var displayItems:  [AudioItem] = [] // 当前页显示
    private let pageSize = 10
    private var currentPage = 0
    private var currentFilter: AudioFilter = .all
    private var hasMorePages: Bool { filteredItems.count > displayItems.count }
    private var recordStartDate = Date()
    private var pausedElapsed: TimeInterval = 0
    private var timerLink:    CADisplayLink?
    private var batteryTimer: Timer?
    private var isResumingFromPause = false
    private var appInitiatedPauseResume = false  // App 主动发的暂停/恢复
    private var decibelEnabled = false
    private var waveBars: [UIView] = []
    private var waveTimer: Timer?

    // MARK: - UI
    private let scrollView      = UIScrollView()
    private let contentView     = UIView()
    private let connectCard     = UIView()
    private let connectBtn      = UIButton(type: .system)
    private let connectedCard   = UIView()
    private let nameLabel       = UILabel()
    private let batteryLabel    = UILabel()
    private let storageLabel    = UILabel()
    private let firmwareLabel   = UILabel()
    private let disconnectBtn   = UIButton(type: .system)
    private let otaBtn          = UIButton(type: .system)
    private let macLabel        = UILabel()
    private let settingsLabel   = UILabel()
    private let ledSwitch       = UISwitch()
    private let usbSwitch       = UISwitch()
    private let powerOnRecSwitch = UISwitch()
    private let autoTransferSwitch = UISwitch()
    private let decibelSwitch   = UISwitch()
    private let keyStartSwitch  = UISwitch()
    private let segmentBtn      = UIButton(type: .system)
    private let idleBtn         = UIButton(type: .system)
    private let micGainBtn      = UIButton(type: .system)
    private let safeCodeBtn     = UIButton(type: .system)
    private let activateCodeBtn = UIButton(type: .system)
    private let formatBtn       = UIButton(type: .system)
    private let recordCard      = UIView()
    private let recordTimeLabel = UILabel()
    private let startRecBtn     = UIButton(type: .system)
    private let pauseRecBtn     = UIButton(type: .system)
    private let saveRecBtn      = UIButton(type: .system)
    private let waveContainer   = UIView()
    private let fileCard        = UIView()
    private let fileHeaderLabel = UILabel()
    private let refreshBtn      = UIButton(type: .system)
    private let filterSegment   = UISegmentedControl(items: ["全部", "设备", "本地"])
    private let tableView       = UITableView(frame: .zero, style: .plain)
    private var tableViewHeightConstraint: NSLayoutConstraint?
    
    
    @objc private func showScanPeripheral() {
        let vc = ScanViewController()
        vc.onConnected = { [weak self] in
            guard let self = self else { return }
            AIRECBleManager.shared.delegate = self
        }
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "灵犀"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "扫描设备",
                style: .plain,
                target: self,
                action: #selector(showScanPeripheral)
            )
        buildUI()
        showDisconnectedUI()
        AIRECBleManager.shared.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AIRECBleManager.shared.delegate = self
        if AIRECBleManager.shared.isConnected { showConnectedUI() }
    }
}

// MARK: - Build UI
extension MainViewController {
    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView); scrollView.addSubview(contentView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        // 未连接卡片
        styleCard(connectCard)
        connectBtn.setTitle("扫描并连接设备", for: .normal)
        connectBtn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        connectBtn.backgroundColor = .systemBlue
        connectBtn.setTitleColor(.white, for: .normal)
        connectBtn.layer.cornerRadius = 10
        connectBtn.addTarget(self, action: #selector(openScan), for: .touchUpInside)
        connectBtn.translatesAutoresizingMaskIntoConstraints = false
        connectCard.addSubview(connectBtn)
        NSLayoutConstraint.activate([
            connectBtn.topAnchor.constraint(equalTo: connectCard.topAnchor, constant: 20),
            connectBtn.leadingAnchor.constraint(equalTo: connectCard.leadingAnchor, constant: 20),
            connectBtn.trailingAnchor.constraint(equalTo: connectCard.trailingAnchor, constant: -20),
            connectBtn.heightAnchor.constraint(equalToConstant: 50),
            connectBtn.bottomAnchor.constraint(equalTo: connectCard.bottomAnchor, constant: -20),
        ])

        // 已连接卡片
        styleCard(connectedCard)
        [nameLabel, batteryLabel, storageLabel, firmwareLabel].forEach {
            $0.font = .systemFont(ofSize: 15); $0.numberOfLines = 1
        }
        nameLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        disconnectBtn.setTitle("断开连接", for: .normal)
        disconnectBtn.setTitleColor(.systemRed, for: .normal)
        disconnectBtn.addTarget(self, action: #selector(disconnectTapped), for: .touchUpInside)
        otaBtn.setTitle("OTA升级", for: .normal)
        otaBtn.setTitleColor(.systemOrange, for: .normal)
        otaBtn.addTarget(self, action: #selector(otaTapped), for: .touchUpInside)
        let infoStack = UIStackView(arrangedSubviews: [nameLabel, batteryLabel, storageLabel, firmwareLabel])
        infoStack.axis = .vertical; infoStack.spacing = 6
        let btnStack = UIStackView(arrangedSubviews: [otaBtn, disconnectBtn])
        btnStack.axis = .vertical; btnStack.spacing = 8; btnStack.alignment = .trailing
        let topRow = UIStackView(arrangedSubviews: [infoStack, btnStack])
        topRow.axis = .horizontal; topRow.alignment = .top; topRow.spacing = 8
        topRow.translatesAutoresizingMaskIntoConstraints = false

        // MAC label
        macLabel.font = .systemFont(ofSize: 12); macLabel.textColor = .secondaryLabel; macLabel.text = "SN：--"

        // Settings section
        settingsLabel.text = "⚙️ 设备设置"; settingsLabel.font = .systemFont(ofSize: 14, weight: .semibold)

        func makeSwRow(_ label: String, _ sw: UISwitch) -> UIStackView {
            let l = UILabel(); l.text = label; l.font = .systemFont(ofSize: 13)
            let s = UIStackView(arrangedSubviews: [l, sw])
            s.axis = .horizontal; s.spacing = 4; return s
        }
        let swRow1 = UIStackView(arrangedSubviews: [makeSwRow("录音灯", ledSwitch), makeSwRow("USB", usbSwitch)])
        swRow1.axis = .horizontal; swRow1.distribution = .fillEqually; swRow1.spacing = 8
        let swRow2 = UIStackView(arrangedSubviews: [makeSwRow("开机录音", powerOnRecSwitch), makeSwRow("自动传输", autoTransferSwitch)])
        swRow2.axis = .horizontal; swRow2.distribution = .fillEqually; swRow2.spacing = 8
        let swRow3 = UIStackView(arrangedSubviews: [makeSwRow("分贝检测", decibelSwitch), makeSwRow("按键启动", keyStartSwitch)])
        swRow3.axis = .horizontal; swRow3.distribution = .fillEqually; swRow3.spacing = 8

        ledSwitch.addTarget(self, action: #selector(ledSwitchChanged), for: .valueChanged)
        usbSwitch.addTarget(self, action: #selector(usbSwitchChanged), for: .valueChanged)
        powerOnRecSwitch.addTarget(self, action: #selector(powerOnRecChanged), for: .valueChanged)
        decibelSwitch.addTarget(self, action: #selector(decibelSwitchChanged), for: .valueChanged)

        func makePickerRow(_ label: String, _ btn: UIButton) -> UIStackView {
            let l = UILabel(); l.text = label; l.font = .systemFont(ofSize: 13)
            btn.titleLabel?.font = .systemFont(ofSize: 13); btn.setTitleColor(.systemBlue, for: .normal)
            let s = UIStackView(arrangedSubviews: [l, btn])
            s.axis = .horizontal; s.spacing = 4; return s
        }
        segmentBtn.setTitle("不分段", for: .normal)
        idleBtn.setTitle("不关机", for: .normal)
        micGainBtn.setTitle("3", for: .normal)
        segmentBtn.addTarget(self, action: #selector(segmentTapped), for: .touchUpInside)
        idleBtn.addTarget(self, action: #selector(idleTapped), for: .touchUpInside)
        micGainBtn.addTarget(self, action: #selector(micGainTapped), for: .touchUpInside)
        let pickRow1 = UIStackView(arrangedSubviews: [makePickerRow("分段录音：", segmentBtn), makePickerRow("空闲关机：", idleBtn)])
        pickRow1.axis = .horizontal; pickRow1.distribution = .fillEqually; pickRow1.spacing = 8
        let pickRow2 = makePickerRow("麦克风增益：", micGainBtn)

        [safeCodeBtn, activateCodeBtn, formatBtn].forEach {
            $0.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
            $0.layer.cornerRadius = 6; $0.heightAnchor.constraint(equalToConstant: 32).isActive = true
        }
        safeCodeBtn.setTitle("安全码", for: .normal); safeCodeBtn.backgroundColor = .systemBlue; safeCodeBtn.setTitleColor(.white, for: .normal)
        activateCodeBtn.setTitle("激活码", for: .normal); activateCodeBtn.backgroundColor = .systemBlue; activateCodeBtn.setTitleColor(.white, for: .normal)
        formatBtn.setTitle("格式化", for: .normal); formatBtn.backgroundColor = .systemRed; formatBtn.setTitleColor(.white, for: .normal)
        safeCodeBtn.addTarget(self, action: #selector(safeCodeTapped), for: .touchUpInside)
        activateCodeBtn.addTarget(self, action: #selector(activateCodeTapped), for: .touchUpInside)
        formatBtn.addTarget(self, action: #selector(formatTapped), for: .touchUpInside)
        let actionRow = UIStackView(arrangedSubviews: [safeCodeBtn, activateCodeBtn, formatBtn])
        actionRow.axis = .horizontal; actionRow.distribution = .fillEqually; actionRow.spacing = 8

        let sep = UIView(); sep.backgroundColor = .separator; sep.heightAnchor.constraint(equalToConstant: 1).isActive = true

        let settingsStack = UIStackView(arrangedSubviews: [
            macLabel, sep, settingsLabel, swRow1, swRow2, swRow3, pickRow1, pickRow2, actionRow
        ])
        settingsStack.axis = .vertical; settingsStack.spacing = 8

        let cardStack = UIStackView(arrangedSubviews: [topRow, settingsStack])
        cardStack.axis = .vertical; cardStack.spacing = 12
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        connectedCard.addSubview(cardStack)
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: connectedCard.topAnchor, constant: 16),
            cardStack.leadingAnchor.constraint(equalTo: connectedCard.leadingAnchor, constant: 16),
            cardStack.trailingAnchor.constraint(equalTo: connectedCard.trailingAnchor, constant: -16),
            cardStack.bottomAnchor.constraint(equalTo: connectedCard.bottomAnchor, constant: -16),
        ])

        // 录音卡片
        styleCard(recordCard)
        recordTimeLabel.text = "00:00:00"
        recordTimeLabel.font = .monospacedDigitSystemFont(ofSize: 36, weight: .thin)
        recordTimeLabel.textAlignment = .center
        recordTimeLabel.textColor = .systemBlue
        startRecBtn.setTitle("开始录音", for: .normal)
        pauseRecBtn.setTitle("暂停", for: .normal)
        saveRecBtn.setTitle("保存", for: .normal)
        [startRecBtn, pauseRecBtn, saveRecBtn].forEach {
            $0.backgroundColor = .systemBlue
            $0.setTitleColor(.white, for: .normal)
            $0.setTitleColor(.lightGray, for: .disabled)
            $0.layer.cornerRadius = 8
            $0.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
            $0.heightAnchor.constraint(equalToConstant: 44).isActive = true
        }
        startRecBtn.addTarget(self, action: #selector(startRecTapped), for: .touchUpInside)
        pauseRecBtn.addTarget(self, action: #selector(pauseRecTapped), for: .touchUpInside)
        saveRecBtn.addTarget(self, action: #selector(saveRecTapped), for: .touchUpInside)
        saveRecBtn.backgroundColor = .systemGreen
        let recBtnStack = UIStackView(arrangedSubviews: [startRecBtn, pauseRecBtn, saveRecBtn])
        recBtnStack.axis = .horizontal; recBtnStack.spacing = 10; recBtnStack.distribution = .fillEqually

        // 声波动画容器
        waveContainer.isHidden = true
        waveContainer.heightAnchor.constraint(equalToConstant: 40).isActive = true
        for _ in 0..<9 {
            let bar = UIView()
            bar.backgroundColor = .systemBlue
            bar.layer.cornerRadius = 2
            bar.translatesAutoresizingMaskIntoConstraints = false
            waveContainer.addSubview(bar)
            waveBars.append(bar)
        }
        layoutWaveBars()

        let recStack = UIStackView(arrangedSubviews: [recordTimeLabel, waveContainer, recBtnStack])
        recStack.axis = .vertical; recStack.spacing = 16
        recStack.translatesAutoresizingMaskIntoConstraints = false
        recordCard.addSubview(recStack)
        NSLayoutConstraint.activate([
            recStack.topAnchor.constraint(equalTo: recordCard.topAnchor, constant: 16),
            recStack.leadingAnchor.constraint(equalTo: recordCard.leadingAnchor, constant: 16),
            recStack.trailingAnchor.constraint(equalTo: recordCard.trailingAnchor, constant: -16),
            recStack.bottomAnchor.constraint(equalTo: recordCard.bottomAnchor, constant: -16),
        ])

        // 文件卡片
        styleCard(fileCard)
        fileHeaderLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        fileHeaderLabel.text = "🎵 音频文件 (0)"
        refreshBtn.setTitle("刷新", for: .normal)
        refreshBtn.addTarget(self, action: #selector(refreshFiles), for: .touchUpInside)
        filterSegment.selectedSegmentIndex = 0
        filterSegment.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
        let fileHeader = UIStackView(arrangedSubviews: [fileHeaderLabel, refreshBtn])
        fileHeader.axis = .horizontal; fileHeader.alignment = .center
        tableView.register(FileCell.self, forCellReuseIdentifier: FileCell.reuseId)
        tableView.dataSource = self; tableView.delegate = self
        tableView.isScrollEnabled = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 70
        // 高度约束：由 reloadFileTable 动态更新
        tableViewHeightConstraint = tableView.heightAnchor.constraint(equalToConstant: 0)
        tableViewHeightConstraint?.isActive = true
        let fileStack = UIStackView(arrangedSubviews: [fileHeader, filterSegment, tableView])
        fileStack.axis = .vertical; fileStack.spacing = 8
        fileStack.translatesAutoresizingMaskIntoConstraints = false
        fileCard.addSubview(fileStack)
        NSLayoutConstraint.activate([
            fileStack.topAnchor.constraint(equalTo: fileCard.topAnchor, constant: 16),
            fileStack.leadingAnchor.constraint(equalTo: fileCard.leadingAnchor, constant: 16),
            fileStack.trailingAnchor.constraint(equalTo: fileCard.trailingAnchor, constant: -16),
            fileStack.bottomAnchor.constraint(equalTo: fileCard.bottomAnchor, constant: -16),
        ])

        // 主布局
        let mainStack = UIStackView(arrangedSubviews: [connectCard, connectedCard, recordCard, fileCard])
        mainStack.axis = .vertical; mainStack.spacing = 16
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
        ])
    }

    private func styleCard(_ v: UIView) {
        v.backgroundColor = .secondarySystemGroupedBackground
        v.layer.cornerRadius = 12
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.06
        v.layer.shadowOffset = CGSize(width: 0, height: 2)
        v.layer.shadowRadius = 4
    }
}

// MARK: - Actions
extension MainViewController {
    @objc private func openScan() {
        let vc = ScanViewController()
        vc.onConnected = { [weak self] in
            guard let self = self else { return }
            AIRECBleManager.shared.delegate = self
        }
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    @objc private func otaTapped() {
        let dev = AIRECBleManager.shared.getConnectedDevice()
        let ver = dev?.firmwareVersion.isEmpty == false ? dev!.firmwareVersion : "未知"
        let alert = UIAlertController(title: "OTA 固件升级",
            message: "当前固件版本：\(ver)\n\n升级步骤：\n1. 将固件文件(.bin)放入设备存储根目录\n2. 重命名为 update.bin\n3. 重启设备，设备将自动完成升级",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    @objc private func disconnectTapped() {
        let alert = UIAlertController(title: "断开连接", message: "确认断开蓝牙连接？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "断开", style: .destructive) { [weak self] _ in
            self?.lastDevice = nil
            AIRECBleManager.shared.disconnect()
            self?.showDisconnectedUI()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func refreshFiles() {
        // 先显示本地音频，再刷新设备
        let localItems = AudioStore.shared.loadLocalItems()
        if !localItems.isEmpty && allItems.isEmpty {
            allItems = localItems.sorted { $0.createTime > $1.createTime }
            applyFilter()
        }
        guard AIRECBleManager.shared.isConnected else { showToast("请先连接设备"); return }
        AIRECBleManager.shared.fetchFileList()
    }

    @objc private func filterChanged() {
        currentFilter = AudioFilter(rawValue: filterSegment.selectedSegmentIndex) ?? .all
        applyFilter()
    }

    @objc private func startRecTapped() {
        // 开启实时音频流监听
        AIRECBleManager.shared.onAudioStreamData = { data in
            let bytes = [UInt8](data)
            print("AIREC_STREAM: received \(data.count) bytes, header: \(bytes.prefix(min(4, bytes.count)).map{String(format:"%02X",$0)}.joined(separator:" "))")
        }
        AIRECBleManager.shared.startRecord()
        isRecording = true;
        isPaused = false
        startLocalTimer();
        updateRecordButtons()
        startWaveAnimation()
    }

    @objc private func pauseRecTapped() {
        appInitiatedPauseResume = true  // 标记为 App 主动发起
        if isPaused {
            AIRECBleManager.shared.resumeRecord()
            isPaused = false;
            pauseRecBtn.setTitle("暂停", for: .normal);
            resumeLocalTimer()
            startWaveAnimation()
        } else {
            AIRECBleManager.shared.pauseRecord()
            isPaused = true;
            pauseRecBtn.setTitle("继续", for: .normal);
            pauseLocalTimer()
            stopWaveAnimation()
        }
        updateRecordButtons()
    }

    @objc private func saveRecTapped() {
        // 停止实时音频流监听
        AIRECBleManager.shared.onAudioStreamData = nil
        AIRECBleManager.shared.endRecord()
        isRecording = false; isPaused = false
        stopLocalTimer()
        stopWaveAnimation()
        recordTimeLabel.text = "00:00:00"; recordTimeLabel.textColor = .systemBlue
        updateRecordButtons()
    }

    // MARK: - Settings Actions
    @objc private func ledSwitchChanged() { AIRECBleManager.shared.sendLedSwitch(ledSwitch.isOn) }
    @objc private func usbSwitchChanged() { AIRECBleManager.shared.sendUsbSwitch(usbSwitch.isOn) }
    @objc private func powerOnRecChanged() { AIRECBleManager.shared.sendPowerOnRecord(powerOnRecSwitch.isOn) }
    @objc private func decibelSwitchChanged() {
        decibelEnabled = decibelSwitch.isOn
        if decibelEnabled && isRecording && !isPaused {
            startWaveAnimation()
        } else {
            stopWaveAnimation()
        }
    }

    @objc private func segmentTapped() {
        let opts = [0, 5, 10, 15, 30, 60, 120, 180, 240, 480]
        let sheet = UIAlertController(title: "分段录音时间", message: nil, preferredStyle: .actionSheet)
        for min in opts {
            let label = segmentLabel(min)
            sheet.addAction(UIAlertAction(title: label, style: .default) { [weak self] _ in
                AIRECBleManager.shared.sendSegmentDuration(min)
                self?.segmentBtn.setTitle(label, for: .normal)
            })
        }
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(sheet, animated: true)
    }

    @objc private func idleTapped() {
        let opts = [0, 3, 5, 10, 15, 30, 60, 120, 240]
        let sheet = UIAlertController(title: "空闲关机时间", message: nil, preferredStyle: .actionSheet)
        for min in opts {
            let label = idleLabel(min)
            sheet.addAction(UIAlertAction(title: label, style: .default) { [weak self] _ in
                AIRECBleManager.shared.sendIdleShutdown(min)
                self?.idleBtn.setTitle(label, for: .normal)
            })
        }
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(sheet, animated: true)
    }

    @objc private func micGainTapped() {
        let sheet = UIAlertController(title: "麦克风增益", message: nil, preferredStyle: .actionSheet)
        for g in 1...7 {
            sheet.addAction(UIAlertAction(title: "增益 \(g)", style: .default) { [weak self] _ in
                AIRECBleManager.shared.sendMicGain(g)
                self?.micGainBtn.setTitle("\(g)", for: .normal)
            })
        }
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(sheet, animated: true)
    }

    @objc private func safeCodeTapped() { showCodeInput(title: "安全码", hint: "请输入安全码") }
    @objc private func activateCodeTapped() { showCodeInput(title: "激活码", hint: "请输入激活码") }

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

    @objc private func formatTapped() {
        let alert = UIAlertController(title: "⚠️ 格式化存储", message: "此操作将清除设备上所有录音文件，且不可恢复。\n\n确定要继续吗？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定格式化", style: .destructive) { [weak self] _ in
            guard let self = self else { return }

            // 风火轮 loading
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

            AIRECBleManager.shared.sendFormatDisk()
            AIRECBleManager.shared.onFormatResult = { [weak self] success, msg in
                guard let self = self else { return }
                hud.dismiss(animated: true) {
                    self.showToast(success ? "✅ \(msg)" : "❌ \(msg)")
                    if success {
                        // 清空本地文件列表
                        self.allItems.removeAll()
                        self.filteredItems.removeAll()
                        self.displayItems.removeAll()
                        self.fileStates.removeAll()
                        self.currentPage = 0
                        self.reloadFileTable()
                        // 刷新设备信息和文件列表
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            AIRECBleManager.shared.fetchDeviceInfo()
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            AIRECBleManager.shared.fetchFileList()
                        }
                    }
                }
            }

            // 超时保护：10秒没回包自动关闭
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

// MARK: - UI State
extension MainViewController {
    
    private func showConnectedUI() {
        connectCard.isHidden = true
        connectedCard.isHidden = false;
        recordCard.isHidden = false
        fileCard.isHidden = false
        if let dev = AIRECBleManager.shared.getConnectedDevice() {
            lastDevice = dev;
            updateDeviceInfo(dev)
        }
        // 如果设备在录音中，同步显示录音状态
        if isRecording {
            recordTimeLabel.textColor = .systemRed
            if !isPaused {
                startLocalTimer()
            }
        }
        updateRecordButtons()
    }

    private func showDisconnectedUI() {
        connectCard.isHidden = false
        connectedCard.isHidden = true; recordCard.isHidden = true; fileCard.isHidden = true
        isRecording = false; isPaused = false
        recordTimeLabel.text = "00:00:00"
        allItems.removeAll(); filteredItems.removeAll(); displayItems.removeAll()
        fileStates.removeAll(); currentPage = 0
        // 断开连接后仍显示本地音频
        let localItems = AudioStore.shared.loadLocalItems()
        if !localItems.isEmpty {
            allItems = localItems.sorted { $0.createTime > $1.createTime }
            applyFilter()
        } else {
            tableView.reloadData()
            tableViewHeightConstraint?.constant = 0
            fileHeaderLabel.text = "🎵 音频文件 (0)"
        }
    }

    private func updateDeviceInfo(_ dev: AIRECBleDevice) {
        nameLabel.text     = dev.name
        batteryLabel.text  = "电量：\(dev.battery)%"
        storageLabel.text  = "存储：\(dev.storageStr)"
        firmwareLabel.text = "固件：\(dev.firmwareVersion.isEmpty ? "读取中..." : dev.firmwareVersion)"
        let mac = AIRECBleManager.shared.macAddress
        macLabel.text = "SN：\(mac.isEmpty ? "--" : mac)"
        // 更新设置开关
        let mgr = AIRECBleManager.shared
        ledSwitch.isOn = mgr.ledSwitch
        usbSwitch.isOn = mgr.usbSwitch
        powerOnRecSwitch.isOn = mgr.powerOnRecord
        segmentBtn.setTitle(segmentLabel(mgr.segmentDuration), for: .normal)
        idleBtn.setTitle(idleLabel(mgr.idleShutdown), for: .normal)
        micGainBtn.setTitle("\(mgr.micGain)", for: .normal)
    }

    private func updateRecordButtons() {
        startRecBtn.isEnabled = !isRecording
        pauseRecBtn.isEnabled = isRecording
        saveRecBtn.isEnabled  = isRecording
        startRecBtn.backgroundColor = isRecording ? .systemGray4 : .systemBlue
        saveRecBtn.backgroundColor  = isRecording ? .systemGreen : .systemGray4
        if !isRecording { pauseRecBtn.setTitle("暂停", for: .normal) }
    }

    // MARK: - 文件列表（统一模型 + 分页 + 过滤 + 排序）

    private func mergeAndDisplay(deviceFiles: [AIRECBleFile]) {
        print("AIREC_iOS: mergeAndDisplay called with \(deviceFiles.count) device files")
        let audioExts: Set<String> = ["wav","mp3","aac","m4a","ogg","opus","flac","pcm","amr"]
        let filtered = deviceFiles.filter { f in
            let name = f.fileName.lowercased()
            guard let dot = name.lastIndex(of: ".") else { return true }
            return audioExts.contains(String(name[name.index(after: dot)...]))
        }
        // 去重：同一文件名只保留一个（优先保留有本地路径的）
        var seen: Set<String> = []
        var deduped: [AIRECBleFile] = []
        for f in filtered {
            if !seen.contains(f.fileName) {
                seen.insert(f.fileName)
                deduped.append(f)
            }
        }

        let deviceItems = deduped.map { f -> AudioItem in
            AudioItem(from: f, localPath: AudioStore.shared.localPath(for: f.fileName))
        }
        let localOnly = AudioStore.shared.loadLocalItems().filter { local in
            !deviceItems.contains(where: { $0.id == local.id })
        }
        var merged = deviceItems + localOnly
        merged.sort { a, b in
            // 最新时间排前面；时间相同时按文件名倒序（时间戳文件名场景下倒序=更新）
            if a.createTime == b.createTime { return a.fileName > b.fileName }
            if a.createTime.isEmpty { return false }
            if b.createTime.isEmpty { return true }
            return a.createTime > b.createTime
        }
        allItems = merged
        applyFilter()
    }

    private func applyFilter() {
        switch currentFilter {
        case .all:    filteredItems = allItems
        case .device: filteredItems = allItems.filter { $0.isDevice }
        case .local:  filteredItems = allItems.filter { $0.isLocal }
        }
        currentPage = 0
        displayItems = Array(filteredItems.prefix(pageSize))
        reloadFileTable()
    }

    private func loadNextPage() {
        guard hasMorePages else { return }
        currentPage += 1
        let start = currentPage * pageSize
        let end = min(start + pageSize, filteredItems.count)
        displayItems.append(contentsOf: filteredItems[start..<end])
        reloadFileTable()
    }

    private func reloadFileTable() {
        tableView.reloadData()
        let total = filteredItems.count
        let showing = displayItems.count
        let moreText = hasMorePages ? " (\(showing)/\(total)，上拉加载更多)" : ""
        fileHeaderLabel.text = "🎵 音频文件 (\(total))\(moreText)"
        // 更新高度约束，让 ScrollView 正确撑开
        let rowH: CGFloat = 72
        tableViewHeightConstraint?.constant = CGFloat(max(displayItems.count, 0)) * rowH
        // 强制布局更新
        UIView.animate(withDuration: 0) {
            self.contentView.layoutIfNeeded()
        }
        print("AIREC_iOS: reloadFileTable total=\(total) showing=\(showing) height=\(CGFloat(displayItems.count) * rowH)")
    }

        private func startLocalTimer() {
        recordStartDate = Date(); pausedElapsed = 0
        timerLink?.invalidate()
        timerLink = CADisplayLink(target: self, selector: #selector(tickTimer))
        timerLink?.add(to: .main, forMode: .common)
        recordTimeLabel.textColor = .systemRed
    }
    private func resumeLocalTimer() {
        recordStartDate = Date()
        timerLink?.invalidate()
        timerLink = CADisplayLink(target: self, selector: #selector(tickTimer))
        timerLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 1, maximum: 1, preferred: 1)
        timerLink?.add(to: .main, forMode: .common)
        recordTimeLabel.textColor = .systemRed
    }
    private func pauseLocalTimer() {
        pausedElapsed += Date().timeIntervalSince(recordStartDate)
        timerLink?.invalidate(); timerLink = nil
    }
    private func stopLocalTimer() {
        timerLink?.invalidate(); timerLink = nil; pausedElapsed = 0
    }
    @objc private func tickTimer() {
        let total = Int(pausedElapsed + Date().timeIntervalSince(recordStartDate))
        recordTimeLabel.text = String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }
    private func startBatteryPoll() {
        batteryTimer?.invalidate()
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self = self, self.isRecording, AIRECBleManager.shared.isConnected else { return }
            AIRECBleManager.shared.fetchDeviceInfo()
        }
    }
    private func stopBatteryPoll() { batteryTimer?.invalidate(); batteryTimer = nil }

    // MARK: - 声波动画
    private func layoutWaveBars() {
        let barW: CGFloat = 4, spacing: CGFloat = 4
        let totalW = CGFloat(waveBars.count) * barW + CGFloat(waveBars.count - 1) * spacing
        let startX = (UIScreen.main.bounds.width - 64) / 2 - totalW / 2 // approximate center
        for (i, bar) in waveBars.enumerated() {
            NSLayoutConstraint.activate([
                bar.widthAnchor.constraint(equalToConstant: barW),
                bar.bottomAnchor.constraint(equalTo: waveContainer.bottomAnchor),
                bar.heightAnchor.constraint(equalToConstant: 8),
                bar.leadingAnchor.constraint(equalTo: waveContainer.leadingAnchor,
                    constant: startX + CGFloat(i) * (barW + spacing))
            ])
        }
    }

    private func startWaveAnimation() {
        guard decibelEnabled else { return }
        waveContainer.isHidden = false
        waveTimer?.invalidate()
        waveTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            guard let self = self, self.decibelEnabled, self.isRecording, !self.isPaused else {
                self?.stopWaveAnimation(); return
            }
            for bar in self.waveBars {
                let h = CGFloat(8 + Int.random(in: 0..<32))
                bar.constraints.first(where: { $0.firstAttribute == .height })?.constant = h
            }
            UIView.animate(withDuration: 0.1) { self.waveContainer.layoutIfNeeded() }
        }
    }

    private func stopWaveAnimation() {
        waveTimer?.invalidate(); waveTimer = nil
        waveContainer.isHidden = true
    }
}

// MARK: - UITableView
extension MainViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { displayItems.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FileCell.reuseId, for: indexPath) as! FileCell
        let item = displayItems[indexPath.row]
        let state = fileStates[item.id] ?? (item.isLocal ? .done : .idle)
        cell.configure(item: item, state: state)
        cell.delegate = self
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row == displayItems.count - 1 && hasMorePages { loadNextPage() }
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let del = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, done in
            self?.confirmDelete(at: indexPath); done(true)
        }
        return UISwipeActionsConfiguration(actions: [del])
    }

    private func confirmDelete(at indexPath: IndexPath) {
        let item = displayItems[indexPath.row]
        let alert = UIAlertController(title: "删除文件", message: "确认删除 \(item.fileName)？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            // 删除设备文件
            if item.isDevice { AIRECBleManager.shared.deleteFile(item.fileName) }
            // 删除本地文件
            AudioStore.shared.delete(id: item.id)
            // 从列表移除
            self.allItems.removeAll { $0.id == item.id }
            self.applyFilter()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - FileCellDelegate
extension MainViewController: FileCellDelegate {
    func fileCellDidTapDownload(_ cell: FileCell) {
        guard let ip = tableView.indexPath(for: cell) else { return }
        let item = displayItems[ip.row]
        guard AIRECBleManager.shared.isConnected else { showToast("请先连接设备"); return }
        fileStates[item.id] = .downloading(0)
        tableView.reloadRows(at: [ip], with: .none)
        // 从设备文件列表找到对应文件发起下载
        if let bleFile = AIRECBleManager.shared.getConnectedDevice()?.fileList.first(where: { $0.fileName == item.fileName }) {
            AIRECBleManager.shared.downloadFile(bleFile)
        } else {
            // 设备文件列表为空时先刷新再提示
            showToast("请先刷新文件列表")
            fileStates[item.id] = .idle
            tableView.reloadRows(at: [ip], with: .none)
        }
    }
    func fileCellDidTapPlay(_ cell: FileCell) {
        guard let ip = tableView.indexPath(for: cell) else { return }
        let item = displayItems[ip.row]
        // 优先用持久化路径，其次用 SDK 缓存路径
        var basePath = item.localPath ?? AudioStore.shared.localPath(for: item.fileName)
                       ?? AIRECBleManager.shared.getLocalPath(item.fileName)
        // 如果基础路径不存在，尝试带扩展名的变体
        if let bp = basePath, !FileManager.default.fileExists(atPath: bp) {
            for ext in [".caf", ".opus", ".mp3", ".wav", ".aac", ".m4a"] {
                let candidate = bp + ext
                if FileManager.default.fileExists(atPath: candidate) { basePath = candidate; break }
            }
        }
        guard let localPath = basePath, FileManager.default.fileExists(atPath: localPath) else {
            showToast("文件不存在，请重新下载"); return
        }
        navigationController?.pushViewController(
            AudioPlayViewController(filePath: localPath, fileName: item.fileName, fileSize: item.fileSizeStr),
            animated: true)
    }
}

// MARK: - AIRECBleDelegate
extension MainViewController: AIRECBleDelegate {

    func bleManager(_ manager: AIRECBleManager, didConnect device: AIRECBleDevice) {
        print("AIREC_iOS: MainVC didConnect called, device=\(device.name)")

        print("AIREC_iOS: didConnect called, device=\(device.name)")

        lastDevice = device;
        initialInfoFetched = false
        // 立即接管 delegate，防止 ScanViewController dismiss 后回调丢失
        AIRECBleManager.shared.delegate = self
        showConnectedUI()
        // 立即显示本地已下载音频
        let localItems = AudioStore.shared.loadLocalItems()
        if !localItems.isEmpty {
            allItems = localItems.sorted { $0.createTime > $1.createTime }
            applyFilter()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self, AIRECBleManager.shared.isConnected else { return }
            AIRECBleManager.shared.delegate = self
            AIRECBleManager.shared.fetchAllDeviceInfo()
            // 单独查询录音状态，同步设备当前录音状态到 UI
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard self != nil, AIRECBleManager.shared.isConnected else { return }
                AIRECBleManager.shared.fetchDeviceInfo()  // 包含 recordStatus
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            guard self != nil, AIRECBleManager.shared.isConnected else { return }
            AIRECBleManager.shared.fetchFileList()
        }

    }

    func bleManager(_ manager: AIRECBleManager, didDisconnect device: AIRECBleDevice?, reason: String) {
        stopBatteryPoll();
        stopLocalTimer();
        initialInfoFetched = false
        showDisconnectedUI()
        if let last = lastDevice {
            showToast("设备断开，3秒后自动重连...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard let self = self, !AIRECBleManager.shared.isConnected, self.lastDevice != nil else { return }
                AIRECBleManager.shared.connect(last)
            }
        } else { showToast("设备已断开") }
    }

    func bleManager(_ manager: AIRECBleManager, didUpdateDeviceInfo device: AIRECBleDevice) {
        updateDeviceInfo(device)
    }

    func bleManager(_ manager: AIRECBleManager, didUpdateFileList files: [AIRECBleFile]) {
        print("AIREC_iOS: didUpdateFileList called with \(files.count) files")
        if AIRECBleManager.shared.isConnected && connectedCard.isHidden { showConnectedUI()
        }
        mergeAndDisplay(deviceFiles: files)
    }

    func bleManager(_ manager: AIRECBleManager, didDeleteFile fileName: String, success: Bool) {
        showToast(success ? "删除成功" : "删除失败")
        if success { AIRECBleManager.shared.fetchFileList()
        }
    }

    func bleManager(_ manager: AIRECBleManager, didChangeRecordState recording: Bool, fileName: String) {
        isRecording = recording; isPaused = false
        pauseRecBtn.setTitle("暂停", for: .normal)
        if !recording {
            recordTimeLabel.text = "00:00:00"; recordTimeLabel.textColor = .systemBlue
            stopLocalTimer(); stopBatteryPoll()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                guard AIRECBleManager.shared.isConnected else { return }
                AIRECBleManager.shared.fetchDeviceInfo()
                AIRECBleManager.shared.fetchFirmwareVersion()
                AIRECBleManager.shared.fetchFileList()
            }
        } else {
            if isResumingFromPause {
                isResumingFromPause = false
                // 从暂停恢复，不重置计时
            } else {
                startLocalTimer()  // 开始新计时（连接时设备已在录音也从0开始）
            }
            startBatteryPoll()
        }
        updateRecordButtons()
        // 连接后第一次收到录音状态，标记已同步
        if !initialInfoFetched { initialInfoFetched = true }
        showToast(recording ? "录音中" : "录音已保存")
    }

    func bleManagerDidPauseRecord(_ manager: AIRECBleManager) {
        // 0x10 回包：
        // - 如果是 App 主动发的（appInitiatedPauseResume=true），UI 已更新，只需清标志
        // - 如果是设备端按键触发的，根据当前状态 toggle
        if appInitiatedPauseResume {
            appInitiatedPauseResume = false
            // UI 已经在按钮点击时更新，不需要再 toggle
        } else {
            // 设备端按键触发
            if isPaused {
                isPaused = false
                pauseRecBtn.setTitle("暂停", for: .normal)
                resumeLocalTimer()
            } else {
                isPaused = true
                pauseRecBtn.setTitle("继续", for: .normal)
                pauseLocalTimer()
            }
            startBatteryPoll()
            updateRecordButtons()
        }
    }

    func bleManager(_ manager: AIRECBleManager, didQueryRecordStatus recording: Bool, paused: Bool, fileName: String) {
        // 同步设备录音状态到 UI（每次都同步，不限制次数）
        let wasRecording = isRecording
        isRecording = recording; isPaused = paused
        pauseRecBtn.setTitle(paused ? "继续" : "暂停", for: .normal)
        if recording && !paused {
            if !wasRecording { startLocalTimer() }  // 只在从未录音变为录音时启动计时
            startBatteryPoll()
        } else if paused {
            if wasRecording && !isPaused { pauseLocalTimer() }
            startBatteryPoll()
        } else {
            if wasRecording { stopLocalTimer(); recordTimeLabel.text = "00:00:00" }
            stopBatteryPoll()
        }
        updateRecordButtons()
        // 只在第一次连接时补查文件列表
        if !initialInfoFetched {
            initialInfoFetched = true
            if !recording {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    guard AIRECBleManager.shared.isConnected else { return }
                    AIRECBleManager.shared.fetchFileList()
                }
            }
        }
    }


    func bleManager(_ manager: AIRECBleManager, didUpdateRecordDuration durationSec: Int64) {
        recordStartDate = Date().addingTimeInterval(-TimeInterval(durationSec))
        pausedElapsed = 0
        let h = durationSec / 3600, m = (durationSec % 3600) / 60, s = durationSec % 60
        recordTimeLabel.text = String(format: "%02d:%02d:%02d", h, m, s)
    }

    func bleManager(_ manager: AIRECBleManager, didReceiveFirmwareVersion version: String) {
        if !version.isEmpty { firmwareLabel.text = "固件：\(version)" }
    }

    func bleManager(_ manager: AIRECBleManager, didChangeBluetoothState enabled: Bool) {
        if !enabled { lastDevice = nil; showToast("蓝牙已关闭"); showDisconnectedUI() }
    }

    func bleManager(_ manager: AIRECBleManager, downloadProgress file: AIRECBleFile, progress: Int) {
        fileStates[file.fileName] = .downloading(progress)
        reloadDisplayCell(id: file.fileName)
    }

    func bleManager(_ manager: AIRECBleManager, downloadComplete file: AIRECBleFile, localPath: String) {
        fileStates[file.fileName] = .done
        // 持久化到本地存储
        let savedItem = AudioItem(from: file, localPath: localPath)
        AudioStore.shared.save(savedItem)
        // 更新 allItems 里的 localPath
        if let idx = allItems.firstIndex(where: { $0.id == file.fileName }) {
            allItems[idx].localPath = localPath
        } else {
            allItems.append(savedItem)
            allItems.sort { $0.createTime > $1.createTime }
        }
        applyFilter()
        showToast("下载完成：\(file.fileName)")
    }

    func bleManager(_ manager: AIRECBleManager, downloadFailed file: AIRECBleFile, reason: String) {
        fileStates[file.fileName] = .error
        for (k, v) in fileStates { if case .downloading = v { fileStates[k] = .idle } }
        tableView.reloadData()
        showToast("下载失败：\(reason)")
    }

    private func reloadDisplayCell(id: String) {
        if let idx = displayItems.firstIndex(where: { $0.id == id }) {
            tableView.reloadRows(at: [IndexPath(row: idx, section: 0)], with: .none)
        }
    }
}

// MARK: - Helpers
extension UIViewController {
    func showAlert(title: String, message: String) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "确定", style: .default))
        present(a, animated: true)
    }

    }
