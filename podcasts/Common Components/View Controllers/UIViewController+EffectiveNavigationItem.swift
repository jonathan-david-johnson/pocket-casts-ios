import UIKit

extension UIViewController {
    /// When this view controller is hosted as a child inside another
    /// non-`UINavigationController` view controller (i.e. the host owns the
    /// visible nav bar), returns the host's `navigationItem` so writes to
    /// `effectiveNavigationItem.{left,right}BarButtonItem` land on the
    /// visible nav bar.
    ///
    /// Falls back to `self.navigationItem` when:
    /// - There is no parent (standalone use, or root before being added).
    /// - The parent is a `UINavigationController` (normal pushed VC case).
    var effectiveNavigationItem: UINavigationItem {
        if let parent, !(parent is UINavigationController) {
            return parent.navigationItem
        }
        return navigationItem
    }
}
