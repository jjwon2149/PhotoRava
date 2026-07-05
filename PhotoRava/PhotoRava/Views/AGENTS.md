# AGENTS.md

## 범위

- SwiftUI 화면과 사용자 흐름.
- 주요 탭은 경로, EXIF, 설정이다.

## 주요 진입점

- 경로 목록/유입: `Home/RouteListView.swift`
- 사진 선택: `PhotoPicker/PhotoSelectionView.swift`
- 분석 진행: `Analysis/AnalysisProgressView.swift`
- EXIF 스탬프: `Exif/ExifStampRootView.swift`
- 지도/상세: `Map/*`, `Timeline/*`, `Edit/RouteEditView.swift`
- 광고 UI: `Ads/RouteListAdBannerView.swift`
- 권한/진단: `Home/SettingsView.swift`

## 고위험 화면

- `Exif/ExifStampRootView.swift`는 3000줄 이상이며 상태, 사진 로딩, preview, save/share, batch export, route handoff를 모두 가진다. 심볼 검색 후 필요한 구간만 연다.
- `Analysis/AnalysisProgressView.swift`는 metadata/OCR/route 저장을 조합한다. 모델/서비스 변경과 함께 검증한다.
- `Home/RouteListView.swift`는 첫 화면, 검색/필터, photo picker, analysis sheet, banner 광고가 만나는 지점이다.

## UI 변경 규칙

- 한국어 텍스트 줄바꿈, Dynamic Type, 작은 iPhone 화면을 확인한다.
- 광고는 RouteList/home banner만 허용한다. interstitial/rewarded/app-open/native/full-screen은 명시 승인 전 금지다.
- 핵심 작업 흐름인 사진 선택, 분석, EXIF 저장/공유 위에 광고나 sheet가 끼어들지 않게 한다.
- 권한/공개 문구 화면 변경은 Info.plist와 privacy/support 문서를 같이 확인한다.

## 수동 QA

- iPhone SE급 작은 화면
- iPhone 일반 화면
- 권한 미허용/허용 상태
- 빈 route 목록과 저장된 route 목록
- 단일/다중 EXIF export
- GPS 있음/없음 사진 분석
