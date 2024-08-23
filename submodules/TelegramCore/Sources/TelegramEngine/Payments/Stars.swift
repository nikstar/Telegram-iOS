import Foundation
import Postbox
import MtProtoKit
import SwiftSignalKit
import TelegramApi

public struct StarsTopUpOption: Equatable, Codable {
    enum CodingKeys: String, CodingKey {
        case count
        case storeProductId
        case currency
        case amount
        case isExtended
    }
    
    public let count: Int64
    public let storeProductId: String?
    public let currency: String
    public let amount: Int64
    public let isExtended: Bool
    
    public init(count: Int64, storeProductId: String?, currency: String, amount: Int64, isExtended: Bool) {
        self.count = count
        self.storeProductId = storeProductId
        self.currency = currency
        self.amount = amount
        self.isExtended = isExtended
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.count = try container.decode(Int64.self, forKey: .count)
        self.storeProductId = try container.decodeIfPresent(String.self, forKey: .storeProductId)
        self.currency = try container.decode(String.self, forKey: .currency)
        self.amount = try container.decode(Int64.self, forKey: .amount)
        self.isExtended = try container.decodeIfPresent(Bool.self, forKey: .isExtended) ?? false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.count, forKey: .count)
        try container.encodeIfPresent(self.storeProductId, forKey: .storeProductId)
        try container.encode(self.currency, forKey: .currency)
        try container.encode(self.amount, forKey: .amount)
        try container.encode(self.isExtended, forKey: .isExtended)
    }
}

extension StarsTopUpOption {
    init(apiStarsTopupOption: Api.StarsTopupOption) {
        switch apiStarsTopupOption {
        case let .starsTopupOption(flags, stars, storeProduct, currency, amount):
            self.init(count: stars, storeProductId: storeProduct, currency: currency, amount: amount, isExtended: (flags & (1 << 1)) != 0)
        }
    }
}

func _internal_starsTopUpOptions(account: Account) -> Signal<[StarsTopUpOption], NoError> {
    return account.network.request(Api.functions.payments.getStarsTopupOptions())
    |> map(Optional.init)
    |> `catch` { _ -> Signal<[Api.StarsTopupOption]?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { results -> Signal<[StarsTopUpOption], NoError> in
        if let results = results {
            return .single(results.map { StarsTopUpOption(apiStarsTopupOption: $0) })
        } else {
            return .single([])
        }
    }
}

public struct StarsGiftOption: Equatable, Codable {
    enum CodingKeys: String, CodingKey {
        case count
        case currency
        case amount
        case storeProductId
        case isExtended
    }
    
    public let count: Int64
    public let currency: String
    public let amount: Int64
    public let storeProductId: String?
    public let isExtended: Bool
    
    public init(count: Int64, storeProductId: String?, currency: String, amount: Int64, isExtended: Bool) {
        self.count = count
        self.currency = currency
        self.amount = amount
        self.storeProductId = storeProductId
        self.isExtended = isExtended
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.count = try container.decode(Int64.self, forKey: .count)
        self.storeProductId = try container.decodeIfPresent(String.self, forKey: .storeProductId)
        self.currency = try container.decode(String.self, forKey: .currency)
        self.amount = try container.decode(Int64.self, forKey: .amount)
        self.isExtended = try container.decodeIfPresent(Bool.self, forKey: .isExtended) ?? false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.count, forKey: .count)
        try container.encodeIfPresent(self.storeProductId, forKey: .storeProductId)
        try container.encode(self.currency, forKey: .currency)
        try container.encode(self.amount, forKey: .amount)
        try container.encode(self.isExtended, forKey: .isExtended)
    }
}

extension StarsGiftOption {
    init(apiStarsGiftOption: Api.StarsGiftOption) {
        switch apiStarsGiftOption {
        case let .starsGiftOption(flags, stars, storeProduct, currency, amount):
            self.init(count: stars, storeProductId: storeProduct, currency: currency, amount: amount, isExtended: (flags & (1 << 1)) != 0)
        }
    }
}

func _internal_starsGiftOptions(account: Account, peerId: EnginePeer.Id?) -> Signal<[StarsGiftOption], NoError> {
    return account.postbox.transaction { transaction -> Api.InputUser? in
        return peerId.flatMap { transaction.getPeer($0).flatMap(apiInputUser) }
    }
    |> mapToSignal { inputUser in
        var flags: Int32 = 0
        if let _ = inputUser {
            flags |= (1 << 0)
        }
        return account.network.request(Api.functions.payments.getStarsGiftOptions(flags: flags, userId: inputUser))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<[Api.StarsGiftOption]?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { results -> Signal<[StarsGiftOption], NoError> in
            if let results = results {
                return .single(results.map { StarsGiftOption(apiStarsGiftOption: $0) })
            } else {
                return .single([])
            }
        }
    }
}



public struct StarsGiveawayOption: Equatable, Codable {
    enum CodingKeys: String, CodingKey {
        case count
        case currency
        case amount
        case yearlyBoosts
        case storeProductId
        case winners
        case isExtended
        case isDefault
    }
    
    public struct Winners: Equatable, Codable {
        enum CodingKeys: String, CodingKey {
            case users
            case starsPerUser
            case isDefault
        }
        
        public let users: Int32
        public let starsPerUser: Int64
        public let isDefault: Bool
        
