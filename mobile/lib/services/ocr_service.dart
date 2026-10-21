import 'package:flutter/services.dart';
import '../models/manual.dart';

class OcrService {
  static const channel = MethodChannel('manual_collector/ocr');
  Future<List<OcrLine>> recognize(String path) async {
    final result = await channel.invokeListMethod<dynamic>('recognize', {
      'path': path,
    });
    return (result ?? [])
        .map((item) => OcrLine.fromJson(Map<String, dynamic>.from(item as Map)))
        .where(
          (line) =>
              line.text.trim().isNotEmpty && line.width > 0 && line.height > 0,
        )
        .toList();
  }
}
