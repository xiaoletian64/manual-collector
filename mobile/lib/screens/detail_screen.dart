import 'dart:io';
import 'package:flutter/material.dart';
import '../models/manual.dart';
import '../services/library_repository.dart';
import 'library_screen.dart';
import 'reader_screen.dart';

/// 产品档案：型号、品牌、购买日期、保修、售后电话。
/// 深链：书柜卡片角标 / 阅读器菜单「产品档案」。
class ManualDetailScreen extends StatefulWidget {
  const ManualDetailScreen({
    super.key,
    required this.repository,
    required this.manualId,
    this.autoEdit = false,
  });
  final LibraryRepository repository;
  final String manualId;
  final bool autoEdit;
  @override
  State<ManualDetailScreen> createState() => _ManualDetailScreenState();
}

class _ManualDetailScreenState extends State<ManualDetailScreen> {
  Manual? _manual;
  int _pdfBytes = 0;
  bool _editing = false;

  // 编辑中的临时值
  late TextEditingController _title;
  late TextEditingController _brand;
  late TextEditingController _modelNo;
  late TextEditingController _phone;
  DateTime? _purchasedAt;
  int? _warrantyMonths;
  late String _category;

  @override
  void initState() {
    super.initState();
    _load().then((_) {
      if (mounted && widget.autoEdit && _manual != null) _startEdit();
    });
  }

  Future<void> _load() async {
    final manual = await widget.repository.get(widget.manualId);
    final pdf = File(widget.repository.pdfPath(widget.manualId));
    final length = await pdf.exists() ? await pdf.length() : 0;
    if (!mounted) return;
    setState(() {
      _manual = manual;
      _pdfBytes = length;
    });
  }

