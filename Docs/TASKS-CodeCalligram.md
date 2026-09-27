# TASKS — Code Calligram Immersive Preview

상태 표기: `[x]` 완료 · `[ ]` 미완료 · `[~]` 부분 완료 / 검증 필요

## Phase 0 — 프로젝트 준비
- [x] T0.1 PRD 작성 (`Docs/PRD-CodeCalligram.md`)
- [x] T0.2 태스크 문서 작성 (이 파일)
- [x] T0.3 Info.plist 씬 매니페스트 자동 생성 설정 (ImmersiveSpace 멀티 씬 지원) — 생성된 plist에서 `UIApplicationSupportsMultipleScenes = true` 확인
- [x] T0.4 실기기 배포 설정: 번들 ID `com.coulson.CodeCalligram`, 표시 이름 "Code Calligram", iOS 런치 스크린 자동 생성, Automatic 서명(팀 5Z8G42AVKD)

## Phase 1 — CalligramScript 언어
- [x] T1.1 토큰/위치 타입, Lexer (숫자·식별자·문자열·기호·주석·개행)
- [x] T1.2 AST 정의 (Expr / Statement)
- [x] T1.3 Parser (선언, 대입, for-range, if/else, 호출, 우선순위)
- [x] T1.4 Interpreter (스코프, 값 연산, 내장 수학 함수, emit/color/hsv/size/glyph)
- [x] T1.5 안전 한도 (emit 15k, 스텝 500k) 및 진단(줄·열) 모델
- [x] T1.6 샘플 프로그램 4종
- [ ] T1.7 Swift Testing 유닛 테스트 (Lexer/Parser/Interpreter) — 테스트 타깃 추가 필요

## Phase 2 — 렌더링 파이프라인
- [x] T2.1 글리프 아틀라스 레이아웃 + CoreText 렌더러 (ASCII 32~127, 16×6, 64 px)
- [x] T2.2 CalligramMeshBuilder (쿼드/UV/노멀/팔레트 양자화/perFace 머티리얼 인덱스)
- [x] T2.3 UnlitMaterial 알파 마스크 머티리얼 생성
- [x] T2.4 SkyDome 절차적 텍스처 + 내향 구체
- [x] T2.5 바닥 격자 평면
- [x] T2.6 SpinComponent / SpinSystem (자동 회전)
- [x] T2.7 CalligramSceneController (씬 구성, 출력 적용, 엔티티 교체, 준비 전 apply 대기열)
- [~] T2.8 아틀라스 UV 상하 방향 실기기 확인 (픽셀 검사로 이미지·UV 일치는 확인, RealityKit 표시만 미확인)

## Phase 3 — 앱 모델과 UI
- [x] T3.1 AppModel (@Observable): source, output, diagnostics, settings, revision
- [x] T3.2 라이브 프리뷰 디바운스 (Task 취소 기반, Combine 미사용)
- [x] T3.3 CodeEditorView (모노스페이스, 자동수정 끔, 샘플 메뉴)
- [x] T3.4 ControlPanelView (실행/라이브/크기/방향/회전/통계/진단)
- [x] T3.5 ContentView 적응형 레이아웃 (Regular: 3열 / Compact: 탭)

## Phase 4 — 이머시브 & 프리뷰
- [x] T4.1 ImmersiveSpace 선언 + Full 몰입 스타일
- [x] T4.2 ImmersiveToggleButton (진입/퇴장, 상태 동기화)
- [x] T4.3 ImmersiveCalligramView (RealityView + `.task(id: revision)`)
- [x] T4.4 PreviewCanvasView (macOS/iOS 가상 카메라, 드래그 궤도, 핀치 거리)

## Phase 5 — 검증
- [x] T5.1 macOS 빌드 성공 (2026-09-27)
- [x] T5.2 visionOS 시뮬레이터 빌드/실행 확인 — 창 UI·인터프리터(1,800 글리프, 19 ms) 정상. 이머시브 진입은 자동 입력 불가로 미확인
- [ ] T5.3 15k 글리프 성능 측정 (fps, 메시 생성 시간)
- [ ] T5.4 오류 케이스 UX 점검 (구문 오류, 한도 초과, 무한 루프)
- [ ] T5.5 SkyDome 안 칼리그램 엔티티 육안 확인 (Vision Pro 실기기 또는 시뮬레이터 수동 조작)

## Phase 5B — 실기기 테스트 절차
1. Xcode ▸ Signing & Capabilities에서 팀이 선택되어 있고 번들 ID `com.coulson.CodeCalligram`가 자동 등록되는지 확인 (필요 시 ID 변경).
2. **Vision Pro**: 기기를 Mac과 같은 Wi‑Fi에 두고 개발자 모드 활성화 → 실행 대상에서 기기 선택 → ⌘R. 창에서 "이머시브 공간 진입"을 눌러 SkyDome과 엔티티(앞 1.6 m, 높이 1.4 m) 확인. Digital Crown으로 나가도 버튼 상태가 복구되는지 확인.
3. **iPhone**: 탭 레이아웃(코드/프리뷰/설정)으로 동작. 프리뷰는 가상 카메라이므로 카메라 권한 요청이 없어야 함. 만약 권한 알림이 뜨면 `NSCameraUsageDescription` 추가 후 보고.
4. **iPad**: 가로/전체 화면은 3열, Split View는 탭으로 전환되는지 확인.
- [ ] T5B.1 Vision Pro 실기기 이머시브 확인
- [ ] T5B.2 iPhone 실기기 확인
- [ ] T5B.3 iPad 실기기 확인

## Phase 6 — 이후 (M3+)
- [ ] 코드 저장/불러오기, 최근 문서
- [ ] 여러 엔티티 동시 배치 및 선택
- [ ] 손 제스처로 엔티티 이동/회전/스케일
- [ ] 비ASCII 글리프 지원 (동적 아틀라스)
- [ ] 바이트코드 컴파일로 인터프리터 가속
- [ ] USDZ 내보내기
