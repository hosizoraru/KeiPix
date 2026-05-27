# Localization

KeiPix 当前支持英文（`en`）、简体中文（`zh-Hans`）、繁体中文（`zh-Hant`）、日文（`ja`）四个语言。每个 UI 字符串都通过 `L10n` 静态访问器读取，避免散落的字面量。

## 文件位置

```
Sources/KeiPix/Resources/
└── Localizable.xcstrings   # 单一字符串目录，所有语言共用
```

`Package.swift` 声明 `defaultLocalization: "en"`，`Info.plist` 与脚本生成的 plist 都声明 `CFBundleLocalizations: [en, zh-Hans, zh-Hant, ja]`。`XCStringsBuilder` SwiftPM 插件在构建时调用 `xcrun xcstringstool compile`，把 `Localizable.xcstrings` 编译成各 `<lang>.lproj/Localizable.strings`，再由 `Resources/.process` 自动打包进 bundle。

## L10n 入口

`Sources/KeiPix/Support/L10n.swift` 是所有 UI 字符串的访问层：

- 每个 key 对应一个静态计算属性 / 方法（必要时带占位符）
- 测试 `L10nRuntimeDiagnostics` 在 Runtime Readiness 中校验关键 key 在所有语言下都存在
- `SettingsView` 的搜索按本地化文案做匹配，索引词单独放在 `SettingsSearchTerms.swift`

## 添加新文案

1. 在 `L10n.swift` 加新 key（保持字母 / 模块顺序）
2. 在 `Localizable.xcstrings` 中加入对应条目，并补全 `en` / `zh-Hans` / `zh-Hant` / `ja` 四种语言。Xcode 打开 `.xcstrings` 是最直观的方式；命令行编辑也可以，遵循 JSON 字段顺序与缩进
3. 如果出现在 Settings 搜索结果中，把搜索词加到 `SettingsSearchTerms.swift`
4. 跑 `swift build` 校验（缺 key 会在 Runtime Readiness 标红）
5. 如果改到 surface 上的可见文案，按 [`quality-assurance.md`](quality-assurance.md) 重抓视觉 QA

## 新增语言

- 在 `Localizable.xcstrings` 中为目标 locale 补全所有 key 的翻译
- `Package.swift` 不需要改（资源走 `Resources/.process`，插件按 xcstrings 中声明的语言生成 `.lproj`）；Xcode 路径需要重新 `xcodegen generate`
- `Info.plist` / `script/build_and_run.sh` 中的 `CFBundleLocalizations` 加入新语言代码
- 把翻译走查写进当次 PR 的验证清单

## 文案风格

- 英文：句首大写，避免缩写歧义；UI 动作动词优先（"Open", "Refresh"）
- 中文：以平静直陈为主，避免感叹号 / 营销语气；专有名词（Pixiv / Pixivision / Ugoira）保留原文
- 错误提示：先讲发生了什么，再讲下一步（"Token 已失效。重新登录或在 Settings → Account 中刷新"）
- 安全相关文案显式标"本地"或"远端"，避免误把本地操作理解成 Pixiv 上变更
