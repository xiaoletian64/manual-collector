import SwiftUI
import Combine

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var manuals: [Manual] = []
    @Published var selectedCategory: String = "全部"
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var syncStatus: String = ""

    private let ragService: RAGService
    private let cloudProvider: BaiduCloudProvider

    init(apiKey: String = UserDefaults.standard.string(forKey: "llm_api_key") ?? "") {
        self.ragService = RAGService(apiKey: apiKey)
        self.cloudProvider = BaiduCloudProvider()
    }

    var filteredManuals: [Manual] {
        let filtered: [Manual]
        if selectedCategory == "全部" {
            filtered = manuals
        } else {
            filtered = manuals.filter { $0.category.rawValue == selectedCategory }
        }
        if searchText.isEmpty { return filtered }
        return filtered.filter { m in
            m.productName.localizedCaseInsensitiveContains(searchText) ||
            m.model.localizedCaseInsensitiveContains(searchText)
        }
    }

    func loadManuals() {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.manuals = Manual.previewData()
            self?.isLoading = false
        }
    }

    func addManual(_ manual: Manual) {
        manuals.insert(manual, at: 0)
    }

    func syncToCloud(manual: Manual) async {
        syncStatus = "同步中..."
        do {
            try await cloudProvider.authenticate()
            let data = try JSONEncoder().encode(manual)
            _ = try await cloudProvider.upload(data: data, remotePath: "/apps/手册收集器/products/\(manual.id.uuidString)/meta.json")
            await MainActor.run { syncStatus = "已同步" }
        } catch {
            await MainActor.run { syncStatus = "同步失败: \(error.localizedDescription)" }
        }
    }
}

extension Manual {
    static func previewData() -> [Manual] {
        [
            Manual(id: UUID(), productName: "海尔冰箱", brand: "海尔", model: "BCD-500WGH", category: .厨电, coverImageURL: nil, pageCount: 24, completenessScore: 95, createdAt: Date(), cloudSyncStatus: .synced),
            Manual(id: UUID(), productName: "戴森吸尘器 V15", brand: "Dyson", model: "V15 Detect", category: .其他, coverImageURL: nil, pageCount: 36, completenessScore: 78, createdAt: Date().addingTimeInterval(-86400), cloudSyncStatus: .local),
            Manual(id: UUID(), productName: "小米空气净化器 4 Pro", brand: "小米", model: "AC-M24-SC", category: .数码, coverImageURL: nil, pageCount: 18, completenessScore: 88, createdAt: Date().addingTimeInterval(-172800), cloudSyncStatus: .synced),
        ]
    }
}
