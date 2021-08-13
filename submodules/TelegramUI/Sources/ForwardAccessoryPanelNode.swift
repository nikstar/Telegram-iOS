import Foundation
import UIKit
import AsyncDisplayKit
import TelegramCore
import Postbox
import SwiftSignalKit
import Display
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import LocalizedPeerData
import AlertUI
import PresentationDataUtils
import TextFormat
import Markdown

func textStringForForwardedMessage(_ message: Message, strings: PresentationStrings) -> (String, Bool) {
    for media in message.media {
        switch media {
            case _ as TelegramMediaImage:
                return (strings.ForwardedPhotos(1), true)
            case let file as TelegramMediaFile:
                var fileName: String = strings.ForwardedFiles(1)
                for attribute in file.attributes {
                    switch attribute {
                        case .Sticker:
                            return (strings.ForwardedStickers(1), true)
                        case let .FileName(name):
                            fileName = name
                        case let .Audio(isVoice, _, title, performer, _):
                            if isVoice {
                                return (strings.ForwardedAudios(1), true)
                            } else {
                                if let title = title, let performer = performer, !title.isEmpty, !performer.isEmpty {
                                    return (title + " — " + performer, true)
                                } else if let title = title, !title.isEmpty {
                                    return (title, true)
                                } else if let performer = performer, !performer.isEmpty {
                                    return (performer, true)
                                } else {
                                    return (strings.ForwardedAudios(1), true)
                                }
                            }
                        case .Video:
                            if file.isAnimated {
                                return (strings.ForwardedGifs(1), true)
                            } else {
                                return (strings.ForwardedVideos(1), true)
                            }
                        default:
                            break
                    }
                }
                if file.isAnimatedSticker {
                    return (strings.ForwardedStickers(1), true)
                }
                return (fileName, true)
            case _ as TelegramMediaContact:
                return (strings.ForwardedContacts(1), true)
            case let game as TelegramMediaGame:
                return (game.title, true)
            case _ as TelegramMediaMap:
                return (strings.ForwardedLocations(1), true)
            case _ as TelegramMediaAction:
                return ("", true)
            case _ as TelegramMediaPoll:
                return (strings.ForwardedPolls(1), true)
            case let dice as TelegramMediaDice:
                return (dice.emoji, true)
            case let invoice as TelegramMediaInvoice:
                return (invoice.title, true)
            default:
                break
        }
    }
    return (message.text, false)
}

final class ForwardAccessoryPanelNode: AccessoryPanelNode {
    private let messageDisposable = MetaDisposable()
    let messageIds: [MessageId]
    private var authors: String?
    private var sourcePeer: (isPersonal: Bool, displayTitle: String)?
    
    let closeButton: ASButtonNode
    let lineNode: ASImageNode
    let titleNode: ImmediateTextNode
    let textNode: ImmediateTextNode
    
    private let actionArea: AccessibilityAreaNode
    
    let context: AccountContext
    var theme: PresentationTheme
    var strings: PresentationStrings
    var fontSize: PresentationFontSize
    var nameDisplayOrder: PresentationPersonNameOrder
    var hideSendersNames: Bool
    
    private var validLayout: (size: CGSize, interfaceState: ChatPresentationInterfaceState)?
    
    init(context: AccountContext, messageIds: [MessageId], theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize, nameDisplayOrder: PresentationPersonNameOrder, hideSendersNames: Bool) {
        self.context = context
        self.messageIds = messageIds
        self.theme = theme
        self.strings = strings
        self.fontSize = fontSize
        self.nameDisplayOrder = nameDisplayOrder
        self.hideSendersNames = hideSendersNames
        
        self.closeButton = ASButtonNode()
        self.closeButton.accessibilityLabel = strings.VoiceOver_DiscardPreparedContent
        self.closeButton.setImage(PresentationResourcesChat.chatInputPanelCloseIconImage(theme), for: [])
        self.closeButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        self.closeButton.displaysAsynchronously = false
        
        self.lineNode = ASImageNode()
        self.lineNode.displayWithoutProcessing = false
        self.lineNode.displaysAsynchronously = false
        self.lineNode.image = PresentationResourcesChat.chatInputPanelVerticalSeparatorLineImage(theme)
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.displaysAsynchronously = false
        
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 1
        self.textNode.displaysAsynchronously = false
        
        self.actionArea = AccessibilityAreaNode()
        
        super.init()
        
        self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: [.touchUpInside])
        self.addSubnode(self.closeButton)
        
