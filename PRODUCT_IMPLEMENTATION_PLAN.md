# Ruffnova 产品功能设计与施工方案

## 1. 目标与原则

Ruffnova 的核心定位是 Apple 平台上的本地 Flash 作品库与播放器，而不仅是可打开 `.swf` 文件的运行器。首要体验是：用户导入一批旧作品后，能快速找到、稳定运行、恢复上次进度，并在兼容性或权限问题出现时知道如何处理。

本计划按以下原则执行：

- 可靠性优先于新的视觉与播放控制功能。
- 优先扩展现有 `LibraryItem`、`LibraryService`、`PermissionPolicyService`、`DiagnosticsService`，不新增平行的持久化来源。
- macOS 与 iOS 共享领域模型和业务规则；仅在输入、文件访问和呈现层分平台实现。
- 每一阶段均包含迁移、失败恢复、测试与本地化，不以只有 UI 的功能作为完成标准。

## 2. 当前基础与缺口

| 已有基础 | 可直接复用 | 主要缺口 |
| --- | --- | --- |
| 资源库 | `LibraryItem` 已保存标签、备注、缩略图、内容类型、兼容性状态、最后播放帧和文件级播放偏好 | 缺少可编辑的文件级运行配置、智能视图和批量导入反馈 |
| 资源组织 | `CollectionService` 已支持创建、改名、删除、持久化、排序和条目归属 | 缺少面向高频任务的智能集合与来源维度 |
| 权限 | `PermissionPolicyService` 已有网络/文件系统全局默认值、单文件覆盖和持久化 | Swift 策略尚未接入 Ruffle Navigator，当前不能拦截 SWF 的实际网络/文件访问 |
| 诊断 | 兼容性报告可显示文件、运行信息、问题、trace 并复制文本 | 缺少脱敏、报告包、提交问题和运行历史 |
| 播放器 | 已有动画/互动内容区分、模式、全屏、时间轴、速度、循环、音量和截图 | 缺少可靠的键盘焦点、可配置输入和手柄支持 |
| 导入 | 支持单个 SWF、目录扫描和 macOS ZIP 解压 | ZIP 依赖 macOS `/usr/bin/unzip`，不适用于 iOS 或受沙盒约束的发行方式；缺少导入预览、重复项策略、进度和结果反馈 |

## 3. 路线图

| 阶段 | 名称 | 目标 | 交付门槛 |
| --- | --- | --- | --- |
| P0 | 播放可靠性基线 | 让打开、加载、全屏、暂停和错误恢复状态可信 | 新增 FFI 加载状态观测；自动化状态测试与人工回归矩阵均通过 |
| P1 | 文件级运行档案 | 让用户能为不同 SWF 保存正确的运行方式 | 配置在重启后恢复，且可一键重置；需要重载的设置有明确提示 |
| P1b | 引擎访问边界 | 让单文件网络/文件系统策略真正约束 SWF | Rust Navigator 已执行策略，拒绝与授权均可审计 |
| P2 | 导入与资源库工作流 | 让大批量导入、查找和整理可预测 | 导入结果可见，重复项和失效文件可处理 |
| P3a | 游戏输入 | 让互动 SWF 的键盘、手柄和触控输入可管理 | macOS/iOS 键盘映射、焦点和虚拟按键可用 |
| P3b | 存档管理 | 让支持本地存储的作品可管理数据 | 新增跨平台存储后端与存档 FFI 后，才交付导入/导出/清除 |
| P4 | 兼容性支持闭环 | 让问题可诊断、可复现、可反馈 | 用户能生成脱敏报告包并发起 Issue |

P0 是 P1-P4 的前置条件；P1 与 P2 可并行；P1b 依赖 Rust FFI 的策略设计；P3a 可在 P0 后实施；P3b 依赖存档 FFI 可行性验证；P4 可在 P0 后并行推进。

## 4. P0：播放可靠性基线

### 功能设计

- 打开文件后显示可感知的加载状态；加载成功、失败、超时和用户取消均是互斥状态。
- 错误界面提供“重试”“回到资料库”“查看诊断”三个明确动作。
- macOS 全屏状态以窗口回调为唯一事实来源，避免按 Esc 退出后 Swift 状态、FFI 状态和窗口状态不一致；iOS 使用应用内“舞台沉浸模式”，只控制舞台布局、状态栏与导航栏，不模拟原生窗口全屏。
- 导航到资源库、搜索、诊断或设置时默认不暂停播放；仅在离开播放器且用户显式选择暂停时变更播放状态。
- 快速重复打开同一文件或连续打开不同文件时，后一次请求取消前一次加载并释放前一播放器资源。

