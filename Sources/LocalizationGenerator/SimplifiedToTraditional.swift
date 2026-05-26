import Foundation

/// Simplified → Traditional Chinese conversion focused on Taiwan
/// (`zh-Hant-TW`) terminology used in the KeiPix UI.
///
/// We deliberately avoid pulling in OpenCC or any other runtime
/// dependency — KeiPix is a SwiftPM macOS app with no Python/Dart in
/// the build, and the canonical `zh-Hans` source covers ~560 unique
/// CJK characters. A vetted character map is small enough to keep in
/// source and easy to audit.
///
/// The conversion runs in two passes:
///
/// 1. `wordOverrides` rewrites Taiwan-specific terminology that would
///    otherwise produce technically-correct-but-non-native results
///    (e.g. simplified `默认` → `預設` in Taiwan rather than `默認`).
///    Overrides are applied to the simplified source before character
///    mapping so the keys read naturally.
/// 2. `characterMap` converts the remaining characters one-by-one.
///    Anything not in the table passes through unchanged, which is
///    the right behaviour for digits, punctuation, ASCII, emoji, and
///    the many CJK characters that are identical in both scripts.
enum SimplifiedToTraditional {
    /// Convert a simplified-Chinese string to traditional Chinese
    /// (Taiwan terminology). Format specifiers like `%@`, `%d`, and
    /// the non-breaking dot `·` are passed through untouched because
    /// they're plain ASCII / punctuation.
    static func convert(_ source: String) -> String {
        var working = source
        for (simplified, traditional) in wordOverrides {
            working = working.replacingOccurrences(of: simplified, with: traditional)
        }
        var output = String()
        output.reserveCapacity(working.count)
        for character in working {
            if let mapped = characterMap[character] {
                output.append(mapped)
            } else {
                output.append(character)
            }
        }
        return output
    }

