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

    final List<Widget> views = [
      const FeedTab(),
      const VanguardTab(),
      const PlanTab(),
      const ActionTab(),
    ];

    // Grab the phone number from the AppState
    final phone = watchValue((AppState s) => s.userPhone);

    // Clean the phone number just in case it has +972
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
                    Scaffold.of(context).openEndDrawer();
                  },
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
          body: views[currentIndex],

          bottomNavigationBar: Container(
            height: 85, // Increased by 10px to accommodate the buffer
            padding: const EdgeInsets.only(top: 10.0), // Creates a 10px un-clickable dead zone at the top
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
            child: SafeArea(
              bottom: true,
              child: Row(
                children: [
                  _buildNavItem(icon: Icons.play_circle_fill, label: 'tab_feed'.tr(), index: 0, currentIndex: currentIndex),
                  _buildNavItem(icon: Icons.shield, label: 'tab_vanguard'.tr(), index: 1, currentIndex: currentIndex),
                  _buildNavItem(icon: Icons.view_carousel, label: 'tab_100_days'.tr(), index: 2, currentIndex: currentIndex),
                  _buildNavItem(icon: Icons.group, label: 'tab_action'.tr(), index: 3, currentIndex: currentIndex),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}


Widget _buildNavItem({
  required IconData icon,
  required String label,
  required int index,
  required int currentIndex,
}) {
  final isSelected = currentIndex == index;
  final color = isSelected ? const Color(0xFF103856) : const Color(0xFF103856).withOpacity(0.5);

  return Expanded(
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => di<AppState>().setNavIndex(index),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: const Offset(0, -4),
              child: isSelected
                  ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Icon(icon, size: 40.0, color: color),
              )
                  : Icon(icon, size: 40.0, color: color),
            ),
            Transform.translate(
              offset: const Offset(0, -8),
              child: Container(
                color: Colors.transparent,
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 4.0, bottom: 8.0),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    height: 1.0,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
