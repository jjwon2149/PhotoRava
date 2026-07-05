# growth-ux-roadmap - Work Plan

## TL;DR (For humans)
**What you'll get:** PhotoRava의 방문 -> 시작 -> 활성화 -> 재방문 -> 공유/결제 의도 퍼널을 기준으로 첫 방문, 첫 사진 선택, 첫 분석, EXIF 저장/공유, App Store 전환을 개선하는 성장/UX 로드맵입니다. 구현자는 아래 Todo를 순서대로 실행하면 제품 코드를 바꾸기 전에 측정 기준, 화면 개선, 수동 QA 기준을 모두 알 수 있습니다.

**Why this approach:** 현재 앱은 이미 홈 빈 상태와 EXIF 빈 상태에 CTA가 있지만, 첫 가치 이해, 권한/실패 회복, 분석 대기, 공유 후 재방문 루프, 계측 이벤트가 분리되어 있습니다. 그래서 먼저 계측과 퍼널 정의를 잡고, 기존 SwiftUI 화면 안에서 가장 작은 변경으로 첫 성공 경험을 높입니다.

**What it will NOT do:** 회원가입, 계정, paywall, StoreKit, interstitial/rewarded/app-open 광고, production AdMob ID 변경, SwiftData schema 변경은 이 로드맵의 1차 범위가 아닙니다.

**Effort:** Medium
**Risk:** Medium - 앱의 첫 화면, 사진 권한, 분석/EXIF 핵심 흐름을 건드리므로 실제 기기/시뮬레이터 수동 QA가 필수입니다.
**Decisions I made for you:** 첫 활성화는 "첫 route 분석 완료" 또는 "첫 EXIF 저장/공유 완료"로 정의합니다. 기본 진입은 홈/경로 탭 유지, 별도 온보딩 캐러셀은 나중으로 미룹니다. 계측은 SDK를 넣지 않고 `docs/growth/event-taxonomy.md`와 로컬 debug-event contract까지만 정의합니다. 결제는 현재 구현 대상이 아니라 future metric placeholder로 둡니다.

Your next move: `$start-work .omo/plans/growth-ux-roadmap.md`로 실행하거나, 범위/기본 결정을 바꾸고 싶으면 이 파일을 먼저 수정하세요. Full execution detail follows below.

---

> TL;DR (machine): Medium effort, medium risk, no implementation yet; plan covers growth hypotheses, Top 10 growth/UI improvements, quick experiments, prioritized tasks, acceptance, manual QA, and measurement.

## Scope
### Must have
- 현재 UX 문제 가설.
- 사용자 증가에 가장 영향 큰 개선안 Top 10.
- UI 친숙도 개선안 Top 10.
- 빠른 실험 목록.
- 구현 우선순위.
- acceptance criteria.
- 수동 QA와 측정 방법.
- 실행 가능한 계획 파일. 실제 위치는 `ulw-plan` 규칙에 따라 `.omo/plans/growth-ux-roadmap.md`.

### Current UX Problem Hypotheses
1. 첫 방문자는 홈 빈 상태에서 "사진으로 여정을 복원"은 이해하지만, 결과물이 "지도+타임라인+EXIF 공유 이미지"까지 이어진다는 가치를 5초 안에 모두 보기는 어렵다.
2. 홈의 `+` 아이콘은 초보자에게 "새 경로 만들기"라는 의미가 숨겨져 있고, 주요 CTA가 빈 상태에서는 강하지만 route가 생긴 뒤에는 상대적으로 약해진다.
3. 사진 선택 화면은 "사진 앨범 열기 -> 경로 분석하기"의 기능은 명확하지만, 몇 장을 고르면 좋은지, GPS 없는 사진도 가능한지, 실패 시 무엇이 일어나는지 설명이 부족하다.
4. 분석 화면은 진행률과 단계가 있지만 "왜 오래 걸리는지", "GPS 없는 사진은 OCR을 쓰는지", "취소하면 저장되지 않는지" 같은 불안 해소 문구가 약하다.
5. 에러 alert는 dismiss 중심이라 사용자가 다음 액션을 알기 어렵다.
6. EXIF 탭은 독립 기능으로 이해되지만, 저장/공유 후 route 분석으로 이어지는 성장 루프가 사후 alert에 숨어 있다.
7. Settings는 진단 중심이라 초보자에게 권한 해결 안내와 가치 연결이 충분히 친숙하지 않다.
8. AdMob banner는 홈 하단에만 있지만 첫 방문 빈 상태와 CTA 근처에서 시각적 우선순위를 방해할 가능성이 있다.
9. 재방문 이유가 "저장된 route 목록" 외에 명확히 강화되지 않았다.
10. 방문/시작/활성화/재방문/공유/결제 의도 이벤트가 코드에 보이지 않아 개선 효과를 판단하기 어렵다.

