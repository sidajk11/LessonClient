//
//  UnitLevelListViewModel.swift
//  LessonClient
//
//  Created by Codex on 4/23/26.
//

import Foundation

@MainActor
final class UnitLevelListViewModel: ObservableObject {
    struct EditableUnitLevel: Identifiable, Equatable {
        let id: Int
        let original: UnitLevelRead
        var levelText: String
        var startUnitText: String
        var isSaving: Bool = false

        var hasChanges: Bool {
            levelText != String(original.level) || startUnitText != String(original.startUnit)
        }

        init(unitLevel: UnitLevelRead) {
            id = unitLevel.id
            original = unitLevel
            levelText = String(unitLevel.level)
            startUnitText = String(unitLevel.startUnit)
        }
    }

    @Published var items: [EditableUnitLevel] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    @Published var levelFilterText: String = ""
    @Published var startUnitFilterText: String = ""
    @Published var newLevelText: String = ""
    @Published var newStartUnitText: String = ""
    @Published var isCreating: Bool = false

    private let ds = UnitLevelDataSource.shared
    private let limit: Int = 100
    private var offset: Int = 0
    private var hasMore: Bool = true

    var canCreate: Bool {
        parsedPositiveInt(newLevelText) != nil &&
        parsedPositiveInt(newStartUnitText) != nil &&
        !isCreating
    }

    func refresh() async {
        errorMessage = nil

        guard let level = parsedFilter(from: levelFilterText, label: "레벨"),
              let startUnit = parsedFilter(from: startUnitFilterText, label: "시작 유닛") else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        offset = 0
        hasMore = true

        do {
            let result = try await ds.listUnitLevels(
                level: level,
                startUnit: startUnit,
                limit: limit,
                offset: offset
            )
            items = result.map(EditableUnitLevel.init)
            offset += result.count
            hasMore = result.count == limit
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMoreIfNeeded(current item: EditableUnitLevel) async {
        guard !isLoading, hasMore else { return }
        guard item.id == items.last?.id else { return }

        guard let level = parsedFilter(from: levelFilterText, label: "레벨"),
              let startUnit = parsedFilter(from: startUnitFilterText, label: "시작 유닛") else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await ds.listUnitLevels(
                level: level,
                startUnit: startUnit,
                limit: limit,
                offset: offset
            )
            items.append(contentsOf: result.map(EditableUnitLevel.init))
            offset += result.count
            hasMore = result.count == limit
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func create() async {
        errorMessage = nil

        guard let level = parsedPositiveInt(newLevelText),
              let startUnit = parsedPositiveInt(newStartUnitText) else {
            errorMessage = "새 유닛 레벨 값은 1 이상의 숫자여야 합니다."
            return
        }

        isCreating = true
        defer { isCreating = false }

        do {
            let created = try await ds.createUnitLevel(
                payload: UnitLevelCreate(level: level, startUnit: startUnit)
            )
            items.insert(EditableUnitLevel(unitLevel: created), at: 0)
            newLevelText = ""
            newStartUnitText = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sanitizeLevelFilter(_ value: String) {
        levelFilterText = value.filter(\.isNumber)
    }

    func sanitizeStartUnitFilter(_ value: String) {
        startUnitFilterText = value.filter(\.isNumber)
    }

    func sanitizeNewLevel(_ value: String) {
        newLevelText = value.filter(\.isNumber)
    }

    func sanitizeNewStartUnit(_ value: String) {
        newStartUnitText = value.filter(\.isNumber)
    }

    func updateLevelText(for item: EditableUnitLevel, value: String) {
        updateItem(item) { $0.levelText = value.filter(\.isNumber) }
    }

    func updateStartUnitText(for item: EditableUnitLevel, value: String) {
        updateItem(item) { $0.startUnitText = value.filter(\.isNumber) }
    }

    func save(_ item: EditableUnitLevel) async {
        errorMessage = nil

        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let current = items[index]

        guard let level = parsedPositiveInt(current.levelText),
              let startUnit = parsedPositiveInt(current.startUnitText) else {
            errorMessage = "레벨과 시작 유닛은 1 이상의 숫자여야 합니다."
            return
        }

        items[index].isSaving = true
        defer {
            if let currentIndex = items.firstIndex(where: { $0.id == item.id }) {
                items[currentIndex].isSaving = false
            }
        }

        do {
            let saved = try await ds.updateUnitLevel(
                id: item.id,
                payload: UnitLevelUpdate(level: level, startUnit: startUnit)
            )
            if let savedIndex = items.firstIndex(where: { $0.id == item.id }) {
                items[savedIndex] = EditableUnitLevel(unitLevel: saved)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reset(_ item: EditableUnitLevel) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = EditableUnitLevel(unitLevel: items[index].original)
    }

    func delete(_ item: EditableUnitLevel) async {
        errorMessage = nil

        do {
            try await ds.deleteUnitLevel(id: item.id)
            items.removeAll { $0.id == item.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateItem(
        _ item: EditableUnitLevel,
        mutate: (inout EditableUnitLevel) -> Void
    ) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        mutate(&items[index])
    }

    private func parsedFilter(from raw: String, label: String) -> Int?? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .some(nil) }
        guard let value = parsedPositiveInt(trimmed) else {
            errorMessage = "\(label)은 1 이상의 숫자여야 합니다."
            return .none
        }
        return .some(value)
    }

    private func parsedPositiveInt(_ raw: String) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value >= 1 else { return nil }
        return value
    }
}
