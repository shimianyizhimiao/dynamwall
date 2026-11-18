# 動態壁紙 · DynWall

**macOS uniquement** · macOS 13+ · Apple Silicon et Intel · Swift + AppKit · aucune dépendance externe

> ⚠️ **Projet personnel : il peut encore y avoir des bugs.** Testé uniquement sur macOS 26.4 / Apple Silicon.
> En cas de problème, ouvrez une Issue avec votre version de macOS et le journal `~/Library/Logs/動態壁紙.log`.

[繁體中文](README.md) · [English](README.en.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md) · [Italiano](README.it.md)

Moteur de fond d'écran animé natif pour macOS : **vidéo, GIF, images ou votre propre HTML/CSS/JS**,
dessiné **au-dessus du fond d'écran système et sous les icônes du bureau** — icônes, menu contextuel,
glisser-déposer et Mission Control continuent de fonctionner. Avec une bibliothèque graphique.

Guide d'utilisation détaillé : [docs/使用說明.md](docs/使用說明.md) (en chinois).

## Fonctionnalités

- **Quatre sources** : vidéo (boucle sans coupure via `AVPlayerLooper`), images, GIF, HTML/CSS/JS
- **Rechargement à chaud du HTML** : enregistrez le fichier, le bureau se met à jour aussitôt
- **Bibliothèque graphique** : vignettes, aperçu en direct, panneau de réglages, glisser-déposer
- **Barre des menus** : changer de fond, pause, assombrir, vitesse, lancement à l'ouverture de session
- **Quitter sans rien perdre** : l'image courante est enregistrée comme fond d'écran
- **Empaquetage** : transformer une vidéo en `.app` autonome, puis en `.dmg` à glisser-déposer
- **4 fonds intégrés** dessinés en canvas (aurore / mer d'étoiles / grille cyber / pluie numérique)

## Prérequis

- macOS 13 Ventura ou ultérieur (Apple Silicon ou Intel)
- Xcode Command Line Tools — `xcode-select --install`
- Facultatif : Google Chrome (génère les vignettes et affiches en mode headless)

## Compiler et installer

```bash
git clone https://github.com/shimianyizhimiao/dynwall.git
cd dynwall
./build.sh            # génère build/動態壁紙.app
./build.sh install    # installe aussi dans ~/Applications
```

Signature ad-hoc : aucun compte Apple Developer nécessaire.

## Utilisation

1. Ouvrez `~/Applications/動態壁紙.app` → la bibliothèque
2. Choisissez une vignette → **Appliquer au bureau**
3. **＋ Ajouter un fond** pour vidéo / image / GIF / dossier HTML (ou glissez les fichiers)
4. Icône de la barre des menus (pointeur en haut de l'écran) → changer / pause / bibliothèque (⌘L)

CLI : `DynWall --set video "/chemin/clip.mp4"` · `--set builtin starfield` · `--autostart on`

## Compatibilité

| macOS | État |
|---|---|
| 26.x (machine de dev : 26.4) | ✅ testé |
| 15 Sequoia | ⚠️ non testé (API disponible) |
| 14 Sonoma | ⚠️ non testé |
| 13 Ventura | ⚠️ compile pour 13.0, non testé |
| 12 et antérieur | ❌ non pris en charge |

`arm64` et `x86_64` compilent avec une cible macOS 13.

## Problèmes connus

- Utilise une préférence WebKit privée (`pageVisibilityBasedProcessSuppressionEnabled`) → **non distribuable sur l'App Store**
- Prise en charge multi-écrans basique, peu testée
- Fond vidéo 4K 60 fps ≈ 5–10 % de CPU ; préférez 1080p sur portable
- Une seule application de fond d'écran à la fois
- Les apps en plein écran masquent le fond (comportement normal de macOS)

## Licence

[PolyForm Noncommercial 1.0.0](LICENSE) **+ clause Share-Alike** :

- ✅ usage personnel, éducatif, à but non lucratif ; modifier et partager (sous les mêmes termes)
- ❌ vendre, fournir avec du matériel, intégrer à un produit payant, monétiser par la publicité
- ❌ distribuer en code fermé (les versions modifiées doivent être publiées sous les mêmes termes)
- ❌ supprimer la mention de copyright ou les informations d'auteur dans l'app

C'est du **source-available**, _pas_ de l'open source au sens OSI (l'OSI interdit de restreindre l'usage commercial).
Pour une licence commerciale, contactez l'auteur.

Les fonds intégrés et l'icône sont originaux. Les outils d'empaquetage ne vous donnent aucun droit
sur les médias que vous y intégrez.