        public init(users: Int32, starsPerUser: Int64, isDefault: Bool) {
            self.users = users
            self.starsPerUser = starsPerUser
            self.isDefault = isDefault
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.users = try container.decode(Int32.self, forKey: .users)
            self.starsPerUser = try container.decode(Int64.self, forKey: .starsPerUser)
            self.isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.users, forKey: .users)
            try container.encode(self.starsPerUser, forKey: .starsPerUser)
            try container.encode(self.isDefault, forKey: .isDefault)
        }
    }
    
    public let count: Int64
    public let yearlyBoosts: Int32
    public let currency: String
    public let amount: Int64
    public let storeProductId: String?
    public let winners: [Winners]
    public let isExtended: Bool
    public let isDefault: Bool
    
    public init(count: Int64, yearlyBoosts: Int32, storeProductId: String?, currency: String, amount: Int64, winners: [Winners], isExtended: Bool, isDefault: Bool) {
        self.count = count
        self.yearlyBoosts = yearlyBoosts
        self.currency = currency
        self.amount = amount
        self.storeProductId = storeProductId
        self.winners = winners
        self.isExtended = isExtended
        self.isDefault = isDefault
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.count = try container.decode(Int64.self, forKey: .count)
        self.yearlyBoosts = try container.decode(Int32.self, forKey: .yearlyBoosts)
        self.storeProductId = try container.decodeIfPresent(String.self, forKey: .storeProductId)
        self.currency = try container.decode(String.self, forKey: .currency)
        self.amount = try container.decode(Int64.self, forKey: .amount)
        self.winners = try container.decode([StarsGiveawayOption.Winners].self, forKey: .winners)
        self.isExtended = try container.decodeIfPresent(Bool.self, forKey: .isExtended) ?? false
        self.isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.count, forKey: .count)
        try container.encode(self.yearlyBoosts, forKey: .yearlyBoosts)
        try container.encodeIfPresent(self.storeProductId, forKey: .storeProductId)
        try container.encode(self.currency, forKey: .currency)
        try container.encode(self.amount, forKey: .amount)
        try container.encode(self.winners, forKey: .winners)
        try container.encode(self.isExtended, forKey: .isExtended)
        try container.encode(self.isDefault, forKey: .isDefault)
    }
}

extension StarsGiveawayOption.Winners {
    init(apiStarsGiveawayWinnersOption: Api.StarsGiveawayWinnersOption) {
        switch apiStarsGiveawayWinnersOption {
        case let .starsGiveawayWinnersOption(flags, users, starsPerUser):
            self.init(users: users, starsPerUser: starsPerUser, isDefault: (flags & (1 << 0)) != 0)
        }
    }
}

extension StarsGiveawayOption {
    init(apiStarsGiveawayOption: Api.StarsGiveawayOption) {
        switch apiStarsGiveawayOption {
        case let .starsGiveawayOption(flags, stars, yearlyBoosts, storeProduct, currency, amount, winners):
            self.init(count: stars, yearlyBoosts: yearlyBoosts, storeProductId: storeProduct, currency: currency, amount: amount, winners: winners.map { StarsGiveawayOption.Winners(apiStarsGiveawayWinnersOption: $0) }, isExtended: (flags & (1 << 0)) != 0, isDefault: (flags & (1 << 1)) != 0)
        }
    }
}

func _internal_starsGiveawayOptions(account: Account) -> Signal<[StarsGiveawayOption], NoError> {
    return account.network.request(Api.functions.payments.getStarsGiveawayOptions())
    |> map(Optional.init)
    |> `catch` { _ -> Signal<[Api.StarsGiveawayOption]?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { results -> Signal<[StarsGiveawayOption], NoError> in
        if let results = results {
            return .single(results.map { StarsGiveawayOption(apiStarsGiveawayOption: $0) })
        } else {
            return .single([])
        }
    }
}

struct InternalStarsStatus {
    let balance: Int64
    let subscriptionsMissingBalance: Int64?
    let subscriptions: [StarsContext.State.Subscription]
    let nextSubscriptionsOffset: String?
    let transactions: [StarsContext.State.Transaction]
    let nextTransactionsOffset: String?
}

private enum RequestStarsStateError {
    case generic
}

private func _internal_requestStarsState(account: Account, peerId: EnginePeer.Id, mode: StarsTransactionsContext.Mode, subscriptionId: String?, offset: String?, limit: Int32) -> Signal<InternalStarsStatus, RequestStarsStateError> {
    return account.postbox.transaction { transaction -> Peer? in
        return transaction.getPeer(peerId)
    } 
    |> castError(RequestStarsStateError.self)
    |> mapToSignal { peer -> Signal<InternalStarsStatus, RequestStarsStateError> in
        guard let peer, let inputPeer = apiInputPeer(peer) else {
            return .fail(.generic)
        }
                
        let signal: Signal<Api.payments.StarsStatus, MTRpcError>
        if let offset {
            var flags: Int32 = 0
            switch mode {
            case .incoming:
                flags = 1 << 0
            case .outgoing:
                flags = 1 << 1
            default:
                break
            }
            if let _ = subscriptionId {
                flags = 1 << 3
            }
            signal = account.network.request(Api.functions.payments.getStarsTransactions(flags: flags, subscriptionId: subscriptionId, peer: inputPeer, offset: offset, limit: limit))
        } else {
            signal = account.network.request(Api.functions.payments.getStarsStatus(peer: inputPeer))
        }
        
        return signal
        |> retryRequest
        |> castError(RequestStarsStateError.self)
        |> mapToSignal { result -> Signal<InternalStarsStatus, RequestStarsStateError> in
            return account.postbox.transaction { transaction -> InternalStarsStatus in
                switch result {
                case let .starsStatus(_, balance, _, _, subscriptionsMissingBalance, transactions, nextTransactionsOffset, chats, users):
                    let peers = AccumulatedPeers(chats: chats, users: users)
                    updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: peers)
                
                    var parsedTransactions: [StarsContext.State.Transaction] = []
                    if let transactions {
                        for entry in transactions {
                            if let parsedTransaction = StarsContext.State.Transaction(apiTransaction: entry, peerId: peerId != account.peerId ? peerId : nil, transaction: transaction) {
                                parsedTransactions.append(parsedTransaction)
                            }
                        }
                    }
                    return InternalStarsStatus(
                        balance: balance,
                        subscriptionsMissingBalance: subscriptionsMissingBalance,
                        subscriptions: [],
                        nextSubscriptionsOffset: nil,
                        transactions: parsedTransactions,
                        nextTransactionsOffset: nextTransactionsOffset
                    )
                }
            }
            |> castError(RequestStarsStateError.self)
        }
    }
}

private enum RequestStarsSubscriptionsError {
    case generic
}