### Growth Improvements Top 10
1. 홈 첫 화면의 가치 문장을 "여행 사진을 지도 경로와 공유 이미지로 바꾸기"처럼 결과물 중심으로 재작성한다.
2. route가 있어도 상단 header에 "새 사진 분석" CTA를 명시적으로 둔다.
3. 사진 선택 화면에 권장 시작점("먼저 5-20장을 골라보세요")과 GPS/OCR 가능성을 한 줄로 안내한다.
4. 첫 분석 완료 직후 route 저장 성공, 지도 보기, EXIF 스탬프 만들기, 공유하기 중 다음 행동을 명확히 제안한다.
5. EXIF 저장/공유 완료 후 "이 사진들로 경로 분석하기"를 alert가 아니라 결과 영역의 지속 CTA로 강화한다.
6. 공유 가능한 route summary 또는 route snapshot CTA를 route detail/map에 추가하는 후속 과제를 둔다.
7. App Store 스크린샷을 route 복원형과 EXIF 공유형 두 세트로 나누어 Product Page Optimization 후보를 만든다.
8. App Store Custom Product Page는 여행/블로그/카메라 사용자별 메시지를 분리하는 후속 실험으로 둔다.
9. activation 기준 이벤트를 route completed, exif saved, exif shared로 잡고 cohort별 재방문을 본다.
10. 리뷰 요청은 첫 launch/onboarding이 아니라 두 번째 성공 경험 이후에만 검토한다.

### UI Friendliness Improvements Top 10
1. 모든 주요 CTA를 동사+결과 형태로 통일한다: "사진 선택하기"보다 "사진으로 경로 만들기".
2. toolbar icon-only CTA에는 accessibility label뿐 아니라 빈 상태가 아닐 때도 가까운 문맥 텍스트를 제공한다.
3. 빈 상태는 "무엇을 할 수 있는지"보다 "무엇이 만들어지는지"를 먼저 보여준다.
4. 검색 empty state에는 검색어 삭제/새 경로 만들기 CTA를 추가한다.
5. 사진 선택 empty state에는 권한 거부/limited 권한 시 다음 행동을 보여준다.
6. 분석 loading은 현재 단계, 남은 대략 작업, 취소 영향, 사진 개수를 함께 보여준다.
7. error alert는 재시도/권한 설정/사진 다시 선택 같은 회복 CTA를 제공한다.
8. batch EXIF 실패 내역은 초보자용 요약과 전문가용 detail을 분리한다.
9. 작은 iPhone과 Dynamic Type에서 CTA, banner, bottom safe area가 겹치지 않도록 검증한다.
10. Settings의 "진단" 문구를 초보자용 설명과 개발자용 상태로 나눈다.

### Quick Experiments
1. 홈 empty headline A/B copy: "사진으로 여정을 복원하세요" vs "여행 사진을 지도 경로로 바꾸세요".
2. 홈 primary CTA: "사진 선택하기" vs "사진으로 경로 만들기".
3. 사진 선택 도움말: "5-20장 추천" 안내 추가 전후 `analysis_start` 전환율.
4. 분석 완료 후 next action sheet: map only vs map + EXIF/share CTA.
5. EXIF 저장 후 route 분석 CTA 위치: alert vs persistent result card.
6. 검색 empty state CTA 추가 전후 route 재분석 시작률.
7. App Store screenshot first frame: route map result vs before/after EXIF output.
8. Product Page Optimization: one treatment only, value proposition screenshot set.
9. Revisit prompt: saved route header copy vs no header copy.
10. Share copy: generated image share only vs image + route summary.

### Implementation Priority
- P0: Funnel event taxonomy and privacy-safe measurement plan.
- P0: First-visit/home CTA copy and empty/list-state route-start clarity.
- P0: Photo selection guidance and disabled-state explanation.
- P1: Analysis loading/error recovery.
- P1: EXIF save/share -> route-analysis loop.
- P1: Search empty and Settings permission friendliness.
- P2: App Store PPO/CPP assets and screenshot variants.
- P2: Share/revisit loops and rating prompt timing.
- P3: Payment-intent metric only after monetization strategy exists.

