# Ruffnova 三项特色功能施工计划

> 目标：将 Ruffnova 从“原生 SWF 播放器”升级为“Flash 游戏收藏、配置、存档和兼容性诊断工作台”。
>
> 功能范围：
>
> 1. SharedObject 存档槽与自动备份
> 2. 可视化按键映射与 iOS 自定义触屏布局
> 3. 兼容性详情页与一键应用运行建议

---

## 1. 产品定位与范围边界

### 1.1 SharedObject 存档槽不是即时存档

第一项功能保存的是游戏主动写入的 Flash SharedObject，即 `.sol` 数据。

可以恢复：

- 游戏进度
- 解锁内容
- 游戏内设置
- 游戏自己持久化的数据

不能恢复：

- ActionScript VM 执行栈
- 当前显示列表状态
- 尚未写入 `.sol` 的当前进度
- 音频位置
- 定时器和随机数状态
- 网络连接状态
- 当前画面对应的完整运行状态

因此 UI 统一使用：

- “存档槽”
- “SharedObject 快照”
- “自动备份”

不要称为“即时存档”或“保存当前状态”。恢复后必须重新加载 SWF。

### 1.2 输入配置第一版边界

第一版支持：

- 每个 SWF 独立的键盘映射
- 每个 SWF 独立的控制器映射
- iOS 横屏和竖屏独立触屏布局
- 控件移动、尺寸、透明度、显示/隐藏
- 内置布局预设
- 恢复默认
- 键盘录入
- 控制器按键学习

第一版暂不支持：

- 连发
- 宏
- 时序按键
- Toggle 键
- 多个普通键组成的复杂组合
- 虚拟模拟摇杆
- 每个具体手柄一套映射
- 用户预设云同步

### 1.3 兼容性建议第一版边界

可以自动应用：

- 当前 SWF 的 `quality`
- 当前 SWF 的 `maxExecutionDuration`
- 后续有可靠规则时的其他 `FileRuntimeProfile` 字段

不能静默应用：

- 网络权限
- 文件系统权限
- 全局设置
- 删除存档
- 覆盖输入布局
- 对所有 SWF 生效的配置

权限建议必须单独确认。

---

## 2. 推荐产品决策

### 2.1 存档

| 决策 | 推荐值 |
|---|---|
| 存档槽数量 | 3 个固定命名槽 |
| 快照范围 | 当前作品全部 SharedObject 条目 |
| 恢复行为 | 暂停播放器，恢复数据，重新加载 SWF |
| 自动备份 | 默认开启 |
| 周期检查 | 每 5 分钟检查一次，有变化才创建 |
| 关闭/切换文件 | 尝试生成自动备份 |
| iOS 进入后台 | 尝试生成自动备份 |
| 破坏性操作前 | 强制创建安全快照 |
| 自动备份保留 | 最近 5 份全部保留，再按日/周分层保留 |
| 每游戏自动备份上限 | 约 16 份 |
| 全局软上限 | 1 GiB |
| 删除资料库项目 | 默认保留存档，提供“同时删除存档数据”选项 |
| 命名槽自动清理 | 永不自动删除 |

### 2.2 输入

| 决策 | 推荐值 |
|---|---|
| 键位冲突 | 默认不允许，提供“替换原绑定” |
| 配置层级 | 内置默认配置 + 每文件覆盖 |
| 横竖屏布局 | 分别保存 |
| 触屏控件 | Button 和 D-pad |
| 坐标 | 相对可用区域的 0～1 归一化坐标 |
| 最小触控区域 | 44×44 pt |
| 编辑时是否发送输入 | 不发送 |
| 未映射键盘按键 | 继续原样发送给 SWF |
| 映射保存 | 编辑完成后一次性持久化 |
| 内置预设 | Classic、Compact、Left-handed、Minimal |

### 2.3 兼容性

| 决策 | 推荐值 |
|---|---|
| “兼容”含义 | 本次观察未发现已知问题 |
| 自动建议 | 只提供确定、可解释的规则 |
| 应用前 | 必须展示 before/after |
| 权限建议 | 单独确认，不纳入静默一键应用 |
| 应用范围 | 只修改当前文件的 runtime profile |
| 撤销 | 恢复应用建议前的完整文件配置 |
| 报告持久化 | 保存摘要、证据和建议，不保存完整 trace |
| 旧结果 | 保留但标记为过期 |

---

## 3. 总体架构方案

### 3.1 继续以 `LibraryItem` 为作品聚合根

轻量、作品级的配置继续保存在 `LibraryItem`：

- `InputProfile`
- 触屏布局
- `FileRuntimeProfile`
- 自动备份偏好
- 最近兼容性评估摘要

以下内容不写入 `library.json`：

- `.sol` 原始数据
- 快照二进制
- 完整 trace 历史
- 性能逐帧采样
- 大量快照清单
- 截图

### 3.2 将 `LibraryItemDetailsView` 演进为作品详情中心