private func _internal_requestStarsSubscriptions(account: Account, peerId: EnginePeer.Id, offset: String, missingBalance: Bool) -> Signal<InternalStarsStatus, RequestStarsSubscriptionsError> {
    return account.postbox.transaction { transaction -> Peer? in
        return transaction.getPeer(peerId)
    }
    |> castError(RequestStarsSubscriptionsError.self)
    |> mapToSignal { peer -> Signal<InternalStarsStatus, RequestStarsSubscriptionsError> in
        guard let peer, let inputPeer = apiInputPeerOrSelf(peer, accountPeerId: peerId) else {
            return .fail(.generic)
        }
        var flags: Int32 = 0
        if missingBalance {
            flags |= (1 << 0)
        }
        return account.network.request(Api.functions.payments.getStarsSubscriptions(flags: flags, peer: inputPeer, offset: offset))
        |> retryRequest
        |> castError(RequestStarsSubscriptionsError.self)
        |> mapToSignal { result -> Signal<InternalStarsStatus, RequestStarsSubscriptionsError> in
            return account.postbox.transaction { transaction -> InternalStarsStatus in
                switch result {
                case let .starsStatus(_, balance, subscriptions, subscriptionsNextOffset, subscriptionsMissingBalance, _, _, chats, users):
                    let peers = AccumulatedPeers(chats: chats, users: users)
                    updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: peers)
                    
                    var parsedSubscriptions: [StarsContext.State.Subscription] = []
                    if let subscriptions {
                        for entry in subscriptions {
                            if let parsedSubscription = StarsContext.State.Subscription(apiSubscription: entry, transaction: transaction) {
                                if !missingBalance || parsedSubscription.flags.contains(.missingBalance) {
                                    parsedSubscriptions.append(parsedSubscription)
                                }
                            }
                        }
                    }
                    return InternalStarsStatus(
                        balance: balance,
                        subscriptionsMissingBalance: subscriptionsMissingBalance,
                        subscriptions: parsedSubscriptions,
                        nextSubscriptionsOffset: subscriptionsNextOffset,
                        transactions: [],
                        nextTransactionsOffset: nil
                    )
                }
            }
            |> castError(RequestStarsSubscriptionsError.self)
        }
    }
}

private final class StarsContextImpl {
    private let account: Account
    fileprivate let peerId: EnginePeer.Id
    
    fileprivate var _state: StarsContext.State?
    private let _statePromise = Promise<StarsContext.State?>()
    var state: Signal<StarsContext.State?, NoError> {
        return self._statePromise.get()
    }
    
    private let disposable = MetaDisposable()
    private var updateDisposable: Disposable?
    
    init(account: Account) {
        assert(Queue.mainQueue().isCurrent())
        
        self.account = account
        self.peerId = account.peerId
        
        self._state = nil
        self._statePromise.set(.single(nil))
        
        self.load(force: true)
        
        self.updateDisposable = (account.stateManager.updatedStarsBalance()
        |> deliverOnMainQueue).startStrict(next: { [weak self] balances in
            guard let self, let state = self._state, let balance = balances[peerId] else {
                return
            }
            self.updateState(StarsContext.State(flags: [], balance: balance, subscriptions: state.subscriptions, canLoadMoreSubscriptions: state.canLoadMoreSubscriptions, transactions: state.transactions, canLoadMoreTransactions: state.canLoadMoreTransactions, isLoading: false))
            self.load(force: true)
        })
    }
    
    deinit {
        assert(Queue.mainQueue().isCurrent())
        self.disposable.dispose()
        self.updateDisposable?.dispose()
    }
    
    private var previousLoadTimestamp: Double?
    func load(force: Bool) {
        assert(Queue.mainQueue().isCurrent())
        
        let currentTimestamp = CFAbsoluteTimeGetCurrent()
        if let previousLoadTimestamp = self.previousLoadTimestamp, currentTimestamp - previousLoadTimestamp < 60 && !force {
            return
        }
        self.previousLoadTimestamp = currentTimestamp
        
        self.disposable.set((_internal_requestStarsState(account: self.account, peerId: self.peerId, mode: .all, subscriptionId: nil, offset: nil, limit: 5)
        |> deliverOnMainQueue).start(next: { [weak self] status in
            guard let self else {
                return
            }
            self.updateState(StarsContext.State(flags: [], balance: status.balance, subscriptions: status.subscriptions, canLoadMoreSubscriptions: status.nextSubscriptionsOffset != nil, transactions: status.transactions, canLoadMoreTransactions: status.nextTransactionsOffset != nil, isLoading: false))
        }, error: { [weak self] _ in
            guard let self else {
                return
            }
            Queue.mainQueue().after(2.5, {
                self.load(force: true)
            })
        }))
    }
    
    func add(balance: Int64, addTransaction: Bool) {
        guard let state = self._state else {
            return
        }
        var transactions = state.transactions
        if addTransaction {
            transactions.insert(.init(flags: [.isLocal], id: "\(arc4random())", count: balance, date: Int32(Date().timeIntervalSince1970), peer: .appStore, title: nil, description: nil, photo: nil, transactionDate: nil, transactionUrl: nil, paidMessageId: nil, giveawayMessageId: nil, media: [], subscriptionPeriod: nil), at: 0)
        }
        
        self.updateState(StarsContext.State(flags: [.isPendingBalance], balance: max(0, state.balance + balance), subscriptions: state.subscriptions, canLoadMoreSubscriptions: state.canLoadMoreSubscriptions, transactions: transactions, canLoadMoreTransactions: state.canLoadMoreTransactions, isLoading: state.isLoading))
    }
    
    fileprivate func updateBalance(_ balance: Int64, transactions: [StarsContext.State.Transaction]?) {
        guard let state = self._state else {
            return
        }
        self.updateState(StarsContext.State(flags: [], balance: balance, subscriptions: state.subscriptions, canLoadMoreSubscriptions: state.canLoadMoreSubscriptions, transactions: transactions ?? state.transactions, canLoadMoreTransactions: state.canLoadMoreTransactions, isLoading: state.isLoading))
    }
    
