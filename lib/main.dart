import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/services/local_storage_service.dart';
import 'core/services/offline_sync_service.dart';
import 'core/services/printer_service.dart';
import 'core/theme/app_theme.dart';
import 'providers/pos_provider.dart';
import 'ui/screens/main_layout_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Local Storage first for instant offline catalog and bills availability
  await LocalStorageService().initialize();

  // Initialize Supabase Client
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    // ignore: deprecated_member_use
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  // Initialize offline sync and thermal printer services
  await OfflineSyncService().initialize(Supabase.instance.client);
  await PrinterService().initialize();

  runApp(const CfcPosApp());
}

class CfcPosApp extends StatelessWidget {
  const CfcPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PosProvider()),
        ChangeNotifierProvider.value(value: OfflineSyncService()),
        ChangeNotifierProvider.value(value: PrinterService()),
      ],
      child: MaterialApp(
        title: 'CFC Multi-Shop Restaurant POS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          overscroll: false,
          physics: const ClampingScrollPhysics(),
        ),
        home: const MainLayoutScreen(),
      ),
    );
  }
}
