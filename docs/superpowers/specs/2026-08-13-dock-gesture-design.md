# DockGesture 设计规格

日期：2026-08-13  
状态：已完成交互设计，等待用户复核

## 1. 目标

构建一个原生 macOS 菜单栏应用 `DockGesture`，在不修改或注入 Dock 进程的前提下，为 Dock 中的应用图标增加三种手势：

| 手势 | 条件 | 结果 |
| --- | --- | --- |
| 普通左键点击 | 目标应用正处于前台 | 拦截本次 Dock 点击并隐藏目标应用 |
| 普通左键点击 | 目标应用不在前台 | 完全放行，由 Dock 按系统默认方式激活应用 |
| Command + 右键点击 | 鼠标命中 Dock 应用图标 | 拦截本次点击并立即请求应用正常退出 |
| Command + Option + 右键点击 | 鼠标命中 Dock 应用图标 | 拦截本次点击并立即请求应用强制退出 |

退出手势不显示确认框。Finder 与其他应用遵循完全相同的规则；macOS 可能在 Finder 退出后自行重新启动 Finder，这不视为工具失败。

## 2. 范围

### 2.1 包含

- 纯菜单栏运行，不显示自身 Dock 图标。
- 功能总开关。
- 登录时启动开关，首次运行默认关闭。
- 权限状态、重新检查权限和打开相关系统设置的入口。
- 最近一次动作及结果的简短状态。
- 对 Dock 位于屏幕左侧、底部或右侧的情况使用同一套坐标命中逻辑。
- 支持当前电脑的 Apple Silicon 和 macOS 15；最低部署版本为 macOS 13。

### 2.2 不包含

- 修改、注入或替换系统 Dock。
- 对应用窗口、菜单栏项目、桌面图标或第三方 Dock 实现同类手势。
- 自定义应用白名单、黑名单或手势键位。
- 在普通退出失败后自动升级为强制退出。
- Mac App Store 分发或 Developer ID 公证。

## 3. 精确交互规则

### 3.1 Dock 项目范围

只处理由系统 Dock 暴露的应用项目。文件夹、堆栈、废纸篓、分隔线、最近使用的文稿和最小化窗口均原样放行。

命中结果必须同时满足：

1. 辅助功能元素属于 `com.apple.dock` 进程；
2. 当前元素或其可接受的父元素是 Dock 应用项目；
3. 能从该元素解析到一个当前运行的应用。

任何步骤失败都必须放行原始点击。

### 3.2 修饰键规则

- 隐藏只响应不带 Command、Option、Control 或 Shift 的普通左键点击；带修饰键的左键点击保留系统原有语义。
- 右键手势必须包含 Command。
- Command + Option 的优先级高于仅 Command，并执行强制退出。
- 如果右键还带有 Control 或 Shift，不接管该手势，保留系统默认行为。
- Caps Lock 和 Fn 不参与上述组合判断。

### 3.3 点击生命周期

- 在 mouse-down 时完成识别并且最多触发一次动作。
- 如果工具接管 mouse-down，则记录对应鼠标按钮，并一并拦截该按钮的 mouse-up。
- 如果未接管 mouse-down，则 mouse-down 和 mouse-up 都原样传递。
- 事件回调只做命中、分类和派发；隐藏或退出动作异步执行，不能阻塞全局输入事件循环。

### 3.4 前台判定

普通左键 mouse-down 到达时，以 `NSWorkspace.shared.frontmostApplication` 为准。只有其运行实例与 Dock 项目解析出的运行实例相同，才隐藏目标应用并拦截点击。否则不自行激活应用，而是放行给 Dock。

## 4. 架构

### 4.1 `DockEventTap`

职责：

- 通过 Core Graphics event tap 接收 left/right mouse-down 和 mouse-up。
- 读取鼠标全局坐标和有效修饰键。
- 在被系统因超时停用时重新启用 event tap。
- 根据手势分类结果决定返回原事件还是吞掉事件。

