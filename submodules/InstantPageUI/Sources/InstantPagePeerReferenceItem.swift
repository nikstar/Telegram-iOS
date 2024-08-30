import Foundation
import UIKit
import TelegramCore
import AsyncDisplayKit
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ContextUI

public final class InstantPagePeerReferenceItem: InstantPageItem {
    public var frame: CGRect
    public let wantsNode: Bool = true
    public let separatesTiles: Bool = false
    public let medias: [InstantPageMedia] = []
    
    let initialPeer: EnginePeer
    let safeInset: CGFloat
    let transparent: Bool
    let rtl: Bool
    
    init(frame: CGRect, initialPeer: EnginePeer, safeInset: CGFloat, transparent: Bool, rtl: Bool) {
        self.frame = frame
        self.initialPeer = initialPeer
        self.safeInset = safeInset
        self.transparent = transparent
        self.rtl = rtl
    }
    
    public func node(context: AccountContext, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, theme: InstantPageTheme, sourceLocation: InstantPageSourceLocation, openMedia: @escaping (InstantPageMedia) -> Void, longPressMedia: @escaping (InstantPageMedia) -> Void, activatePinchPreview: ((PinchSourceContainerNode) -> Void)?, pinchPreviewFinished: ((InstantPageNode) -> Void)?, openPeer: @escaping (EnginePeer) -> Void, openUrl: @escaping (InstantPageUrlItem) -> Void, updateWebEmbedHeight: @escaping (CGFloat) -> Void, updateDetailsExpanded: @escaping (Bool) -> Void, currentExpandedDetails: [Int : Bool]?, getPreloadedResource: @escaping (String) -> Data?) -> InstantPageNode? {
        return InstantPagePeerReferenceNode(context: context, strings: strings, nameDisplayOrder: nameDisplayOrder, theme: theme, initialPeer: self.initialPeer, safeInset: self.safeInset, transparent: self.transparent, rtl: self.rtl, openPeer: openPeer)
    }
    
    public func matchesAnchor(_ anchor: String) -> Bool {
        return false
    }
    
    public func matchesNode(_ node: InstantPageNode) -> Bool {
        if let node = node as? InstantPagePeerReferenceNode {
            return self.initialPeer.id == node.peer?.id && self.safeInset == node.safeInset
        } else {
            return false
        }
    }
    
    public func distanceThresholdGroup() -> Int? {
        return 5
    }
    
    public func distanceThresholdWithGroupCount(_ count: Int) -> CGFloat {
        if count > 3 {
            return 1000.0
        } else {
            return CGFloat.greatestFiniteMagnitude
        }
    }
    
    public func linkSelectionRects(at point: CGPoint) -> [CGRect] {
        return []
    }
    
    public func drawInTile(context: CGContext) {
    }
}
