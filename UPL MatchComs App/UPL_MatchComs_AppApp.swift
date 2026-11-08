//
//  UPL_MatchComs_AppApp.swift
//  UPL MatchComs App
//
//  Created by Yinka Ige on 22/09/2026.
//

import FirebaseCore
import GoogleSignIn
import SwiftUI

@main
struct UPL_MatchComs_AppApp: App {
    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
