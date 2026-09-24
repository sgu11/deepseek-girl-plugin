# 项目协作约定

## 项目范围

- 维护 macOS 原生 Codex 鲸鱼娘插件。当前功能包括常驻桌宠交互、回合完成提示，以及只读的 Codex 订阅余量。
- 以 `README.md` 记录当前行为、使用方法和运行所需条件。

## 代码职责

- `app/` 使用 Swift 与 AppKit。让 `Companion.swift` 协调生命周期和交互，把窗口定位、手势、气泡、设置、用量、事件与声音逻辑放在各自模块。
- `hooks/event.py` 处理插件的 `SessionStart` 和 `Stop` 事件。保持执行快速、非阻塞，输出合法的空 JSON；完成事件仅保存会话 ID、回合 ID 和时间戳。
- `hooks/quota.py` 通过 Codex App Server 的 `account/rateLimits/read` 只读接口取数。展示接口实际返回的额度窗口、剩余百分比与重置时间。
- `assets/rubble-duck1.mp3` 用于按压和回合完成（音量均为 0.6），`assets/rubble-duck2.mp3` 用于松开。让桌宠成为完成提示音的唯一播放来源。
- 维持单角色桌宠。调整素材时核对构建、测试及运行时引用，保持交互与音效正常。

## 修改与验证

- 在本源码目录编辑文件。将 `.build/`、`bin/` 和插件安装缓存视为生成或安装产物。
- Swift 改动运行 `./scripts/build.sh` 和 `./scripts/test.sh`；Python hook 或用量逻辑改动运行 `./scripts/test.sh`。
- 交互与音效改动分别说明自动测试和实际桌面验证的结果。
- 用户要求部署当前修改时，先构建，再刷新插件、重启桌宠并核对安装副本。对用户全局 Codex 配置、其他 hook 和通知的修改按明确请求单独处理。
- 可见行为变化同步更新 `README.md`；素材范围变化核对构建、测试与运行时引用。