    private func updateState(_ state: StarsContext.State) {
        self._state = state
        self._statePromise.set(.single(state))
    }
}

private extension StarsContext.State.Transaction {
    init?(apiTransaction: Api.StarsTransaction, peerId: EnginePeer.Id?, transaction: Transaction) {
        switch apiTransaction {
        case let .starsTransaction(apiFlags, id, stars, date, transactionPeer, title, description, photo, transactionDate, transactionUrl, _, messageId, extendedMedia, subscriptionPeriod, giveawayPostId):
            let parsedPeer: StarsContext.State.Transaction.Peer
            var paidMessageId: MessageId?
            var giveawayMessageId: MessageId?
           
            switch transactionPeer {
            case .starsTransactionPeerAppStore:
                parsedPeer = .appStore
            case .starsTransactionPeerPlayMarket:
                parsedPeer = .playMarket
            case .starsTransactionPeerFragment:
                parsedPeer = .fragment
            case .starsTransactionPeerPremiumBot:
                parsedPeer = .premiumBot
            case .starsTransactionPeerAds:
                parsedPeer = .ads
            case .starsTransactionPeerUnsupported:
                parsedPeer = .unsupported
            case let .starsTransactionPeer(apiPeer):
                guard let peer = transaction.getPeer(apiPeer.peerId) else {
                    return nil
                }
                parsedPeer = .peer(EnginePeer(peer))
                if let messageId {
                    if let peerId {
                        paidMessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: messageId)
                    } else {
                        paidMessageId = MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: messageId)
                    }
                }
                if let giveawayPostId {
                    giveawayMessageId = MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: giveawayPostId)
                }
            }
            
            var flags: Flags = []
            if (apiFlags & (1 << 3)) != 0 {
                flags.insert(.isRefund)
            }
            if (apiFlags & (1 << 4)) != 0 {
                flags.insert(.isPending)
            }
            if (apiFlags & (1 << 6)) != 0 {
                flags.insert(.isFailed)
            }
            if (apiFlags & (1 << 10)) != 0 {
                flags.insert(.isGift)
            }
            if (apiFlags & (1 << 11)) != 0 {
                flags.insert(.isReaction)
            }
            
            let media = extendedMedia.flatMap({ $0.compactMap { textMediaAndExpirationTimerFromApiMedia($0, PeerId(0)).media } }) ?? []
            let _ = subscriptionPeriod
            self.init(flags: flags, id: id, count: stars, date: date, peer: parsedPeer, title: title, description: description, photo: photo.flatMap(TelegramMediaWebFile.init), transactionDate: transactionDate, transactionUrl: transactionUrl, paidMessageId: paidMessageId, giveawayMessageId: giveawayMessageId, media: media, subscriptionPeriod: subscriptionPeriod)
        }
    }
}

private extension StarsContext.State.Subscription {
    init?(apiSubscription: Api.StarsSubscription, transaction: Transaction) {
        switch apiSubscription {
        case let .starsSubscription(apiFlags, id, apiPeer, untilDate, pricing, inviteHash):
            guard let peer = transaction.getPeer(apiPeer.peerId) else {
                return nil
            }
            var flags: Flags = []
            if (apiFlags & (1 << 0)) != 0 {
                flags.insert(.isCancelled)
            }
            if (apiFlags & (1 << 1)) != 0 {
                flags.insert(.canRefulfill)
            }
            if (apiFlags & (1 << 2)) != 0 {
                flags.insert(.missingBalance)
            }
            self.init(flags: flags, id: id, peer: EnginePeer(peer), untilDate: untilDate, pricing: StarsSubscriptionPricing(apiStarsSubscriptionPricing: pricing), inviteHash: inviteHash)
        }
    }
}

public final class StarsContext {
    public struct State: Equatable {
        public struct Transaction: Equatable {
            public struct Flags: OptionSet {
                public var rawValue: Int32
                
                public init(rawValue: Int32) {
                    self.rawValue = rawValue
                }
                
                public static let isRefund = Flags(rawValue: 1 << 0)
                public static let isLocal = Flags(rawValue: 1 << 1)
                public static let isPending = Flags(rawValue: 1 << 2)
                public static let isFailed = Flags(rawValue: 1 << 3)
                public static let isGift = Flags(rawValue: 1 << 4)
                public static let isReaction = Flags(rawValue: 1 << 5)
            }
            
            public enum Peer: Equatable {
                case appStore
                case playMarket
                case fragment
                case premiumBot
                case ads
                case unsupported
                case peer(EnginePeer)
            }
            
            public let flags: Flags
            public let id: String
            public let count: Int64
            public let date: Int32
            public let peer: Peer
            public let title: String?
            public let description: String?
            public let photo: TelegramMediaWebFile?
            public let transactionDate: Int32?
            public let transactionUrl: String?
            public let paidMessageId: MessageId?
            public let giveawayMessageId: MessageId?
            public let media: [Media]
            public let subscriptionPeriod: Int32?
            
            public init(
                flags: Flags,
                id: String,
                count: Int64,
                date: Int32,
                peer: Peer,
                title: String?,
                description: String?,
                photo: TelegramMediaWebFile?,
                transactionDate: Int32?,
                transactionUrl: String?,
                paidMessageId: MessageId?,
                giveawayMessageId: MessageId?,
                media: [Media],
                subscriptionPeriod: Int32?
            ) {
                self.flags = flags
                self.id = id
                self.count = count
                self.date = date
                self.peer = peer
                self.title = title
                self.description = description
                self.photo = photo
                self.transactionDate = transactionDate
                self.transactionUrl = transactionUrl
                self.paidMessageId = paidMessageId
                self.giveawayMessageId = giveawayMessageId
                self.media = media
                self.subscriptionPeriod = subscriptionPeriod
            }
            
