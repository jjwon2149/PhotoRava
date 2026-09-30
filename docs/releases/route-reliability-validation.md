# 경로 신뢰성 배포 검증

계획: [route-reliability-release.md](../../.omo/plans/route-reliability-release.md)

## 상태

- 구현과 자동 검증을 완료했다. 실제 기기 QA 및 배포 서명이 남아 있어 출시 승인 문서는 아니다.
- 버전/빌드 번호와 배포 서명은 변경하지 않았다.
- 기존 사용자 작업인 `AdvancedStylingAndMigrationPlan.md`, `BatchExifStampExportPlan.md`, `AppScreenshots/`는 수정하지 않는다.

## 환경

- Xcode 27.0 (27A266a), Tuist 4.31.0.
- 초기 git 확인은 Xcode 라이선스 요구로 실패했으나 이후 정상 동작했다. 이 작업에서 라이선스 동의를 실행하지 않았다.
- Xcode의 CoreSimulator 구성 요소 누락으로 목적지 조회가 실패했다. `xcodebuild -runFirstLaunch` 실행 후 `simctl list devices available`이 정상 동작했다.
- 사용 가능한 런타임에는 iOS 18.2, 18.5, 26.4, 26.5가 있다. 최소 지원 OS인 iOS 17은 현재 사용 가능한 런타임 목록에 없다.

## 자동 검증 결과

| 검증 | 결과 | 근거 |
| --- | --- | --- |
| Tuist 프로젝트 생성 | 통과 | 테스트 타깃 및 PhotoRava scheme 생성 |
| Xcode 타깃/목적지 조회 | 통과 | PhotoRavaTests 및 iOS 18.5/26.5 목적지 확인 |
| 최종 iOS 18.5 단위 테스트 | 17개 통과, 실패 0 | `/tmp/PhotoRava-test-final4-ios18.log`, `/tmp/PhotoRava-test-final4-ios18.xcresult` |
| 배포 서명 포함 Release archive | 실패 — 개발 팀 미설정 | `/tmp/PhotoRava-release-validation.log` |
| 서명 제외 Release archive | 통과 — 배포 가능한 서명본은 아님 | `/tmp/PhotoRava-release-unsigned-final.log`, `/tmp/PhotoRava-reliability-unsigned.xcarchive` |
| iOS 26.5 단위 테스트 | 17개 통과, 실패 0 | `/tmp/PhotoRava-test-final2-ios26.log`, `/tmp/PhotoRava-test-final2-ios26.xcresult` |
| 삭제 후 화면 모델 반영 추가 회귀 테스트 | 최초 충돌 재현 후 수정, 최종 전체 테스트에 포함하여 통과 | 최초 실패: `/tmp/PhotoRava-test-final-ios18.log`, 집중 재검증: `/tmp/PhotoRava-test-apply-focused2.xcresult` |
| 코드 리뷰 및 공백 오류 검사 | 남은 지적 없음 / `git diff --check` 통과 | 독립 sol Medium 리뷰 및 최종 작업 트리 검사 |

최종 자동 테스트는 순수 경로 계산 6개, 합성 기존 데이터의 디스크 복구 3개, 분석 작업 제어·저장·편집 트랜잭션 8개다. 작업 중단과 늦은 응답은 제어 가능한 비동기 입력으로 검증한다. 실제 메타데이터/OCR/AI 각 단계의 사진 처리와 실제 이전 배포 버전 저장소 업그레이드를 검증한 것으로 간주하지 않는다.

## 반영한 변경

- `RouteGeometryCalculator`, `RouteReconstructionService`: 원본 좌표 보존, 거리 계산 분리, AI 작업 취소 전파, 서비스 내부 저장 제거.
- `RouteDerivedDataRecoveryService`, `PhotoRavaApp`: 기존 보정 경로 복구, 건별 실패 격리, 시작 화면 응답성 유지.
- `RouteAnalysisCoordinator`, `AnalysisProgressView`: 취소 가능한 실행, 격리된 저장, 같은 초안의 중복 저장 방지, 저장 후 표시 실패 구분.
- `RouteEditView`, `TimelineDetailView`: 저장 전 초안 유지, 실패 시 기존 기록 보존, 삭제된 사진 객체 접근 방지, 화면 갱신 전 모든 잔존 사진 확인.
- `RouteBottomSheet`, `RouteSnapshotRenderer`: 직선거리 의미 안내, 현재 거리와 맞지 않는 요약의 공유 제외.
- `Project.swift`, `PhotoRavaTests`: 테스트 타깃 및 17개 회귀 테스트.
- SwiftData 저장 필드, EXIF 기능 구현, 앱 버전/빌드 번호는 변경하지 않았다.

## 확인된 제한

- 기존 OCR API 사용 등의 컴파일 경고는 남아 있다. 이번 변경과 무관한 전체 경고 정리는 수행하지 않았다.
- 시뮬레이터 앱 실행 명령은 성공했지만, 실제 사진·권한·전체 화면 흐름 수동 검증을 대신하지 않는다.
- 서명 제외 archive는 빌드 검증용이며 App Store 업로드용 결과물이 아니다.

## 출시 전 남은 수동 검증

- [ ] 이전 배포 버전 위에 후보 빌드를 설치하여 실제 기존 경로·사진·사용자 편집 보존 확인.
- [ ] 실제 왕복 사진의 중간 방문 장소 및 거리 확인.
- [ ] GPS 있음/없음 혼합 사진과 전부 위치 판별 불가 사진 확인.
- [ ] 분석 각 단계 취소, 재시작 및 저장 재시도 확인.
- [ ] 경로 편집/타임라인 위치 변경 후 저장·다시 열기 확인.
- [ ] EXIF 단일/배치 저장·공유 및 경로 분석 전달 확인.
- [ ] 사진 권한 거부/제한/허용, 작은 화면, 큰 글자 확인.
- [ ] iOS 17 및 실제 AI 지원/미지원 기기 확인.
- [x] App Store Connect 버전/빌드 이력 확인 및 배포 번호 확정: 1.0.4 (9).
- [x] 서명된 Release archive 및 TestFlight 업로드: [업로드 기록](1.0.4-9-testflight.md).
- [ ] TestFlight 실기기 QA (업로드 당시 Apple 처리 중).

## 배포 기준

계산·저장·취소 자동 테스트, 기존 설치 업그레이드, 실제 기기 회귀 QA를 통과하기 전에는 출시 준비 완료로 표시하지 않는다. 원본 데이터 삭제나 앱 재설치를 복구 절차로 사용하지 않는다.