### 施工方案

1. 在 Rust FFI 新增可轮询的 `ruffle_player_get_load_state`，至少区分 `loading`、`ready`、`failed`，并提供稳定错误码/消息。`load_url` 返回“请求已接受”而非“影片已加载”，不得据此结束 Swift 加载态。
2. 在 `AppState` 引入内部 `PlayerLoadState`：`idle`、`loading(requestID)`、`ready`、`failed(PlayerLoadError)`。保留现有 `isLoading` 作为由状态推导的过渡属性，随后逐步移除直接写入。
3. 为 `openFile` 分配 UUID 请求标识；桥接加载状态仅在请求标识仍匹配时更新。超时任务与旧请求绑定，取消旧请求时一并失效。
4. macOS 在窗口全屏通知中更新 `isFullscreen`，再同步到 bridge；iOS 将 `isStageMaximized` 作为独立的应用内舞台状态，不依赖不存在的原生窗口全屏回调。
5. 将加载错误归类为文件不可读、bridge 初始化失败、引擎加载失败、超时和用户取消，并映射到本地化文案与恢复动作。
6. 为状态转换建立纯 Swift 测试，并以 mock FFI 状态覆盖重复打开、超时后重试、关闭时加载、Esc 退出 macOS 全屏和播放自然结束。

### 涉及模块

- `App/Environment/AppState.swift`
- `Features/Player/Rendering/RufflePlayerView.swift`
- `Ruffle/Bridge/RuffleBridge.swift`
- `engine/ffi/src/player.rs`、`CRuffleFFI/ruffle_ffi.h`
- `App/Windows/ContentView.swift`
- `Platform/macOS/*`、`Platform/iOS/*`
- `Tests/RuffnovaTests/PlayerLoadStateTests.swift`（新增）

### 验收标准

- 加载超过 150ms 时出现加载反馈；成功或失败后正确消失。
- 连续双击两个不同条目，最终只播放最后一个条目。
- 退出原生全屏后菜单文案、播放器布局和 bridge 全屏状态一致。
- 任意加载失败都能重试，且不会保留不可操作的遮罩。

## 5. P1：文件级运行档案

### 功能设计

在“文件详情”中新增“运行配置”区域，优先级为：文件配置 > 应用默认配置 > 引擎默认值。

- 可覆写：渲染质量、缩放/黑边模式、播放速度、循环、自动播放、ActionScript 最大执行时间。
- 每项开关使用“使用应用默认值”或具体值，避免把当前全局值复制成难以辨别的永久配置。
- 提供“恢复应用默认设置”及“重置本文件运行配置”。
- 权限区域在本阶段仅展示和管理既有策略；在 P1b 完成前，不将其表述为对 SWF 网络或文件访问的实际拦截。

### 数据设计

新增 `FileRuntimeProfile: Codable, Equatable`，挂载到 `LibraryItem`：

```swift
struct FileRuntimeProfile: Codable, Equatable {
    var quality: RuffleQuality?
    var letterbox: String?
    var playbackSpeed: Float?
    var isLooping: Bool?
    var autoplay: Bool?
    var maxExecutionDuration: TimeInterval?
}
```

权限策略不复制到该模型，继续由 `PermissionPolicyService` 使用稳定的文件标识持久化，防止同一项有两套权限真相。

### 施工方案

1. 将现有 `playbackPreferences` 的职责与 `FileRuntimeProfile` 对齐：保留已持久化的播放进度相关字段，迁移运行配置字段，避免重复命名。
2. `LibraryService` 增加 `effectiveRuntimeProfile(for:)`，按文件、应用设置、引擎默认值计算最终配置。
3. `AppState.openFile` 在 bridge 初始化前应用最终配置。质量、黑边、速度和循环可即时同步 bridge；自动播放和最大执行时间属于播放器创建配置，修改当前文件时提供“重新加载以应用”的明确操作，或待 FFI 提供 setter 后再改为即时生效。
4. 扩展 `LibraryItemDetailsView`，采用分组表单呈现每项覆写；权限行跳转到策略管理页，并标明 P1b 完成前它只管理应用策略记录。
5. 库 schema 版本加一，并编写旧 `library.json` 解码、迁移和回滚测试。

### 涉及模块

