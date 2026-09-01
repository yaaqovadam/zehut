import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:zehut_app/tabs/feed_tab.dart';
import 'common/common.dart';
import 'app_state.dart';
import 'tabs/plan_tab.dart'; // Add this import
import 'tabs/action_tab.dart'; // Make sure this is imported!
import 'tabs/vanguard_tab.dart'; // <--- Make sure this is here!
import 'package:web/web.dart' as web;
// By extending WatchingWidget, we can listen to GetIt seamlessly
class MainShell extends WatchingWidget {
  const MainShell({super.key});


  @override
  Widget build(BuildContext context) {
    final currentIndex = watchValue((AppState s) => s.navIndex);

    // 1. Is this a mobile phone? (iOS or Android)
    final bool isMobileDevice = defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android;

    // 2. THE FILTER: Is this a regular Safari/Chrome browser tab?
    // Safari tabs block the notch, so top padding is exactly 0.
    // The installed Home Screen App bleeds behind the battery/clock, so top padding is > 0.
    final bool isMobileBrowserTab = kIsWeb && isMobileDevice && MediaQuery.of(context).padding.top == 0;

    // 3. YOUR RULE: Apply 20px lift IF it's a mobile device, BUT ONLY IF it is NOT a regular browser tab.
    // Desktop apps get 0. Browser tabs get 0. ONLY the installed mobile app gets 20.
    // final double customBottomPadding = (isMobileDevice && !isMobileBrowserTab) ? 20.0 : 0.0;
    bool isPWA = false;
    if (kIsWeb) {
      isPWA = web.window.matchMedia('(display-mode: standalone)').matches;
    }

    // YOUR RULE: 34px (Apple's exact line height) for the installed app. 0px for Safari/Chrome tabs.
    final double customBottomPadding = isPWA ?20.0 : 0.0;

    final List<Widget> views = [
      const FeedTab(),
      const VanguardTab(),
      const PlanTab(),
      const ActionTab(),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Let the flexible space handle the color
        elevation: 0, // 👈 Turn off default symmetric shadow
        surfaceTintColor: Colors.transparent,

        // 👇 THE NEW CUSTOM SHADOW & BORDER 👇
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
                offset: const Offset(0, 5), // 👈 Pushed exactly 5px downwards!
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
          )
        ],
      ),
      body: views[currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          // 👇 Darker, thicker top line 👇
          border: Border(
            top: BorderSide(
              color: const Color(0xFF103856).withOpacity(0.3), // Darker Navy
              width: 2.0,
            ),
          ),
          // 👇 Bigger, taller, darker shadow 👇
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25), // Darker shadow (increased from 0.08)
              offset: const Offset(0, -8), // Taller shadow (pushes further up the screen)
              blurRadius: 24, // Wider, softer spread (increased from 12)
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
  }
}


