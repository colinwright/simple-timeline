// NotificationNames.swift

import Foundation

extension Notification.Name {
    /// Notification posted to request that the timeline deselects any active items.
    /// This is typically sent from a background tap in the main ContentView.
    static let deselectTimelineItems = Notification.Name("deselectTimelineItems")
}
