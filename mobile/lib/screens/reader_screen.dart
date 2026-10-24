import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/manual.dart';
import 'detail_screen.dart';
import '../services/library_repository.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.repository,
    required this.manual,
    this.initialQuery = '',
  });
  final LibraryRepository repository;
  final Manual manual;
  final String initialQuery;
  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _controller = PdfViewerController();
  late final _documentRef = PdfDocumentRefFile(
    widget.repository.pdfPath(widget.manual.id),
  );
  PdfTextSearcher? _searcher;
  late final _query = TextEditingController(text: widget.initialQuery);
  late String _title = widget.manual.title;
  List<ScanPage> _pages = [];
  int _page = 1;
  bool _ready = false, _sharing = false;
  String? _error;

  Future<void> _openArchive() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManualDetailScreen(
          repository: widget.repository,
          manualId: widget.manual.id,
        ),
      ),
    );
    if (mounted) {
      final fresh = await widget.repository.get(widget.manual.id);
      setState(() => _title = fresh.title);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final pages = await widget.repository.pages(widget.manual.id);
      if (!await File(widget.repository.pdfPath(widget.manual.id)).exists()) {
        throw StateError('missing pdf');
      }
      if (mounted) {
        setState(() => _pages = pages);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = '无法读取 PDF，原始页面仍保留在本机。');
      }
    }
  }

  void _changed() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searcher?.removeListener(_changed);
    _searcher?.dispose();
    _query.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('保存 PDF'), subtitle: Text(_title)),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('保存到本地 / 文件库'),
              subtitle: const Text('选择文件夹，或系统文件中已接入的网盘'),
              onTap: () => Navigator.pop(context, 'save'),
            ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('发送到网盘或其他应用'),
              subtitle: const Text('通过目标应用继续保存或上传'),
              onTap: () => Navigator.pop(context, 'share'),
            ),
          ],
        ),
      ),
    );
    if (action != null && mounted) await _share(saveToFiles: action == 'save');
  }

  Future<void> _share({bool saveToFiles = false}) async {
    if (_sharing) {
      return;
    }
    setState(() => _sharing = true);
    try {
      final box = context.findRenderObject() as RenderBox?;
      final safeName = _title.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_');
      final temporary = await getTemporaryDirectory();
      final exportDirectory = await temporary.createTemp('manual-export-');
      final exportFile = await File(
        widget.repository.pdfPath(widget.manual.id),
      ).copy(p.join(exportDirectory.path, '$safeName.pdf'));
      if (saveToFiles) {
        final saved = await const MethodChannel(
          'manual_collector/export',
        ).invokeMethod<bool>('savePdf', {'path': exportFile.path});
        if (mounted && saved == true) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('PDF 已保存到所选位置')));
        }
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(exportFile.path, mimeType: 'application/pdf')],
          fileNameOverrides: ['$safeName.pdf'],
          subject: _title,
          sharePositionOrigin: box == null
              ? const Rect.fromLTWH(0, 0, 100, 100)
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('导出失败，请重试')));
      }
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
      }
    }
  }

  Future<void> _edit() async {
    final name = TextEditingController(text: _title);
    var category = (await widget.repository.get(widget.manual.id)).category;
    if (!mounted) {
      name.dispose();
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('编辑资料'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: '产品名称 / 型号'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: '分类'),
                  items: categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => category = value ?? category),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isNotEmpty) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    final newTitle = name.text.trim();
    // Controller remains alive until the dialog's closing animation is finished.
    if (accepted == true) {
      try {
        await widget.repository.updateInfo(
          widget.manual.id,
          newTitle,
          category,
        );
        if (mounted) {
          setState(() => _title = newTitle);
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('修改未保存，请重试')));
        }
      }
    }
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这本说明书？'),
        content: const Text('扫描图片、识别文字和本机 PDF 都会删除。请先导出需要保留的副本。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (yes == true) {
      try {
        await widget.repository.delete(widget.manual.id);
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('删除未完成，请返回书柜检查')));
        }
      }
    }
  }

  void _showText() {
    if (_pages.isEmpty) {
      return;
    }
    final page = _pages[(_page - 1).clamp(0, _pages.length - 1)];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '第 $_page 页 · 识别文字',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text('可长按复制；参数和安全信息请核对扫描原图。'),
                const Divider(height: 32),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      page.text.isEmpty ? '此页没有识别文字，仍可阅读原图。' : page.text,
                      style: const TextStyle(height: 1.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_title),
      actions: [
        IconButton(
          tooltip: '导出 PDF',
          onPressed: _sharing ? null : _export,
          icon: const Icon(Icons.ios_share),
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _edit();
            } else if (value == 'archive') {
              _openArchive();
            } else {
              _delete();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'archive', child: Text('产品档案')),
            PopupMenuItem(value: 'edit', child: Text('修改名称和分类')),
            PopupMenuItem(value: 'delete', child: Text('删除说明书')),
          ],
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _query,
            enabled: _ready,
            decoration: InputDecoration(
              hintText: '在这本 PDF 中查找',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清空查找',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _query.clear();
                        _searcher?.startTextSearch('');
                      },
                    ),
            ),
            onChanged: (text) {
              setState(() {});
              _searcher?.startTextSearch(text.trim());
            },
          ),
        ),
        if (_query.text.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    (_searcher?.isSearching ?? false)
                        ? '正在查找…'
                        : (_searcher?.matches.isEmpty ?? true)
                        ? '未找到匹配文字'
                        : '${(_searcher?.currentIndex ?? 0) + 1} / ${_searcher?.matches.length ?? 0} 处匹配',
                  ),
                ),
                IconButton(
                  tooltip: '上一个结果',
                  onPressed: (_searcher?.hasMatches ?? false)
                      ? () => _searcher?.goToPrevMatch()
                      : null,
                  icon: const Icon(Icons.keyboard_arrow_up),
                ),
                IconButton(
                  tooltip: '下一个结果',
                  onPressed: (_searcher?.hasMatches ?? false)
                      ? () => _searcher?.goToNextMatch()
                      : null,
                  icon: const Icon(Icons.keyboard_arrow_down),
                ),
              ],
            ),
          ),
        Expanded(
          child: _error != null
              ? Center(child: Text(_error!))
              : PdfViewer(
                  _documentRef,
                  controller: _controller,
                  params: PdfViewerParams(
                    backgroundColor: const Color(0xFFE8E8E2),
                    onViewerReady: (document, controller) {
                      if (!mounted) return;
                      _searcher?.removeListener(_changed);
                      _searcher?.dispose();
                      _searcher = PdfTextSearcher(controller)
                        ..addListener(_changed);
                      setState(() => _ready = true);
                      if (_query.text.isNotEmpty) {
                        _searcher?.startTextSearch(_query.text.trim());
                      }
                    },
                    onPageChanged: (page) {
                      if (page != null && mounted) {
                        setState(() => _page = page);
                      }
                    },
                    pagePaintCallbacks: [
                      if (_searcher != null)
                        _searcher!.pageTextMatchPaintCallback,
                    ],
                  ),
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: '上一页',
                  onPressed: _ready && _page > 1
                      ? () => _controller.goToPage(pageNumber: _page - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('$_page / ${_pages.length} 页'),
                IconButton(
                  tooltip: '下一页',
                  onPressed: _ready && _page < _pages.length
                      ? () => _controller.goToPage(pageNumber: _page + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _pages.isEmpty ? null : _showText,
                  icon: const Icon(Icons.text_snippet_outlined),
                  label: const Text('文字'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
