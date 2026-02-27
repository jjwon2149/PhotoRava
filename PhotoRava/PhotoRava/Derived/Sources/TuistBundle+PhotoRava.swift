import Foundation

extension Bundle {
    public static let module: Bundle = Bundle(for: BundleClass.self)
}

private final class BundleClass {}