            public static func == (lhs: Transaction, rhs: Transaction) -> Bool {
                if lhs.flags != rhs.flags {
                    return false
                }
                if lhs.id != rhs.id {
                    return false
                }
                if lhs.count != rhs.count {
                    return false
                }
                if lhs.date != rhs.date {
                    return false
                }
                if lhs.peer != rhs.peer {
                    return false
                }
                if lhs.title != rhs.title {
                    return false
                }
                if lhs.description != rhs.description {
                    return false
                }
                if lhs.photo != rhs.photo {
                    return false
                }
                if lhs.transactionDate != rhs.transactionDate {
                    return false
                }
                if lhs.transactionUrl != rhs.transactionUrl {
                    return false
                }
                if lhs.paidMessageId != rhs.paidMessageId {
                    return false
                }
                if lhs.giveawayMessageId != rhs.giveawayMessageId {
                    return false
                }
                if !areMediaArraysEqual(lhs.media, rhs.media) {
                    return false
                }
                if lhs.subscriptionPeriod != rhs.subscriptionPeriod {
                    return false
                }
                return true
            }
        }
        
        public struct Subscription: Equatable {
            public struct Flags: OptionSet {
                public var rawValue: Int32
                
                public init(rawValue: Int32) {
                    self.rawValue = rawValue
                }
                
                public static let isCancelled = Flags(rawValue: 1 << 0)
                public static let canRefulfill = Flags(rawValue: 1 << 1)
                public static let missingBalance = Flags(rawValue: 1 << 2)
            }
            
            public let flags: Flags
            public let id: String
            public let peer: EnginePeer
            public let untilDate: Int32
            public let pricing: StarsSubscriptionPricing
            public let inviteHash: String?
            
            public init(
                flags: Flags,
                id: String,
                peer: EnginePeer,
                untilDate: Int32,
                pricing: StarsSubscriptionPricing,
                inviteHash: String?
            ) {
                self.flags = flags
                self.id = id
                self.peer = peer
                self.untilDate = untilDate
                self.pricing = pricing
                self.inviteHash = inviteHash
            }
            
            public static func == (lhs: Subscription, rhs: Subscription) -> Bool {
                if lhs.flags != rhs.flags {
                    return false
                }
                if lhs.id != rhs.id {
                    return false
                }
                if lhs.peer != rhs.peer {
                    return false
                }
                if lhs.untilDate != rhs.untilDate {
                    return false
                }
                if lhs.pricing != rhs.pricing {
                    return false
                }
                if lhs.inviteHash != rhs.inviteHash {
                    return false
                }
                return true
            }
        }
        
        public struct Flags: OptionSet {
            public var rawValue: Int32
            
            public init(rawValue: Int32) {
                self.rawValue = rawValue
            }
            
            public static let isPendingBalance = Flags(rawValue: 1 << 0)
        }
        
        public var flags: Flags
        public var balance: Int64
        public var subscriptions: [Subscription]
        public var canLoadMoreSubscriptions: Bool
        public var transactions: [Transaction]
        public var canLoadMoreTransactions: Bool
        public var isLoading: Bool
        
        init(flags: Flags, balance: Int64, subscriptions: [Subscription], canLoadMoreSubscriptions: Bool, transactions: [Transaction], canLoadMoreTransactions: Bool, isLoading: Bool) {
            self.flags = flags
            self.balance = balance
            self.subscriptions = subscriptions
            self.canLoadMoreSubscriptions = canLoadMoreSubscriptions
            self.transactions = transactions
            self.canLoadMoreTransactions = canLoadMoreTransactions
            self.isLoading = isLoading
        }
        
        public static func == (lhs: State, rhs: State) -> Bool {
            if lhs.flags != rhs.flags {
                return true
            }
            if lhs.balance != rhs.balance {
                return false
            }
            if lhs.transactions != rhs.transactions {
                return false
            }
            if lhs.subscriptions != rhs.subscriptions {
                return false
            }
            if lhs.canLoadMoreTransactions != rhs.canLoadMoreTransactions {
                return false
            }
            if lhs.isLoading != rhs.isLoading {
                return false
            }
            return true
        }
    }
    
    private let impl: QueueLocalObject<StarsContextImpl>
    
    public var state: Signal<StarsContext.State?, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.state.start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
    
    var peerId: EnginePeer.Id {
        var peerId: EnginePeer.Id?
        self.impl.syncWith { impl in
            peerId = impl.peerId
        }
        return peerId!
    }
    
    public var currentState: StarsContext.State? {
        var state: StarsContext.State?
        self.impl.syncWith { impl in
            state = impl._state
        }
        return state
    }
    
    public func add(balance: Int64, addTransaction: Bool = true) {
        self.impl.with {
            $0.add(balance: balance, addTransaction: addTransaction)
        }
    }
    
    fileprivate func updateBalance(_ balance: Int64, transactions: [StarsContext.State.Transaction]?) {
        self.impl.with {
            $0.updateBalance(balance, transactions: transactions)
        }
    }
    
    
    public func load(force: Bool) {
        self.impl.with {
            $0.load(force: force)
        }
    }
    
    
    init(account: Account) {
        self.impl = QueueLocalObject(queue: Queue.mainQueue(), generate: {
            return StarsContextImpl(account: account)
        })
    }
}

private final class StarsTransactionsContextImpl {
    private let account: Account
    private weak var starsContext: StarsContext?
    private let peerId: EnginePeer.Id
    private let mode: StarsTransactionsContext.Mode
    
    private var _state: StarsTransactionsContext.State
    private let _statePromise = Promise<StarsTransactionsContext.State>()
    var state: Signal<StarsTransactionsContext.State, NoError> {
        return self._statePromise.get()
    }
    private var nextOffset: String? = ""
    
    private let disposable = MetaDisposable()
    private var stateDisposable: Disposable?
    
