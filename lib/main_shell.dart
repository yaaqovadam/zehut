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
      backgroundColor: topAndBottomNavigationBarColor,
      appBar: AppBar(
        backgroundColor: topAndBottomNavigationBarColor,
        elevation: 0,
        title: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom:12.0),
              child: Image.asset('assets/images/zahut-logo.png', height: 35),
            ),
            const SizedBox(width: 10),
            Text(
              'app_name'.tr(),
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w900,
                fontSize: 26,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.language, color: Theme.of(context).primaryColor),
            onPressed: () {
              if (context.locale.languageCode == 'he') {
                context.setLocale(const Locale('en'));
              } else {
                context.setLocale(const Locale('he'));
              }
            },
          )
        ],
      ),
      body: views[currentIndex],

      // 👇 THE SURGICAL LIFT 👇
      bottomNavigationBar: Container(
        color: topAndBottomNavigationBarColor,

        // Injects the 20px ONLY on the Home Screen app
        padding: EdgeInsets.only(bottom: customBottomPadding),

        child: MediaQuery.removePadding(
          context: context,
          removeBottom: true, // Kills the engine's broken background math
          child: BottomNavigationBar(
            backgroundColor: topAndBottomNavigationBarColor,
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
          ),
        ),
      ),
    );
  }
}