  void _startEdit() {
    final manual = _manual!;
    _title = TextEditingController(text: manual.title);
    _brand = TextEditingController(text: manual.brand);
    _modelNo = TextEditingController(text: manual.modelNo);
    _phone = TextEditingController(text: manual.phone);
    _purchasedAt = manual.purchasedAt;
    _warrantyMonths = manual.warrantyMonths;
    _category = manual.category;
    setState(() => _editing = true);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写产品名称或型号')));
      return;
    }
    final repository = widget.repository;
    final manualId = widget.manualId;
    await repository.updateArchive(
      id: manualId,
      title: title,
      category: _category,
      brand: _brand.text.trim(),
      modelNo: _modelNo.text.trim(),
      phone: _phone.text.trim(),
      purchasedAt: _purchasedAt,
      warrantyMonths: _warrantyMonths,
    );
    if (!mounted) return;
    setState(() => _editing = false);
    await _load();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchasedAt ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
      helpText: '购买日期',
    );
    if (picked != null) setState(() => _purchasedAt = picked);
  }

  Future<void> _pickWarranty() async {
    final value = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('保修时长'),
        children: [
          for (final months in const [12, 24, 36])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, months),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('$months 个月（${months ~/ 12} 年）'),
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 0),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('自定义…'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, -1),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                '清除保修信息',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        ],
      ),
    );
    if (value == null) return;
    if (value == 0) {
      if (!mounted) return;
      final controller = TextEditingController(
        text: _warrantyMonths?.toString() ?? '',
      );
      final months = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('保修多少个月？'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(suffixText: '个月'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, int.tryParse(controller.text)),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      if (months != null && months > 0) {
        if (!mounted) return;
        setState(() => _warrantyMonths = months);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _warrantyMonths = value == -1 ? null : value);
  }

  String _fmtDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// 保修状态卡。
  Widget _warrantyCard(ColorScheme colors) {
    final manual = _manual!;
    final end = manual.warrantyEnd;
    if (end == null) {
      return Card(
        elevation: 0,
        color: colors.surfaceContainerLow,
        child: ListTile(
          leading: Icon(Icons.verified_user_outlined, color: colors.outline),
          title: const Text('未设置保修'),
          subtitle: const Text('填购买日期和保修期，临期前这里会亮提醒'),
        ),
      );
    }
    final days = manual.warrantyDaysLeft!;
    final expired = days < 0;
    final urgent = !expired && days <= 30;
    final color = expired
        ? colors.outline
        : urgent
        ? colors.error
        : colors.primary;
    final text = expired
        ? '已过保 ${-days} 天'
        : days == 0
        ? '保修今天到期'
        : '保修还剩 $days 天';
    return Card(
      elevation: 0,
      color: urgent
          ? colors.errorContainer.withValues(alpha: .5)
          : colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.verified_user_outlined, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_fmtDate(manual.purchasedAt!)} 购买 · ${manual.warrantyMonths} 个月保修 · ${_fmtDate(end)} 到期',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manual = _manual;
    if (manual == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? '编辑档案' : '产品档案'),
        actions: [
          if (!_editing)
            IconButton(
              tooltip: '编辑档案',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _startEdit,
            )
          else
            TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: _editing ? _buildEdit(colors) : _buildView(colors, manual),
    );
  }

  Widget _buildView(ColorScheme colors, Manual manual) {
    final phone = manual.phone.trim();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 84,
                height: 112,
                child: CoverView(
                  coverPath: manual.cover == null
                      ? null
                      : widget.repository.path(manual.cover!),
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
                    manual.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Chip(
                        label: Text(manual.category),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      if (manual.subtitle.isNotEmpty)
                        Chip(
                          label: Text(manual.subtitle),
                          visualDensity: VisualDensity.compact,
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _warrantyCard(colors),
        if (phone.isNotEmpty) ...[
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: colors.surfaceContainerLow,
            child: ListTile(
              leading: const Icon(Icons.support_agent_outlined),
              title: Text(phone),
              subtitle: const Text('官方售后电话'),
              trailing: FilledButton.tonal(
                onPressed: () => widget.repository.dial(phone),
                child: const Text('拨打'),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text('归档信息', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: colors.surfaceContainerLow,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.auto_stories_outlined),
                title: Text('${manual.pageCount} 页'),
                subtitle: Text(
                  manual.searchablePages == manual.pageCount
                      ? '全部页面可搜索'
                      : '${manual.searchablePages} 页可搜索',
                ),
              ),
              if (_pdfBytes > 0)
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: Text(
                    '可搜索 PDF · ${(_pdfBytes / 1048576).toStringAsFixed(1)} MB',
                  ),
                  subtitle: Text('归档于 ${_fmtDate(manual.createdAt)}'),
                ),
              ListTile(
                leading: const Icon(Icons.book_outlined),
                title: const Text('打开阅读器'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReaderScreen(
                        repository: widget.repository,
                        manual: manual,
                      ),
                    ),
                  );
                  await _load();
                },
              ),
            ],
          ),
        ),
        if (manual.subtitle.isEmpty || manual.phone.isEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '提示：编辑档案补充型号和售后电话，报修时不用翻纸质说明书。',
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  Widget _buildEdit(ColorScheme colors) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _title,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: '产品名称 / 型号 *',
            hintText: '例如：米家电饭煲 C1',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _brand,
                decoration: const InputDecoration(labelText: '品牌'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _modelNo,
                decoration: const InputDecoration(labelText: '型号'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          initialValue: _category,
          decoration: const InputDecoration(labelText: '分类'),
          items: categories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _category = value);
          },
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: '购买日期'),
                  child: Text(
                    _purchasedAt == null ? '未设置' : _fmtDate(_purchasedAt!),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: _pickWarranty,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: '保修时长'),
                  child: Text(
                    _warrantyMonths == null ? '未设置' : '$_warrantyMonths 个月',
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: '售后电话',
            hintText: '说明书背面的 400 电话',
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('保存档案'),
        ),
        const SizedBox(height: 8),
        Text(
          '保修提醒在本机计算，不联网、不上传任何资料。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}
