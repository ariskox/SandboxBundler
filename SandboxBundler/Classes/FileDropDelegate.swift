//
//  FileDropDelegate.swift
//  SandboxBundler
//
//  Created by Aris Koxaras on 29/10/24.
//

import Foundation
import SwiftUI

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
                try await self.handle(url: url)
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

    func handle(url: URL) async throws {
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
