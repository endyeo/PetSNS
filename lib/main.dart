import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'store.dart';
import 'design_system.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'supabase_connection.dart';
export 'design_system.dart' show coral, ink, cream, muted;
export 'screens/home_screen.dart';
export 'screens/login_screen.dart';
export 'screens/chat_screen.dart';
export 'screens/memory_view.dart';
export 'widgets/common.dart';

SupabaseConnectionResult? supabaseConnection;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  supabaseConnection = await initializeSupabase();
  debugPrint('[PetSNS Supabase] ${supabaseConnection!.message}');
  runApp(const PetApp());
}

class PetApp extends StatefulWidget {
  const PetApp({super.key});
  @override
  State<PetApp> createState() => _PetAppState();
}

class _PetAppState extends State<PetApp> {
  PetStore? store;
  String? error;
  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    setState(() => error = null);
    try {
      final s = PetStore(await SharedPreferences.getInstance());
      await s.load();
      if (mounted) {
        setState(() => store = s);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = '데이터를 불러오지 못했습니다. $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('ko'),
    supportedLocales: const [Locale('ko')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    title: 'PetSNS · 함께 쌓는 작은 행복',
    theme: petTheme,
    home: store == null
        ? Scaffold(
            body: Center(
              child: error == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(error!),
                        TextButton(onPressed: init, child: const Text('다시 시도')),
                      ],
                    ),
            ),
          )
        : ListenableBuilder(
            listenable: store!,
            builder: (context, _) => store!.user == null
                ? Login(store: store!)
                : Home(store: store!),
          ),
  );
}
