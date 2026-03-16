import SwiftUI

struct CalendarHeatmapDayState {
    let balance: Double
    let hasRecord: Bool
}

struct CalendarHeatmapView: View {
    let cells: [Date?]
    @Binding var selectedDate: Date
    let dayStates: [Date: CalendarHeatmapDayState]

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
        let isFuture = date.isFutureDayInCurrentCalendar
        let dayState = dayStates[date.startOfDayInCurrentCalendar]
        let balance = dayState?.balance ?? 0
        let hasData = (dayState?.hasRecord ?? false) && !isFuture
        let balanceDotColor: Color = {
            if balance <= -80 { return .green }
            if balance >= 80 { return .red }
            return .orange
        }()

        Button {
            guard !isFuture else { return }
            KeepFitHaptics.selection()
            selectedDate = date
        } label: {
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : (isFuture ? Color.secondary : Color.primary))

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
                    .fill(
                        isSelected
                            ? Color.accentColor
                            : Color(.tertiarySystemBackground).opacity(isFuture ? 0.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }
}

struct WeekStripCalendarView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var selectedDate: Date
    let accent: Color
    let indicatorColor: (Date) -> Color?
    @ScaledMetric(relativeTo: .body) private var rowPadding: CGFloat = 10
    @ScaledMetric(relativeTo: .body) private var dayCellHeight: CGFloat = 54

    private var isCompactLayout: Bool {
        UIScreen.main.bounds.width <= 390 || dynamicTypeSize >= .xxxLarge
    }

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
        HStack(spacing: isCompactLayout ? 5 : 7) {
            ForEach(weekDates, id: \.self) { date in
                weekCell(for: date)
            }
        }
        .padding(isCompactLayout ? max(8, rowPadding - 2) : rowPadding)
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
        let isFuture = date.isFutureDayInCurrentCalendar
        let weekday = calendar.component(.weekday, from: date)
        let weekdayIndex = (weekday - calendar.firstWeekday + 7) % 7

        Button {
            guard !isFuture else { return }
            KeepFitHaptics.selection()
            selectedDate = date
        } label: {
            VStack(spacing: 2) {
                Text(weekTitles[weekdayIndex])
                    .font(.system(size: isCompactLayout ? 10.5 : 11.5, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.95) : (isFuture ? Color.secondary.opacity(0.62) : Color.secondary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: isCompactLayout ? 14 : 15, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : (isFuture ? Color.secondary : Color.primary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if let dotColor = indicatorColor(date), !isFuture {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 5, height: 5)
                } else {
                    Color.clear.frame(width: 5, height: 5)
                }
            }
            .frame(maxWidth: .infinity, minHeight: isCompactLayout ? max(48, dayCellHeight - 4) : dayCellHeight)
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
                                colors: isFuture ? [.white.opacity(0.08), .white.opacity(0.04)] : [.white.opacity(0.16), .white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isSelected ? .white.opacity(0.45) : .white.opacity(isFuture ? 0.12 : 0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }

    private func shiftWeek(by offset: Int) {
        let calendar = AppPreferences.calendar
        let currentWeekStart = selectedDate.startOfWeekInCurrentCalendar
        guard let targetWeekStart = calendar.date(byAdding: .day, value: offset * 7, to: currentWeekStart) else { return }
        let today = Date().startOfDayInCurrentCalendar
        let todayWeekStart = today.startOfWeekInCurrentCalendar
        let clampedWeekStart = min(targetWeekStart, todayWeekStart)
        let targetSelectedDate = clampedWeekStart.isSameDay(as: todayWeekStart) ? today : clampedWeekStart
        KeepFitHaptics.selection()
        withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
            selectedDate = targetSelectedDate
        }
    }
}