    init(account: Account, subject: StarsTransactionsContext.Subject, mode: StarsTransactionsContext.Mode) {
        assert(Queue.mainQueue().isCurrent())
        
        self.account = account
        switch subject {
        case let .starsContext(starsContext):
            self.starsContext = starsContext
            self.peerId = starsContext.peerId
        case let .peer(peerId):
            self.peerId = peerId
        }
        self.mode = mode
        
        let currentTransactions = self.starsContext?.currentState?.transactions ?? []
        let initialTransactions: [StarsContext.State.Transaction]
        switch mode {
        case .all:
            initialTransactions = currentTransactions
        case .incoming:
            initialTransactions = currentTransactions.filter { $0.count > 0 }
        case .outgoing:
            initialTransactions = currentTransactions.filter { $0.count < 0 }
        }
        
        self._state = StarsTransactionsContext.State(transactions: initialTransactions, canLoadMore: true, isLoading: false)
        self._statePromise.set(.single(self._state))
        
        if let starsContext = self.starsContext {
            self.stateDisposable = (starsContext.state
            |> deliverOnMainQueue).start(next: { [weak self] state in
                guard let self, let state else {
                    return
                }
                
                let currentTransactions = state.transactions
                let filteredTransactions: [StarsContext.State.Transaction]
                switch mode {
                case .all:
                    filteredTransactions = currentTransactions
                case .incoming:
                    filteredTransactions = currentTransactions.filter { $0.count > 0 }
                case .outgoing:
                    filteredTransactions = currentTransactions.filter { $0.count < 0 }
                }
                
                if filteredTransactions != initialTransactions {
                    var existingIds = Set<String>()
                    for transaction in self._state.transactions {
                        if !transaction.flags.contains(.isLocal) {
                            existingIds.insert(transaction.id)
                        }
                    }
                    
                    var updatedState = self._state
                    updatedState.transactions.removeAll(where: { $0.flags.contains(.isLocal) })
                    for transaction in filteredTransactions.reversed() {
                        if !existingIds.contains(transaction.id) {
                            updatedState.transactions.insert(transaction, at: 0)
                        }
                    }
                    self.updateState(updatedState)
                }
            })
        }
    }
    
    deinit {
        assert(Queue.mainQueue().isCurrent())
        self.disposable.dispose()
        self.stateDisposable?.dispose()
    }
    
    func loadMore(reload: Bool = false) {
        assert(Queue.mainQueue().isCurrent())
        
        if reload {
            self.nextOffset = ""
        }
        
        guard !self._state.isLoading, let nextOffset = self.nextOffset else {
            return
        }
        
        var updatedState = self._state
        updatedState.isLoading = true
        self.updateState(updatedState)
                
        self.disposable.set((_internal_requestStarsState(account: self.account, peerId: self.peerId, mode: self.mode, subscriptionId: nil, offset: nextOffset, limit: self.nextOffset == "" ? 25 : 50)
        |> deliverOnMainQueue).start(next: { [weak self] status in
            guard let self else {
                return
            }
            self.nextOffset = status.nextTransactionsOffset
            
            var updatedState = self._state
            updatedState.transactions = nextOffset.isEmpty ? status.transactions : updatedState.transactions + status.transactions
            updatedState.isLoading = false
            updatedState.canLoadMore = self.nextOffset != nil
            self.updateState(updatedState)
            
            if case .all = self.mode, nextOffset.isEmpty {
                self.starsContext?.updateBalance(status.balance, transactions: status.transactions)
            } else {
                self.starsContext?.updateBalance(status.balance, transactions: nil)
            }
        }))
    }
    
    private func updateState(_ state: StarsTransactionsContext.State) {
        self._state = state
        self._statePromise.set(.single(state))
    }
}
    
public final class StarsTransactionsContext {
    public struct State: Equatable {
        public var transactions: [StarsContext.State.Transaction]
        public var canLoadMore: Bool
        public var isLoading: Bool
        
        init(transactions: [StarsContext.State.Transaction], canLoadMore: Bool, isLoading: Bool) {
            self.transactions = transactions
            self.canLoadMore = canLoadMore
            self.isLoading = isLoading
        }
    }
    
    fileprivate let impl: QueueLocalObject<StarsTransactionsContextImpl>
    
    public enum Subject {
        case starsContext(StarsContext)
        case peer(EnginePeer.Id)
    }
    
    public enum Mode {
        case all
        case incoming
        case outgoing
    }
    
    public var state: Signal<StarsTransactionsContext.State, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.state.start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
    
    public func reload() {
        self.impl.with {
            $0.loadMore(reload: true)
        }
    }
    
    public func loadMore() {
        self.impl.with {
            $0.loadMore()
        }
    }
    
    init(account: Account, subject: Subject, mode: Mode) {
        self.impl = QueueLocalObject(queue: Queue.mainQueue(), generate: {
            return StarsTransactionsContextImpl(account: account, subject: subject, mode: mode)
        })
    }
}

private final class StarsSubscriptionsContextImpl {
    private let account: Account
    private let missingBalance: Bool
    
    private var _state: StarsSubscriptionsContext.State
    private let _statePromise = Promise<StarsSubscriptionsContext.State>()
    var state: Signal<StarsSubscriptionsContext.State, NoError> {
        return self._statePromise.get()
    }
    private var nextOffset: String? = ""
    
    private let disposable = MetaDisposable()
    private var stateDisposable: Disposable?
    private let updateDisposable = MetaDisposable()
    
    init(account: Account, starsContext: StarsContext?, missingBalance: Bool) {
        assert(Queue.mainQueue().isCurrent())
        
        self.account = account
        self.missingBalance = missingBalance
        
        let currentSubscriptions = starsContext?.currentState?.subscriptions ?? []
        let canLoadMore = starsContext?.currentState?.canLoadMoreSubscriptions ?? true
        
        self._state = StarsSubscriptionsContext.State(balance: 0, subscriptions: currentSubscriptions, canLoadMore: canLoadMore, isLoading: false)
        self._statePromise.set(.single(self._state))
        
        self.loadMore()
    }
    
    deinit {
        assert(Queue.mainQueue().isCurrent())
        self.disposable.dispose()
        self.stateDisposable?.dispose()
        self.updateDisposable.dispose()
    }
    
