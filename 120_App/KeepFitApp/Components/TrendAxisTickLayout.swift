import Foundation

// Widths use the same font as the axis. plotWidth excludes the Y axis;
// edgePadding is the space between the plot edges and the first/last points.
func trendAxisTickIndices(
    labelWidths: [CGFloat],
    plotWidth: CGFloat,
    edgePadding: CGFloat,
    minimumGap: CGFloat = 8
) -> [Int] {
    let count = labelWidths.count
    guard count > 1 else { return count == 1 ? [0] : [] }
    let span = max(0, plotWidth - 2 * edgePadding)
    let last = count - 1

    func fits(_ indices: [Int]) -> Bool {
        zip(indices, indices.dropFirst()).allSatisfy { left, right in
            let distance = span * CGFloat(right - left) / CGFloat(last)
            return distance >= (labelWidths[left] + labelWidths[right]) / 2 + minimumGap
        }
    }

    let all = Array(0..<count)
    if fits(all) { return all }

    // Once labels need thinning, sample the whole range. Avoid an almost-full
    // axis that omits just one date and leaves a conspicuous hole in the middle.
    let smallestWidth = labelWidths.min() ?? 0
    let capacity = Int(span / max(1, smallestWidth + minimumGap)) + 1
    let maximumTickCount = min((count + 1) / 2, capacity)
    if maximumTickCount >= 2 {
        for tickCount in stride(from: maximumTickCount, through: 2, by: -1) {
            let indices = (0..<tickCount).map { tick in
                Int((Double(tick) * Double(last) / Double(tickCount - 1)).rounded())
            }
            if fits(indices) { return indices }
        }
    }
    return [0]
}
