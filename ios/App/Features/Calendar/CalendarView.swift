import SocialsCore
import SwiftUI

/// Calendar screen: display switcher (day/week/agenda-list/month... `CalendarDisplay`), customer
/// selector, date navigation, and the matching content view. Owns one `CalendarViewModel`, wired
/// to the app's real `SocialsAPI`/`CacheStore` from `AppEnvironment` (mirrors `ChannelsListView`'s
/// composition). Mirrors web's `calendar.tsx` + `calendar.context.tsx` (display switch,
/// `select.customer.tsx` customer filter) and `CalendarContext.setFilters`.
struct CalendarView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: CalendarViewModel?
    @State private var customers: [ChannelCustomer] = []

    let orgId: String

    var body: some View {
        Group {
            if let viewModel {
                content(for: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Calendar")
        .task {
            if viewModel == nil {
                let model = CalendarViewModel(
                    api: environment.api, cacheStore: environment.cacheStore, orgId: orgId)
                viewModel = model
                await model.refresh()
                customers = (try? await environment.api.customers()) ?? []
            }
        }
    }

    @ViewBuilder
    private func content(for viewModel: CalendarViewModel) -> some View {
        VStack(spacing: 0) {
            displaySwitcher(for: viewModel)

            if viewModel.display != .list {
                dateNavigator(for: viewModel)
            }

            if !customers.isEmpty {
                customerSelector(for: viewModel)
            }

            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .accessibilityLabel("Calendar error")
                    .padding(.horizontal)
            }

            ZStack {
                switch viewModel.display {
                case .day, .list:
                    AgendaListView(viewModel: viewModel)
                case .week:
                    WeekGridView(viewModel: viewModel)
                case .month:
                    MonthGridView(viewModel: viewModel)
                }

                if viewModel.isLoading {
                    ProgressView()
                }
            }
        }
        .refreshable { await viewModel.refresh() }
    }

    private func displaySwitcher(for viewModel: CalendarViewModel) -> some View {
        Picker("Display", selection: displayBinding(for: viewModel)) {
            Text("Day").tag(CalendarDisplay.day)
            Text("Week").tag(CalendarDisplay.week)
            Text("Month").tag(CalendarDisplay.month)
            Text("List").tag(CalendarDisplay.list)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.top, 8)
        .accessibilityLabel("Calendar display")
    }

    private func displayBinding(for viewModel: CalendarViewModel) -> Binding<CalendarDisplay> {
        Binding(
            get: { viewModel.display },
            set: { newValue in Task { await viewModel.setDisplay(newValue) } })
    }

    private func dateNavigator(for viewModel: CalendarViewModel) -> some View {
        HStack {
            Button {
                Task { await viewModel.setReferenceDate(shiftedDate(-1, for: viewModel)) }
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Previous \(viewModel.display.rawValue)")

            Spacer()

            Text(Self.referenceDateLabel(viewModel.referenceDate, display: viewModel.display))
                .font(.headline)
                .accessibilityLabel(Self.referenceDateLabel(viewModel.referenceDate, display: viewModel.display))

            Spacer()

            Button {
                Task { await viewModel.setReferenceDate(shiftedDate(1, for: viewModel)) }
            } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel("Next \(viewModel.display.rawValue)")
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    private func shiftedDate(_ direction: Int, for viewModel: CalendarViewModel) -> Date {
        let component: Calendar.Component
        switch viewModel.display {
        case .day: component = .day
        case .week: component = .weekOfYear
        case .month: component = .month
        case .list: component = .day
        }
        return CalendarRange.isoCalendar.date(
            byAdding: component, value: direction, to: viewModel.referenceDate) ?? viewModel.referenceDate
    }

    private func customerSelector(for viewModel: CalendarViewModel) -> some View {
        Menu {
            Button("All customers") {
                Task { await viewModel.setCustomer(nil) }
            }
            ForEach(customers, id: \.id) { customer in
                Button(customer.name) {
                    Task { await viewModel.setCustomer(customer.id) }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedCustomerName(viewModel))
                Image(systemName: "chevron.down")
            }
            .font(.footnote)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .accessibilityLabel("Customer filter: \(selectedCustomerName(viewModel))")
    }

    private func selectedCustomerName(_ viewModel: CalendarViewModel) -> String {
        guard let customerId = viewModel.customer,
            let match = customers.first(where: { $0.id == customerId })
        else { return "All customers" }
        return match.name
    }

    private static func referenceDateLabel(_ date: Date, display: CalendarDisplay) -> String {
        let formatter = DateFormatter()
        switch display {
        case .day: formatter.dateFormat = "EEEE, MMM d, yyyy"
        case .week: formatter.dateFormat = "'Week of' MMM d, yyyy"
        case .month: formatter.dateFormat = "MMMM yyyy"
        case .list: formatter.dateFormat = "MMM d, yyyy"
        }
        return formatter.string(from: date)
    }
}
