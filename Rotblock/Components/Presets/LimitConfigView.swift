//
//  LimitConfigView.swift
//  Rotblock
//

import CoreLocation
import FamilyControls
import MapKit
import SwiftUI

@MainActor
struct LimitConfigView: View {
    // MARK: - Inputs

    /// The preset being edited. `nil` means create a new preset.
    var presetID: UUID?

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(DeviceActivityManager.self) private var deviceActivity: DeviceActivityManager
    @Environment(PresetActivationService.self) private var activationService

    // MARK: - State

    @State private var name: String = "Deep work"
    @State private var hours: Double = 3
    @State private var selection: FamilyActivitySelection = .init()
    @State private var showingPicker = false

    @State private var scheduleOn = false
    @State private var startTime: Date = Self.defaultTime(hour: 9)
    @State private var endTime: Date = Self.defaultTime(hour: 12)
    @State private var selectedDays: Set<Weekday> = [
        .monday, .tuesday, .wednesday, .thursday, .friday,
    ]

    @State private var showDeleteConfirm = false
    @State private var saveError: String?
    @State private var locationAuth = LocationAuthMonitor()
    @State private var showLocationDeniedAlert = false
    @State private var pendingLocationSwitch = false

    /// Blocks stacked on this preset. Multiple kinds can be combined (e.g. location + opens).
    @State private var selectedBlocks: Set<LimitType> = [.timer]
    @State private var openLimitCount: Int = 5
    @State private var isPerOpenTimeLimitEnabled = false
    @State private var perOpenMinutes: Int = 10

    /// Display order for block chips and the order blocks are saved in.
    private static let blockOrder: [LimitType] = [.timer, .allowedHour, .location, .open]

    // Location-limit state. Not persisted — pure UI scaffolding for now.
    @State private var locationQuery: String = ""
    @State private var locationMode: LocationMode = .blockOnlyHere
    @State private var selectedPlace: LocationPlace?
    @State private var mapCameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    @State private var locationSearchError: String?
    @State private var isSearchingLocation = false
    private enum LocationMode: String, CaseIterable, Identifiable {
        case blockOnlyHere = "Block only here"
        case allowOnlyHere = "Allow only here"
        var id: String {
            rawValue
        }
    }

    private struct LocationPlace: Identifiable, Equatable {
        let id = UUID()
        let name: String
        let address: String
        let coordinate: CLLocationCoordinate2D

        static func == (lhs: LocationPlace, rhs: LocationPlace) -> Bool {
            lhs.id == rhs.id
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.rbIvory100.ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 10)

                    nameSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 28)

