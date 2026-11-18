# 動態壁紙 · DynWall

**Solo macOS** · macOS 13+ · Apple Silicon e Intel · Swift + AppKit · nessuna dipendenza esterna

> ⚠️ **Progetto personale: potrebbero esserci ancora dei bug.** Testato solo su macOS 26.4 / Apple Silicon.
> Se qualcosa non funziona, apri una Issue con la tua versione di macOS e il log `~/Library/Logs/動態壁紙.log`.

[繁體中文](README.md) · [English](README.en.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md) · [Italiano](README.it.md)

Motore di sfondi animati nativo per macOS: **video, GIF, immagini o il tuo HTML/CSS/JS**,
disegnato **sopra lo sfondo di sistema e sotto le icone del desktop** — icone, menu contestuale,
drag & drop e Mission Control continuano a funzionare. Include una libreria grafica.

Guida dettagliata: [docs/使用說明.md](docs/使用說明.md) (in cinese).

## Funzioni

- **Quattro sorgenti**: video (loop continuo con `AVPlayerLooper`), immagini, GIF, HTML/CSS/JS
- **Ricarica a caldo dell'HTML**: salvi il file e il desktop si aggiorna subito
- **Libreria grafica**: miniature, anteprima dal vivo, pannello impostazioni, drag & drop
- **Controllo nella barra dei menu**: cambia sfondo, pausa, scurisci, velocità, avvio automatico
- **Chiudendo non perdi nulla**: il fotogramma attuale diventa lo sfondo del desktop
- **Packaging**: trasforma un video in una `.app` autonoma, poi in un `.dmg` da trascinare
- **4 sfondi inclusi** in canvas (aurora / mare di stelle / griglia cyber / pioggia digitale)

## Requisiti

- macOS 13 Ventura o successivo (Apple Silicon o Intel)
- Xcode Command Line Tools — `xcode-select --install`
- Opzionale: Google Chrome (genera miniature e poster in modalità headless)

## Compilazione e installazione

```bash
git clone https://github.com/shimianyizhimiao/dynwall.git
cd dynwall
./build.sh            # crea build/動態壁紙.app
./build.sh install    # installa anche in ~/Applications
```

Firma ad-hoc: nessun account Apple Developer richiesto.

## Uso

1. Apri `~/Applications/動態壁紙.app` → libreria sfondi
2. Scegli una miniatura → **Applica al desktop**
3. **＋ Aggiungi sfondo** per video / immagine / GIF / cartella HTML (o trascina i file)
4. Icona nella barra dei menu (porta il puntatore in alto) → cambia / pausa / libreria (⌘L)

CLI: `DynWall --set video "/percorso/clip.mp4"` · `--set builtin starfield` · `--autostart on`

## Compatibilità

| macOS | Stato |
|---|---|
| 26.x (macchina di sviluppo: 26.4) | ✅ testato |
| 15 Sequoia | ⚠️ non testato (API disponibili) |
| 14 Sonoma | ⚠️ non testato |
| 13 Ventura | ⚠️ compila per 13.0, non testato |
| 12 e precedenti | ❌ non supportato |

`arm64` e `x86_64` compilano con target macOS 13.

## Problemi noti

- Usa una preferenza privata di WebKit (`pageVisibilityBasedProcessSuppressionEnabled`) → **non distribuibile sull'App Store**
- Supporto multi-monitor di base, poco testato
- Sfondo video 4K 60 fps ≈ 5–10% di CPU; sui portatili meglio 1080p
- Può girare una sola app di sfondi alla volta
- Le app a schermo intero coprono lo sfondo (comportamento normale di macOS)

## Licenza

[PolyForm Noncommercial 1.0.0](LICENSE) **+ clausola Share-Alike**:

- ✅ uso personale, didattico e senza scopo di lucro; modificare e condividere (con gli stessi termini)
- ❌ vendere, abbinare a hardware, integrare in prodotti a pagamento, monetizzare con pubblicità
- ❌ distribuire in codice chiuso (le versioni modificate vanno pubblicate con gli stessi termini)
- ❌ rimuovere l'avviso di copyright o le informazioni sull'autore nell'app

È **source-available**, _non_ open source secondo l'OSI (l'OSI non consente di limitare l'uso commerciale).
Per una licenza commerciale contatta l'autore.

Gli sfondi inclusi e l'icona sono originali. Gli strumenti di packaging non concedono diritti
sui media che includi.
