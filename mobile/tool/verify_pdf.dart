import 'dart:io';
import 'package:manual_collector/models/manual.dart';
import 'package:manual_collector/services/searchable_pdf.dart';

Future<void> main() async {
  await Directory('build/qa').create(recursive: true);
  await buildSearchablePdf(
    PdfJob(
      title: '说明书柜验证样本',
      pages: [
        const PdfInputPage('test/fixtures/manual.jpg', [
          OcrLine('电饭煲使用说明书', .08, .08, .6, .045),
          OcrLine('安全须知', .08, .20, .3, .03),
          OcrLine('清洁前请断开电源。', .08, .27, .7, .03),
          OcrLine('型号 Model C1 220V 50Hz', .08, .34, .75, .03),
        ]),
        const PdfInputPage('test/fixtures/landscape.jpg', [
          OcrLine('保修说明 WARRANTY', .08, .1, .6, .08),
        ]),
        const PdfInputPage('test/fixtures/manual.jpg', []),
      ],
      font: await File('assets/fonts/NotoSansSC-Regular.ttf').readAsBytes(),
      output: 'build/qa/searchable-manual.pdf',
    ),
  );
  stdout.writeln(
    'Created build/qa/searchable-manual.pdf (3 pages; third intentionally has no OCR)',
  );
}
