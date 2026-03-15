import SwiftUI
import UniformTypeIdentifiers

struct ClipboardCardView: View {
    let item: ClipboardItem
    let isFirst: Bool
    let isSelected: Bool
    let isFocused: Bool
    let numberBadge: Int?
    let onSelect: () -> Void
    let onToggleSelect: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void

    @State private var isHovered = false

    private var fileMissing: Bool {
        item.contentType == .file && !item.filesExist
    }

    private var borderColor: Color {
        if isFocused { return Color.accentColor }
        if isSelected { return Color.accentColor.opacity(0.7) }
        if isFirst { return Color.accentColor.opacity(0.5) }
        if isHovered { return Color.accentColor.opacity(0.3) }
        return Color.white.opacity(0.1)
    }

    private var borderWidth: CGFloat {
        if isFocused { return 2.5 }
        if isSelected { return 2 }
        if isFirst { return 1.5 }
        return 1
    }

    private var cardBackground: Color {
        if isSelected { return Color.accentColor.opacity(0.18) }
        if isHovered { return Color.accentColor.opacity(0.12) }
        return Color(.controlBackgroundColor).opacity(0.6)
    }

    var body: some View {
        cardContent
            .onDrag {
                itemProvider(for: item)
            }
            .onHover { hovering in
                isHovered = hovering
            }
            .opacity(fileMissing ? 0.5 : 1.0)
            .help(fileMissing ? "File no longer exists" : "")
    }

    private var cardContent: some View {
        ZStack(alignment: .topLeading) {
            // Main card button — click to paste
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 6) {
                    // Top row: content type badge + timestamp
                    HStack(spacing: 4) {
                        Image(systemName: item.contentType.sfSymbolName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if item.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.orange)
                        }

                        Spacer()

                        Text(TimeFormatter.relativeString(from: item.copiedAt))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    // Content area
                    contentPreview
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                    // Bottom: detail label
                    HStack {
                        Spacer()
                        Text(item.detailLabel)
                            .font(.system(size: 9))
                            .foregroundStyle(.quaternary)
                    }
                }
                .padding(10)
                .frame(width: 136, height: 116)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(borderColor, lineWidth: borderWidth)
                )
                .scaleEffect(isHovered ? 1.03 : 1.0)
                .shadow(color: isHovered ? .black.opacity(0.15) : .clear, radius: 4, y: 2)
                .animation(.easeOut(duration: 0.15), value: isHovered)
                .animation(.easeOut(duration: 0.15), value: isSelected)
                .animation(.easeOut(duration: 0.15), value: isFocused)
            }
            .buttonStyle(.plain)

            // Hover controls overlay
            if isHovered || isSelected {
                // Top-left: selection checkbox
                Button(action: onToggleSelect) {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.accentColor : Color(.controlBackgroundColor).opacity(0.8))
                            .frame(width: 20, height: 20)
                        Circle()
                            .strokeBorder(isSelected ? Color.accentColor : Color.white.opacity(0.3), lineWidth: 1)
                            .frame(width: 20, height: 20)
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: 4)
                .transition(.opacity)
            }

            // Number badge (quick-paste keys 1-9)
            if let badge = numberBadge, !isHovered, !isSelected {
                Text("\(badge)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.secondary.opacity(0.5)))
                    .offset(x: 8, y: 92)
            }

            if isHovered {
                // Top-right: delete + pin buttons
                HStack(spacing: 2) {
                    Button(action: onTogglePin) {
                        Image(systemName: item.isPinned ? "pin.slash.fill" : "pin")
                            .font(.system(size: 9))
                            .foregroundStyle(item.isPinned ? .orange : .secondary)
                            .frame(width: 18, height: 18)
                            .background(
                                Circle()
                                    .fill(Color(.controlBackgroundColor).opacity(0.85))
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 18, height: 18)
                            .background(
                                Circle()
                                    .fill(Color(.controlBackgroundColor).opacity(0.85))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .offset(x: 98, y: 4)
                .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private var contentPreview: some View {
        switch item.contentType {
        case .image:
            if let nsImage = item.nsImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

        case .file:
            filePreview

        case .code:
            Text(item.previewText)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .foregroundStyle(.primary)

        default:
            Text(item.previewText)
                .font(.system(.caption))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .foregroundStyle(.primary)
        }
    }

    @ViewBuilder
    private var filePreview: some View {
        if let urls = item.fileURLs {
            VStack(spacing: 4) {
                if urls.count == 1 {
                    let url = urls[0]
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                        .resizable()
                        .frame(width: 32, height: 32)
                    Text(url.lastPathComponent)
                        .font(.caption)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                } else {
                    ZStack {
                        ForEach(0..<min(urls.count, 3), id: \.self) { i in
                            Image(nsImage: NSWorkspace.shared.icon(forFile: urls[i].path))
                                .resizable()
                                .frame(width: 28, height: 28)
                                .offset(x: CGFloat(i * 6), y: CGFloat(i * -4))
                        }
                    }
                    Text("\(urls.count) files")
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Drag and Drop

    private func itemProvider(for item: ClipboardItem) -> NSItemProvider {
        switch item.contentType {
        case .text, .code, .url, .richText:
            return NSItemProvider(object: (item.textContent ?? "") as NSString)

        case .image:
            if let data = item.imageData, let image = NSImage(data: data) {
                return NSItemProvider(object: image)
            }
            return NSItemProvider()

        case .file:
            if let urls = item.fileURLs, !urls.isEmpty {
                let provider = NSItemProvider()
                for url in urls {
                    provider.registerFileRepresentation(
                        forTypeIdentifier: UTType.fileURL.identifier,
                        visibility: .all
                    ) { completion in
                        completion(url, false, nil)
                        return nil
                    }
                }
                return provider
            }
            return NSItemProvider()
        }
    }
}
