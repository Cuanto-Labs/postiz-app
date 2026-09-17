import SocialsCore
import SwiftUI

/// ISO week grid (Monday first, matching `CalendarRange.week`/web's `isoWeek` plugin): seven
/// day columns, each showing that day's posts. Mirrors web's week view in `calendar.tsx`.
struct WeekGridView: View {
    let viewModel: CalendarViewModel

    /// Toggled after every drag-to-reschedule attempt so `.sensoryFeedback` below fires a
    /// success/error haptic matching the outcome (optimistic move confirmed vs rolled back).
    @State private var rescheduleOutcome: Bool?

    private var calendar: Calendar { CalendarRange.isoCalendar }

    private var weekDays: [Date] {
        let range = CalendarRange.week(containing: viewModel.referenceDate, calendar: calendar)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: range.lowerBound) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(weekDays, id: \.self) { day in
                    dayColumn(for: day)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .sensoryFeedback(trigger: rescheduleOutcome) { _, newValue in
            guard let newValue else { return nil }
            return newValue ? .success : .error
        }
    }

    private func dayColumn(for day: Date) -> some View {
        let posts = postsForDay(day)
        return VStack(alignment: .leading, spacing: 4) {
            Text(Self.dayHeader(day))
                .font(.subheadline.weight(.semibold))
                .accessibilityLabel(Self.dayHeader(day))

            if posts.isEmpty {
                Text("No posts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(posts, id: \.id) { post in
                    CalendarPostCard(
                        publishDate: post.publishDate, status: post.status,
                        channelName: post.integration?.name, channelPicture: post.integration?.picture,
                        content: post.content,
                        onPreview: post.group.map { group in { Task { await viewModel.loadPreview(group: group) } } },
                        onDuplicate: { Task { await viewModel.duplicate(post) } },
                        onDelete: post.group.map { group in { Task { await viewModel.delete(group: group) } } })
                        .draggable(post.group ?? "")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dropDestination(for: String.self) { groups, _ in
            guard let group = groups.first else { return false }
            reschedule(group: group, onto: day)
            return true
        }
        .accessibilityHint("Drop a dragged post here to reschedule it to \(Self.dayHeader(day))")
    }

    /// Drag-to-reschedule: keeps the dragged post's time-of-day, moves only the day, and
    /// records the outcome so `.sensoryFeedback` fires the matching haptic. The optimistic
    /// move + rollback itself lives in `CalendarViewModel.reschedule(group:to:)`.
    private func reschedule(group: String, onto day: Date) {
        let originalISO = viewModel.posts.first(where: { $0.group == group })?.publishDate
        let target = Self.combinedDate(day: day, timeFrom: originalISO, calendar: calendar)
        Task {
            let succeeded = await viewModel.reschedule(group: group, to: target)
            rescheduleOutcome = succeeded
        }
    }

    private static func combinedDate(day: Date, timeFrom iso: String?, calendar: Calendar) -> Date {
        guard let iso, let original = ISO8601DateFormatter().date(from: iso) else { return day }
        let time = calendar.dateComponents([.hour, .minute, .second], from: original)
        return calendar.date(
            bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: time.second ?? 0, of: day)
            ?? day
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

    private static func dayHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
}
