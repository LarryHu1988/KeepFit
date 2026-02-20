import SwiftUI

struct CalendarHeatmapView: View {
    let cells: [Date?]
    @Binding var selectedDate: Date
    let dayBalance: (Date) -> Double
    let hasRecord: (Date) -> Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private var weekTitles: [String] {
        var calendar = AppPreferences.calendar
        calendar.locale = AppPreferences.locale
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard symbols.count == 7 else { return ["日", "一", "二", "三", "四", "五", "六"] }
        let start = max(0, min(6, calendar.firstWeekday - 1))
        return Array(symbols[start...] + symbols[..<start])
    }

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
            KeepFitHaptics.selection()
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
    let accent: Color
    let indicatorColor: (Date) -> Color?

    private var weekTitles: [String] {
        var calendar = AppPreferences.calendar
        calendar.locale = AppPreferences.locale
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard symbols.count == 7 else { return ["日", "一", "二", "三", "四", "五", "六"] }
        let start = max(0, min(6, calendar.firstWeekday - 1))
        return Array(symbols[start...] + symbols[..<start])
    }

    private var weekDates: [Date] {
        let calendar = AppPreferences.calendar
        let weekStart = selectedDate.startOfWeekInCurrentCalendar
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
        .padding(9)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.2), .white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.28), lineWidth: 1)
                )
        )
        .shadow(color: accent.opacity(0.12), radius: 8, x: 0, y: 4)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 16)
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = value.translation.height
                    guard abs(horizontal) > abs(vertical), abs(horizontal) > 30 else { return }
                    if horizontal < 0 {
                        shiftWeek(by: 1)
                    } else {
                        shiftWeek(by: -1)
                    }
                }
        )
    }

    @ViewBuilder
    private func weekCell(for date: Date) -> some View {
        let calendar = AppPreferences.calendar
        let isSelected = date.isSameDay(as: selectedDate)
        let weekday = calendar.component(.weekday, from: date)
        let weekdayIndex = (weekday - calendar.firstWeekday + 7) % 7

        Button {
            KeepFitHaptics.selection()
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
                    .fill(
                        isSelected
                            ? LinearGradient(
                                colors: [accent.opacity(0.88), accent.opacity(0.68)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [.white.opacity(0.16), .white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isSelected ? .white.opacity(0.45) : .white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func shiftWeek(by offset: Int) {
        let calendar = AppPreferences.calendar
        let currentWeekStart = selectedDate.startOfWeekInCurrentCalendar
        guard let targetWeekStart = calendar.date(byAdding: .day, value: offset * 7, to: currentWeekStart) else { return }
        let today = Date().startOfDayInCurrentCalendar
        let todayWeekStart = today.startOfWeekInCurrentCalendar
        let targetSelectedDate = targetWeekStart.isSameDay(as: todayWeekStart) ? today : targetWeekStart
        KeepFitHaptics.selection()
        withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
            selectedDate = targetSelectedDate
        }
    }
}