建议详情结构：

1. 概览
2. 兼容性
3. 运行设置
4. 输入与控制
5. 存档与备份
6. 权限
7. 组织与集合

呈现方式：

- macOS：现有详情 Sheet 内使用分区或侧栏
- iPhone：`NavigationStack`
- iPad：Detail column
- Library、Recent、Favorites 均进入同一详情中心
- 播放错误可直接打开该作品的“兼容性”分区

不需要引入全局路由框架，只需一个轻量入口枚举：

```swift
enum LibraryItemDetailsSection {
    case overview
    case compatibility
    case controls
    case storage
    case permissions
}
```

### 3.3 复杂逻辑放入独立服务

`AppState` 只负责协调：

- 当前正在播放哪个 `LibraryItem`
- 暂停、重载播放器
- 应用输入配置
- 执行恢复后的重新加载
- 触发兼容性评估
- 打开详情分区

以下逻辑不能继续塞入 `AppState`：

- 快照事务
- 快照保留策略
- 输入映射验证
- 触屏控件碰撞和边界计算
- 兼容性规则判断
- 建议 patch 合并逻辑

---

## 4. Library schema 和迁移策略

当前三项功能都会修改 `LibraryItem`，建议只进行一次 schema 升级：

```text
Library schema 3 → 4
InputProfile version 1 → 2
Snapshot manifest version 1
Compatibility assessment version 1
```

### 4.1 迁移要求

- schema 3 的真实资料库可以无损升级
- 缺少新字段时使用默认值
- `InputProfile` v1 自动转换为 v2
- 新增 enum 遇到未知值时回退为 `unknown`
- 迁移必须幂等
- 迁移失败不能覆盖原 `library.json`
- 先成功写入迁移结果，再更新 `library.version`
- 升级前保留一份旧库备份
- 不迁移或移动现有 SharedObject 目录

### 4.2 推荐新增字段

```swift
struct LibraryItem {
    // 已有字段
    var inputProfile: InputProfile?
    var runtimeProfile: FileRuntimeProfile?

    // 新增
    var gameStoragePreferences: GameStoragePreferences?
    var compatibilityAssessment: PersistedCompatibilityAssessment?
}
```

---

# 5. Milestone 施工顺序

## M0：验证技术前提并冻结数据契约

### 工作内容

1. 使用真实会写入多个 `.sol` 的 SWF 验证：
   - 能否列举全部 SharedObject
   - 播放器暂停后读取是否稳定
   - 恢复磁盘数据后是否必须重载
   - 嵌套 SharedObject key 是否稳定
2. 确认 Rust FFI 修改的可复现交付路径：
   - Rust 源码补丁
   - `cbindgen` 生成 Header
   - `CRuffleFFI/ruffle_ffi.h`
   - `build_engine.sh`
3. 冻结：
   - Library schema 4
   - `InputProfile` v2
   - Snapshot manifest v1
   - Compatibility assessment v1
4. 确认产品默认值。

### 验收标准

- 真实 SWF 的多个 `.sol` 可以完整导出、恢复并读回
- 恢复后重载游戏可以读取旧进度
- Rust 修改可从干净 checkout 重建
- 所有持久化模型字段和版本号明确
- 确认恢复失败时的 rollback 方案

## M1：作品详情中心与 schema 4

### 修改文件

- `Features/Library/Models/LibraryItem.swift`
- `Features/Library/Services/LibraryService.swift`
- `Features/Library/Views/LibraryItemDetailsView.swift`
- `Features/Library/Views/LibraryFileCell.swift`
- `Features/Library/Views/RecentFileRow.swift`
- `Features/Library/Views/FavoritesGridView.swift`
- `Tests/RuffnovaTests/LibraryMigrationTests.swift`

### 工作内容

1. 将 Library schema 升到 4。
2. 引入新增可选字段。
3. 实现 `InputProfile` v1 → v2 解码兼容。
4. 将 `LibraryItemDetailsView` 调整为详情中心。
5. 添加兼容性、输入和存档三个入口。
6. 保持现有运行设置、权限、标签、备注和集合功能。
7. 支持打开详情时指定初始分区。

### 验收标准

- schema 3 fixture 无损升级到 schema 4
- 迁移执行两次结果相同
- 迁移失败不会覆盖原库
- 现有单元测试全部通过
- 无输入配置的旧项目使用默认配置

---

# 6. 功能一：SharedObject 存档槽与自动备份

## 6.1 数据模型

建议新增：

### `SharedObjectSnapshotManifest`

```text
schemaVersion
id
libraryID
kind
slotID
reason
createdAt
appVersion
engineVersion
totalBytes
sourceFingerprint
entries
```

### `SharedObjectSnapshotEntry`

```text
key
relativePath
byteCount
sha256
```

### `SharedObjectSnapshotKind`

```text
slot
automatic
safety
```

### `SharedObjectSnapshotReason`