- `Features/Library/Models/LibraryItem.swift`
- `Features/Library/Services/LibraryService.swift`
- `Features/Library/Views/LibraryItemDetailsView.swift`
- `Features/Settings/Models/SettingsPersistence.swift`
- `App/Environment/AppState.swift`
- `Core/Security/PermissionPolicyService.swift`
- `Ruffle/Bridge/RuffleBridge.swift`

### 验收标准

- 两个 SWF 可拥有不同速度、循环和脚本超时设置，重启后仍正确生效。
- “重置本文件”不影响应用其他默认设置或其他作品。
- 文件被移动并通过“重新定位”恢复后，其配置和权限覆盖仍保留或明确提示需重新授权。

## 6. P1b：引擎访问边界

### 功能设计

- 网络和文件系统策略只在 Ruffle 引擎实际执行请求的位置判定，不能仅由 SwiftUI 弹窗记录决定。
- 第一版采用加载前已确定的“允许/拒绝”文件级策略，覆盖网络与本地相对路径访问；不在 SWF 执行期间等待异步系统弹窗。
- 动态资源级授权是后续能力，须先设计 Rust 异步请求、Swift 回应、超时和取消语义后才开放。

### 施工方案

1. 为 `RuffleConfig` 增加网络/文件系统策略枚举，并在 `FfiNavigatorBackend.fetch`、文件解析及相关入口执行策略。
2. 将 `PermissionPolicyService` 的有效决策在创建播放器前转换为 FFI 配置；拒绝时通过新的 FFI 诊断事件返回资源类型与脱敏后的请求目标。
3. 明确本地相对资源、`http(s)`、重定向、`navigateToURL`、socket 和文件选择 API 的第一版支持矩阵。未支持的能力应稳定拒绝并报告，不得静默忽略。
4. 在 macOS/iOS 上用本地 HTTP fixture、相对路径资源和拒绝策略进行集成测试。

### 验收标准

- 被拒绝的网络或文件请求无法由 SWF 绕过，诊断报告记录原因但不泄露完整本地路径。
- 同一 `LibraryItem` 的允许/拒绝策略在重启后仍由 FFI 生效。
- iOS 沙盒和 macOS 沙盒条件下的行为一致且有明确错误反馈。

## 7. P2：导入与资源库工作流

### 功能设计

- 文件夹或 ZIP 导入先展示预览：发现的 SWF 数、重复项、已失效条目、不可读项目。
- 用户选择“加入资料库”或“加入并播放第一个可用文件”；可选是否递归扫描子目录。
- 导入完成显示结果摘要，包含“查看新加入项目”“查看跳过项目”。
- 库新增智能视图：继续游玩、最近添加、缺失文件、兼容性问题、互动作品、未标注作品。
- 支持从条目菜单对缩略图重新生成、重新扫描元数据、批量设置标签和批量加入集合。

### 施工方案

1. 新增 `ImportPlan`、`ImportPreview` 与 `ImportResult` 领域模型。扫描在非主线程执行，UI 仅接收进度与可取消结果。
2. `ImportService` 只负责分类、扫描、ZIP 解压；去重及库现状对比放到 `LibraryService` 或独立 `ImportCoordinator`，以 URL 标准化规则为唯一依据。
3. 以经审查的跨平台 ZIP 库替换 macOS `/usr/bin/unzip`，统一实现 iOS/macOS 解压。解压前检查入口数量，解压后限制文件数、单文件和总大小，并拒绝路径穿越、符号链接逃逸和受密码保护的归档。若该依赖未获批准，则在两个平台均隐藏 ZIP 入口，不保留平台不一致的半功能。
4. 批量 `LibraryService.add` 改为用规范化 URL 的 `Set` 预构建索引，避免大目录导入时重复线性查找。
5. 基于既有 `LibraryFilter` 添加智能视图枚举和查询方法；不要把这些视图持久化为普通 `CollectionService` 集合。
6. 为 1,000 项导入、重复路径、符号链接、损坏 ZIP、取消扫描和缺失文件恢复添加测试。

### 涉及模块

- `Features/Import/Services/ImportService.swift`
- `Features/Import/`（新增协调器、预览 sheet、结果 sheet）
- `Features/Library/Models/LibraryItem.swift`
- `Features/Library/Services/LibraryService.swift`
- `Features/Library/Views/LibraryContentView.swift`
- `Features/Library/Views/AppSidebar.swift`
- `Platform/macOS/Services/MacFilePickerService.swift`
- `Platform/iOS/Services/IOSFilePickerService.swift`

### 验收标准

- 导入 1,000 个文件时界面保持可交互，可取消，且无重复条目。
- ZIP 解压失败、无 SWF、重复文件和成功导入有各自明确反馈。
- 智能视图始终由实际库状态计算，无需用户手工维护。

