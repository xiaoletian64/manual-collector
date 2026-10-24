import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/manual.dart';
import '../services/library_repository.dart';
import '../services/update_service.dart';
import 'reader_screen.dart';
import 'scan_screen.dart';
import 'update_screen.dart';
import 'detail_screen.dart';

enum _Sort { recent, name, warranty }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.repository});
  final LibraryRepository repository;
  @override
  State<LibraryScreen> createState() => LibraryScreenState();
}

class LibraryScreenState extends State<LibraryScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Manual> _manuals = [], _drafts = [];
  String? _category;
  String? _error;
  bool _loading = true;
  bool _grid = true;
  bool _updateAvailable = false;
  _Sort _sort = _Sort.recent;
  final Set<String> _selected = {};
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _reload();
    if (Platform.isAndroid) _checkUpdateQuietly();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
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

  /// 供外壳调用：回到书柜页刷新并打开刚保存的书。
  Future<void> refreshAndRead(Manual manual) async {
    await _reload();
    if (mounted) _read(manual);
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    try {
      final manuals = await widget.repository.list(
        query: _search.text,
        category: _category,
        sort: switch (_sort) {
          _Sort.recent => 'recent',
          _Sort.name => 'name',
          _Sort.warranty => 'warranty',
        },
      );
      final drafts = await widget.repository.list(status: 'draft');
      if (!mounted || generation != _generation) return;
      setState(() {
        _manuals = manuals;
        _drafts = drafts;
        _loading = false;
        _error = null;
        _selected.removeWhere(
          (id) => !_manuals.any((manual) => manual.id == id),
        );
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

  void _toggleSelect(String id) {
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
      if (_selected.isEmpty) _selected.clear(); // 让空集合走非选择分支
    });
  }

  Future<void> _bulkCategory() async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('移动 ${_selected.length} 项到分类'),
        children: categories
            .map(
              (category) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, category),
                child: Text(category),
              ),
            )
            .toList(),
      ),
    );
    if (value == null) return;
    for (final id in _selected) {
      final manual = _manuals.firstWhere((m) => m.id == id);
      await widget.repository.updateInfo(
        id,
        manual.title,
        value,
        keepArchive: true,
      );
    }
    if (!mounted) return;
    setState(() => _selected.clear());
    await _reload();
  }

  Future<void> _bulkDelete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除 ${_selected.length} 本说明书？'),
        content: const Text('对应的页面、PDF 和识别文字将从本机删除，无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    for (final id in _selected.toList()) {
      await widget.repository.delete(id);
    }
    if (!mounted) return;
    setState(() => _selected.clear());
    await _reload();
  }

  void _exitSelection() => setState(() => _selected.clear());

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final searching = _search.text.trim().isNotEmpty || _category != null;
    final selecting = _selected.isNotEmpty;
    return Scaffold(
      appBar: selecting
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelection,
              ),
              title: Text('已选 ${_selected.length} 项'),
              actions: [
                IconButton(
                  tooltip: '全选',
                  icon: const Icon(Icons.select_all),
                  onPressed: () => setState(() {
                    if (_selected.length == _manuals.length) {
                      _selected.clear();
                    } else {
                      _selected
                        ..clear()
                        ..addAll(_manuals.map((manual) => manual.id));
                    }
                  }),
                ),
              ],
            )
          : AppBar(
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
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const UpdateScreen()),
                  ),
                ),
                IconButton(
                  tooltip: '使用说明',
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => showHelpDialog(context),
                ),
              ],
            ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '纸张可以收起，使用方法随时可查。',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        hintText: '搜产品名、型号或内容，如：E1、除垢',
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
                    Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: ['全部', ...categories]
                                  .map(
                                    (category) => Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        label: Text(category),
                                        selected:
                                            (_category ?? '全部') == category,
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
                        ),
                        const SizedBox(width: 4),
                        PopupMenuButton<_Sort>(
                          tooltip: '排序',
                          icon: Icon(
                            _sort == _Sort.warranty
                                ? Icons.schedule
                                : Icons.sort,
                            color: _sort == _Sort.warranty
                                ? colors.primary
                                : null,
                          ),
                          onSelected: (value) {
                            setState(() => _sort = value);
                            _reload();
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: _Sort.recent,
                              child: Text('最近添加'),
                            ),
                            PopupMenuItem(
                              value: _Sort.name,
                              child: Text('按名称'),
                            ),
                            PopupMenuItem(
                              value: _Sort.warranty,
                              child: Text('保修临期优先'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_drafts.isNotEmpty) ...[
                      const SizedBox(height: 8),
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
                            onTap: () => openDraft(
                              context,
                              widget.repository,
                              draft,
                              (saved) => refreshAndRead(saved!),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            searching
                                ? '找到 ${_manuals.length} 本说明书'
                                : '我的收藏 · ${_manuals.length} 本',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: _grid ? '切换列表视图' : '切换书架视图',
                          icon: Icon(
                            _grid ? Icons.view_list_outlined : Icons.shelves,
                          ),
                          onPressed: () => setState(() => _grid = !_grid),
                        ),
                      ],
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
                    ],
                  ),
                ),
              )
            else if (_grid)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 130),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: _manuals.length,
                  itemBuilder: (context, index) {
                    final manual = _manuals[index];
                    return ManualGridCard(
                      manual: manual,
                      repository: widget.repository,
                      selected: _selected.contains(manual.id),
                      selecting: selecting,
                      onTap: () =>
                          selecting ? _toggleSelect(manual.id) : _read(manual),
                      onLongPress: () => _toggleSelect(manual.id),
                      onArchive: () => _openArchive(manual),
                    );
                  },
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 130),
                sliver: SliverList.separated(
                  itemCount: _manuals.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final manual = _manuals[index];
                    return ManualListCard(
                      manual: manual,
                      repository: widget.repository,
                      selected: _selected.contains(manual.id),
                      selecting: selecting,
                      query: _search.text,
                      onTap: () =>
                          selecting ? _toggleSelect(manual.id) : _read(manual),
                      onLongPress: () => _toggleSelect(manual.id),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: selecting
          ? BottomAppBar(
              height: 68,
              color: colors.surfaceContainer,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: _bulkCategory,
                    icon: const Icon(Icons.category_outlined),
                    label: const Text('改分类'),
                  ),
                  TextButton.icon(
                    onPressed: _bulkDelete,
                    icon: Icon(Icons.delete_outline, color: colors.error),
                    label: Text('删除', style: TextStyle(color: colors.error)),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Future<void> _openArchive(Manual manual) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManualDetailScreen(
          repository: widget.repository,
          manualId: manual.id,
        ),
      ),
    );
    await _reload();
  }
}