```text
manual
periodic
background
close
switchGame
beforeRestore
beforeImport
beforeDelete
beforeClear
```

### `GameStoragePreferences`

```text
automaticBackupEnabled: Bool?
```

`nil` 表示使用全局默认。

## 6.2 磁盘目录

```text
Application Support/RuffleFlashPlayer/
├── SharedObjects/
│   └── <library-id>/
│       └── 当前活动 .sol 文件
│
└── SharedObjectSnapshots/
    └── <library-id>/
        ├── slots/
        │   ├── slot-1/
        │   │   ├── manifest.json
        │   │   └── objects/...
        │   ├── slot-2/
        │   └── slot-3/
        ├── automatic/
        │   └── <timestamp>-<snapshot-id>/
        ├── safety/
        │   └── <timestamp>-<snapshot-id>/
        └── staging/
            └── <operation-id>/
```

快照目录必须位于 `SharedObjects` 外部，否则 Rust 递归列举时可能把备份误认为活动存储。

## 6.3 推荐新增文件

- `Features/Player/Models/SharedObjectSnapshot.swift`
- `Features/Player/Services/SharedObjectSnapshotService.swift`
- `Features/Player/Views/SaveSlotsView.swift`
- `Features/Player/Views/SharedObjectBackupListView.swift`
- `Tests/RuffnovaTests/SharedObjectSnapshotServiceTests.swift`

## 6.4 修改现有文件

- `Shared/Persistence/SharedObjectStoragePaths.swift`
- `Features/Player/Services/GameStorageService.swift`
- `Features/Player/Views/GameStorageSection.swift`
- `Features/Library/Models/LibraryItem.swift`
- `Features/Library/Services/LibraryService.swift`
- `Features/Library/Views/LibraryItemDetailsView.swift`
- `Features/Settings/Models/SettingsPersistence.swift`
- `Features/Settings/Views/SettingsView.swift`
- `App/Environment/AppState.swift`
- `App/AppDelegate.swift`
- Rust storage 和 FFI 文件
- `CRuffleFFI/ruffle_ffi.h`

## 6.5 快照创建事务

流程：

1. 验证 `libraryID` 和目录边界。
2. 若当前作品正在运行，暂停播放并停止 tick/render。
3. 按稳定顺序列举全部 SharedObject key。
4. 逐项读取数据。
5. 计算每个 entry 的 SHA-256。
6. 计算整个命名空间指纹。
7. 自动备份时与最近指纹比较，无变化则不创建。
8. 在 `staging/<operation-id>` 中写入快照。
9. `manifest.json` 最后写入，作为完成标记。
10. 重新读取并校验所有文件。
11. 原子 rename 到正式目录。
12. 恢复播放器先前状态。
13. 执行保留策略。

任何没有有效 manifest 的目录都不能显示为可恢复快照。

## 6.6 恢复事务

流程：

1. 暂停当前作品并停止输入、渲染和时间线轮询。
2. 锁定该 `libraryID`，禁止并发存档事务。
3. 验证 manifest：
   - schema 支持
   - library ID 匹配
   - key 合法
   - 无 `..`
   - 无绝对路径
   - 无重复 key
   - 所有文件存在
   - 大小和 SHA-256 匹配
   - 总大小不超过 10 MiB
4. 强制创建当前活动数据的 safety 快照。
5. 在活动目录同级 staging 构建新的完整命名空间。
6. 读回验证。
7. 将旧活动目录 rename 为 rollback。
8. 将新目录 rename 为正式目录。
9. 再通过 FFI list/read 验证。
10. 成功后删除 rollback。
11. 失败则原子恢复旧目录。
12. 如果作品当前打开，重新创建或加载播放器。
13. 恢复播放状态。

不能逐个覆盖 `.sol` 后再删除旧文件，否则中途失败会产生混合状态。

## 6.7 自动备份触发

### 周期触发

- 游戏加载完成后启动
- 每 5 分钟检查一次
- 只有内容指纹变化时创建
- 关闭文件后停止

### 生命周期触发

- 切换到其他 SWF 前
- 关闭当前 SWF 前
- iOS 进入后台时
- macOS 终止时作为补充尝试

### 强制安全快照

以下操作不受自动备份开关影响：

- 恢复槽位前
- 导入并覆盖 `.sol` 前
- 删除 `.sol` 前
- 清空存储前
- 覆盖槽位前

安全快照失败时，应取消破坏性操作。

## 6.8 UI

### 概览

- 当前 SharedObject 使用量
- 自动备份状态
- 最近备份时间
- “这不是运行中即时存档”的说明

### 三个槽位

每个槽显示：

- 空槽或保存时间
- `.sol` 数量
- 总大小
- 保存
- 覆盖
- 恢复
- 删除
- 导出

### 自动备份

- 最近备份列表
- 查看全部
- 恢复
- 删除
- 导出

### 高级管理

保留现有：

- 单个 `.sol` 导入
- 单个 `.sol` 导出
- 删除单个条目
- 清空全部

