import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:manual_collector/models/manual.dart';
import 'package:manual_collector/services/library_repository.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late LibraryRepository repository;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('manual-test-');
    repository = await LibraryRepository.open(
      directory: directory,
      factory: databaseFactoryFfi,
    );
  });
  tearDown(() async {
    await repository.close();
    await directory.delete(recursive: true);
  });
  test(
    'draft, ordering, Chinese search and PDF survive database reopen',
    () async {
      final manual = await repository.createDraft();
      await repository.addPage(manual.id, 'page-1', [1, 2, 3]);
      await repository.addPage(manual.id, 'page-2', [4, 5, 6]);
      await repository.setOcr('page-2', [
        const OcrLine('清洁前请断开电源 100% A_B', .1, .2, .6, .1),
      ], 'done');
      await repository.updateInfo(manual.id, '电饭煲 C1', '厨电');
      expect(await repository.list(), isEmpty);
      expect((await repository.list(status: 'draft')).single.pageCount, 2);
      await repository.reorder(
        (await repository.pages(manual.id)).reversed.toList(),
      );
      await File(repository.pdfPath(manual.id)).writeAsString('%PDF-1.7');
      await repository.publish(manual.id);
      await repository.close();
      repository = await LibraryRepository.open(
        directory: directory,
        factory: databaseFactoryFfi,
      );
      expect((await repository.pages(manual.id)).first.id, 'page-2');
      expect((await repository.list(query: '断开电源')).single.title, '电饭煲 C1');
      expect((await repository.list(query: 'c1')).single.searchablePages, 1);
      expect(await repository.list(query: 'unknown'), isEmpty);
      expect(await repository.list(category: '数码'), isEmpty);
      expect((await repository.list(query: '100%')).length, 1);
      expect(await repository.list(query: '%unknown'), isEmpty);
      await repository.removePage((await repository.pages(manual.id)).last);
      expect((await repository.pages(manual.id)).single.position, 0);
      await repository.delete(manual.id);
      expect(await repository.list(), isEmpty);
      expect(await repository.pages(manual.id), isEmpty);
      expect(Directory(repository.path(manual.id)).existsSync(), false);
    },
  );
  test(
    'cannot publish without pages and PDF; original draft remains',
    () async {
      final manual = await repository.createDraft();
      await expectLater(repository.publish(manual.id), throwsStateError);
      expect((await repository.list(status: 'draft')).single.id, manual.id);
    },
  );
}
