import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class AppRelease {
  AppRelease(
    this.code,
    this.version,
    this.url,
    this.hash,
    this.size,
    this.notes,
  );
  final int code, size;
  final String version, hash, notes;
  final Uri url;
  factory AppRelease.parse(Map<String, dynamic> data, Uri endpoint) {
    final code = data['versionCode'];
    final size = data['size'];
    final hash = data['sha256'];
    final version = data['versionName'];
    final url = endpoint.resolve(data['apkUrl'] as String);
    if (data['packageName'] != 'com.manualcollector.manual_collector' ||
        code is! int ||
        code < 1 ||
        size is! int ||
        size < 1 ||
        size > 512 * 1024 * 1024 ||
        hash is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
        version is! String ||
        version.isEmpty ||
        url.origin != endpoint.origin ||
        url.userInfo.isNotEmpty ||
        !['http', 'https'].contains(url.scheme)) {
      throw const FormatException('更新清单无效');
    }
    return AppRelease(
      code,
      version,
      url,
      hash,
      size,
      data['notes'] as String? ?? '功能改进与问题修复',
    );
  }
}

class UpdateService {
  static const channel = MethodChannel('manual_collector/update');
  static final endpoint = Uri.parse(
    const String.fromEnvironment(
      'UPDATE_MANIFEST_URL',
      defaultValue:
          'http://124.222.88.195/manual-collector/android/latest.json',
    ),
  );
  HttpClient? _downloadClient;
  bool _cancelled = false;
  Future<Map<String, dynamic>> info() async =>
      Map<String, dynamic>.from(await channel.invokeMethod('info') as Map);

  Future<AppRelease> check({Uri? source}) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final uri = source ?? endpoint;
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 12));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      if (response.statusCode != 200) {
        throw HttpException('更新服务暂不可用 (${response.statusCode})');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 12))) {
        bytes.addAll(chunk);
        if (bytes.length > 65536) throw const FormatException('更新清单过大');
      }
      return AppRelease.parse(
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
        uri,
      );
    } finally {
      client.close(force: true);
    }
  }

  void cancel() {
    _cancelled = true;
    _downloadClient?.close(force: true);
  }

  Future<File> download(
    AppRelease release,
    void Function(double) progress, {
    Directory? directory,
  }) async {
    _cancelled = false;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    _downloadClient = client;
    final root = directory ?? await getTemporaryDirectory();
    final folder = await Directory(
      '${root.path}/updates',
    ).create(recursive: true);
    final partial = File('${folder.path}/update.apk.part');
    final output = File('${folder.path}/update.apk');
    IOSink? sink;
    try {
      final request = await client
          .getUrl(release.url)
          .timeout(const Duration(seconds: 20));
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode != 200) throw const HttpException('下载失败');
      if (response.contentLength >= 0 && response.contentLength != release.size) {
        throw const FormatException('安装包大小不符');
      }
      sink = partial.openWrite();
      var received = 0;
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        if (_cancelled) throw const HttpException('下载已取消');
        received += chunk.length;
        if (received > release.size) throw const FormatException('安装包大小不符');
        sink.add(chunk);
        await sink.flush();
        progress(received / release.size);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (_cancelled || received != release.size) {
        throw const FormatException('下载未完成');
      }
      if ((await sha256.bind(partial.openRead()).first).toString() !=
          release.hash) {
        throw const FormatException('安装包校验失败');
      }
      if (_cancelled) throw const HttpException('下载已取消');
      return await partial.rename(output.path);
    } finally {
      await sink?.close();
      client.close(force: true);
      _downloadClient = null;
      if (await partial.exists()) await partial.delete();
    }
  }

  Future<void> install(File apk, int code) =>
      channel.invokeMethod('install', {'path': apk.path, 'versionCode': code});
}