## 6.9 验收标准

- 快照覆盖当前作品所有 SharedObject
- 不同作品完全隔离
- 恢复后 key 集合与快照完全一致
- 快照中不存在的旧条目会被删除
- 任意阶段失败都不会损坏当前活动存档
- 当前作品恢复后自动重载
- 破坏性操作前 safety 快照失败则取消操作
- 快照不计入活动 10 MiB 配额
- 命名槽不被自动清理
- 自动备份不阻塞主线程或渲染循环

---

# 7. 功能二：可视化输入配置与触屏布局

## 7.1 `InputProfile` v2

建议结构：

```text
InputProfile
├── version
├── actionOutputs
├── keyboardBindings
├── controllerBindings
└── touchLayouts
```

### `GameKeyOutput`

```text
keyCode
charCode
modifiers
```

第一版每个 `GameAction` 只对应一个主 HID 输出键。

### `KeyboardBinding`

```text
trigger:
  hidUsage
  requiredModifiers
action
isEnabled
```

未命中自定义绑定的键继续原样发送给 SWF。

### `ControllerBinding`

```text
element
action
pressThreshold
releaseThreshold
```

### `ControllerElement`

至少包括：

- D-pad 四方向
- A/B/X/Y
- Menu/Options
- 左右肩键
- 左右扳机
- 左右摇杆按压

### `TouchControlInstance`

```text
id
kind
actions
center
size
opacity
isEnabled
zIndex
```

### `TouchControlKind`

第一版：

- `button`
- `directionalPad`

### `TouchLayoutSet`

```text
portrait
landscape
```

坐标、尺寸使用 0～1 归一化数据。

## 7.2 输入来源身份修正

当前来源身份过粗：

```swift
.keyboard
.virtual(GameAction)
.controller(UUID, GameAction)
```

需要扩展为能区分真实输入实例：

```text
keyboard(physicalHID, modifiers)
virtual(controlInstanceID, subAction)
controller(runtimeControllerID, ControllerElement)
```

原因：

- 两个键盘键可能映射到同一动作
- 两个触屏按钮可能对应同一动作
- 两个手柄可能同时操作
- D-pad 可能同时按住右和上

继续保留 `InputRouter` 当前多来源去重算法，但必须保证 down/up 使用相同来源身份。

## 7.3 配置应用安全顺序

任何配置提交、预设切换、布局方向切换都必须：

1. `releaseAll`
2. 更新内存中的 profile
3. 持久化 `LibraryItem.inputProfile`
4. 刷新运行中的 resolver
5. 恢复舞台焦点

不能按下时使用旧映射、松开时使用新映射，否则旧输出键会卡住。

## 7.4 推荐新增文件

- `Features/Player/Models/TouchControlLayout.swift`
- `Features/Player/Models/InputPreset.swift`
- `Features/Player/Services/InputProfileResolver.swift`
- `Features/Player/ViewModels/InputProfileEditorViewModel.swift`
- `Features/Player/Views/InputMappingEditorView.swift`
- `Features/Player/Views/TouchLayoutEditorView.swift`
- `Features/Player/Views/TouchControlView.swift`
- `Features/Player/Views/TouchDirectionalPadView.swift`
- `Features/Player/Views/PlatformKeyCaptureView.swift`

## 7.5 修改现有文件

- `Features/Player/Models/InputProfile.swift`
- `Features/Player/Services/InputRouter.swift`
- `Features/Player/Services/GameControllerInputService.swift`
- `Features/Player/Views/GameControlsView.swift`
- `Features/Player/Rendering/RufflePlayerView.swift`
- `Features/Player/Services/PlayerInputCoordinator.swift`
- `App/Environment/AppState.swift`
- `Features/Library/Models/LibraryItem.swift`
- `Features/Library/Services/LibraryService.swift`
- `Features/Library/Views/LibraryItemDetailsView.swift`
- `Platform/iOS/Views/IOSContentView.swift`
- `App/Windows/ContentView.swift`
- `Features/Player/Controls/PlayerControlBar.swift`

## 7.6 按键映射编辑器

### 动作列表

展示八个 `GameAction`：

- up
- down
- left
- right
- confirm
- cancel
- primary
- secondary

每行显示：

- 动作名称
- 输出给游戏的 HID 键
- 键盘触发键
- 控制器元素
- 冲突状态
- 录制/清除/恢复默认

### macOS 录键

1. 点击“录制键”
2. 编辑器获取键盘焦点
3. 显示“请按一个键，Esc 取消”
4. 捕获本地 `NSEvent`
5. 转换为 HID
6. 不发送给 SWF
7. 检查冲突
8. 用户确认替换

### iOS 键盘录入

- 外接键盘：通过 `UIKey` 捕获
- 无外接键盘：提供可搜索的 HID 键列表
- 捕获期间不转发给播放器

### 控制器学习

