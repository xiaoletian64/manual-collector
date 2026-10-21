import Foundation

struct Manual: Identifiable, Codable {
    let id: UUID
    var productName: String
    var brand: String
    var model: String
    var category: Category
    var coverImageURL: URL?
    var pageCount: Int
    var completenessScore: Int
    var createdAt: Date
    var cloudSyncStatus: SyncStatus

    init(id: UUID = UUID(),
         productName: String,
         brand: String = "",
         model: String = "",
         category: Category = .其他,
         coverImageURL: URL? = nil,
         pageCount: Int = 0,
         completenessScore: Int = 0,
         createdAt: Date = Date(),
         cloudSyncStatus: SyncStatus = .local) {
        self.id = id
        self.productName = productName
        self.brand = brand
        self.model = model
        self.category = category
        self.coverImageURL = coverImageURL
        self.pageCount = pageCount
        self.completenessScore = completenessScore
        self.createdAt = createdAt
        self.cloudSyncStatus = cloudSyncStatus
    }
}

enum Category: String, CaseIterable, Codable {
    case 厨电, 数码, 家具, 汽车, 其他
}

enum SyncStatus: String, Codable {
    case local, syncing, synced
}