### Must NOT have (guardrails, anti-slop, scope boundaries)
- Do not implement product code while preparing this plan.
- Do not add sign-up, login, account creation, paywall, subscription, or StoreKit in this roadmap's first execution wave.
- Do not add interstitial, rewarded, app-open, native, or full-screen ads without explicit user approval.
- Do not commit production AdMob IDs or analytics secrets.
- Do not change `Route` or `PhotoRecord` schema for copy, CTA, or analytics display work.
- Do not make a separate onboarding carousel before improving the existing first-use path.
- Do not collect photo contents, location coordinates, OCR text, route names, or image metadata in analytics events.
- Do not add Firebase, GA4, remote analytics upload, StoreKit, or rating prompts during this plan's first execution.
- Durable planning artifacts must live under `docs/growth/`; `.omo/evidence/` is reserved for QA logs, screenshots, and command receipts.

## Verification strategy
> Zero human intervention - all verification is agent-executed.
- Test decision: none by default because the repo currently has no automated test target. Each implementation todo must run `tuist generate` plus simulator build. Add automated tests only in a later, explicitly approved test-target task.
- Build/install/launch command:
  ```sh
  set -euo pipefail
  tuist generate
  xcodebuild -workspace PhotoRava.xcworkspace -scheme PhotoRava -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/PhotoRava-growth-ux-build CODE_SIGNING_ALLOWED=NO build
  APP_PATH="$(find /tmp/PhotoRava-growth-ux-build/Build/Products/Debug-iphonesimulator -maxdepth 2 -name 'PhotoRava.app' -print -quit)"
  test -n "$APP_PATH"
  DEVICE_UDID="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone 16/ {print $2; exit}')"
  if [ -z "$DEVICE_UDID" ]; then
    DEVICE_UDID="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/ {print $2; exit}')"
  fi
  test -n "$DEVICE_UDID"
  xcrun simctl boot "$DEVICE_UDID" || true
  xcrun simctl bootstatus "$DEVICE_UDID" -b
  xcrun simctl install "$DEVICE_UDID" "$APP_PATH"
  xcrun simctl launch "$DEVICE_UDID" com.mabataki.smithwrld999.PhotoRava
  ```
- Default QA device: `iPhone 16` simulator. If unavailable, use the first available iPhone simulator returned by `xcrun simctl list devices available` and record the exact device name/UDID in `.omo/evidence/task-9-growth-ux-roadmap/qa-notes.md`. Small-screen failure QA should use an iPhone SE-class simulator or the smallest installed iPhone simulator.
- Manual QA surface: iOS Simulator or physical iPhone. Capture screenshots/video under `.omo/evidence/task-N-growth-ux-roadmap/` where `N` is the todo number.
- Photo-library QA prerequisite: before photo-selection or EXIF QA, seed the booted simulator with sample images using `MEDIA_FILES="$(find AppScreenshots marketing-screenshots -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \\) -print)" && test -n "$MEDIA_FILES" && printf '%s\n' "$MEDIA_FILES" | xargs xcrun simctl addmedia "$DEVICE_UDID"`; if no valid media exists, record the missing fixture in the task evidence and use any available simulator photo library sample.
- Permission-state QA prerequisite: reset app permissions with `xcrun simctl privacy "$DEVICE_UDID" reset all com.mabataki.smithwrld999.PhotoRava`; for denied-state QA use `xcrun simctl privacy "$DEVICE_UDID" revoke photos com.mabataki.smithwrld999.PhotoRava` and record the command output.
- Metrics verification: produce `docs/growth/event-taxonomy.md`; no SDK or remote upload. If later implementation adds a local debug logger, verify only local console/debug output without sending private photo/location payloads.
- External references:
  - Apple Product Page Optimization: `https://developer.apple.com/app-store/product-page-optimization/`
  - Apple Custom Product Pages: `https://developer.apple.com/app-store/custom-product-pages/`
  - Firebase Analytics events for iOS: `https://firebase.google.com/docs/analytics/ios/events`
  - Apple HIG onboarding/loading/ratings pages: JS-rendered, use as design principles only.

## Execution strategy
### Parallel execution waves
> Target 5-8 todos per wave. Fewer than 3 (except the final) means you under-split.
- Wave 1: Measurement and first-use copy foundation.
- Wave 2: Core route-analysis UX and recovery states.
- Wave 3: EXIF growth loop, search/settings friendliness, App Store experiment prep.
- Wave 4: Manual QA, measurement review, release readiness.

### Durable artifact paths
- Event taxonomy: `docs/growth/event-taxonomy.md`
- App Store experiment brief: `docs/growth/app-store-experiments.md`
- Revisit/share/rating/payment-intent rules: `docs/growth/revisit-share-rules.md`
- Final execution report: `docs/growth/growth-ux-execution-report.md`
- QA evidence: `.omo/evidence/task-N-growth-ux-roadmap/`

