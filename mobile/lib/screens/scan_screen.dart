import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/manual.dart';
import '../services/library_repository.dart';
import '../services/ocr_service.dart';
import '../services/image_service.dart';
import '../services/searchable_pdf.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.repository, required this.manual});
  final LibraryRepository repository;
  final Manual manual;
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late final _title = TextEditingController(text: widget.manual.title);
  late String _category = widget.manual.category;
  List<ScanPage> _pages = [];
  bool _busy = true;
  String _progress = '读取草稿…';
  final _picker = ImagePicker();
  final _ocr = OcrService();
  LibraryRepository get repo => widget.repository;
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _notice(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _initialize() async {
    try {
      await _refresh();
      if (Platform.isAndroid) {
        final recovered = await _picker.retrieveLostData();
        if (recovered.files?.isNotEmpty == true) {
          await _import(recovered.files!);
        }
        if (recovered.exception != null) {
          _notice('上次选图未完成，请重新导入');
        }
      }
    } catch (_) {
      _notice('草稿读取失败，请返回后重试');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _refresh() async {
    final pages = await repo.pages(widget.manual.id);
    if (mounted) {
      setState(() => _pages = pages);
    }
  }

  Future<void> _persistInfo() =>
      repo.updateInfo(widget.manual.id, _title.text, _category);
  Future<void> _run(String label, Future<void> Function() action) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _progress = label;
    });
    try {
      await action();
    } on PlatformException catch (e) {
      _notice(switch (e.code) {
        'camera_access_denied' => '相机权限未开启，请在系统设置中允许访问相机',
        'photo_access_denied' => '相册权限未开启，请在系统设置中允许访问照片',
        _ => e.message ?? '操作失败，请检查权限后重试',
      });
    } catch (_) {
      _notice('操作未完成，已导入的页面仍在草稿中。请检查图片和存储空间后重试。');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _pick(bool camera) =>
      _run(camera ? '等待拍照…' : '等待选择图片…', () async {
        await _persistInfo();
        if (_pages.length >= 100) {
          _notice('每本最多 100 页，请分册保存');
          return;
        }
        final List<XFile> files;
        if (camera) {
          final image = await _picker.pickImage(
            source: ImageSource.camera,
            maxWidth: 2600,
            maxHeight: 2600,
            imageQuality: 95,
          );
          files = image == null ? [] : [image];
        } else {
          files = await _picker.pickMultiImage(
            maxWidth: 2600,
            maxHeight: 2600,
            imageQuality: 95,
            requestFullMetadata: false,
          );
        }
        await _import(files);
      });
  Future<void> _import(List<XFile> files) async {
    final remaining = 100 - _pages.length;
    if (files.length > remaining) {
      _notice('每本最多 100 页，本次仅导入前 $remaining 张');
    }
    var failed = 0;
    for (var i = 0; i < files.length && i < remaining; i++) {
      if (mounted) {
        setState(
          () => _progress =
              '正在保存第 ${i + 1} / ${files.length.clamp(0, remaining)} 张…',
        );
      }
      try {
        final bytes = await compute(
          normalizeImage,
          await files[i].readAsBytes(),
        );
        await repo.addPage(widget.manual.id, const Uuid().v4(), bytes);
      } catch (_) {
        failed++;
      }
    }
    await _refresh();
    if (failed > 0) {
      _notice('$failed 张图片无法导入，请选择 JPG/PNG 或重新拍摄');
    }
  }

  Future<void> _rotate(ScanPage page) => _run('正在旋转页面…', () async {
    final file = File(repo.path(page.image));
    final bytes = await compute(rotateImage, await file.readAsBytes());
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsBytes(bytes, flush: true);
    // Invalidate OCR before replacing pixels, so interrupted edits cannot export stale coordinates.
    await repo.setOcr(page.id, [], 'pending');
    await temporary.rename(file.path);
    await FileImage(file).evict();
    await ResizeImage.resizeIfNeeded(250, null, FileImage(file)).evict();
    await _refresh();
  });
  Future<void> _move(int index, int offset) => _run('保存页面顺序…', () async {
    final pages = [..._pages];
    final page = pages.removeAt(index);
    pages.insert(index + offset, page);
    await repo.reorder(pages);
    await _refresh();
  });
  Future<void> _recognize() async {
    final pending = _pages.where((p) => p.ocrStatus != 'done').toList();
    for (var i = 0; i < pending.length; i++) {
      final page = pending[i];
      if (mounted) {
        setState(() => _progress = '本机文字识别 ${i + 1} / ${pending.length}…');
      }
      try {
        final lines = await _ocr.recognize(repo.path(page.image));
        await repo.setOcr(page.id, lines, lines.isEmpty ? 'empty' : 'done');
      } catch (_) {
        await repo.setOcr(page.id, [], 'failed');
      }
    }
    await _refresh();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      _notice('请填写产品名称或型号，方便以后查找');
      return;
    }
    if (_pages.isEmpty) {
      _notice('请先拍照或导入图片');
      return;
    }
    await _run('保存草稿…', () async {
      await _persistInfo();
      await _recognize();
      final unavailable = _pages.where((p) => p.text.trim().isEmpty).length;
      if (unavailable > 0 && mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('$unavailable 页未识别到文字'),
            content: const Text(
              '这些页面会完整保留在 PDF 中，但无法搜索其中的文字。可以返回检查、旋转或补拍，也可以先保存原图。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('返回检查'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('仍然保存'),
              ),
            ],
          ),
        );
        if (proceed != true) {
          return;
        }
      }
      if (mounted) {
        setState(() => _progress = '正在生成可搜索 PDF…');
      }
      final font = await rootBundle.load('assets/fonts/NotoSansSC-Regular.ttf');
      await compute(
        buildSearchablePdf,
        PdfJob(
          title: _title.text.trim(),
          pages: _pages
              .map((p) => PdfInputPage(repo.path(p.image), p.lines))
              .toList(),
          font: font.buffer.asUint8List(font.offsetInBytes, font.lengthInBytes),
          output: repo.pdfPath(widget.manual.id),
        ),
      );
      await repo.publish(widget.manual.id);
      final manual = await repo.get(widget.manual.id);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(manual);
    });
  }

  Future<void> _discard() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这份草稿？'),
        content: const Text('已导入的页面将从本机删除，无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('保留'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除草稿'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await _run('删除草稿…', () async {
        await repo.delete(widget.manual.id);
        if (mounted) {
          Navigator.pop(context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('整理说明书'),
          actions: [
            IconButton(
              tooltip: '删除草稿',
              onPressed: _busy ? null : _discard,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_busy) ...[
              const LinearProgressIndicator(),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_progress),
              ),
            ],
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  TextField(
                    controller: _title,
                    enabled: !_busy,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: '产品名称 / 型号',
                      hintText: '例如：米家电饭煲 C1',
                    ),
                    onChanged: (_) => _persistInfo().catchError((Object _) {
                      _notice('名称未保存，请重试');
                    }),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: '分类'),
                    items: categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _category = value);
                              _persistInfo().catchError((Object _) {
                                _notice('分类未保存，请重试');
                              });
                            }
                          },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _pick(true),
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('拍摄一页'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _pick(false),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('导入图片'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '${_pages.length} 页 · 按阅读顺序排列',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '页面自动保存为草稿。拍摄时铺平纸张、避开反光，让文字尽量占满画面。',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  if (_pages.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 64,
                            color: colors.outline,
                          ),
                          const SizedBox(height: 16),
                          const Text('先添加封面，再按顺序添加内页'),
                        ],
                      ),
                    ),
                  ..._pages.asMap().entries.map((entry) {
                    final i = entry.key;
                    final page = entry.value;
                    final status = switch (page.ocrStatus) {
                      'done' => '已识别 ${page.text.length} 字',
                      'empty' => '未识别到文字 · 可补拍或重试',
                      'failed' => '识别失败 · 可重试',
                      _ => '待识别',
                    };
                    return Card(
                      margin: const EdgeInsets.only(top: 12),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                InkWell(
                                  onTap: _busy
                                      ? null
                                      : () => showDialog(
                                          context: context,
                                          builder: (_) => Dialog.fullscreen(
                                            child: Scaffold(
                                              appBar: AppBar(
                                                title: Text('第 ${i + 1} 页'),
                                              ),
                                              body: Center(
                                                child: InteractiveViewer(
                                                  maxScale: 6,
                                                  child: Image.file(
                                                    File(repo.path(page.image)),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      File(repo.path(page.image)),
                                      width: 72,
                                      height: 96,
                                      fit: BoxFit.cover,
                                      cacheWidth: 250,
                                      errorBuilder: (_, _, _) => const SizedBox(
                                        width: 72,
                                        height: 96,
                                        child: Icon(Icons.broken_image),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '第 ${i + 1} 页',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: page.ocrStatus == 'done'
                                              ? colors.primary
                                              : colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: '删除第 ${i + 1} 页',
                                  onPressed: _busy
                                      ? null
                                      : () => _run('删除页面…', () async {
                                          await repo.removePage(page);
                                          await _refresh();
                                        }),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  tooltip: '前移',
                                  onPressed: _busy || i == 0
                                      ? null
                                      : () => _move(i, -1),
                                  icon: const Icon(Icons.arrow_upward),
                                ),
                                IconButton(
                                  tooltip: '后移',
                                  onPressed: _busy || i == _pages.length - 1
                                      ? null
                                      : () => _move(i, 1),
                                  icon: const Icon(Icons.arrow_downward),
                                ),
                                TextButton.icon(
                                  onPressed: _busy ? null : () => _rotate(page),
                                  icon: const Icon(Icons.rotate_right),
                                  label: const Text('旋转'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (_pages.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run('开始文字识别…', _recognize),
                        icon: const Icon(Icons.text_snippet_outlined),
                        label: const Text('识别 / 重试未识别页面'),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy || _pages.isEmpty ? null : _save,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('生成 PDF 并存入书柜'),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
