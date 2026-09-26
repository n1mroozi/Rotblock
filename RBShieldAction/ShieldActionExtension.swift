import FamilyControls
import ManagedSettings

final class ShieldActionExtension: ShieldActionDelegate {
    private let manager = ShieldActionManager()

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(
            manager.handle(action: action, target: .application(application))
        )
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(
            manager.handle(action: action, target: .category(category))
        )
    }
}
