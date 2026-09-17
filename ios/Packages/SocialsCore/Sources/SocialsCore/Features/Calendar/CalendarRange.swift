import Foundation

/// Day/week/month range calculators mirroring web's `getDateRange`
/// (`apps/frontend/src/components/launches/calendar.context.tsx`) — week is ISO (Monday-start),
/// matching dayjs's `isoWeek` plugin there.
public enum CalendarRange {
    /// ISO-8601 calendar (Monday first weekday) used for week/month bucketing.
    public static var isoCalendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar
    }

    public static func day(containing date: Date, calendar: Calendar = isoCalendar) -> ClosedRange<Date> {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? start
        return start...end
    }

    public static func week(containing date: Date, calendar: Calendar = isoCalendar) -> ClosedRange<Date> {
        let interval =
            calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 0)
        let end = calendar.date(byAdding: .second, value: -1, to: interval.end) ?? interval.end
        return interval.start...end
    }

    public static func month(containing date: Date, calendar: Calendar = isoCalendar) -> ClosedRange<Date> {
        let interval = calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 0)
        let end = calendar.date(byAdding: .second, value: -1, to: interval.end) ?? interval.end
        return interval.start...end
    }

    /// Returns the fetch window for `display` at `referenceDate`, or `nil` for `.list` (which
    /// paginates instead of windowing by date, mirroring web's list SWR key).
    public static func range(
        for display: CalendarDisplay, referenceDate: Date, calendar: Calendar = isoCalendar
    ) -> ClosedRange<Date>? {
        switch display {
        case .day: return day(containing: referenceDate, calendar: calendar)
        case .week: return week(containing: referenceDate, calendar: calendar)
        case .month: return month(containing: referenceDate, calendar: calendar)
        case .list: return nil
        }
    }
}
