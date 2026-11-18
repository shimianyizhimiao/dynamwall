# 動態壁紙 · DynWall

**Nur für macOS** · macOS 13+ · Apple Silicon und Intel · Swift + AppKit · keine externen Abhängigkeiten

> ⚠️ **Privates Projekt – es können noch Fehler auftreten.** Nur unter macOS 26.4 / Apple Silicon getestet.
> Bei Problemen bitte ein Issue mit macOS-Version und dem Log `~/Library/Logs/動態壁紙.log` öffnen.

[繁體中文](README.md) · [English](README.en.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md) · [Italiano](README.it.md)

Nativer animierter Desktop-Hintergrund für macOS: **Video, GIF, Bilder oder eigenes HTML/CSS/JS**,
gezeichnet **über dem Systemhintergrund und unter den Desktop-Symbolen** – Symbole, Kontextmenü,
Drag & Drop und Mission Control funktionieren weiter. Mit grafischer Wallpaper-Bibliothek.

Ausführliche Anleitung: [docs/使用說明.md](docs/使用說明.md) (auf Chinesisch).

## Funktionen

- **Vier Quellen**: Video (nahtlose Schleife über `AVPlayerLooper`), Bilder, GIF, eigenes HTML/CSS/JS
- **HTML-Hot-Reload**: Datei speichern, Desktop aktualisiert sich sofort
- **Grafische Bibliothek**: Vorschaubilder, Live-Vorschau, Einstellungen, Drag & Drop
- **Menüleisten-Steuerung**: wechseln, pausieren, abdunkeln, Geschwindigkeit, Autostart
- **Beim Beenden bleibt es**: das aktuelle Bild wird als Desktop-Hintergrund gespeichert
- **Paketierung**: Video als eigenständige `.app`, danach als Drag-Install-`.dmg`
- **4 eingebaute** Canvas-Wallpaper (Polarlicht / Sternenmeer / Cyber-Raster / Digitalregen)

## Voraussetzungen

- macOS 13 Ventura oder neuer (Apple Silicon oder Intel)
- Xcode Command Line Tools — `xcode-select --install`
- Optional: Google Chrome (rendert Vorschaubilder/Poster headless)

## Bauen und installieren

```bash
git clone https://github.com/shimianyizhimiao/dynwall.git
cd dynwall
./build.sh            # erzeugt build/動態壁紙.app
./build.sh install    # installiert zusätzlich nach ~/Applications
```

Ad-hoc-Signatur – kein Apple-Developer-Konto nötig.

## Benutzung

1. `~/Applications/動態壁紙.app` öffnen → Wallpaper-Bibliothek
2. Vorschaubild wählen → **Auf den Desktop anwenden**
3. **＋ Wallpaper hinzufügen** für Video / Bild / GIF / HTML-Ordner (oder Dateien hineinziehen)
4. Menüleisten-Symbol (Maus nach oben) → wechseln / pausieren / Bibliothek (⌘L)

CLI: `DynWall --set video "/pfad/clip.mp4"` · `--set builtin starfield` · `--autostart on`

## Kompatibilität

| macOS | Status |
|---|---|
| 26.x (Entwicklungsrechner: 26.4) | ✅ getestet |
| 15 Sequoia | ⚠️ ungetestet (APIs vorhanden) |
| 14 Sonoma | ⚠️ ungetestet |
| 13 Ventura | ⚠️ baut für 13.0, ungetestet |
| 12 und älter | ❌ nicht unterstützt |

`arm64` und `x86_64` bauen mit Deployment-Target macOS 13.

## Bekannte Probleme

- Nutzt eine private WebKit-Einstellung (`pageVisibilityBasedProcessSuppressionEnabled`) → **nicht im App Store verteilbar**
- Multi-Monitor-Unterstützung ist einfach und wenig getestet
- 4K-60fps-Video-Wallpaper ≈ 5–10 % CPU; auf Laptops besser 1080p
- Es darf nur eine Wallpaper-App gleichzeitig laufen
- Vollbild-Apps verdecken das Wallpaper (normales macOS-Verhalten)

## Lizenz

[PolyForm Noncommercial 1.0.0](LICENSE) **+ Share-Alike-Zusatz**:

- ✅ private, edukative und gemeinnützige Nutzung; ändern und teilen (zu denselben Bedingungen)
- ❌ verkaufen, mit Hardware bündeln, in bezahlte Produkte einbetten, mit Werbung Geld verdienen
- ❌ Closed-Source-Verbreitung (geänderte Versionen müssen zu denselben Bedingungen veröffentlicht werden)
- ❌ Copyright-Hinweis oder Autorenangabe in der App entfernen

Das ist **source-available**, _kein_ OSI-Open-Source (die OSI erlaubt keine Einschränkung kommerzieller Nutzung).
Für eine kommerzielle Lizenz den Autor kontaktieren.

Eingebaute Wallpaper und App-Icon sind Eigenproduktionen. Die Packaging-Tools übertragen keine Rechte
an den eingebundenen Medien.
