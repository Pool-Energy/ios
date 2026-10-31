import Foundation

// MARK: - Paging

struct Page<Item: Decodable>: Decodable {
    let count: Int
    let next: String?
    let previous: String?
    let results: [Item]
}

// MARK: - Pool statistics

struct Stats: Decodable {
    let fee: Double
    let farmers: Int
    let farmersActive: Int
    let poolSpace: Int64
    let estimateWin: Int
    let timeSinceLastWin: Int?
    let blockchainHeight: Int64
    let blockchainSpace: Int64
    let blockchainDuststorm: Bool
    let blockchainMempoolFullPct: Int
    let rewardSystem: String
    let rewardsAmount: Int64
    let rewardsBlocks: Int
    let lastRewards: [LastReward]
    let xchCurrentPrice: XchPrice
    let poolWallets: [PoolWallet]
    let poolNodes: [PoolNode]
    let averageEffort: Double?
    let xchTbMonth: Double?
}

struct LastReward: Decodable {
    let date: String
    let height: Int
}

struct XchPrice: Decodable {
    let usd: Double?
    let eur: Double?

    func value(for currency: String) -> Double? {
        currency == "eur" ? eur : usd
    }
}

struct PoolWallet: Decodable, Identifiable {
    var id: String { name }
    let name: String
    let amount: Int64
    let synced: Bool
    let syncing: Bool?
    let height: Int64?
    let address: String?
}

struct PoolNode: Decodable, Identifiable {
    var id: String { name }
    let name: String
    let region: String?
    let synced: Bool?
    let enabled: Bool?
    let primary: Bool?
    let version: String?
    let location: String?
    let syncPercent: Double?
    let peakHeight: Int64?
}

// MARK: - Farmers

struct Launcher: Decodable, Identifiable {
    var id: String { launcherId }
    let launcherId: String
    let name: String?
    let pictureUrl: String?
    let p2SingletonPuzzleHash: String
    let points: Int
    let pointsPplns: Int
    let sharePplns: String
    let difficulty: Int
    let customDifficulty: String?
    let isPoolMember: Bool
    let estimatedSize: Int64
    let joinedAt: String?
    let joinedLastAt: String?
    let pointsOfTotal: Double?

    var displayName: String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cleaned = EmojiSupport.sanitized(trimmed)
        return cleaned.isEmpty ? Fmt.shortHash(launcherId) : cleaned
    }

    var share: Double {
        Double(sharePplns) ?? pointsOfTotal ?? 0
    }
}

struct LauncherDetail: Decodable, Identifiable {
    var id: String { launcherId }
    let launcherId: String
    let name: String?
    let pictureUrl: String?
    let p2SingletonPuzzleHash: String
    let points: Int
    let pointsPplns: Int
    let sharePplns: String
    let difficulty: Int
    let customDifficulty: String?
    let isPoolMember: Bool
    let estimatedSize: Int64
    let joinedAt: String?
    let joinedLastAt: String?
    let payout: PayoutSummary?
    let fee: FeeDetails?
    let pointsOfTotal: Double?
    let blocks: BlocksSummary?
    let partials: PartialsSummary?
    let rewards: RewardsSummary?
    let message: String?
    let currentEtw: Int?
    let currentEffort: Double?

    var displayName: String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cleaned = EmojiSupport.sanitized(trimmed)
        return cleaned.isEmpty ? Fmt.shortHash(launcherId) : cleaned
    }

    var share: Double {
        Double(sharePplns) ?? pointsOfTotal ?? 0
    }
}

struct PayoutSummary: Decodable {
    let totalPaid: Double?
    let totalUnpaid: Double?
    let totalTransactions: Int?
}

struct FeeDetails: Decodable {
    let stayLengthDays: Int?
    let stayLengthDaysMax: Int?
    let stayLengthDiscount: Double?
    let stayLengthDiscountMax: Double?
    let sizeDiscount: Double?
    let maxDiscount: Double?
    let pool: Double?
    let finalFee: Double?