## 8. P3a：游戏输入

### 功能设计

#### 输入

- 舞台获得焦点后所有键盘输入进入 SWF；工具栏、搜索框和 sheet 获得焦点时不劫持键盘。
- “游戏控制”页允许按作品设置动作映射：方向、确认、取消、主要动作、次要动作；先覆盖键盘，后接入 `GCController`。
- macOS Game Mode 显示简洁的输入状态；iOS 为互动内容提供可隐藏、可调整位置的虚拟方向键和动作键。

### 数据与施工方案

1. 新增 `InputProfile`，按稳定的 `LibraryItem.id` 存储，不按路径存储；预留 `version` 字段，键位使用逻辑动作而非物理 keycode 作为持久化格式。
2. 建立 `HIDKeyMapper`，先将 macOS `NSEvent` 与 iOS `UIKey` 统一转换为 USB HID Usage，再传入现有 `ruffle_player_key_event`。不得把 macOS virtual key code 直接传入 FFI。
3. 建立 `InputRouter`，将键盘、iOS 虚拟按键和 `GCController` 动作转换为逻辑动作，再映射为 HID 按下/抬起事件。确保 UIKit/AppKit 事件监听在播放器销毁时注销，并在手柄断连时释放所有按下状态。
4. 用焦点状态控制 command shortcut 与游戏输入的优先级，避免 `Command-P`、空格等菜单快捷键误触发游戏动作。
5. 用 mock bridge 测试动作映射、焦点切换、设备断连和虚拟按键连发；至少以两个真实互动 SWF 做人工回归。

### 涉及模块

- `Features/Player/Services/PlayerInputCoordinator.swift`
- `Features/Player/Services/InputRouter.swift`（新增）
- `Features/Player/Services/HIDKeyMapper.swift`（新增）
- `Features/Player/Views/GameControlsView.swift`（新增）
- `Ruffle/Bridge/RuffleBridge.swift`
- `Platform/macOS/Services/MacInputProvider.swift`
- `Platform/iOS/Services/IOSInputProvider.swift`

### 验收标准

- 点击舞台后，方向键和映射键仅发送给当前 SWF；搜索和弹窗打开时不发送。
- 断开手柄不会造成卡键状态。

## 9. P3b：存档管理

### 前置条件

当前 Ruffle FFI 使用默认内存存储，未向 `PlayerBuilder` 注入跨会话的 `StorageBackend`，也没有公开存档列举、导出、导入或删除 API。P3b 在以下 FFI 能力经原型验证、测试通过前不得进入 UI 实施：

- 按稳定作品标识隔离的持久化存储后端。
- 列举、读取、替换和删除指定作品存储条目的 API。
- 所有导入操作的临时备份、原子提交和失败回滚。
- macOS/iOS App Sandbox 内可写且会随应用备份策略明确的存储目录。

### 功能与施工方案

1. 在 Rust 实现跨平台的 `StorageBackend`，由 Swift 在创建播放器时提供受应用容器管理的目录与 `LibraryItem.id` 命名空间；禁止以用户文件路径作为存档目录键。
2. 扩展 C FFI 与 `RuffleBridge`，提供已复制内存的存档清单、读取、原子替换和删除接口；任何跨语言字符串或字节缓冲区都定义清晰的所有权与释放函数。
3. 在 Swift 新增 `GameStorageService`，仅处理由 FFI 提供的二进制存档包，不尝试解析 `.sol` 内容。导入前写入临时备份，验证后原子替换，失败则恢复。
4. FFI 集成测试验证同作品重启恢复、作品间隔离、损坏导入回滚、删除与存储配额；通过后再在文件详情与设置中提供查看占用空间、导出、导入及清除操作。

### 验收标准

- 重启应用后，支持 SharedObject 的作品能恢复各自数据，且不同 `LibraryItem` 之间不串档。
- 导入损坏或超额存档不会破坏原有数据。
- 用户只在 FFI 能力真实可用时看到导入、导出和清除操作。

## 10. P4：兼容性支持闭环

### 功能设计

- 诊断面板增加“生成支持报告包”，包含结构化 JSON、可阅读文本、可选截图和最近 trace。
- 默认脱敏：不包含本机绝对路径、用户名、目录结构或任意本地文件内容；文件名默认保留但可关闭。
- “报告问题”打开带预填标题和正文的 Issue 页面，用户确认后才调用浏览器；报告正文标明 Ruffnova、Ruffle 和系统版本。
- 用户可为条目标记“我这里可以运行”或“我这里无法运行”，这应与引擎自动检测结果分开保存，防止误导兼容性结论。