1. 点击“按手柄按钮绑定”
2. `GameControllerInputService` 进入 capture mode
3. 捕获下一个标准化 `ControllerElement`
4. 不将该事件发送给游戏
5. 显示结果
6. 恢复正常模式

## 7.7 iOS 触屏布局编辑器

### 画布

- 使用播放器截图、缩略图或中性舞台预览
- 不让下面的 `RuffleMetalViewIOS` 同时响应手势
- 支持横屏/竖屏预览切换

### 编辑能力

- 点击选中
- 拖动位置
- 调整尺寸
- 调整透明度
- 显示/隐藏
- 添加按钮
- 添加 D-pad
- 删除
- 复制
- 应用预设
- 恢复当前方向默认
- 恢复全部默认
- 测试模式

### 约束

- 控件不能永久移出画布
- 可见控件命中区域至少 44×44 pt
- 避让 Safe Area、Home Indicator 和系统栏
- 控件重叠允许保存，但显示警告
- D-pad 作为整体移动和缩放
- 编辑模式不发送游戏输入
- 切换方向前释放全部输入

## 7.8 运行时

`GameControlsView` 改为根据当前方向布局动态绘制：

```text
实际容器 width >= height → landscape
实际容器 width < height → portrait
```

不能只依赖设备 Orientation，因为 iPad Split View 和 Stage Manager 下容器比例可能不同。

## 7.9 验收标准

- v1 profile 无损迁移到 v2
- 两个物理键映射到同一输出时，最后一个释放才发送 key-up
- 两个同动作触屏按钮可以同时按住
- 两个控制器可以共同操作
- 配置保存前释放全部输入
- 编辑器取消不修改资料库
- 拖动过程中不写磁盘
- 保存时只写一次
- 横竖屏布局互不影响
- 旋转、后台、关闭文件、隐藏控件时无卡键
- 默认布局功能不低于当前固定布局
- VoiceOver 可以识别所有动作和编辑状态

---

# 8. 功能三：兼容性详情与运行建议

## 8.1 领域模型

需要将原始证据、问题判断和建议动作分离。

### `CompatibilityAssessmentStatus`

```text
unknown
compatible
degraded
blocked
```

含义：

- `unknown`：信号不足或结果过期
- `compatible`：本次观察未发现已知问题
- `degraded`：可运行，但存在警告或降级
- `blocked`：当前无法正常运行

### `CompatibilitySeverity`

```text
info
warning
error
critical
```

### `CompatibilityEvidence`

```text
id
kind
code
source
observedAt
value
redactedTarget
confidence
occurrenceCount
firstObservedAt
lastObservedAt
```

### `CompatibilityFinding`

```text
ruleID
severity
titleKey
messageKey
evidenceIDs
recommendationIDs
isBlocking
firstDetectedAt
lastDetectedAt
```

### `CompatibilityRecommendation`

```text
id
priority
titleKey
explanationKey
expectedEffectKey
action
requiresReload
requiresConfirmation
alreadyApplied
rollbackAvailable
```

### `CompatibilityAction`

安全配置动作：

```text
setRuntimeOverrides
resetRuntimeOverrides
reloadCurrentFile
retryLoad
openRuntimeSettings
openInputLayout
openSaveStorage
locateFile
copyReport
```

权限动作：

```text
requestPermission
openPermissionSettings
```

### `PersistedCompatibilityAssessment`

```text
schemaVersion
rulesetVersion
generatedAt
lastObservedAt
status
findings
recommendations
evidence
inputFingerprint
engineBuildIdentifier
appBuildIdentifier
appliedRecommendationRecords
isCompleteObservation
```

## 8.2 推荐新增文件

- `Features/Diagnostics/Models/CompatibilityAssessment.swift`
- `Features/Diagnostics/Models/RuntimeRecommendation.swift`
- `Features/Diagnostics/Services/CompatibilityRuleEngine.swift`
- `Features/Diagnostics/Services/CompatibilityActionService.swift`
- `Features/Diagnostics/Views/CompatibilityDetailsView.swift`
- `Tests/RuffnovaTests/CompatibilityRuleEngineTests.swift`
- `Tests/RuffnovaTests/CompatibilityPersistenceTests.swift`
- `Tests/RuffnovaTests/CompatibilityActionServiceTests.swift`

## 8.3 修改现有文件

- `Features/Diagnostics/Models/PlayerIssue.swift`
- `Features/Diagnostics/Models/CompatibilityReport.swift`
- `Features/Diagnostics/Services/DiagnosticsService.swift`
- `Features/Diagnostics/Views/DiagnosticsView.swift`
- `Core/Security/PermissionPolicyService.swift`
- `Features/Library/Models/LibraryItem.swift`
- `Features/Library/Services/LibraryService.swift`
- `Features/Library/Views/LibraryItemDetailsView.swift`
- `Features/Library/Views/LibraryFileCell.swift`
- `App/Environment/AppState.swift`
- `Ruffle/Bridge/RuffleBridge.swift`
- Rust FFI metadata、加载错误和诊断代码
- `CRuffleFFI/ruffle_ffi.h`

