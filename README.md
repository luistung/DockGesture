# DockGesture

DockGesture 是一个不占用 Dock 的原生 macOS 菜单栏小工具，为系统 Dock 中的应用图标增加以下行为：

- 普通左键点击当前前台应用：隐藏该应用。
- Command + 右键点击应用：立即请求正常退出。
- Command + Option + 右键点击应用：立即请求强制退出。

Finder 与其他应用使用相同规则。文件夹、废纸篓、分隔线和最小化窗口不受影响。退出手势不显示确认框。

## 安装和首次运行

当前修订版应用位于 `outputs/DockGesture-1.0.1.app`，便于传递的压缩包位于 `outputs/DockGesture-1.0.1.zip`。建议先把应用移动到“应用程序”文件夹，再首次打开；授予权限后不要再移动应用，否则 macOS 可能要求重新授权。

1. 打开 DockGesture，菜单栏会出现手指图标或警告图标。
2. 缺少输入监控权限时，应用会显示中文步骤说明。点击“打开输入监控设置”，在列表中开启 DockGesture；如果列表中没有它，点击“+”从“应用程序”文件夹添加。
3. 按系统提示授予“辅助功能”权限。
4. 如果授权后状态未自动变为“运行中”，退出并重新打开一次。
5. 如需开机自动运行，在菜单中勾选“登录时启动”。首次启用可能还需在“系统设置 → 通用 → 登录项”中批准。

权限未授予、总开关关闭或 Dock 项目无法可靠识别时，工具会放行点击，不改变 Dock 的默认行为。

## 使用

| 操作 | 效果 |
| --- | --- |
| 普通左键点击前台应用的 Dock 图标 | 隐藏应用 |
| 普通左键点击后台应用的 Dock 图标 | 由 Dock 正常激活应用 |
| Command + 右键点击 Dock 应用图标 | 正常退出 |
| Command + Option + 右键点击 Dock 应用图标 | 强制退出 |

带 Control 或 Shift 的右键组合不会被接管。正常退出失败时，DockGesture 不会自动升级为强制退出。

## 构建和测试

要求 macOS 13 或更高版本以及 Apple Command Line Tools：

```bash
./scripts/test.sh
./scripts/build.sh
```

构建脚本使用 Swift 6，并为当前电脑的处理器架构生成 ad-hoc 签名应用。项目也提供标准 `Package.swift`；如果本机 Command Line Tools 的 SwiftPM 组件版本一致，可直接运行 `swift test`。

部分混合版本的 Command Line Tools 会重复声明 `SwiftBridging` 模块。脚本通过编译器 VFS overlay 临时隐藏重复声明，不会修改任何系统文件。

## 安全提示

强制退出可能丢失未保存数据。首次验证 Command + Option + 右键时，请使用无重要数据的测试应用。Finder 被退出后可能由 macOS 自动重新启动，这是系统行为。
