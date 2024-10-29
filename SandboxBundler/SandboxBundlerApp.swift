//
//  SandboxBundlerApp.swift
//  SandboxBundler
//
//  Created by Aris Koxaras on 29/10/24.
//

import SwiftUI

@main
struct SandboxBundlerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
