import Foundation

/// Built-in example programs shown in the editor's sample menu.
nonisolated struct CalligramSample: Sendable, Identifiable, Hashable {
    let id: String
    let title: String
    let source: String
}

nonisolated enum CalligramSamples {
    static let all: [CalligramSample] = [helix, fibonacciSphere, torusKnot, waveGrid]

    static let helix = CalligramSample(
        id: "helix",
        title: "이중 나선",
        source: """
        // Code Calligram: 이중 나선
        // 소스 코드의 글자가 emit() 순서대로 배치됩니다.
        let n = 900
        let turns = 5
        for i in 0..<n {
            let t = i / n
            let a = t * TAU * turns
            let r = 0.28 + 0.06 * sin(t * TAU * 3)
            let y = t * 0.9 - 0.45
            color(0.3 + 0.7 * t, 0.85, 1 - t)
            emit(cos(a) * r, y, sin(a) * r)
            color(1, 0.55 + 0.45 * t, 0.3)
            emit(cos(a + PI) * r, y, sin(a + PI) * r)
        }
        """)

    static let fibonacciSphere = CalligramSample(
        id: "sphere",
        title: "피보나치 구",
        source: """
        // Code Calligram: 피보나치 격자 구
        let n = 1400
        let radius = 0.42
        let golden = PI * (3 - sqrt(5))
        for i in 0..<n {
            let y = 1 - (i / (n - 1)) * 2
            let r = sqrt(1 - y * y)
            let a = golden * i
            hsv(0.55 + 0.25 * y, 0.6, 1)
            emit(cos(a) * r * radius, y * radius, sin(a) * r * radius)
        }
        """)

    static let torusKnot = CalligramSample(
        id: "knot",
        title: "토러스 매듭 (3,7)",
        source: """
        // Code Calligram: 토러스 매듭
        let n = 1800
        let p = 3
        let q = 7
        for i in 0..<n {
            let t = i / n * TAU
            let r = 0.26 + 0.1 * cos(q * t)
            hsv(t / TAU, 0.7, 1)
            size(0.018 + 0.014 * (1 + cos(q * t)) / 2)
            emit(r * cos(p * t), 0.12 * sin(q * t), r * sin(p * t))
        }
        """)

    static let waveGrid = CalligramSample(
        id: "wave",
        title: "웨이브 그리드",
        source: """
        // Code Calligram: 파동 격자
        let cols = 42
        let rows = 42
        for ix in 0..<cols {
            for iz in 0..<rows {
                let x = (ix / (cols - 1) - 0.5) * 0.9
                let z = (iz / (rows - 1) - 0.5) * 0.9
                let d = sqrt(x * x + z * z)
                let y = 0.12 * sin(d * 18) * (1 - d)
                color(0.35 + y * 3, 0.75, 1 - d)
                if (ix + iz) % 7 == 0 {
                    size(0.03)
                } else {
                    size(0.02)
                }
                emit(x, y, z)
            }
        }
        """)
}
