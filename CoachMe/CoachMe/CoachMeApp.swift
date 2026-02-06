//
//  CoachMeApp.swift
//  CoachMe
//
//  Created by Sumanth Daggubati on 2/5/26.
//

import SwiftUI
import Sentry

@main
struct CoachMeApp: App {
    init() {
        // Sentry initialization (configure in production)
        // SentrySDK.start { options in
        //     options.dsn = "YOUR_SENTRY_DSN"
        // }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