### 施工方案

1. 新增 `SupportReport` 及 `SupportReportRedactor`，在生成阶段而非复制阶段执行脱敏，禁止 UI 层自己拼接报告。
2. `DiagnosticsService` 输出 JSON 与 Markdown/text 两种格式；报告包写入临时目录，使用完成后清理。
3. 定义 `UserCompatibilityObservation`（结果、应用版本、引擎版本、日期、可选备注），挂载 `LibraryItem` 并在详情中展示其与自动状态的区别。
4. URL 构建使用 `URLComponents`，Issue 正文长度受限；附件不自动上传，改为用户手动选择报告包。
5. 测试脱敏规则、Unicode 文件名、无 trace 情况、超长 trace 截断、缺少引擎版本和浏览器 URL 编码。

### 涉及模块

- `Features/Diagnostics/Models/CompatibilityReport.swift`
- `Features/Diagnostics/Services/DiagnosticsService.swift`
- `Features/Diagnostics/Views/DiagnosticsView.swift`
- `Features/Library/Models/LibraryItem.swift`
- `Features/Library/Views/LibraryItemDetailsView.swift`
- `App/Commands/AppCommandRouter.swift`

### 验收标准

- 生成的报告不包含用户主目录、完整本地路径或原始存档数据。
- 支持报告可离线生成；浏览器提交失败不丢失本地报告。
- 自动兼容性状态与用户实际观察可同时查看，且用户观察带版本和时间。

## 11. 横向工程要求

### 本地化与可访问性

- 所有新文案进入 `Resources/en.json` 与 `Resources/zh-Hans.json`，其他现有语言先提供英文回退并在发布前补齐。
- 配置表单、导入进度、权限弹窗和虚拟控制器必须有 VoiceOver 标签、状态和可达顺序。
- 不以颜色作为兼容性、错误或权限状态的唯一信号。

### 持久化与迁移

- 所有 `Codable` 模型新增字段必须提供默认解码行为。
- 每次 schema 递增均记录迁移路径、失败报告和幂等性测试。
- 数据文件写入延续原子写方式；导入、存档替换等多步骤操作使用临时文件和可恢复提交。

### 性能与隐私

- 目录扫描、哈希、缩略图和诊断压缩不运行在主线程。
- 不采集遥测或上传作品、存档、trace；用户主动提交前始终可预览报告内容。
- ZIP 解压、外部网络访问和文件系统请求应有大小/时间/权限边界。

## 12. 测试与发布门槛

| 类别 | 必测场景 |
| --- | --- |
| 单元测试 | 状态机、有效运行配置、导入去重、智能视图筛选、权限优先级、脱敏、迁移 |
| 集成测试 | 打开/关闭/重试、导入目录、移动后重新定位、配置重启恢复、P1b 的网络/文件拒绝、存档事务（P3b FFI 可用后） |
| UI 回归 | 空库、加载、错误、互动 SWF、动画 SWF、全屏、深浅色、英语与简体中文、macOS/iOS 紧凑布局 |
| 手工样本 | 至少 10 个动画、10 个互动作品，覆盖 AVM1、AVM2、网络请求、持久化数据和异常脚本 |
| 性能 | 1,000 条库、10,000 条目录扫描候选、长 trace、反复打开/关闭播放器 |

每个阶段合并前必须满足：新增业务逻辑有单元测试；用户可见错误有恢复路径；新持久化字段有旧数据解码测试；新增用户文案完成中英文；无已知的静默失败路径。

## 13. 建议实施顺序

1. 完成 P0 的 FFI 加载状态、Swift 状态机与回归测试，冻结播放器生命周期接口。
2. 完成 P1 文件级运行档案；需要重载的配置不承诺即时生效。
3. 并行实施 P2 导入协调器和智能视图，并在开始 ZIP UI 前确定跨平台归档依赖。
4. 实施 P3a 输入层，先修复 HID 键码转换，再增加虚拟按键和手柄映射。
5. 先为 P1b 和 P3b 各自完成 Rust FFI 原型与集成测试；通过后再分别实施权限 UI 与存档 UI。
6. 完成 P4 的脱敏报告与 Issue 发起流程，建立社区兼容性反馈闭环。

不建议在上述阶段完成前新增下载中心、在线作品目录或纯视觉重构。这些能力会扩大权限、版权和网络边界，无法直接提升本地 Flash 作品的核心成功率。
