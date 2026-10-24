import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/manual.dart';
import 'services/library_repository.dart';
import 'screens/library_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/scan_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Noto Sans SC',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  runApp(const Bootstrap());
}

/// 书柜主题：纸感墨绿。动态取色仅在 Android 12+ 开启时覆盖种子色。
ThemeData buildTheme(Brightness brightness, bool dynamicColor) {
  final light = brightness == Brightness.light;
  ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF49664D),
    brightness: brightness,
    surface: light ? const Color(0xFFFAF9F5) : const Color(0xFF161B16),
  );
  if (dynamicColor && light) {
    // 保留纸感底色，只取用户的强调色（harmonized 后的 primary）。
    final dynamicScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF49664D),
      brightness: brightness,
    );
    scheme = scheme.copyWith(primary: dynamicScheme.primary);
  }
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      filled: true,
      fillColor: light ? const Color(0xFFF4F2EC) : scheme.surfaceContainerLow,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: ZoomPageTransitionsBuilder()},
    ),
  );
}

class ThemeController extends ChangeNotifier {
  ThemeMode mode = ThemeMode.system;
  static const _key = 'theme_mode';
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    mode =
        ThemeMode.values.asMap()[prefs.getInt(_key) ?? 0] ?? ThemeMode.system;
  }

  Future<void> set(ThemeMode value) async {
    mode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, value.index);
  }
}

final themeController = ThemeController();

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});
  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  late Future<LibraryRepository> _opening = LibraryRepository.open();

  @override
  void initState() {
    super.initState();
    themeController.load().then((_) {
      if (mounted) setState(() {});
    });
    themeController.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    themeController.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dynamicColor =
        PlatformDynamicColor.supported &&
        themeController.mode == ThemeMode.system;
    return MaterialApp(
      title: '说明书柜',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: buildTheme(Brightness.light, dynamicColor),
      darkTheme: buildTheme(Brightness.dark, dynamicColor),
      themeMode: themeController.mode,
      home: FutureBuilder<LibraryRepository>(
        future: _opening,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return HomeShell(repository: snapshot.data!);
          }
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.folder_off_outlined, size: 48),
                      const SizedBox(height: 16),
                      const Text('暂时无法打开书柜，已有文件不会被清空。'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => setState(() {
                          _opening = LibraryRepository.open();
                        }),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}

/// 动态取色探测：Android 12+ 且系统开启取色时生效。
class PlatformDynamicColor {
  static const channel = MethodChannel('manual_collector/ui');
  static bool? _supported;
  static bool get supported {
    if (_supported != null) return _supported!;
    if (!defaultTargetPlatform.toString().contains('android')) {
      _supported = false;
      return false;
    }
    channel
        .invokeMethod<bool>('dynamicColorAvailable')
        .then((value) {
          _supported = value ?? false;
        })
        .catchError((Object _) {
          _supported = false;
        });
    return false; // 首帧用静态色，异步结果影响后续重建。
  }
}

/// 应用外壳：2 Tab（书柜 / 我的）+ 中央扫描 FAB。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.repository});
  final LibraryRepository repository;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  bool _opening = false;
  late final GlobalKey<LibraryScreenState> _libraryKey =
      GlobalKey<LibraryScreenState>();

  Future<void> _add() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final saved = await Navigator.of(context).push<Manual>(
        MaterialPageRoute(
          builder: (_) =>
              ScanScreen(repository: widget.repository, manual: null),
        ),
      );
      if (saved != null) _libraryKey.currentState?.refreshAndRead(saved);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          LibraryScreen(key: _libraryKey, repository: widget.repository),
          ProfileScreen(repository: widget.repository),
        ],
      ),
      floatingActionButton: FloatingActionButton.large(
        onPressed: _opening ? null : _add,
        shape: const CircleBorder(),
        child: _opening
            ? const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Icon(
                Icons.add_a_photo_outlined,
                color: colors.onPrimaryContainer,
              ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        height: 68,
        color: colors.surfaceContainer,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          children: [
            Expanded(
              child: _NavButton(
                icon: Icons.shelves,
                label: '书柜',
                selected: _tab == 0,
                onTap: () => setState(() => _tab = 0),
              ),
            ),
            const SizedBox(width: 72), // 中央 FAB 让位
            Expanded(
              child: _NavButton(
                icon: Icons.person_outline,
                label: '我的',
                selected: _tab == 1,
                onTap: () => setState(() => _tab = 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部导航按钮（NavigationDestination 无回调参数，这里自绘）。
class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = selected ? colors.primary : colors.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
