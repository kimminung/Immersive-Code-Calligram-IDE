import Foundation

/// Built-in example programs shown in the editor's sample menu.
nonisolated struct CalligramSample: Sendable, Identifiable, Hashable {
    let id: String
    let title: String
    let category: CalligramSampleCategory
    /// One-line description of the mathematics behind the shape.
    let summary: String
    let source: String
}

nonisolated enum CalligramSampleCategory: String, Sendable, CaseIterable, Identifiable {
    case curves = "곡선 · 매듭"
    case surfaces = "곡면"
    case attractors = "끌개 · 카오스"
    case fractals = "프랙탈 · IFS"
    case fields = "격자 · 필드"
    case fourD = "4차원 · 위상"
    case typography = "타이포그래피"

    var id: String { rawValue }
}

nonisolated enum CalligramSamples {
    static let all: [CalligramSample] = [
        // 곡선 · 매듭
        dnaHelix, torusKnot, trefoilTube, lissajousKnot, maurerRose, heartSolid,
        // 곡면
        mobiusStrip, kleinBottle, sphericalHarmonics, supershape, diniSurface, breatherSurface, enneperSurface, seashell,
        // 끌개 · 카오스
        lorenzAttractor, aizawaAttractor, thomasAttractor, cliffordAttractor,
        // 프랙탈 · IFS
        juliaSet, mengerSponge, sierpinskiTetrahedron, barnsleyFern,
        // 격자 · 필드
        waveGrid, fibonacciSphere, phyllotaxis, spiralGalaxy,
        // 4차원 · 위상
        hopfFibration, cliffordTorus,
        // 타이포그래피
        glyphCylinder,
    ]

    static func samples(in category: CalligramSampleCategory) -> [CalligramSample] {
        all.filter { $0.category == category }
    }

    /// Sample loaded when the app starts.
    static var initial: CalligramSample { dnaHelix }

    // MARK: - 곡선 · 매듭

    static let dnaHelix = CalligramSample(
        id: "dna",
        title: "DNA 이중 나선",
        category: .curves,
        summary: "두 가닥의 나선 r(t)e^{iθ}에 염기쌍 가로대를 선형 보간으로 연결",
        source: """
        // DNA 이중 나선: 두 가닥 + 염기쌍 가로대
        // 가닥: (r cos a, y, r sin a), 반대 가닥은 위상 π만큼 이동
        let n = 420
        let turns = 4.5
        let rungEvery = 7
        for i in 0..<n {
            let t = i / n
            let a = t * TAU * turns
            let r = 0.22 + 0.04 * sin(t * TAU * 3)
            let y = t * 0.9 - 0.45
            hsv(0.55 + 0.2 * t, 0.8, 1)
            size(0.026)
            emit(cos(a) * r, y, sin(a) * r)
            hsv(0.02 + 0.1 * t, 0.85, 1)
            emit(cos(a + PI) * r, y, sin(a + PI) * r)
            // 일정 간격마다 두 가닥 사이를 잇는 염기쌍
            if i % rungEvery == 0 {
                for k in 1..<8 {
                    let u = k / 8
                    let x = cos(a) * r * (1 - 2 * u)
                    let z = sin(a) * r * (1 - 2 * u)
                    hsv(0.3 + 0.4 * u, 0.5, 0.95)
                    size(0.016)
                    emit(x, y, z)
                }
            }
        }
        """)

    static let torusKnot = CalligramSample(
        id: "knot",
        title: "토러스 매듭 (3,7)",
        category: .curves,
        summary: "r = R + ρ cos(qt), 위치 (r cos pt, ρ sin qt, r sin pt)인 (p,q)-토러스 매듭",
        source: """
        // (p, q) 토러스 매듭: 도넛 표면을 p바퀴 돌며 구멍을 q번 통과
        let n = 2400
        let p = 3
        let q = 7
        let R = 0.27
        let rho = 0.11
        for i in 0..<n {
            let t = i / n * TAU
            let r = R + rho * cos(q * t)
            hsv(t / TAU, 0.7, 1)
            size(0.016 + 0.014 * (1 + cos(q * t)) / 2)
            emit(r * cos(p * t), rho * sin(q * t), r * sin(p * t))
        }
        """)

    static let trefoilTube = CalligramSample(
        id: "trefoil-tube",
        title: "세잎 매듭 튜브 (프레네 틀)",
        category: .curves,
        summary: "곡선의 접선 T를 수치 미분으로 구하고 N = T×ŷ, B = T×N 틀 위에 원을 그려 튜브를 만듦",
        source: """
        // 세잎 매듭 c(t) = (sin t + 2 sin 2t, cos t − 2 cos 2t, −sin 3t)
        // 각 지점에서 접선 T와 법선/종법선 N, B를 만들어 튜브 단면 원을 배치
        let segments = 220
        let ring = 14
        let tube = 0.075
        let scale = 0.13
        let h = 0.01
        for i in 0..<segments {
            let t = i / segments * TAU
            // 현재 점 p
            let px = (sin(t) + 2 * sin(2 * t)) * scale
            let py = (cos(t) - 2 * cos(2 * t)) * scale
            let pz = -sin(3 * t) * scale
            // 조금 앞의 점 q → 접선 T ≈ (q − p)/|q − p|
            let qx = (sin(t + h) + 2 * sin(2 * (t + h))) * scale
            let qy = (cos(t + h) - 2 * cos(2 * (t + h))) * scale
            let qz = -sin(3 * (t + h)) * scale
            let dx = qx - px
            let dy = qy - py
            let dz = qz - pz
            let len = sqrt(dx * dx + dy * dy + dz * dz)
            let tx = dx / len
            let ty = dy / len
            let tz = dz / len
            // N = normalize(T × ŷ)
            let nx0 = ty * 0 - tz * 1
            let ny0 = tz * 0 - tx * 0
            let nz0 = tx * 1 - ty * 0
            let nlen = sqrt(nx0 * nx0 + ny0 * ny0 + nz0 * nz0) + 0.000001
            let nx = nx0 / nlen
            let ny = ny0 / nlen
            let nz = nz0 / nlen
            // B = T × N
            let bx = ty * nz - tz * ny
            let by = tz * nx - tx * nz
            let bz = tx * ny - ty * nx
            for j in 0..<ring {
                let a = j / ring * TAU
                let ox = tube * (cos(a) * nx + sin(a) * bx)
                let oy = tube * (cos(a) * ny + sin(a) * by)
                let oz = tube * (cos(a) * nz + sin(a) * bz)
                hsv(t / TAU + 0.15 * sin(a), 0.75, 0.85 + 0.15 * cos(a))
                size(0.02)
                emit(px + ox, py + oy, pz + oz)
            }
        }
        """)

    static let lissajousKnot = CalligramSample(
        id: "lissajous",
        title: "리사주 매듭 (3,4,7)",
        category: .curves,
        summary: "x = sin(3t+δ₁), y = sin(4t+δ₂), z = sin(7t): 세 진동수의 3차원 리사주 곡선",
        source: """
        // 3D 리사주 매듭: 세 축이 서로 다른 진동수로 흔들림
        let n = 3600
        let a = 3
        let b = 4
        let c = 7
        let delta1 = 0.7
        let delta2 = 0.2
        let A = 0.42
        for i in 0..<n {
            let t = i / n * TAU
            let x = sin(a * t + delta1)
            let y = sin(b * t + delta2)
            let z = sin(c * t)
            hsv(t / TAU, 0.75, 1)
            size(0.014 + 0.012 * (0.5 + 0.5 * cos(c * t)))
            emit(A * x, A * y, A * z)
        }
        """)

    static let maurerRose = CalligramSample(
        id: "maurer",
        title: "마우러 장미 (6, 71°)",
        category: .curves,
        summary: "장미 곡선 r = sin(kθ) 위의 점을 71° 간격으로 이어 만든 현(弦)의 집합, 높이는 r에 비례",
        source: """
        // 마우러 장미: θ_k = 71°·k 에서 r = sin(6θ) 인 점들을 차례로 잇는다
        let petals = 6
        let step = 71
        let chords = 360
        let perChord = 10
        let A = 0.45
        for k in 0..<chords {
            let t0 = k * step * PI / 180
            let t1 = (k + 1) * step * PI / 180
            let r0 = sin(petals * t0)
            let r1 = sin(petals * t1)
            let x0 = r0 * cos(t0)
            let z0 = r0 * sin(t0)
            let x1 = r1 * cos(t1)
            let z1 = r1 * sin(t1)
            for j in 0..<perChord {
                let u = j / perChord
                let r = lerp(r0, r1, u)
                hsv(0.85 + 0.2 * abs(r), 0.7, 1)
                size(0.014 + 0.012 * abs(r))
                emit(A * lerp(x0, x1, u), 0.16 * r, A * lerp(z0, z1, u))
            }
        }
        """)

    static let heartSolid = CalligramSample(
        id: "heart",
        title: "심장 곡선 입체",
        category: .curves,
        summary: "x = 16 sin³t, y = 13 cos t − 5 cos 2t − 2 cos 3t − cos 4t 를 층별로 축소해 쌓은 입체",
        source: """
        // 하트 곡선을 z 방향으로 층층이 쌓되, 각 층을 반원 프로파일로 축소해 볼륨감을 줌
        let layers = 40
        let perLayer = 96
        let S = 0.024
        for l in 0..<layers {
            let v = l / (layers - 1) * 2 - 1
            let shrink = sqrt(1 - v * v)
            for i in 0..<perLayer {
                let t = i / perLayer * TAU
                let x = 16 * sin(t) ^ 3
                let y = 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)
                hsv(0.96 + 0.06 * v, 0.55 + 0.4 * shrink, 1)
                size(0.014 + 0.012 * shrink)
                emit(x * S * shrink, (y + 2) * S * shrink, v * 0.22)
            }
        }
        """)

    // MARK: - 곡면

    static let mobiusStrip = CalligramSample(
        id: "mobius",
        title: "뫼비우스 띠",
        category: .surfaces,
        summary: "((1 + v/2 cos(u/2)) cos u, v/2 sin(u/2), (1 + v/2 cos(u/2)) sin u): 한 면뿐인 띠",
        source: """
        // 뫼비우스 띠: 반 바퀴 비틀어 붙인 띠. 글자는 띠를 따라 이어짐
        let along = 150
        let across = 16
        let A = 0.3
        for j in 0..<across {
            let v = (j / (across - 1)) * 2 - 1
            for i in 0..<along {
                let u = i / along * TAU
                let w = 1 + (v / 2) * cos(u / 2)
                hsv(u / TAU, 0.6, 0.75 + 0.25 * v)
                size(0.022)
                emit(A * w * cos(u), A * (v / 2) * sin(u / 2), A * w * sin(u))
            }
        }
        """)

    static let kleinBottle = CalligramSample(
        id: "klein",
        title: "클라인 병 (8자형)",
        category: .surfaces,
        summary: "8자형 몰입: (r + cos(u/2) sin v − sin(u/2) sin 2v)(cos u, sin u), z = sin(u/2) sin v + cos(u/2) sin 2v",
        source: """
        // 클라인 병의 8자형(figure-8) 매개변수화
        let nu = 110
        let nv = 36
        let R = 2
        let S = 0.13
        for i in 0..<nu {
            let u = i / nu * TAU
            for j in 0..<nv {
                let v = j / nv * TAU
                let w = R + cos(u / 2) * sin(v) - sin(u / 2) * sin(2 * v)
                let x = w * cos(u)
                let z = w * sin(u)
                let y = sin(u / 2) * sin(v) + cos(u / 2) * sin(2 * v)
                hsv(0.5 + 0.5 * v / TAU, 0.65, 0.6 + 0.4 * (0.5 + 0.5 * cos(u)))
                size(0.02)
                emit(x * S, y * S, z * S)
            }
        }
        """)

    static let sphericalHarmonics = CalligramSample(
        id: "harmonics",
        title: "구면 조화 함수 곡면",
        category: .surfaces,
        summary: "r(φ,θ) = sin⁴(3φ) + cos⁴(2φ) + sin²(5θ) + cos²(4θ) 를 구면좌표 반지름으로 사용",
        source: """
        // 구면 조화형 곡면 (Paul Bourke 식): 반지름이 각도의 삼각함수 거듭제곱 합
        let rows = 90
        let cols = 60
        let m0 = 3
        let m1 = 4
        let m2 = 2
        let m3 = 4
        let m4 = 5
        let m5 = 2
        let m6 = 4
        let m7 = 2
        for i in 0..<rows {
            let phi = i / (rows - 1) * PI
            for j in 0..<cols {
                let theta = j / cols * TAU
                let r = sin(m0 * phi) ^ m1 + cos(m2 * phi) ^ m3 + sin(m4 * theta) ^ m5 + cos(m6 * theta) ^ m7
                let rr = r / 4 * 0.5
                hsv(0.6 - 0.6 * r / 4, 0.7, 1)
                size(0.014 + 0.014 * r / 4)
                emit(rr * sin(phi) * cos(theta), rr * cos(phi), rr * sin(phi) * sin(theta))
            }
        }
        """)

    static let supershape = CalligramSample(
        id: "supershape",
        title: "슈퍼포뮬러 3D",
        category: .surfaces,
        summary: "r(φ) = (|cos(mφ/4)|ⁿ² + |sin(mφ/4)|ⁿ³)^(−1/n₁) 두 개를 곱한 Gielis 초형상",
        source: """
        // Gielis 슈퍼포뮬러: 위도·경도 각각에 r₁(θ), r₂(φ)를 적용
        let lon = 110
        let lat = 56
        let m = 7
        let n1 = 0.2
        let n2 = 1.7
        let n3 = 1.7
        let A = 0.42
        for j in 0..<lat {
            let phi = (j / (lat - 1) - 0.5) * PI
            let r2 = (abs(cos(m * phi / 4)) ^ n2 + abs(sin(m * phi / 4)) ^ n3 + 0.000001) ^ (-1 / n1)
            for i in 0..<lon {
                let theta = (i / lon - 0.5) * TAU
                let r1 = (abs(cos(m * theta / 4)) ^ n2 + abs(sin(m * theta / 4)) ^ n3 + 0.000001) ^ (-1 / n1)
                let x = r1 * cos(theta) * r2 * cos(phi)
                let y = r2 * sin(phi)
                let z = r1 * sin(theta) * r2 * cos(phi)
                hsv(0.08 + 0.5 * (r1 * r2), 0.8, 1)
                size(0.018)
                emit(A * x, A * y, A * z)
            }
        }
        """)

    static let diniSurface = CalligramSample(
        id: "dini",
        title: "디니 곡면 (비틀린 의구면)",
        category: .surfaces,
        summary: "(a cos u sin v, a(cos v + ln tan(v/2)) + b u, a sin u sin v): 일정한 음의 곡률을 갖는 곡면",
        source: """
        // 디니 곡면: 의구면(pseudosphere)을 나선형으로 비튼 것. 가우스 곡률이 음수로 일정
        let nu = 140
        let nv = 26
        let a = 1
        let b = 0.2
        let S = 0.17
        for i in 0..<nu {
            let u = i / nu * 4 * PI
            for j in 0..<nv {
                let v = 0.08 + (j / (nv - 1)) * 1.9
                let x = a * cos(u) * sin(v)
                let z = a * sin(u) * sin(v)
                let y = a * (cos(v) + log(tan(v / 2))) + b * u - 0.6
                hsv(0.45 + 0.4 * (j / nv), 0.7, 1)
                size(0.014 + 0.012 * sin(v))
                emit(x * S, y * S, z * S)
            }
        }
        """)

    static let breatherSurface = CalligramSample(
        id: "breather",
        title: "브리더 곡면",
        category: .surfaces,
        summary: "사인-고든 방정식의 브리더 해에서 유도된 곡면. cosh, sinh와 w = √(1−a²)가 등장",
        source: """
        // 브리더 곡면 (a = 0.4). 분모 D = a[(w cosh(au))² + (a sin(wv))²]
        let a = 0.4
        let w = sqrt(1 - a * a)
        let nu = 120
        let nv = 60
        let S = 0.05
        for i in 0..<nu {
            let u = (i / (nu - 1) - 0.5) * 28
            let ch = cosh(a * u)
            let sh = sinh(a * u)
            for j in 0..<nv {
                let v = (j / (nv - 1) - 0.5) * 74.8
                let D = a * ((w * ch) ^ 2 + (a * sin(w * v)) ^ 2)
                let x = -u + (2 * (1 - a * a) * ch * sh) / D
                let y = (2 * w * ch * (-(w * cos(v) * cos(w * v)) - sin(v) * sin(w * v))) / D
                let z = (2 * w * ch * (-(w * sin(v) * cos(w * v)) + cos(v) * sin(w * v))) / D
                hsv(0.55 + 0.3 * sin(v * 0.3), 0.7, 0.8 + 0.2 * cos(u * 0.5))
                size(0.016)
                emit(x * S, y * S, z * S)
            }
        }
        """)

    static let enneperSurface = CalligramSample(
        id: "enneper",
        title: "엔네퍼 극소곡면",
        category: .surfaces,
        summary: "x = u − u³/3 + uv², y = v − v³/3 + vu², z = u² − v²: 평균 곡률이 0인 극소곡면",
        source: """
        // 엔네퍼 곡면: 비누막처럼 평균 곡률이 0
        let n = 64
        let range = 2
        let S = 0.06
        for i in 0..<n {
            let u = (i / (n - 1) - 0.5) * 2 * range
            for j in 0..<n {
                let v = (j / (n - 1) - 0.5) * 2 * range
                let x = u - u ^ 3 / 3 + u * v ^ 2
                let y = v - v ^ 3 / 3 + v * u ^ 2
                let z = u ^ 2 - v ^ 2
                hsv(0.6 + 0.25 * atan2(v, u) / PI, 0.65, 1)
                size(0.018)
                emit(x * S, z * S, y * S)
            }
        }
        """)

    static let seashell = CalligramSample(
        id: "seashell",
        title: "소라 껍데기",
        category: .surfaces,
        summary: "반지름이 e^{u/6π}로 지수 성장하는 로그 나선 튜브 곡면",
        source: """
        // 소라 껍데기: 지수적으로 커지는 튜브를 나선으로 감음
        let nu = 160
        let nv = 28
        let S = 0.09
        for i in 0..<nu {
            let u = i / nu * 6 * PI
            let e1 = exp(u / (6 * PI))
            let e2 = exp(u / (3 * PI))
            for j in 0..<nv {
                let v = j / nv * TAU
                let c2 = cos(v / 2) ^ 2
                let x = 2 * (1 - e1) * cos(u) * c2
                let z = 2 * (-1 + e1) * sin(u) * c2
                let y = 1 - e2 - sin(v) + e1 * sin(v) + 3
                hsv(0.05 + 0.08 * sin(v), 0.5 + 0.3 * (u / (6 * PI)), 1)
                size(0.012 + 0.016 * (u / (6 * PI)))
                emit(x * S, y * S, z * S)
            }
        }
        """)

    // MARK: - 끌개 · 카오스

    static let lorenzAttractor = CalligramSample(
        id: "lorenz",
        title: "로렌츠 끌개",
        category: .attractors,
        summary: "ẋ = σ(y−x), ẏ = x(ρ−z)−y, ż = xy−βz 를 오일러 적분. 색은 속력에 비례",
        source: """
        // 로렌츠 끌개: σ = 10, ρ = 28, β = 8/3
        let sigma = 10
        let rho = 28
        let beta = 8 / 3
        let dt = 0.004
        let n = 7000
        let S = 0.016
        var x = 0.1
        var y = 0
        var z = 0
        for i in 0..<n {
            let dx = sigma * (y - x)
            let dy = x * (rho - z) - y
            let dz = x * y - beta * z
            x += dx * dt
            y += dy * dt
            z += dz * dt
            let speed = sqrt(dx * dx + dy * dy + dz * dz)
            hsv(0.62 + 0.35 * clamp(speed / 250, 0, 1), 0.85, 1)
            size(0.012 + 0.012 * (i / n))
            emit(x * S, (z - 25) * S, y * S)
        }
        """)

    static let aizawaAttractor = CalligramSample(
        id: "aizawa",
        title: "아이자와 끌개",
        category: .attractors,
        summary: "ż = c + az − z³/3 − (x²+y²)(1+ez) + fzx³ 항이 만드는 구형 소용돌이",
        source: """
        // 아이자와 끌개: a=0.95 b=0.7 c=0.6 d=3.5 e=0.25 f=0.1
        let a = 0.95
        let b = 0.7
        let c = 0.6
        let d = 3.5
        let e = 0.25
        let f = 0.1
        let dt = 0.01
        let n = 9000
        let S = 0.27
        var x = 0.1
        var y = 0
        var z = 0
        for i in 0..<n {
            let dx = (z - b) * x - d * y
            let dy = d * x + (z - b) * y
            let dz = c + a * z - z ^ 3 / 3 - (x ^ 2 + y ^ 2) * (1 + e * z) + f * z * x ^ 3
            x += dx * dt
            y += dy * dt
            z += dz * dt
            hsv(0.75 + 0.25 * z, 0.7, 0.7 + 0.3 * (0.5 + 0.5 * sin(i * 0.01)))
            size(0.014)
            emit(x * S, (z - 0.7) * S, y * S)
        }
        """)

    static let thomasAttractor = CalligramSample(
        id: "thomas",
        title: "토마스 순환대칭 끌개",
        category: .attractors,
        summary: "ẋ = sin y − bx, ẏ = sin z − by, ż = sin x − bz (b = 0.208186): 순환 대칭 카오스",
        source: """
        // 토마스 끌개: 세 식이 x→y→z→x 순환 대칭
        let b = 0.208186
        let dt = 0.06
        let n = 9000
        let S = 0.11
        var x = 1.1
        var y = 1.1
        var z = -0.01
        for i in 0..<n {
            let dx = sin(y) - b * x
            let dy = sin(z) - b * y
            let dz = sin(x) - b * z
            x += dx * dt
            y += dy * dt
            z += dz * dt
            hsv(0.5 + 0.5 * atan2(z, x) / PI, 0.75, 1)
            size(0.013 + 0.01 * (0.5 + 0.5 * sin(y)))
            // 궤도가 한 엽(lobe)에 머무는 동안 중심이 치우치므로 평균 위치만큼 되돌림
            emit((x - 1.3) * S, (y - 1.3) * S, (z - 1.3) * S)
        }
        """)

    static let cliffordAttractor = CalligramSample(
        id: "clifford",
        title: "클리퍼드 끌개",
        category: .attractors,
        summary: "xₙ₊₁ = sin(a yₙ) + c cos(a xₙ), yₙ₊₁ = sin(b xₙ) + d cos(b yₙ), 높이는 sin x cos y",
        source: """
        // 클리퍼드 끌개 (a=-1.4, b=1.6, c=1.0, d=0.7)를 높이 z = sin(x) cos(y)로 들어 올림
        let a = -1.4
        let b = 1.6
        let c = 1.0
        let d = 0.7
        let n = 9000
        let S = 0.2
        var x = 0.1
        var y = 0.1
        for i in 0..<n {
            let xn = sin(a * y) + c * cos(a * x)
            let yn = sin(b * x) + d * cos(b * y)
            x = xn
            y = yn
            let h = sin(x) * cos(y)
            hsv(0.55 + 0.45 * h, 0.7, 0.85 + 0.15 * h)
            size(0.012)
            emit(x * S, h * 0.25, y * S)
        }
        """)

    // MARK: - 프랙탈 · IFS

    static let juliaSet = CalligramSample(
        id: "julia",
        title: "줄리아 집합 높이맵",
        category: .fractals,
        summary: "zₙ₊₁ = zₙ² + c (c = −0.8 + 0.156i)의 탈출 시간을 높이와 색으로 표시",
        source: """
        // 줄리아 집합: 각 격자점에서 z ← z² + c 를 반복, 탈출까지 걸린 횟수가 높이
        let cols = 72
        let rows = 54
        let maxIter = 24
        let cr = -0.8
        let ci = 0.156
        for i in 0..<cols {
            for j in 0..<rows {
                var x = (i / (cols - 1) - 0.5) * 3.2
                var y = (j / (rows - 1) - 0.5) * 2.4
                var iter = 0
                var escaped = false
                for k in 0..<maxIter {
                    if !escaped {
                        let xn = x * x - y * y + cr
                        y = 2 * x * y + ci
                        x = xn
                        if x * x + y * y > 4 {
                            escaped = true
                        } else {
                            iter = k + 1
                        }
                    }
                }
                let h = iter / maxIter
                hsv(0.68 - 0.6 * h, 0.8, 0.45 + 0.55 * h)
                size(0.011 + 0.014 * h)
                emit((i / (cols - 1) - 0.5) * 0.9, h * 0.3 - 0.15, (j / (rows - 1) - 0.5) * 0.68)
            }
        }
        """)

    static let mengerSponge = CalligramSample(
        id: "menger",
        title: "멩거 스펀지 (3단계)",
        category: .fractals,
        summary: "각 축 좌표의 3진 자릿수 중 두 개 이상이 1인 셀을 제거해 얻는 프랙탈 (8000 셀)",
        source: """
        // 멩거 스펀지: 27³ 격자에서 3진법 자릿수 검사로 남길 셀을 고른다
        let level = 3
        let cells = 27
        let S = 0.8
        for ix in 0..<cells {
            for iy in 0..<cells {
                for iz in 0..<cells {
                    var solid = true
                    for k in 0..<level {
                        let p = 3 ^ k
                        let dx = floor(ix / p) % 3
                        let dy = floor(iy / p) % 3
                        let dz = floor(iz / p) % 3
                        var ones = 0
                        if dx == 1 { ones += 1 }
                        if dy == 1 { ones += 1 }
                        if dz == 1 { ones += 1 }
                        if ones >= 2 { solid = false }
                    }
                    if solid {
                        hsv(0.5 + 0.35 * (iy / cells), 0.55, 0.7 + 0.3 * (ix / cells))
                        size(0.024)
                        emit(((ix + 0.5) / cells - 0.5) * S, ((iy + 0.5) / cells - 0.5) * S, ((iz + 0.5) / cells - 0.5) * S)
                    }
                }
            }
        }
        """)

    static let sierpinskiTetrahedron = CalligramSample(
        id: "sierpinski",
        title: "시에르핀스키 사면체 (카오스 게임)",
        category: .fractals,
        summary: "무작위로 고른 꼭짓점과 현재 점의 중점으로 이동하는 IFS: pₙ₊₁ = (pₙ + vₖ)/2",
        source: """
        // 카오스 게임: 사면체 꼭짓점 하나를 무작위로 골라 그 방향으로 절반 이동
        seed(7)
        let n = 9000
        var x = 0
        var y = 0
        var z = 0
        for i in 0..<n {
            let pick = floor(random() * 4)
            var tx = 0
            var ty = 0.5
            var tz = 0
            if pick == 1 {
                tx = -0.47
                ty = -0.27
                tz = 0.27
            } else if pick == 2 {
                tx = 0.47
                ty = -0.27
                tz = 0.27
            } else if pick == 3 {
                tx = 0
                ty = -0.27
                tz = -0.54
            }
            x = (x + tx) / 2
            y = (y + ty) / 2
            z = (z + tz) / 2
            if i > 20 {
                hsv(pick / 4 + 0.05, 0.7, 1)
                size(0.014)
                emit(x, y, z)
            }
        }
        """)

    static let barnsleyFern = CalligramSample(
        id: "fern",
        title: "반슬리 고사리",
        category: .fractals,
        summary: "네 개의 아핀 변환을 확률 1%, 85%, 7%, 7%로 적용하는 반복 함수계(IFS)",
        source: """
        // 반슬리 고사리: 확률에 따라 네 아핀 변환 중 하나를 적용
        seed(3)
        let n = 9500
        let S = 0.09
        var x = 0
        var y = 0
        for i in 0..<n {
            let r = random()
            var nx = 0
            var ny = 0
            if r < 0.01 {
                nx = 0
                ny = 0.16 * y
            } else if r < 0.86 {
                nx = 0.85 * x + 0.04 * y
                ny = -0.04 * x + 0.85 * y + 1.6
            } else if r < 0.93 {
                nx = 0.2 * x - 0.26 * y
                ny = 0.23 * x + 0.22 * y + 1.6
            } else {
                nx = -0.15 * x + 0.28 * y
                ny = 0.26 * x + 0.24 * y + 0.44
            }
            x = nx
            y = ny
            let z = 0.08 * sin(y * 1.3)
            hsv(0.26 + 0.1 * (y / 10), 0.8, 0.55 + 0.45 * (y / 10))
            size(0.012)
            emit(x * S, (y - 5) * S, z)
        }
        """)

    // MARK: - 격자 · 필드

    static let waveGrid = CalligramSample(
        id: "wave",
        title: "간섭 파동 격자",
        category: .fields,
        summary: "두 파원에서 나온 sin(kd₁) + sin(kd₂) 의 중첩으로 생기는 간섭 무늬",
        source: """
        // 두 파원의 간섭: 높이 = 각 파원까지 거리의 사인파 합
        let cols = 56
        let rows = 56
        let k = 22
        for ix in 0..<cols {
            for iz in 0..<rows {
                let x = (ix / (cols - 1) - 0.5) * 0.95
                let z = (iz / (rows - 1) - 0.5) * 0.95
                let d1 = sqrt((x - 0.2) ^ 2 + z ^ 2)
                let d2 = sqrt((x + 0.2) ^ 2 + z ^ 2)
                let y = 0.06 * (sin(d1 * k) + sin(d2 * k)) * (1 - sqrt(x * x + z * z))
                hsv(0.55 + y * 2.5, 0.75, 0.7 + 0.3 * (1 - sqrt(x * x + z * z)))
                if (ix + iz) % 7 == 0 {
                    size(0.028)
                } else {
                    size(0.018)
                }
                emit(x, y, z)
            }
        }
        """)

    static let fibonacciSphere = CalligramSample(
        id: "sphere",
        title: "피보나치 구",
        category: .fields,
        summary: "황금각 π(3−√5)씩 회전하며 y를 균등 분할해 구면에 점을 고르게 배치",
        source: """
        // 피보나치 격자 구: 황금각 간격으로 고르게 분포
        let n = 1600
        let radius = 0.42
        let golden = PI * (3 - sqrt(5))
        for i in 0..<n {
            let y = 1 - (i / (n - 1)) * 2
            let r = sqrt(1 - y * y)
            let a = golden * i
            hsv(0.55 + 0.25 * y, 0.6, 1)
            size(0.02 + 0.012 * (0.5 + 0.5 * sin(a * 0.5)))
            emit(cos(a) * r * radius, y * radius, sin(a) * r * radius)
        }
        """)

    static let phyllotaxis = CalligramSample(
        id: "phyllotaxis",
        title: "잎차례 돔 (황금각)",
        category: .fields,
        summary: "r = c√i, θ = i·137.5° 인 보겔 나선을 돔 위에 올리고 13·21 피보나치 사선을 강조",
        source: """
        // 잎차례(phyllotaxis): 해바라기 씨앗 배열을 돔 형태로
        let n = 3400
        let golden = PI * (3 - sqrt(5))
        for i in 0..<n {
            let t = i / n
            let r = 0.46 * sqrt(t)
            let a = i * golden
            let y = 0.34 * cos(r / 0.46 * PI / 2) - 0.1
            hsv(0.08 + 0.12 * t, 0.85, 0.85)
            size(0.01 + 0.02 * (1 - t))
            if i % 21 == 0 {
                hsv(0.5, 0.8, 1)
                size(0.03)
            } else if i % 13 == 0 {
                hsv(0.95, 0.8, 1)
                size(0.026)
            }
            emit(cos(a) * r, y, sin(a) * r)
        }
        """)

    static let spiralGalaxy = CalligramSample(
        id: "galaxy",
        title: "나선 은하",
        category: .fields,
        summary: "θ = θ₀ + k ln(r/r₀) 로그 나선 팔 3개에 정규 잡음을 더한 별 분포",
        source: """
        // 나선 은하: 세 개의 로그 나선 팔 + 무작위 산란
        seed(11)
        let arms = 3
        let n = 7000
        for i in 0..<n {
            let t = i / n
            let arm = i % arms
            let r = 0.05 + 0.43 * t ^ 0.75
            let angle = arm * TAU / arms + log(r / 0.05) * 2.4
            let spread = 0.11 * (1 - t) + 0.025
            let x = cos(angle) * r + (random() - 0.5) * spread
            let z = sin(angle) * r + (random() - 0.5) * spread
            let y = (random() - 0.5) * (0.06 * (1 - t) + 0.01)
            hsv(0.12 + 0.48 * t, 0.55 - 0.3 * t, 1)
            size(0.008 + 0.018 * (1 - t) * random())
            emit(x, y, z)
        }
        """)

    // MARK: - 4차원 · 위상

    static let hopfFibration = CalligramSample(
        id: "hopf",
        title: "호프 올뭉치 (S³ → S²)",
        category: .fourD,
        summary: "S³ 위의 원 (e^{iξ₁} sin η, e^{iξ₂} cos η)을 입체사영 p/(1−w)으로 ℝ³에 내린 연결 고리들",
        source: """
        // 호프 올뭉치: 밑공간의 점 하나가 S³의 원 하나(올)에 대응. 올끼리 서로 한 번씩 얽힘
        let fibers = 30
        let steps = 160
        let S = 0.11
        for k in 0..<fibers {
            let phi = k / fibers * TAU
            let eta = 0.55 + 0.5 * ((k % 3) / 2)
            for j in 0..<steps {
                let t = j / steps * TAU
                // S³ ⊂ ℝ⁴ 위의 점 (a, b, c, d)
                let a = cos(t) * sin(eta)
                let b = sin(t) * sin(eta)
                let c = cos(t + phi) * cos(eta)
                let d = sin(t + phi) * cos(eta)
                // c 방향에서 입체사영
                let w = 1 - c
                hsv(k / fibers, 0.7, 1)
                size(0.014 + 0.01 * (1 - w))
                emit(a / w * S, d / w * S, b / w * S)
            }
        }
        """)

    static let cliffordTorus = CalligramSample(
        id: "clifford-torus",
        title: "클리퍼드 토러스 (4D 회전)",
        category: .fourD,
        summary: "(cos u, sin u, cos v, sin v)/√2 를 xw 평면에서 α만큼 회전한 뒤 입체사영",
        source: """
        // 클리퍼드 토러스: S³ 안의 평평한 토러스를 4차원 회전 후 3차원으로 사영
        let nu = 72
        let nv = 48
        let alpha = 0.9
        let S = 0.15
        let inv = 1 / sqrt(2)
        for i in 0..<nu {
            let u = i / nu * TAU
            for j in 0..<nv {
                let v = j / nv * TAU
                let x = cos(u) * inv
                let y = sin(u) * inv
                let z = cos(v) * inv
                let w = sin(v) * inv
                // xw 평면 회전
                let xr = x * cos(alpha) - w * sin(alpha)
                let wr = x * sin(alpha) + w * cos(alpha)
                let k = S / (1.05 - wr)
                hsv(u / TAU, 0.6 + 0.4 * (0.5 + 0.5 * sin(v)), 1)
                size(0.016 + 0.01 * (wr + 0.7))
                emit(xr * k, y * k, z * k)
            }
        }
        """)

    // MARK: - 타이포그래피

    static let glyphCylinder = CalligramSample(
        id: "glyph-cylinder",
        title: "글리프 실린더 (텍스트 링)",
        category: .typography,
        summary: "glyph()로 지정한 문장이 원통 둘레를 따라 흐르고, 높이는 sin 파동으로 출렁임",
        source: """
        // 원통에 문장을 감는다. glyph()의 문자들이 emit 순서대로 사용됨
        glyph("CODE IS POETRY * IMMERSIVE CALLIGRAM * ")
        let rows = 14
        let perRow = 96
        let R = 0.36
        for r in 0..<rows {
            let v = r / (rows - 1)
            for i in 0..<perRow {
                let u = i / perRow
                let a = u * TAU + v * 0.6
                let wave = 0.05 * sin(u * TAU * 3 + v * TAU)
                let y = (v - 0.5) * 0.8 + wave
                hsv(fract(v + u * 0.3), 0.65, 1)
                size(0.03)
                emit(cos(a) * R, y, sin(a) * R)
            }
        }
        """)
}
