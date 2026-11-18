# 動態壁紙 · DynWall

**macOS 専用** · macOS 13 以降 · Apple Silicon / Intel · Swift + AppKit · 外部依存なし

> ⚠️ **個人開発のプロジェクトです。まだバグがあるかもしれません。** 動作確認は macOS 26.4 / Apple Silicon のみ。
> 不具合があれば、macOS のバージョンと `~/Library/Logs/動態壁紙.log` を添えて Issue を立ててください。

[繁體中文](README.md) · [English](README.en.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md) · [Italiano](README.it.md)

macOS 用のネイティブ壁紙エンジン。**動画・GIF・画像・自作の HTML/CSS/JS** を、
**システム壁紙の上・デスクトップアイコンの下**に描画します（アイコン、右クリックメニュー、
ドラッグ＆ドロップ、Mission Control はそのまま使えます）。グラフィカルな壁紙ライブラリ付き。

詳しい使い方は [docs/使用說明.md](docs/使用說明.md)（中国語）を参照してください。

## 機能

- **4 種類のソース**：動画（`AVPlayerLooper` でシームレスループ）、画像、GIF、自作 HTML/CSS/JS
- **HTML ホットリロード**：保存するとデスクトップが即座に更新（FSEvents）
- **壁紙ライブラリ**：サムネイル、ライブプレビュー、設定パネル、ドラッグ＆ドロップ
- **メニューバー**：壁紙切替、一時停止、暗くする、速度、ログイン時に起動
- **終了しても壁紙は残る**：その瞬間のフレームをデスクトップピクチャとして保存
- **パッケージ化**：動画を単体の `.app` に、さらにドラッグインストール用 `.dmg` に
- **内蔵 4 種類**の canvas 壁紙（オーロラ / 星海 / サイバーグリッド / デジタルレイン）

## 必要環境

- macOS 13 Ventura 以降（Apple Silicon / Intel）
- Xcode Command Line Tools — `xcode-select --install`
- 任意：Google Chrome（内蔵サムネイル・ポスターのヘッドレス描画に使用）

## ビルド

```bash
git clone https://github.com/shimianyizhimiao/dynwall.git
cd dynwall
./build.sh            # build/動態壁紙.app を生成
./build.sh install    # ~/Applications にインストール
```

ad-hoc 署名なので Apple Developer アカウントは不要です。

## 使い方

1. `~/Applications/動態壁紙.app` を開く → 壁紙ライブラリ
2. サムネイルを選ぶ → **デスクトップに適用**
3. **＋ 壁紙を追加** で動画 / 画像 / GIF / HTML フォルダを追加（ウィンドウへドラッグでも可）
4. メニューバーのアイコン（画面上端にポインタを移動）→ 切替 / 一時停止 / ライブラリ（⌘L）

CLI：`DynWall --set video "/path/clip.mp4"` · `--set builtin starfield` · `--autostart on` · `--copy-templates`

## 対応状況

| macOS | 状態 |
|---|---|
| 26.x（開発機 26.4） | ✅ 動作確認済み |
| 15 Sequoia | ⚠️ 未検証（API は利用可能） |
| 14 Sonoma | ⚠️ 未検証 |
| 13 Ventura | ⚠️ 13.0 SDK でビルド可、未検証 |
| 12 以前 | ❌ 非対応 |

`arm64` / `x86_64` の両方が macOS 13 をターゲットにビルドできます（ビルドした Mac 向けのバイナリになります）。

## 既知の問題・制限

- WebKit の非公開設定（`pageVisibilityBasedProcessSuppressionEnabled`）を使用 → **App Store 配布不可**
- マルチディスプレイ対応は基本レベル、十分な検証なし
- 4K 60fps の動画壁紙は CPU 5〜10%（ハードウェアデコード）。ノート PC は 1080p 推奨
- 壁紙アプリは同時に 1 つだけ（同じレイヤーの 2 つのウィンドウは重なります）
- フルスクリーンアプリは壁紙を覆います（macOS の仕様）

## ライセンス

[PolyForm Noncommercial 1.0.0](LICENSE) **+ Share-Alike 追加条項**：

- ✅ 個人・教育・非営利での利用、改変と共有（同一条件で）
- ❌ 販売、ハードウェアへの同梱、有料製品への組み込み、広告収益
- ❌ クローズドソースでの配布（配布する改変版は同一条件でソース公開が必要）
- ❌ 著作権表示やアプリ内の作者情報の削除

これは **source-available**（ソース公開）であり、OSI 定義のオープンソースでは**ありません**。
商用ライセンスが必要な場合は作者に連絡してください。

内蔵壁紙とアプリアイコンは自作です。同梱した動画・画像素材の権利は本プロジェクトからは付与されません。
