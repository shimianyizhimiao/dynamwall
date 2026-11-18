# 動態壁紙 · DynWall

一個原生的 macOS 動態壁紙程式：**影片、GIF、圖片、或自己寫的 HTML/CSS/JS 都可以當桌面壁紙**，
畫在**系統桌布之上、桌面圖示之下**（桌面圖示、右鍵選單、拖檔案、Mission Control 全部照常），
附一個圖形化壁紙庫。

A native animated wallpaper engine for macOS — video, GIF, images, or your own HTML canvas,
drawn above the system wallpaper and below the desktop icons. Swift + AppKit + AVFoundation + WebKit,
no third-party dependencies.

```
┌──────────────────────────────────────────┬──────────────────┐
│  全部 │ 內建 │ 影片 │ 圖片 │ 我的 HTML   ＋加入壁紙 │
├──────────────────────────────────────────┼──────────────────┤
│  ┌───────┐ ┌───────┐ ┌───────┐          │  即時預覽         │
│  │ 極光   │ │ 星海  │ │ 影片   │          │  （會動的預覽）   │
│  │[使用中]│ │      │ │12 秒  │          │                  │
│  └───────┘ └───────┘ └───────┘          │  [套用到桌面]     │
│  ┌───────┐ ┌───────┐                    │  ───────────────  │
│  │ 數位雨 │ │ 賽博格 │                    │  播放中 ✓ 靜音 ✓   │
│  └───────┘ └───────┘                    │  速度 / 暗化 滑桿  │
└──────────────────────────────────────────┴──────────────────┘
```

## 功能

- **四種來源**：影片（`AVPlayerLooper` 無縫循環）、圖片、GIF、自己寫的 HTML/CSS/JS
- **HTML 熱重載**：存檔即時更新畫面（FSEvents 監看，就地修改與另存改名都吃得到）
- **圖形化壁紙庫**：縮圖格狀 + 即時預覽 + 設定面板，可直接把檔案拖進視窗加入
- **選單列控制**：換壁紙、暫停、暗化、縮放、速度、開機自動啟動
- **關掉 App 桌面不變**：套用／結束時把「當下這一格」存成靜態圖並設成系統桌布
- **可打包**：把某支影片包成獨立、雙擊即用的 `.app`，再做成一張拖曳安裝的 `.dmg`
- **內建 4 款**示範壁紙（極光／星海／賽博格柵／數位雨），純 canvas 手寫

## 系統需求

- macOS 13 以上（Apple Silicon / Intel）
- Xcode Command Line Tools：`xcode-select --install`
- 選用：Google Chrome —— `build.sh` 用它無頭渲染內建壁紙的縮圖與高解析海報；沒有也能編，只是少縮圖

## 建置

```bash
git clone https://github.com/<you>/dynwall.git
cd dynwall
./build.sh            # 編譯到 build/動態壁紙.app
./build.sh install    # 另外安裝到 ~/Applications/動態壁紙.app
```

只用 macOS 內建的 `swiftc` 與 `clang`，不需要 Xcode 專案、不需要任何套件管理器。ad-hoc 簽章即可跑。

## 使用

- 雙擊 `~/Applications/動態壁紙.app` → 開啟壁紙庫
- 點縮圖選取 → 按「**套用到桌面**」
- 「**＋加入壁紙**」選影片／圖片／GIF／HTML 資料夾；也可以直接拖進視窗（會複製一份進壁紙庫，原檔不動）
- 右側面板：播放速度、暗化、縮放方式、靜音、滑鼠互動、開機自動啟動、「關掉 App 後桌面保留同一張」
- 選單列圖示（滑鼠移到螢幕最上面才會出現）→ 快速換壁紙／暫停／開啟壁紙庫（⌘L）

### 命令列

```bash
DynWall --set video "/path/to/clip.mp4"
DynWall --set builtin starfield
DynWall --autostart on          # 開機自動啟動（寫 LaunchAgent）
DynWall --copy-templates        # 複製可編輯的 HTML 範本
DynWall --login                 # 登入時用：只在背景跑壁紙，不開介面
DynWall --cycle-test 9          # 壓力測試：每 9 秒自動切換來源
DYN_DEBUG=1 DynWall             # 每 3 秒輸出狀態（fps、影片時間、視窗圖層）
DynWall --dump-menu             # 印出選單結構
```

## 自訂 HTML 壁紙

```bash
DynWall --copy-templates
```

範本會出現在 `~/Library/Application Support/動態壁紙/wallpapers/`（例如「極光（可編輯）」）。
每個範本最上面都有一段中文註解的 `CONFIG`，改數字就好：

