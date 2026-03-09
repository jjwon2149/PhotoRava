# Workflows

## 로컬 실행

- `PhotoRava/PhotoRava/PhotoRava.xcodeproj`를 열고 `PhotoRava` 스킴을 실행한다.
- 공유 스킴과 빌드 설정은 이미 있다. 별도 의존성 설치 단계는 없다.
- 확인용 명령:

```sh
xcodebuild -list -project PhotoRava/PhotoRava/PhotoRava.xcodeproj
```

- 검증한 시뮬레이터 빌드 명령:

```sh
xcodebuild -project PhotoRava/PhotoRava/PhotoRava.xcodeproj -scheme PhotoRava -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/PhotoRava-build build
```

## 수동 검증

- 공유 스킴에 자동 테스트가 없다. 집중된 수동 체크로 확인한다.
- 경로 흐름:
  - GPS가 있는 사진과 없는 사진을 각각 선택한다.
  - 경로 생성이 끝나고 저장된 경로가 지도/타임라인에서 열리는지 확인한다.
  - 지원 기기와 iOS 26+ 환경이면 AI 요약/AI 보정이 보이는지, 아니면 fallback 출력이 남는지 확인한다.
- EXIF 흐름:
  - 단일 사진과 여러 장 배치를 각각 선택한다.
  - 미리보기와 저장/내보내기가 동작하는지 확인한다.
- 권한:
  - `Settings`에서 사진/위치 권한 상태가 바뀌는지 확인한다.

## 빌드와 릴리즈

- 배포 타깃은 iOS 17.0이다.
- 일부 AI 코드 경로는 iOS 26.0+와 지원 기기를 요구하지만, fallback이 있어 앱 자체는 빌드된다.
- 드문 작업: Release archive

```sh
xcodebuild -project PhotoRava/PhotoRava/PhotoRava.xcodeproj -scheme PhotoRava -configuration Release -destination 'generic/platform=iOS' archive -archivePath /tmp/PhotoRava.xcarchive
```

- 저장소에는 Fastlane, export options, CI 릴리즈 스크립트, 별도 provisioning 문서가 없다. signing/export는 Xcode와 프로젝트 설정을 함께 확인해야 한다.

## 트러블슈팅

- `build.db` locked:
  - 고유한 `-derivedDataPath`를 붙여 다시 빌드한다.
- 경로 생성이 약하거나 비어 있음:
  - 사진 권한, 위치 메타데이터 존재 여부, 선택 사진이 `PHAsset`으로 다시 매핑되는지 확인한다.
- 권한 문구를 바꿈:
  - `Derived/InfoPlists/PhotoRava-Info.plist`, `SettingsView.swift`, `privacy-policy.md`, `support.md`를 같이 맞춘다.
- 더 많은 구조 정보가 필요함:
  - `WORKFLOW.md`가 아니라 `docs/architecture.md`를 읽는다. 전자는 저장소 워크플로 문서가 아니라 작업 템플릿이다.
