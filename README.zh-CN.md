# 动态壁纸 · DynWall

**仅限 macOS** · macOS 13+ · 支持 Apple Silicon 与 Intel · Swift + AppKit · 无第三方依赖

> ⚠️ **个人项目，可能还有些 bug。** 只在 macOS 26.4 / Apple Silicon 上实测过。
> 遇到问题请开 Issue，并附上你的 macOS 版本和 `~/Library/Logs/動態壁紙.log`。

[繁體中文](README.md) · [English](README.en.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md) · [Italiano](README.it.md)

原生 macOS 动态壁纸程序：**视频、GIF、图片、自己写的 HTML/CSS/JS 都能当壁纸**，
绘制在**系统壁纸之上、桌面图标之下** —— 桌面图标、右键菜单、拖拽、Mission Control 全部正常。附带图形化壁纸库。

## 功能

- **四种来源**：视频（`AVPlayerLooper` 无缝循环）、图片、GIF、自定义 HTML/CSS/JS
- **HTML 热重载**：保存文件，桌面立即更新
- **图形化壁纸库**：缩略图、实时预览、设置面板、拖拽导入
- **菜单栏控制**：切换壁纸、暂停、变暗、速度、开机自启
- **关掉 App 壁纸不变**：把当前画面存成静态图设为系统壁纸
- **打包**：把视频包成独立双击即用的 `.app`，再做成拖拽安装的 `.dmg`
- **内置 4 款** canvas 壁纸（极光 / 星海 / 赛博网格 / 数字雨）

## 系统要求

- macOS 13 Ventura 或更新（Apple Silicon / Intel）
- Xcode Command Line Tools：`xcode-select --install`
- 可选：Google Chrome（用于无头渲染内置缩略图与海报）

## 编译与安装

```bash
git clone https://github.com/shimianyizhimiao/dynwall.git
cd dynwall
./build.sh            # 编译到 build/動態壁紙.app
./build.sh install    # 并安装到 ~/Applications
```

采用 ad-hoc 签名，不需要 Apple 开发者账号。

## 使用

1. 双击 `~/Applications/動態壁紙.app` → 打开壁纸库
2. 点缩略图 → **应用到桌面**
3. **＋加入壁纸** 选视频 / 图片 / GIF / HTML 文件夹，或直接把文件拖进窗口
4. 菜单栏图标（鼠标移到屏幕最上方）→ 快速切换 / 暂停 / 打开壁纸库（⌘L）

命令行：`DynWall --set video "/path/clip.mp4"` · `--set builtin starfield` · `--autostart on` · `--copy-templates`

## 兼容性

| macOS | 状态 |
|---|---|
| 26.x（开发机 26.4） | ✅ 已实测 |
| 15 Sequoia | ⚠️ 未实测（API 可用） |
| 14 Sonoma | ⚠️ 未实测 |
| 13 Ventura | ⚠️ 以 13.0 SDK 编译通过，未实测 |
| 12 及更旧 | ❌ 不支持 |

`arm64` 与 `x86_64` 都能以 macOS 13 为目标编译；构建出的程序针对你编译所用的 Mac。

## 已知问题与限制

- 使用了 WebKit 私有偏好（`pageVisibilityBasedProcessSuppressionEnabled`）→ **无法上架 App Store**
- 多显示器支持较基础，未充分测试
- 4K 60fps 视频壁纸约 5–10% CPU（硬件解码），笔记本建议 1080p
- 同一时间只能运行一个壁纸 App（同图层的两个窗口会互相覆盖）
- 全屏 App 会遮住壁纸（macOS 全屏空间的正常行为）

## 授权

[PolyForm Noncommercial 1.0.0](LICENSE) **+ Share-Alike 附加条款**：

- ✅ 个人、教育、非营利使用；可以修改并分享（须用相同条款）
- ❌ 销售、随硬件搭售、内嵌付费产品、广告获利
- ❌ 闭源分发 —— 修改后分发必须以相同条款公开源码
- ❌ 移除版权声明或 App 内的作者信息

这是 **源码公开（source-available）**，**不是** OSI 定义的开源协议（OSI 不允许限制商业使用）。
需要商业授权请联系作者。

内置壁纸与 App 图标均为原创。打包工具不会授予你随包分发的视频／图片素材的任何权利，
请不要分发有版权的素材。