### Dependency matrix
| Todo | Depends on | Blocks | Can parallelize with |
| --- | --- | --- | --- |
| 1 | none | 2, 3, 4, 5, 6, 7, 8 | none |
| 2 | 1 | 4, 9 | 3 |
| 3 | 1 | 4, 5, 9 | 2 |
| 4 | 2, 3 | 9 | 5, 6 |
| 5 | 3 | 9 | 4, 6 |
| 6 | 1 | 9 | 4, 5, 7 |
| 7 | 1 | 9 | 6, 8 |
| 8 | 1 | 9 | 6, 7 |
| 9 | 2, 3, 4, 5, 6, 7, 8 | 10 | none |
| 10 | 9 | final verification | none |

## Todos
> Implementation + Test = ONE todo. Never separate.
<!-- APPEND TASK BATCHES BELOW THIS LINE WITH edit/apply_patch - never rewrite the headers above. -->
- [x] 1. Define privacy-safe growth funnel and event taxonomy.
  What to do / Must NOT do: Create `docs/growth/event-taxonomy.md`. Define events for visit, start, activation, revisit, share, and payment intent. Include a local debug-event contract section that later code can implement without choosing a third-party SDK. Must not add SDKs, secrets, product-code logging, Firebase/GA4, or remote upload yet. Must not log photo contents, precise coordinates, OCR text, route names, or image metadata.
  Parallelization: Wave 1 | Blocked by: none | Blocks: 2, 3, 4, 5, 6, 7, 8
  References: `README.md`; `docs/architecture.md`; `docs/workflows.md`; `PhotoRava/PhotoRava/Views/Home/RouteListView.swift:49`; `PhotoRava/PhotoRava/Views/PhotoPicker/PhotoSelectionView.swift:17`; `PhotoRava/PhotoRava/Views/Analysis/AnalysisProgressView.swift:24`; `PhotoRava/PhotoRava/Views/Exif/ExifStampRootView.swift:137`; Firebase Analytics events docs.
  Acceptance criteria (agent-executable): The taxonomy lists event name, trigger, parameters, privacy classification, funnel stage, and success metric for every required stage: `app_visit`, `route_start_tap`, `photo_picker_open`, `analysis_start`, `analysis_complete`, `analysis_error`, `exif_start`, `exif_save_complete`, `exif_share_complete`, `revisit_saved_route`, `share_intent`, `payment_intent_placeholder`. It also states "No remote analytics SDK in this plan" and gives a local debug-event payload shape.
  QA scenarios (name the exact tool + invocation): happy: `mkdir -p .omo/evidence/task-1-growth-ux-roadmap && rg -n "app_visit|analysis_complete|payment_intent_placeholder|No remote analytics SDK" docs/growth/event-taxonomy.md | tee .omo/evidence/task-1-growth-ux-roadmap/qa.txt` must find all stage markers. failure: `bash -lc 'set -o pipefail; if rg -n "Firebase.configure|Analytics.logEvent|precise coordinate payload|raw OCR payload|raw EXIF payload|image data payload" docs/growth/event-taxonomy.md | tee -a .omo/evidence/task-1-growth-ux-roadmap/qa.txt; then exit 1; else exit 0; fi'` must exit 0, proving the taxonomy does not instruct unsafe payloads or SDK use.
  Commit: Y | `docs(growth): define privacy-safe funnel taxonomy`

- [x] 2. Improve first-visit home value comprehension within existing `RouteListView`.
  What to do / Must NOT do: Update home empty-state copy and CTA to explain the result in 5 seconds: photos become route map, timeline, and shareable EXIF output. Preserve current SwiftUI structure, `NavigationStack`, `searchable`, AdMob safe-area inset, Dynamic Type handling, and `PhotosPicker` sheet behavior. Do not add a separate onboarding carousel.
  Parallelization: Wave 1 | Blocked by: 1 | Blocks: 4, 9
  References: `PhotoRava/PhotoRava/Views/Home/RouteListView.swift:49`; `:67`; `:71`; `:73`; `:75`; `:152`; `:178`; `:185`; `:197`; `PhotoRava/PhotoRava/Views/Ads/RouteListAdBannerView.swift`.
  Acceptance criteria (agent-executable): First empty screen has one primary value headline, one supporting line naming route map/timeline/EXIF output, and one primary CTA with a verb+result label. In the `home-empty.png` screenshot, those three elements are visible in the first viewport without scrolling, satisfying the 5-second value-understanding check. Existing search, plus button, route list, and banner behavior still compile.
  QA scenarios (name the exact tool + invocation): happy: run the build/install/launch command from `Verification strategy`, then run `mkdir -p .omo/evidence/task-2-growth-ux-roadmap && xcrun simctl io booted screenshot .omo/evidence/task-2-growth-ux-roadmap/home-empty.png`; the first viewport must show the new headline, supporting result copy, and CTA. failure: with no saved routes on the smallest installed iPhone simulator, set an accessibility Dynamic Type size in Simulator Settings, relaunch, then run `xcrun simctl io booted screenshot .omo/evidence/task-2-growth-ux-roadmap/home-empty-accessibility.png`; CTA must not overlap the bottom banner.
  Commit: Y | `feat(ux): clarify first-run route value`

