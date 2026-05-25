# Localization

KeiPix 当前支持英文（`en`）与简体中文（`zh-Hans`）两个语言。每个 UI 字符串都通过 `L10n` 静态访问器读取，避免散落的字面量。

## 文件位置

```
Sources/KeiPix/Resources/
├── en.lproj/Localizable.strings        # 主语言（默认 fallback）
└── zh-Hans.lproj/Localizable.strings   # 简体中文
```

`SWIFT_VERSION 6.0` + `Package.swift` 中 `defaultLocalization: "en"`，`Info.plist` 与脚本生成的 plist 都声明 `CFBundleLocalizations: [en, zh-Hans]`。

## L10n 入口

`Sources/KeiPix/Support/L10n.swift` 是所有 UI 字符串的访问层：

- 每个 key 对应一个静态计算属性 / 方法（必要时带占位符）
- 测试 `L10nRuntimeDiagnostics` 在 Runtime Readiness 中校验关键 key 在两套 strings 文件中都存在
- `SettingsView` 的搜索按本地化文案做匹配，索引词单独放在 `SettingsSearchTerms.swift`

## 添加新文案

1. 在 `L10n.swift` 加新 key（保持字母 / 模块顺序）
2. 同步在 `en.lproj/Localizable.strings` 与 `zh-Hans.lproj/Localizable.strings` 写入翻译
3. 如果出现在 Settings 搜索结果中，把搜索词加到 `SettingsSearchTerms.swift`
4. 跑 `swift build` 校验（缺 key 会在 Runtime Readiness 标红）
5. 如果改到 surface 上的可见文案，按 [`quality-assurance.md`](quality-assurance.md) 重抓视觉 QA

## 新增语言

- 复制 `en.lproj/Localizable.strings` 到新 `<lang>.lproj/Localizable.strings`
- 在 `Package.swift` 不需要改（资源走 `Resources/.process`），但 Xcode 路径需要重新 `xcodegen generate`
- `Info.plist` / `script/build_and_run.sh` 中的 `CFBundleLocalizations` 加入新语言代码
- 把翻译走查写进当次 PR 的验证清单

## 文案风格

- 英文：句首大写，避免缩写歧义；UI 动作动词优先（"Open", "Refresh"）
- 中文：以平静直陈为主，避免感叹号 / 营销语气；专有名词（Pixiv / Pixivision / Ugoira）保留原文
- 错误提示：先讲发生了什么，再讲下一步（"Token 已失效。重新登录或在 Settings → Account 中刷新"）
- 安全相关文案显式标"本地"或"远端"，避免误把本地操作理解成 Pixiv 上变更
