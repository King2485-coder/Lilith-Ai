import Foundation
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "atom_neutral" asset catalog image resource.
    static let atomNeutral = DeveloperToolsSupport.ImageResource(name: "atom_neutral", bundle: resourceBundle)

    /// The "atom_smirk" asset catalog image resource.
    static let atomSmirk = DeveloperToolsSupport.ImageResource(name: "atom_smirk", bundle: resourceBundle)

    /// The "atom_thinking" asset catalog image resource.
    static let atomThinking = DeveloperToolsSupport.ImageResource(name: "atom_thinking", bundle: resourceBundle)

}

