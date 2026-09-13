import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:web/web.dart' as web;

// Import your tabs and state
import 'package:zehut_app/tabs/feed_tab.dart';
import 'tabs/plan_tab.dart';
import 'tabs/action_tab.dart';
import 'tabs/vanguard_tab.dart';
import 'common/common.dart';
import 'app_state.dart';
import 'dart:html' as html;

// Import the new drawer we created
import 'tabs/app_drawer.dart';

class MainShell extends WatchingWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final currentIndex = watchValue((AppState s) => s.navIndex);

    bool isPWA = false;
    if (kIsWeb) {
      isPWA = web.window.matchMedia('(display-mode: standalone)').matches;
    }

    final double customBottomPadding = isPWA ? 20.0 : 0.0;

    final List<Widget> views = [
      const FeedTab(),
      const VanguardTab(),
      const PlanTab(),
      const ActionTab(),
    ];

// Clean the phone number just in case it has +972
// 1. Grab the phone number from the AppState (ADD THIS LINE)
    final phone = watchValue((AppState s) => s.userPhone);

    // 2. Clean the phone number just in case it has +972
    String safePhone = "guest";
    if (phone != null && phone.isNotEmpty) {
      safePhone = phone.replaceAll('+972', '0');
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('admins').doc(safePhone).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator(color: Colors.lightBlue)),
          );
        }

        bool isAdmin = false;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null && data['isAdmin'] == true) {
            isAdmin = true;
          }
        }

        // 🚨 TERMINAL DEBUGGER 🚨
        debugPrint("==== ADMIN CHECK ====");
        debugPrint("Raw Phone from State: '$phone'");
        debugPrint("Cleaned Phone Queried: '$safePhone'");
        debugPrint("Document Exists in DB: ${snapshot.data?.exists}");
        debugPrint("Is Admin Granted: $isAdmin");
        debugPrint("=====================");

        return Scaffold(
          backgroundColor: Colors.white,
          endDrawer: AppDrawer(isAdmin: isAdmin),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: const Color(0xFF103856).withOpacity(0.3),
                    width: 2.0,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    offset: const Offset(0, 5),
                    blurRadius: 14,
                  ),
                ],
              ),
            ),
            centerTitle: true,
            leadingWidth: 80,
            leading: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Image.asset('assets/images/zahut-logo.png', height: 35),
            ),
            title: Text(
              'app_name'.tr(),
              style: const TextStyle(
                color: Color(0xFF103856),
                fontWeight: FontWeight.w900,
                fontSize: 26,
              ),
            ),
            actions: [
              InkWell(
                onTap: () {
                  if (context.locale.languageCode == 'he') {
                    context.setLocale(const Locale('en'));
                  } else {
                    context.setLocale(const Locale('he'));
                  }
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.language, color: Colors.lightBlue, size: 28),
                    const SizedBox(height: 2),
                    Text(
                      context.locale.languageCode == 'he' ? 'English' : 'עברית',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, size: 32, color: Colors.black),
                  onPressed: () {
                    // if (kIsWeb) {
                    //   // html.window.dispatchEvent(html.CustomEvent('showInstallPrompt'));
                    //   html.window.dispatchEvent(html.CustomEvent('showInstallPrompt', detail: context.locale.languageCode));
                    // }
                    Scaffold.of(context).openEndDrawer();
                  },
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
          body: views[currentIndex],
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(
                  color: const Color(0xFF103856).withOpacity(0.3),
                  width: 2.0,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  offset: const Offset(0, -8),
                  blurRadius: 24,
                ),
              ],
            ),
            padding: EdgeInsets.only(bottom: customBottomPadding),
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: BottomNavigationBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                type: BottomNavigationBarType.fixed,
                currentIndex: currentIndex,
                onTap: (index) => di<AppState>().setNavIndex(index),
                items: [
                  BottomNavigationBarItem(icon: const Icon(Icons.play_circle_fill), label: 'tab_feed'.tr()),
                  BottomNavigationBarItem(icon: const Icon(Icons.shield), label: 'tab_vanguard'.tr()),
                  BottomNavigationBarItem(icon: const Icon(Icons.view_carousel), label: 'tab_100_days'.tr()),
                  BottomNavigationBarItem(icon: const Icon(Icons.group), label: 'tab_action'.tr()),
                ],
                selectedItemColor: Colors.lightBlue,
                unselectedItemColor: const Color(0xFF103856).withOpacity(0.5),
              ),
            ),
          ),
        );
      },
    );
  }
}