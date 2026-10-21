import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:manual_collector/services/library_repository.dart';
import 'package:manual_collector/services/image_service.dart';
import 'package:manual_collector/services/ocr_service.dart';
import 'package:manual_collector/services/searchable_pdf.dart';
import 'package:manual_collector/screens/library_screen.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native Chinese OCR -> searchable PDF -> persistent library -> reader',
    (tester) async {
      final root = await Directory.systemTemp.createTemp('manual-integration-');
      var repository = await LibraryRepository.open(directory: root);
      final manual = await repository.createDraft();
      final fontLoader = FontLoader('TestChinese')
        ..addFont(rootBundle.load('assets/fonts/NotoSansSC-Regular.ttf'));
      await fontLoader.load();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..drawColor(Colors.white, BlendMode.src);
      final painter = TextPainter(
        text: const TextSpan(
          text: '电饭煲使用说明书\n\n安全须知\n\n清洁前请断开电源\n\nModel C1 220V 50Hz',
          style: TextStyle(
            fontFamily: 'TestChinese',
            color: Colors.black,
            fontSize: 54,
            height: 1.6,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 1080);
      painter.paint(canvas, const Offset(60, 80));
      final picture = recorder.endRecording();
      final image = await picture.toImage(1200, 1600);
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await repository.addPage(
        manual.id,
        'page-1',
        normalizeImage(png.buffer.asUint8List()),
      );
      image.dispose();
      picture.dispose();
      painter.dispose();
      final page = (await repository.pages(manual.id)).single;
      final lines = await OcrService().recognize(repository.path(page.image));
      final text = lines.map((l) => l.text).join('\n');
      expect(text, contains('安全'));
      expect(text, contains('电源'));
      await repository.setOcr(page.id, lines, 'done');
      await repository.updateInfo(manual.id, '电饭煲 C1', '厨电');
      await buildSearchablePdf(
        PdfJob(
          title: '电饭煲 C1',
          pages: [PdfInputPage(repository.path(page.image), lines)],
          font: (await rootBundle.load(
            'assets/fonts/NotoSansSC-Regular.ttf',
          )).buffer.asUint8List(),
          output: repository.pdfPath(manual.id),
        ),
      );
      await repository.publish(manual.id);
      await repository.close();
      repository = await LibraryRepository.open(directory: root);
      expect((await repository.list(query: '电源')).single.title, '电饭煲 C1');
      await pdfrxFlutterInitialize();
      final pdf = await PdfDocument.openFile(repository.pdfPath(manual.id));
      final extracted = await pdf.pages.first.loadText();
      expect(extracted!.fullText, contains('电源'));
      expect(pdf.pages.length, 1);
      await pdf.dispose();
      await tester.pumpWidget(
        MaterialApp(home: LibraryScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      expect(find.text('电饭煲 C1'), findsOneWidget);
      await tester.tap(find.text('电饭煲 C1'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byType(PdfViewer), findsOneWidget);
      expect(find.text('1 / 1 页'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '电源');
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.textContaining('处匹配'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await repository.close();
      await root.delete(recursive: true);
    },
  );
}
