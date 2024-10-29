//
//  FileManager+Extension.swift
//  SandboxBundler
//
//  Created by Aris Koxaras on 29/10/24.
//

import Foundation
import SwiftBlade

struct BinaryFile {
    var url: URL?
    var architecture: Architecture
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
