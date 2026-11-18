# 動態壁紙 · DynWall

**macOS 전용** · macOS 13 이상 · Apple Silicon / Intel · Swift + AppKit · 외부 의존성 없음

> ⚠️ **개인 프로젝트라 아직 버그가 있을 수 있습니다.** macOS 26.4 / Apple Silicon 에서만 테스트했습니다.
> 문제가 생기면 macOS 버전과 `~/Library/Logs/動態壁紙.log` 를 함께 Issue 로 알려주세요.

[繁體中文](README.md) · [English](README.en.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md) · [Italiano](README.it.md)

macOS 용 네이티브 라이브 배경화면 엔진. **동영상, GIF, 이미지, 직접 작성한 HTML/CSS/JS** 를
**시스템 배경화면 위, 데스크톱 아이콘 아래**에 그립니다(아이콘, 우클릭 메뉴, 드래그 앤 드롭,
Mission Control 모두 정상 동작). 그래픽 배경화면 라이브러리 포함.

자세한 사용법은 [docs/使用說明.md](docs/使用說明.md) (중국어)를 참고하세요.

## 기능

- **네 가지 소스**: 동영상(`AVPlayerLooper` 무한 반복), 이미지, GIF, 사용자 HTML/CSS/JS
- **HTML 핫 리로드**: 파일을 저장하면 데스크톱이 즉시 갱신(FSEvents)
- **배경화면 라이브러리**: 썸네일, 실시간 미리보기, 설정 패널, 드래그 앤 드롭
- **메뉴 막대 제어**: 배경화면 전환, 일시정지, 어둡게, 속도, 로그인 시 자동 실행
- **앱을 종료해도 유지**: 현재 프레임을 데스크톱 그림으로 저장
- **패키징**: 동영상을 단독 실행 `.app` 으로, 다시 드래그 설치용 `.dmg` 로
- **내장 4종** canvas 배경화면(오로라 / 성해 / 사이버 그리드 / 디지털 레인)

## 요구 사항

- macOS 13 Ventura 이상 (Apple Silicon / Intel)
- Xcode Command Line Tools — `xcode-select --install`
- 선택 사항: Google Chrome (내장 썸네일·포스터 헤드리스 렌더링)

## 빌드

```bash
git clone https://github.com/shimianyizhimiao/dynwall.git
cd dynwall
./build.sh            # build/動態壁紙.app 생성
./build.sh install    # ~/Applications 에 설치
```

ad-hoc 서명이라 Apple Developer 계정이 필요 없습니다.

## 사용법

1. `~/Applications/動態壁紙.app` 실행 → 배경화면 라이브러리
2. 썸네일 선택 → **데스크톱에 적용**
3. **＋ 배경화면 추가** 로 동영상 / 이미지 / GIF / HTML 폴더 추가(창에 끌어다 놓아도 됨)
4. 메뉴 막대 아이콘(마우스를 화면 맨 위로) → 전환 / 일시정지 / 라이브러리(⌘L)

CLI: `DynWall --set video "/path/clip.mp4"` · `--set builtin starfield` · `--autostart on` · `--copy-templates`

## 호환성

| macOS | 상태 |
|---|---|
| 26.x (개발 기기 26.4) | ✅ 테스트 완료 |
| 15 Sequoia | ⚠️ 미검증(API 사용 가능) |
| 14 Sonoma | ⚠️ 미검증 |
| 13 Ventura | ⚠️ 13.0 SDK 로 빌드 가능, 미검증 |
| 12 이하 | ❌ 지원 안 함 |

`arm64` 와 `x86_64` 모두 macOS 13 을 타깃으로 빌드됩니다(빌드한 Mac 용 바이너리).

## 알려진 문제와 제한

- WebKit 비공개 설정(`pageVisibilityBasedProcessSuppressionEnabled`) 사용 → **App Store 배포 불가**
- 다중 디스플레이는 기본 수준, 충분히 검증되지 않음
- 4K 60fps 동영상 배경화면은 CPU 5~10%(하드웨어 디코딩). 노트북은 1080p 권장
- 배경화면 앱은 한 번에 하나만 (같은 레이어의 두 창은 서로 덮음)
- 전체 화면 앱은 배경화면을 가림(macOS 전체 화면 공간의 정상 동작)

## 라이선스

[PolyForm Noncommercial 1.0.0](LICENSE) **+ Share-Alike 추가 조항**:

- ✅ 개인·교육·비영리 사용, 수정 및 공유(동일 조건으로)
- ❌ 판매, 하드웨어 동봉, 유료 제품 내장, 광고 수익
- ❌ 클로즈드 소스 배포 — 배포하는 수정판은 동일 조건으로 소스 공개 필요
- ❌ 저작권 표시나 앱 내 저자 정보 삭제

이 프로젝트는 **source-available**(소스 공개)이며 OSI 정의의 오픈소스가 **아닙니다**.
상업적 라이선스가 필요하면 저자에게 문의하세요.

내장 배경화면과 앱 아이콘은 직접 제작했습니다. 함께 배포하는 동영상·이미지 소재의 권리는 부여되지 않습니다.
