import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // 👈 ADDED kIsWeb IMPORT
import 'package:google_fonts/google_fonts.dart';
import 'package:watch_it/watch_it.dart';
import 'firebase_options.dart';
import 'app_state.dart';
import 'main_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin/admin_feed_manager.dart';


/*
  final batch = FirebaseFirestore.instance.batch();
  final collection = FirebaseFirestore.instance.collection('feeds');

  for (int i = 0; i < fileNames.length; i++) {
    final name = fileNames[i];
    final docRef = collection.doc('clip_${i + 1}');
    batch.set(docRef, {
      'index': i,
      'title': name.replaceAll('-', ' ').toUpperCase(),
      'subtitle': 'צפו עד הסוף',
      'url': '$baseUrl$name.mp4',
      'thumb': '$baseUrl$name.jpg',
      'isLocked': false,
      'like_count': 100 + i,
    });
  }
  await batch.commit();
  print("🔥🔥🔥 ALL 26 VIDEOS WRITTEN TO FIRESTORE DIRECTLY FROM APP! 🔥🔥🔥");
}
*/


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // await _seedDatabaseOnce(); // 👈 Add this line here just onceawait _seedDatabaseOnce(); // 👈 Add this line here just once
  // 👈 THE FIX: Stop web from crashing by ignoring mobile-only UI commands
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );
  }

  await EasyLocalization.ensureInitialized();
  await setupLocator(); // Initialize get_it / watch_it

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('he'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('he'),
      startLocale: const Locale('he'),
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
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.trackpad,
        },
      ),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        primaryColor: Colors.lightBlue,

        colorScheme: const ColorScheme.light(
          primary: Colors.lightBlue,
          secondary: Color(0xFFF59E0B),
          surface: Colors.white,
          onSurface: Color(0xFF103856),
        ),

        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.15),
          surfaceTintColor: Colors.transparent,
          shape: Border(
            bottom: BorderSide(
              color: const Color(0xFF103856).withOpacity(0.1),
              width: 1,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.lightBlue),
          titleTextStyle: const TextStyle(
            color: Color(0xFF103856),
            fontWeight: FontWeight.w900,
            fontSize: 26,
          ),
        ),

        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: Colors.lightBlue,
          unselectedItemColor: const Color(0xFF103856).withOpacity(0.6),
          type: BottomNavigationBarType.fixed,
        ),

        textTheme: GoogleFonts.heeboTextTheme(
          ThemeData.light().textTheme.apply(
            bodyColor: const Color(0xFF103856),
            displayColor: const Color(0xFF103856),
          ),
        ),

        iconTheme: const IconThemeData(
          color: Colors.lightBlue,
        ),

        sliderTheme: SliderThemeData(
          activeTrackColor: Colors.lightBlue,
          thumbColor: Colors.lightBlue,
          inactiveTrackColor: const Color(0xFF103856).withOpacity(0.1),
        ),
      ),
      home: const MainShell(),
    );
  }
}