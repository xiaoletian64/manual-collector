import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manual_collector/models/manual.dart';
import 'package:manual_collector/screens/library_screen.dart';
import 'package:manual_collector/services/library_repository.dart';
import 'dart:io';
import 'package:sqflite/sqflite.dart';

class EmptyRepository extends LibraryRepository {
  EmptyRepository() : super(_UnusedDatabase(), Directory.systemTemp);
  @override
  Future<List<Manual>> list({
    String query = '',
    String? category,
    String status = 'ready',
    String sort = 'recent',
  }) async => [];
}

// No storage is touched in this UI check.
class _UnusedDatabase implements Database {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'empty library has a useful import action and honest search state',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: LibraryScreen(repository: EmptyRepository())),
      );
      await tester.pumpAndSettle();
      expect(find.text('从第一本说明书开始'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '安全');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('没有找到相关说明书'), findsOneWidget);
    },
  );
}
