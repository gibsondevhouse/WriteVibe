//
//  AttachMenu.swift
//  WriteVibe
//

import SwiftUI
import UniformTypeIdentifiers

struct AttachMenu: View {
    var onDocumentAttached: ((String) -> Void)? = nil
    var onDocumentImportFailed: ((String) -> Void)? = nil
    var onShowURLAlert: (() -> Void)? = nil

    private let options: [(icon: String, label: String)] = [
        ("photo.on.rectangle", "Upload Image"),
        ("doc.text",           "Upload Document"),
        ("link",               "Attach URL"),
        ("mic",                "Voice Input"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(options, id: \.label) { opt in
                Button {
                    switch opt.label {
                    case "Upload Document":
                        Task { @MainActor in
                            do {
                                if let text = try await DocumentIngestionService.pickAndExtract() {
                                    onDocumentAttached?(text)
                                }
                            } catch {
                                onDocumentImportFailed?(error.localizedDescription)
                            }
                        }
                    case "Attach URL":
                        onShowURLAlert?()
                    case "Upload Image":
                        Task { @MainActor in
                            let panel = NSOpenPanel()
                            panel.allowedContentTypes = [.image]
                            panel.allowsMultipleSelection = false
                            if panel.runModal() == .OK, let url = panel.url {
                                onDocumentAttached?("[Image Attached: \(url.lastPathComponent)]")
                            }
                        }
                    case "Voice Input":
                        onDocumentImportFailed?("Voice Input coming soon (macOS 15+ Dictation API)")
                    default:
                        break
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: opt.icon)
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundStyle(.tint)
                            .frame(width: 20, alignment: .center)
                        Text(opt.label)
                            .font(.body)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                if opt.label != options.last!.label {
                    Divider()
                }
            }
        }
        .frame(width: 200)
        .padding(8)
    }
}