- [x] 3. Make photo selection guidance and disabled states beginner-friendly.
  What to do / Must NOT do: Update `PhotoSelectionView` empty and grid states so users know how many photos to pick, that GPS photos work best, and that GPS-less photos may still use OCR/fallback. Explain why "경로 분석하기" is disabled when zero photos are selected. Do not change the max selection count or metadata loading behavior.
  Parallelization: Wave 1 | Blocked by: 1 | Blocks: 4, 5, 9
  References: `PhotoRava/PhotoRava/Views/PhotoPicker/PhotoSelectionView.swift:17`; `:31`; `:40`; `:69`; `:84`; `:95`; `:115`; `:122`; `:130`; `docs/workflows.md` manual route verification.
  Acceptance criteria (agent-executable): Empty picker state includes a beginner hint, selected grid state includes selected count context, disabled analyze CTA has visible helper text, and no selected-photo logic changes.
  QA scenarios (name the exact tool + invocation): happy: run the build/install/launch command from `Verification strategy`, then `mkdir -p .omo/evidence/task-3-growth-ux-roadmap`, tap the home primary CTA in Simulator, run `xcrun simctl io booted screenshot .omo/evidence/task-3-growth-ux-roadmap/photo-empty.png`, select at least 3 photos through PhotosPicker, then run `xcrun simctl io booted screenshot .omo/evidence/task-3-growth-ux-roadmap/photo-selected.png`; both states must show understandable next action. failure: with zero selected photos, run `xcrun simctl io booted screenshot .omo/evidence/task-3-growth-ux-roadmap/photo-zero-disabled.png`; analysis must be disabled and explain why. Record selected count and device name in `.omo/evidence/task-3-growth-ux-roadmap/qa-notes.md`.
  Commit: Y | `feat(ux): guide first photo selection`

- [x] 4. Improve analysis loading, cancellation, and error recovery.
  What to do / Must NOT do: Update `AnalysisProgressView` copy/states to reduce uncertainty: current step, processed count, privacy/local processing, cancellation effect, and recovery options on error. Keep the existing route completion handoff to `RouteMapView`. Do not change OCR, metadata extraction, route reconstruction, or SwiftData schema.
  Parallelization: Wave 2 | Blocked by: 2, 3 | Blocks: 9
  References: `PhotoRava/PhotoRava/Views/Analysis/AnalysisProgressView.swift:24`; `:36`; `:40`; `:52`; `:60`; `:78`; `:84`; `:109`; `:155`; `docs/workflows.md` route flow manual checks.
  Acceptance criteria (agent-executable): Loading state explains what is happening and remains readable on small iPhone; cancel button has a clear accessibility label/hint; error alert has next-action choices such as retry/select again/dismiss depending on feasible state.
  QA scenarios (name the exact tool + invocation): happy: run the build/install/launch command from `Verification strategy`, then `mkdir -p .omo/evidence/task-4-growth-ux-roadmap`, start route analysis with GPS photos in Simulator, run `xcrun simctl io booted screenshot .omo/evidence/task-4-growth-ux-roadmap/analysis-loading.png`, wait for completion, then run `xcrun simctl io booted screenshot .omo/evidence/task-4-growth-ux-roadmap/analysis-complete.png`. failure: reproduce a permission-denied/no-readable-photo path by denying Photos access in iOS Settings, relaunching with `xcrun simctl launch booted com.mabataki.smithwrld999.PhotoRava`, attempting route analysis, and running `xcrun simctl io booted screenshot .omo/evidence/task-4-growth-ux-roadmap/analysis-error-or-permission-recovery.png`; user must see retry/select-again/settings recovery. If PhotosPicker still permits direct item loading, record that in `.omo/evidence/task-4-growth-ux-roadmap/qa-notes.md` and use the Settings denied-state screenshot as the failure evidence.
  Commit: Y | `feat(ux): clarify analysis progress and recovery`

