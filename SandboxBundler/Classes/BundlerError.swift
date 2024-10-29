//
//  BundlerError.swift
//  SandboxBundler
//
//  Created by Aris Koxaras on 29/10/24.
//

import Foundation

struct BundlerError: Error, Identifiable, LocalizedError {
    var title: String = "Error"
    var message: String

    var id: String { return message }

    var errorDescription: String? {
        return message
    }
}
