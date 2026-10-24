import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/manual.dart';

/// 平台通道：拨号等原生小能力。
const platform = MethodChannel('manual_collector/ui');

class LibraryRepository {
  LibraryRepository(this.db, this.root);
  final Database db;
  final Directory root;
  static Future<LibraryRepository> open({
    Directory? directory,
    DatabaseFactory? factory,
  }) async {
    final root =
        directory ??
        Directory(
          p.join((await getApplicationDocumentsDirectory()).path, 'manuals'),
        );
    await root.create(recursive: true);
    final db = await (factory ?? databaseFactory).openDatabase(
      p.join(root.path, 'library.db'),
      options: OpenDatabaseOptions(
        version: 2,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE manuals (id TEXT PRIMARY KEY, title TEXT NOT NULL, category TEXT NOT NULL, created_at INTEGER NOT NULL, status TEXT NOT NULL, brand TEXT NOT NULL DEFAULT \'\', model TEXT NOT NULL DEFAULT \'\', purchased_at INTEGER, warranty_months INTEGER, phone TEXT NOT NULL DEFAULT \'\')',
          );
          await db.execute(
            "CREATE TABLE pages (id TEXT PRIMARY KEY, manual_id TEXT NOT NULL REFERENCES manuals(id) ON DELETE CASCADE, image TEXT NOT NULL, position INTEGER NOT NULL, text TEXT NOT NULL DEFAULT '', lines TEXT NOT NULL DEFAULT '[]', ocr_status TEXT NOT NULL DEFAULT 'pending')",
          );
          await db.execute(
            'CREATE INDEX pages_manual ON pages(manual_id, position)',
          );
        },
        onUpgrade: (db, from, to) async {
          if (from < 2) {
            await db.execute(
              "ALTER TABLE manuals ADD COLUMN brand TEXT NOT NULL DEFAULT ''",
            );
            await db.execute(
              "ALTER TABLE manuals ADD COLUMN model TEXT NOT NULL DEFAULT ''",
            );
            await db.execute(
              'ALTER TABLE manuals ADD COLUMN purchased_at INTEGER',
            );
            await db.execute(
              'ALTER TABLE manuals ADD COLUMN warranty_months INTEGER',
            );
            await db.execute(
              "ALTER TABLE manuals ADD COLUMN phone TEXT NOT NULL DEFAULT ''",
            );
          }
        },
      ),
    );
    return LibraryRepository(db, root);
  }

  String path(String relative) => p.join(root.path, relative);
  String pdfPath(String id) => path('$id/manual.pdf');

  Future<List<Manual>> list({
    String query = '',
    String? category,
    String status = 'ready',
    String sort = 'recent',
  }) async {
    // instr treats user input literally (including %, _ and quotes) and works with Chinese.
    final normalized = query.trim().toLowerCase();
    final orderBy = switch (sort) {
      // SQLite 没有现成的"剩余天数"，按(有保修且未过保)在前、截止日升序排；
      // 无保修信息的排最后，再按创建时间兜底。
      'warranty' =>
        'ORDER BY CASE WHEN m.purchased_at IS NULL OR m.warranty_months IS NULL THEN 1 ELSE 0 END,'
            ' m.purchased_at + m.warranty_months * 30.44 * 86400000 ASC, m.created_at DESC',
      'name' => 'ORDER BY m.title COLLATE NOCASE ASC',
      _ => 'ORDER BY m.created_at DESC',
    };
    final rows = await db.rawQuery(
      '''
      SELECT m.*, (SELECT count(*) FROM pages WHERE manual_id=m.id) AS page_count,
      (SELECT count(*) FROM pages WHERE manual_id=m.id AND ocr_status='done' AND text!='') AS searchable_pages,
      (SELECT image FROM pages WHERE manual_id=m.id ORDER BY position LIMIT 1) AS cover,
      (SELECT text FROM pages WHERE manual_id=m.id AND instr(lower(text), ?) > 0 ORDER BY position LIMIT 1) AS match_snippet
      FROM manuals m WHERE status=? AND (? IS NULL OR category=?)
      AND (?='' OR instr(lower(title), ?) > 0 OR EXISTS
        (SELECT 1 FROM pages WHERE manual_id=m.id AND instr(lower(text), ?) > 0))
      $orderBy
    ''',
      [
        normalized,
        status,
        category,
        category,
        normalized,
        normalized,
        normalized,
      ],
    );
    return rows.map(Manual.fromRow).toList();
  }

  /// 我的页统计。
  Future<Map<String, int>> stats() async {
    final row = (await db.rawQuery(
      '''
      SELECT
        (SELECT count(*) FROM manuals WHERE status='ready') AS manuals,
        (SELECT count(*) FROM pages p JOIN manuals m ON p.manual_id=m.id WHERE m.status='ready') AS pages,
        (SELECT count(*) FROM pages p JOIN manuals m ON p.manual_id=m.id WHERE m.status='ready' AND p.ocr_status='done' AND p.text!='') AS searchable,
        (SELECT count(*) FROM manuals WHERE status='ready' AND purchased_at IS NOT NULL AND warranty_months IS NOT NULL
           AND purchased_at + warranty_months * 30.44 * 86400000 > ?
           AND purchased_at + warranty_months * 30.44 * 86400000 < ? + 90 * 86400000) AS warrantySoon
    ''',
      [
        DateTime.now().millisecondsSinceEpoch,
        DateTime.now().millisecondsSinceEpoch,
      ],
    )).single;
    return {
      'manuals': row['manuals'] as int? ?? 0,
      'pages': row['pages'] as int? ?? 0,
      'searchable': row['searchable'] as int? ?? 0,
      'warrantySoon': row['warrantySoon'] as int? ?? 0,
    };
  }

  Future<Manual> get(String id) async {
    final row = (await db.query(
      'manuals',
      where: 'id=?',
      whereArgs: [id],
    )).single;
    return Manual.fromRow(row);
  }

  Future<Manual> createDraft() async {
    final id = const Uuid().v4();
    await Directory(path(id)).create(recursive: true);
    await db.insert('manuals', {
      'id': id,
      'title': '',
      'category': '未分类',
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'status': 'draft',
    });
    return get(id);
  }

  Future<List<ScanPage>> pages(String id) async => (await db.query(
    'pages',
    where: 'manual_id=?',
    whereArgs: [id],
    orderBy: 'position',
  )).map(ScanPage.fromRow).toList();

  Future<void> addPage(String manualId, String pageId, List<int> bytes) async {
    final relative = '$manualId/$pageId.jpg';
    await File(path(relative)).writeAsBytes(bytes, flush: true);
    try {
      final rows = await pages(manualId);
      await db.insert('pages', {
        'id': pageId,
        'manual_id': manualId,
        'image': relative,
        'position': rows.length,
      });
    } catch (_) {
      await File(path(relative)).delete();
      rethrow;
    }
  }

  Future<void> setOcr(String id, List<OcrLine> lines, String status) async {
    await db.update(
      'pages',
      {
        'lines': jsonEncode(lines.map((l) => l.toJson()).toList()),
        'text': lines.map((l) => l.text).join('\n'),
        'ocr_status': status,
      },
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<void> reorder(List<ScanPage> pages) async {
    await db.transaction((tx) async {
      for (var i = 0; i < pages.length; i++) {
        await tx.update(
          'pages',
          {'position': i},
          where: 'id=?',
          whereArgs: [pages[i].id],
        );
      }
    });
  }

  Future<void> removePage(ScanPage page) async {
    await db.delete('pages', where: 'id=?', whereArgs: [page.id]);
    await reorder(await pages(page.manualId));
    final file = File(path(page.image));
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> updateInfo(
    String id,
    String title,
    String category, {
    bool keepArchive = false,
  }) async {
    await db.update(
      'manuals',
      {'title': title.trim(), 'category': category},
      where: 'id=?',
      whereArgs: [id],
    );
  }

  /// 产品档案完整保存（阅读器「修改名称和分类」走 updateInfo，不碰档案字段）。
  Future<void> updateArchive({
    required String id,
    required String title,
    required String category,
    required String brand,
    required String modelNo,
    required String phone,
    DateTime? purchasedAt,
    int? warrantyMonths,
  }) async {
    await db.update(
      'manuals',
      {
        'title': title.trim(),
        'category': category,
        'brand': brand,
        'model': modelNo,
        'phone': phone,
        'purchased_at': purchasedAt?.millisecondsSinceEpoch,
        'warranty_months': warrantyMonths,
      },
      where: 'id=?',
      whereArgs: [id],
    );
  }

  /// 拨打售后电话（无电话应用时静默失败）。
  Future<void> dial(String phone) async {
    try {
      await platform.invokeMethod('dial', {'phone': phone});
    } catch (_) {}
  }

  Future<void> publish(String id) async {
    if (!(await File(pdfPath(id)).exists()) || (await pages(id)).isEmpty) {
      throw StateError('PDF 尚未生成，草稿已保留');
    }
    await db.update(
      'manuals',
      {'status': 'ready'},
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<void> delete(String id) async {
    await db.delete('manuals', where: 'id=?', whereArgs: [id]);
    final folder = Directory(path(id));
    if (await folder.exists()) {
      await folder.delete(recursive: true);
    }
  }

  Future<void> close() => db.close();
}
