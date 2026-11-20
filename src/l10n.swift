import Foundation

// MARK: - 語言

enum AppLang: String, CaseIterable, Identifiable {
    case zhHant = "zh-Hant"
    case zhHans = "zh-Hans"
    case en = "en"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .zhHant: return "繁體中文"
        case .zhHans: return "简体中文"
        case .en: return "English"
        }
    }
}

enum L10n {
    static var current: AppLang = .zhHant

    /// 繁中字串 → 該語言的翻譯；沒翻譯就原樣回傳
    static func t(_ zh: String) -> String {
        switch current {
        case .zhHant: return zh
        case .zhHans: return hans[zh] ?? zh
        case .en: return en[zh] ?? zh
        }
    }

    // MARK: 英文

    static let en: [String: String] = [
        // 分頁 / 通用
        "首頁": "Home", "靜態": "Stills", "動態": "Motion", "我的": "Mine",
        "一般": "General", "播放": "Playback", "進階": "Advanced", "關於": "About",
        "完成": "Done", "啟動": "Startup", "畫面": "Display", "導覽": "Tour",
        "調整": "Adjust", "快取": "Cache", "診斷": "Diagnostics", "壁紙庫": "Library",

        // 設定
        "登入時自動啟動": "Launch at login",
        "關掉 App 後保留桌面": "Keep desktop wallpaper after quitting",
        "鎖定畫面顯示當下畫面": "Show current frame on lock screen",
        "填滿畫面（裁切邊緣）": "Fill screen (crop edges)",
        "完整顯示（可能留黑邊）": "Fit (may show black bars)",
        "延展變形": "Stretch",
        "「填滿」適合影片與照片；「完整顯示」適合有文字或介面的自訂 HTML。":
            "\"Fill\" suits videos and photos; \"Fit\" suits custom HTML with text or UI.",
        "重播使用導覽": "Replay the tour",
        "導覽只會自動出現一次；之後想看就從這裡重播。":
            "The tour only appears once automatically — replay it here.",
        "播放中": "Playing", "靜音": "Mute", "允許滑鼠互動": "Allow mouse interaction",
        "視差（景深）": "Parallax (depth)",
        "壁紙會先放大一點，所以位移時不會露出黑邊；影片、圖片、HTML 都適用。":
            "The wallpaper is scaled up slightly so panning never reveals black edges. Works with video, images and HTML.",
        "定時自動換壁紙": "Rotate wallpaper automatically",
        "5 分鐘": "5 min", "15 分鐘": "15 min", "30 分鐘": "30 min",
        "1 小時": "1 hour", "3 小時": "3 hours",
        "全螢幕時暫停": "Pause in full screen",
        "自動化（省電）": "Automation (power saving)",
        "打開桌布設定": "Open Wallpaper settings",
        "還原系統桌布設定": "Restore system wallpaper settings",
        "鎖定畫面（系統限制）": "Lock screen (system limitation)",
        "開啟壁紙資料夾": "Open wallpaper folder",
        "清除快取": "Clear cache",
        "清掉不會影響壁紙本身，下次開啟會重新產生縮圖。":
            "This does not touch your wallpapers; thumbnails are rebuilt next launch.",
        "開啟日誌資料夾": "Open log folder",
        "回報問題時把診斷資訊貼給我，比猜快很多。":
            "Paste the diagnostics when reporting a bug — much faster than guessing.",
        "動態壁紙 DynWall": "DynWall",
        "macOS 的鎖定畫面由系統進程繪製，第三方 App 改不到 —— 我們試過直接寫系統桌布資料庫（Index.plist）與冒充 Apple 的動態桌布，系統會在幾秒內改回它記憶體裡的設定，所以這個功能拿掉了，不再留半套。":
            "macOS draws the lock screen in a system process; third-party apps cannot change it. We tried writing the wallpaper store (Index.plist) and impersonating Apple's aerials — the system reverts within seconds. The feature was removed rather than shipped half-working.",
        "要讓鎖定畫面跟桌面一樣，只能在「系統設定 → 桌布」那裡設定（可選同一張給桌面與鎖定畫面）。下方的桌布海報功能仍然有效：桌面上會是壁紙的當下畫面。":
            "To make the lock screen match your desktop, set it in System Settings → Wallpaper. Desktop posters still work: your desktop shows the current frame.",

        // 主視窗
        "使用中": "In use", "設為桌布": "Set as wallpaper", "套用到桌面": "Apply to desktop",
        "在 Finder 顯示": "Reveal in Finder", "編輯 HTML…": "Edit HTML…",
        "刪除（移到垃圾桶）": "Delete (move to Trash)",
        "加入檔案…（影片 / 圖片 / GIF / HTML）": "Add files… (video / image / GIF / HTML)",
        "匯入 Wallpaper Engine 網頁壁紙…": "Import Wallpaper Engine web wallpaper…",
        "加入壁紙": "Add wallpaper", "猜你喜歡": "Surprise me",
        "隨機挑一張套用": "Pick a random wallpaper", "使用導覽": "Show the tour",
        "設定（⌘,）": "Settings (⌘,)", "精選": "Featured", "搜尋…": "Search…",
        "隨機挑一張": "Pick one at random", "重新掃描": "Rescan", "熱門:": "Popular:",
        "最新壁紙": "Latest", "內建動態壁紙": "Built-in", "我的收藏": "My wallpapers",
        "還沒有最愛": "No favourites yet",
        "在卡片右下角按 ♡，就會出現在這裡": "Tap ♡ on a card and it shows up here",
        "找不到符合的壁紙": "No wallpapers found",
        "換個關鍵字或分類試試": "Try another keyword or category",

        // 補：設定說明
        "開機後在背景直接開始播壁紙，不開視窗。": "Starts playing in the background at login without opening a window.",
        "結束 App 時把當下畫面留在桌面。關掉的話，結束時會還原你原本的桌布。": "Leaves the current frame on the desktop after quitting. If off, your original wallpaper is restored.",
        "打密碼那個畫面系統只認「桌布圖」，所以一定要有一張靜態圖；關掉就會看到你原本的桌布。": "The lock screen only reads a still wallpaper image, so a static frame is required; turn this off to keep your original wallpaper.",
        "只有自訂 HTML 壁紙有作用：滑鼠點擊、滾動會傳給網頁。": "Only for custom HTML wallpapers: clicks and scrolling are forwarded to the page.",
        "影片壁紙的聲音；預設靜音。": "Audio for video wallpapers; muted by default.",
        "關掉就暫停壁紙（影片停在當下這一格）。": "Turn off to pause the wallpaper (video stays on the current frame).",
        "滑鼠移動時，壁紙往同方向微微位移，看起來有前後層次。預設關閉。": "The wallpaper shifts slightly with the mouse for a sense of depth. Off by default.",
        "時間到就換成壁紙庫裡的下一張，一直循環。": "Switches to the next wallpaper in your library on schedule, looping.",
        "看影片、玩遊戲開全螢幕時把壁紙停住，省電也省顯卡。": "Pauses the wallpaper when an app is full screen — saves battery and GPU.",
        "換語言後會自動重開 App（壁紙會繼續播放）。": "The app restarts after switching language (the wallpaper keeps playing).",
        "個人專案，可能還有一些 BUG；若你是從付費管道拿到，那不是作者發布的版本。": "A personal project — expect some bugs. If you paid for it, this is not the author's build.",
        "語言 Language": "Language", "語言": "Language",
        "開啟壁紙庫資料夾": "Open wallpaper folder",

        "預設畫面縮放": "Scaling", "間隔": "Interval", "播放速度": "Speed",
        "暗化": "Dim", "位移幅度": "Offset", "縮圖與海報快取": "Thumbnail & poster cache",
        "版本": "Version", "影片／圖片／GIF／自訂 HTML": "native macOS · video / image / GIF / custom HTML",

        // 補：主視窗細節
        "HTML 動畫": "HTML animation", "影片・%.0f MB": "Video · %.0f MB",
        "我的 HTML": "My HTML", "圖片": "Image", "影片": "Video", "秒": "sec",
        "早安": "Good morning", "午安": "Good afternoon", "晚安": "Good evening",
        "探索壁紙庫": "Explore wallpapers", "靜態壁紙": "Still wallpapers",
        "動態壁紙": "Motion wallpapers", "我的最愛": "Favourites",
        "還沒有壁紙": "No wallpapers yet", "張": "items", "篩選結果": "Filtered",
        "精選動態壁紙": "Featured motion", "我的壁紙": "My wallpapers",
        "內建動態": "Built-in",
        "星海": "Star Sea", "極光": "Aurora", "星雲": "Nebula", "地球": "Earth",
        "星系": "Galaxy", "月球": "Moon", "火星": "Mars", "海洋": "Ocean",
        "城市夜景": "City at night", "喜馬拉雅": "Himalaya", "木星": "Jupiter",
        "設定": "Settings",

        // 首次啟動
        "選擇語言": "Choose your language",
        "之後可以在「設定 → 一般」更改。": "You can change this later in Settings → General.",
        "繼續": "Continue",
    ]