该模块不解析应用、不直接隐藏或退出应用。

### 4.2 `DockItemResolver`

职责：

- 使用系统级 `AXUIElementCopyElementAtPosition` 对鼠标位置做辅助功能命中测试。
- 必要时有限地向父层级遍历，以识别 Dock 应用项目。
- 校验元素归属 Dock 进程。
- 优先通过 Dock 项目 URL 解析应用 bundle URL 和 bundle identifier，再与 `NSWorkspace.shared.runningApplications` 匹配。
- 返回稳定的运行应用描述，或在任何不确定情况下返回无结果。

匹配多个实例时，优先选择当前前台且 bundle URL 一致的实例；否则选择第一个具有 `.regular` activation policy 且 bundle URL 一致的实例。该规则保证结果确定，但不尝试同时退出多个实例。

### 4.3 `GestureClassifier`

职责：将鼠标按钮、事件阶段、修饰键、目标类型和前台状态转换为以下之一：

- `passThrough`
- `hide`
- `terminate`
- `forceTerminate`
- `suppressMatchingMouseUp`

该模块是纯逻辑模块，不依赖 AppKit 全局状态，便于单元测试。

### 4.4 `AppActionController`

职责：

- `hide`：调用目标运行应用的隐藏能力。
- `terminate`：调用 `NSRunningApplication.terminate()`。
- `forceTerminate`：调用 `NSRunningApplication.forceTerminate()`。
- 发布动作开始和结果状态，供菜单栏显示。

正常退出返回失败时只记录失败，不调用强制退出。强制退出可能在目标实际结束前返回；结果状态应区分“请求已接受”和“目标已结束”，并可通过运行状态或工作区通知更新。

应用不启用 App Sandbox，因为沙盒应用不能使用 `NSRunningApplication.forceTerminate()` 终止其他应用。

### 4.5 `PermissionController`

职责：

- 检查辅助功能信任状态。
- 检查监听输入事件所需的系统授权状态。
- 首次运行时触发系统授权提示，并提供打开系统设置的入口。
- 只有所需权限均满足时才启动事件拦截。

权限不足、被撤销或 event tap 创建失败时，工具必须进入“需要权限”状态并停止接管全部点击。

### 4.6 `MenuBarController`

菜单从上到下包含：

1. 不可点击的状态行：运行中、已暂停或需要权限；
2. 启用 Dock 手势；
3. 登录时启动；
4. 最近一次动作及结果；
5. 重新检查权限；
6. 打开辅助功能设置；
7. 打开输入监控设置（系统提供对应入口时）；
8. 退出 DockGesture。

菜单栏图标用三种模板状态表达正常、暂停和警告，不使用彩色常驻图标。

### 4.7 `LoginItemController`

使用 macOS 13 及以上的 `SMAppService.mainApp` 注册或注销主应用登录项。菜单勾选状态从系统服务状态读取，而不是只读取本地偏好。注册被系统拒绝时显示失败状态并提供打开“登录项”设置的入口。

## 5. 数据流

1. 用户在 Dock 上按下鼠标。
2. `DockEventTap` 读取按钮、坐标和修饰键。
3. 对可能相关的手势，`DockItemResolver` 命中并解析运行应用；不相关手势立即放行。
4. `GestureClassifier` 根据目标、修饰键和前台应用输出动作。
5. `passThrough` 返回原事件；其他动作吞掉 mouse-down 并登记需要吞掉的 mouse-up。
6. `AppActionController` 在主队列异步执行动作并发布结果。
7. `MenuBarController` 刷新最近动作状态。

## 6. 权限与隐私

- 辅助功能权限用于读取 Dock 的辅助功能元素并允许事件过滤。
- 输入监控权限是否单独出现由当前 macOS 的 event tap 授权策略决定；应用同时实现预检和引导。
- 不读取键入内容，不监听键盘 key-down/key-up；修饰键直接从鼠标事件 flags 获取。
- 不联网、不采集遥测、不持久化应用使用记录。
- 只保存功能开关等本地偏好；登录项真实状态由 `SMAppService` 管理。

