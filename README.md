# 鲸鱼娘 for Codex

一只陪你写代码的 macOS 桌宠。她悬浮在 Codex 桌面版窗口旁，跟着窗口移动；回合完成时会冒出「压力一只蓝色大肥鱼？」并叫一声。想看订阅余量时，点一下鲸鱼娘即可。

## 互动

- **拖动与吸附**：按住鲸鱼娘或气泡即可拖动。靠近 Codex 窗口边缘时会吸附；位置会保存，窗口移动或缩放后仍会跟随。左侧吸附时角色会镜像。
- **点击气泡**：点击鲸鱼娘会展示台词和 Codex 订阅余量；约 5 秒后自动收起。点击普通台词气泡可切换下一句，最后一句后收起。回合完成的提示同样约显示 5 秒。
- **声音反馈**：按下、松开各有一段短音效；Codex 回合完成时播放猫叫。
- **右键设置**：可开关点击泡泡和边缘吸附、编辑泡泡文案，并在「Codex 订阅余量」菜单中查看或刷新用量。多条文案以 `|` 分隔。

鲸鱼娘只在找到可见的 Codex 窗口时显示。用量浮层与台词使用同一个气泡位置：展开用量时保留当前台词，收起后恢复普通气泡，不会在桌面上多留一块面板。

## 订阅余量

插件通过本机 Codex CLI 的 App Server 只读接口获取订阅限额，展示接口实际返回的额度窗口、剩余百分比和重置时间。剩余百分比按 `100% − 已用百分比` 计算，不代表精确的剩余 token 数。数据会定期刷新，也可通过右键菜单手动刷新。

这项功能需要本机 Codex CLI 已使用 ChatGPT 账户登录；API Key 模式不能提供 ChatGPT 订阅余量。如果 CLI 与桌面版使用不同账户，显示的是 CLI 账户的数据。读取失败时会显示不可用状态，不会估算或填入虚构的数值。

## 安装

需要 macOS、Xcode Command Line Tools 和 `python3`。先下载源码并构建原生程序：

```sh
mkdir -p ~/.codex/plugins
git clone https://github.com/tommy0103/deepseek-girl-plugin.git ~/.codex/plugins/deepseek-girl
cd ~/.codex/plugins/deepseek-girl
./scripts/build.sh
./scripts/test.sh
```

然后在个人插件市场 `~/.agents/plugins/marketplace.json` 中加入以下插件条目。若你已经有这个文件，请将条目合并进现有的 `plugins` 数组，不要覆盖其他插件：

```json
{
  "name": "deepseek-girl-local",
  "plugins": [
    {
      "name": "deepseek-girl",
      "source": {
        "source": "local",
        "path": "./.codex/plugins/deepseek-girl"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL"
      },
      "category": "Productivity"
    }
  ]
}
```

重启 Codex 桌面版，在插件目录选择 `deepseek-girl-local` 并安装「鲸鱼娘」。按提示审阅并信任 `SessionStart` 和 `Stop` 两个 hook；更新 hook 后可能需要重新审阅。插件从安装副本运行，因此修改源码、重新构建后，还需刷新安装副本并重启 Codex。

更多安装与信任机制见 [OpenAI 插件文档](https://developers.openai.com/plugins/build/plugins#install-a-local-plugin-manually)和 [Codex hook 文档](https://learn.chatgpt.com/docs/hooks)。

## 本地试运行

不安装插件也可以先检查窗口识别并启动挂件：

```sh
./bin/deepseek-girl --probe
mkdir -p /tmp/deepseek-girl-preview
./bin/deepseek-girl --data-dir /tmp/deepseek-girl-preview --asset ./assets/deepseek-sticker.png
```

`--probe` 只报告是否找到 Codex 窗口。手动运行时，退出启动挂件的终端进程即可关闭。

## 数据与实现

`SessionStart` hook 启动挂件，`Stop` hook 通知回合完成。hook 只保存会话 ID、回合 ID 和时间戳，不读取消息正文，也不扫描 Codex 的 session 日志。用量缓存包含查询状态、时间以及额度窗口标识、名称、时长、已用百分比和重置时间，不保存账户 ID 或登录凭据。设置与位置保存在插件私有数据目录。

桌宠界面由 Swift/AppKit 实现；Python hook 负责事件通知与只读用量查询。完成猫叫由常驻桌宠播放，不需要额外的全局通知脚本。
