//
//  ContentView.swift
//  SandboxBundler
//
//  Created by Aris Koxaras on 29/10/24.
//

import SwiftUI

struct ContentView: View {
    @State private var fileType = FileType.universal
    @State private var universalBinary: BinaryFile?
    @State private var arm64Binary: BinaryFile?
    @State private var x86_64Binary: BinaryFile?
    @State private var exportError: ExportError?
    @State private var bundleID: String = ""

    enum FileType: String, CaseIterable, Identifiable {
        case universal = "Universal Binary"
        case separate = "Separate architectures"

        var id: String { self.rawValue }
    }

    var body: some View {
        VStack {
            Picker("", selection: $fileType) {
                ForEach(FileType.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            switch fileType {
            case .universal:
                Droppable(architecture: .universal, binaryFile: $universalBinary)
            case .separate:
                HStack {
                    Droppable(architecture: .arm64, binaryFile: $arm64Binary)
                    Droppable(architecture: .intel64, binaryFile: $x86_64Binary)
                }
            }

            VStack {
                Text("Application's bundle id")
                TextField("com.example.app", text: $bundleID)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 250)

                Text(
"""
Add only your app's bundle id. Do not include the Team ID, 
the App ID Prefix, or the bundled executable name
""")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 5)
            }
            .padding(.vertical)

            Button("Export signed binary") {
                exportBinary()
            }
            .padding(.vertical)

        }
        .padding()
        .alert(item: $exportError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .cancel()
            )
        }
    }

    func exportBinary() {
        Task {
            do {
                let _ = try filesAreValid()
                let _ = try bundleIDisValid()
                guard let outputDir = selectOutputFolder() else {
                    return
                }

                let inputURL: URL
                let outputFileName: String

                switch fileType {
                case .universal:
                    inputURL = universalBinary!.url!
                    outputFileName = inputURL.lastPathComponent
                case .separate:
                    inputURL = try await combineBinaries()
                    outputFileName = arm64Binary!.url!.lastPathComponent
                }

                let outputURL = outputDir.appendingPathComponent(outputFileName)

                try FileManager.default.copyItem(at: inputURL, to: outputURL)

                try await codesign(file: outputURL)

                self.exportError = ExportError(title: "Success", message: "The file was signed successfully")

            } catch let exportError as ExportError {
                self.exportError = exportError
            } catch {
                self.exportError = ExportError(message: error.localizedDescription)
            }
        }

    }

    func bundleIDisValid() throws(ExportError) -> Bool {
        guard bundleID.count > 0 else {
            throw ExportError(message: "Bundle ID is missing")
        }
        return true
    }

    func filesAreValid() throws(ExportError) -> Bool {
        switch fileType {
        case .universal:
            guard let universalBinary else {
                throw ExportError(message: "Universal binary is missing")
            }
            guard case .universal = universalBinary.architecture else {
                throw ExportError(message: "Select a file which is a universal binary")
            }
            return true
        case .separate:
            guard let arm64Binary = arm64Binary else {
                throw ExportError(message: "ARM64 binary is missing")
            }
            guard case .arm64 = arm64Binary.architecture else {
                throw ExportError(message: "Select a file which is an ARM64 binary")
            }
            guard let x86_64Binary = x86_64Binary else {
                throw ExportError(message: "x86_64 binary is missing")
            }
            guard case .intel64 = x86_64Binary.architecture else {
                throw ExportError(message: "Select a file which is an x86_64 binary")
            }
            return true
        }
    }

    // Returns a temporary url
    func combineBinaries() async throws(ExportError) -> URL {
        guard let fileX86 = x86_64Binary?.url, let fileARM = arm64Binary?.url else {
            throw ExportError(message: "Missing binaries")
        }

        let lipoURL = URL(fileURLWithPath: "/usr/bin/lipo")

        let tempDirectory = FileManager.default.temporaryDirectory
        let outputURL = tempDirectory.appendingPathComponent(UUID().uuidString)

        do {
            let result = try await Process.runAsync(
                url: lipoURL,
                arguments: [
                    "-create",
                    "-output",
                    outputURL.path(),
                    fileX86.path(),
                    fileARM.path()
                ]
            )
            debugPrint("got result \(result.standard) \(result.error)")
            return outputURL
        } catch {
            throw ExportError(message: "Failed to combine binaries: \(error.localizedDescription)")
        }

    }

    private func selectOutputFolder() -> URL? {
        let dialog = NSOpenPanel()
        dialog.title = "Choose a destination folder"
        dialog.canChooseFiles = false
        dialog.canChooseDirectories = true
        dialog.allowsMultipleSelection = false
        dialog.prompt = "Select Folder"

        guard dialog.runModal() == .OK, let result = dialog.url else {
            return nil
        }
        return result
    }

    private func codesign(file: URL) async throws(ExportError) {
        let codesignURL = URL(fileURLWithPath: "/usr/bin/codesign")
        let bundledEntitlements = Bundle.main.url(forResource: "exported_entitlements", withExtension: "plist")!

        do {
            let result = try await Process.runAsync(
                url: codesignURL,
                arguments: [
                    "-s",
                    "-",
                    "-i",
                    bundleID,
                    "-o",
                    "runtime",
                    "--entitlements",
                    bundledEntitlements.path(),
                    "-f",
                    file.path()
                ]
            )
            debugPrint("got result \(result.standard) \(result.error)")
        } catch {
            throw ExportError(message: "Failed to codesign \(error.localizedDescription)")
        }

    }
}

struct ExportError: Error, Identifiable, LocalizedError {
    var title: String = "Error"
    var message: String

    var id: String { return message }

    var errorDescription: String? {
        return message
    }
}


#Preview {
    ContentView()
}
