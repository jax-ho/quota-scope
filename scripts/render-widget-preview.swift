import AppKit
import Foundation
import SwiftUI
import WidgetKit

private struct PreviewRoot: View {
    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            VStack(alignment: .leading, spacing: 20) {
                preview(.systemSmall, scheme: .dark)
                preview(.systemSmall, scheme: .light)
            }

            VStack(alignment: .leading, spacing: 20) {
                preview(.systemMedium, scheme: .dark)
                preview(.systemMedium, scheme: .light)
            }

            VStack(alignment: .leading, spacing: 20) {
                preview(.systemLarge, scheme: .dark)
                preview(.systemLarge, scheme: .light)
            }
        }
        .padding(34)
        .background(Color(red: 0.91, green: 0.94, blue: 0.92))
    }

    private func preview(_ family: WidgetFamily, scheme: ColorScheme) -> some View {
        CodexWatcherWidgetView(entry: CodexUsageProvider.sampleEntry, familyOverride: family)
            .environment(\.colorScheme, scheme)
            .frame(width: size(for: family).width, height: size(for: family).height)
    }

    private func size(for family: WidgetFamily) -> CGSize {
        switch family {
        case .systemSmall:
            return CGSize(width: 160, height: 160)
        case .systemLarge:
            return CGSize(width: 340, height: 360)
        default:
            return CGSize(width: 340, height: 160)
        }
    }
}

@main
struct RenderWidgetPreview {
    @MainActor
    static func main() async throws {
        guard CommandLine.arguments.count > 1 else {
            throw NSError(domain: "QuotaScopePreview", code: 2)
        }

        let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let renderer = ImageRenderer(content: PreviewRoot())
        renderer.scale = 2

        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "QuotaScopePreview", code: 1)
        }

        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try png.write(to: outputURL)
        print(outputURL.path)
    }
}