- [x] 5. Strengthen EXIF save/share to route-analysis growth loop.
  What to do / Must NOT do: Make EXIF empty state and export result state explain the two outcomes: create a stamped image and optionally analyze those same photos as a route. Convert hidden/ephemeral post-save suggestions into clear persistent context where feasible. Do not alter renderer output, file formats, batch export limits, or route handoff behavior unless required for copy placement.
  Parallelization: Wave 2 | Blocked by: 3 | Blocks: 9
  References: `PhotoRava/PhotoRava/Views/Exif/ExifStampRootView.swift:137`; `:150`; `:154`; `:166`; `:180`; `:1438`; `:1458`; `:1464`; `:1530`; `:1609`; `AppState.swift` transfer-to-analysis behavior.
  Acceptance criteria (agent-executable): EXIF first-use copy names output clearly; save/share buttons remain disabled/enabled as before; after batch/single export success, route-analysis CTA is visible and understandable without depending only on an alert.
  QA scenarios (name the exact tool + invocation): happy: run the build/install/launch command from `Verification strategy`, then `mkdir -p .omo/evidence/task-5-growth-ux-roadmap`, select one EXIF photo in Simulator, run `xcrun simctl io booted screenshot .omo/evidence/task-5-growth-ux-roadmap/exif-single.png`, save/share, then run `xcrun simctl io booted screenshot .omo/evidence/task-5-growth-ux-roadmap/exif-result.png`; batch select multiple photos and run `xcrun simctl io booted screenshot .omo/evidence/task-5-growth-ux-roadmap/exif-batch-result.png`. failure: deny Photos add/write permission in iOS Settings before save, relaunch, attempt EXIF save, then run `xcrun simctl io booted screenshot .omo/evidence/task-5-growth-ux-roadmap/exif-save-permission-recovery.png`; UI must show friendly recovery. If a batch failure is available, also capture `.omo/evidence/task-5-growth-ux-roadmap/exif-batch-failure.png`.
  Commit: Y | `feat(ux): connect exif export to route analysis`

- [x] 6. Add friendly recovery for search empty, permissions, and settings diagnostics.
  What to do / Must NOT do: Improve search empty state with "검색어 지우기" and "새 경로 만들기" actions. Adjust Settings copy so permission rows explain why access matters and diagnostics are understandable to non-developers. If permission wording changes, keep `PhotoRava-Info.plist`, `privacy-policy.md`, and `support.md` aligned. Do not weaken privacy posture.
  Parallelization: Wave 3 | Blocked by: 1 | Blocks: 9
  References: `PhotoRava/PhotoRava/Views/Home/RouteListView.swift:56`; `:73`; `:260` search empty state; `PhotoRava/PhotoRava/Views/Home/SettingsView.swift`; `PhotoRava/PhotoRava/Derived/InfoPlists/PhotoRava-Info.plist`; `PhotoRava/PhotoRava/privacy-policy.md`; `PhotoRava/PhotoRava/support.md`.
  Acceptance criteria (agent-executable): Search empty state offers recovery; Settings uses Korean app language consistently or intentionally changes the title from "Settings"; permission/public docs remain aligned if copy changes.
  QA scenarios (name the exact tool + invocation): happy: run the build/install/launch command from `Verification strategy`, then `mkdir -p .omo/evidence/task-6-growth-ux-roadmap`, enter a no-result search query in Simulator, run `xcrun simctl io booted screenshot .omo/evidence/task-6-growth-ux-roadmap/search-empty.png`; open Settings tab and run `xcrun simctl io booted screenshot .omo/evidence/task-6-growth-ux-roadmap/settings.png`. failure: deny photo permission in iOS Settings, relaunch PhotoRava with `xcrun simctl launch booted com.mabataki.smithwrld999.PhotoRava`, open Settings tab, then run `xcrun simctl io booted screenshot .omo/evidence/task-6-growth-ux-roadmap/settings-denied.png`; Settings must show recovery path without misleading copy.
  Commit: Y | `feat(ux): improve empty and permission recovery`

- [x] 7. Prepare App Store growth experiment assets and hypotheses.
  What to do / Must NOT do: Create `docs/growth/app-store-experiments.md` as a docs-only experiment brief for App Store Product Page Optimization and Custom Product Pages. Define screenshots/copy variants for route-first users and EXIF-first users using existing `marketing-screenshots` assets. Do not upload to App Store Connect in this task.
  Parallelization: Wave 3 | Blocked by: 1 | Blocks: 9
  References: `README.md` Product Snapshot; `marketing-screenshots/`; `docs/workflows.md` marketing screenshot generation; Apple Product Page Optimization; Apple Custom Product Pages.
  Acceptance criteria (agent-executable): Brief includes hypothesis, audience, creative changes, success metric, minimum run rule, and rollback/apply decision for at least two experiments: default product page screenshot order and custom product page by audience.
  QA scenarios (name the exact tool + invocation): happy: `mkdir -p .omo/evidence/task-7-growth-ux-roadmap && rg -n "Hypothesis|Metric|Route-first|EXIF-first|Rollback" docs/growth/app-store-experiments.md | tee .omo/evidence/task-7-growth-ux-roadmap/qa.txt` returns all required sections. failure: `bash -lc 'set -o pipefail; if rg -n "uploaded|submitted|App Store Connect 변경 완료|PPO started|CPP published" docs/growth/app-store-experiments.md | tee -a .omo/evidence/task-7-growth-ux-roadmap/qa.txt; then exit 1; else exit 0; fi'` must exit 0, proving the doc does not claim console changes were performed.
  Commit: Y | `docs(growth): plan app store experiments`

