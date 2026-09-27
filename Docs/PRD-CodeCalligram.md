# Tech PRD — Code Calligram Immersive Preview (v0.1)

작성일: 2026-09-27
대상 플랫폼: visionOS 27 (주), macOS 27 / iOS 27 (개발용 프리뷰)
기술 스택: SwiftUI, RealityKit, Swift Concurrency (Combine 미사용)

---

## 1. 배경과 비전

사용자는 "코드 칼리그램(Code Calligram)"이라는 개념으로 3D 엔티티를 만든다. 칼리그램은 글자로 그림을 그리는 기법이다. 여기서는 사용자가 작성한 **소스 코드의 글자 자체**가 3D 형상의 표면과 궤적을 채운다.

사용자는 창(Window)에 배치된 텍스트 필드에 기하/알고리즘 코드를 입력한다. 앱은 그 코드를 해석해 점(point) 집합을 만든다. 각 점에는 소스 코드의 글자가 순서대로 배치된다. 사용자는 "이머시브 공간 진입" 버튼을 눌러 SkyDome 안으로 들어가고, 코드로 이뤄진 엔티티를 육안으로 확인하면서 코드를 수정한다.

용도는 아직 정해지지 않았다. 따라서 이번 버전은 **"코드 → 즉시 3D 프리뷰"라는 IDE 유사 루프**를 견고하게 만드는 데 집중한다.

## 2. 목표 / 비목표

### 목표 (v0.1)
- G1. 텍스트 필드에 코드를 입력하면 0.5초 이내에 3D 칼리그램이 갱신된다 (라이브 프리뷰).
- G2. visionOS에서 Full 이머시브 SkyDome 안에 엔티티를 표시한다.
- G3. 엔티티의 모든 시각 요소는 글리프(코드 글자)로만 구성된다.
- G4. 파싱/런타임 오류를 줄·열 번호와 함께 표시한다.
- G5. macOS에서도 같은 코드가 창 내부 프리뷰로 동작해 Vision Pro 없이 개발할 수 있다.

### 비목표 (v0.1에서 제외)
- 실제 Swift 코드 컴파일·실행 (런타임 컴파일은 App Store 및 보안 정책상 불가). 대신 자체 DSL을 사용한다.
- 파일 저장/불러오기, iCloud 동기화.
- 멀티 엔티티 편집, 씬 그래프 편집기.
- 손 제스처 기반 엔티티 직접 조작 (드래그·스케일).
- 공유(SharePlay), 내보내기(USDZ).

## 3. 사용자 시나리오

1. 앱을 실행하면 창에 코드 에디터와 샘플 코드가 보인다. 오른쪽 패널에 컨트롤과 진단이 있다.
2. macOS/iOS에서는 창 안에 프리뷰 캔버스가 있고, 드래그로 회전·핀치로 확대할 수 있다.
3. visionOS에서 "이머시브 공간 진입"을 누르면 SkyDome이 열리고 앞쪽 1.6 m, 높이 1.4 m 위치에 칼리그램 엔티티가 나타난다. 창은 그대로 남아 코드를 계속 편집할 수 있다.
4. 코드를 수정하면 디바운스 후 자동으로 재실행되고 엔티티가 교체된다.
5. 오류가 있으면 진단 패널에 `3:14 정의되지 않은 변수 'radius'` 형식으로 표시되고, 마지막으로 성공한 엔티티는 유지된다.

## 4. 기능 요구사항

### FR-1 코드 에디터
- 모노스페이스 `TextEditor`, 자동 수정/자동 대문자 비활성화.
- 샘플 코드 메뉴 (나선, 피보나치 구, 토러스 매듭, 웨이브 그리드).
- "실행" 버튼 (⌘R) 및 라이브 프리뷰 토글.

### FR-2 CalligramScript (DSL)
Swift 문법에 가까운 소형 언어. 컴파일러가 아닌 트리 워킹 인터프리터로 실행한다.

