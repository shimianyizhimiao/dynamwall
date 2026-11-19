# 動態壁紙 · DynWall

**僅限 macOS** · macOS 13+ · Apple Silicon 與 Intel · Swift + AppKit · 無第三方依賴

> ⚠️ **個人專案，可能還有一些 BUG。** 只在 macOS 26.4 / Apple Silicon 實測過。
> 遇到問題請開 Issue，並附上你的 macOS 版本與 `~/Library/Logs/動態壁紙.log`。

[繁體中文](README.md) · [English](README.en.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md) · [Italiano](README.it.md)

🌐 **官網：<https://shimianyizhimiao.github.io/dynamwall/>** · 
📖 **完整使用說明（step-by-step）：[docs/使用說明.md](docs/使用說明.md)**

一個原生的 macOS 動態壁紙程式：**影片、GIF、圖片、或自己寫的 HTML/CSS/JS 都可以變成桌面壁紙**，
畫在**系統桌布之上、桌面圖示之下**（桌面圖示、右鍵選單、拖檔案、Mission Control 全部照常），
附一個圖形化壁紙庫。

A native animated wallpaper engine for macOS — video, GIF, images, or your own HTML canvas,
drawn above the system wallpaper and below the desktop icons. Swift + AppKit + AVFoundation + WebKit,
no third-party dependencies.

```
┌──────────────────────────────────────────────────────────────┐
│  全部 │ 內建 │ 影片 │ 圖片 │ 我的 HTML         🔍 排序  ＋  ⚙ │
├──────────────────────────────────────────────────────────────┤
│  ┌────────────────────────────────────────────────────────┐  │
│  │        大張即時預覽（影片真的在播、HTML 真的在跑）      │  │
│  │        ‹                                           ›    │  │
│  └────────────────────────────────────────────────────────┘  │
│  最新壁紙      ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ →         │
│               └────┘ └────┘ └────┘ └────┘ └────┘            │
│  精選動態壁紙  ┌────┐ ┌────┐ ┌────┐ →                        │
│  我的壁紙      ┌────┐ ┌────┐ ┌────┐ ┌────┐ →                 │
└──────────────────────────────────────────────────────────────┘
```
## 功能

- **四種來源**：影片（`AVPlayerLooper` 無縫循環）、圖片、GIF、自己寫的 HTML/CSS/JS
- **HTML 熱重載**：存檔即時更新畫面（FSEvents 監看，就地修改與另存改名都吃得到）
- **圖形化壁紙庫**：縮圖格狀 + 即時預覽 + 設定面板，可直接把檔案拖進視窗加入
- **選單列控制**：換壁紙、暫停、暗化、縮放、速度、開機自動啟動
- **關掉 App 桌面不變**：套用／結束時把「當下這一格」存成靜態圖並設成系統桌布
- **可打包**：把某支影片包成獨立、雙擊即用的 `.app`，再做成一張拖曳安裝的 `.dmg`
- **探索頁**：首頁／靜態／動態／我的 分頁、熱門關鍵字、分類晶片（全部・動態・靜態・NASA・HTML・最愛）、4 欄卡片格（解析度徽章＋愛心收藏）、「猜你喜歡」隨機套用
- **首頁就是預覽**：上方大張 hero 會**真的播放**（影片用 `AVPlayer`、HTML/GIF 用 `WKWebView`），每 6 秒自動換下一張
- **第一次開就有導覽**：五步帶你走完「加入壁紙 → 選一張 → 調設定 → 套用」
- **內建 4 款**示範壁紙（極光／星海／賽博格柵／數位雨），純 canvas 手寫
- **內建精選 9 張 NASA 壁紙**（星雲／地球／極光／星系／月球／火星／海洋／城市夜景／喜馬拉雅，公有領域）
- **視差（景深）**：滑鼠移動時壁紙跟著位移 0–30px，內容先放大所以不會露邊（預設關閉）
- **定時輪換**：每 5 分鐘～3 小時自動換壁紙庫裡的下一張
- **全螢幕／休眠／鎖定自動暫停**：看片、玩遊戲、蓋上螢幕都不浪費電，醒來自己接回去
- **鎖定畫面（系統限制）**：macOS 的鎖定畫面由系統進程繪製，第三方 App 無法更改（實測直接改系統桌布資料庫或冒充 Apple 動態桌布，系統幾秒內就改回）。要在鎖定畫面看到同一張，只能到「系統設定 → 桌布」設定一次；App 的設定頁有一顆按鈕直接幫你打開
- **桌布海報**：桌面上會是壁紙的「當下畫面」（截圖寫成桌布圖），關掉 App 可選擇保留或還原
- **匯入 Wallpaper Engine 網頁壁紙**：選 `project.json`，整個專案複製進壁紙庫（屬性面板與音訊視覺化不支援）
- **原生開關自己畫**：設定頁的開關是 SwiftUI 繪製，不會出現「白色圓點偶爾不見」