## 8.4 规则引擎原则

`CompatibilityRuleEngine` 必须是纯函数：

```text
CompatibilityContext → PersistedCompatibilityAssessment
```

要求：

- 同一输入产生相同输出
- finding ID 稳定
- recommendation ID 稳定
- 固定排序
- 每个 finding 都引用 evidence
- 每个 recommendation 都引用 finding
- 无证据时不生成强建议
- 不使用本地化字符串作为规则输入
- 不直接访问 SwiftUI、磁盘或 Bridge

## 8.5 第一版规则

### 文件和加载

| Rule ID | 条件 | 状态/动作 |
|---|---|---|
| `file.missing.v1` | 文件不存在 | blocked；定位文件 |
| `file.inaccessible.v1` | 文件不可读 | blocked；重新选择文件 |
| `load.failed.v1` | 根 SWF 加载失败 | blocked；重试/复制报告 |
| `load.timeout.v1` | 加载超时 | degraded/blocked；建议提高执行时长 |
| `render.initializationFailed.v1` | Metal/Ruffle 初始化失败 | blocked；重试/复制报告 |

### 权限和资源

| Rule ID | 条件 | 动作 |
|---|---|---|
| `permission.networkDenied.v1` | 实际出现网络拒绝 | 单独请求网络权限 |
| `permission.filesystemDenied.v1` | 实际出现文件拒绝 | 单独请求文件权限 |
| `engine.networkUnsupported.v1` | 引擎后端不支持请求 | 只解释，不误导为授权即可解决 |
| `engine.unsupportedScheme.v1` | 不支持 URL scheme | 展示脱敏 scheme |
| `engine.navigationUnsupported.v1` | 导航不支持 | 展示限制 |
| `engine.socketUnsupported.v1` | Socket 不支持 | 展示限制 |

### 元数据

| Rule ID | 条件 | 动作 |
|---|---|---|
| `metadata.unavailable.v1` | 已加载但元数据不可用 | info |
| `metadata.invalidStage.v1` | 舞台尺寸异常 | warning；重载/报告 |
| `metadata.as3Observed.v1` | 检测到 AS3 | 仅信息，不作为不兼容依据 |

### 性能与运行配置

| Rule ID | 条件 | 建议 |
|---|---|---|
| `performance.sustainedLowFPS.v1` | 前台稳定采样 8～10 秒且持续低 FPS | 将该文件 quality 降一级 |
| `runtime.executionLimitLow.v1` | 出现 timeout 且执行上限偏低 | 提高该文件执行上限 |

不能因为用户关闭 autoplay、looping 或使用特殊 letterbox 就判定为兼容性问题。

### 输入和存档

| Rule ID | 条件 | 建议 |
|---|---|---|
| `input.interactiveDefaultLayout.v1` | 互动内容仍使用默认输入 | 打开输入布局 |
| `storage.nearQuota.v1` | SharedObject 使用量 ≥ 80% | 打开存档管理 |
| `storage.quotaExceeded.v1` | 达到配额并出现写入失败 | 导出/清理存档 |
| `healthy.observedRun.v1` | 正常加载且无 warning 以上问题 | compatible |

## 8.6 “一键应用”流程

1. 用户打开兼容性详情。
2. 重新计算建议，避免使用过期结果。
3. 展示变更摘要：

```text
Quality: High → Medium
Max execution duration: 15s → 30s
需要重新加载：是
```

4. 用户确认。
5. 合并所有安全 `RuntimeProfilePatch`。
6. 只写一次 `LibraryService.update`。
7. 当前作品正在播放时只重载一次。
8. 重新评估。
9. 记录应用前 profile，允许撤销。

### 权限处理

一键应用安全配置后，再逐项询问：

```text
《Game.swf》请求访问网络资源 example.com。
[允许一次] [对此文件允许] [保持拒绝]
```

不能：

- 修改全局权限为 allow
- 静默覆盖 `denyForFile`
- 因权限被拒绝就标记为引擎不兼容

## 8.7 兼容性详情页

### 顶部摘要

- 文件名和缩略图
- 状态徽章
- 上次检查时间
- 是否过期
- 重新检查

### 建议

- 建议数量
- 安全建议总应用按钮
- 每项 before/after
- 是否需要重载
- 是否需要权限确认
- 单独应用和撤销

### 已发现问题

- 严重度
- 问题说明
- 证据来源
- 首次和最后观察时间
- 出现次数
- 脱敏资源目标

### 运行环境

- SWF 版本
- AVM1/AVM2
- 舞台尺寸
- 帧率
- 总帧数
- App 版本
- 引擎版本
- 当前运行配置及其来源
- 权限及其来源

### 相关功能

- 输入布局
- 存档管理
- 文件运行设置
- 文件权限
- 复制脱敏报告

### 技术证据

放在可折叠区域：