- [x] 8. Define revisit, share, rating, and payment-intent rules.
  What to do / Must NOT do: Create `docs/growth/revisit-share-rules.md` defining when to ask users to share, revisit saved routes, request App Store rating, and record payment intent. Do not implement StoreKit, rating prompt, or paid feature UI yet.
  Parallelization: Wave 3 | Blocked by: 1 | Blocks: 9
  References: `PhotoRava/PhotoRava/Views/Timeline/TimelineDetailView.swift`; `PhotoRava/PhotoRava/Views/Map/RouteMapView.swift`; `PhotoRava/PhotoRava/Views/Map/RouteBottomSheet.swift`; `PhotoRava/PhotoRava/Views/Exif/ExifStampRootView.swift:1530`; `PhotoRava/PhotoRava/Views/Exif/ExifStampRootView.swift:1609`; Apple ratings and reviews HIG.
  Acceptance criteria (agent-executable): Rules state that rating prompt is never shown on first launch/onboarding; share prompts happen only after successful user-created output; payment intent is measured only as user interest, not monetization implementation.
  QA scenarios (name the exact tool + invocation): happy: `mkdir -p .omo/evidence/task-8-growth-ux-roadmap && rg -n "first launch|successful|payment intent|share" docs/growth/revisit-share-rules.md | tee .omo/evidence/task-8-growth-ux-roadmap/qa.txt` returns the rules. failure: `bash -lc 'set -o pipefail; if rg -n "implement StoreKit|show paywall|start subscription|request payment|SKStoreReviewController.requestReview" docs/growth/revisit-share-rules.md | tee -a .omo/evidence/task-8-growth-ux-roadmap/qa.txt; then exit 1; else exit 0; fi'` must exit 0, proving the rules do not implement monetization or rating prompts.
  Commit: Y | `docs(growth): define revisit and share rules`

- [x] 9. Run full simulator visual and funnel QA across route and EXIF paths.
  What to do / Must NOT do: After Todos 2-8, run a full build and capture user-facing evidence for first visit, route start, photo selection, analysis loading/error/completion, EXIF start/save/share, Settings permission state, and search empty state. Do not rely on build logs alone.
  Parallelization: Wave 4 | Blocked by: 2, 3, 4, 5, 6, 7, 8 | Blocks: 10
  References: `docs/workflows.md` manual verification; all changed files from Todos 2-8; `docs/growth/event-taxonomy.md`.
  Acceptance criteria (agent-executable): Build exits 0; every required screenshot/video exists; QA notes map each capture to one funnel stage and one acceptance criterion.
  QA scenarios (name the exact tool + invocation): happy: run the build/install/launch command from `Verification strategy`, then `mkdir -p .omo/evidence/task-9-growth-ux-roadmap` and capture funnel screenshots with `xcrun simctl io booted screenshot .omo/evidence/task-9-growth-ux-roadmap/home-empty.png`, `xcrun simctl io booted screenshot .omo/evidence/task-9-growth-ux-roadmap/photo-selection.png`, `xcrun simctl io booted screenshot .omo/evidence/task-9-growth-ux-roadmap/analysis-loading.png`, `xcrun simctl io booted screenshot .omo/evidence/task-9-growth-ux-roadmap/exif-export.png`, and `xcrun simctl io booted screenshot .omo/evidence/task-9-growth-ux-roadmap/settings.png`; write the simulator name, iOS version, and app install path to `.omo/evidence/task-9-growth-ux-roadmap/qa-notes.md`. failure: repeat on the smallest installed iPhone simulator with accessibility Dynamic Type and denied/limited photo permission; capture `home-empty-small-accessibility.png`, `settings-denied.png`, and any failure/recovery screen. No CTA overlap, dead-end error, or hidden recovery action is allowed.
  Commit: N | verification only

