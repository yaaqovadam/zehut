import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:watch_it/watch_it.dart';
import 'firebase_options.dart';
import 'app_state.dart';
import 'main_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // LOCK ORIENTATION TO PORTRAIT (Vertical Only)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  await EasyLocalization.ensureInitialized();



// Call this in your initState() or main() function
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );

await   setupLocator(); // Initialize get_it / watch_it



  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('he'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('he'),
      startLocale: const Locale('he'), // Start in Hebrew for the pitch to Moshe
      child: const ZehutApp(),
    ),
  );
}

class ZehutApp extends StatelessWidget {
  const ZehutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Zehut 2026',
      // NEW: Force Flutter Web to allow mouse and trackpad swiping
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.trackpad,
        },
      ),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale, // Automatically handles RTL flipping!

      // The Post-Oct 7th Vibe: Deep Slate & Amber
      theme: ThemeData(
        brightness: Brightness.dark,
        // 1. Force the entire app background to your Deep Blue
        // scaffoldBackgroundColor: const Color(0xFF1f1a54),
        scaffoldBackgroundColor: Color(0xff010126),
        primaryColor: const Color(0xFFF59E0B),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF59E0B),
          secondary: Color(0xFF38BDF8),
          surface: Color(0xFF1E293B), // Leaves the cards Slate Gray so they pop
        ),

        // 2. THE APPBAR FIX
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1f1a54),
          elevation: 0,
          scrolledUnderElevation: 0, // STOPS THE COLOR FROM CHANGING ON SCROLL!
          surfaceTintColor: Colors.transparent, // Kills the Material 3 tint
        ),

        // 3. THE BOTTOM BAR FIX
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1f1a54),
          elevation: 0, // Removes the top shadow that alters the color
          selectedItemColor: Color(0xFFF59E0B),
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
        ),

        textTheme: GoogleFonts.heeboTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      home: const MainShell(),
    );
  }
}