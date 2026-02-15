import SwiftUI

struct CalendarHeatmapView: View {
    let month: Date
    let cells: [Date?]
    @Binding var selectedDate: Date
    let deficitSunCount: (Date) -> Int
    let hasRecord: (Date) -> Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let weekTitles = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Formatters.monthTitle.string(from: month))
                .font(.headline)

            HStack {
                ForEach(weekTitles, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, value in
                    if let date = value {
                        calendarCell(for: date)
                    } else {
                        Rectangle()
                            .fill(.clear)
                            .frame(height: 48)
                    }
                }
            }

            Text("点击任意日期查看当天记录")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func calendarCell(for date: Date) -> some View {
        let isSelected = date.isSameDay(as: selectedDate)
        let sunCount = deficitSunCount(date)
        let hasData = hasRecord(date)

        Button {
            selectedDate = date
        } label: {
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)

                if sunCount > 0 {
                    HStack(spacing: 1) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.orange)
                        if sunCount > 1 {
                            Text("x\(sunCount)")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(.orange)
                        }
                    }
                } else if hasData {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 4, height: 4)
                } else {
                    Color.clear.frame(height: 8)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color(.tertiarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}
