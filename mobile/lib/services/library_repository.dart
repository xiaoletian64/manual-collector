import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/manual.dart';

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
        version: 1,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE manuals (id TEXT PRIMARY KEY, title TEXT NOT NULL, category TEXT NOT NULL, created_at INTEGER NOT NULL, status TEXT NOT NULL)',
          );
          await db.execute(
            "CREATE TABLE pages (id TEXT PRIMARY KEY, manual_id TEXT NOT NULL REFERENCES manuals(id) ON DELETE CASCADE, image TEXT NOT NULL, position INTEGER NOT NULL, text TEXT NOT NULL DEFAULT '', lines TEXT NOT NULL DEFAULT '[]', ocr_status TEXT NOT NULL DEFAULT 'pending')",
          );
          await db.execute(
            'CREATE INDEX pages_manual ON pages(manual_id, position)',
          );
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
  }) async {
    // instr treats user input literally (including %, _ and quotes) and works with Chinese.
    final normalized = query.trim().toLowerCase();
    final rows = await db.rawQuery(
      '''
      SELECT m.*, (SELECT count(*) FROM pages WHERE manual_id=m.id) AS page_count,
      (SELECT count(*) FROM pages WHERE manual_id=m.id AND ocr_status='done' AND text!='') AS searchable_pages,
      (SELECT image FROM pages WHERE manual_id=m.id ORDER BY position LIMIT 1) AS cover,
      (SELECT text FROM pages WHERE manual_id=m.id AND instr(lower(text), ?) > 0 ORDER BY position LIMIT 1) AS match_snippet
      FROM manuals m WHERE status=? AND (? IS NULL OR category=?)
      AND (?='' OR instr(lower(title), ?) > 0 OR EXISTS
        (SELECT 1 FROM pages WHERE manual_id=m.id AND instr(lower(text), ?) > 0))
      ORDER BY created_at DESC
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

  Future<void> updateInfo(String id, String title, String category) async {
    await db.update(
      'manuals',
      {'title': title.trim(), 'category': category},
      where: 'id=?',
      whereArgs: [id],
    );
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
