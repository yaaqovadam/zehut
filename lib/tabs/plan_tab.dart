import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../common/common.dart';
import '../app_state.dart';
import 'package:watch_it/watch_it.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlanTab extends StatefulWidget {
  const PlanTab({super.key});

  @override
  State<PlanTab> createState() => _PlanTabState();
}

class _PlanTabState extends State<PlanTab> {
  final CardSwiperController controller = CardSwiperController();
  bool isFinished = false;
  final TextEditingController _contactController = TextEditingController();
  final Key _swiperKey = UniqueKey();
  String? _pendingPhone;
  String? _authCode;

  int _score = 0;
  final List<bool> _swipeHistory = [];

  final List<Map<String, dynamic>> _policies = [
    {"day": "pol_1_day", "title": "pol_1_title", "desc": "pol_1_desc", "icon": Icons.military_tech, "color": const Color(0xFFB91C1C)},
    {"day": "pol_8_day", "title": "pol_8_title", "desc": "pol_8_desc", "icon": Icons.gavel, "color": const Color(0xFFE11D48)},
    {"day": "pol_2_day", "title": "pol_2_title", "desc": "pol_2_desc", "icon": Icons.shield, "color": const Color(0xFFF59E0B)},
    {"day": "pol_6_day", "title": "pol_6_title", "desc": "pol_6_desc", "icon": Icons.hearing_disabled, "color": const Color(0xFF9333EA)},
    {"day": "pol_3_day", "title": "pol_3_title", "desc": "pol_3_desc", "icon": Icons.security, "color": const Color(0xFF3B82F6)},
    {"day": "pol_7_day", "title": "pol_7_title", "desc": "pol_7_desc", "icon": Icons.warning_amber_rounded, "color": const Color(0xFFF97316)},
    {"day": "pol_4_day", "title": "pol_4_title", "desc": "pol_4_desc", "icon": Icons.shopping_cart_checkout, "color": const Color(0xFF10B981)},
    {"day": "pol_5_day", "title": "pol_5_title", "desc": "pol_5_desc", "icon": Icons.flag, "color": const Color(0xFFD4AF37)},
  ];

