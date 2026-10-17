import SwiftUI
import UniformTypeIdentifiers

@main
struct Switch2iOSApp: App {
    var body: some Scene {
        WindowGroup {
            PortLibraryView()
                .preferredColorScheme(.dark)
        }
    }
}

private struct DumpInspection {
    let filename: String
    let byteCount: Int64
    let kind: String
    let detail: String
}

private struct StatusTile: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(Color(red: 0.73, green: 0.78, blue: 1))
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 18))
    }
}

struct PortLibraryView: View {
    @State private var showImporter = false
    @State private var inspection: DumpInspection?
    @State private var errorMessage: String?

    private let lavender = Color(red: 0.75, green: 0.75, blue: 1)
    private let background = Color(red: 0.065, green: 0.073, blue: 0.11)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(lavender)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Switch2iOS")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            Text("Native port research · developer preview")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.top, 18)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("FIRST PORT TARGET")
                            .font(.caption.weight(.semibold))
                            .tracking(1.6)
                            .foregroundStyle(lavender)
                        Text("Super Mario Odyssey")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                        Text("Building a native iOS execution path with reusable components from Mush8.")
                            .foregroundStyle(.secondary)
                        Label("Research stage — not playable", systemImage: "hammer.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(lavender)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(22)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.22, green: 0.22, blue: 0.37), Color(red: 0.11, green: 0.13, blue: 0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 24)
                    )

                    Text("Local file inspection")
                        .font(.title3.bold())

                    Text("Inspect the header of your own NSP dump. This preview never uploads or stores the selected file and does not attempt to run game code.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button {
                        showImporter = true
                    } label: {
                        Label("Choose a game dump", systemImage: "doc.badge.plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(background)
                    .background(lavender, in: RoundedRectangle(cornerRadius: 16))
                    .fileImporter(
                        isPresented: $showImporter,
                        allowedContentTypes: [.data],
                        allowsMultipleSelection: false
                    ) { result in
                        switch result {
                        case .success(let urls):
                            guard let selected = urls.first else { return }
                            inspect(selected)
                        case .failure(let error):
                            errorMessage = error.localizedDescription
                        }
                    }

                    if let current = inspection {
                        StatusTile(
                            icon: "doc.text.magnifyingglass",
                            title: current.filename,
                            detail: "\(current.kind) · \(ByteCountFormatter.string(fromByteCount: current.byteCount, countStyle: .file))\n\(current.detail)"
                        )
                    }

                    if let errorMessage {
                        StatusTile(icon: "exclamationmark.triangle", title: "File inspection failed", detail: errorMessage)
                    }

                    Text("Porting pipeline")
                        .font(.title3.bold())
                        .padding(.top, 3)

                    StatusTile(icon: "1.circle.fill", title: "Inspect", detail: "Read your own game dump metadata locally.")
                    StatusTile(icon: "2.circle.fill", title: "Adapt", detail: "Develop per-game ARM64 patches, Switch services, graphics and shaders on a computer.")
                    StatusTile(icon: "3.circle.fill", title: "Build", detail: "Compile and sign a separate native IPA using an Apple toolchain.")

                    Text("This app is a native project dashboard, not an emulator or automatic game converter. No Odyssey executable or Nintendo files are bundled.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 18)
                }
                .padding(.horizontal, 20)
            }
            .background(background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func inspect(_ url: URL) {
        errorMessage = nil
        let granted = url.startAccessingSecurityScopedResource()
        defer {
            if granted { url.stopAccessingSecurityScopedResource() }
        }
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let header = try handle.read(upToCount: 16) ?? Data()
            let isNSP = header.starts(with: Data("PFS0".utf8))
            let kind = isNSP ? "NSP container header found" : "Unrecognized or unsupported header"
            let detail = isNSP
                ? "Container identified. Compatibility and ownership are not determined by this scan."
                : "Only the NSP/PFS0 header is recognized by this preview; no game data was extracted."
            inspection = DumpInspection(
                filename: url.lastPathComponent,
                byteCount: Int64(values.fileSize ?? 0),
                kind: kind,
                detail: detail
            )
        } catch {
            inspection = nil
            errorMessage = error.localizedDescription
        }
    }
}
