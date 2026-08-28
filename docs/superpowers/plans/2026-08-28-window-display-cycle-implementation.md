# DockGesture Fn+Enter 窗口跨显示器循环实施计划

日期：2026-08-28

分支：`codex/window-display-cycle`

依据：`docs/superpowers/specs/2026-08-28-window-display-cycle-design.md`

## 1. 快捷键纯逻辑模型

- 新建 `Sources/DockGestureCore/WindowMoveShortcut.swift`。
- 定义 Return、Keypad Enter 两种目标虚拟键、Fn 与冲突修饰键、key-down/key-up、自动重复，以及“放行”“拦截”“拦截并触发”的决定。
- 使用可变状态记录已处理的按键，使 Fn 先释放时仍能拦截对应 key-up；停止事件监听时必须复位。
- 新建 `Tests/DockGestureCoreTests/WindowMoveShortcutTests.swift`，先写失败测试，再实现最小逻辑。
- 把关键等价检查加入 `Tests/ManualTestRunner/main.swift`，保证项目现有脚本测试路径覆盖新功能。

## 2. 显示器循环与窗口几何模型

- 新建 `Sources/DockGestureCore/DisplayCyclePlanner.swift`。
- 定义与 AppKit 无关的窗口矩形、显示器完整区域、可见区域和规划结果。
- 实现源显示器选择：最大交叠面积优先，窗口中心和列表顺序用于平局判定。
- 实现下一显示器循环，两屏与三屏的末项均回到首项。
- 实现相对行程映射、只缩小不放大和最终边界限制。
- 在 `Tests/DockGestureCoreTests/DisplayCyclePlannerTests.swift` 与手工测试 runner 中覆盖同尺寸、不同尺寸、贴边、横跨屏幕、超大窗口、单显示器和全屏形状识别。

## 3. 扩展全局事件监听

- 修改 `Sources/DockGesture/DockEventTap.swift`，事件掩码加入 `keyDown` 与 `keyUp`。
- 在鼠标路径之前处理键盘事件，读取 `keyboardEventKeycode`、`keyboardEventAutorepeat` 和 `maskSecondaryFn`。
- 为事件 tap 增加 `onWindowMoveShortcut` 回调；触发时异步派发到主线程，事件回调本身不做 AX 或屏幕计算。
- 对匹配的 key-down、自动重复和对应 key-up 返回 `nil`；其他键盘事件完全放行。
- `stop()`、事件 tap 被系统禁用后恢复时重置快捷键状态，避免残留 key-up 被错误拦截。
- 保持现有鼠标手势分类、mouse-up 抑制和 tap 恢复行为不变。

## 4. 前台窗口辅助功能访问

- 新建 `Sources/DockGesture/FocusedWindowAccessor.swift`。
- 通过 `NSWorkspace.shared.frontmostApplication`、`AXUIElementCreateApplication` 和 `kAXFocusedWindowAttribute` 获取聚焦窗口。
- 读取窗口标题、位置、尺寸，并检查 `kAXPositionAttribute` 与 `kAXSizeAttribute` 是否可设置。
- 提供设置尺寸、设置位置的窄接口，把 `AXError` 映射为结构化失败阶段，不在该组件中决定显示器或用户文案。
- 不缓存 AX 窗口元素；每次快捷键重新解析，避免窗口关闭或切换后使用失效对象。

## 5. 窗口移动控制器

- 新建 `Sources/DockGesture/FocusedWindowMover.swift`。
- 每次触发重新读取 `NSScreen.screens`、`frame`、`visibleFrame` 与显示器名称，并转换为 AX 使用的左上角全局坐标。
- 少于两台屏幕时立即返回“只有一台显示器，无需移动”。
- 若窗口矩形占满某台显示器完整 `frame`，或位置不可设置，按全屏、平铺或不可移动窗口拒绝处理。
- 调用 `DisplayCyclePlanner` 得到目标矩形；仅当目标尺寸变化时设置尺寸，然后设置位置。
- 如果必须缩小但尺寸不可设置，停止且不先移动窗口。
- 成功后返回目标显示器和窗口标题；失败返回设计文档中定义的简短菜单状态。

## 6. 生命周期与菜单状态接入

- 修改 `Sources/DockGesture/AppDelegate.swift`，创建窗口移动控制器并连接 `DockEventTap.onWindowMoveShortcut`。
- 移动结果写入现有 `lastAction` 并刷新菜单，不弹窗、不发通知。
- 沿用现有功能总开关和权限门槛：只有总开关启用且辅助功能、输入监控都就绪时，快捷键才生效。
- 保留当前菜单标题“启用 Dock 手势”，本期不引入新的独立开关。
- 修改 `Resources/Info.plist` 的 `NSInputMonitoringUsageDescription`，同时说明 Dock 鼠标手势和 `Fn + Enter` 键盘快捷键。

## 7. 自动化验证

- 运行 `./scripts/test.sh`，确认新增检查与原有 Dock 手势检查全部通过。
- 运行 `swift test`；若本机混合 Command Line Tools 的已知 SwiftBridging 问题仍存在，以项目脚本测试为准并记录。
- 运行 `./scripts/build.sh`，验证 Swift 6 `warnings-as-errors`、应用签名和 ZIP 打包。
- 运行 `git diff --check`、`codesign --verify --deep --strict` 与 `unzip -t`。
- 复核只修改计划内文件，不提交 `.build-local`、`outputs` 或 `work` 中的生成物。

## 8. 本机按键与双屏验收

- 备份当前 `/Applications/DockGesture.app`，安装开发分支构建；不覆盖项目中保存的正式版备份。
- 在当前键盘上确认 `Fn + Return` 的实际 keycode 与 Fn 标志；兼容 Return 和 Keypad Enter，但绝不把裸 Keypad Enter 当成快捷键。
- 在文本编辑器中验证快捷键不会插入换行，长按不会连续跨屏。
- 连续按快捷键验证两台显示器往返循环，并验证不同尺寸、贴边、横跨屏幕和目标屏较小的窗口。
- 验证 Finder、AppKit 应用和 Electron/Chromium 应用。
- 验证全屏、系统平铺、无聚焦窗口和单显示器路径安全失败且只更新菜单状态。
- 验证总开关关闭后快捷键失效，原有 Dock 隐藏、退出、强制退出和状态标记均无回归。

## 9. 交付边界

- 将实现提交到 `codex/window-display-cycle`，提交作者保持 `luistung <dongliang1986@gmail.com>`。
- 不合并 `master`、不推送远程、不创建 Release，直到用户完成开发版体验并明确批准。
- 交付时报告自动测试数量、构建与签名结果、实机应用覆盖范围和仍不支持的窗口类型。