  @override
  void dispose() {
    controller.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _showA2HSBottomSheet(BuildContext parentContext) async {
    if (di<AppState>().a2hsCount.value > 0) {
      debugPrint("Skipping A2HS prompt. Count is ${di<AppState>().a2hsCount.value}");
      return;
    }

    String? phone = di<AppState>().userPhone.value;
    if (phone != null && phone.isNotEmpty) {
      await di<AppState>().markA2HSPrompted(phone);
    }

    if (!parentContext.mounted) return;

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.85),
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext modalContext) {
        return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    'icons/Icon-192.png',
                    width: 72,
                    height: 72,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.shield, size: 72, color: Colors.blueAccent),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "התנתק מהדפדפן. הישאר מחובר לרשת.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                "הוסף את 'זהות' למסך הבית שלך לגישה מהירה, מוצפנת וללא צנזורה - בדיוק כמו אפליקציה רגילה.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Column(
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.ios_share, color: Colors.amber, size: 22),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "1. לחץ על כפתור השיתוף (Share) בדפדפן",
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.add_box_outlined, color: Colors.amber, size: 22),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "2. בחר 'אל מסך הבית' (Add to Home Screen)",
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text(
                  "הבנתי, המשך לאפליקציה",
                  style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: () => Navigator.pop(modalContext),
              ),
            ],
          ),
            ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ValueListenableBuilder<bool>(
          valueListenable: di<AppState>().isLoggedIn,
          builder: (context, isLoggedIn, child) {
            bool showCaptureWall = isFinished && !isLoggedIn;

            return Column(
              children: [
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        "plan_title".tr(),
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Theme.of(context).primaryColor),
                      ),
                      if (showCaptureWall)
                        PositionedDirectional(
                          start: 0,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.close, color: Colors.grey, size: 30),
                            onPressed: () {
                              FocusScope.of(context).unfocus();
                              setState(() => isFinished = false);
                              Future.delayed(const Duration(milliseconds: 50), () {
                                if (_swipeHistory.isNotEmpty) controller.undo();
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Stack(
                    children: [
                      Offstage(
                        offstage: isFinished,
                        child: _buildSwiper(),
                      ),
                      if (showCaptureWall)
                        _buildCaptureScreen(),
                      if (isFinished && isLoggedIn)
                        _buildEndScreen(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSwiper() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            // 🔥 ELEVATION FIX: Removed top padding to pull the deck up!
            padding: const EdgeInsets.only(bottom: 20.0),
            child: CardSwiper(
              controller: controller,
              key: _swiperKey,
              cardsCount: _policies.length,
              isLoop: false,
              allowedSwipeDirection: const AllowedSwipeDirection.all(),
              numberOfCardsDisplayed: 3,
              backCardOffset: const Offset(0, 30),
              // 🔥 ELEVATION FIX: Dropped top padding from 25 to 0.
              padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 0, bottom: 25.0),
              cardBuilder: (context, index, x, y) {
                return _SmartPolicyCard(
                  policy: _policies[index],
                  isFirstCard: index == 0, // 🔥 THE TRIGGER FOR THE GHOST NUDGE
                );
              },
              onSwipe: _onSwipe,
              onUndo: _onUndo,
              onEnd: () async {
                setState(() {
                  isFinished = true;
                });

                if (di<AppState>().isLoggedIn.value) {
                  String? knownPhone = di<AppState>().userPhone.value;
                  if (knownPhone != null) {
                    int matchPercentage = (_score / _policies.length * 100).round();
                    await FirebaseFirestore.instance.collection('citizens').doc(knownPhone).set({
                      'phone': knownPhone,
                      'match_percentage': matchPercentage,
                      'source': 'swipe_quiz_tab3',
                      'timestamp_quiz': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));
                  }
                }
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 23.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton(
                heroTag: "btn_reject",
                onPressed: () => controller.swipe(CardSwiperDirection.left),
                backgroundColor: Colors.red.withOpacity(0.2),
                elevation: 0,
                child: const Icon(Icons.close, color: Colors.red, size: 30),
              ),
              FloatingActionButton.small(
                heroTag: "btn_undo",
                onPressed: () => controller.undo(),
                backgroundColor: Colors.grey.withOpacity(0.2),
                elevation: 0,
                child: const Icon(Icons.undo, color: Colors.grey),
              ),
              FloatingActionButton(
                heroTag: "btn_accept",
                onPressed: () => controller.swipe(CardSwiperDirection.right),
                backgroundColor: Colors.green.withOpacity(0.2),
                elevation: 0,
                child: const Icon(Icons.check, color: Colors.green, size: 30),
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildCaptureScreen() {
    // CAPTURE MAIN CONTEXT SO IT NEVER DIES
    final parentContext = context;

    if (_pendingPhone != null && _authCode != null) {
      return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('citizens').doc(_pendingPhone).snapshots(),
        builder: (streamContext, snapshot) { // RENAMED TO PREVENT SHADOWING
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            var v = data?['verified'];

            if (data != null && (v == true || v == 'true') && _pendingPhone != null) {
              final String verifiedPhone = _pendingPhone!;

              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (_pendingPhone == null) return;

                setState(() {
                  _pendingPhone = null;
                  _authCode = null;
                });

                await di<AppState>().savePhone(verifiedPhone);

                Future.delayed(const Duration(milliseconds: 400), () {
                  // SAFELY CALL USING THE MAIN PARENT CONTEXT
                  if (parentContext.mounted) {
                    _showA2HSBottomSheet(parentContext);
                  }
                });
              });
            }
          }

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_outline, size: 80, color: Colors.orangeAccent),
                  const SizedBox(height: 20),
                  Text(
                    "verify_secure_title".tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    "verify_secure_desc".tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 16, height: 1.4),
                  ),
                  const SizedBox(height: 40),
                  ValueListenableBuilder<int>(
                    valueListenable: di<AppState>().lockoutSeconds,
                    builder: (context, secondsLeft, child) {
                      final bool isLocked = secondsLeft > 0;

                      return ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isLocked ? Colors.redAccent.shade700 : const Color(0xFF25D366),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        icon: Icon(
                          isLocked ? Icons.timer : Icons.chat_bubble_outline,
                          color: !isLocked ? const Color(0xff010126) : Colors.white,
                        ),
                        label: Text(
                          isLocked
                              ? "${'verify_locked_btn'.tr()}${secondsLeft.toString().padLeft(2, '0')}"
                              : "verify_whatsapp_btn".tr(),
                          style: TextStyle(color: !isLocked ? const Color(0xff010126) : Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        onPressed: isLocked ? () {
                          _showTopToast(context, "verify_toast_locked".tr());
                        } : () async {
                          di<AppState>().registerAuthAttempt();
                          const burnerPhone = "972525822005";

                          // 1. Grab the localized string
                          String instruction = "whatsappVerifyMsg".tr();

                          // 2. Build string: Code + EXACTLY ONE SPACE + Instruction
                          String whatsappMessage = "$_authCode $instruction";

                          // 3. Encode to prevent URL breaking
                          String encodedMessage = Uri.encodeComponent(whatsappMessage);

                          final url = Uri.parse("https://wa.me/$burnerPhone?text=$encodedMessage");
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 15),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _pendingPhone = null;
                        _authCode = null;
                        _contactController.clear();
                      });
                    },
                    child: Text(
                      "change_phone_btn".tr(),
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.analytics, size: 80, color: Colors.blueAccent),
                  const SizedBox(height: 20),
                  Text(
                    "capture_title".tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    "capture_desc_phone".tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 16, height: 1.4),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Icon(Icons.phone_android, color: Colors.grey),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _contactController,
                            keyboardType: TextInputType.phone,
                            keyboardAppearance: Brightness.dark,

                            // 🔥 FIX 1: Kill the browser's native text overlays
                            enableSuggestions: false,
                            autocorrect: false,

                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              // 🔥 FIX 2: Locks the Canvas text to the HTML DOM height
                              height: 1.15,
                            ),

                            decoration: InputDecoration(
                              hintText: "capture_hint".tr(),
                              hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5), fontSize: 16),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: Text(
                      "capture_btn".tr(),
                      style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      FocusScope.of(context).unfocus();

                      String contactInfo = _contactController.text.replaceAll(RegExp(r'[^0-9]'), '');

                      if (contactInfo.length < 9) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("capture_error_phone".tr(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        return;
                      }

                      int matchPercentage = (_score / _policies.length * 100).round();

                      try {
                        String masterUid = generateSecureToken();
                        DocumentSnapshot citizenDoc = await FirebaseFirestore.instance.collection('citizens').doc(contactInfo).get();

                        int currentA2hs = 0;
                        bool alreadyVerified = false;

                        if (citizenDoc.exists && citizenDoc.data() != null) {
                          final dataMap = citizenDoc.data() as Map<String, dynamic>;
                          masterUid = dataMap['uid'] ?? masterUid;
                          currentA2hs = dataMap['a2hs_count'] ?? 0;

                          var v = dataMap['verified'];
                          alreadyVerified = (v == true || v == 'true');
                        }

                        if (alreadyVerified) {
                          await FirebaseFirestore.instance.collection('citizens').doc(contactInfo).set({
                            'match_percentage': matchPercentage,
                            'source': 'swipe_quiz_tab3',
                            'timestamp_quiz': FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));

                          await di<AppState>().savePhone(contactInfo);

                          setState(() {
                            _pendingPhone = null;
                            _authCode = null;
                            isFinished = true;
                          });

                          Future.delayed(const Duration(milliseconds: 400), () {
                            if (parentContext.mounted) {
                              _showA2HSBottomSheet(parentContext);
                            }
                          });
                          return;
                        }

                        String newAuthCode = generateSecureToken();
                        await FirebaseFirestore.instance.collection('citizens').doc(contactInfo).set({
                          'phone': contactInfo,
                          'uid': masterUid,
                          'match_percentage': matchPercentage,
                          'source': 'swipe_quiz_tab3',
                          'timestamp_quiz': FieldValue.serverTimestamp(),
                          'auth_code': newAuthCode,
                          'verified': false,
                          'a2hs_count': currentA2hs,
                        }, SetOptions(merge: true));

                        setState(() {
                          _pendingPhone = contactInfo;
                          _authCode = newAuthCode;
                        });
                      } catch (e) {
                        debugPrint("Firebase error: $e");
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  void _showTopToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 150,
          left: 20,
          right: 20,
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  bool _onSwipe(int previousIndex, int? currentIndex, CardSwiperDirection direction) {
    bool agreed = (direction == CardSwiperDirection.right || direction == CardSwiperDirection.top);
    if (agreed) _score++;
    _swipeHistory.add(agreed);
    return true;
  }

  bool _onUndo(int? previousIndex, int currentIndex, CardSwiperDirection direction) {
    if (_swipeHistory.isNotEmpty) {
      bool lastAgreed = _swipeHistory.removeLast();
      if (lastAgreed) _score--;
    }
    return true;
  }

  Widget _buildEndScreen() {
    String titleKey;
    String descKey;
    Color resultColor;

    int matchPercentage = (_score / _policies.length * 100).round();

    if (matchPercentage >= 70) {
      titleKey = "result_high_title";
      descKey = "result_high_desc";
      resultColor = Colors.green;
    } else if (matchPercentage >= 40) {
      titleKey = "result_med_title";
      descKey = "result_med_desc";
      resultColor = Theme.of(context).primaryColor;
    } else {
      titleKey = "result_low_title";
      descKey = "result_low_desc";
      resultColor = Colors.red;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(35),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: resultColor, width: 5),
            ),
            child: Text(
              "$matchPercentage%",
              style: TextStyle(color: resultColor, fontSize: 48, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
          Text("match_score".tr(), style: const TextStyle(color: Colors.grey, fontSize: 18)),
          const SizedBox(height: 10),
          Text(
            titleKey.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              descKey.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 18),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                isFinished = false;
                _score = 0;
                _swipeHistory.clear();
                _contactController.clear();
              });
            },
            icon: const Icon(Icons.refresh, color: Colors.black),
            label: Text("btn_review".tr(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            ),
          )
        ],
      ),
    );
  }
}
// ==========================================
// 🔥 THE NEW SMART POLICY CARD WIDGET
// ==========================================
// 🔥 THE NEW SMART POLICY CARD WIDGET
// ==========================================
class _SmartPolicyCard extends StatefulWidget {
  final Map<String, dynamic> policy;
  final bool isFirstCard;

  const _SmartPolicyCard({required this.policy, required this.isFirstCard});

  @override
  State<_SmartPolicyCard> createState() => _SmartPolicyCardState();
}

class _SmartPolicyCardState extends State<_SmartPolicyCard> with SingleTickerProviderStateMixin {
  bool _isRevealed = false;

  // ANIMATION CONTROLLERS
  late AnimationController _nudgeController;
  late Animation<double> _slideAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();

    // Setup the Ghost Nudge animation physics
    _nudgeController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200)
    );

    // Slides the card 40 pixels right, holds, then elastic snaps back
    _slideAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 40.0).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
      TweenSequenceItem(tween: ConstantTween(40.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 40.0, end: 0.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 50),
    ]).animate(_nudgeController);

    // Slightly tilts the card 0.05 radians to mimic a human dragging it
    _rotateAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.05).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
      TweenSequenceItem(tween: ConstantTween(0.05), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 50),
    ]).animate(_nudgeController);

    // If it's the top card, check if we should play the animation
    if (widget.isFirstCard) {
      _triggerGhostNudge();
    }
  }

  Future<void> _triggerGhostNudge() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTutorial = prefs.getBool('hasSeenSwipeTutorial') ?? false;

    if (!hasSeenTutorial) {
      // Wait a moment for the screen to settle, then fire the animation
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        await _nudgeController.forward();
        // Save to SharedPreferences so they never see it again
        await prefs.setBool('hasSeenSwipeTutorial', true);
      }
    }
  }

  @override
  void dispose() {
    _nudgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _nudgeController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(_slideAnimation.value, 0),
            child: Transform.rotate(
              angle: _rotateAnimation.value,
              child: child,
            ),
          );
        },
        child: GestureDetector(
          onTap: () {
            if (!_isRevealed) {
              setState(() => _isRevealed = true);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: widget.policy["color"].withOpacity(0.5), width: 2),
              boxShadow: [
                BoxShadow(color: widget.policy["color"].withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: widget.policy["color"],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
                  ),
                  child: Text(
                    widget.policy['day'].toString().tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(widget.policy['icon'], size: 70, color: widget.policy["color"]),
                          const SizedBox(height: 20),
                          Text(
                            widget.policy['title'].toString().tr(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 20),
                          AnimatedCrossFade(
                            duration: const Duration(milliseconds: 300),
                            crossFadeState: _isRevealed ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                            firstChild: Column(
                              children: [
                                ShaderMask(
                                  shaderCallback: (Rect bounds) {
                                    return const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.white, Colors.transparent],
                                      stops: [0.3, 1.0],
                                    ).createShader(bounds);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: Text(
                                    widget.policy['desc'].toString().tr(),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    style: const TextStyle(color: Colors.grey, fontSize: 18, height: 1.4),
                                  ),
                                ),
                                const SizedBox(height: 15),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.touch_app, color: widget.policy["color"], size: 22),
                                    const SizedBox(width: 8),
                                    Text(
                                        context.locale.languageCode == 'he' ? "לחץ לקריאה" : "Tap to read",
                                        style: TextStyle(color: widget.policy["color"], fontWeight: FontWeight.bold, fontSize: 16)
                                    ),
                                  ],
                                )
                              ],
                            ),
                            secondChild: Text(
                              widget.policy['desc'].toString().tr(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 18, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}