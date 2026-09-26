import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:web/web.dart' as web;

// Import your tabs and state
import 'package:zehut_app/tabs/feed_tab.dart';
import 'tabs/plan_tab.dart';
import 'tabs/kitat_konenut.dart';
import 'tabs/vanguard_tab.dart';
import 'common/common.dart';
import 'app_state.dart';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'dart:html' as html;

// Import the new drawer we created
import 'tabs/app_drawer.dart';

class MainShell extends WatchingWidget {
  const MainShell({super.key});

  @override
   build(BuildContext context) {
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
// UNIVERSAL FIX: Strip only the '+' symbol to match global E.164 DB format.
    String safePhone = "guest";
    if (phone != null && phone.isNotEmpty) {
      safePhone = phone.replaceAll('+', '');
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('admins').doc(safePhone).snapshots(),
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

        // 🚨 MUST BE DEFINED HERE
        final bool isStandalone = kIsWeb && html.window.matchMedia('(display-mode: standalone)').matches;
        final double iconOffsetY = isStandalone ? -15.0 : 0.0;

        return Scaffold(
            backgroundColor: Colors.white,

          endDrawer: AppDrawer(isAdmin: isAdmin), // 🚨 Pass the result to the drawer

            appBar: AppBar(
              toolbarHeight: 56.0 + (isStandalone ? 23.0 : 0.0),
              backgroundColor: Colors.transparent,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: const Color(0xFF103856).withOpacity(0.5),
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
              leading: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: Transform.translate(
                  offset: Offset(0, iconOffsetY - 7.0), // 🚨 Raised 7px
                  child: Container(
                    color: Colors.transparent,
                    padding: EdgeInsets.only(
                        left: 16.0,
                        top: isStandalone ? 8.0 : 0.0
                    ),
                    alignment: Alignment.center,
                    child: Image.asset('assets/images/zahut-logo.png', height: 35),
                  ),
                ),
              ),
              title: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: Container(
                  color: Colors.transparent,
                  // 🚨 Added 20px right padding to push the title center/left and away from the language button
                  padding: EdgeInsets.only(
                    bottom: isStandalone ? 10.0 : 0.0,
                    right: 20.0,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'app_name'.tr(),
                    style: const TextStyle(
                      color: Color(0xFF103856),
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                    ),
                  ),
                ),
              ),
              actions: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (context.locale.languageCode == 'he') {
                      context.setLocale(const Locale('en'));
                    } else {
                      context.setLocale(const Locale('he'));
                    }
                  },
                  child: Container(
                    color: Colors.transparent,
                    padding: EdgeInsets.only(
                      left: 5.0,
                      right: 5.0,
                      bottom: isStandalone ? 17.0 : 0.0,
                    ),
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
                ),
                Builder(
                  builder: (context) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Scaffold.of(context).openEndDrawer();
                    },
                    child: Container(
                      color: Colors.transparent,
                      padding: EdgeInsets.only(
                        left: 10.0,
                        right: 15.0,
                        bottom: isStandalone ? 23.0 : 0.0,
                      ),
                      alignment: Alignment.center,
                      // 🚨 Increased size from 36.0 to 41.0
                      child: const Icon(Icons.menu, size: 41.0, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
            body: views[currentIndex],
          bottomNavigationBar: Container(
            height: (kIsWeb && html.window.matchMedia('(display-mode: standalone)').matches) ? 75.0 : 65.0,
            padding: const EdgeInsets.only(top: 5.0),
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
  final color = isSelected ? Colors.lightBlue : const Color(0xFF103856).withOpacity(0.5);
  final bool isStandalone = kIsWeb && html.window.matchMedia('(display-mode: standalone)').matches;

  return Expanded(
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => di<AppState>().setNavIndex(index),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          color: Colors.transparent,
          // 🚨 Increased from 8.0 to 13.0 to lift 5 more px on PWA
          padding: EdgeInsets.only(bottom: isStandalone ? 13.0 : 0.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.grey.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Icon(icon, size: 34.0, color: color),
              ),
              Transform.translate(
                offset: const Offset(0, -7.0),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    height: 1.1,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}