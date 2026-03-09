# Architecture

## 범위

- 앱 타깃: `PhotoRava`
- 소스 루트: `PhotoRava/PhotoRava`
- 진입점: `PhotoRavaApp.swift`
- 공용 UI 상태: `AppState.swift`
- 핵심 영속 모델: `Models/Route.swift`, `Models/PhotoRecord.swift`

## 핵심 모듈

| 영역 | 주요 파일 | 역할 |
| --- | --- | --- |
| 앱 셸 | `PhotoRavaApp.swift`, `AppState.swift` | 앱 시작, SwiftData 마운트, 탭 전환, 분석 대기 사진 전달 |
| 경로 유입 | `Views/Home/RouteListView.swift`, `Views/PhotoPicker/PhotoSelectionView.swift`, `Views/Analysis/AnalysisProgressView.swift` | 사진 선택 시작, 분석 실행, 결과 저장 |
| 경로 처리 | `Services/PhotoMetadataService.swift`, `Services/OCRService.swift`, `Services/RouteReconstructionService.swift` | 메타데이터 추출, OCR, 지오코딩, 통계 계산, 경로 파생 데이터 저장 |
| 경로 상세 UI | `Views/Timeline/TimelineDetailView.swift`, `Views/Map/RouteMapView.swift`, `Views/Map/RouteBottomSheet.swift`, `Views/Edit/RouteEditView.swift` | 지도, 타임라인, 편집, AI 재요약 |
| EXIF 흐름 | `Views/Exif/ExifStampRootView.swift`, `Models/ExifStamp/*`, `Services/ExifStampMetadataService.swift`, `Services/StampedImageRenderer.swift` | 사진 로드, 메타데이터 보존, 스탬프 렌더링 |
| 설정/공개 문서 | `Views/Home/SettingsView.swift`, `Derived/InfoPlists/PhotoRava-Info.plist`, `privacy-policy.md`, `support.md` | 권한 진단과 공개 문구 관리 |

## 데이터 흐름

1. `RouteListView.swift`가 저장된 `Route`를 읽고 사진 선택으로 진입한다.
2. `PhotoSelectionView.swift`가 `PhotosPickerItem`을 수집하고 가능하면 `PHAsset` 식별자를 유지한다.
3. `AnalysisProgressView.swift`가 먼저 메타데이터를 추출하고, GPS가 없는 사진에만 OCR을 실행한다.
4. 분석된 각 사진은 `PhotoRecord`가 된다.
5. `RouteReconstructionService.swift`가 `Route`를 재구성하고, 좌표/거리/시간/도로명/인코딩된 경로 좌표를 채운다.
6. `LocalAIService`는 `OCRService.swift` 안에 있다. 지원 기기와 iOS 26+ 환경에서는 지오코딩 질의 보정과 경로 요약을 만들고, 그 외에는 fallback이 동작한다.
7. 완성된 `Route`는 SwiftData에 저장되고, 상세 화면이 이를 소비한다.
8. EXIF 흐름은 `ExifStampRootView.swift`에서 별도로 시작하며, 경로 복원 없이 메타데이터/렌더링 서비스만 사용한다.

## 주요 의사결정

- 의존 방향은 대부분 `Views -> Services -> Models`다.
- 별도 coordinator/domain 계층은 없고, `AnalysisProgressView.swift`가 서비스를 직접 조합한다.
- `Route.swift`, `PhotoRecord.swift`는 저장 스키마다. UI 변경처럼 보여도 이 파일 수정은 고위험이다.
- `Derived/*`는 생성된 프로젝트 보조 코드이며, 제품 구조를 이해하는 1차 문서는 아니다.
- 현재 저장소에는 테스트 타깃, 테스트 플랜, CI, 릴리즈 자동화 스크립트가 없다.

## 어디부터 볼지

- 새 경로 분석 기능: `RouteListView.swift` -> `PhotoSelectionView.swift` -> `AnalysisProgressView.swift` -> `RouteReconstructionService.swift`
- 지도/타임라인 변경: `TimelineDetailView.swift`, `RouteMapView.swift`, `RouteBottomSheet.swift`
- EXIF 내보내기 변경: `ExifStampRootView.swift`, `ExifStampMetadataService.swift`, `StampedImageRenderer.swift`
- 권한/공개 문구 변경: `PhotoRava-Info.plist`, `SettingsView.swift`, `privacy-policy.md`, `support.md`
- 버전/signing/번들/배포 타깃 변경: `PhotoRava.xcodeproj/project.pbxproj`
