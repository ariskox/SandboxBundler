//
//  Droppable.swift
//  SandboxBundler
//
//  Created by Aris Koxaras on 29/10/24.
//

import Foundation
import SwiftUI

struct Droppable: View {
    @State var architecture: Architecture
    @Binding var binaryFile: BinaryFile?
    @State private var isDropping = false

    var body: some View {
        Rectangle()
            .fill(fillColor)
            .cornerRadius(20) // Rounded corners
            .border(isDropping ? Color.blue : Color.clear, width: 4)
            .frame(width: 250, height: 80)
            .overlay {
                Text(overlayTitle)
                    .foregroundColor(overlayTextColor)
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
            .onTapGesture {
                selectInputFolder()
            }
    }

    var overlayTextColor: Color {
        return (binaryFile != nil) ? .white : .black
    }

    var overlayTitle: String {
        if binaryFile != nil {
            return archTitle
        } else {
            return architecture.dragAndDropTitle
        }
    }

    var fillColor: Color {
        if binaryFile != nil {
            return isInvalid ? Color.red.opacity(0.5) : Color.green.opacity(0.5)
        } else {
            return Color.gray.opacity(0.5)
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

    private func selectInputFolder() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select a binary file"
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false

        if openPanel.runModal() == .OK, let selectedURL = openPanel.url {
            self.isDropping = true
            Task { @MainActor in
                defer { self.isDropping = false }
                let delegate = FileDropDelegate(binaryFile: $binaryFile, isDropping: $isDropping)
                try await delegate.handle(url: selectedURL)
            }
        }
    }

}