```
// 주석
let n = 900
var t = 0
for i in 0..<n {
    t = i / n
    let a = t * TAU * 5
    color(0.3 + 0.7 * t, 0.8, 1 - t)
    emit(cos(a) * 0.3, t * 0.9 - 0.45, sin(a) * 0.3)
}
```

- 타입: 숫자(Double), 불(Bool), 문자열(String, `glyph()` 인자 전용).
- 문: `let`/`var` 선언, 대입(`= += -= *= /=`), `for x in a..<b {}` / `a...b`, `if / else if / else`, 식 문(함수 호출).
- 연산자 우선순위: `||` < `&&` < `== !=` < `< <= > >=` < `+ -` < `* / %` < 단항 `- !` < `^`(거듭제곱, 우결합).
- 수학 내장: `sin cos tan asin acos atan atan2 sqrt abs pow min max floor ceil round exp log log2 sign clamp lerp hypot random seed`.
- 상수: `PI TAU E`.
- 씬 내장(부수효과):
  - `emit(x, y, z)` — 현재 색/크기로 글리프를 배치한다. 글자는 소스 코드에서 공백을 제외한 문자를 순서대로 순환한다.
  - `color(r, g, b[, a])`, `hsv(h, s, v)` — 이후 emit의 색.
  - `size(meters)` — 이후 emit의 글리프 크기.
  - `glyph("text")` — 소스 대신 지정 문자열을 순환. `glyph("")`로 복원.
- 안전 한도: emit 15,000개, 실행 스텝 500,000. 초과 시 명확한 오류로 중단하고 부분 결과를 보여준다.
- 모든 오류는 `SourceLocation(line, column)`을 갖는다.

### FR-3 렌더링 (Code Calligram)
- 글리프 아틀라스: ASCII 32~127을 16×6 셀(64 px)로 CoreText 렌더링 → `TextureResource`.
- 각 점을 하나의 쿼드(2 삼각형)로 만들고 UV로 해당 글자 셀을 매핑한다. 전체를 **단일 `MeshResource`**로 생성해 드로우 콜을 최소화한다.
- 색은 팔레트 양자화(채널 1/31 단위, 최대 48색) 후 `MeshDescriptor.materials = .perFace`로 머티리얼 인덱스를 부여한다. 머티리얼은 `UnlitMaterial` + `opacityThreshold`(알파 마스크)로 정렬 아티팩트를 피한다.
- 글리프 방향: `viewer`(모두 +Z를 향함, 기본) / `outward`(도형 중심에서 바깥을 향함).
- 옵션: 글리프 크기 배율, 자동 회전(SpinSystem).

### FR-4 SkyDome 이머시브 환경 (visionOS)
- `ImmersiveSpace(id: "CalligramSpace")`, `.immersionStyle(.full)`.
- 반경 40 m 구체에 절차적 등장방형(equirectangular) 텍스처(그라디언트 + 위경도 격자 + 희미한 코드 글자)를 `faceCulling = .front`로 안쪽에 표시.
- 바닥 y = 0에 12 m 격자 평면(투명 마스크)으로 공간 기준 제공.
- 창의 버튼으로 진입/퇴장. 시스템이 공간을 닫으면 상태를 동기화한다.

### FR-5 개발용 프리뷰 (macOS/iOS)
- 같은 `CalligramSceneController`를 창 안 `RealityView`(가상 카메라)에 표시.
- 드래그 = 궤도 회전, 핀치 = 거리 조절.

## 5. 비기능 요구사항
- NFR-1 인터프리터·메시 데이터 생성은 메인 액터 밖(`Task.detached`)에서 수행. UI는 항상 응답.
- NFR-2 15,000 글리프(60,000 정점)까지 visionOS에서 90 fps 유지 목표.
- NFR-3 코드 편집 → 화면 반영 지연 ≤ 500 ms (디바운스 450 ms 포함 시 ≤ 1 s).
- NFR-4 Combine 미사용. `@Observable`, async/await, `Task`만 사용.
- NFR-5 모든 플랫폼에서 빌드 성공 (`#if os(visionOS)` 분기 최소화).

## 6. 아키텍처

