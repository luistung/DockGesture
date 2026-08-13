# DockGesture 1.0.3 图标刷新修复实施计划

日期：2026-08-13

1. 将 Bundle 版本升级为 `1.0.3 (4)`，并把图标文件名显式设为 `DockGesture.icns`。
2. 修改构建脚本，在创建 Bundle 前删除暂存 App 和同版本输出 App，确保每次生成全新的目录与元数据。
3. 更新 README 的当前安装包版本与 1.0.3 修复说明。
4. 运行核心测试、构建、版本与图标资源检查、代码签名检查和 ZIP 完整性检查。
5. 退出现有 DockGesture，替换 `/Applications/DockGesture.app`，强制注册 Bundle 并重启 Dock。
6. 通过系统图标解析结果和截图确认安装版本显示蓝紫色 DockGesture 图标。
7. 提交实现并推送 `master`，创建 `v1.0.3` 正式 Release，上传 ZIP 和 SHA-256 校验值。