        self.addSubnode(self.lineNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.actionArea)
        
        self.messageDisposable.set((context.account.postbox.messagesAtIds(messageIds)
        |> deliverOnMainQueue).start(next: { [weak self] messages in
            if let strongSelf = self {
                var authors = ""
                var uniquePeerIds = Set<PeerId>()
                var text = ""
                var sourcePeer: (Bool, String)?
                for message in messages {
                    if let author = message.effectiveAuthor, !uniquePeerIds.contains(author.id) {
                        uniquePeerIds.insert(author.id)
                        if !authors.isEmpty {
                            authors.append(", ")
                        }
                        authors.append(author.compactDisplayTitle)
                    }
                    if let peer = message.peers[message.id.peerId] {
                        sourcePeer = (peer.id.namespace == Namespaces.Peer.CloudUser, peer.displayTitle(strings: strongSelf.strings, displayOrder: strongSelf.nameDisplayOrder))
                    }
                }
                if messages.count == 1 {
                    let (string, _) = textStringForForwardedMessage(messages[0], strings: strings)
                    text = string
                } else {
                    text = strings.ForwardedMessages(Int32(messages.count))
                }
                
                strongSelf.sourcePeer = sourcePeer
                strongSelf.authors = authors
                
                if strongSelf.hideSendersNames {
                    strongSelf.titleNode.attributedText = NSAttributedString(string: strongSelf.strings.Conversation_ForwardOptions_You, font: Font.medium(15.0), textColor: strongSelf.theme.chat.inputPanel.panelControlAccentColor)
                } else {
                    strongSelf.titleNode.attributedText = NSAttributedString(string: authors, font: Font.medium(15.0), textColor: strongSelf.theme.chat.inputPanel.panelControlAccentColor)
                }
                
                strongSelf.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(15.0), textColor: strongSelf.theme.chat.inputPanel.secondaryTextColor)
                
                let headerString: String
                if messages.count == 1 {
                    headerString = "Forward message"
                } else {
                    headerString = "Forward messages"
                }
                strongSelf.actionArea.accessibilityLabel = "\(headerString). From: \(authors).\n\(text)"

                if let (size, interfaceState) = strongSelf.validLayout {
                    strongSelf.updateState(size: size, interfaceState: interfaceState)
                }
            }
        }))
    }
    
    deinit {
        self.messageDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    override func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.updateThemeAndStrings(theme: theme, strings: strings, hideSendersNames: self.hideSendersNames)
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings, hideSendersNames: Bool) {
        if self.theme !== theme || self.strings !== strings || self.hideSendersNames != hideSendersNames {
            self.theme = theme
            self.strings = strings
            self.hideSendersNames = hideSendersNames
            
            self.closeButton.setImage(PresentationResourcesChat.chatInputPanelCloseIconImage(theme), for: [])
            
            self.lineNode.image = PresentationResourcesChat.chatInputPanelVerticalSeparatorLineImage(theme)
            
            if hideSendersNames {
                self.titleNode.attributedText = NSAttributedString(string: strings.Conversation_ForwardOptions_You, font: Font.medium(15.0), textColor: self.theme.chat.inputPanel.panelControlAccentColor)
            } else if let authors = self.authors {
                self.titleNode.attributedText = NSAttributedString(string: authors, font: Font.medium(15.0), textColor: self.theme.chat.inputPanel.panelControlAccentColor)
            }
            
            if let text = self.textNode.attributedText?.string {
                self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(15.0), textColor: self.theme.chat.inputPanel.secondaryTextColor)
            }
            
            if let (size, interfaceState) = self.validLayout {
                self.updateState(size: size, interfaceState: interfaceState)
            }
        }
    }

    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: constrainedSize.width, height: 45.0)
    }

    override func updateState(size: CGSize, interfaceState: ChatPresentationInterfaceState) {
        self.validLayout = (size, interfaceState)

        let bounds = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: 45.0))
        let inset: CGFloat = interfaceState.renderedPeer == nil ? 19.0 : 55.0
        let leftInset: CGFloat = inset
        let rightInset: CGFloat = inset
        let textLineInset: CGFloat = 10.0
        let textRightInset: CGFloat = 20.0

        let closeButtonSize = CGSize(width: 44.0, height: bounds.height)
        let closeButtonFrame = CGRect(origin: CGPoint(x: bounds.width - rightInset - closeButtonSize.width + 12.0, y: 2.0), size: closeButtonSize)
        self.closeButton.frame = closeButtonFrame
        self.closeButton.isHidden = interfaceState.renderedPeer == nil

        self.actionArea.frame = CGRect(origin: CGPoint(x: leftInset, y: 2.0), size: CGSize(width: closeButtonFrame.minX - leftInset, height: bounds.height))

        self.lineNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 8.0), size: CGSize(width: 2.0, height: bounds.size.height - 10.0))

        let titleSize = self.titleNode.updateLayout(CGSize(width: bounds.size.width - leftInset - textLineInset - rightInset - textRightInset, height: bounds.size.height))
        self.titleNode.frame = CGRect(origin: CGPoint(x: leftInset + textLineInset, y: 7.0), size: titleSize)

        let textSize = self.textNode.updateLayout(CGSize(width: bounds.size.width - leftInset - textLineInset - rightInset - textRightInset, height: bounds.size.height))
        self.textNode.frame = CGRect(origin: CGPoint(x: leftInset + textLineInset, y: 25.0), size: textSize)
    }
    
    @objc func closePressed() {
        guard let (isPersonal, peerDisplayTitle) = self.sourcePeer else {
            return
        }
        let messageCount = Int32(self.messageIds.count)
        let messages = self.strings.Conversation_ForwardOptions_Messages(messageCount)
        let string = isPersonal ? self.strings.Conversation_ForwardOptions_TextPersonal(messages, peerDisplayTitle) : self.strings.Conversation_ForwardOptions_Text(messages, peerDisplayTitle)
        
        let font = Font.regular(floor(self.fontSize.baseDisplaySize * 15.0 / 17.0))
        let boldFont = Font.semibold(floor(self.fontSize.baseDisplaySize * 15.0 / 17.0))
        let body = MarkdownAttributeSet(font: font, textColor: self.theme.actionSheet.secondaryTextColor)
        let bold = MarkdownAttributeSet(font: boldFont, textColor: self.theme.actionSheet.secondaryTextColor)
        
        let title = NSAttributedString(string: self.strings.Conversation_ForwardOptions_Title(messageCount), font: Font.semibold(floor(self.fontSize.baseDisplaySize)), textColor: self.theme.actionSheet.primaryTextColor, paragraphAlignment: .center)
        let text = addAttributesToStringWithRanges(string._tuple, body: body, argumentAttributes: [0: bold, 1: bold], textAlignment: .center)
        
        let alertController = richTextAlertController(context: self.context, title: title, text: text, actions: [TextAlertAction(type: .genericAction, title: self.strings.Conversation_ForwardOptions_ForwardToAnotherChat, action: { [weak self] in
            self?.interfaceInteraction?.forwardCurrentForwardMessages()
        }), TextAlertAction(type: .genericAction, title: self.hideSendersNames ? self.strings.Conversation_ForwardOptions_ShowSendersNames : self.strings.Conversation_ForwardOptions_HideSendersNames, action: { [weak self] in
            if let strongSelf = self {
                strongSelf.interfaceInteraction?.updateForwardMessageHideSendersNames(!strongSelf.hideSendersNames)
            }
        }), TextAlertAction(type: .destructiveAction, title: self.strings.Conversation_ForwardOptions_CancelForwarding, action: { [weak self] in
            self?.dismiss?()
        })], actionLayout: .vertical)
        self.interfaceInteraction?.presentController(alertController, nil)
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if self.closeButton.isHidden {
                self.interfaceInteraction?.updateForwardMessageHideSendersNames(!self.hideSendersNames)
            } else {
                self.closePressed()
            }
        }
    }
}
