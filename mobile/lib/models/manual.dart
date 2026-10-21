import 'dart:convert';

const categories = ['未分类', '家电', '数码', '厨电', '工具', '汽车', '其他'];

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
  });
  final String id, title, category, status;
  final DateTime createdAt;
  final int pageCount, searchablePages;
  final String? cover, matchSnippet;
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
  );
}