```
MyApp (App)
 ├─ WindowGroup ── ContentView
 │     ├─ CodeEditorView         (TextEditor + 샘플 메뉴)
 │     ├─ ControlPanelView       (실행, 라이브, 크기, 방향, 회전, 진단, 통계)
 │     ├─ ImmersiveToggleButton  (visionOS)
 │     └─ PreviewCanvasView      (macOS/iOS, RealityView + 가상 카메라)
 └─ ImmersiveSpace("CalligramSpace") ── ImmersiveCalligramView (visionOS)

AppModel (@Observable, MainActor)
  source, diagnostics, output, settings, revision, immersiveState
  run() ── Task.detached ── CalligramEngine.run(source)

CalligramEngine (nonisolated, Sendable)
  CalligramLexer → CalligramParser → CalligramInterpreter → CalligramProgramOutput(points)

CalligramSceneController (MainActor)
  makeScene(mode)  : SkyDome, GroundGrid, GlyphAtlas 텍스처, 피벗
  apply(output, settings) : CalligramMeshBuilder(detached) → MeshDescriptor → ModelEntity 교체

Rendering (nonisolated)
  GlyphAtlasLayout / GlyphAtlasRenderer, CalligramMeshBuilder, EnvironmentTextureRenderer
  SpinComponent / SpinSystem
```

### 데이터 흐름
1. `source` 변경 → `scheduleLiveRun()` (450 ms 디바운스, 이전 Task 취소)
2. `run()` → detached 인터프리터 → `output`, `diagnostics` 갱신, `revision += 1`
3. 뷰의 `.task(id: revision)` → `controller.apply(...)` → 메시 재생성 → 엔티티 교체

## 7. 파일 구성

```
MyApp/
  MyApp.swift, ContentView.swift
  Model/AppModel.swift, Model/CalligramRenderSettings.swift
  Language/CalligramLexer.swift, CalligramAST.swift, CalligramParser.swift,
           CalligramInterpreter.swift, CalligramEngine.swift, CalligramSamples.swift
  Rendering/GlyphAtlas.swift, CalligramMeshBuilder.swift, EnvironmentTextureRenderer.swift,
            SpinSystem.swift, CalligramSceneController.swift
  Views/CodeEditorView.swift, ControlPanelView.swift, ImmersiveCalligramView.swift,
        PreviewCanvasView.swift, ImmersiveToggleButton.swift
Docs/
  PRD-CodeCalligram.md, TASKS-CodeCalligram.md
```

## 8. 리스크와 대응
| 리스크 | 대응 |
|---|---|
| 디버그 빌드에서 인터프리터가 느림 | 스텝 한도 + detached 실행. 필요 시 바이트코드 컴파일로 전환 |
| 수천 개 투명 쿼드의 정렬 아티팩트 | 알파 마스크(`opacityThreshold`)로 블렌딩 회피 |
| 아틀라스 UV 상하 반전 | 아틀라스를 CoreGraphics 좌표(좌하단 원점)에서 계산해 RealityKit UV와 일치시킴. 실기기 확인 항목 |
| Immersive Space가 열리지 않음 | `INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES`로 멀티 씬 매니페스트 생성 |
| 사용자가 무한 루프 작성 | 스텝/emit 한도, 루프 크기 사전 검사 |

## 9. 마일스톤
- M1 (이번 세션): DSL, 렌더링 파이프라인, 창 UI, 이머시브 뷰, macOS 프리뷰, 빌드 성공.
- M2: Vision Pro 시뮬레이터/실기기 검증, 아틀라스 방향·색 확인, 성능 측정.
- M3: 저장/불러오기, 여러 엔티티, 손 제스처 이동.
- M4: 용도 결정 후 기능 확장 (교육용 도형 시각화, 코드 아트 갤러리, 데이터 시각화 등 후보).

## 10. 오픈 이슈
- 글리프 방향 기본값 (`viewer` vs `outward`)은 실기기에서 가독성 비교 후 결정.
- 한글 등 비ASCII 글자 지원 여부 (현재 `?`로 대체).
- 엔티티 배치 위치를 사용자가 옮길 수 있게 할지.
