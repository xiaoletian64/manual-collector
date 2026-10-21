import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manual_collector/services/update_service.dart';

void main() {
  final bytes = utf8.encode('test APK bytes');
  Map<String, dynamic> manifest() => {
    'packageName': 'com.manualcollector.manual_collector',
    'versionCode': 3,
    'versionName': '0.1.2',
    'size': bytes.length,
    'sha256': sha256.convert(bytes).toString(),
    'apkUrl': 'app.apk',
    'notes': 'test',
  };
  test(
    'reject wrong package, insecure cross-origin URL and invalid metadata',
    () {
      final endpoint = Uri.parse('https://updates.example/latest.json');
      expect(AppRelease.parse(manifest(), endpoint).code, 3);
      for (final replacement in [
        {'packageName': 'other'},
        {'apkUrl': 'http://updates.example/app.apk'},
        {'apkUrl': 'https://other.example/app.apk'},
        {'size': 0},
        {'sha256': 'bad'},
        {'versionCode': '3'},
      ]) {
        expect(
          () => AppRelease.parse({...manifest(), ...replacement}, endpoint),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'check and stream download; reject corrupt, truncated, redirected and missing updates',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final directory = await Directory.systemTemp.createTemp(
        'manual-ota-test',
      );
      var mode = 'ok';
      server.listen((request) async {
        if (request.uri.path == '/latest.json') {
          if (mode == 'missing') {
            request.response.statusCode = 404;
          } else {
            request.response.write(jsonEncode(manifest()));
          }
        } else if (mode == 'redirect') {
          request.response.statusCode = 302;
          request.response.headers.set('location', '/other.apk');
        } else {
          request.response.add(
            mode == 'corrupt'
                ? List.filled(bytes.length, 0)
                : mode == 'short'
                ? bytes.sublist(1)
                : bytes,
          );
        }
        await request.response.close();
      });
      try {
        final service = UpdateService();
        final release = await service.check(
          source: Uri.parse('http://127.0.0.1:${server.port}/latest.json'),
        );
        var progress = 0.0;
        final apk = await service.download(
          release,
          (value) => progress = value,
          directory: directory,
        );
        expect(await apk.readAsBytes(), bytes);
        expect(progress, 1);
        await apk.delete();
        for (final failure in ['corrupt', 'short', 'redirect']) {
          mode = failure;
          await expectLater(
            service.download(release, (_) {}, directory: directory),
            throwsA(isA<Exception>()),
          );
          expect(
            File('${directory.path}/updates/update.apk').existsSync(),
            false,
          );
          expect(
            File('${directory.path}/updates/update.apk.part').existsSync(),
            false,
          );
        }
        mode = 'ok';
        await expectLater(
          service.download(
            release,
            (_) => service.cancel(),
            directory: directory,
          ),
          throwsA(isA<Exception>()),
        );
        expect(
          File('${directory.path}/updates/update.apk').existsSync(),
          false,
        );
        mode = 'missing';
        await expectLater(
          service.check(
            source: Uri.parse('http://127.0.0.1:${server.port}/latest.json'),
          ),
          throwsA(isA<HttpException>()),
        );
      } finally {
        await server.close(force: true);
        await directory.delete(recursive: true);
      }
    },
  );
}
