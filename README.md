# PhotoRava

PhotoRava는 선택한 사진으로 이동 경로를 복원하고, 사진에 EXIF 스탬프를 새겨 내보내는 단일 iOS 앱입니다. 실제 소스 루트는 `PhotoRava/PhotoRava`이며, 핵심 영속 모델은 `Route`와 `PhotoRecord`입니다. 지원 기기와 iOS 26+ 환경에서는 온디바이스 AI 요약/지오코딩 보정이 동작하고, 지원되지 않는 경우 코드에 fallback 경로가 있습니다.

## Quick Start

1. `PhotoRava/PhotoRava/PhotoRava.xcodeproj`를 Xcode에서 엽니다.
2. `PhotoRava` 스킴을 iPhone Simulator 또는 실기기에서 실행합니다.
3. 경로 분석/EXIF 저장을 테스트할 때 사진 읽기, 사진 추가 저장, 위치 권한을 허용합니다.
4. CLI 빌드:

```sh
xcodebuild -project PhotoRava/PhotoRava/PhotoRava.xcodeproj -scheme PhotoRava -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build
```

## Directory Guide

- `PhotoRava/PhotoRava/PhotoRavaApp.swift`, `AppState.swift`: 앱 진입점과 공용 UI 상태
- `PhotoRava/PhotoRava/Models`: SwiftData 모델과 EXIF 설정
- `PhotoRava/PhotoRava/Views`: 기능별 진입 화면과 UI 흐름
- `PhotoRava/PhotoRava/Services`: 메타데이터 추출, OCR, 경로 복원, 렌더링
- `PhotoRava/PhotoRava/Derived`: 생성된 plist/에셋 헬퍼. 구조 이해의 주 문서가 아님

## Read Next

- `docs/architecture.md`: 구조와 데이터 흐름
- `docs/workflows.md`: 실행, 빌드, 수동 검증
- `AGENTS.md`: Codex/LLM용 읽기 순서와 컨텍스트 규칙

## Public Docs

- `PhotoRava/PhotoRava/privacy-policy.md`
- `PhotoRava/PhotoRava/support.md`