    // MARK: - Word-level overrides
    //
    // Order matters: longer phrases first, so a multi-character
    // Taiwan-specific term wins over its constituent characters. Only
    // include phrases that the character map alone would miss; pure
    // S→T character substitutions belong in `characterMap`.
    static let wordOverrides: [(String, String)] = [
        // ─── Pixiv Web (zh-tw) terminology ──────────────────────────
        // Pixiv Taiwan uses these forms consistently across the web
        // app. They override the otherwise-correct mainland forms
        // before single-character mapping runs.
        ("作品", "作品"),                          // identical, kept for clarity
        ("插画", "插畫"),                          // illustration
        ("漫画", "漫畫"),                          // manga
        ("动图", "動圖"),                          // ugoira on Pixiv-TW
        ("动画", "動畫"),                          // animation
        ("画廊", "畫廊"),                          // gallery
        ("画", "畫"),                              // drawing/painting
        ("发现", "發現"),                          // discover/explore
        ("发表", "發表"),                          // publish
        ("发送", "傳送"),                          // send
        ("发布", "發佈"),                          // publish/release
        // Search & filters
        ("搜索", "搜尋"),                          // search (Taiwan: 搜尋, not 搜索)
        ("筛选", "篩選"),                          // filter
        ("过滤", "過濾"),                          // filter (verb)
        ("匹配", "符合"),                          // match (Taiwan: 符合 in UI)
        ("精确", "精確"),                          // exact
        ("关键词", "關鍵字"),                      // keyword (Taiwan: 關鍵字)
        ("热门", "熱門"),                          // trending/hot — kept
        // Bookmarks / follow / mute / report
        ("收藏", "收藏"),                          // bookmark — same form
        ("收藏夹", "收藏夾"),                      // bookmarks folder
        ("关注", "追蹤"),                          // follow (Taiwan: 追蹤, NOT 關注)
        ("取消关注", "取消追蹤"),                  // unfollow
        ("粉丝", "粉絲"),                          // followers
        ("屏蔽", "封鎖"),                          // block/mute (Taiwan UI)
        ("封禁", "封鎖"),                          // ban
        ("举报", "檢舉"),                          // report (Taiwan: 檢舉, not 舉報)
        ("反馈", "意見回饋"),                      // feedback (Taiwan)
        ("反馈对象", "回饋對象"),
        ("举报原因", "檢舉原因"),
        // Comments
        ("评论", "留言"),                          // comment (Taiwan: 留言, not 評論)
        ("评价", "評價"),                          // rating/eval
        ("回复", "回覆"),                          // reply (Taiwan: 回覆)
        ("点赞", "按讚"),                          // like (Taiwan: 按讚)
        // Account / settings
        ("设置", "設定"),                          // settings (Taiwan: 設定)
        ("账号", "帳號"),
        ("帐号", "帳號"),
        ("账户", "帳戶"),
        ("帐户", "帳戶"),
        ("登录", "登入"),                          // login
        ("退出登录", "登出"),                      // logout
        ("注销", "登出"),
        ("注册", "註冊"),                          // register
        ("个人资料", "個人資料"),                  // profile
        ("用户名", "使用者名稱"),                  // username
        ("用户", "使用者"),                        // user
        ("密码", "密碼"),                          // password
        ("默认", "預設"),                          // default (Taiwan: 預設)
        ("自定义", "自訂"),                        // custom (Taiwan: 自訂)
        ("公开", "公開"),                          // public
        ("私密", "私人"),                          // private (Taiwan: 私人)
        // Files / cache / network
        ("文件夹", "資料夾"),
        ("文件", "檔案"),
        ("缓存", "快取"),
        ("数据", "資料"),
        ("数据库", "資料庫"),
        ("信息", "資訊"),
        ("视频", "影片"),
        ("视图", "視圖"),                          // explicit, kept consistent
        ("软件", "軟體"),
        ("硬件", "硬體"),
        ("网络", "網路"),
        ("网页", "網頁"),
        ("网站", "網站"),
        ("链接", "連結"),                          // link
        ("链", "鏈"),
        // Common verbs
        ("加载", "載入"),                          // load
        ("下载", "下載"),                          // download — same
        ("上传", "上傳"),                          // upload
        ("打开", "開啟"),                          // open
        ("关闭", "關閉"),                          // close
        ("打印", "列印"),
        ("剪贴板", "剪貼簿"),
        ("剪切板", "剪貼簿"),
        ("复制", "複製"),
        ("黏贴", "貼上"),
        ("粘贴", "貼上"),
        ("撤销", "復原"),                          // undo (Taiwan)
        ("退出", "結束"),                          // quit (Taiwan: 結束)
        // Domain-specific
        ("标签", "標籤"),                          // tag (Taiwan: 標籤, NOT 標簽)
        ("热门标签", "熱門標籤"),
        ("年龄限制", "年齡限制"),
        ("内容分级", "內容分級"),
        ("内容标识", "內容標示"),
        ("成人内容", "成人內容"),
        ("敏感内容", "敏感內容"),
        ("快捷键", "快速鍵"),
        ("分辨率", "解析度"),
        ("界面", "介面"),
        ("内核", "核心"),
        ("项目", "項目"),
        ("视图", "視圖"),
        ("应用", "應用"),
        ("作品系列", "作品系列"),
        ("系列", "系列"),
        ("追更", "追蹤"),                          // watchlist
        ("追更系列", "追蹤系列"),
        ("漫画追更", "漫畫追蹤"),
        ("收藏数", "收藏數"),
        ("浏览数", "瀏覽數"),
        ("浏览历史", "瀏覽紀錄"),                  // history (Taiwan: 紀錄)
        ("历史", "紀錄"),                          // history alone — Taiwan UI prefers 紀錄
        ("文章", "文章"),
        ("登记", "登記")
    ]

