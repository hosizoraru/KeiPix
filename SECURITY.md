# Security Policy

KeiPix 会处理 Pixiv access token、refresh token、本地浏览/搜索历史和下载文件，因此安全报告请尽量走私密渠道。

## Supported Versions

当前仓库还没有正式 release channel。安全修复以 `master` 分支为准，tag release 会继承当时 `master` 的修复状态。

## Reporting A Vulnerability

优先使用 GitHub Private Vulnerability Reporting。如果该入口不可用，请开一个最小 public issue：

- 不要贴 token、refresh token、cookie、完整请求头、真实账户 ID、下载路径或未公开漏洞利用细节。
- 只说明影响范围和需要私下沟通。
- 维护者确认后，再通过私密渠道交换复现步骤、日志和补丁建议。

## Sensitive Data Boundaries

- Pixiv session 存在沙盒容器内的 `pixiv-sessions.json`，由 `PixivSessionStore` 管理。
- Visual QA Sample 模式不读取真实账号凭据。
- 仓库没有遥测；`--telemetry` 只是跟随本地 `os_log`。
- 任何远端写入路径都必须有可见入口、显式授权和可回滚/可撤销说明。

## What Helps

报告安全问题时，尽量提供：

- 受影响的 commit 或 tag。
- macOS / Xcode / Swift 版本。
- 最小复现步骤。
- 预期影响和实际影响。
- 不含敏感值的日志片段或截图。
