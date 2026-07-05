# AGENTS.md

## 먼저 이해할 것

- 이 저장소는 단일 iOS 타깃이다. 소스 루트는 `PhotoRava/PhotoRava`.
- Xcode 프로젝트는 `Project.swift`에서 `tuist generate`로 생성한다.
- 제품 흐름은 `경로 분석`과 `EXIF 스탬프` 두 축이다.
- 영속 스키마의 중심은 `Models/Route.swift`, `Models/PhotoRecord.swift`.
- AI 기능은 선택적이다. `FoundationModels` 코드는 `@available(iOS 26.0, *)`로 분기되며 fallback이 있다.

## 읽기 순서

1. `README.md`
2. `docs/architecture.md`
3. `docs/workflows.md`
4. `PhotoRava/PhotoRava/PhotoRavaApp.swift`
5. `PhotoRava/PhotoRava/AppState.swift`
6. `PhotoRava/PhotoRava/Models/Route.swift`
7. `PhotoRava/PhotoRava/Models/PhotoRecord.swift`
8. 그 다음부터 변경 대상 기능의 진입 파일만 연다.

## 컨텍스트 정책

### 하위 규칙

- `PhotoRava/PhotoRava/AGENTS.md`: 앱 소스 루트 공통 규칙.
- `PhotoRava/PhotoRava/Models/AGENTS.md`: SwiftData 영속 모델 규칙.
- `PhotoRava/PhotoRava/Services/AGENTS.md`: 메타데이터/OCR/경로/렌더링 서비스 규칙.
- `PhotoRava/PhotoRava/Views/AGENTS.md`: SwiftUI 화면 흐름과 수동 QA 규칙.

### 항상 참고

- `README.md`
- `AGENTS.md`
- `docs/architecture.md`
- `docs/workflows.md`
- `PhotoRava/PhotoRava/PhotoRavaApp.swift`
- `PhotoRava/PhotoRava/AppState.swift`
- `PhotoRava/PhotoRava/Models/Route.swift`
- `PhotoRava/PhotoRava/Models/PhotoRecord.swift`
- `Project.swift`

### 필요 시 참고

- 경로 목록/유입: `PhotoRava/PhotoRava/Views/Home/RouteListView.swift`, `PhotoRava/PhotoRava/Views/PhotoPicker/PhotoSelectionView.swift`, `PhotoRava/PhotoRava/Views/Analysis/AnalysisProgressView.swift`
- 경로 처리: `PhotoRava/PhotoRava/Services/PhotoMetadataService.swift`, `PhotoRava/PhotoRava/Services/OCRService.swift`, `PhotoRava/PhotoRava/Services/RouteReconstructionService.swift`
- 상세 UI: `PhotoRava/PhotoRava/Views/Timeline/TimelineDetailView.swift`, `PhotoRava/PhotoRava/Views/Map/RouteMapView.swift`, `PhotoRava/PhotoRava/Views/Map/RouteBottomSheet.swift`, `PhotoRava/PhotoRava/Views/Edit/RouteEditView.swift`
- EXIF 흐름: `PhotoRava/PhotoRava/Views/Exif/ExifStampRootView.swift`, `PhotoRava/PhotoRava/Models/ExifStamp/*`, `PhotoRava/PhotoRava/Services/ExifStampMetadataService.swift`, `PhotoRava/PhotoRava/Services/StampedImageRenderer.swift`
- 권한/공개 문구: `PhotoRava/PhotoRava/Derived/InfoPlists/PhotoRava-Info.plist`, `PhotoRava/PhotoRava/Views/Home/SettingsView.swift`, `PhotoRava/PhotoRava/privacy-policy.md`, `PhotoRava/PhotoRava/support.md`
- 프로젝트 설정: `Project.swift`

### 기본 무시

- `PhotoRava/PhotoRava/.build/`
- `PhotoRava/PhotoRava/.cache/`
- `PhotoRava/PhotoRava/.claude/`
- `PhotoRava/PhotoRava/.home/`
- `PhotoRava/PhotoRava/Derived/Sources/` (타깃 소스에서 제외된 예전 Tuist 헬퍼)
- `PhotoRava/PhotoRava/Assets.xcassets/AppIcon.appiconset/*.png`
- `WORKFLOW.md`
- 생성된 `PhotoRava.xcodeproj/`

## 명령

### 프로젝트 생성

```sh
tuist generate
```

### 시뮬레이터 빌드

```sh
xcodebuild -workspace PhotoRava.xcworkspace \
  -scheme PhotoRava \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/PhotoRava-build \
  CODE_SIGNING_ALLOWED=NO \
  build
```

### 릴리즈 아카이브

```sh
xcodebuild -workspace PhotoRava.xcworkspace \
  -scheme PhotoRava \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/PhotoRava.xcarchive \
  archive
```

## 릴리즈/외부 연동 주의

- 현재 저장소에는 테스트 타깃, test plan, CI workflow, Fastlane, export options, provisioning guide가 없다.
- `Project.swift`의 `DEVELOPMENT_TEAM`은 비어 있다. 배포 서명/export는 로컬 Xcode 계정 또는 비공개 설정으로 검증한다.
- AdMob 기본값은 Google demo ID다. production `ADMOB_APPLICATION_IDENTIFIER`, `ADMOB_ROUTE_LIST_BANNER_AD_UNIT_IDENTIFIER`는 빌드 설정으로만 비공개 주입하고 커밋하지 않는다.
- `docs/reviewer-guide.md`는 외부 리뷰어용 빠른 진입 문서다.

## 수정 우선순위

- 가장 작은 기능 진입 파일부터 읽고, 필요할 때만 서비스와 모델로 내려간다.
- `Route.swift`, `PhotoRecord.swift` 변경은 영속 스키마 변경으로 취급한다.
- 권한이나 정책 문구를 바꾸기 전에는 `PhotoRava-Info.plist`, `SettingsView.swift`, `privacy-policy.md`, `support.md`를 함께 확인한다.
- 버전, 번들 ID, signing, 배포 타깃, 타깃 멤버십을 바꿀 때만 `Project.swift`를 연다.
- `ExifStampRootView.swift`, `OCRService.swift`는 크다. 전체 선읽기 대신 심볼 검색 후 필요한 구간만 연다.

## 변경 전 체크리스트

- 변경 대상이 `경로 분석`인지 `EXIF 스탬프`인지 확인했는가?
- `Route` 또는 `PhotoRecord` 필드가 바뀌는가?
- Info.plist 권한 문구나 공개 문서도 같이 수정해야 하는가?
- Xcode 프로젝트 수정이 정말 필요한가?
- 생성물, 캐시, 백업 파일, 바이너리 에셋을 불필요하게 읽거나 수정하지 않는가?

## 답변 스타일

- 짧고 사실 위주로 쓴다.
- 변경 파일과 동작 영향만 적는다.
- 이미 문서화된 구조/워크플로 설명을 반복하지 않는다.
- 검증하지 못한 내용은 그대로 명시한다.
