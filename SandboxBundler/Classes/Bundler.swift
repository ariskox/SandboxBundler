//
//  Bundler.swift
//  SandboxBundler
//
//  Created by Aris Koxaras on 29/10/24.
//

import Foundation

class Bundler {
    // Returns a temporary url
    func combineBinaries(x86_64URL: URL, arm64URL: URL) async throws(BundlerError) -> URL {
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
                    x86_64URL.path(),
                    arm64URL.path()
                ]
            )
            debugPrint("got result \(result.standard) \(result.error)")
            return outputURL
        } catch {
            throw BundlerError(message: "Failed to combine binaries: \(error.localizedDescription)")
        }

    }

    func codesign(file: URL, bundleID: String) async throws(BundlerError) {
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
            throw BundlerError(message: "Failed to codesign \(error.localizedDescription)")
        }

    }

}