- [x] 10. Create final growth/UX decision report.
  What to do / Must NOT do: Create `docs/growth/growth-ux-execution-report.md` summarizing which hypotheses shipped, which metrics are ready to instrument, what evidence passed, and what remains deferred. Do not claim App Store/Firebase/AdMob console changes unless actually performed in a later approved task.
  Parallelization: Wave 4 | Blocked by: 9 | Blocks: final verification
  References: `.omo/evidence/task-*/`; changed files from the implementation branch; this plan.
  Acceptance criteria (agent-executable): Report contains shipped changes, metric mapping, QA evidence links, risks, and next experiments. It explicitly names any unverified states.
  QA scenarios (name the exact tool + invocation): happy: `mkdir -p .omo/evidence/task-10-growth-ux-roadmap && rg -n "Shipped|Metrics|Evidence|Risks|Deferred" docs/growth/growth-ux-execution-report.md | tee .omo/evidence/task-10-growth-ux-roadmap/qa.txt` returns all required sections. failure: `bash -lc 'set -o pipefail; if rg -n "completed in App Store Connect|Firebase live|production payment|remote analytics enabled|PPO running" docs/growth/growth-ux-execution-report.md | tee -a .omo/evidence/task-10-growth-ux-roadmap/qa.txt; then exit 1; else exit 0; fi'` must exit 0, proving the report contains no false external-state claims.
  Commit: Y | `docs(growth): summarize ux roadmap execution`

## Final verification wave
> Runs in parallel after ALL todos. ALL must APPROVE. Surface results and wait for the user's explicit okay before declaring complete.
- [x] F1. Plan compliance audit: run `mkdir -p .omo/evidence/final-growth-ux-roadmap && rg -n "app_visit|route_start_tap|analysis_complete|exif_share_complete|payment_intent_placeholder" docs/growth/event-taxonomy.md | tee .omo/evidence/final-growth-ux-roadmap/F1-plan-compliance.txt`; then verify every todo acceptance criterion is satisfied, no Must NOT guardrail is violated, and event taxonomy covers visit -> start -> activation -> revisit -> share/payment.
- [x] F2. Code quality review: run `git diff --check | tee .omo/evidence/final-growth-ux-roadmap/F2-diff-check.txt` and inspect changed Swift/docs for local style, no schema changes unless explicitly approved, no production secrets, no new intrusive ad formats. Save notes to `.omo/evidence/final-growth-ux-roadmap/F2-code-quality.md`.
- [x] F3. Real manual QA: waived by user for capture QA; no new final-wave screenshots were captured. The waiver is recorded in `.omo/evidence/final-growth-ux-roadmap/F3-manual-qa-waived.md`.
- [x] F4. Scope fidelity: run `git diff --name-only | tee .omo/evidence/final-growth-ux-roadmap/F4-files.txt`; then run `bash -lc 'set -o pipefail; git diff -U0 -- . ":!*.png" ":!*.jpg" ":!*.jpeg" | rg -n "Firebase.configure|Analytics.logEvent|StoreKit|SKStoreReviewController|GADInterstitial|RewardedAd|AppOpenAd|NativeAd|ca-app-pub-" | tee .omo/evidence/final-growth-ux-roadmap/F4-scope-fidelity.txt; status=${PIPESTATUS[1]}; test "$status" -eq 1 || test "$status" -eq 0'` and inspect `F4-scope-fidelity.txt`: it must be empty or contain only explicit "do not add" guardrails in docs. This diff-scoped search avoids false positives from existing demo AdMob IDs while still catching newly added SDKs, production IDs, StoreKit, or ad formats.

## Commit strategy
- Use small commits by wave:
  1. `docs(growth): define privacy-safe funnel taxonomy`
  2. `feat(ux): clarify first-run route value`
  3. `feat(ux): guide first photo selection`
  4. `feat(ux): clarify analysis progress and recovery`
  5. `feat(ux): connect exif export to route analysis`
  6. `feat(ux): improve empty and permission recovery`
  7. `docs(growth): plan app store experiments`
  8. `docs(growth): define revisit and share rules`
  9. `docs(growth): summarize ux roadmap execution`
- Do not commit verification-only Todo 9 unless it produces durable docs/evidence that should be tracked.
- Final handoff should include build/install/launch command result, simulator evidence paths, metric taxonomy path, final verification artifacts, and the exact simulator device/iOS version used.

## Success criteria
- A first-time user can understand within 5 seconds that PhotoRava turns photos into a route map/timeline and EXIF-stamped shareable output.
- A first-time user can reach the core action from home to photo selection to analysis without relying on icon-only interpretation.
- Empty, loading, error, permission, search, EXIF, and small-screen states provide a clear next action.
- Growth metrics cover: visit -> start -> activation -> revisit -> share/payment intent.
- No analytics plan collects private photo contents, precise location, OCR text, route names, or raw EXIF values.
- Existing route analysis and EXIF export flows still build and pass manual QA.
- AdMob remains limited to existing route-list banner behavior unless separately approved.
- App Store growth experiments are documented as hypotheses with metrics, not claimed as already run.
