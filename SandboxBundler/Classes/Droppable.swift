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
                .onDrop(
                    of: [.fileURL],
                    delegate: FileDropDelegate(
                        binaryFile: $binaryFile,
                        isDropping: $isDropping
                    )
                )

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
