import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/update_service.dart';

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});
  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  final _service = UpdateService();
  AppRelease? _release;
  File? _apk;
  bool _busy = false;
  double? _progress;
  String _current = '', _status = '';
  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) _check();
  }

  @override
  void dispose() {
    _service.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() {
      _busy = true;
      _status = '正在检查更新…';
      _release = null;
      _apk = null;
    });
    try {
      final info = await _service.info();
      if (mounted) {
        setState(
          () => _current = '${info['versionName']} (${info['versionCode']})',
        );
      }
      final release = await _service.check();
      if (!mounted) return;
      setState(() {
        _release = release.code > (info['versionCode'] as int) ? release : null;
        _status = _release == null ? '当前已是最新版本' : '发现新版本 ${release.version}';
      });
    } catch (_) {
      if (mounted) setState(() => _status = '暂时无法检查更新，请稍后重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _update() async {
    final release = _release!;
    setState(() {
      _busy = true;
      _status = '正在下载安装包…';
    });
    try {
      _apk ??= await _service.download(release, (value) {
        if (mounted) setState(() => _progress = value);
      });
      if (!mounted) return;
      await _service.install(_apk!, release.code);
      if (mounted) setState(() => _status = '请在系统安装窗口确认更新；取消后可再次安装。');
    } on PlatformException catch (e) {
      if (mounted) {
        setState(
          () => _status = e.code == 'permission'
              ? '请允许安装此来源的应用，返回后点击“安装更新”。'
              : e.message ?? '无法安装更新，请重试。',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _status = '下载未完成或校验失败，可重新下载。');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('软件更新')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          const Icon(Icons.system_update, size: 56),
          const SizedBox(height: 20),
          if (!Platform.isAndroid)
            const Text('iOS 版本通过 TestFlight 或 App Store 获取更新。'),
          if (Platform.isAndroid) ...[
            Text('当前版本：${_current.isEmpty ? '读取中' : _current}'),
            const SizedBox(height: 16),
            Text(_status),
            const SizedBox(height: 16),
            if (_release != null) ...[
              Text(_release!.notes),
              const SizedBox(height: 12),
              Text('安装包 ${(_release!.size / 1048576).toStringAsFixed(1)} MB'),
            ],
            if (_busy) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress),
            ],
            const SizedBox(height: 24),
            if (_release != null)
              FilledButton(
                onPressed: _busy ? null : _update,
                child: Text(_apk == null ? '下载并安装更新' : '安装更新'),
              ),
            TextButton(
              onPressed: _busy ? null : _check,
              child: const Text('检查更新'),
            ),
            if (_busy && _progress != null)
              TextButton(onPressed: _service.cancel, child: const Text('取消下载')),
            const SizedBox(height: 24),
            const Text('更新会保留本机说明书。无需卸载旧版本。'),
          ],
        ],
      ),
    ),
  );
}
