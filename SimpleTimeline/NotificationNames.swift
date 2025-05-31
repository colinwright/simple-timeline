// NotificationNames.swift

import Foundation

extension Notification.Name {
    /// Notification posted to request that the timeline deselects any active items.
    /// This is typically sent from a background tap in the main ContentView.
    static let deselectTimelineItems = Notification.Name("deselectTimelineItems")

    /// Notification posted when an internal link is clicked in a rich text view,
    /// requesting the app to navigate to the specified internal item.
    /// The userInfo dictionary should contain "urlString" with the custom scheme URL.
    static let navigateToInternalItem = Notification.Name("navigateToInternalItem")
}
