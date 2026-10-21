import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/library_repository.dart';
import 'screens/library_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Noto Sans SC',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  runApp(const Bootstrap());
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});
  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  late Future<LibraryRepository> _opening = LibraryRepository.open();
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '说明书柜',
    debugShowCheckedModeBanner: false,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF49664D),
        surface: const Color(0xFFFAF9F5),
      ),
      scaffoldBackgroundColor: const Color(0xFFFAF9F5),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFAF9F5),
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    home: FutureBuilder<LibraryRepository>(
      future: _opening,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return LibraryScreen(repository: snapshot.data!);
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
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    ),
  );
}