    func loadMore() {
        assert(Queue.mainQueue().isCurrent())
        
        guard !self._state.isLoading, let nextOffset = self.nextOffset else {
            return
        }
        
        var updatedState = self._state
        updatedState.isLoading = true
        self.updateState(updatedState)
                
        self.disposable.set((_internal_requestStarsSubscriptions(account: self.account, peerId: self.account.peerId, offset: nextOffset, missingBalance: self.missingBalance)
        |> deliverOnMainQueue).start(next: { [weak self] status in
            guard let self else {
                return
            }

            self.nextOffset = status.nextSubscriptionsOffset
            
            var updatedState = self._state
            updatedState.balance = status.subscriptionsMissingBalance ?? 0
            updatedState.subscriptions = nextOffset.isEmpty ? status.subscriptions : updatedState.subscriptions + status.subscriptions
            updatedState.isLoading = false
            updatedState.canLoadMore = self.nextOffset != nil
            self.updateState(updatedState)
        }))
    }
    
    private func updateState(_ state: StarsSubscriptionsContext.State) {
        self._state = state
        self._statePromise.set(.single(state))
    }
    
    func updateSubscription(id: String, cancel: Bool) {
        var updatedState = self._state
        if let index = updatedState.subscriptions.firstIndex(where: { $0.id == id }) {
            let subscription = updatedState.subscriptions[index]
            var updatedFlags = subscription.flags
            if cancel {
                updatedFlags.insert(.isCancelled)
            } else {
                updatedFlags.remove(.isCancelled)
            }
            let updatedSubscription = StarsContext.State.Subscription(flags: updatedFlags, id: subscription.id, peer: subscription.peer, untilDate: subscription.untilDate, pricing: subscription.pricing, inviteHash: subscription.inviteHash)
            updatedState.subscriptions[index] = updatedSubscription
        }
        self.updateState(updatedState)
        self.updateDisposable.set(_internal_updateStarsSubscription(account: self.account, peerId: self.account.peerId, subscriptionId: id, cancel: cancel).startStrict())
    }
    
    private var previousLoadTimestamp: Double?
    func load(force: Bool) {
        assert(Queue.mainQueue().isCurrent())
        
        guard !self._state.isLoading else {
            return
        }
        
        let currentTimestamp = CFAbsoluteTimeGetCurrent()
        if let previousLoadTimestamp = self.previousLoadTimestamp, currentTimestamp - previousLoadTimestamp < 60 && !force {
            return
        }
        self.previousLoadTimestamp = currentTimestamp
        self._state.isLoading = true
        
        self.disposable.set((_internal_requestStarsSubscriptions(account: self.account, peerId: self.account.peerId, offset: "", missingBalance: self.missingBalance)
        |> deliverOnMainQueue).start(next: { [weak self] status in
            guard let self else {
                return
            }
            self.nextOffset = status.nextSubscriptionsOffset
            
            var updatedState = self._state
            updatedState.subscriptions = status.subscriptions
            updatedState.isLoading = false
            updatedState.canLoadMore = self.nextOffset != nil
            self.updateState(updatedState)
        }))
    }
}
    
public final class StarsSubscriptionsContext {
    public struct State: Equatable {
        public var balance: Int64
        public var subscriptions: [StarsContext.State.Subscription]
        public var canLoadMore: Bool
        public var isLoading: Bool
        
        init(balance: Int64, subscriptions: [StarsContext.State.Subscription], canLoadMore: Bool, isLoading: Bool) {
            self.balance = balance
            self.subscriptions = subscriptions
            self.canLoadMore = canLoadMore
            self.isLoading = isLoading
        }
    }
    
    fileprivate let impl: QueueLocalObject<StarsSubscriptionsContextImpl>
        
    public var state: Signal<StarsSubscriptionsContext.State, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.state.start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
    
    public func loadMore() {
        self.impl.with {
            $0.loadMore()
        }
    }
    
    init(account: Account, starsContext: StarsContext?, missingBalance: Bool) {
        self.impl = QueueLocalObject(queue: Queue.mainQueue(), generate: {
            return StarsSubscriptionsContextImpl(account: account, starsContext: starsContext, missingBalance: missingBalance)
        })
    }
    
    public func updateSubscription(id: String, cancel: Bool) {
        self.impl.with {
            $0.updateSubscription(id: id, cancel: cancel)
        }
    }
    
    public func load(force: Bool) {
        self.impl.with {
            $0.load(force: force)
        }
    }
}


func _internal_sendStarsPaymentForm(account: Account, formId: Int64, source: BotPaymentInvoiceSource) -> Signal<SendBotPaymentResult, SendBotPaymentFormError> {
    return account.postbox.transaction { transaction -> Api.InputInvoice? in
        return _internal_parseInputInvoice(transaction: transaction, source: source)
    }
    |> castError(SendBotPaymentFormError.self)
    |> mapToSignal { invoice -> Signal<SendBotPaymentResult, SendBotPaymentFormError> in
        guard let invoice = invoice else {
            return .fail(.generic)
        }
        
        let flags: Int32 = 0

        return account.network.request(Api.functions.payments.sendStarsForm(flags: flags, formId: formId, invoice: invoice))
        |> map { result -> SendBotPaymentResult in
            switch result {
                case let .paymentResult(updates):
                    account.stateManager.addUpdates(updates)
                
                    switch source {
                    case .starsChatSubscription:
                        let chats = updates.chats.compactMap { parseTelegramGroupOrChannel(chat: $0) }
                        if let first = chats.first {
                            return .done(receiptMessageId: nil, subscriptionPeerId: first.id)
                        }
                    default:
                        break
                    }
                    var receiptMessageId: MessageId?
                    for apiMessage in updates.messages {
                        if let message = StoreMessage(apiMessage: apiMessage, accountPeerId: account.peerId, peerIsForum: false) {
                            for media in message.media {
                                if let action = media as? TelegramMediaAction {
                                    if case .paymentSent = action.action {
                                        switch source {
                                        case let .slug(slug):
                                            for media in message.media {
                                                if let action = media as? TelegramMediaAction, case let .paymentSent(_, _, invoiceSlug?, _, _) = action.action, invoiceSlug == slug {
                                                    if case let .Id(id) = message.id {
                                                        receiptMessageId = id
                                                    }
                                                }
                                            }
                                        case let .message(messageId):
                                            for attribute in message.attributes {
                                                if let reply = attribute as? ReplyMessageAttribute {
                                                    if reply.messageId == messageId {
                                                        if case let .Id(id) = message.id {
                                                            receiptMessageId = id
                                                        }
                                                    }
                                                }
                                            }
                                        case let .premiumGiveaway(_, _, _, _, _, _, randomId, _, _, _, _):
                                            if message.globallyUniqueId == randomId {
                                                if case let .Id(id) = message.id {
                                                    receiptMessageId = id
                                                }
                                            }
                                        case .giftCode, .stars, .starsGift:
                                            receiptMessageId = nil
                                        case .starsChatSubscription:
                                            receiptMessageId = nil
                                        }
                                    }
                                }
                            }
                        }
                    }
                return .done(receiptMessageId: receiptMessageId, subscriptionPeerId: nil)
                case let .paymentVerificationNeeded(url):
                    return .externalVerificationRequired(url: url)
            }
        }
        |> `catch` { error -> Signal<SendBotPaymentResult, SendBotPaymentFormError> in
            if error.errorDescription == "BOT_PRECHECKOUT_FAILED" {
                return .fail(.precheckoutFailed)
            } else if error.errorDescription == "PAYMENT_FAILED" {
                return .fail(.paymentFailed)
            } else if error.errorDescription == "INVOICE_ALREADY_PAID" {
                return .fail(.alreadyPaid)
            } else if error.errorDescription == "MEDIA_ALREADY_PAID" {
                return .fail(.alreadyPaid)
            }
            return .fail(.generic)
        }
    }
}