```js
const CONFIG = {
  動畫速度: 0.7,
  光帶數量: 3,
  顏色:     ['#22d3ee', '#34d399', '#a78bfa'],
  星星數量: 160
};
```

**存檔，桌面立刻更新**，不必重開 App。Canvas、CSS 動畫、Three.js、shader 都可以，只要不依賴網路。

## 原理（想改的人看這裡）

| 問題 | 做法 |
|---|---|
| 壁紙要蓋在桌布上、又在圖示下 | `NSWindow.level = -2147483604`（系統桌布 `-2147483624`、桌面圖示 `-2147483603` 之間）＋ `collectionBehavior = [.canJoinAllSpaces, .stationary]`、`ignoresMouseEvents` |
| 影片無縫循環 | `AVQueuePlayer` + `AVPlayerLooper`（比手動 seek 不會閃） |
| HTML 熱重載 | FSEvents（`DispatchSourceFileSystemObject` 對就地改檔不可靠） |
| 關掉 App 桌布不變 | 套用／結束時產生靜態海報 → `NSWorkspace.setDesktopImageURL` |
| 睡眠喚醒後要恢復 | 不依賴系統通知：每 3 秒自查 `CGDisplayIsAsleep` 與 `CGSSessionScreenIsLocked` |
| 離屏 WebView 被節流 | 關掉 `pageVisibilityBasedProcessSuppressionEnabled`（WebKit 私有偏好） |

檔案位置：

| 內容 | 路徑 |
|---|---|
| 設定 | `~/Library/Application Support/動態壁紙/config.json` |
| 壁紙庫（加入的檔案） | `~/Library/Application Support/動態壁紙/library/` |
| 自訂 HTML 壁紙 | `~/Library/Application Support/動態壁紙/wallpapers/` |
| 海報快取／縮圖 | `~/Library/Caches/動態壁紙/` |
| 日誌 | `~/Library/Logs/動態壁紙.log` |

## 打包成獨立 App / DMG

```bash
# 把一支影片（或圖片）包成獨立 App：媒體放在 App 內部，對方不必有原檔
./build-standalone.sh "我的壁紙" "mywall" "/path/to/clip.mp4" "我的壁紙"

# 做成拖曳安裝的 DMG（背景說明圖、圖示位置、使用說明都排好）
./build-dmg.sh "$HOME/Applications/我的壁紙.app" "我的壁紙"
```

獨立 App 有自己的 bundle id（`com.dynwall.<後綴>`）與資料夾（`~/Library/Application Support/動態壁紙-<後綴>/`），
開機啟動也是自己的 LaunchAgent，不會跟主程式打架。

> 沒有開發者簽章，別人第一次開啟要 **右鍵 →「打開」→ 再按一次「打開」**。

## 疑難排解

| 症狀 | 原因 / 解法 |
|---|---|
| 換了壁紙，桌面卻是別張 | 有**第二支**壁紙 App 在跑：同一個視窗圖層、後開的在上面。`pgrep -fl DynWall` 只留一支，`ls ~/Library/LaunchAgents/` 也只留一個 |
| 壁紙狂頻閃 | 「重建迴圈」：`didChangeScreenParameters` → 重建內容 → 寫桌布 → 再觸發。日誌連續出現 `APPLY` 就是它 |
| 蓋上蓋子再打開就不動 | 系統喚醒／解鎖通知常沒送到背景程式；程式已改成每 3 秒自查實際狀態 |
| 指定桌面上的影片讀不到 | 非沙盒 App 由 Finder 啟動時沒有「桌面／文件／下載」權限（TCC）。用「加入壁紙」複製進 App 資料夾 |
| 網頁壁紙停住 | 頁面若自己判斷 `document.hidden` 會停（壁紙視窗被遮住時 WebKit 會回報 hidden），把那段拿掉 |
| 全螢幕 App 蓋住壁紙 | 正常 —— macOS 的全螢幕是另一個桌面 |

## 已知限制

- 用到 WebKit 私有偏好 `pageVisibilityBasedProcessSuppressionEnabled`，**不適合上架 App Store**；自用或自行簽章發佈沒問題。
- 多螢幕有基本支援，但未在雙螢幕上充分測試。
- 4K 60fps 影片壁紙約 5–10% CPU（硬體解碼），筆電建議用 1080p。

## 授權

MIT，見 [LICENSE](LICENSE)。

內建壁紙（`resources/wallpapers/*`）與 App 圖示都是本專案自製。
打包工具不會也不能替你取得影片素材的授權 —— 包自己的影片時請自行確認權利。
