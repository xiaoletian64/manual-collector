import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import '../models/manual.dart';

class PdfInputPage {
  const PdfInputPage(this.path, this.lines);
  final String path;
  final List<OcrLine> lines;
}

class PdfJob {
  const PdfJob({
    required this.title,
    required this.pages,
    required this.font,
    required this.output,
  });
  final String title, output;
  final List<PdfInputPage> pages;
  final Uint8List font;
}

// Executed in an isolate. Render mode 3 preserves the original scan and makes
// Unicode text selectable/searchable in ordinary PDF readers, not only this app.
Future<String> buildSearchablePdf(PdfJob job) async {
  if (job.pages.isEmpty) {
    throw StateError('请先添加说明书页面');
  }
  final doc = PdfDocument();
  PdfInfo(doc, title: job.title, creator: '说明书柜', subject: '扫描原图与 OCR 文字层');
  final font = PdfTtfFont(doc, ByteData.sublistView(job.font));
  for (final input in job.pages) {
    final image = PdfImage.jpeg(
      doc,
      image: await File(input.path).readAsBytes(),
    );
    // Keep the scan's aspect ratio, including landscape pages.
    final scale =
        842.0 / (image.width > image.height ? image.width : image.height);
    final width = image.width * scale;
    final height = image.height * scale;
    final page = PdfPage(
      doc,
      pageFormat: PdfPageFormat(width, height, marginAll: 0),
    );
    final canvas = page.getGraphics();
    canvas.drawImage(image, 0, 0, width, height);
    for (final line in input.lines) {
      final text = line.text.replaceAll(RegExp(r'[\x00-\x1F]'), ' ').trim();
      if (text.isEmpty ||
          !line.x.isFinite ||
          !line.y.isFinite ||
          !line.width.isFinite ||
          !line.height.isFinite ||
          line.width <= 0 ||
          line.height <= 0) {
        continue;
      }
      final left = line.x.clamp(0.0, 1.0) * width;
      final top = line.y.clamp(0.0, 1.0) * height;
      final boxWidth = (line.width * width).clamp(0.1, width - left + 0.1);
      final boxHeight = (line.height * height).clamp(0.1, height - top + 0.1);
      // Font ascent/descent maps the line bounds to the PDF baseline.
      final fontSize = boxHeight / (font.ascent - font.descent);
      final advance = font.stringMetrics(text).advanceWidth * fontSize;
      if (advance <= 0) {
        continue;
      }
      canvas.drawString(
        font,
        fontSize,
        text,
        left,
        height - top - font.ascent * fontSize,
        scale: boxWidth / advance,
        mode: PdfTextRenderingMode.invisible,
      );
    }
  }
  final temporary = File('${job.output}.tmp');
  await temporary.writeAsBytes(await doc.save(), flush: true);
  await temporary.rename(job.output);
  return job.output;
}
