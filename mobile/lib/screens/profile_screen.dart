import 'dart:io';
import 'package:flutter/material.dart';
import '../main.dart' show themeController;
import '../services/library_repository.dart';
import 'library_screen.dart' show showHelpDialog;
import 'update_screen.dart';

/// 我的：统计、外观、备份说明、更新、关于。
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.repository});
  final LibraryRepository repository;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _manuals = 0, _pages = 0, _searchable = 0, _warrantySoon = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = await widget.repository.stats();
    if (!mounted) return;
    setState(() {
      _manuals = stats['manuals'] ?? 0;
      _pages = stats['pages'] ?? 0;
      _searchable = stats['searchable'] ?? 0;
      _warrantySoon = stats['warrantySoon'] ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final percent = _pages == 0
        ? 100
        : (_searchable * 100 ~/ _pages).clamp(0, 100);
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            elevation: 0,
            color: colors.primaryContainer.withValues(alpha: .45),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_manuals 本说明书 · $_pages 页',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _pages == 0 ? '扫描第一本，开始建立家庭产品档案' : '其中 $percent% 的页面可以全文搜索',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  if (_warrantySoon > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.notifications_active_outlined,
                          size: 16,
                          color: colors.error,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$_warrantySoon 台设备保修将在 90 天内到期',
                          style: TextStyle(color: colors.error, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('外观', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: colors.surfaceContainerLow,
            child: ListenableBuilder(
              listenable: themeController,
              builder: (context, _) => RadioGroup<ThemeMode>(
                groupValue: themeController.mode,
                onChanged: (value) {
                  if (value != null) themeController.set(value);
                },
                child: Column(
                  children: [
                    for (final entry in const {
                      ThemeMode.system: '跟随系统',
                      ThemeMode.light: '浅色',
                      ThemeMode.dark: '深色',
                    }.entries)
                      RadioListTile<ThemeMode>(
                        value: entry.key,
                        title: Text(entry.value),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('资料与备份', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: colors.surfaceContainerLow,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: const Text('资料保存在哪里？'),
                  subtitle: const Text('全部在本机，不上传任何服务器'),
                  onTap: () => showHelpDialog(context),
                ),
                ListTile(
                  leading: const Icon(Icons.ios_share),
                  title: const Text('如何备份？'),
                  subtitle: const Text('打开说明书 → 导出 PDF，保存副本'),
                  onTap: () => showHelpDialog(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 0,
            color: colors.surfaceContainerLow,
            child: Column(
              children: [
                if (Platform.isAndroid)
                  ListTile(
                    leading: const Icon(Icons.system_update),
                    title: const Text('软件更新'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const UpdateScreen()),
                    ),
                  ),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('使用说明'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showHelpDialog(context),
                ),
                const AboutListTile(
                  icon: Icon(Icons.info_outline),
                  applicationName: '说明书柜',
                  applicationVersion: 'v0.2.0',
                  aboutBoxChildren: [
                    Text('给家里每台设备配一个丢不掉的说明书。'),
                    SizedBox(height: 8),
                    Text('本地 OCR · 可搜索 PDF · 产品档案 · 不联网'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
