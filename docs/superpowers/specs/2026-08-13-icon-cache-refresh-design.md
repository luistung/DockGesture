# DockGesture 1.0.3 图标刷新修复设计

## 背景与根因

DockGesture 的安装包已经包含有效的 `DockGesture.icns`，`Info.plist` 也声明了该图标。当前 `/Applications/DockGesture.app` 中的图标文件与构建产物完全一致，但 Launchpad 仍显示 macOS 默认占位图标。

根因是构建脚本使用 `ditto` 覆盖既有 App 目录，却没有先删除旧目录；同时加入图标后仍沿用 `1.0.2 (3)`。App 顶层目录的修改时间和 Bundle 版本没有产生足以让 Launch Services 失效旧缓存的变化，因此系统继续使用首次注册时的占位图标。

## 方案选择

采用“新版本 + 干净打包 + 重新注册”的方案：

- 发布 `1.0.3`，Bundle build number 升至 `4`。
- 在 `CFBundleIconFile` 中显式写入 `DockGesture.icns`。
- 每次构建前删除暂存 App 和既有输出 App，再创建全新的 Bundle 目录。
- 替换本机 `/Applications/DockGesture.app` 时先退出旧进程并移除旧 Bundle，然后复制新版本。
- 使用 Launch Services 重新注册新 App，并重新启动 Dock 以刷新 Launchpad 图标缓存。

不采用仅清缓存的临时处理，因为它不能避免以后发布包再次触发相同问题；也不迁移到 Xcode Asset Catalog，因为当前 SwiftPM/脚本构建方式使用 ICNS 已足够，迁移会增加无关复杂度。

## 构建与安装流程

构建脚本负责生成全新的 `DockGesture-1.0.3.app` 和 `DockGesture-1.0.3.zip`。旧的 `1.0.2` 产物不再作为当前输出，但 GitHub 上既有 Release 保留。

本机安装流程为：退出 DockGesture、替换 `/Applications/DockGesture.app`、验证代码签名、强制注册 Bundle、重启 Dock，然后重新启动 DockGesture。输入监控授权沿用相同 Bundle ID `com.dongliang.DockGesture`，不主动清除系统权限数据库。

## 验证

- 运行全部自动化测试和发布构建。
- 校验 App 内 `CFBundleShortVersionString = 1.0.3`、`CFBundleVersion = 4`、`CFBundleIconFile = DockGesture.icns`。
- 解开 ICNS，确认包含 16–1024 像素的完整图标集合。
- 验证 App 代码签名和 ZIP 完整性。
- 安装后确认 Launch Services 解析出的图标为蓝紫色 DockGesture 图标，而不是默认占位图标。
- 创建并发布 GitHub Release `v1.0.3`，上传 ZIP 与 SHA-256 校验值。

## 影响范围

本次只修改版本元数据、构建清理逻辑、README 中的安装包版本以及发布产物；不改变 Dock 手势、权限逻辑或菜单栏行为。
