# AGENTS.md

## 범위

- SwiftData 영속 모델과 EXIF 설정 모델.
- 핵심 저장 스키마는 `Route.swift`, `PhotoRecord.swift`.
- EXIF 설정 값은 `ExifStamp/*` 아래에 있다.

## 고위험 파일

- `Route.swift`: 경로, 요약, 사용자 편집 필드, 좌표 데이터.
- `PhotoRecord.swift`: 사진 메타데이터, OCR, AI 지오코딩 필드.
- `ExifStamp/ExifStampUserSettings.swift`: 사용자 스탬프 설정.
- `ExifStamp/ExifStampTheme.swift`: 화면/렌더러가 공유하는 테마 정의.

## 변경 규칙

- `@Model` 클래스 필드 변경은 영속 스키마 변경으로 취급한다.
- 저장 필드 이름/타입/optional 여부를 바꾸면 기존 사용자 데이터와 migration 영향을 먼저 판단한다.
- UI 표시용 computed property가 필요하면 저장 필드보다 extension/computed property를 우선한다.
- `@available(iOS 26.0, *)` 타입을 비가용 경로에서 직접 참조하지 않는다.
- `Route`/`PhotoRecord`를 바꾸면 route 분석, timeline/map, edit, EXIF handoff 경로를 같이 검증한다.

## 검증 포인트

- `tuist generate`
- simulator build
- 기존 route 목록 열기
- 새 사진 분석 후 저장
- 저장된 route의 map/timeline/edit 진입
