import SwiftUI
import UIKit
import UserNotifications
import MediaPlayer

@main
struct SleepTrackerIOSApp: App {
    @StateObject private var appModel = AppModel()
    @StateObject private var alarmModel = AlarmFeatureModel()

    init() {
        UNUserNotificationCenter.current().delegate = WakeNotificationDelegate.shared

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
                .overlay(alignment: .topLeading) {
                    HiddenSystemVolumeHost()
                        .frame(width: 1, height: 1)
                        .opacity(0.01)
                        .allowsHitTesting(false)
                }
                .preferredColorScheme(.dark)
        }
    }
}

@MainActor
final class SystemVolumeController {
    static let shared = SystemVolumeController()

    private let volumeView: MPVolumeView
    private var enforcementTask: Task<Void, Never>?
    private var isAlarmArmed = false
    private var isMissionPresented = false

    private init() {
        let view = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
        view.showsRouteButton = false
        view.isUserInteractionEnabled = false
        self.volumeView = view
    }

    var hostView: MPVolumeView {
        volumeView
    }

    func updateWakeState(isAlarmArmed: Bool, isMissionPresented: Bool) {
        self.isAlarmArmed = isAlarmArmed
        self.isMissionPresented = isMissionPresented

        guard isAlarmArmed || isMissionPresented else {
            enforcementTask?.cancel()
            enforcementTask = nil
            return
        }

        if enforcementTask == nil {
            enforcementTask = Task { @MainActor [weak self] in
                while let self, !Task.isCancelled {
                    self.enforceIfNeeded()
                    try? await Task.sleep(for: .seconds(1.5))
                }
            }
        }

        enforceIfNeeded()
    }

    private func enforceIfNeeded() {
        let currentVolume = AVAudioSession.sharedInstance().outputVolume
        guard let targetVolume = SleepTrackerAppCore.enforcedWakeVolumeTarget(
            currentVolume: currentVolume,
            isAlarmArmed: isAlarmArmed,
            isMissionPresented: isMissionPresented
        ) else {
            return
        }

        guard let slider = volumeView.subviews.compactMap({ $0 as? UISlider }).first else {
            return
        }

        if abs(slider.value - targetVolume) < 0.01 {
            return
        }

        slider.value = targetVolume
        slider.sendActions(for: .touchDown)
        slider.sendActions(for: .valueChanged)
        slider.sendActions(for: .touchUpInside)
    }
}

private struct HiddenSystemVolumeHost: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        let volumeView = SystemVolumeController.shared.hostView
        volumeView.frame = container.bounds
        volumeView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(volumeView)
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

final class WakeNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = WakeNotificationDelegate()
    private var isMissionPresented = false

    func updateMissionPresentation(isPresented: Bool) {
        isMissionPresented = isPresented
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        if SleepTrackerAppCore.shouldPlayForegroundWakeNotificationSound(
            isMissionPresented: isMissionPresented
        ) {
            return [.banner, .list, .sound]
        }

        return [.banner, .list]
    }
}
