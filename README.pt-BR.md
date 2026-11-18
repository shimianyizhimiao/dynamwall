# 動態壁紙 · DynWall

**Somente macOS** · macOS 13+ · Apple Silicon e Intel · Swift + AppKit · sem dependências externas

> ⚠️ **Projeto pessoal — ainda pode ter bugs.** Testado apenas em macOS 26.4 / Apple Silicon.
> Se algo falhar, abra uma Issue com a sua versão do macOS e o log `~/Library/Logs/動態壁紙.log`.

[繁體中文](README.md) · [English](README.en.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md) · [Italiano](README.it.md)

Motor de papel de parede animado nativo para macOS: **vídeo, GIF, imagens ou seu próprio HTML/CSS/JS**,
desenhado **acima do papel de parede do sistema e abaixo dos ícones da área de trabalho** — ícones,
menu de contexto, arrastar e soltar e o Mission Control continuam funcionando. Inclui biblioteca gráfica.

Guia de uso detalhado: [docs/使用說明.md](docs/使用說明.md) (em chinês).

## Recursos

- **Quatro fontes**: vídeo (loop perfeito com `AVPlayerLooper`), imagens, GIF, HTML/CSS/JS próprio
- **Recarga automática do HTML**: salve o arquivo e a área de trabalho atualiza na hora
- **Biblioteca gráfica**: miniaturas, prévia ao vivo, painel de ajustes, arrastar e soltar
- **Controle na barra de menus**: trocar, pausar, escurecer, velocidade, abrir ao iniciar sessão
- **Fechar não perde nada**: o quadro atual vira o papel de parede do sistema
- **Empacotamento**: transforme um vídeo em `.app` independente e depois em `.dmg` de arrastar
- **4 papéis de parede** em canvas (aurora / mar de estrelas / grade ciber / chuva digital)

## Requisitos

- macOS 13 Ventura ou superior (Apple Silicon ou Intel)
- Xcode Command Line Tools — `xcode-select --install`
- Opcional: Google Chrome (gera miniaturas e pôsteres em modo headless)

## Compilar e instalar

```bash
git clone https://github.com/shimianyizhimiao/dynwall.git
cd dynwall
./build.sh            # gera build/動態壁紙.app
./build.sh install    # também instala em ~/Applications
```

Assinatura ad-hoc — não precisa de conta Apple Developer.

## Uso

1. Abra `~/Applications/動態壁紙.app` → biblioteca de papéis de parede
2. Escolha uma miniatura → **Aplicar à área de trabalho**
3. **＋ Adicionar papel de parede** para vídeo / imagem / GIF / pasta HTML (ou arraste os arquivos)
4. Ícone da barra de menus (leve o cursor ao topo da tela) → trocar / pausar / biblioteca (⌘L)

CLI: `DynWall --set video "/caminho/clip.mp4"` · `--set builtin starfield` · `--autostart on`

## Compatibilidade

| macOS | Estado |
|---|---|
| 26.x (máquina de dev: 26.4) | ✅ testado |
| 15 Sequoia | ⚠️ não testado (APIs disponíveis) |
| 14 Sonoma | ⚠️ não testado |
| 13 Ventura | ⚠️ compila para 13.0, não testado |
| 12 e anteriores | ❌ sem suporte |

`arm64` e `x86_64` compilam com destino macOS 13.

## Problemas conhecidos

- Usa uma preferência privada do WebKit (`pageVisibilityBasedProcessSuppressionEnabled`) → **não distribuível na App Store**
- Suporte a múltiplos monitores é básico e pouco testado
- Papel de parede em vídeo 4K 60 fps ≈ 5–10% de CPU; em notebooks prefira 1080p
- Só um app de papel de parede pode rodar por vez
- Apps em tela cheia cobrem o papel de parede (comportamento normal do macOS)

## Licença

[PolyForm Noncommercial 1.0.0](LICENSE) **+ cláusula Share-Alike**:

- ✅ uso pessoal, educacional e sem fins lucrativos; modificar e compartilhar (nos mesmos termos)
- ❌ vender, incluir com hardware, embutir em produtos pagos, monetizar com anúncios
- ❌ distribuir em código fechado (versões modificadas devem ser publicadas nos mesmos termos)
- ❌ remover o aviso de copyright ou as informações do autor no app

É **source-available**, _não_ é open source pela OSI (a OSI não permite restringir uso comercial).
Para licença comercial, fale com o autor.

Os papéis de parede incluídos e o ícone são originais. As ferramentas de empacotamento não concedem
direitos sobre as mídias que você incluir.
