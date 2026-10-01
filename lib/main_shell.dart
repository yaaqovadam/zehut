import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart'; // 🎯 Added Video Player
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

// Import the new drawer we created
import 'tabs/app_drawer.dart';

class MainShell extends WatchingWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final currentIndex = watchValue((AppState s) => s.navIndex);
    final isEditMode = watchValue((AppState s) => s.isFeedEditMode); // 🎯 Listens to state

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

    final phone = watchValue((AppState s) => s.userPhone);
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

        final bool isStandalone = kIsWeb && html.window.matchMedia('(display-mode: standalone)').matches;
        final double iconOffsetY = isStandalone ? -15.0 : 0.0;

        return Scaffold(
          backgroundColor: Colors.white,
          endDrawer: AppDrawer(isAdmin: isAdmin),
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
                offset: Offset(0, iconOffsetY - 7.0),
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
                    child: const Icon(Icons.menu, size: 41.0, color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
          body: views[currentIndex],

          // 🎯 THE SWAP: Normal Tabs OR Waveform Scrubber
          bottomNavigationBar: isEditMode
              ? const EditScrubberNavBar()
              : Container(
            height: isStandalone ? 75.0 : 65.0,
            padding: const EdgeInsets.only(top: 5.0),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: const Color(0xFF103856).withOpacity(0.3), width: 2.0),
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.25), offset: const Offset(0, -8), blurRadius: 24),
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
class EditScrubberNavBar extends WatchingStatefulWidget {
  const EditScrubberNavBar({super.key});

  @override
  State<EditScrubberNavBar> createState() => _EditScrubberNavBarState();
}

class _EditScrubberNavBarState extends State<EditScrubberNavBar> {

  void _jump(int direction, List<dynamic> words) {
    if (words.isEmpty) return;

    int maxRow = (words.length - 1) ~/ 3;
    int targetRow = di<AppState>().manualEditRow.value + direction;

    if (targetRow < 0) targetRow = 0;
    if (targetRow > maxRow) targetRow = maxRow;

    di<AppState>().manualEditRow.value = targetRow;
  }

  @override
  Widget build(BuildContext context) {
    final trackWords = watchValue((AppState s) => s.editTrackWords);
    final bool isStandalone = kIsWeb && html.window.matchMedia('(display-mode: standalone)').matches;

    return Container(
      height: isStandalone ? 95.0 : 85.0,
      // 🎯 Added top: 10.0 to push the buttons down 10px
      padding: EdgeInsets.only(top: 10.0, left: 20, right: 20, bottom: isStandalone ? 15.0 : 5.0),
      decoration: const BoxDecoration(
        color: Colors.black,
        // 🎯 Changed border line to lightBlue
        border: Border(top: BorderSide(color: Colors.lightBlue, width: 2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ⏪ PREV BUTTON
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade900,
                // 🎯 Reduced vertical padding from 15 to 5 to shrink height by 20px
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ),
            icon: const Icon(Icons.fast_rewind, color: Colors.white, size: 24),
            label: const Text("PREV", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            onPressed: () => _jump(-1, trackWords),
          ),

          // ⏩ NEXT BUTTON
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlue,
                // 🎯 Reduced vertical padding from 15 to 5 to shrink height by 20px
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ),
            label: const Text("NEXT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
            icon: const Icon(Icons.fast_forward, color: Colors.black, size: 24),
            onPressed: () => _jump(1, trackWords),
          ),
        ],
      ),
    );
  }
}

