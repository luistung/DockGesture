# DockGesture 实施计划

日期：2026-08-13  
依据：`docs/superpowers/specs/2026-08-13-dock-gesture-design.md`

## 任务 1：建立可测试的 Swift Package

创建 `Package.swift`、`DockGestureCore`、`DockGesture` 和 `DockGestureCoreTests`。先实现不依赖系统 UI 的手势模型、分类器和应用动作执行策略，再用 XCTest 固定普通左键、Command + 右键、Command + Option + 右键及放行规则。

验收：`swift test` 通过，普通退出失败不会调用强制退出。

## 任务 2：实现 Dock 辅助功能命中

实现 `DockItemResolver`：按全局坐标命中 AX 元素，校验元素 PID 属于系统 Dock，有限向上查找应用 Dock 项目，通过 URL 与运行应用匹配。所有不确定结果返回 `nil`。

验收：代码可编译；非 Dock、非应用项目及解析失败路径均不会产生应用动作。

## 任务 3：实现全局鼠标事件过滤

实现 `DockEventTap`：监听左右键按下/抬起，预筛选相关修饰键，调用 resolver 和 classifier，在 mouse-down 派发动作并抑制匹配 mouse-up；处理 event tap 超时停用与停止清理。

验收：被接管事件完整吞掉，未接管事件原样返回，回调不等待应用退出。

## 任务 4：实现应用动作与状态

用 `NSRunningApplication` 实现隐藏、正常退出和强制退出；动作异步回到主队列，并将接受/失败结果更新到菜单状态。Finder 不设例外。

验收：每个手势只调用对应 API，普通退出失败不升级。

## 任务 5：实现权限、菜单栏与登录项

实现辅助功能和输入监听权限预检/请求、定时重新评估、系统设置入口；实现菜单栏三态图标、总开关、最近动作、登录启动和退出；使用 `SMAppService.mainApp` 管理登录项。

验收：权限不足或总开关关闭时 event tap 不运行；菜单状态与真实服务状态一致。

## 任务 6：打包与说明

增加 `Info.plist`、构建脚本和 README。构建脚本生成 `outputs/DockGesture.app`，设置 `LSUIElement`、最低系统版本并做 ad-hoc 签名。

验收：应用 bundle 结构、Info.plist、架构和代码签名均可检查；应用可启动为菜单栏程序。

## 任务 7：最终验证

运行自动测试、release 构建、签名检查和进程级启动检查。需要用户授权或会影响当前桌面的手动 Dock 手势测试不自动执行，并在 README 中给出安全验证步骤。

验收：所有非交互检查通过；明确列出必须由用户完成的辅助功能授权与真实 Dock 手势验证。