## 7. 错误处理

- 权限不足：停止 event tap，所有 Dock 行为保持原样，菜单栏显示警告。
- event tap 创建失败：显示可恢复错误，允许重新检查，不循环高速重试。
- event tap 超时停用：在回调内快速重新启用；连续失败则停止监听并显示错误。
- AX 命中或属性读取失败：原样放行当前点击。
- 找不到运行应用：原样放行当前点击。
- 隐藏、退出或强退请求失败：不重试、不改变动作类型，仅更新结果状态。
- 应用在解析后已退出：视为无须继续操作，绝不改为操作其他同名应用。

## 8. 工程与构建

- 语言：Swift 6。
- UI：AppKit 菜单栏应用。
- 工程形态：Swift Package，包含可执行 target、核心库 target 和测试 target。
- 构建环境：Apple Command Line Tools；不要求安装完整 Xcode。
- 产物：标准 `.app` bundle，`Info.plist` 设置 `LSUIElement=true`。
- 签名：本机 ad-hoc 签名，保证 app bundle 内代码一致性；不承诺跨机器的 Gatekeeper 分发体验。
- 构建脚本：编译 release 二进制、组装 bundle、写入 Info.plist、签名并将最终产物复制到 `outputs/`。

## 9. 验证计划

### 9.1 自动测试

- `GestureClassifier` 的全部按钮、阶段和修饰键组合。
- 普通左键对前台同一实例执行隐藏，对非前台实例放行。
- 被接管的 mouse-down 只产生一个动作，并吞掉匹配 mouse-up。
- 未接管的 mouse-down/mouse-up 均放行。
- Command + Option + 右键优先选择强制退出。
- 带 Control 或 Shift 的右键组合放行。
- 正常退出失败后绝不调用强制退出。
- 权限不足时不创建或立即停止 event tap。
- Dock 项目解析失败及非应用项目全部放行。

### 9.2 本机冒烟测试

- Dock 分别位于左、下、右时识别应用项目。
- 点击当前前台的普通应用图标后应用隐藏，Dock 不额外激活它。
- 点击非前台应用图标后由 Dock 正常激活。
- Command + 右键让专用测试应用正常退出，且不显示 Dock 右键菜单。
- Command + Option + 右键强制结束专用测试应用，且不显示 Dock 右键菜单。
- Finder 使用相同手势路径；记录系统是否自动重启 Finder。
- 文件夹、废纸篓、分隔线和最小化窗口保持原行为。
- 总开关关闭后所有点击保持系统原行为。
- 撤销权限后工具停止接管；重新授权后能恢复。
- 登录项可注册、注销，并且菜单状态与系统设置一致。

强制退出验证只使用专门的测试进程，不操作用户当前正在工作的应用。

## 10. 验收标准

满足以下条件即视为完成：

1. 三种手势在当前电脑上按本规格稳定工作。
2. 非目标手势和非应用 Dock 项目不受影响。
3. 工具未获权限、被暂停或解析失败时不破坏 Dock 默认行为。
4. Command + 右键失败时不会自动强制退出。
5. 菜单栏可查看状态、开关功能、管理登录启动和进入权限设置。
6. 自动测试通过，且本机冒烟测试不使用用户工作中的应用做强退目标。
7. `outputs/` 中包含可运行应用；仓库包含源码、构建脚本和使用说明。

## 11. 主要系统接口依据

- Core Graphics event tap 用于访问和过滤鼠标事件。
- Accessibility `AXUIElementCopyElementAtPosition` 用于按全局屏幕坐标命中 UI 元素。
- `NSRunningApplication.terminate()` 与 `forceTerminate()` 分别用于正常退出和强制退出。
- `SMAppService.mainApp` 用于 macOS 13 及以上的主应用登录启动。