    // MARK: 簡中

    static let hans: [String: String] = [
        "首頁": "首页", "靜態": "静态", "動態": "动态", "我的": "我的",
        "一般": "一般", "播放": "播放", "進階": "进阶", "關於": "关于",
        "完成": "完成", "啟動": "启动", "畫面": "画面", "導覽": "导览",
        "調整": "调整", "快取": "缓存", "診斷": "诊断", "壁紙庫": "壁纸库",

        "登入時自動啟動": "登录时自动启动",
        "關掉 App 後保留桌面": "关掉 App 后保留桌面",
        "鎖定畫面顯示當下畫面": "锁定画面显示当下画面",
        "填滿畫面（裁切邊緣）": "填满画面（裁切边缘）",
        "完整顯示（可能留黑邊）": "完整显示（可能留黑边）",
        "延展變形": "延展变形",
        "「填滿」適合影片與照片；「完整顯示」適合有文字或介面的自訂 HTML。":
            "“填满”适合视频与照片；“完整显示”适合有文字或界面的自定义 HTML。",
        "重播使用導覽": "重播使用导览",
        "導覽只會自動出現一次；之後想看就從這裡重播。": "导览只会自动出现一次；之后想看就从这里重播。",
        "播放中": "播放中", "靜音": "静音", "允許滑鼠互動": "允许鼠标互动",
        "視差（景深）": "视差（景深）",
        "壁紙會先放大一點，所以位移時不會露出黑邊；影片、圖片、HTML 都適用。":
            "壁纸会先放大一点，所以位移时不会露出黑边；视频、图片、HTML 都适用。",
        "定時自動換壁紙": "定时自动换壁纸",
        "5 分鐘": "5 分钟", "15 分鐘": "15 分钟", "30 分鐘": "30 分钟",
        "1 小時": "1 小时", "3 小時": "3 小时",
        "全螢幕時暫停": "全屏时暂停",
        "自動化（省電）": "自动化（省电）",
        "打開桌布設定": "打开桌面壁纸设置",
        "還原系統桌布設定": "还原系统壁纸设置",
        "鎖定畫面（系統限制）": "锁定画面（系统限制）",
        "開啟壁紙資料夾": "打开壁纸文件夹",
        "清除快取": "清除缓存",
        "清掉不會影響壁紙本身，下次開啟會重新產生縮圖。": "清掉不会影响壁纸本身，下次打开会重新生成缩略图。",
        "開啟日誌資料夾": "打开日志文件夹",
        "回報問題時把診斷資訊貼給我，比猜快很多。": "回报问题时把诊断信息贴给我，比猜快很多。",
        "動態壁紙 DynWall": "动态壁纸 DynWall",
        "macOS 的鎖定畫面由系統進程繪製，第三方 App 改不到 —— 我們試過直接寫系統桌布資料庫（Index.plist）與冒充 Apple 的動態桌布，系統會在幾秒內改回它記憶體裡的設定，所以這個功能拿掉了，不再留半套。":
            "macOS 的锁定画面由系统进程绘制，第三方 App 改不到 —— 我们试过直接写系统壁纸数据库（Index.plist）与冒充 Apple 的动态壁纸，系统会在几秒内改回它内存里的设置，所以这个功能拿掉了，不再留半套。",
        "要讓鎖定畫面跟桌面一樣，只能在「系統設定 → 桌布」那裡設定（可選同一張給桌面與鎖定畫面）。下方的桌布海報功能仍然有效：桌面上會是壁紙的當下畫面。":
            "要让锁定画面跟桌面一样，只能在“系统设置 → 壁纸”那里设置（可选同一张给桌面与锁定画面）。下方的桌面海报功能仍然有效：桌面上会是壁纸的当下画面。",

        "使用中": "使用中", "設為桌布": "设为壁纸", "套用到桌面": "套用到桌面",
        "在 Finder 顯示": "在 Finder 显示", "編輯 HTML…": "编辑 HTML…",
        "刪除（移到垃圾桶）": "删除（移到废纸篓）",
        "加入檔案…（影片 / 圖片 / GIF / HTML）": "加入文件…（视频 / 图片 / GIF / HTML）",
        "匯入 Wallpaper Engine 網頁壁紙…": "导入 Wallpaper Engine 网页壁纸…",
        "加入壁紙": "加入壁纸", "猜你喜歡": "猜你喜欢",
        "隨機挑一張套用": "随机挑一张套用", "使用導覽": "使用导览",
        "設定（⌘,）": "设置（⌘,）", "精選": "精选", "搜尋…": "搜索…",
        "隨機挑一張": "随机挑一张", "重新掃描": "重新扫描", "熱門:": "热门:",
        "最新壁紙": "最新壁纸", "內建動態壁紙": "内置动态壁纸", "我的收藏": "我的收藏",
        "還沒有最愛": "还没有收藏",
        "在卡片右下角按 ♡，就會出現在這裡": "在卡片右下角按 ♡，就会出现在这里",
        "找不到符合的壁紙": "找不到符合条件的壁纸",
        "換個關鍵字或分類試試": "换个关键词或分类试试",

        // 補：設定說明
        "開機後在背景直接開始播壁紙，不開視窗。": "开机后在后台直接开始播壁纸，不开窗口。",
        "結束 App 時把當下畫面留在桌面。關掉的話，結束時會還原你原本的桌布。": "结束 App 时把当下画面留在桌面。关掉的话，结束时会还原你原本的壁纸。",
        "打密碼那個畫面系統只認「桌布圖」，所以一定要有一張靜態圖；關掉就會看到你原本的桌布。": "输密码那个画面系统只认“壁纸图”，所以一定要有一张静态图；关掉就会看到你原本的壁纸。",
        "只有自訂 HTML 壁紙有作用：滑鼠點擊、滾動會傳給網頁。": "只有自定义 HTML 壁纸有作用：鼠标点击、滚动会传给网页。",
        "影片壁紙的聲音；預設靜音。": "视频壁纸的声音；默认静音。",
        "關掉就暫停壁紙（影片停在當下這一格）。": "关掉就暂停壁纸（视频停在当下这一格）。",
        "滑鼠移動時，壁紙往同方向微微位移，看起來有前後層次。預設關閉。": "鼠标移动时，壁纸往同方向微微位移，看起来有前后层次。默认关闭。",
        "時間到就換成壁紙庫裡的下一張，一直循環。": "时间到就换成壁纸库里的下一张，一直循环。",
        "看影片、玩遊戲開全螢幕時把壁紙停住，省電也省顯卡。": "看视频、玩游戏开全屏时把壁纸停住，省电也省显卡。",
        "換語言後會自動重開 App（壁紙會繼續播放）。": "换语言后会自动重启 App（壁纸会继续播放）。",
        "個人專案，可能還有一些 BUG；若你是從付費管道拿到，那不是作者發布的版本。": "个人项目，可能还有一些 BUG；若你是从付费渠道拿到，那不是作者发布的版本。",
        "語言 Language": "语言 Language", "語言": "语言",
        "開啟壁紙庫資料夾": "打开壁纸文件夹",

        "預設畫面縮放": "默认画面缩放", "間隔": "间隔", "播放速度": "播放速度",
        "暗化": "暗化", "位移幅度": "位移幅度", "縮圖與海報快取": "缩略图与海报缓存",
        "版本": "版本", "影片／圖片／GIF／自訂 HTML": "macOS 原生・视频／图片／GIF／自定义 HTML",

        // 補：主視窗細節
        "HTML 動畫": "HTML 动画", "影片・%.0f MB": "视频・%.0f MB",
        "我的 HTML": "我的 HTML", "圖片": "图片", "影片": "视频", "秒": "秒",
        "早安": "早安", "午安": "午安", "晚安": "晚安",
        "探索壁紙庫": "探索壁纸库", "靜態壁紙": "静态壁纸",
        "動態壁紙": "动态壁纸", "我的最愛": "我的收藏",
        "還沒有壁紙": "还没有壁纸", "張": "张", "篩選結果": "筛选结果",
        "精選動態壁紙": "精选动态壁纸", "我的壁紙": "我的壁纸",
        "內建動態": "内置动态",
        "星海": "星海", "極光": "极光", "星雲": "星云", "地球": "地球",
        "星系": "星系", "月球": "月球", "火星": "火星", "海洋": "海洋",
        "城市夜景": "城市夜景", "喜馬拉雅": "喜马拉雅", "木星": "木星",
        "設定": "设置",

        "選擇語言": "选择语言",
        "之後可以在「設定 → 一般」更改。": "之后可以在“设置 → 一般”更改。",
        "繼續": "继续",
    ]
}

/// 短版呼叫
func T(_ zh: String) -> String { L10n.t(zh) }
