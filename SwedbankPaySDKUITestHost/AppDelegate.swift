import UIKit
import SwedbankPaySDK

let shouldRestoreState = CommandLine.arguments.contains("-restore")
//we need a different config for each merchant to test
let configIndex = CommandLine.arguments.first { $0.contains("-configIndex")}?.split(separator: " ").last
    .flatMap { Int(String($0)) } ?? 0

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
        
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        currentConfig = paymentTestConfigurations[configIndex]
        SwedbankPaySDKController.defaultConfiguration = currentConfig
        return true
    }
    
    func application(_ application: UIApplication, shouldSaveSecureApplicationState coder: NSCoder) -> Bool {
        application.ignoreSnapshotOnNextApplicationLaunch()
        return true
    }
    
    func application(_ application: UIApplication, shouldRestoreSecureApplicationState coder: NSCoder) -> Bool {
        return shouldRestoreState
    }
}
