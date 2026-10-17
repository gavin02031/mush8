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
    @State private var report: NSPInspectionReport?
    @State private var reportFile: URL?
    @State private var filename: String?
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

                    Text("Inspect the NSP file list directly on your iPhone. Your game dump stays on your device and is not uploaded or copied.")
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

                    if let current = report {
                        StatusTile(
                            icon: "checkmark.shield",
                            title: current.recognizedGame ?? "NSP package recognized",
                            detail: "\(current.packageRole) · \(ByteCountFormatter.string(fromByteCount: Int64(current.totalBytes), countStyle: .file))\nTitle ID: \(current.titleId ?? "Not found")"
                        )
                        StatusTile(
                            icon: "square.stack.3d.up",
                            title: "Package contents",
                            detail: "\(current.entryCount) entries · \(current.ncaCount) NCA archives\nTicket: \(current.hasTicket ? "Found" : "Not found") · Certificate: \(current.hasCertificate ? "Found" : "Not found")\nGame version: not yet verified"
                        )
                        Text("This report does not include game data, keys, or file paths. It cannot yet verify the game's compatibility.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if let reportFile {
                            ShareLink(item: reportFile, preview: SharePreview("Switch2iOS NSP report")) {
                                Label("Share metadata report (.json)", systemImage: "square.and.arrow.up")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 15)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(background)
                            .background(lavender, in: RoundedRectangle(cornerRadius: 16))
                        }
                    }

                    if let errorMessage {
                        StatusTile(icon: "exclamationmark.triangle", title: "Inspection failed", detail: errorMessage)
                    }

                    Text("Porting pipeline")
                        .font(.title3.bold())
                        .padding(.top, 3)

                    StatusTile(icon: "1.circle.fill", title: "Inspect", detail: "Read local NSP package metadata without uploading the game.")
                    StatusTile(icon: "2.circle.fill", title: "Adapt", detail: "Develop Odyssey-specific ARM64 patches, Switch services and Metal shaders.")
                    StatusTile(icon: "3.circle.fill", title: "Build", detail: "Compile a standalone playable app once game compatibility has been demonstrated.")

                    Text("Switch2iOS is a developer dashboard, not an emulator or automatic converter. No Odyssey executable or Nintendo files are bundled.")
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
        report = nil
        reportFile = nil
        filename = nil
        let granted = url.startAccessingSecurityScopedResource()
        defer {
            if granted { url.stopAccessingSecurityScopedResource() }
        }
        do {
            let result = try NSPInspector.inspect(url)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let json = try encoder.encode(result)
            let destination = FileManager.default.temporaryDirectory.appendingPathComponent("Switch2iOS-NSP-Report.json")
            try json.write(to: destination, options: .atomic)
            report = result
            reportFile = destination
            filename = url.lastPathComponent
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
