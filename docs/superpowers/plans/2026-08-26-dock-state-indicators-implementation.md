# DockGesture Dock 应用状态标记实施计划

日期：2026-08-26

分支：`feature/dock-state-indicators`

## 1. 纯状态与几何模型

- 新建 `Sources/DockGestureCore/DockApplicationIndicator.swift`。
- 定义运行实例快照、`frontmost`、`hidden`、`none` 三态和多实例优先级归并。
- 定义标记直径限制与右上角锚点的纯几何计算。
- 新建 `Tests/DockGestureCoreTests/DockApplicationIndicatorTests.swift`，覆盖四种基本状态、多实例优先级和尺寸边界。
- 把等价检查加入 `Tests/ManualTestRunner/main.swift`，确保现有脚本测试路径也覆盖新逻辑。

## 2. Dock 项目快照

- 扩展 `Sources/DockGesture/DockItemResolver.swift`，在保留点击命中解析的同时新增 Dock 应用项目枚举。
- 从辅助功能树提取应用 Dock item 的 URL、标题、位置和尺寸。
- 沿用 URL、Bundle ID、唯一标题的匹配顺序，把 Dock item 关联到运行实例。
- Dock PID 或辅助功能树失效时返回空快照，不保留陈旧元素。

## 3. 状态监控与刷新调度

- 新建 `Sources/DockGesture/DockApplicationStateMonitor.swift`，订阅应用启动、退出、激活、停用、隐藏和取消隐藏通知。
- 新建 `Sources/DockGesture/DockStateRefreshScheduler.swift`，在状态通知时即时刷新；鼠标靠近 Dock 时提升到最高 30 Hz，静止时降频。
- 监听屏幕参数与 Space 变化，变化时强制重新发现 Dock 项目。

## 4. 透明覆盖层

- 新建 `Sources/DockGesture/DockStateOverlayController.swift` 和 `DockStateIndicatorView.swift`。
- 按屏幕维护透明、无边框、非激活、鼠标穿透的覆盖窗口，窗口层级位于 Dock 之上。
- 绘制蓝色前台亮点与灰色隐藏减号，按 Dock 图标尺寸缩放。
- 快照失败、无标记、暂停或权限不足时立即关闭覆盖窗口。

## 5. 生命周期接入

- 在 `Sources/DockGesture/AppDelegate.swift` 中创建并连接状态监控、刷新调度和覆盖层。
- 现有总开关启用且权限齐全时启动，暂停、权限丢失和退出时停止。
- 覆盖层故障不改变 `DockEventTap` 的运行状态，保证原有手势独立工作。

## 6. 自动化验证

- 运行 `./scripts/test.sh`，确保新旧检查全部通过。
- 运行 `swift test`；若本机 SwiftPM 组件不兼容，以现有脚本测试为准并记录原因。
- 运行 `./scripts/build.sh`，验证 Swift 6 warnings-as-errors、签名和打包。
- 使用 `git diff --check`、`codesign --verify --deep --strict` 和 ZIP 完整性检查。

## 7. 本机原型验收

- 备份当前 `/Applications/DockGesture.app`，安装开发分支构建并启动。
- 验证前台蓝点、隐藏灰色减号、后台可见与未启动无标记。
- 验证 Finder、Dock 自动隐藏与放大、Dock 三个方向、多屏、Space 切换和 Dock 重启。
- 验证覆盖层鼠标穿透，原有隐藏、退出和强制退出手势正常。
- 验证失败时可恢复已备份的 1.0.3 正式版。

## 8. 交付

- 提交实现到 `feature/dock-state-indicators`。
- 不合并 `master`，不创建 Release。
- 把原型运行状态、测试结果和已知限制交给用户确认。
