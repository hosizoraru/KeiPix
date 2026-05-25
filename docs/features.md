# Features

按流程展开的非小说功能矩阵。每条线的完成度与最近一次证据时间戳来自 [`readme/NON_NOVEL_GAP_AUDIT_2026-05-25.md`](../readme/NON_NOVEL_GAP_AUDIT_2026-05-25.md)；本页只做精炼。小说面相关流程**继续延后**，待非小说面稳定再启动。

## 账户与登录

- Pixiv OAuth PKCE，使用嵌入式 `WKWebView`
- 沙盒应用容器内的本地安全存储：access / refresh token 持久化
- token 自动刷新 + Settings → Runtime Readiness 一键 Account Health Check（显式刷新一次并写入诊断）
- refresh-token 一键导入：兼容 Pixez 用户迁移
- 多账户切换：侧边栏头像菜单 + Settings 的统一模式选择器
- 三种会话模式：真实账户 / Guest 预览 / Visual QA Sample（隔离）

## 发现入口

- 默认路由是原生 Discover 仪表盘，把所有非首页侧边栏入口聚合成 SwiftUI 命令中心
- 各分区显示本地计数：保存搜索、历史、置顶作者、漫画追更、下载、Pixivision 收藏
- 主 feed：推荐插画 / 推荐漫画 / 最新作品 / 排行榜 / 关注更新 / 收藏 / 标签搜索 / Pixivision

## 画廊与卡片

- 自定义 `MasonryLayout` SwiftUI Layout，4 档密度（auto / 两列 / 三列 / 紧凑）
- 三列固定模式按真实账号宽高比分布做了密集化：常规 / 常宽 / 常全景（≤ 3.2）单列；真正超宽（≥ 3.4）开始跨列；ultra-wide（≥ 4.0）整行
- 卡片角标：AI / R-18 / R-18G / ugoira / 多 P / 已静音
- 选区：⌘-click 多选、⌘A 全选、⇧⌘A 取消、画廊菜单 / Artwork 菜单可批量复制 / 下载 / 收藏 / 屏蔽
- 已加载 feed 与选中子集都支持批量收藏预览（含跳过已收藏）

## 作品详情

- 大图 + 信息折叠：描述、系列、评论、相关作品、tags、metadata
- 折叠状态按作品持久化（`ArtworkDetailStateLibrary`）
- 评论支持 Pixiv emoji token（`(happy)` 等）渲染、原生 emoji 选择器、stamp 图片、举报 / mute 联动
- 相关作品自动加载，无需先点折叠
- 安全反馈与本地静音入口集中在 Feedback / Mute sheet

## 阅读器

- 详情内嵌阅读器 + 独立阅读器窗口（共享设置）
- 三种模式：连续 / 单页 / 索引；按作品类型保存默认值（漫画 vs 普通插画）
- 触控板手势：滑页、双指放大、智能 zoom、键盘翻页
- 全屏专注预设、跳页面板、按作品续读
- 下载到本地的作品有独立本地阅读器，同样保留页码续读

## 下载

- 队列：并发任务、过滤 / 搜索 / 排序、源页范围下载、模板命名占位符
- 失败项一键全部重试 + 退避调度，避免瞬时压满连接
- 下载完成可触发自动收藏（按 Settings 开关）
- 下载库本地预览：Finder 联动、复制链接、当前页图片分享 / 复制 / 下载、ugoira 预览
- 模板占位符：作品 ID / 标题 / 创作者 / 页码 / 扩展 / AI / R-18 / R-18G / tag

## Ugoira

- 元数据 → 解码 → 播放 / 速度（0.5 / 1 / 1.5 / 2x） / 暂停
- ZIP 下载 + 本地 ZIP 预览
- 导出：GIF（含按速率重采样）、当前帧 PNG
- 视觉 QA 用本地生成的样本帧覆盖播放器界面

## 搜索

- 高级筛选：match mode / sort / age / 日期 / 收藏数（含 20k / 50k / 100k 阈值） / AI / 作品类型 / ugoira
- 自动补全 + 本地历史 + 保存关键词 + 完整保存预设（含全部筛选）
- JSON 导入 / 导出（含历史 / 关键词 / 预设）
- Pixiv Web URL 互通：可从 Web 搜索 URL 反向恢复筛选
- 非 Premium 限量热门预览：走 `/v1/search/popular-preview/illust`
- Premium-only 男 / 女完整热门排序保留为可见的锁状操作，需要 Premium 测试账号验收

## Pixivision / Spotlight

- 列表 + 详情，文章内通过原生 `WebArticleView` 渲染
- 收藏 / 历史 / Pixiv 链接解析
- Runtime Readiness 会拉取最新文章 HTML，验证 Pixiv / Pixivision 链接全部命中原生 resolver

## 收藏与关注

- 单作品收藏编辑器：tag 建议、默认可见性、自动 tag、自动下载联动
- 批量收藏预览：作用范围 + 跳过已收藏样本 + 共享 tag
- 关注 / 取消关注 + 公开 / 私密区分
- 推荐 / 搜索 / 关注 / 关联作者列表（含批量动作 + 关联作者发现）
- 本地置顶作者集合，sidebar Library 路由

## 漫画

- 推荐 / 最新 / 排行榜分开
- 系列视图 + 追更列表 + 已读基线 + 未读 / 更新角标 + 标记已读 + 跳到最新一话
- 系列 sheet：原生排序、本地未读 / 已读筛选、宽卡片避免硬换行
- 画廊卡片右键支持系列动作（打开 / 加入追更 / 复制系列链接 / 在 Pixiv 打开）

## 安全过滤

- AI / R-18 / R-18G / mute / ugoira 角标和详情提示
- 可选 R-18 / R-18G 缩略图预览遮罩，覆盖画廊、热门标签、搜索预览、作者预览、相关作品、历史、系列网格
- 可见 feed 批量静音预览：tag / 作者 / 作品 / 评论 phrase + 受影响计数 + 一步撤销
- Pixiv mute list 只读同步：Runtime Readiness 拉取 `/v1/mute/list` 与本地比对
- 反馈 sheet：Pixiv 兼容举报原因 + 摘要复制 + Web 提交跳转

## URL 路由与拖放

- 主窗口接收 Pixiv / Pixivision 链接拖放、剪贴板提取、`.webloc` / `.url` 文档、`keipix://` 自定义 scheme
- 数字 ID 直达：搜索栏支持 `illust:123` / `user:123`，App Controls 也有专门的 ID 打开 sheet
- 全部走同一个 `PixivWebLinkResolver`

## 复制 / 分享模板

- Settings → Sharing 暴露作品 / 作者两套模板编辑器
- 占位符：作品 ID、用户 ID、标题、创作者、页 / 统计、tag、Pixiv URL、AI / R-18 标记
- 实时预览 + 重置 + 持久化

## 本地缓存与离线

- URLCache 磁盘 + 内存图片缓存
- 按路由 / focused creator / search text / bookmark tag / ranking date / search filters 缓存最近成功的作品流
- 加载更多页同步入缓存
- 网络瞬断时只读还原带 cached-feed strip 提示，并提供 Refresh 入口

## 设置

按原生 Form 分组：

- General / Reading / Discovery / Safety / Downloads / Account / Sharing / Runtime Readiness
- 设置项支持中英搜索；搜索词索引拆到 `SettingsSearchTerms.swift`
- Settings 主文件保持 ≤ 1000 行