public struct StarsTransactionReference: PostboxCoding, Hashable, Equatable {
    public let peerId: EnginePeer.Id
    public let id: String
    public let isRefund: Bool
    
    public init(peerId: EnginePeer.Id,  id: String, isRefund: Bool) {
        self.peerId = peerId
        self.id = id
        self.isRefund = isRefund
    }
    
    public init(decoder: PostboxDecoder) {
        self.peerId = EnginePeer.Id(decoder.decodeInt64ForKey("peerId", orElse: 0))
        self.id = decoder.decodeStringForKey("id", orElse: "")
        self.isRefund = decoder.decodeBoolForKey("refund", orElse: false)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.peerId.toInt64(), forKey: "peerId")
        encoder.encodeString(self.id, forKey: "id")
        encoder.encodeBool(self.isRefund, forKey: "refund")
    }
}

func _internal_getStarsTransaction(accountPeerId: PeerId, postbox: Postbox, network: Network, transactionReference: StarsTransactionReference) -> Signal<StarsContext.State.Transaction?, NoError> {
    return postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(transactionReference.peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<StarsContext.State.Transaction?, NoError> in
        guard let inputPeer else {
            return .single(nil)
        }
        return network.request(
            Api.functions.payments.getStarsTransactionsByID(
                peer: inputPeer,
                id: [.inputStarsTransaction(flags: transactionReference.isRefund ? (1 << 0) : 0, id: transactionReference.id)]
            )
        )
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.payments.StarsStatus?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<StarsContext.State.Transaction?, NoError> in
            return postbox.transaction { transaction -> StarsContext.State.Transaction? in
                guard let result, case let .starsStatus(_, _, _, _, _, transactions, _, chats, users) = result, let matchingTransaction = transactions?.first else {
                    return nil
                }
                let peers = AccumulatedPeers(chats: chats, users: users)
                updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: peers)
                
                return StarsContext.State.Transaction(apiTransaction: matchingTransaction, peerId: transactionReference.peerId, transaction: transaction)
            }
        }
    }
}

public struct StarsSubscriptionPricing: Codable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case period
        case amount
    }
    
    public let period: Int32
    public let amount: Int64
    
    public init(period: Int32, amount: Int64) {
        self.period = period
        self.amount = amount
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.period = try container.decode(Int32.self, forKey: .period)
        self.amount = try container.decode(Int64.self, forKey: .amount)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.period, forKey: .period)
        try container.encode(self.amount, forKey: .amount)
    }
    
    public static let monthPeriod: Int32 = 2592000
    public static let testPeriod: Int32 = 300
}

extension StarsSubscriptionPricing {
    init(apiStarsSubscriptionPricing: Api.StarsSubscriptionPricing) {
        switch apiStarsSubscriptionPricing {
        case let .starsSubscriptionPricing(period, amount):
            self = .init(period: period, amount: amount)
        }
    }
    
    var apiStarsSubscriptionPricing: Api.StarsSubscriptionPricing {
        return .starsSubscriptionPricing(period: self.period, amount: self.amount)
    }
}

public enum UpdateStarsSubsciptionError {
    case generic
}

func _internal_updateStarsSubscription(account: Account, peerId: EnginePeer.Id, subscriptionId: String, cancel: Bool) -> Signal<Never, UpdateStarsSubsciptionError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> castError(UpdateStarsSubsciptionError.self)
    |> mapToSignal { inputPeer -> Signal<Never, UpdateStarsSubsciptionError> in
        guard let inputPeer else {
            return .complete()
        }
        let flags: Int32 = (1 << 0)
        return account.network.request(Api.functions.payments.changeStarsSubscription(flags: flags, peer: inputPeer, subscriptionId: subscriptionId, canceled: cancel ? .boolTrue : .boolFalse))
        |> mapError { _ -> UpdateStarsSubsciptionError in
            return .generic
        }
        |> ignoreValues
    }
}

public enum FulfillStarsSubsciptionError {
    case generic
}

func _internal_fulfillStarsSubscription(account: Account, peerId: EnginePeer.Id, subscriptionId: String) -> Signal<Never, FulfillStarsSubsciptionError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> castError(FulfillStarsSubsciptionError.self)
    |> mapToSignal { inputPeer -> Signal<Never, FulfillStarsSubsciptionError> in
        guard let inputPeer else {
            return .complete()
        }
        return account.network.request(Api.functions.payments.fulfillStarsSubscription(peer: inputPeer, subscriptionId: subscriptionId))
        |> mapError { _ -> FulfillStarsSubsciptionError in
            return .generic
        }
        |> ignoreValues
    }
}
