# Code Style

这个文件记录本项目的代码规范和个人偏好。新增代码、重构代码、命名类和方法时，优先参考这里。

## 命名

- 类名使用清晰的职责名，例如 `AudioPlaybackManager`、`AudioWaveformAnalyzer`、`AudioFormatDetector`。
- 方法名尽量表达业务含义，不只表达技术动作。
- 对音频格式识别这类方法，使用 `getAudioIdentifyType(path:)`。
- 避免过度缩写。除非是通用缩写，例如 `URL`、`ID`、`BLE`。

## 职责拆分

- 播放控制放在 `AudioPlaybackManager`。
- 波形分析放在 `AudioWaveformAnalyzer`。
- 音频格式识别放在 `AudioFormatDetector`。
- 一个类只处理一类核心事情。如果某个方法开始和当前类职责不太相关，优先考虑抽成独立工具类。

## Swift 写法

- 优先使用 `guard` 提前返回，减少多层嵌套。
- 异步回调里使用 `[weak self]`，避免循环引用。
- UI 更新放到主线程。
- 文件、音频、蓝牙等耗时操作放到后台队列。
- 属性能 `private` 就 `private`，需要外部只读时使用 `private(set)`。

## SnapKit 布局

- 新增 UIKit 页面和自定义 View 时，优先使用 SnapKit 写约束。
- 子视图添加顺序保持清晰：先 `addSubview`，再统一 `snp.makeConstraints`。
- 约束尽量写在 `setupUI`、`setupConstraints` 或对应的初始化配置方法里。
- 固定高度、间距、边距使用明确数值，避免魔法计算散落在业务代码里。
- 多个视图共用的间距可以抽成局部常量，例如 `let horizontalInset = 16`。
- 更新约束时使用 `snp.updateConstraints` 或保存 `Constraint` 引用，不重复创建冲突约束。
- 简单布局不要混用 frame 和 Auto Layout。确实需要手动布局时，集中放在 `layoutSubviews` 或 `viewDidLayoutSubviews`。
- 约束关系优先表达业务结构，例如 `make.top.equalTo(titleLabel.snp.bottom).offset(8)`，比硬算 y 值更好维护。

## 音频相关

- 对无扩展名音频文件，先通过文件头识别真实格式。
- 私有音频格式转换逻辑继续放在 `ATWOpusConverter`。
- 播放逻辑优先使用 `AVAudioPlayer`，不支持时再兜底到 `AVPlayer`。
- 波形只表示振幅变化，不表示语义、音高或频谱。

## 注释

- 注释解释“为什么这样做”，少写“这行代码做了什么”。
- 对格式识别、私有协议、蓝牙流程这类不直观逻辑，可以加简短注释。
- 删除废弃代码，不长期保留大段注释代码。

## 文件组织

- Manager 类放在 `AIRECIOSBleDemo/Manager`。
- View 类放在 `AIRECIOSBleDemo/View`。
- ViewController 放在 `AIRECIOSBleDemo/ViewController`，旧文件暂时保留原位置。
- Model 放在 `AIRECIOSBleDemo/Model`。

## 重构原则

- 先保证行为不变，再调整结构。
- 重复逻辑优先收敛成一个公共方法或工具类。
- 改动范围尽量小，不顺手改无关代码。
- 命名以当前项目读起来顺为准，不为了“标准英文”牺牲自己的理解成本。