    // MARK: - Character map
    //
    // Covers every CJK character used by the canonical `zh-Hans`
    // source. Characters identical in both scripts are intentionally
    // omitted so the lookup misses fall through to the source
    // character. Keep the entries sorted alphabetically (by simplified
    // form) so future edits show as small, reviewable diffs.
    static let characterMap: [Character: Character] = [
        "与": "與",
        "专": "專",
        "业": "業",
        "丝": "絲",
        "丢": "丟",
        "两": "兩",
        "个": "個",
        "为": "為",
        "举": "舉",
        "义": "義",
        "书": "書",
        "于": "於",
        "产": "產",
        "仅": "僅",
        "从": "從",
        "优": "優",
        "会": "會",
        "传": "傳",
        "体": "體",
        "侧": "側",
        "储": "儲",
        "关": "關",
        "内": "內",
        "写": "寫",
        "减": "減",
        "凑": "湊",
        "创": "創",
        "删": "刪",
        "动": "動",
        "势": "勢",
        "区": "區",
        "单": "單",
        "占": "佔",
        "历": "歷",
        "参": "參",
        "双": "雙",
        "发": "發",
        "变": "變",
        "叠": "疊",
        "号": "號",
        "后": "後",
        "启": "啟",
        "员": "員",
        "响": "響",
        "围": "圍",
        "图": "圖",
        "坏": "壞",
        "块": "塊",
        "处": "處",
        "备": "備",
        "复": "複",
        "头": "頭",
        "夹": "夾",
        "实": "實",
        "审": "審",
        "宽": "寬",
        "对": "對",
        "导": "導",
        "将": "將",
        "尽": "盡",
        "带": "帶",
        "帧": "幀",
        "并": "並",
        "库": "庫",
        "应": "應",
        "废": "廢",
        "开": "開",
        "弃": "棄",
        "归": "歸",
        "当": "當",
        "录": "錄",
        "径": "徑",
        "态": "態",
        "总": "總",
        "户": "戶",
        "执": "執",
        "扫": "掃",
        "扰": "擾",
        "护": "護",
        "报": "報",
        "择": "擇",
        "换": "換",
        "据": "據",
        "无": "無",
        "旧": "舊",
        "时": "時",
        "显": "顯",
        "暂": "暫",
        "权": "權",
        "来": "來",
        "构": "構",
        "标": "標",
        "栏": "欄",
        "样": "樣",
        "桥": "橋",
        "检": "檢",
        "横": "橫",
        "欢": "歡",
        "残": "殘",
        "测": "測",
        "浏": "瀏",
        "游": "遊",
        "滤": "濾",
        "点": "點",
        "烟": "煙",
        "热": "熱",
        "状": "狀",
        "现": "現",
        "画": "畫",
        "码": "碼",
        "确": "確",
        "离": "離",
        "稳": "穩",
        "签": "簽",
        "简": "簡",
        "篓": "簍",
        "类": "類",
        "粘": "黏",
        "紧": "緊",
        "级": "級",
        "纳": "納",
        "纸": "紙",
        "线": "線",
        "组": "組",
        "织": "織",
        "经": "經",
        "结": "結",
        "给": "給",
        "络": "絡",
        "统": "統",
        "继": "繼",
        "绪": "緒",
        "续": "續",
        "缓": "緩",
        "编": "編",
        "缩": "縮",
        "网": "網",
        "范": "範",
        "荐": "薦",
        "获": "獲",
        "补": "補",
        "见": "見",
        "观": "觀",
        "视": "視",
        "览": "覽",
        "觉": "覺",
        "触": "觸",
        "计": "計",
        "认": "認",
        "让": "讓",
        "记": "記",
        "论": "論",
        "设": "設",
        "访": "訪",
        "证": "證",
        "评": "評",
        "识": "識",
        "诊": "診",
        "词": "詞",
        "译": "譯",
        "试": "試",
        "话": "話",
        "详": "詳",
        "语": "語",
        "误": "誤",
        "说": "說",
        "请": "請",
        "读": "讀",
        "调": "調",
        "败": "敗",
        "账": "帳",
        "贴": "貼",
        "资": "資",
        "踪": "蹤",
        "转": "轉",
        "轴": "軸",
        "载": "載",
        "辑": "輯",
        "输": "輸",
        "边": "邊",
        "达": "達",
        "过": "過",
        "运": "運",
        "返": "返",
        "还": "還",
        "这": "這",
        "进": "進",
        "远": "遠",
        "连": "連",
        "适": "適",
        "选": "選",
        "通": "通",
        "遮": "遮",
        "里": "裡",
        "链": "鏈",
        "销": "銷",
        "错": "錯",
        "键": "鍵",
        "长": "長",
        "门": "門",
        "闭": "閉",
        "问": "問",
        "间": "間",
        "阅": "閱",
        "队": "隊",
        "阵": "陣",
        "险": "險",
        "隐": "隱",
        "页": "頁",
        "顶": "頂",
        "项": "項",
        "顺": "順",
        "须": "須",
        "预": "預",
        "题": "題",
        "馈": "饋",
        "验": "驗",
        "骚": "騷",
        "龄": "齡"
    ]
}