/// 使用说明弹窗（书柜与我的页共用）。
Future<void> showHelpDialog(BuildContext context) => showDialog(
  context: context,
  builder: (_) => AlertDialog(
    title: const Text('让纸质说明书更好找'),
    content: const Text(
      '拍照或导入图片，整理顺序后生成 PDF。原图保留，识别文字用于全文搜索；型号、保修、售后电话写在产品档案里。\n\n所有资料保存在本机，卸载应用会删除本地资料。请用阅读页的“导出 PDF”保存副本。\n\n识别可能有误，参数、安全事项请核对原图。当前版本不含云同步。',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('知道了'),
      ),
    ],
  ),
);

/// 草稿入口（书柜卡片与保存完成页共用）。
Future<void> openDraft(
  BuildContext context,
  LibraryRepository repository,
  Manual draft,
  ValueChanged<Manual?> onSaved,
) async {
  final saved = await Navigator.of(context).push<Manual>(
    MaterialPageRoute(
      builder: (_) => ScanScreen(repository: repository, manual: draft),
    ),
  );
  if (saved != null) onSaved(saved);
}

/// 保修角标：临期红/橙，过保不显示。
class WarrantyBadge extends StatelessWidget {
  const WarrantyBadge({super.key, required this.manual});
  final Manual manual;
  @override
  Widget build(BuildContext context) {
    final days = manual.warrantyDaysLeft;
    if (days == null || days < 0) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final urgent = days <= 30;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: urgent ? colors.errorContainer : colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        days == 0 ? '今天到期' : '保修剩 $days 天',
        style: TextStyle(
          fontSize: 11,
          height: 1,
          color: urgent ? colors.onErrorContainer : colors.onTertiaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 纸书封面占位：分类首字。
class CoverView extends StatelessWidget {
  const CoverView({
    super.key,
    required this.coverPath,
    required this.title,
    this.width,
    this.height,
  });
  final String? coverPath; // 绝对路径
  final String title;
  final double? width, height;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (coverPath != null) {
      return Image.file(
        File(coverPath!),
        width: width,
        height: height,
        fit: BoxFit.cover,
        cacheWidth: 400,
        errorBuilder: (_, _, _) => _placeholder(colors),
      );
    }
    return _placeholder(colors);
  }

  Widget _placeholder(ColorScheme colors) => Container(
    width: width,
    height: height,
    color: colors.surfaceContainerHighest,
    alignment: Alignment.center,
    child: Text(
      title.isEmpty ? '未\n命\n名' : title.characters.first,
      style: TextStyle(
        color: colors.onSurfaceVariant,
        fontSize: title.isEmpty ? 14 : 28,
        fontWeight: FontWeight.w600,
        height: title.isEmpty ? 1.4 : 1,
      ),
    ),
  );
}

/// 书架网格卡片。
class ManualGridCard extends StatelessWidget {
  const ManualGridCard({
    super.key,
    required this.manual,
    required this.repository,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
    required this.onArchive,
  });
  final Manual manual;
  final LibraryRepository repository;
  final bool selected, selecting;
  final VoidCallback onTap, onLongPress, onArchive;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          margin: EdgeInsets.zero,
          color: colors.surfaceContainerLow,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SizedBox(
                    width: double.infinity,
                    child: CoverView(
                      coverPath: manual.cover == null
                          ? null
                          : repository.path(manual.cover!),
                      title: manual.title,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        manual.title.isEmpty ? '未命名' : manual.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              manual.subtitle.isEmpty
                                  ? '${manual.category} · ${manual.pageCount} 页'
                                  : '${manual.subtitle} · ${manual.pageCount} 页',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: onArchive,
                            borderRadius: BorderRadius.circular(999),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.badge_outlined,
                                size: 18,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      WarrantyBadge(manual: manual),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (selecting)
          Positioned.fill(
            child: Material(
              color: selected
                  ? colors.primary.withValues(alpha: .18)
                  : Colors.transparent,
              child: InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: selected ? colors.primary : colors.outline,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 列表卡片（0.1.2 版式 + 保修角标 + 多选）。
class ManualListCard extends StatelessWidget {
  const ManualListCard({
    super.key,
    required this.manual,
    required this.repository,
    required this.selected,
    required this.selecting,
    required this.query,
    required this.onTap,
    required this.onLongPress,
  });
  final Manual manual;
  final LibraryRepository repository;
  final bool selected, selecting;
  final String query;
  final VoidCallback onTap, onLongPress;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      margin: EdgeInsets.zero,
      color: selected
          ? colors.primaryContainer.withValues(alpha: .4)
          : colors.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (selecting)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: selected ? colors.primary : colors.outline,
                  ),
                ),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 72,
                  height: 96,
                  child: CoverView(
                    coverPath: manual.cover == null
                        ? null
                        : repository.path(manual.cover!),
                    title: manual.title,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manual.title.isEmpty ? '未命名' : manual.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      manual.subtitle.isEmpty
                          ? '${manual.category} · ${manual.pageCount} 页'
                          : '${manual.subtitle} · ${manual.pageCount} 页',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          manual.searchablePages == manual.pageCount
                              ? '可搜索 PDF'
                              : '${manual.searchablePages}/${manual.pageCount} 页可搜索',
                          style: TextStyle(color: colors.primary, fontSize: 12),
                        ),
                        WarrantyBadge(manual: manual),
                      ],
                    ),
                    if (query.trim().isNotEmpty && manual.matchSnippet != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _snippet(manual.matchSnippet!, query),
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
  }

  String _snippet(String text, String query) {
    final at = text.toLowerCase().indexOf(query.trim().toLowerCase());
    final start = at > 15 ? at - 15 : 0;
    return '${start > 0 ? '…' : ''}${text.substring(start).replaceAll('\n', ' ')}';
  }
}
