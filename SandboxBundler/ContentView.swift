//
//  ContentView.swift
//  SandboxBundler
//
//  Created by Aris Koxaras on 29/10/24.
//

import SwiftUI

struct ContentView: View {

    enum FileType: String, CaseIterable, Identifiable {
        case universal = "Universal"
        case separate = "Separate architectures"

        var id: String { self.rawValue }
    }

    @State private var fileType = FileType.universal
    @State private var universalBinary: BinaryFile?
    @State private var arm64Binary: BinaryFile?
    @State private var x86_64Binary: BinaryFile?

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
                TextField("com.example.app", text: .constant(""))
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

            }
            .padding(.vertical)

        }
        .padding()
    }
}


struct Droppable: View {
    @State var architecture: Architecture
    @Binding var binaryFile: BinaryFile?
    @State private var isDropping = false

    var body: some View {
        if binaryFile != nil {
            Rectangle()
                .fill(isInvalid ? Color.red.opacity(0.5) : Color.green.opacity(0.5))
                .cornerRadius(20) // Rounded corners
                .frame(width: 250, height: 80)
                .overlay {
                    Text(archTitle)
                        .foregroundColor(.white)
                        .font(.body)
                        .multilineTextAlignment(.center)
                }
                .padding()

        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.5))
                .cornerRadius(20) // Rounded corners
                .border(isDropping ? Color.blue : Color.clear, width: 4)
                .frame(width: 250, height: 80)
                .overlay {
                    Text(architecture.dragAndDropTitle)
                        .foregroundColor(.black)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .onDrop(
                    of: [.fileURL],
                    delegate: FileDropDelegate(
                        binaryFile: $binaryFile,
                        isDropping: $isDropping
                    )
                )
        }
    }

    var archTitle: String {
        guard let binaryFile else { return "" }
        if isInvalid {
            return "Expecting: \(architecture.title).\n Got: \(binaryFile.architecture.title)"
        } else {
            return "\(binaryFile.architecture.title).\n\(binaryFile.url?.lastPathComponent ?? "")"
        }
    }

    var isInvalid: Bool {
        guard let binaryFile = binaryFile else { return false }
        switch (binaryFile.architecture, architecture) {
        case (.arm64, .arm64), (.intel64, .intel64), (.universal, .universal):
                return false
        default:
            return true
        }
    }
}

struct BinaryFile {
    var url: URL?
    var architecture: Architecture
}

import SwiftBlade

struct FileDropDelegate: DropDelegate {
    @Binding var binaryFile: BinaryFile?
    @Binding var isDropping: Bool

    func performDrop(info: DropInfo) -> Bool {
        // Extract file URLs from the drag-and-drop info
        let itemProvider = info.itemProviders(for: [.fileURL]).first
        let _ = itemProvider?.loadObject(ofClass: URL.self) { url, error in
            Task { @MainActor in
                self.isDropping = false
                guard let url = url else { return }
                guard FileManager.default.isReadableFile(atPath: url.path()) else { return }
                do {
                    let archs = try await FileManager.default.getArchitectures(fileURL: url)
                    self.binaryFile = BinaryFile(url: url, architecture: archs)
                } catch {
                    debugPrint("got error \(error)")
                    self.binaryFile = BinaryFile(url: url, architecture: .invalid(error.localizedDescription))
                }
            }
        }
        return true
    }

    func dropEntered(info: DropInfo) {
        isDropping = true
    }

    func dropExited(info: DropInfo) {
        isDropping = false
    }
}

extension FileManager {
    func getArchitectures(fileURL: URL) async throws -> Architecture {
        let lipoURL = URL(fileURLWithPath: "/usr/bin/file")
        let result = try await Process.runAsync(url: lipoURL, arguments: ["-b", fileURL.path ])

        if result.standard.contains("Mach-O universal binary with 2 architectures: [x86_64:Mach-O 64-bit executable x86_64] [arm64]") {
            return .universal
        } else if result.standard.contains("Mach-O 64-bit executable x86_64") {
            return .intel64
        } else if result.standard.contains("Mach-O 64-bit executable arm64") {
            return .arm64
        }
        return .invalid(result.standard)
    }

}

enum Architecture {
    case arm64
    case intel64
    case universal
    case invalid(String)

    var dragAndDropTitle: String {
        switch self {
        case .arm64:
            return "Drag and drop an ARM64 binary here"
        case .intel64:
            return "Drag and drop x86_64 binary here"
        case .universal:
            return "Drag and drop a binary here"
        case .invalid(let archs):
            return "Invalid architecture: \(archs)"
        }
    }

    var title: String {
        switch self {
        case .universal:
            return "Universal binary"
        case .arm64:
            return "Arm64 binary"
        case .intel64:
            return "x86_64 binary"
        case .invalid(let arch):
            return "Invalid architecture: \(arch)"
        }
    }
    var isInvalid: Bool {
        if case .invalid = self {
            return true
        }
        return false
    }
}

#Preview {
    ContentView()
}
