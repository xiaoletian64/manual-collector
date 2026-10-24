import 'dart:convert';

const categories = ['未分类', '家电', '数码', '厨电', '工具', '汽车', '其他'];

/// 标题关键词 → 分类建议（保存时提示，用户一键采纳）。
const categoryHints = <String, List<String>>{
  '家电': [
    '冰箱',
    '洗衣机',
    '空调',
    '电视',
    '热水器',
    '油烟机',
    '燃气灶',
    '电风扇',
    '取暖器',
    '加湿器',
    '净化器',
    '吸尘器',
  ],
  '数码': [
    '手机',
    '平板',
    '笔记本',
    '电脑',
    '耳机',
    '音箱',
    '相机',
    '手表',
    '路由器',
    '键盘',
    '鼠标',
    '显示器',
    '充电',
  ],
  '厨电': [
    '电饭煲',
    '微波炉',
    '榨汁',
    '破壁',
    '空气炸',
    '咖啡机',
    '豆浆机',
    '电压力锅',
    '电磁炉',
    '烤箱',
    '水壶',
    '料理',
  ],
  '工具': ['电钻', '螺丝刀', '电锯', '扳手', '万用表', '热风枪', '焊', '测量'],
  '汽车': ['行车记录', '充电桩', '车载', '轮胎', '机油', '滤芯', '汽车'],
};

/// 从标题猜分类；猜不出返回 null。
String? suggestCategory(String title) {
  final t = title.toLowerCase();
  for (final entry in categoryHints.entries) {
    for (final keyword in entry.value) {
      if (t.contains(keyword)) {
        return entry.key;
      }
    }
  }
  return null;
}

/// 从 OCR 文本抽 400 客服电话（待用户确认后写入档案）。
String? suggestPhone(String ocrText) {
  final re = RegExp(r'4[0-9Oo]{2}[-— ]?[0-9Oo]{3}[-— ]?[0-9Oo]{3,4}');
  for (final match in re.allMatches(ocrText)) {
    final digits = match.group(0)!.replaceAll(RegExp('[^0-9]'), '');
    if (digits.length >= 10 &&
        digits.length <= 12 &&
        digits.startsWith('400')) {
      return digits;
    }
  }
  return null;
}

class OcrLine {
  const OcrLine(this.text, this.x, this.y, this.width, this.height);
  final String text;
  final double x, y, width, height;
  factory OcrLine.fromJson(Map<String, dynamic> json) => OcrLine(
    json['text'] as String,
    (json['x'] as num).toDouble(),
    (json['y'] as num).toDouble(),
    (json['width'] as num).toDouble(),
    (json['height'] as num).toDouble(),
  );
  Map<String, dynamic> toJson() => {
    'text': text,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };
}

class ScanPage {
  const ScanPage({
    required this.id,
    required this.manualId,
    required this.image,
    required this.position,
    this.lines = const [],
    this.ocrStatus = 'pending',
  });
  final String id, manualId, image, ocrStatus;
  final int position;
  final List<OcrLine> lines;
  String get text => lines.map((line) => line.text).join('\n');
  factory ScanPage.fromRow(Map<String, Object?> row) => ScanPage(
    id: row['id'] as String,
    manualId: row['manual_id'] as String,
    image: row['image'] as String,
    position: row['position'] as int,
    ocrStatus: row['ocr_status'] as String,
    lines: (jsonDecode(row['lines'] as String) as List)
        .map((line) => OcrLine.fromJson(Map<String, dynamic>.from(line)))
        .toList(),
  );
}

class Manual {
  const Manual({
    required this.id,
    required this.title,
    required this.category,
    required this.createdAt,
    required this.status,
    this.pageCount = 0,
    this.searchablePages = 0,
    this.cover,
    this.matchSnippet,
    this.brand = '',
    this.modelNo = '',
    this.phone = '',
    this.purchasedAt,
    this.warrantyMonths,
  });
  final String id, title, category, status;
  final DateTime createdAt;
  final int pageCount, searchablePages;
  final String? cover, matchSnippet;
  final String brand, modelNo, phone;
  final DateTime? purchasedAt;
  final int? warrantyMonths;
  factory Manual.fromRow(Map<String, Object?> row) => Manual(
    id: row['id'] as String,
    title: row['title'] as String,
    category: row['category'] as String,
    status: row['status'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    pageCount: row['page_count'] as int? ?? 0,
    searchablePages: row['searchable_pages'] as int? ?? 0,
    cover: row['cover'] as String?,
    matchSnippet: row['match_snippet'] as String?,
    brand: row['brand'] as String? ?? '',
    modelNo: row['model'] as String? ?? '',
    phone: row['phone'] as String? ?? '',
    purchasedAt: row['purchased_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row['purchased_at'] as int),
    warrantyMonths: row['warranty_months'] as int?,
  );

  /// 保修截止日；未填购买日期或保修期返回 null。
  DateTime? get warrantyEnd {
    final months = warrantyMonths;
    final start = purchasedAt;
    if (start == null || months == null || months <= 0) {
      return null;
    }
    final total = start.month - 1 + months;
    return DateTime(start.year + total ~/ 12, total % 12 + 1, start.day);
  }

  /// 距保修截止的剩余天数（负数=已过保 N 天）；无保修信息返回 null。
  int? get warrantyDaysLeft => warrantyEnd?.difference(DateTime.now()).inDays;

  bool get hasWarrantyInfo => warrantyEnd != null;

  ///「品牌 型号」拼出来的副标题，空则返回空串。
  String get subtitle {
    final parts = [brand.trim(), modelNo.trim()].where((s) => s.isNotEmpty);
    return parts.join(' · ');
  }
}