                    blocksSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)

                    if selectedBlocks.contains(.timer) {
                        durationSection
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                            .accessibilityIdentifier("limitConfig.section.timer")
                    }

                    if selectedBlocks.contains(.allowedHour) {
                        allowedHourSection
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                            .accessibilityIdentifier("limitConfig.section.allowedHour")
                    }

                    if selectedBlocks.contains(.location) {
                        locationSection
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                            .accessibilityIdentifier("limitConfig.section.location")
                    }

                    if selectedBlocks.contains(.open) {
                        opensSection
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                            .accessibilityIdentifier("limitConfig.section.opens")
                    }

                    appsSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)

                    scheduleSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                }
                .padding(.bottom, 140)
            }

            saveBar
        }
        .onAppear(perform: hydrateFromPreset)
        .onChange(of: locationAuth.status) { _, newStatus in
            guard pendingLocationSwitch else { return }
            switch newStatus {
            case .authorizedAlways:
                pendingLocationSwitch = false
                selectedBlocks.insert(.location)
            case .denied, .restricted:
                pendingLocationSwitch = false
                showLocationDeniedAlert = true
            default:
                break
            }
        }
        .familyActivityPicker(isPresented: $showingPicker, selection: $selection)
        .alert("Delete preset?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: deletePreset)
        } message: {
            Text("\"\(name)\" will be removed. This can't be undone.")
        }
        .alert(
            "Couldn't save preset",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
        .alert("Location access required", isPresented: $showLocationDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Location presets need \"Always\" access to monitor your position. Enable it in Settings → Privacy & Security → Location Services → Rotblock."
            )
        }
    }

    private var allowedHourSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Allowed Window")
            RBCard(padding: 20, cornerRadius: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Apps are allowed only during this time range.")
                        .font(RBFont.sans(13))
                        .foregroundStyle(Color.rbCloud600)

                    HStack {
                        Text("Start")
                            .font(RBFont.sans(15))
                            .foregroundStyle(Color.rbSlate900)
                        Spacer()
                        DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .tint(Color.rbSlate900)
                    }

                    HStack {
                        Text("End")
                            .font(RBFont.sans(15))
                            .foregroundStyle(Color.rbSlate900)
                        Spacer()
                        DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .tint(Color.rbSlate900)
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(Color.rbIvory50)
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(Color.rbIvory300, lineWidth: 1))
                    Image(systemName: RBIcons.chevronLeft)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.rbSlate900)
                }
            }
            .buttonStyle(PressableButtonStyle())

            Spacer()

            Text(presetID == nil ? "NEW PRESET" : "EDIT PRESET")
                .font(RBFont.mono(12, weight: .regular))
                .tracking(0.8)
                .foregroundStyle(Color.rbCloud600)

            Spacer()

            if presetID != nil {
                Button(action: { showDeleteConfirm = true }) {
                    Text("Delete")
                        .font(RBFont.sans(14))
                        .foregroundStyle(Color.rbCloud600)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier("limitConfig.delete")
            } else {
                Color.clear.frame(width: 60, height: 36)
            }
        }
    }

    // MARK: - Name

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "Name")
            TextField("Name", text: $name)
                .font(RBFont.frauncesItalic(34))
                .foregroundStyle(Color.rbSlate900)
                .tint(Color.rbSlate900)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(false)
                .padding(.vertical, 4)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.rbIvory300)
                        .frame(height: 1)
                        .offset(y: 4)
                }
                .accessibilityIdentifier("limitConfig.nameField")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Blocks

    private var blocksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Blocks")
            Text("Stack as many as you want — they all apply at once.")
                .font(RBFont.sans(12))
                .foregroundStyle(Color.rbCloud600)
            HStack(spacing: 8) {
                ForEach(Self.blockOrder) { kind in
                    blockChip(kind)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggleBlock(_ kind: LimitType) {
        if selectedBlocks.contains(kind) {
            // Never allow deselecting down to zero blocks.
            guard selectedBlocks.count > 1 else { return }
            selectedBlocks.remove(kind)
            return
        }
        if kind == .location {
            switch locationAuth.status {
            case .authorizedAlways:
                break
            case .denied, .restricted:
                showLocationDeniedAlert = true
                return
            default:
                pendingLocationSwitch = true
                locationAuth.requestAlways()
                return
            }
        }
        selectedBlocks.insert(kind)
    }

    private func blockChip(_ kind: LimitType) -> some View {
        let isSelected = selectedBlocks.contains(kind)
        return Button {
            toggleBlock(kind)
        } label: {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: RBIcons.check)
                        .font(.system(size: 10, weight: .semibold))
                }
                Text(kind.shortLabel)
                    .font(RBFont.sans(13, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(isSelected ? Color.rbIvory100 : Color.rbSlate900)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.rbSlate900 : Color.rbIvory50)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.rbSlate900 : Color.rbIvory300, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("limitConfig.block.\(kind.shortLabel)")
    }

    private struct LocationLimitPanel: View {
        @Binding var locationQuery: String
        @Binding var locationMode: LimitConfigView.LocationMode
        @Binding var selectedPlace: LimitConfigView.LocationPlace?
        @Binding var mapCameraPosition: MapCameraPosition
        @Binding var locationSearchError: String?
        @Binding var isSearchingLocation: Bool

        @State private var completer = LocationCompleter()
        @State private var queryDebounceTask: Task<Void, Never>?

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "Location")
                VStack(spacing: 12) {
                    VStack(spacing: 4) {
                        searchField
                        if !completer.suggestions.isEmpty {
                            suggestionDropdown
                        }
                    }
                    locationModePicker
                    locationMap
                    if let place = selectedPlace {
                        locationSummary(place: place)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.rbIvory50)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.rbIvory300, lineWidth: 1)
                )
            }
        }

        private var searchField: some View {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.rbCloud500)
                TextField("Search an address", text: $locationQuery)
                    .font(RBFont.sans(15))
                    .foregroundStyle(Color.rbSlate900)
                    .tint(Color.rbSlate900)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(false)
                    .submitLabel(.search)
                    .onSubmit(runLocationSearch)
                    .onChange(of: locationQuery) { _, query in
                        queryDebounceTask?.cancel()
                        queryDebounceTask = Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(250))
                            guard !Task.isCancelled else { return }
                            completer.update(query: query)
                        }
                    }
                if isSearchingLocation {
                    ProgressView().controlSize(.small)
                } else if !locationQuery.isEmpty {
                    Button {
                        queryDebounceTask?.cancel()
                        locationQuery = ""
                        locationSearchError = nil
                        completer.suggestions = []
                        completer.update(query: "")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.rbCloud500)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.rbIvory100)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.rbIvory300, lineWidth: 1)
            )
        }

        private var locationModePicker: some View {
            HStack(spacing: 8) {
                ForEach(LimitConfigView.LocationMode.allCases) { mode in
                    let isSelected = locationMode == mode
                    Button {
                        locationMode = mode
                    } label: {
                        Text(mode.rawValue)
                            .font(RBFont.sans(13, weight: .medium))
                            .foregroundStyle(isSelected ? Color.rbIvory100 : Color.rbSlate900)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(isSelected ? Color.rbSlate900 : Color.rbIvory100)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(isSelected ? Color.rbSlate900 : Color.rbIvory300, lineWidth: 1)
                            )
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }

        private var locationMap: some View {
            Map(position: $mapCameraPosition) {
                if let place = selectedPlace {
                    Marker(place.name, coordinate: place.coordinate)
                        .tint(locationMode == .blockOnlyHere ? .red : .green)
                }
            }
            .mapStyle(.standard())
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.rbIvory300, lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                if let error = locationSearchError {
                    Text(error)
                        .font(RBFont.sans(12))
                        .foregroundStyle(Color.rbIvory100)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(Color.rbSlate900.opacity(0.85))
                        )
                        .padding(10)
                }
            }
        }

        private func locationSummary(place: LocationPlace) -> some View {
            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.rbSlate900)
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .font(RBFont.sans(14, weight: .medium))
                        .foregroundStyle(Color.rbSlate900)
                        .lineLimit(1)
                    Text(place.address)
                        .font(RBFont.sans(12))
                        .foregroundStyle(Color.rbCloud600)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
            }
        }

        private struct LocationSuggestionRow: Identifiable {
            let id: String
            let title: String
            let subtitle: String
            let completion: MKLocalSearchCompletion

            init(_ completion: MKLocalSearchCompletion) {
                self.completion = completion
                title = completion.title
                subtitle = completion.subtitle
                id = "\(completion.title)\n\(completion.subtitle)"
            }
        }

        private var suggestionRows: [LocationSuggestionRow] {
            completer.suggestions.prefix(5).map(LocationSuggestionRow.init)
        }

        private var suggestionDropdown: some View {
            VStack(spacing: 0) {
                ForEach(Array(suggestionRows.enumerated()), id: \.element.id) { idx, row in
                    if idx > 0 {
                        Color.rbIvory300.frame(height: 1)
                    }
                    Button {
                        selectSuggestion(row.completion)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "mappin")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.rbCloud500)
                                .frame(width: 16)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(row.title)
                                    .font(RBFont.sans(14, weight: .medium))
                                    .foregroundStyle(Color.rbSlate900)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if !row.subtitle.isEmpty {
                                    Text(row.subtitle)
                                        .font(RBFont.sans(12))
                                        .foregroundStyle(Color.rbCloud600)
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.rbIvory50)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.rbIvory300, lineWidth: 1)
            )
        }

        private func selectSuggestion(_ completion: MKLocalSearchCompletion) {
            locationQuery = completion.title
            completer.suggestions = []
            locationSearchError = nil
            isSearchingLocation = true

            Task {
                defer { isSearchingLocation = false }
                do {
                    let request = MKLocalSearch.Request(completion: completion)
                    let response = try await MKLocalSearch(request: request).start()
                    guard let item = response.mapItems.first else {
                        locationSearchError = "No match for \"\(completion.title)\""
                        return
                    }
                    let coordinate = item.location.coordinate
                    let place = LocationPlace(
                        name: item.name ?? completion.title,
                        address: LimitConfigView.formatAddress(for: item, fallbackQuery: completion.title),
                        coordinate: coordinate
                    )
                    selectedPlace = place
                    withAnimation(.easeInOut(duration: 0.35)) {
                        mapCameraPosition = .region(
                            MKCoordinateRegion(
                                center: coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            )
                        )
                    }
                } catch {
                    locationSearchError = "Couldn't search — try again."
                }
            }
        }

        private func runLocationSearch() {
            let query = locationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return }

            completer.suggestions = []
            locationSearchError = nil
            isSearchingLocation = true

            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.resultTypes = [.address, .pointOfInterest]

            Task {
                defer { isSearchingLocation = false }
                do {
                    let response = try await MKLocalSearch(request: request).start()
                    guard let item = response.mapItems.first else {
                        locationSearchError = "No match for \"\(query)\""
                        return
                    }
                    let coordinate = item.location.coordinate
                    let place = LocationPlace(
                        name: item.name ?? query,
                        address: LimitConfigView.formatAddress(for: item, fallbackQuery: query),
                        coordinate: coordinate
                    )
                    selectedPlace = place
                    withAnimation(.easeInOut(duration: 0.35)) {
                        mapCameraPosition = .region(
                            MKCoordinateRegion(
                                center: coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            )
                        )
                    }
                } catch {
                    locationSearchError = "Couldn't search — try again."
                }
            }
        }
    }

    // MARK: - Location

    private var locationSection: some View {
        LocationLimitPanel(
            locationQuery: $locationQuery,
            locationMode: $locationMode,
            selectedPlace: $selectedPlace,
            mapCameraPosition: $mapCameraPosition,
            locationSearchError: $locationSearchError,
            isSearchingLocation: $isSearchingLocation
        )
    }

    /// Formatted single-line address for an `MKMapItem` (iOS 26+:
    /// `addressRepresentations` / `address` instead of deprecated `placemark`).
    private static func formatAddress(for item: MKMapItem, fallbackQuery: String) -> String {
        if let reps = item.addressRepresentations,
           let line = reps.fullAddress(includingRegion: true, singleLine: true),
           !line.isEmpty {
            return line
        }
        if let full = item.address?.fullAddress, !full.isEmpty { return full }
        if let short = item.address?.shortAddress, !short.isEmpty { return short }
        return item.name ?? fallbackQuery
    }

    // MARK: - Open limit

    private var opensSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Opens")
            RBCard(padding: 20, cornerRadius: 18) {
                VStack(alignment: .leading, spacing: 16) {
                    openCounterRow
                    RBDivider()
                    perOpenToggleRow
                    if isPerOpenTimeLimitEnabled {
                        RBDivider()
                        perOpenMinutesRow
                    }
                }
            }
        }
    }

    private var openCounterRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Opens per day")
                    .font(RBFont.sans(15))
                    .foregroundStyle(Color.rbSlate900)
                Text(
                    "How many launches are allowed before block kicks in. Ex: opening an app counts as one open for the whole preset, not just for the app(sorry ill make it so u can do both l8r)"
                )
                .font(RBFont.sans(12))
                .foregroundStyle(Color.rbCloud600)
            }
            Spacer(minLength: 12)
            HStack(spacing: 14) {
                Button("-") {
                    openLimitCount = max(1, openLimitCount - 1)
                }
                .font(RBFont.sans(18, weight: .medium))
                .foregroundStyle(Color.rbSlate900)
                .buttonStyle(.plain)

                Text("\(openLimitCount)")
                    .font(RBFont.mono(13))
                    .foregroundStyle(Color.rbSlate900)
                    .frame(minWidth: 24)

                Button("+") {
                    openLimitCount = min(99, openLimitCount + 1)
                }
                .font(RBFont.sans(18, weight: .medium))
                .foregroundStyle(Color.rbSlate900)
                .buttonStyle(.plain)
            }
        }
    }

    private var perOpenToggleRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Time limit per open")
                    .font(RBFont.sans(15))
                    .foregroundStyle(Color.rbSlate900)
                Text("Get interrupted after a certain amount of time.")
                    .font(RBFont.sans(12))
                    .foregroundStyle(Color.rbCloud600)
            }
            Spacer(minLength: 12)
            RBToggle(isOn: $isPerOpenTimeLimitEnabled)
        }
    }

    private let perOpenMinuteOptions = Array(2...60) // or 5...120 in steps of 5
    private var perOpenMinutesRow: some View {
        HStack {
            Text("Minutes per open")
                .font(RBFont.sans(15))
                .foregroundStyle(Color.rbSlate900)
            Spacer(minLength: 12)
            Picker("Minutes per open", selection: $perOpenMinutes) {
                ForEach(perOpenMinuteOptions, id: \.self) { min in
                    Text("\(min) min").tag(min)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.rbSlate900)
            .font(RBFont.mono(13))
        }
    }

    // MARK: - Duration

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Duration")
            RBCard(padding: 20, cornerRadius: 18) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(timerDurationLabel)")
                            .font(RBFont.headline(44, weight: .regular))
                            .foregroundStyle(Color.rbSlate900)
                    }
                    .padding(.bottom, 4)

                    Text("Blocks remain active for \(timerDurationLabel) once you start.")
                        .font(RBFont.sans(13))
                        .foregroundStyle(Color.rbCloud600)
                        .padding(.bottom, 18)

                    RBSlider(value: $hours, range: 0.25...8, step: 0.25)

                    HStack {
                        Text("1h")
                        Spacer()
                        Text("4h")
                        Spacer()
                        Text("8h")
                    }
                    .font(RBFont.mono(11))
                    .foregroundStyle(Color.rbCloud500)
                    .padding(.top, 8)
                }
            }
        }
    }

    // MARK: - Apps

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow(text: "Apps to block")
                Spacer()
                Text("\(selectedCount) selected")
                    .font(RBFont.mono(11))
                    .foregroundStyle(Color.rbCloud500)
            }

            Button(action: { showingPicker = true }) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.rbOrangeTint)
                            .frame(width: 36, height: 36)
                        Image(systemName: RBIcons.shield)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Color.rbSlate900)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedCount == 0 ? "Choose apps & categories" : "Edit selection")
                            .font(RBFont.sans(15, weight: .medium))
                            .foregroundStyle(Color.rbSlate900)
                        Text(selectionSummary)
                            .font(RBFont.sans(12))
                            .foregroundStyle(Color.rbCloud600)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: RBIcons.chevronRight)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.rbCloud500)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.rbIvory50)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.rbIvory300, lineWidth: 1)
                )
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private var selectedCount: Int {
        selection.applicationTokens.count
            + selection.categoryTokens.count
            + selection.webDomainTokens.count
    }

    private var selectionSummary: String {
        if selectedCount == 0 { return "None yet — tap to pick" }
        var parts: [String] = []
        let apps = selection.applicationTokens.count
        let cats = selection.categoryTokens.count
        let webs = selection.webDomainTokens.count
        if apps > 0 { parts.append("\(apps) app\(apps == 1 ? "" : "s")") }
        if cats > 0 { parts.append("\(cats) categor\(cats == 1 ? "y" : "ies")") }
        if webs > 0 { parts.append("\(webs) site\(webs == 1 ? "" : "s")") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 0) {
                if scheduleOn {
                    RBDivider()
                    scheduleRow(label: "Start", isLast: false) {
                        DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .tint(Color.rbSlate900)
                            .font(RBFont.mono(14))
                    }
                    RBDivider()
                    scheduleRow(label: "End", isLast: false) {
                        DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .tint(Color.rbSlate900)
                            .font(RBFont.mono(14))
                    }
                    RBDivider()
                    scheduleRow(label: "Days", isLast: true) {
                        dayChips
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.rbIvory50)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.rbIvory300, lineWidth: 1)
            )
        }
    }

    private func scheduleRow<Accessory: View>(
        label: String,
        isLast _: Bool,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        HStack {
            Text(label)
                .font(RBFont.sans(15))
                .foregroundStyle(Color.rbSlate900)
            Spacer()
            accessory()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var dayChips: some View {
        HStack(spacing: 4) {
            ForEach(Self.orderedWeekdays, id: \.self) { day in
                let on = selectedDays.contains(day)
                Button {
                    if on { selectedDays.remove(day) } else { selectedDays.insert(day) }
                } label: {
                    Text(Self.singleLetter(for: day))
                        .font(RBFont.sans(10, weight: .semibold))
                        .foregroundStyle(on ? Color.rbIvory100 : Color.rbCloud500)
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(on ? Color.rbSlate900 : Color.clear)
                        )
                        .overlay(
                            Circle()
                                .stroke(on ? Color.rbSlate900 : Color.rbCloud400, lineWidth: 1)
                        )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    // MARK: - Save bar

    private var saveBar: some View {
        HStack(spacing: 10) {
            RBButton(title: "Cancel", style: .ghost, fullWidth: true) { dismiss() }
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("limitConfig.cancel")

            RBButton(title: "Save preset", style: .primary, icon: RBIcons.check, fullWidth: true) {
                savePreset()
            }
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("limitConfig.save")
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 34)
        .background(
            LinearGradient(
                colors: [Color.rbIvory100.opacity(0), Color.rbIvory100],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Hydrate

    private func hydrateFromPreset() {
        guard let id = presetID else { return }
        guard let p = PresetStore.shared.preset(id: id) else { return }

        name = p.name
        selection = p.selection

        selectedBlocks = Set(p.blockKinds)

        if let secs = p.timerLimitDurationSeconds, p.hasBlock(.timer) {
            hours = max(0.25, min(8, (secs / 900).rounded() * 0.25))
        }

        openLimitCount = max(1, p.openLimitCount ?? openLimitCount)

        if let sessionSeconds = p.openSessionSeconds, sessionSeconds > 0 {
            isPerOpenTimeLimitEnabled = true
            perOpenMinutes = max(1, Int((sessionSeconds / 60).rounded()))
        } else {
            isPerOpenTimeLimitEnabled = false
        }

        if let lat = p.locationLatitude, let lon = p.locationLongitude {
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            selectedPlace = LocationPlace(
                name: "Saved location",
                address: "Saved preset location",
                coordinate: coordinate
            )
            mapCameraPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            )
        } else {
            selectedPlace = nil
        }

        if p.locationMode == LocationZoneMode.allowed.rawValue {
            locationMode = .allowOnlyHere
        } else {
            locationMode = .blockOnlyHere
        }
        if p.hasBlock(.allowedHour) {
            startTime = Self.date(hour: p.allowedStartHour ?? 9, minute: p.allowedStartMinute ?? 0)
            endTime = Self.date(hour: p.allowedEndHour ?? 17, minute: p.allowedEndMinute ?? 0)
        }
        if let sched = p.decodedSchedule {
            scheduleOn = sched.isActive
            startTime = Self.date(hour: sched.startHour, minute: sched.startMinute)
            endTime = Self.date(hour: sched.endHour, minute: sched.endMinute)
            selectedDays = Set(sched.days)
        } else {
            scheduleOn = false
        }
    }

    private func syncOpenLimitKeysIfEditingActivePreset(_ values: PresetValues) {
        guard deviceActivity.activePresetIDs.contains(values.id) else { return }
        ShieldOpenLimit.reconcileSharedKeys(
            allPresets: PresetStore.shared.allPresets(),

            activePresetIDs: deviceActivity.activePresetIDs,
            touchedPreset: values
        )
    }

    // MARK: - Save / Delete

    private func savePreset() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            saveError = "Give your preset a name first."
            return
        }

        let schedule: LimitPresetSchedule? = {
            guard scheduleOn else { return nil }
            let startParts = Self.hourMinute(from: startTime)
            let endParts = Self.hourMinute(from: endTime)
            return LimitPresetSchedule(
                days: Array(selectedDays).sorted { $0.rawValue < $1.rawValue },
                startHour: startParts.hour,
                startMinute: startParts.minute,
                endHour: endParts.hour,
                endMinute: endParts.minute
            )
        }()

        let scheduleData = schedule.flatMap { try? JSONEncoder().encode($0) }

        let blockKinds = Self.blockOrder.filter { selectedBlocks.contains($0) }
        guard !blockKinds.isEmpty else {
            saveError = "Add at least one block to this preset."
            return
        }

        let existing = presetID.flatMap { PresetStore.shared.preset(id: $0) }

        let hasLocationBlock = blockKinds.contains(.location)
        let locationLatitude =
            hasLocationBlock
                ? (selectedPlace?.coordinate.latitude ?? existing?.locationLatitude) : nil
        let locationLongitude =
            hasLocationBlock
                ? (selectedPlace?.coordinate.longitude ?? existing?.locationLongitude) : nil
        if hasLocationBlock, locationLatitude == nil || locationLongitude == nil {
            saveError = "Pick a location for the location block first."
            return
        }

        let allowedRange: (startH: Int, startM: Int, endH: Int, endM: Int)? = {
            guard blockKinds.contains(.allowedHour) else { return nil }
            let start = Self.hourMinute(from: startTime)
            let end = Self.hourMinute(from: endTime)
            return (start.hour, start.minute, end.hour, end.minute)
        }()

        let timerLimitDurationSeconds = blockKinds.contains(.timer) ? (hours * 3600) : nil
        let hasOpenBlock = blockKinds.contains(.open)
        let openLimitCountForSave = hasOpenBlock ? max(1, openLimitCount) : nil
        let openSessionSecondsForSave: Double? = {
            guard hasOpenBlock, isPerOpenTimeLimitEnabled else { return nil }
            return Double(max(1, perOpenMinutes) * 60)
        }()

        let locationRadius: Double? = {
            guard hasLocationBlock else { return nil }
            return existing?.locationRadius ?? 200
        }()
        let locationModeRaw: String? = {
            guard hasLocationBlock else { return nil }
            return locationMode == .allowOnlyHere
                ? LocationZoneMode.allowed.rawValue
                : LocationZoneMode.blocked.rawValue
        }()

        let values = PresetValues(
            id: existing?.id ?? UUID(),
            name: trimmed,
            createdAt: existing?.createdAt ?? Date(),
            selection: selection,
            blockKinds: blockKinds,
            timerLimitDurationSeconds: timerLimitDurationSeconds,
            allowedStartHour: allowedRange?.startH,
            allowedStartMinute: allowedRange?.startM,
            allowedEndHour: allowedRange?.endH,
            allowedEndMinute: allowedRange?.endM,
            locationLatitude: locationLatitude,
            locationLongitude: locationLongitude,
            locationRadius: locationRadius,
            locationMode: locationModeRaw,
            openLimitCount: openLimitCountForSave,
            openSessionSeconds: openSessionSecondsForSave,
            scheduleData: scheduleData
        )

        PresetStore.shared.save(values)
        syncOpenLimitKeysIfEditingActivePreset(values)
        dismiss()
    }

    private func deletePreset() {
        guard let id = presetID,
              let preset = PresetStore.shared.preset(id: id)
        else { return }
        if deviceActivity.activePresetIDs.contains(id) {
            activationService.deactivate(preset)
        }
        PresetStore.shared.delete(id: id)
        dismiss()
    }

    // MARK: - Time helpers

    private static func defaultTime(hour: Int) -> Date {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }

    private static func date(hour: Int, minute: Int) -> Date {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps) ?? Date()
    }

    private static func hourMinute(from date: Date) -> (hour: Int, minute: Int) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0, comps.minute ?? 0)
    }

    // MARK: - helpers

    private var timerDurationLabel: String {
        let totalMinutes = Int(hours * 60)
        let h = totalMinutes / 60
        let m = totalMinutes % 60

        if h > 0 && m > 0 { return "\(h) hr \(m) min" }
        if h > 0 { return "\(h) hr" }
        return "\(m) min"
    }

    /// Weekdays ordered Monday → Sunday.
    private static let orderedWeekdays: [Weekday] = [
        .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday,
    ]

    private static func singleLetter(for day: Weekday) -> String {
        switch day {
        case .monday, .tuesday, .thursday, .sunday, .saturday: return String(day.shortLabel.prefix(1))
        case .wednesday: return "W"
        case .friday: return "F"
        }
    }
}

// MARK: - Previews

#Preview("New preset") {
    LimitConfigView()
        .environment(DeviceActivityManager())
}

#Preview("Edit preset (timer)") {
    let preset = PresetValues(
        id: UUID(),
        name: "Deep work",
        blockKinds: [.timer],
        timerLimitDurationSeconds: 10800
    )
    PresetStore.shared.save(preset)
    return LimitConfigView(presetID: preset.id)
        .environment(DeviceActivityManager())
}