## 內建精選壁紙（NASA・公有領域）

App 內附 9 張 4K 靜態壁紙，全部來自 **NASA Image and Video Library**，依
[NASA Media Usage Guidelines](https://www.nasa.gov/nasa-brand-center/images-and-media/) 屬**公有領域**，
可自由使用與再散布（NASA 不因此背書本專案）。逐張出處見
`resources/wallpapers/static/CREDITS.md`；要重新抓或擴充：

```bash
python3 tools/fetch_wallpapers.py 12     # 抓 12 張（每個主題一張，保持多樣）
```

> 只抓 NASA：它是明確的公有領域來源。Wikimedia 的 CC0／PD 也可以，但每張都要自己確認授權，
> 不像 NASA 整站同一套規則。

## 系統需求

- macOS 13 以上（Apple Silicon / Intel）
- Xcode Command Line Tools（`swiftc`）—— `xcode-select --install`
- 選用：Google Chrome（`build.sh` 用它無頭渲染內建壁紙的縮圖與高解析海報；沒有也能編，只是內建壁紙會少縮圖）

## 相容性

| macOS | 狀態 |
|---|---|
| 26.x（開發機 26.4） | ✅ 實測 |
| 15 Sequoia | ⚠️ 未實測（API 可用） |
| 14 Sonoma | ⚠️ 未實測 |
| 13 Ventura | ⚠️ 以 macOS 13 SDK 編譯通過，未實測 |
| 12 及更舊 | ❌ 不支援 |

`arm64` 與 `x86_64` 都以 macOS 13 為部署目標編譯成功；實際產出的二進位是「你編譯的那台 Mac」的架構。若要通用二進位，把兩個架構都用 `lipo` 合併：

```bash
lipo -create build_arm64/DynWall build_x86_64/DynWall -output DynWall.universal
```

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

## 授權：原始碼公開，但禁止商業使用、禁止閉源

本專案採用 **[PolyForm Noncommercial License 1.0.0](LICENSE) + Share-Alike 附加條款**。

| | |
|---|---|
| ✅ 可以 | 自己用、改、學習、教學、非商業機構使用、把修改版公開分享（同樣開源） |
| ❌ 不可以 | 販售、隨硬體搭售、內嵌付費產品、放廣告賺錢、任何形式換取金錢 |
| ❌ 不可以 | 改成閉源散布 —— 修改後只要對外散布，就必須以相同條款公開原始碼 |
| ❌ 不可以 | 移除版權聲明、授權條款、App 內「關於」的作者資訊 |

> 這是 **source-available**（原始碼公開），**不是** OSI 定義的開源授權 ——
> OSI 不接受限制商業使用的條款。想要商業授權請另外聯絡作者。

實務上建議（作者自己發布時）：

1. **官方版本要有簽章**（Developer ID + 公證，US$99/年）—— 別人改過的版本簽章不同，使用者一看就知道
2. **只在 GitHub Releases 發布**官方 DMG，並附上 `shasum -a 256` 值
3. 專案名稱當作商標使用：不准別人拿「動態壁紙 / DynWall」當自己產品名（避免混淆）

內建壁紙（`resources/wallpapers/*`）與 App 圖示都是本專案自製。
打包工具不會也不能替你取得影片素材的授權 —— 包自己的影片時請自行確認權利；
**尤其是商業遊戲／動畫的影片，散布包著它的 App 會是侵權，跟程式碼授權無關。**

