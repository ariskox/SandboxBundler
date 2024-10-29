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
    @State private var exportError: BundlerError?
    @State private var bundleID: String = ""


    private var outputFileName: String? {
        switch fileType {
        case .separate:
            return arm64Binary?.url?.lastPathComponent
        case .universal:
            return universalBinary?.url?.lastPathComponent
        }
    }

    private var fullBundleID: String? {
        guard let outputFileName = outputFileName, bundleID.count > 0 else {
            return nil
        }
        return bundleID + "." + outputFileName
    }

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
the App ID Prefix, or the bundled executable name.
""")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 5)
                Text(fullBundleID != nil ? "Output signed with BundleID: \(fullBundleID!)": "")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 5)
            }
            .padding(.vertical)

            Button(buttonTitle) {
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

    private var buttonTitle: String {
        switch fileType {
        case .universal:
            return "Export signed universal binary"
        case .separate:
            return "Combine and export universal binary"
        }
    }

    private func exportBinary() {
        Task {
            do {
                let _ = try filesAreValid()
                let _ = try bundleIDisValid()
                guard let outputDir = selectOutputFolder() else {
                    return
                }

                let bundler = Bundler()

                let inputURL: URL

                switch fileType {
                case .universal:
                    inputURL = universalBinary!.url!
                case .separate:
                    guard let fileX86 = x86_64Binary?.url, let fileARM = arm64Binary?.url else {
                        throw BundlerError(message: "Missing binaries")
                    }

                    inputURL = try await bundler.combineBinaries(x86_64URL: fileX86, arm64URL: fileARM)
                }

                let outputURL = outputDir.appendingPathComponent(outputFileName!)

                try FileManager.default.copyItem(at: inputURL, to: outputURL)

                try await bundler.codesign(file: outputURL, bundleID: fullBundleID!)

                self.exportError = BundlerError(title: "Success", message: "The file was signed successfully")

            } catch let exportError as BundlerError {
                self.exportError = exportError
            } catch {
                self.exportError = BundlerError(message: error.localizedDescription)
            }
        }

    }

    private func bundleIDisValid() throws(BundlerError) -> Bool {
        guard bundleID.count > 0 else {
            throw BundlerError(message: "Bundle ID is missing")
        }
        return true
    }

    private func filesAreValid() throws(BundlerError) -> Bool {
        switch fileType {
        case .universal:
            guard let universalBinary else {
                throw BundlerError(message: "Universal binary is missing")
            }
            guard case .universal = universalBinary.architecture else {
                throw BundlerError(message: "Select a file which is a universal binary")
            }
            return true
        case .separate:
            guard let arm64Binary = arm64Binary else {
                throw BundlerError(message: "ARM64 binary is missing")
            }
            guard case .arm64 = arm64Binary.architecture else {
                throw BundlerError(message: "Select a file which is an ARM64 binary")
            }
            guard let x86_64Binary = x86_64Binary else {
                throw BundlerError(message: "x86_64 binary is missing")
            }
            guard case .intel64 = x86_64Binary.architecture else {
                throw BundlerError(message: "Select a file which is an x86_64 binary")
            }
            return true
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

}

#Preview {
    ContentView()
}
