import SwiftUI

struct CalendarHeatmapView: View {
    let cells: [Date?]
    @Binding var selectedDate: Date
    let dayBalance: (Date) -> Double
    let hasRecord: (Date) -> Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let weekTitles = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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

struct WeekStripCalendarView: View {
    @Binding var selectedDate: Date
    let indicatorColor: (Date) -> Color?

    private let weekTitles = ["日", "一", "二", "三", "四", "五", "六"]

    private var weekDates: [Date] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: selectedDate)
        let weekday = calendar.component(.weekday, from: dayStart)
        let weekStart = calendar.date(byAdding: .day, value: -(weekday - 1), to: dayStart) ?? dayStart
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekStart)
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(weekDates, id: \.self) { date in
                weekCell(for: date)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.accentColor.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.9), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func weekCell(for date: Date) -> some View {
        let calendar = Calendar.current
        let isSelected = date.isSameDay(as: selectedDate)
        let weekdayIndex = max(0, min(6, calendar.component(.weekday, from: date) - 1))

        Button {
            selectedDate = date
        } label: {
            VStack(spacing: 2) {
                Text(weekTitles[weekdayIndex])
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.95) : Color.secondary)

                Text("\(calendar.component(.day, from: date))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)

                if let dotColor = indicatorColor(date) {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 5, height: 5)
                } else {
                    Color.clear.frame(width: 5, height: 5)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color(.tertiarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}
