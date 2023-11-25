import AsyncDisplayKit
import Display
import ComponentFlow
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import AccountContext
import ContextUI
import PhotoResources
import TelegramUIPreferences
import ItemListPeerItem
import ItemListPeerActionItem
import MergeLists
import ItemListUI
import PeerInfoVisualMediaPaneNode
import ChatControllerInteraction
import MultilineTextComponent
import Markdown
import SolidRoundedButtonNode

private struct RecommendedChannelsListTransaction {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let animated: Bool
}

private enum RecommendedChannelsListEntryStableId: Hashable {
    case addMember
    case peer(PeerId)
}

private enum RecommendedChannelsListEntry: Comparable, Identifiable {
    case peer(theme: PresentationTheme, index: Int, peer: EnginePeer, subscribers: Int32)
        
    var stableId: RecommendedChannelsListEntryStableId {
        switch self {
            case let .peer(_, _, peer, _):
                return .peer(peer.id)
        }
    }
    
    static func ==(lhs: RecommendedChannelsListEntry, rhs: RecommendedChannelsListEntry) -> Bool {
        switch lhs {
            case let .peer(lhsTheme, lhsIndex, lhsPeer, lhsSubscribers):
                if case let .peer(rhsTheme, rhsIndex, rhsPeer, rhsSubscribers) = rhs, lhsTheme === rhsTheme, lhsIndex == rhsIndex, lhsPeer == rhsPeer, lhsSubscribers == rhsSubscribers {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: RecommendedChannelsListEntry, rhs: RecommendedChannelsListEntry) -> Bool {
        switch lhs {
            case let .peer(_, lhsIndex, _, _):
                switch rhs {
                    case let .peer(_, rhsIndex, _, _):
                        return lhsIndex < rhsIndex
                }
        }
    }
    
    func item(context: AccountContext, presentationData: PresentationData, action: @escaping (EnginePeer) -> Void, openPeerContextAction: @escaping (Peer, ASDisplayNode, ContextGesture?) -> Void) -> ListViewItem {
        switch self {
            case let .peer(_, _, peer, subscribers):
                let subtitle = presentationData.strings.Conversation_StatusSubscribers(subscribers)
                return ItemListPeerItem(presentationData: ItemListPresentationData(presentationData), dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, context: context, peer: peer, presence: nil, text: .text(subtitle, .secondary), label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), switchValue: nil, enabled: true, selectable: true, sectionId: 0, action: {
                    action(peer)
                }, setPeerIdWithRevealedOptions: { _, _ in
                }, removePeer: { _ in
                }, contextAction: { node, gesture in
                    openPeerContextAction(peer._asPeer(), node, gesture)
                }, hasTopStripe: false, noInsets: true, noCorners: true, disableInteractiveTransitionIfNecessary: true)
        }
    }
}

private func preparedTransition(from fromEntries: [RecommendedChannelsListEntry], to toEntries: [RecommendedChannelsListEntry], context: AccountContext, presentationData: PresentationData, action: @escaping (EnginePeer) -> Void, openPeerContextAction: @escaping (Peer, ASDisplayNode, ContextGesture?) -> Void) -> RecommendedChannelsListTransaction {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, action: action, openPeerContextAction: openPeerContextAction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, presentationData: presentationData, action: action, openPeerContextAction: openPeerContextAction), directionHint: nil) }
    
    return RecommendedChannelsListTransaction(deletions: deletions, insertions: insertions, updates: updates, animated: toEntries.count < fromEntries.count)
}

private let channelsLimit: Int32 = 8

final class PeerInfoRecommendedChannelsPaneNode: ASDisplayNode, PeerInfoPaneNode {
    private let context: AccountContext
    private let chatControllerInteraction: ChatControllerInteraction
    private let openPeerContextAction: (Bool, Peer, ASDisplayNode, ContextGesture?) -> Void
    
    weak var parentController: ViewController?
    
    private let listNode: ListView
    private var currentEntries: [RecommendedChannelsListEntry] = []
    private var currentState: RecommendedChannels?
    private var canLoadMore: Bool = false
    private var enqueuedTransactions: [RecommendedChannelsListTransaction] = []
    
