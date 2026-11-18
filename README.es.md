# 動態壁紙 · DynWall

**Solo para macOS** · macOS 13+ · Apple Silicon e Intel · Swift + AppKit · sin dependencias externas

> ⚠️ **Proyecto personal: todavía puede tener errores.** Solo probado en macOS 26.4 / Apple Silicon.
> Si algo falla, abre un Issue con tu versión de macOS y el registro `~/Library/Logs/動態壁紙.log`.

[繁體中文](README.md) · [English](README.en.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md) · [Italiano](README.it.md)

Motor de fondos de pantalla animados nativo para macOS: **vídeo, GIF, imágenes o tu propio HTML/CSS/JS**,
dibujado **encima del fondo del sistema y debajo de los iconos del escritorio** — los iconos, el menú
contextual, arrastrar y soltar y Mission Control siguen funcionando. Incluye una biblioteca gráfica.

Guía de uso detallada: [docs/使用說明.md](docs/使用說明.md) (en chino).

## Funciones

- **Cuatro fuentes**: vídeo (bucle sin cortes con `AVPlayerLooper`), imágenes, GIF, HTML/CSS/JS propio
- **Recarga en caliente del HTML**: guarda el archivo y el escritorio se actualiza al instante
- **Biblioteca gráfica**: miniaturas, vista previa en vivo, panel de ajustes, arrastrar y soltar
- **Control en la barra de menús**: cambiar fondo, pausar, atenuar, velocidad, abrir al iniciar sesión
- **Al cerrar no se pierde**: el fotograma actual se guarda como fondo del escritorio
- **Empaquetado**: convierte un vídeo en una `.app` independiente y luego en un `.dmg` de arrastre
- **4 fondos incluidos** dibujados con canvas (aurora / mar de estrellas / rejilla ciber / lluvia digital)

## Requisitos

- macOS 13 Ventura o posterior (Apple Silicon o Intel)
- Xcode Command Line Tools — `xcode-select --install`
- Opcional: Google Chrome (para generar miniaturas y pósteres sin interfaz)

## Compilar e instalar

```bash
git clone https://github.com/shimianyizhimiao/dynwall.git
cd dynwall
./build.sh            # genera build/動態壁紙.app
./build.sh install    # además instala en ~/Applications
```

Firma ad-hoc: no necesitas cuenta de Apple Developer.

## Uso

1. Abre `~/Applications/動態壁紙.app` → biblioteca de fondos
2. Elige una miniatura → **Aplicar al escritorio**
3. **＋ Añadir fondo** para vídeo / imagen / GIF / carpeta HTML (o arrastra los archivos)
4. Icono de la barra de menús (mueve el puntero arriba) → cambiar / pausar / biblioteca (⌘L)

CLI: `DynWall --set video "/ruta/clip.mp4"` · `--set builtin starfield` · `--autostart on`

## Compatibilidad

| macOS | Estado |
|---|---|
| 26.x (equipo de desarrollo: 26.4) | ✅ probado |
| 15 Sequoia | ⚠️ sin probar (API disponible) |
| 14 Sonoma | ⚠️ sin probar |
| 13 Ventura | ⚠️ compila para 13.0, sin probar |
| 12 y anteriores | ❌ no soportado |

`arm64` y `x86_64` compilan con destino macOS 13.

## Problemas conocidos

- Usa una preferencia privada de WebKit (`pageVisibilityBasedProcessSuppressionEnabled`) → **no distribuible en la App Store**
- Soporte multimonitor básico, poco probado
- Fondo de vídeo 4K 60fps ≈ 5–10% de CPU; en portátiles mejor 1080p
- Solo puede ejecutarse una app de fondos a la vez
- Las apps a pantalla completa tapan el fondo (comportamiento normal de macOS)

## Licencia

[PolyForm Noncommercial 1.0.0](LICENSE) **+ cláusula Share-Alike**:

- ✅ uso personal, educativo y sin ánimo de lucro; modificar y compartir (con los mismos términos)
- ❌ vender, incluir con hardware, integrar en productos de pago, monetizar con anuncios
- ❌ distribuir en código cerrado (las versiones modificadas deben publicarse con los mismos términos)
- ❌ eliminar el aviso de copyright o la información del autor en la app

Es **source-available**, _no_ es código abierto según la OSI (la OSI no permite restringir el uso comercial).
Para una licencia comercial, contacta al autor.

Los fondos incluidos y el icono son originales. Las herramientas de empaquetado no te ceden derechos
sobre el material de vídeo/imagen que incluyas.
