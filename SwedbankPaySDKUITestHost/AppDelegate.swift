import UIKit
import SwedbankPaySDK

let shouldRestoreState = CommandLine.arguments.contains("-restore")
//we need a different config for each merchant to test
let configName = CommandLine.arguments.first { $0.contains("-configName")}?.split(separator: " ").last.flatMap { String($0) }

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
        
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        if let configName = configName {
            guard let config = TestConfigurations(rawValue: configName) else {
                fatalError("You have supplied a non-existing config: \(configName)")
            }
            currentConfig = paymentTestConfigurations[config]!
        }
        
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
