# Contributing To KeiPix

感谢你愿意帮 KeiPix 变好。

完整贡献指南请看 [docs/contributing.md](docs/contributing.md)。那里记录了本仓库实际采用的分支、提交、测试、视觉 QA、远端写入和 reference-client 边界要求。

快速检查：

- 代码改动保持一个主题；多主题拆 PR。
- 热路径默认使用 AppKit/UIKit，SwiftUI 作为状态和组合外壳。
- UI、画廊、阅读器、长文本或平台输入改动需要对应视觉 QA。
- 提交 PR 前至少运行 `swift build` 与 `swift test`。
- 不要在 issue、日志、截图或 manifest 中公开 Pixiv token、refresh token、cookie 或个人账户信息。

本仓库目前没有正式 License。除非作者补充 License，否则源码仅供阅读与评估，不授予分发、再授权或衍生授权。
