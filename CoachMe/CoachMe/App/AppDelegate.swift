//
//  AppDelegate.swift
//  CoachMe
//
//  Story 8.2 — APNs push infrastructure
//

import UIKit
import UserNotifications

/// Bridges UIKit push-notification callbacks into the SwiftUI app lifecycle.
///
/// Wired via `@UIApplicationDelegateAdaptor(AppDelegate.self)` in `CoachMeApp`.
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    // MARK: - UIApplicationDelegate

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// APNs returned a device token — forward to PushNotificationService.
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            await PushNotificationService.shared.registerDeviceToken(deviceToken)
        }
    }

    /// APNs registration failed — log the error.
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushNotificationService.shared.handleRegistrationError(error)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Notification arrived while the app is in the foreground.
    /// Show it as a banner so the user is aware of the nudge.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let notificationType = notification.request.content.userInfo["notification_type"] as? String
        if notificationType == "reactive_reply" {
            // Foreground chat already shows the message in-stream.
            return []
        }
        return [.banner, .sound, .badge]
    }

    /// User tapped a notification — route to the relevant conversation.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        await NotificationRouter.shared.handleNotificationTap(userInfo: userInfo)
    }
}
