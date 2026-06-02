# Support

KeiPix 当前主要通过 GitHub Issues 跟踪问题、功能请求和文档缺口。

## Before Opening An Issue

- 先查看 [README.md](README.md) 与 [docs/](docs/)。
- 如果是构建问题，附上 macOS、Xcode、Swift 版本，以及失败命令。
- 如果是 UI 问题，说明具体 surface，例如 gallery、reader、download queue、settings、Pixivision。
- 如果是账号或网络问题，不要贴 token、refresh token、cookie、完整请求头或个人隐私信息。

## Useful Commands

```bash
swift build
swift test
./script/build_and_run.sh --verify
./script/build_and_run.sh --visual-qa-gallery-three-column
./script/capture_visual_qa.sh gallery-three-column
```

## Security

安全问题请优先阅读 [SECURITY.md](SECURITY.md)。如果 GitHub Private Vulnerability Reporting 不可用，请开一个不含敏感细节的 public issue，说明需要私下沟通漏洞细节。
