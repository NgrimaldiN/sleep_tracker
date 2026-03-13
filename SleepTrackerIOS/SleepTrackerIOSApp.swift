import SwiftUI
import UIKit

@main
struct SleepTrackerIOSApp: App {
    @StateObject private var appModel = AppModel()
    @StateObject private var alarmModel = AlarmFeatureModel()

    init() {
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(red: 0.03, green: 0.05, blue: 0.08, alpha: 1)
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.55)
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.white.withAlphaComponent(0.55)
        ]
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(red: 0.95, green: 0.74, blue: 0.26, alpha: 1)
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0.95, green: 0.74, blue: 0.26, alpha: 1)
        ]
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithTransparentBackground()
        navigationAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        navigationAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navigationAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationAppearance
    }

    var body: some Scene {
        WindowGroup {
            ContentView(appModel: appModel, alarmModel: alarmModel)
                .preferredColorScheme(.dark)
        }
    }
}
