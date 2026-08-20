import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/utils/notification_service.dart';
import 'presentation/controllers/code_controller.dart';
import 'presentation/controllers/main_controller.dart';
import 'presentation/views/code_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    await NotificationService().init();
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }

  // Lock orientation to landscape for Android TV
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const TvApp());
}

class TvApp extends StatelessWidget {
  const TvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CodeController()),
        ChangeNotifierProvider(create: (_) => MainController()),
      ],
      child: MaterialApp(
        title: 'App For TV',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF0F172A),
          colorScheme: const ColorScheme.dark(
            primary: Colors.blueAccent,
            surface: Color(0xFF1E293B),
          ),
        ),
        home: const CodeView(),
      ),
    );
  }
}
