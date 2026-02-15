import SwiftUI

struct CalendarHeatmapView: View {
    let month: Date
    let cells: [Date?]
    @Binding var selectedDate: Date
    let dayBalance: (Date) -> Double
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
        }
    }

    @ViewBuilder
    private func calendarCell(for date: Date) -> some View {
        let isSelected = date.isSameDay(as: selectedDate)
        let balance = dayBalance(date)
        let hasData = hasRecord(date)
        let balanceDotColor: Color = {
            if balance <= -80 { return .green }
            if balance >= 80 { return .red }
            return .orange
        }()

        Button {
            selectedDate = date
        } label: {
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)

                if hasData {
                    Circle()
                        .fill(balanceDotColor)
                        .frame(width: 6, height: 6)
                } else {
                    Color.clear.frame(height: 10)
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
