# DynWall

<p>
  <a href="https://github.com/shimianyizhimiao/macos-live-wallpaper/releases/latest">
    <img alt="Download for macOS" src="https://img.shields.io/badge/⬇_Download-DynWall.dmg-2ea44f?style=for-the-badge&logo=apple&logoColor=white" height="42">
  </a>
  <a href="https://shimianyizhimiao.github.io/macos-live-wallpaper/">
    <img alt="Website" src="https://img.shields.io/badge/Website-shimianyizhimiao.github.io-3b82f6?style=for-the-badge" height="42">
  </a>
</p>

**Just want to use it?** → **[Download DynWall.dmg](https://github.com/shimianyizhimiao/macos-live-wallpaper/releases/latest)**, open it, drag the app to Applications, pick your language on first launch (macOS 13+, Apple silicon / Intel).


**macOS only** · macOS 13+ · Apple Silicon & Intel · Swift + AppKit · no third-party dependencies

> ⚠️ **Personal project — it may still have bugs.** Only tested on macOS 26.4 / Apple Silicon.
> If something breaks, please open an Issue with your macOS version and the log at `~/Library/Logs/動態壁紙.log`.

[繁體中文](README.md) · [English](README.en.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md) · [Italiano](README.it.md)

A native animated wallpaper engine for macOS: **video, GIF, images, or your own HTML/CSS/JS**
drawn **above the system wallpaper and below the desktop icons** — desktop icons, right-click menus,
drag & drop and Mission Control keep working. Comes with a graphical wallpaper library.

## Features

- **Four sources**: video (seamless `AVPlayerLooper`), images, GIF, custom HTML/CSS/JS
- **HTML hot reload**: save the file, the desktop updates instantly (FSEvents)
- **Graphical library**: thumbnails, live preview, settings panel, drag & drop import
- **Menu bar control**: switch wallpaper, pause, dim, rate, launch at login
- **Quit without losing it**: the current frame is saved as the desktop picture
- **Packaging**: turn a video into a standalone double-click `.app`, then a drag-install `.dmg`
- **4 built-in** canvas wallpapers (aurora / starfield / cyber grid / digital rain)

## Requirements

- macOS 13 Ventura or later (Apple Silicon or Intel)
- Xcode Command Line Tools — `xcode-select --install`
- Optional: Google Chrome (renders the built-in thumbnails/posters headlessly)

## Build & install

```bash
git clone https://github.com/shimianyizhimiao/dynwall.git
cd dynwall
./build.sh            # builds build/動態壁紙.app
./build.sh install    # also installs to ~/Applications
```

Ad-hoc signed — no Apple Developer account required.

## Usage

1. Open `~/Applications/動態壁紙.app` → the wallpaper library
2. Pick a thumbnail → **Apply to desktop**
3. **＋ Add wallpaper** for video / image / GIF / HTML folder — or drag files onto the window
4. Menu bar icon (move the pointer to the top of the screen) → quick switch / pause / library (⌘L)

CLI: `DynWall --set video "/path/clip.mp4"` · `--set builtin starfield` · `--autostart on` · `--copy-templates`

## Compatibility

| macOS | Status |
|---|---|
| 26.x (dev machine: 26.4) | ✅ tested |
| 15 Sequoia | ⚠️ not tested (APIs available) |
| 14 Sonoma | ⚠️ not tested |
| 13 Ventura | ⚠️ compiles against the 13.0 SDK, not tested |
| 12 and older | ❌ unsupported |

`arm64` and `x86_64` both compile with a macOS 13 deployment target; the built app targets the Mac you compile on.

## Known issues & limits

- Uses a private WebKit preference (`pageVisibilityBasedProcessSuppressionEnabled`) → **not App Store distributable**
- Multi-display support is basic and not well tested
- 4K 60 fps video wallpaper ≈ 5–10% CPU (hardware decode); use 1080p on laptops
- Only one wallpaper app may run at a time — two windows at the same layer stack on top of each other
- Full-screen apps cover the wallpaper (that is how macOS full-screen spaces work)

## License

[PolyForm Noncommercial 1.0.0](LICENSE) **+ Share-Alike addendum**:

- ✅ personal, educational, non-profit use; modify and share (under the same terms)
- ❌ selling, bundling with hardware, embedding in paid products, ad revenue
- ❌ closed-source distribution — modified versions you distribute must be released under the same terms
- ❌ removing the copyright notice or the in-app author info

This is **source-available**, _not_ OSI open source (OSI does not allow restricting commercial use).
For a commercial license, contact the author.

The built-in wallpapers and app icon are original. The packaging tools do not grant you any rights
to the video/image assets you bundle — do not redistribute copyrighted material.