    private var unlockBackground: UIImageView?
    private var unlockText: ComponentView<Empty>?
    private var unlockButton: SolidRoundedButtonNode?
    
    private var currentParams: (size: CGSize, isScrollingLockedAtTop: Bool)?
    private let presentationDataPromise = Promise<PresentationData>()
    
    private let ready = Promise<Bool>()
    private var didSetReady: Bool = false
    var isReady: Signal<Bool, NoError> {
        return self.ready.get()
    }

    var status: Signal<PeerInfoStatusData?, NoError> {
        return .single(nil)
    }

    var tabBarOffsetUpdated: ((ContainedViewLayoutTransition) -> Void)?
    var tabBarOffset: CGFloat {
        return 0.0
    }
        
    private var disposable: Disposable?
    
    init(context: AccountContext, peerId: PeerId, chatControllerInteraction: ChatControllerInteraction, openPeerContextAction: @escaping (Bool, Peer, ASDisplayNode, ContextGesture?) -> Void) {
        self.context = context
        self.chatControllerInteraction = chatControllerInteraction
        self.openPeerContextAction = openPeerContextAction
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.listNode = ListView()
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        super.init()
        
        self.listNode.preloadPages = true
        self.addSubnode(self.listNode)
        
        self.disposable = (combineLatest(queue: .mainQueue(),
            self.presentationDataPromise.get(),
            context.engine.peers.recommendedChannels(peerId: peerId)
        )
        |> deliverOnMainQueue).startStrict(next: { [weak self] presentationData, recommendedChannels in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.updateState(recommendedChannels: recommendedChannels, presentationData: presentationData)
        })
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    func ensureMessageIsVisible(id: MessageId) {
    }
    
    func scrollToTop() -> Bool {
        if !self.listNode.scrollToOffsetFromTop(0.0, animated: true) {
            self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
            return true
        } else {
            return false
        }
    }
    
    func update(size: CGSize, topInset: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, visibleHeight: CGFloat, isScrollingLockedAtTop: Bool, expandProgress: CGFloat, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        let isFirstLayout = self.currentParams == nil
        self.currentParams = (size, isScrollingLockedAtTop)
        self.presentationDataPromise.set(.single(presentationData))
        
        transition.updateFrame(node: self.listNode, frame: CGRect(origin: CGPoint(), size: size))
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)

        var scrollToItem: ListViewScrollToItem?
        if isScrollingLockedAtTop {
            switch self.listNode.visibleContentOffset() {
            case let .known(value) where value <= CGFloat.ulpOfOne:
                break
            default:
                scrollToItem = ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Spring(duration: duration), directionHint: .Up)
            }
        }
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: scrollToItem, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: size, insets: UIEdgeInsets(top: topInset, left: sideInset, bottom: bottomInset, right: sideInset), duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        self.listNode.scrollEnabled = !isScrollingLockedAtTop
        
        if isFirstLayout, let recommendedChannels = self.currentState {
            self.updateState(recommendedChannels: recommendedChannels, presentationData: presentationData)
        }
        
