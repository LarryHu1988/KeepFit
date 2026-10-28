import Foundation

// Run with:
// swiftc KeepFitApp/Components/TrendAxisTickLayout.swift Tests/TrendAxisTickLayoutTests.swift -o /tmp/keepfit-axis-tests
// /tmp/keepfit-axis-tests
@main
struct TrendAxisTickLayoutTests {
    static func main() {
        let seven: [CGFloat] = [22, 22, 22, 28, 28, 28, 28]
        assert(trendAxisTickIndices(labelWidths: [], plotWidth: 300, edgePadding: 20).isEmpty)
        assert(trendAxisTickIndices(labelWidths: [28], plotWidth: 300, edgePadding: 20) == [0])
        assert(trendAxisTickIndices(labelWidths: seven, plotWidth: 300, edgePadding: 20) == Array(0..<7))
        assert(trendAxisTickIndices(labelWidths: seven, plotWidth: 240, edgePadding: 20) == [0, 2, 4, 6])
        // Wide displays must not inherit the old seven-label limit.
        assert(trendAxisTickIndices(labelWidths: Array(repeating: 28, count: 12), plotWidth: 500, edgePadding: 20).count == 12)

        var cases = 0
        for count in 2...400 {
            for width: CGFloat in [190, 230, 270, 310, 350, 430, 600, 900] {
                for scale: CGFloat in [1, 1.3, 1.8, 2.5] {
                    let widths = (0..<count).map { CGFloat([18, 24, 30][$0 % 3]) * scale }
                    let ticks = trendAxisTickIndices(labelWidths: widths, plotWidth: width, edgePadding: 20)
                    assert(ticks == ticks.sorted() && Set(ticks).count == ticks.count)
                    assert(ticks.first == 0 && ticks.last == count - 1)
                    if ticks.count != count { assert(ticks.count <= (count + 1) / 2) }
                    let gaps = zip(ticks, ticks.dropFirst()).map { $1 - $0 }
                    assert((gaps.max() ?? 0) - (gaps.min() ?? 0) <= 1)
                    for (left, right) in zip(ticks, ticks.dropFirst()) {
                        let distance = (width - 40) * CGFloat(right - left) / CGFloat(count - 1)
                        assert(distance + 0.001 >= (widths[left] + widths[right]) / 2 + 8)
                    }
                    cases += 1
                }
            }
        }
        let largeFontTicks = trendAxisTickIndices(labelWidths: seven.map { $0 * 2 }, plotWidth: 300, edgePadding: 20)
        assert(largeFontTicks.count < 7)
        print("Passed \(cases) width/data/font combinations plus sparse-date and wide-display regressions.")
    }
}