- 最近 trace 摘要
- Rust 诊断
- rule ID
- ruleset version
- assessment fingerprint

## 8.8 过期判定

兼容性结果在以下情况下标记过期：

- SWF 文件大小或修改日期改变
- App 版本变化
- Ruffle 引擎版本变化
- ruleset 版本变化
- `FileRuntimeProfile` 变化
- 权限决定变化
- 输入配置版本变化
- 文件重新定位后身份或权限上下文改变

旧结果保留供参考，但不能继续显示为“最新”。

## 8.9 验收标准

- 同一 context 多次计算结果完全相同
- 每条 finding 都有稳定 rule ID
- 每条建议都能解释原因
- 无证据时不生成破坏性建议
- 一键应用只修改当前文件
- 不覆盖其他 profile 字段
- 权限不会静默放宽
- 当前文件最多重载一次
- 撤销能恢复应用前完整 profile
- 快速切换文件时迟到诊断不会污染新文件
- 报告不包含绝对路径、用户名、URL query/token 或存档内容

---

# 9. 跨功能集成点

## 9.1 存档与输入

- 两者都按 `LibraryItem.id` 关联
- 切换存档不应改变输入配置
- 输入预设不写入 SharedObject 快照
- 后续可增加应用级“保存到槽 1/2/3”动作，但不能作为 HID 发送给 SWF
- 恢复槽位必须二次确认，不建议映射为单键直接执行

## 9.2 存档与兼容性

兼容性详情可以展示：

- 是否产生 SharedObject
- 当前使用量
- 最近自动备份时间
- 是否接近配额
- 最近备份失败

但存档故障不能直接把作品标成 `unsupported`。

## 9.3 输入与兼容性

兼容性规则可以建议：

- 互动内容启用触屏控制
- 使用默认配置时打开输入布局
- 已连接手柄但未配置控制器绑定
- 布局控件越界时恢复默认

不能自动猜测游戏实际需要哪些键。

## 9.4 恢复存档后的播放器行为

恢复流程必须协调：

1. `InputRouter.releaseAll`
2. 停止 render/timeline
3. 恢复 SharedObject
4. 重建或重新加载播放器
5. 重新应用 runtime profile
6. 重新应用 input profile
7. 开始新的兼容性观察
8. 恢复播放状态

---

# 10. 并行开发与冲突控制

## 10.1 可并行开发

### 存档工作流

主要负责：

- `SharedObjectStoragePaths`
- `GameStorageService`
- Snapshot Models/Service
- Save Slots UI
- 存档测试
- Rust storage FFI

### 输入工作流

主要负责：

- `InputProfile`
- `InputRouter`
- `GameControllerInputService`
- Input Resolver
- 映射编辑器
- Touch Layout Editor
- 输入测试

### 兼容性工作流

主要负责：

- Compatibility Models
- Rule Engine
- Action Service
- Compatibility Details
- 兼容性测试

## 10.2 由单一集成人维护的高冲突文件

- `App/Environment/AppState.swift`
- `Features/Library/Models/LibraryItem.swift`
- `Features/Library/Services/LibraryService.swift`
- `Features/Library/Views/LibraryItemDetailsView.swift`
- `Platform/iOS/Views/IOSContentView.swift`
- `Resources/*.json`
- `Ruffnova.xcodeproj/project.pbxproj`

建议先完成 M1，将这些文件的新增接口冻结，再并行推进三个功能。

---

# 11. 测试总矩阵

## 11.1 单元测试

### 存档

- 多 entry 快照
- 嵌套 key
- 空命名空间
- 相同内容去重
- 槽位覆盖
- manifest 损坏
- 文件缺失
- SHA-256 不符
- 目录穿越
- 跨 Library ID 恢复
- 超配额拒绝
- 恢复失败 rollback
- safety 快照失败
- 并发事务串行化
- 自动保留策略
- 命名槽不被清理

### 输入

- profile v1 → v2
- v2 编解码
- 多来源同一输出
- 重复 down 去重
- 最后来源释放才 key-up
- 配置变更前 release
- 控制器断开
- capture mode
- 横竖屏布局
- 控件边界
- 预设恢复
- App 失活释放
- 编辑模式不发送输入

### 兼容性

- 每条规则正例和反例
- 稳定 rule ID
- 稳定排序
- 状态聚合
- 无证据无建议
- safe patch 合并
- 重复应用 no-op
- 权限不可静默应用
- 撤销恢复
- stale 判定
- 报告脱敏
- 旧 assessment 解码

### 迁移

- schema 3 → 4
- InputProfile v1 → v2
- 新字段缺失
- 未知 enum
- 迁移幂等
- 写入失败不推进 version
- 既有运行设置、缩略图、收藏和集合保持不变

## 11.2 真机和人工测试

### macOS

- 键盘录制
- Command 快捷键不被吞
- 控制器学习
- 当前游戏恢复存档
- 失焦时释放输入
- Compatibility Details
- VoiceOver
- 深浅色