        if !self.context.isPremium {
            let unlockText: ComponentView<Empty>
            let unlockBackground: UIImageView
            let unlockButton: SolidRoundedButtonNode
            if let current = self.unlockText {
                unlockText = current
            } else {
                unlockText = ComponentView<Empty>()
                self.unlockText = unlockText
            }
            
            if let current = self.unlockBackground {
                unlockBackground = current
            } else {
                let topColor = presentationData.theme.list.plainBackgroundColor.withAlphaComponent(0.0)
                let bottomColor = presentationData.theme.list.plainBackgroundColor
                unlockBackground = UIImageView(image: generateGradientImage(size: CGSize(width: 1.0, height: 160.0), colors: [topColor, bottomColor], locations: [0.0, 1.0]))
                unlockBackground.contentMode = .scaleToFill
                self.view.addSubview(unlockBackground)
                self.unlockBackground = unlockBackground
            }
                        
            if let current = self.unlockButton {
                unlockButton = current
            } else {
                unlockButton = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(theme: presentationData.theme), cornerRadius: 11.0)
                self.view.addSubview(unlockButton.view)
                self.unlockButton = unlockButton
            
                unlockButton.animationLoopTime = 2.5
                unlockButton.animation = "premium_unlock"
                unlockButton.iconPosition = .right
                unlockButton.title = presentationData.strings.Channel_SimilarChannels_ShowMore
                
                unlockButton.pressed = { [weak self] in
                    self?.unlockPressed()
                }
            }
        
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let textColor = presentationData.theme.list.itemSecondaryTextColor
            let linkColor = presentationData.theme.list.itemAccentColor
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: boldTextFont, textColor: linkColor), linkAttribute: { _ in
                return nil
            })
            
            let unlockSize = unlockText.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .markdown(text: presentationData.strings.Channel_SimilarChannels_ShowMoreInfo, attributes: markdownAttributes),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.2
                    )
                ),
                environment: {},
                containerSize: CGSize(width: size.width - 32.0, height: 200.0)
            )
            if let view = unlockText.view {
                if view.superview == nil {
                    view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.unlockPressed)))
                    self.view.addSubview(view)
                }
                view.frame = CGRect(origin: CGPoint(x: floor((size.width - unlockSize.width) / 2.0), y: size.height - bottomInset - unlockSize.height - 13.0), size: unlockSize)
            }
            
            unlockBackground.frame = CGRect(x: 0.0, y: size.height - bottomInset - 160.0, width: size.width, height: bottomInset + 160.0)
            
            let buttonSideInset = sideInset + 16.0
            let buttonSize = CGSize(width: size.width - buttonSideInset * 2.0, height: 50.0)
            unlockButton.frame = CGRect(origin: CGPoint(x: buttonSideInset, y: size.height - bottomInset - unlockSize.height - buttonSize.height - 26.0), size: buttonSize)
            let _ = unlockButton.updateLayout(width: buttonSize.width, transition: transition)
        } else  {
            self.unlockBackground?.removeFromSuperview()
            self.unlockBackground = nil
            
            self.unlockText?.view?.removeFromSuperview()
            self.unlockText = nil
        }
    }
    
    @objc private func unlockPressed() {
        let controller = self.context.sharedContext.makePremiumIntroController(context: self.context, source: .ads, forceDark: false, dismissed: nil)
        self.chatControllerInteraction.navigationController()?.pushViewController(controller)
    }
    
    private func updateState(recommendedChannels: RecommendedChannels?, presentationData: PresentationData) {
        var entries: [RecommendedChannelsListEntry] = []
                                
        if let channels = recommendedChannels?.channels {
            for channel in channels {
                entries.append(.peer(theme: presentationData.theme, index: entries.count, peer: channel.peer, subscribers: channel.subscribers))
            }
        }
        
        let transaction = preparedTransition(from: self.currentEntries, to: entries, context: self.context, presentationData: presentationData, action: { [weak self] peer in
            self?.chatControllerInteraction.openPeer(peer, .default, nil, .default)
        }, openPeerContextAction: { [weak self] peer, node, gesture in
            self?.openPeerContextAction(true, peer, node, gesture)
        })
        self.currentEntries = entries
        self.enqueuedTransactions.append(transaction)
        self.dequeueTransaction()
    }
    
    private func dequeueTransaction() {
        guard let _ = self.currentParams, let transaction = self.enqueuedTransactions.first else {
            return
        }
        
        self.enqueuedTransactions.remove(at: 0)
        
        var options = ListViewDeleteAndInsertOptions()
        if transaction.animated {
            options.insert(.AnimateInsertion)
        } else {
            options.insert(.Synchronous)
        }
        
        self.listNode.transaction(deleteIndices: transaction.deletions, insertIndicesAndItems: transaction.insertions, updateIndicesAndItems: transaction.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            if !strongSelf.didSetReady {
                strongSelf.didSetReady = true
                strongSelf.ready.set(.single(true))
            }
        })
    }
    
    func findLoadedMessage(id: MessageId) -> Message? {
        return nil
    }
    
    func updateHiddenMedia() {
    }
    
    func transferVelocity(_ velocity: CGFloat) {
        if velocity > 0.0 {
            self.listNode.transferVelocity(velocity)
        }
    }
    
    func cancelPreviewGestures() {
    }
    
    func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return nil
    }
    
    func addToTransitionSurface(view: UIView) {
    }
    
    func updateSelectedMessages(animated: Bool) {
    }
}