    enum CodingKeys: String, CodingKey {
        case stayLengthDays, stayLengthDaysMax, stayLengthDiscount
        case stayLengthDiscountMax, sizeDiscount, maxDiscount, pool
        case finalFee = "final"
    }
}

struct BlocksSummary: Decodable {
    let total: Int
}

struct PartialsSummary: Decodable {
    let total: Int
    let points: Int
    let successful: Int
    let failed: Int
    let performance: Double?
    let harvesters: Int
}

struct RewardsSummary: Decodable {
    let today: Int64?
    let yesterday: Int64?
    let last24h: Int64?
    let last7d: Int64?
    let last30d: Int64?
    let lastPerDay: [DailyReward]?

    enum CodingKeys: String, CodingKey {
        case today, yesterday
        case last24h = "last_24h"
        case last7d = "last_7d"
        case last30d = "last_30d"
        case lastPerDay = "last_per_day"
    }
}

struct DailyReward: Decodable {
    let day: String
    let amount: Int64
}

// MARK: - Blocks

struct Block: Decodable, Identifiable {
    var id: Int { farmedHeight }
    let farmedBy: Launcher?
    let name: String?
    let singleton: String?
    let timestamp: Int
    let farmedHeight: Int
    let confirmedBlockIndex: Int
    let amount: Int64
    let poolSpace: Int64?
    let launcherEtw: Int64?
    let launcherEffort: Int?
    let estimateToWin: Int64?
    let luck: Int?
    let payout: String?
}

// MARK: - Partials

struct Partial: Decodable, Identifiable {
    var id: Int { timestamp }
    let timestamp: Int
    let difficulty: Int
    let error: String?
    let harvesterId: String?
    let plotId: String?
    let chiaVersion: String?
    let timeTaken: Double?
    let plotSize: Int?
    let launcher: String
}

// MARK: - Harvesters

struct Harvester: Decodable, Identifiable {
    var id: String { harvester }
    let launcher: String
    let harvester: String
    let version: String?
    let name: String?
}

// MARK: - Rewards

struct Payout: Decodable, Identifiable {
    let id: Int
    let datetime: String
    let amount: Int64
    let fee: Int64
    let blocks: [PayoutBlock]

    var total: Int64 { amount + fee }
}

struct PayoutBlock: Decodable {
    let farmedHeight: Int
    let timestamp: Int
}

struct PayoutAddress: Decodable, Identifiable {
    let id: Int
    let amount: Int64
    let puzzleHash: String
    let payout: Payout?
    let launcher: Launcher?
    let transaction: TransactionInfo?
}

struct TransactionInfo: Decodable {
    let transaction: String
    let confirmedBlockIndex: Int?
    let createdAtTime: String?
}

// MARK: - Timeseries

struct TimeseriesPoint: Decodable, Identifiable {
    var id: String { "\(datetime)-\(field ?? "")-\(value)" }
    let datetime: String
    let value: Double
    let field: String?

    private enum CodingKeys: String, CodingKey {
        case datetime, value, field
    }

    init(datetime: String, value: Double, field: String?) {
        self.datetime = datetime
        self.value = value
        self.field = field
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        datetime = try container.decode(String.self, forKey: .datetime)
        value = try container.decode(Double.self, forKey: .value)
        // `field` is a string in InfluxDB responses but an int in the schema.
        if let name = try? container.decode(String.self, forKey: .field) {
            field = name
        } else if let number = try? container.decode(Int.self, forKey: .field) {
            field = String(number)
        } else {
            field = nil
        }
    }

    var date: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: datetime) ?? ISO8601DateFormatter().date(from: datetime)
    }
}

// MARK: - Global message

struct GlobalMessage: Decodable, Identifiable {
    var id: String { "\(datetime ?? "")-\(message)" }
    let datetime: String?
    let name: String
    let message: String
    let level: String
    let enabled: Bool
}
