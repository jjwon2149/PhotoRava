# AGENTS.md

## 범위

- 이 디렉터리가 실제 앱 소스 루트다.
- 앱 진입점은 `PhotoRavaApp.swift`, 공유 상태는 `AppState.swift`.
- 하위 핵심 경계는 `Models`, `Services`, `Views`, `Derived/InfoPlists`, `Assets.xcassets`.

## 먼저 확인

- 앱 시작/탭 구조: `PhotoRavaApp.swift`
- 탭 전환/EXIF -> 경로 분석 handoff: `AppState.swift`
- 권한/Info.plist 연동: `Derived/InfoPlists/PhotoRava-Info.plist`, `Views/Home/SettingsView.swift`

## 변경 규칙

- `Derived/Sources`는 타깃에서 제외된 예전 생성 소스다. 수정하지 않는다.
- `Derived/InfoPlists/PhotoRava-Info.plist`는 실제 앱 Info.plist다. 권한 문구, AdMob key, bundle setting placeholder 변경 시만 수정한다.
- 권한 문구 변경은 `SettingsView.swift`, `privacy-policy.md`, `support.md`와 함께 확인한다.
- `Assets.xcassets/AppIcon.appiconset/*.png`는 요청 없이는 읽거나 수정하지 않는다.
- 앱 전체 동작 변경 후에는 자동 테스트가 없으므로 `tuist generate`와 simulator build를 최소 검증으로 삼는다.

## 릴리즈/광고

- AdMob production ID는 소스에 쓰지 않는다.
- Info.plist에는 `$(ADMOB_APPLICATION_IDENTIFIER)`와 `$(ADMOB_ROUTE_LIST_BANNER_AD_UNIT_IDENTIFIER)` placeholder만 둔다.
- 앱 버전, build number, bundle ID, signing 관련 변경은 루트 `Project.swift`에서 한다.
