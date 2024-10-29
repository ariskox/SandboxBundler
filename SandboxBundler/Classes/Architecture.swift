//
//  Architecture.swift
//  SandboxBundler
//
//  Created by Aris Koxaras on 29/10/24.
//

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

