# AIRECIOSBleDemo

iOS 版 AIREC 蓝牙设备 Demo，与 Android 版 AIRECBleDemo 功能完全对应。

## 功能

- 扫描所有 BLE 设备（无设备名过滤）
- 连接 / 断开 / 自动重连
- 设备信息：名称、电量、存储、固件版本
- 录音控制：开始 / 暂停 / 继续 / 保存
- 实时录音计时（设备推送 0x3B 时以设备为准）
- 文件列表查询、左滑删除
- 文件下载（进度条）+ 音频格式自动识别
- 音频播放（AVAudioPlayer）：播放/暂停、快进/快退 10s、进度条
- 文件分享（保存到系统）

## 协议

帧格式与 Android SDK 完全一致：
- 发送：`55 AA [length] [cmd] [data...]`
- 接收：`AA 55 [length] [cmd] [data...]`

## 运行

1. 用 Xcode 打开 `AIRECIOSBleDemo.xcodeproj`
2. 选择真机（BLE 需要真实设备，模拟器不支持）
3. 设置 Development Team
4. Build & Run

## 最低系统要求

iOS 14.0+
