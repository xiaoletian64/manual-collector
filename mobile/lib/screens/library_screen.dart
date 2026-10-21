import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/manual.dart';
import '../services/library_repository.dart';
import '../services/update_service.dart';
import 'scan_screen.dart';
import 'reader_screen.dart';
import 'update_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.repository});
  final LibraryRepository repository;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Manual> _manuals = [], _drafts = [];
  String? _category, _error;
  bool _loading = true, _opening = false;
  int _generation = 0;
  bool _updateAvailable = false;
  @override
  void initState() {
    super.initState();
    _reload();
    if (Platform.isAndroid) _checkUpdateQuietly();
  }

  Future<void> _checkUpdateQuietly() async {
    try {
      final service = UpdateService();
      final info = await service.info();
      final release = await service.check();
      if (mounted) {
        setState(
          () => _updateAvailable = release.code > (info['versionCode'] as int),
        );
      }
    } catch (_) {
      /* Offline operation is unaffected by update checks. */
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    try {
      final manuals = await widget.repository.list(
        query: _search.text,
        category: _category,
      );
      final drafts = await widget.repository.list(status: 'draft');
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _manuals = manuals;
        _drafts = drafts;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _error = '读取失败，请重试';
        });
      }
    }
  }

  Future<void> _add([Manual? draft]) async {
    if (_opening) {
      return;
    }
    setState(() => _opening = true);
    try {
      final manual =
          draft ??
          (_drafts.isNotEmpty
              ? _drafts.first
              : await widget.repository.createDraft());
      if (!mounted) {
        return;
      }
      final saved = await Navigator.of(context).push<Manual>(
        MaterialPageRoute(
          builder: (_) =>
              ScanScreen(repository: widget.repository, manual: manual),
        ),
      );
      await _reload();
      if (saved != null && mounted) {
        await _read(saved);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法创建草稿，请检查可用存储空间后重试')));
      }
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  Future<void> _read(Manual manual) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          repository: widget.repository,
          manual: manual,
          initialQuery: _search.text.trim(),
        ),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final searching = _search.text.trim().isNotEmpty || _category != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '说明书柜',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: '软件更新',
            icon: Badge(
              isLabelVisible: _updateAvailable,
              child: const Icon(Icons.system_update),
            ),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const UpdateScreen())),
          ),
          IconButton(
            tooltip: '使用说明',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('让纸质说明书更好找'),
                content: const Text(
                  '拍照或导入图片，整理顺序后生成 PDF。原图保留，识别文字用于全文搜索。\n\n所有资料保存在本机，卸载应用会删除本地资料。请用阅读页的“导出 PDF”保存副本。\n\n识别可能有误，参数、安全事项请核对原图。当前版本不含云同步。',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('知道了'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _opening ? null : () => _add(),
        icon: const Icon(Icons.add),
        label: const Text('添加说明书'),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '纸张可以收起，使用方法随时可查。',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        hintText: '搜索产品、型号或说明书内容',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: '清空搜索',
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _search.clear();
                                  _reload();
                                },
                              ),
                      ),
                      onChanged: (_) {
                        setState(() {});
                        _debounce?.cancel();
                        _debounce = Timer(
                          const Duration(milliseconds: 250),
                          _reload,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['全部', ...categories]
                            .map(
                              (category) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(category),
                                  selected: (_category ?? '全部') == category,
                                  onSelected: (_) {
                                    setState(
                                      () => _category = category == '全部'
                                          ? null
                                          : category,
                                    );
                                    _reload();
                                  },
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    if (_drafts.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ..._drafts.map(
                        (draft) => Card(
                          color: colors.secondaryContainer,
                          child: ListTile(
                            leading: const Icon(Icons.edit_document),
                            title: Text(
                              draft.title.isEmpty ? '继续整理未完成的扫描' : draft.title,
                            ),
                            subtitle: Text('${draft.pageCount} 页 · 草稿已保存在本机'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _add(draft),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      searching
                          ? '找到 ${_manuals.length} 本说明书'
                          : '我的收藏 · ${_manuals.length} 本',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: TextButton(onPressed: _reload, child: Text(_error!)),
                ),
              )
            else if (_manuals.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 28, 32, 110),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer.withValues(alpha: .5),
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: Icon(
                          searching
                              ? Icons.search_off
                              : Icons.menu_book_rounded,
                          size: 60,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        searching ? '没有找到相关说明书' : '从第一本说明书开始',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        searching
                            ? '换个关键词，或切换到全部分类。'
                            : '拍下家电、工具或数码产品的说明书，\n存成可以搜索的 PDF。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          height: 1.7,
                        ),
                      ),
                      if (!searching) ...[
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _opening ? null : () => _add(),
                          icon: const Icon(Icons.document_scanner_outlined),
                          label: const Text('扫描 / 导入图片'),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                sliver: SliverList.separated(
                  itemCount: _manuals.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final manual = _manuals[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      elevation: 0,
                      color: colors.surfaceContainerLow,
                      child: InkWell(
                        onTap: () => _read(manual),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: manual.cover == null
                                    ? const SizedBox(
                                        width: 72,
                                        height: 96,
                                        child: Icon(Icons.description_outlined),
                                      )
                                    : Image.file(
                                        File(
                                          widget.repository.path(manual.cover!),
                                        ),
                                        width: 72,
                                        height: 96,
                                        fit: BoxFit.cover,
                                        cacheWidth: 200,
                                        errorBuilder: (_, _, _) =>
                                            const SizedBox(
                                              width: 72,
                                              height: 96,
                                              child: Icon(
                                                Icons.broken_image_outlined,
                                              ),
                                            ),
                                      ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      manual.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${manual.category} · ${manual.pageCount} 页',
                                      style: TextStyle(
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      manual.searchablePages == manual.pageCount
                                          ? '可搜索 PDF'
                                          : '${manual.searchablePages}/${manual.pageCount} 页可搜索',
                                      style: TextStyle(
                                        color: colors.primary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (_search.text.trim().isNotEmpty &&
                                        manual.matchSnippet != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          _snippet(
                                            manual.matchSnippet!,
                                            _search.text,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, size: 20),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _snippet(String text, String query) {
    final at = text.toLowerCase().indexOf(query.trim().toLowerCase());
    final start = at > 15 ? at - 15 : 0;
    return '${start > 0 ? '…' : ''}${text.substring(start).replaceAll('\n', ' ')}';
  }
}
