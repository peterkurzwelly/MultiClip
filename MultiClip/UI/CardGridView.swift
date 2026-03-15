import SwiftUI

struct CardGridView: View {
    let store: ClipboardStore
    let showGeneration: Int
    let onItemSelected: (ClipboardItem) -> Void
    let onMultiPaste: ([ClipboardItem]) -> Void

    @State private var selectedIDs: Set<UUID> = []
    @State private var searchText: String = ""
    @State private var focusedIndex: Int? = nil
    @State private var appeared: Bool = false
    @FocusState private var searchFocused: Bool

    private let columns = Array(repeating: GridItem(.fixed(136), spacing: 12), count: 5)

    private var filteredUnpinned: [ClipboardItem] {
        let unpinned = store.unpinnedItems
        guard !searchText.isEmpty else { return unpinned }
        return filterItems(unpinned)
    }

    private var filteredPinned: [ClipboardItem] {
        let pinned = store.pinnedItems
        guard !searchText.isEmpty else { return pinned }
        return filterItems(pinned)
    }

    private var allFiltered: [ClipboardItem] {
        filteredUnpinned + filteredPinned
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with search
            headerBar
                .padding(.top, 14)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

            // Selection bar
            if !selectedIDs.isEmpty {
                selectionBar
            }

            // Content
            if store.items.isEmpty {
                emptyState
            } else if allFiltered.isEmpty {
                noResultsState
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Unpinned items grid
                        if !filteredUnpinned.isEmpty {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(Array(filteredUnpinned.enumerated()), id: \.element.id) { index, item in
                                    cardView(for: item, isFirst: index == 0 && searchText.isEmpty, gridIndex: index)
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        // Pinned section with divider
                        if !filteredPinned.isEmpty {
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "pin.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.orange)
                                    Text("Pinned")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    Rectangle()
                                        .fill(Color.white.opacity(0.08))
                                        .frame(height: 1)
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, filteredUnpinned.isEmpty ? 0 : 16)

                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(Array(filteredPinned.enumerated()), id: \.element.id) { index, item in
                                        cardView(for: item, isFirst: false, gridIndex: filteredUnpinned.count + index)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
        }
        .frame(width: 760, height: 560)
        .background(VisualEffectBlur())
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onKeyPress(.leftArrow) {
            guard !searchFocused else { return .ignored }
            moveFocus(by: -1); return .handled
        }
        .onKeyPress(.rightArrow) {
            guard !searchFocused else { return .ignored }
            moveFocus(by: 1); return .handled
        }
        .onKeyPress(.upArrow) {
            if searchFocused { searchFocused = false }
            moveFocus(by: -5); return .handled
        }
        .onKeyPress(.downArrow) {
            if searchFocused { searchFocused = false }
            moveFocus(by: 5); return .handled
        }
        .onKeyPress(.return) {
            guard focusedIndex != nil else { return .ignored }
            confirmFocused()
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "123456789")) { press in
            guard !searchFocused else { return .ignored }
            if let char = press.characters.first, let digit = char.wholeNumberValue {
                quickPaste(digit - 1)
                return .handled
            }
            return .ignored
        }
        .onChange(of: allFiltered.count) {
            if let idx = focusedIndex, idx >= allFiltered.count {
                focusedIndex = allFiltered.isEmpty ? nil : allFiltered.count - 1
            }
        }
        .task(id: showGeneration) {
            appeared = false
            focusedIndex = nil
            selectedIDs.removeAll()
            searchText = ""
            try? await Task.sleep(for: .milliseconds(20))
            guard !Task.isCancelled else { return }
            appeared = true
        }
    }

    // MARK: - Card

    private func cardView(for item: ClipboardItem, isFirst: Bool, gridIndex: Int) -> some View {
        ClipboardCardView(
            item: item,
            isFirst: isFirst && focusedIndex == nil,
            isSelected: selectedIDs.contains(item.id),
            isFocused: focusedIndex == gridIndex,
            numberBadge: gridIndex < 9 && searchText.isEmpty ? gridIndex + 1 : nil,
            onSelect: { onItemSelected(item) },
            onToggleSelect: { toggleSelection(item) },
            onDelete: { selectedIDs.remove(item.id); store.remove(item) },
            onTogglePin: { store.togglePin(item) }
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .animation(.easeOut(duration: 0.2).delay(Double(gridIndex) * 0.01), value: appeared)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)

                TextField("Search\u{2026}", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($searchFocused)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.controlBackgroundColor).opacity(0.5))
            )

            Text("\(store.items.count) items")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .frame(minWidth: 55, alignment: .trailing)
        }
    }

    // MARK: - Selection Bar

    private var selectionBar: some View {
        HStack(spacing: 12) {
            Text("\(selectedIDs.count) selected")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                selectedIDs.removeAll()
            } label: {
                Text("Clear")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Button {
                pasteSelected()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                    Text("Paste All  \u{2318}\u{21A9}")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor)
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Nothing copied yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Items you copy will appear here.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No matches")
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func filterItems(_ items: [ClipboardItem]) -> [ClipboardItem] {
        let query = searchText.lowercased()
        return items.filter { item in
            switch item.contentType {
            case .text, .code, .url, .richText:
                return item.textContent?.lowercased().contains(query) ?? false
            case .file:
                return item.fileURLs?.contains { $0.lastPathComponent.lowercased().contains(query) } ?? false
            case .image:
                return "image".hasPrefix(query) || query.hasPrefix("image") ||
                       "screenshot".hasPrefix(query) || query.hasPrefix("screenshot")
            }
        }
    }

    private func toggleSelection(_ item: ClipboardItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }

    private func pasteSelected() {
        let selected = store.items.filter { selectedIDs.contains($0.id) }
        guard !selected.isEmpty else { return }
        selectedIDs.removeAll()
        onMultiPaste(selected)
    }

    private func moveFocus(by offset: Int) {
        let items = allFiltered
        guard !items.isEmpty else { return }

        if let current = focusedIndex {
            let next = current + offset
            if next >= 0 && next < items.count {
                focusedIndex = next
            }
        } else {
            focusedIndex = 0
        }
    }

    private func confirmFocused() {
        guard let index = focusedIndex, index < allFiltered.count else { return }
        onItemSelected(allFiltered[index])
    }

    private func quickPaste(_ index: Int) {
        let items = allFiltered
        guard index >= 0, index < items.count else { return }
        onItemSelected(items[index])
    }
}

// MARK: - NSVisualEffectView wrapper

struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
