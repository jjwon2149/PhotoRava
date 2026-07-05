# AGENTS.md

## 범위

- 사진 메타데이터 추출, OCR, 경로 재구성, 이미지 렌더링, AdMob 시작/설정.
- 서비스는 대부분 `Views -> Services -> Models` 방향으로 호출된다.

## 주요 파일

- `PhotoMetadataService.swift`: 사진 EXIF/GPS/asset metadata 추출.
- `OCRService.swift`: Vision OCR, 후보 scoring, iOS 26 `LocalAIService`.
- `RouteReconstructionService.swift`: route 통계, 좌표, 도로명, AI 요약/fallback.
- `ExifStampMetadataService.swift`: EXIF 스탬프용 메타데이터 수집.
- `StampedImageRenderer.swift`: 최종 스탬프 이미지 렌더링.
- `RouteSnapshotRenderer.swift`: 경로 스냅샷 렌더링.
- `AdMobService.swift`: AdMob app ID 설정과 SDK startup.

## 변경 규칙

- GPS 없는 사진 경로는 OCR/fallback이 핵심이다. GPS happy path만 보고 완료하지 않는다.
- `OCRService.swift`와 `RouteReconstructionService.swift`의 iOS 26 AI 경로는 항상 fallback과 함께 유지한다.
- `StampedImageRenderer.swift` 변경은 단일/배치 저장, 공유, 원본 미리보기 품질을 같이 본다.
- AdMob production ID는 절대 커밋하지 않는다. demo ID와 placeholder 구조만 유지한다.
- 서비스가 SwiftData 모델을 직접 mutate하면 UI 저장/편집 경로까지 영향 범위를 확인한다.

## 검증 포인트

- GPS 포함 사진 분석
- GPS 없는 사진 OCR 분석
- iOS 26 미지원 환경 fallback
- EXIF 단일/배치 렌더링
- AdMob 미설정/demo/production override 동작
