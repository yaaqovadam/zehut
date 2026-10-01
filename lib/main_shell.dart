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
  // Holds the position ONLY while your finger is on the screen
  double? _dragValue;

  int _calculateFocusGroup(int currentMillis, List<dynamic> trackWords) {
    int lastDroppedTotal = trackWords.lastIndexWhere((w) => w['startMs'] != null);
    if (lastDroppedTotal == -1) return 0;
    int maxDroppedTime = (trackWords[lastDroppedTotal]['startMs'] as num).toInt();

    if (currentMillis >= maxDroppedTime) {
      int nextTarget = lastDroppedTotal + 1;
      return nextTarget >= trackWords.length ? lastDroppedTotal ~/ 3 : nextTarget ~/ 3;
    } else {
      int reviewIndex = trackWords.lastIndexWhere((w) => w['startMs'] != null && ((w['startMs'] as num).toInt()) <= currentMillis);
      return reviewIndex == -1 ? 0 : reviewIndex ~/ 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawController = watchValue((AppState s) => s.editVideoController);
    final waveformUrl = watchValue((AppState s) => s.editWaveformUrl);
    final trackWords = watchValue((AppState s) => s.editTrackWords);

    if (rawController == null) return const SizedBox.shrink();
    final VideoPlayerController controller = rawController;
    final bool isStandalone = kIsWeb && html.window.matchMedia('(display-mode: standalone)').matches;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final currentMillis = controller.value.position.inMilliseconds;
        int totalRows = (trackWords.length / 3).ceil();
        int activeRow = _calculateFocusGroup(currentMillis, trackWords);

        // 🎯 If dragging, show drag position. Otherwise, show video position.
        double displayValue = _dragValue ?? activeRow.clamp(0, totalRows > 0 ? totalRows - 1 : 0).toDouble();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // PLAY / PAUSE BUTTONS
            Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: Colors.lightBlue,
                      size: 40,
                    ),
                    onPressed: () {
                      controller.value.isPlaying ? controller.pause() : controller.play();
                    },
                  ),
                ],
              ),
            ),

            // WAVEFORM SCRUBBER
            Container(
              height: isStandalone ? 75.0 : 65.0,
              padding: EdgeInsets.only(left: 15, right: 15, bottom: isStandalone ? 15.0 : 0.0),
              decoration: const BoxDecoration(
                color: Colors.black,
                border: Border(top: BorderSide(color: Colors.redAccent, width: 2)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.6,
                      child: Image.network(
                        waveformUrl,
                        fit: BoxFit.fill,
                        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                              trackHeight: 12.0, // 🎯 Thicker invisible track to catch hits
                              // 🎯 Massive hit boxes so it never fails a touch event
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 18.0),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 40.0)
                          ),
                          child: Slider(
                            value: displayValue,
                            min: 0.0,
                            max: (totalRows > 0 ? totalRows - 1 : 0).toDouble(),
                            divisions: totalRows > 1 ? totalRows - 1 : 1,
                            activeColor: Colors.redAccent,
                            inactiveColor: Colors.white38,

                            // 🎯 1. Stops the dot from fighting you when you touch it
                            onChangeStart: (val) {
                              setState(() { _dragValue = val; });
                            },

                            // 🎯 2. Updates visually while your finger moves
                            onChanged: (val) {
                              setState(() { _dragValue = val; });
                            },

                            // 🎯 3. Jumps the video ONLY when you let go
                            onChangeEnd: (val) {
                              int targetRow = val.toInt();
                              int wordIndex = targetRow * 3;
                              if (wordIndex < trackWords.length && trackWords[wordIndex]['startMs'] != null) {
                                int targetMs = (trackWords[wordIndex]['startMs'] as num).toInt();
                                controller.seekTo(Duration(milliseconds: targetMs));
                              }
                              // Release the drag lock
                              setState(() { _dragValue = null; });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