### iPhone

- 横竖屏布局
- Dynamic Island/Home Indicator
- 多点触控
- 按住按钮旋转
- 按住按钮进入后台
- 恢复存档后重载
- Dynamic Type
- VoiceOver

### iPad

- 全屏
- Split View
- Stage Manager
- 外接键盘
- 外接手柄
- Detail column 导航
- 可变窗口尺寸下布局保持在安全区域

### SWF 样本

- AVM1 游戏
- AVM2 游戏
- 动画
- 单 `.sol`
- 多 `.sol`
- 接近 10 MiB
- 网络请求
- 文件资源请求
- Socket 请求
- 加载超时
- Metal 初始化失败模拟
- 低 FPS 样本

---

# 12. 安全与性能门槛

## 12.1 安全

- 快照路径只能由服务生成
- 槽位名称不能直接成为目录名
- 拒绝绝对路径、`..` 和符号链接逃逸
- 快照恢复前验证大小、hash 和条目数
- 权限扩大始终要求确认
- 输入录制只在明确捕获模式下工作
- 不建立全局键盘监听
- 不记录按键历史，只保存最终映射
- 兼容性报告不包含秘密 URL 或存档内容
- 备份不上传、不遥测
- 破坏性操作的 safety 快照失败时必须停止

## 12.2 性能

- 快照 I/O 不在 MainActor 执行
- 10 MiB 快照期间 UI 保持可操作
- 自动备份不进行持续轮询
- 同一 Library ID 只允许一个存档事务
- 触屏拖动期间不写 `library.json`
- 触屏输入路径不进行磁盘 I/O
- 兼容性规则只使用内存摘要
- 列表卡片只读取 assessment 摘要
- 不在 SwiftUI 每次 render 时生成完整报告
- 不持久化逐帧 FPS 数据

---

# 13. 发布阻断条件

出现以下任一问题不得发布：

- 恢复失败会丢失活动 SharedObject
- 不同作品的存档相互串用
- 后台备份留下被识别为有效的半成品
- 自动清理删除了命名槽
- 切换布局、旋转或后台后出现卡键
- 编辑器捕获按键时仍发送给游戏
- 一键建议修改全局设置
- 一键建议修改其他作品
- 权限被静默放宽
- schema 3 真实用户库无法升级
- 兼容性报告泄露绝对路径、URL secret 或存档内容
- Rust FFI 修改无法从干净 checkout 重建

---

# 14. 推荐交付顺序

最终按以下顺序执行：

1. **M0：技术验证与模型冻结**
2. **M1：详情中心和 schema 4**
3. **M2：手动 SharedObject 快照服务**
4. **M3：安全恢复事务和三个存档槽**
5. **M4：输入模型 v2、来源身份和 Resolver**
6. **M5：按键映射编辑器和控制器学习**
7. **M6：iOS 动态触屏布局和编辑器**
8. **M7：兼容性领域模型和规则引擎**
9. **M8：兼容性详情、一键应用和撤销**
10. **M9：自动备份、保留策略和跨功能集成**
11. **M10：真机回归、安全审计、本地化和发布硬化**

该顺序优先解决数据安全与输入状态正确性，再建设 UI 和自动化能力，避免先做出界面，最后发现存档事务或按键释放模型不可靠。

---

## 关键文件清单

### 核心协调

- `App/Environment/AppState.swift`
- `Features/Library/Models/LibraryItem.swift`
- `Features/Library/Services/LibraryService.swift`
- `Features/Library/Views/LibraryItemDetailsView.swift`

### 存档

- `Features/Player/Services/GameStorageService.swift`
- `Features/Player/Views/GameStorageSection.swift`
- `Shared/Persistence/SharedObjectStoragePaths.swift`
- `patches/engine/ffi/src/player.rs`
- `patches/engine/frontend-utils/src/backends/storage.rs`
- `CRuffleFFI/ruffle_ffi.h`

### 输入

- `Features/Player/Models/InputProfile.swift`
- `Features/Player/Services/InputRouter.swift`
- `Features/Player/Services/GameControllerInputService.swift`
- `Features/Player/Views/GameControlsView.swift`
- `Platform/iOS/Views/IOSContentView.swift`

### 兼容性

- `Features/Diagnostics/Models/CompatibilityReport.swift`
- `Features/Diagnostics/Services/DiagnosticsService.swift`
- `Features/Diagnostics/Views/DiagnosticsView.swift`
- `Core/Security/PermissionPolicyService.swift`
- `Ruffle/Bridge/RuffleBridge.swift`

### 测试

- `Tests/RuffnovaTests/LibraryMigrationTests.swift`
- `Tests/RuffnovaTests/GameStorageServiceTests.swift`
- `Tests/RuffnovaTests/InputMappingTests.swift`
- `Tests/RuffnovaTests/DiagnosticsServiceTests.swift`
- 新增快照、输入编辑器和兼容性规则测试文件
