# Safety & Privacy

KeiPix 把"可见性"和"可逆性"当成 P0 要求。任何敏感内容、远端写入、跨账户操作都需要明确授权与可见入口。

## 内容分级

- 卡片角标：AI 生成、R-18、R-18G、ugoira、多 P、已静音
- 详情页同步显示同一组角标，避免列表与详情失同步
- 下载文件名模板支持 `{ai}` / `{r18}` / `{r18g}` 等占位符，便于本地分类

## R-18 / R-18G 预览遮罩

- Settings → Safety 与工具栏 App Controls 菜单都能开关
- 持久化在 `UserDefaults`，跨重启保留
- 覆盖范围：主画廊、masonry 卡片、热门标签、搜索热门预览、作者预览缩略图、近期 / 相关作品、浏览历史、系列网格

## AI 显示

- 本地隐藏 AI 作品 + 搜索 `search_ai_type` 过滤都是支持路径
- Pixiv 账户级 AI 显示开关在已验证的 App API 表面**不可达**，KeiPix 选择不实现远端同步并在 Settings / Runtime Readiness 上明确标注
- 当 Pixiv 公布可验证端点后再补 remote sync

## 静音 / 屏蔽

- 本地静音支持四个对象：tag、作者、作品、评论 phrase
- 可见 feed 批量预览：选定子集 → 显示受影响计数 → 一键应用 → 一步撤销（基于快照）
- Pixiv mute 同步：
  - 只读：Runtime Readiness 拉取 `/v1/mute/list`，与本地比对 tag / 作者，并对比覆盖到本地作品 / 评论 phrase 的差集
  - 写入（导入 / 上传）：默认禁用；只在显式确认 + 可逆 / 可丢弃账户授权下允许
- 所有静音变更都写入本地导入 / 导出 JSON，便于跨设备携带

## 反馈与举报

- 原生 `FeedbackReportSheet` 提供 Pixiv 兼容举报原因
- 摘要可一键复制；最终提交跳转 Pixiv Web，KeiPix 不直接代为提交
- 评论 / 作品 / 作者三个入口都接同一份 sheet
- Settings → Runtime Readiness 暴露 Comment Feedback Preview，可对当前选中作品的第一条评论开 sheet 做读模式 QA

## 本地凭据

- Pixiv access / refresh token 存在 macOS Keychain（`KeychainTokenStore`）
- 多账户按用户 ID 分键，切换时不污染其他账户
- 选择 "Hide account text" 时 UI 不再回显账户名
- Visual QA Sample 模式完全不读 Keychain；`--verify` 与所有 `--visual-qa-*` 旗标都走这套隔离会话

## 沙盒与 entitlements

`App/KeiPix.entitlements`：

- `com.apple.security.app-sandbox = true`
- `com.apple.security.network.client = true`（Pixiv App API + 图片 CDN）
- `com.apple.security.files.user-selected.read-write = true`（保存搜索 JSON 导入导出）
- `com.apple.security.files.downloads.read-write = true`（下载库）
- `com.apple.security.print = true`（保留导出场景）

`project.yml` 同时启用 `ENABLE_HARDENED_RUNTIME = YES`、`ENABLE_USER_SCRIPT_SANDBOXING = YES`、`DEAD_CODE_STRIPPING = YES`。

## 个人数据

- 浏览历史 / 搜索历史 / Pixivision 历史只存本地（`UserDefaults` + 简单 JSON）
- 没有任何遥测或第三方分析；`--telemetry` 模式只是订阅本地 `os_log`
- 主仓库不入库任何带账号信息的样本数据；视觉 QA 全部用本地化生成样本

## 远端写入门槛

| 动作 | 默认状态 | 授权要求 |
| --- | --- | --- |
| 公开 / 私密收藏 | 用户主动操作时直接执行 | 普通用户操作 |
| 关注 / 取消 | 用户主动操作时直接执行 | 普通用户操作 |
| 批量收藏 / 屏蔽 / 下载 | 显式预览 + 可见受影响列表 | 用户在 sheet 中再次确认 |
| Mutable QA 演练（私密收藏 / 关注循环） | 默认禁用 | Settings 显式键入 `TEST ACCOUNT` |
| Pixiv mute 上传 / 导入 | 默认禁用 | 显式 confirmation + 可丢弃账号 |
| 评论删除 | 不实现 | 等待 Pixiv 公布可逆端点 |

任何新写入路径要先回答这两个问题再合入：是否对用户可见？是否可逆？
