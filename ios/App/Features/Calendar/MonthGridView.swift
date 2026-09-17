import SocialsCore
import SwiftUI

/// Month grid: full ISO weeks (Monday first) covering the month, leading/trailing days from the
/// adjacent months dimmed, each cell showing up to a few posts plus an overflow count. Mirrors
/// web's month view in `calendar.tsx` (`calendarStartDate = startOfMonth.subtract(daysBeforeMonth)`).
struct MonthGridView: View {
    let viewModel: CalendarViewModel

    private let maxVisiblePerDay = 2
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var calendar: Calendar { CalendarRange.isoCalendar }

    private var monthRange: ClosedRange<Date> {
        CalendarRange.month(containing: viewModel.referenceDate, calendar: calendar)
    }

    /// Full weeks covering the month, so the grid always has complete rows.
    private var gridDays: [Date] {
        let firstOfMonth = monthRange.lowerBound
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        // ISO weekday: Monday = 2 in Gregorian .weekday; normalize to days-before-month.
        let isoWeekday = calendar.firstWeekday == 2 ? ((weekday + 5) % 7) : (weekday - 1)
        guard let gridStart = calendar.date(byAdding: .day, value: -isoWeekday, to: firstOfMonth) else {
            return []
        }
        let daysUntilEnd = calendar.dateComponents([.day], from: gridStart, to: monthRange.upperBound).day ?? 0
        let totalDays = ((daysUntilEnd / 7) + 1) * 7
        return (0..<totalDays).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(gridDays, id: \.self) { day in
                    dayCell(for: day)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func dayCell(for day: Date) -> some View {
        let posts = postsForDay(day)
        let isCurrentMonth = calendar.isDate(day, equalTo: viewModel.referenceDate, toGranularity: .month)
        return VStack(alignment: .leading, spacing: 2) {
            Text(Self.dayNumber(day))
                .font(.caption2)
                .foregroundStyle(isCurrentMonth ? .primary : .secondary)

            ForEach(posts.prefix(maxVisiblePerDay), id: \.id) { post in
                Text(CalendarPostCard.previewText(post.content))
                    .font(.caption2)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.secondary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }

            if posts.count > maxVisiblePerDay {
                Text("+\(posts.count - maxVisiblePerDay) more")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .topLeading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(Self.dayNumber(day)), \(posts.count) post\(posts.count == 1 ? "" : "s")")
    }

    private func postsForDay(_ day: Date) -> [PostGroupDTO] {
        let dayRange = CalendarRange.day(containing: day, calendar: calendar)
        let formatter = ISO8601DateFormatter()
        return viewModel.posts
            .filter { post in
                guard let iso = post.publishDate, let date = formatter.date(from: iso) else { return false }
                return dayRange.contains(date)
            }
            .sorted { ($0.publishDate ?? "") < ($1.publishDate ?? "") }
    }

    private static func dayNumber(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}
