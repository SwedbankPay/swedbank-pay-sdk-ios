import UIKit

extension UIFont {
    class func medium12() -> UIFont {
        return UIFont(name: "IBMPlexMono-Medium", size: 12) ?? UIFont.systemFont(ofSize: 12)
    }
    
    class func bold12() -> UIFont {
        return UIFont(name: "IBMPlexMono-Bold", size: 12) ?? UIFont.systemFont(ofSize: 12)
    }
    
    class func medium14() -> UIFont {
        return UIFont(name: "IBMPlexMono-Medium", size: 14) ?? UIFont.systemFont(ofSize: 14)
    }
    
    class func bold18() -> UIFont {
        return UIFont(name: "IBMPlexMono-Bold", size: 18) ?? UIFont.systemFont(ofSize: 18)
    }
    
    class func medium24() -> UIFont {
        return UIFont(name: "IBMPlexMono-Medium", size: 24) ?? UIFont.systemFont(ofSize: 24)
    }
}
