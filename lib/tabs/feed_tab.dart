import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:watch_it/watch_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:html' as html;
import 'dart:js_interop';

import '../common/common.dart';
import '../app_state.dart';

class FeedTab extends StatefulWidget {
  const FeedTab({super.key});

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  List<Map<String, dynamic>> _feedVideos = [];
  bool _isLoadingFeed = true;
  late PageController _pageController;

  final ValueNotifier<int> _currentScrollNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> _isGlobalMuted = ValueNotifier<bool>(true);

  String? _pendingPhone;
  String? _authCode;
  final TextEditingController _phoneController = TextEditingController();
  bool _hasSwipedFeed = false;


  int _getActual(int i) {
    if (_feedVideos.isEmpty) return 0;
    return (i % _feedVideos.length + _feedVideos.length) % _feedVideos.length;
  }

  @override
  void initState() {
    super.initState();
    _fetchFeedFromFirebase();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) setState(() => _hasSwipedFeed = prefs.getBool('has_swiped_feed') ?? false);
    });
  }

  Future<void> _fetchFeedFromFirebase({int retryCount = 0}) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('feeds')
          .orderBy('index', descending: false)
          .get();

      final List<Map<String, dynamic>> loadedVideos = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'url': data['url'] ?? '',
          'title': data['title'] ?? '',
          'subtitle': data['subtitle'] ?? '',
          'thumb': data['thumb'] ?? '',
          'like_count': data['like_count'] ?? 0,
          'isLocked': data['isLocked'] == true || data['isLocked'] == 'true',
        };
      }).toList();

      if (mounted) {
        setState(() {
          _feedVideos = loadedVideos;
          _isLoadingFeed = false;
        });

        if (_feedVideos.isNotEmpty) {
          int startingIndex = 0;
          if (kIsWeb) {
            try {
              final metaTag = html.document.querySelector('meta[name="video-index"]');
              if (metaTag != null) {
                final content = metaTag.attributes['content'];
                if (content != null) startingIndex = int.tryParse(content) ?? 0;
              } else {
                final uri = Uri.base;
                String? videoParam = uri.queryParameters['v'];
                if (videoParam != null) startingIndex = int.tryParse(videoParam) ?? 0;
              }
            } catch (_) {}

            if (startingIndex >= _feedVideos.length || startingIndex < 0) {
              startingIndex = 0;
            }
          }

          int virtualMiddleIndex = (_feedVideos.length * 500) + startingIndex;
          _currentScrollNotifier.value = virtualMiddleIndex;
          _pageController = PageController(initialPage: virtualMiddleIndex);
        }
      }
    } catch (e) {
      print("🚨 FAILED TO LOAD FEED (Attempt ${retryCount + 1}): $e");

      // Auto-retry up to 3 times with a short delay if the initial reload fails
      if (retryCount < 3 && mounted) {
        await Future.delayed(const Duration(milliseconds: 600));
        return _fetchFeedFromFirebase(retryCount: retryCount + 1);
      }

      if (mounted) setState(() => _isLoadingFeed = false);
    }
  }

  void _setGlobalMute(bool isMuted) async {
    if (_isGlobalMuted.value == isMuted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('feed_is_muted', isMuted);
    _isGlobalMuted.value = isMuted;
  }

  @override
  void dispose() {
    if (_feedVideos.isNotEmpty) _pageController.dispose();
    _phoneController.dispose();
    _currentScrollNotifier.dispose();
    _isGlobalMuted.dispose();
    super.dispose();
  }

  void _showA2HSBottomSheet() async {
    if (di<AppState>().a2hsCount.value > 0) return;
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.85),
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (BuildContext modalContext) {
        return Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network('icons/Icon-192.png', width: 72, height: 72, errorBuilder: (context, error, stackTrace) => const Icon(Icons.shield, size: 72, color: Colors.blueAccent)),
                ),
              ),
              const SizedBox(height: 20),
              Text("desktop_sheet_title".tr(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text("desktop_sheet_desc".tr(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 15, height: 1.4)),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: Text("desktop_sheet_btn".tr(), style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: () => Navigator.pop(modalContext),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showVerificationBottomSheet() {
    setState(() {
      _pendingPhone = null;
      _authCode = null;
      _phoneController.clear();
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.85),
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext bottomSheetContext) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: StatefulBuilder(
            builder: (statefulContext, setModalState) {
              if (_pendingPhone != null && _authCode != null) {
                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('citizens').doc(_pendingPhone).snapshots(),
                  builder: (streamContext, snapshot) {
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final Map<String, dynamic>? data = snapshot.data!.data() as Map<String, dynamic>?;

                      var v = data?['verified'];
                      if (data != null && (v == true || v == 'true') && _pendingPhone != null) {
                        final String verifiedPhone = _pendingPhone!;
                        final String masterUid = data['uid'] ?? generateSecureToken();

                        WidgetsBinding.instance.addPostFrameCallback((_) async {
                          if (_pendingPhone == null) return;

                          setState(() {
                            _pendingPhone = null;
                            _authCode = null;
                          });

                          Navigator.of(bottomSheetContext).pop();
                          await di<AppState>().savePhone(verifiedPhone);

                          if (mounted) {
                            Future.delayed(const Duration(milliseconds: 400), () {
                              if (mounted) setState(() {});
                            });
                          }
                        });
                      }
                    }

                    return GestureDetector(
                      onTap: () {},
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(statefulContext).viewInsets.bottom + 30,
                          top: 30,
                          left: 30,
                          right: 30,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(Icons.lock_outline, size: 80, color: Colors.orangeAccent),
                            const SizedBox(height: 20),
                            Text("verifyAccountTitle".tr(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 15),
                            Text("tapToAuthenticate".tr(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 16, height: 1.4)),
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
                                  icon: Icon(isLocked ? Icons.timer : Icons.chat_bubble_outline, color: !isLocked ? const Color(0xff010126) : Colors.white),
                                  label: Text(
                                    isLocked ? "${'verify_locked_btn'.tr()}${secondsLeft.toString().padLeft(2, '0')}" : "verify_whatsapp_btn".tr(),
                                    style: TextStyle(color: !isLocked ? const Color(0xff010126) : Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: isLocked ? () {
                                    _showTopToast(statefulContext, "verify_toast_locked".tr());
                                  } : () async {
                                    di<AppState>().registerAuthAttempt();
                                    const burnerPhone = "972525822005";
                                    String instruction = "whatsappVerifyMsg".tr();
                                    String whatsappMessage = "$_authCode $instruction";
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
                                setModalState(() {
                                  setState(() {
                                    _pendingPhone = null;
                                    _authCode = null;
                                    _phoneController.clear();
                                  });
                                });
                              },
                              child: Text("change_phone_btn".tr(), style: const TextStyle(color: Colors.grey, fontSize: 14)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }

              return GestureDetector(
                onTap: () {},
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(statefulContext).viewInsets.bottom + 30,
                    top: 30,
                    left: 30,
                    right: 30,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.shield, size: 80, color: Colors.blueAccent),
                      const SizedBox(height: 20),
                      Text("map_dialog_title".tr(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 15),
                      Text("map_verification_subtitle".tr(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 16, height: 1.4)),
                      const SizedBox(height: 40),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        keyboardAppearance: Brightness.dark,
                        style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 2),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: "capture_hint".tr(),
                          hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5), fontSize: 16, letterSpacing: 0),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                          prefixIcon: const Icon(Icons.phone_android, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(statefulContext).primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text("map_verify_action_btn".tr(), style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        onPressed: () async {
                          FocusScope.of(statefulContext).unfocus();
                          String contactInfo = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');

                          if (contactInfo.length < 9) {
                            _showError("capture_error_phone".tr());
                            return;
                          }

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
                              Navigator.of(bottomSheetContext).pop();
                              await di<AppState>().savePhone(contactInfo);
                              setState(() {});
                              return;
                            }

                            String newAuthCode = generateSecureToken();
                            await FirebaseFirestore.instance.collection('citizens').doc(contactInfo).set({
                              'phone': contactInfo,
                              'uid': masterUid,
                              'auth_code': newAuthCode,
                              'verified': false,
                              'a2hs_count': currentA2hs,
                            }, SetOptions(merge: true));

                            setModalState(() {
                              setState(() {
                                _pendingPhone = contactInfo;
                                _authCode = newAuthCode;
                              });
                            });
                          } catch (e) {
                            _showError("map_err_save".tr());
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showTopToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height - 150, left: 20, right: 20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: Colors.black,
      // floatingActionButton: FloatingActionButton.extended(
      //   backgroundColor: Colors.redAccent,
      //   label: const Text("MIGRATE DB", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      //   icon: const Icon(Icons.rocket_launch, color: Colors.white),
      //   onPressed: () async {
      //     print("🚀 Starting database migration...");
      //     final snapshot = await FirebaseFirestore.instance.collection('feeds').get();
      //
      //     // 🛑 REPLACE THIS WITH YOUR REAL CLOUDFLARE URL BASE 🛑
      //     // Make sure it ends with a slash!
      //     const String cloudflareBaseUrl = "https://pub-142306085f2b48bda4045cd9efdd0d28.r2.dev/";
      //
      //     int count = 0;
      //     for (var doc in snapshot.docs) {
      //       String currentUrl = doc.data()['url']?.toString() ?? '';
      //
      //       // Only update it if it's still using the old local asset path
      //       if (currentUrl.startsWith('assets/')) {
      //         // Grabs just the filename (e.g. "vid1.mp4" from "assets/videos/vid1.mp4")
      //         String fileName = currentUrl.split('/').last;
      //         String newUrl = "$cloudflareBaseUrl$fileName";
      //
      //         await doc.reference.update({'url': newUrl});
      //         print("✅ Updated ${doc.id} -> $newUrl");
      //         count++;
      //       }
      //     }
      //     print("🎉 MIGRATION COMPLETE! $count videos updated.");
      //   },
      // ),
      // // 👆 END TEMPORARY BUTTON 👆
      body: Center(
        child: SizedBox(
          width: isDesktop ? 650 : double.infinity,
          height: double.infinity,
          child: _isLoadingFeed
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)))
              : _feedVideos.isEmpty
              ? const Center(child: Text("No videos found.", style: TextStyle(color: Colors.white)))
              : NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (!_hasSwipedFeed && notification is ScrollUpdateNotification) {
                if (notification.scrollDelta != null && notification.scrollDelta!.abs() > 10) {
                  setState(() => _hasSwipedFeed = true);
                  SharedPreferences.getInstance().then((prefs) => prefs.setBool('has_swiped_feed', true));
                }
              }
              if (notification is ScrollEndNotification && _pageController.hasClients) {
                int target = (_pageController.page ?? 0).round();
                if (_currentScrollNotifier.value != target) {
                  _currentScrollNotifier.value = target;
                }
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
              scrollDirection: Axis.vertical,
              itemCount: _feedVideos.length * 1000,
              itemBuilder: (context, rawIndex) {
                int actualIndex = _getActual(rawIndex);

                return ValueListenableBuilder<int>(
                  valueListenable: _currentScrollNotifier,
                  builder: (context, currentIndex, child) {
                    bool isActive = rawIndex == currentIndex;

                    return ValueListenableBuilder<bool>(
                      valueListenable: _isGlobalMuted,
                      builder: (context, isMuted, child) {
                        return ValueListenableBuilder<bool>(
                          valueListenable: di<AppState>().isLoggedIn,
                          builder: (context, isLoggedIn, child) {
                            bool isLocked = (_feedVideos[actualIndex]['isLocked'] == true || _feedVideos[actualIndex]['isLocked'] == 'true') && !isLoggedIn;

                            return FeedVideoPlayer(
                              videoData: _feedVideos[actualIndex],
                              isLocked: isLocked,
                              isVisible: isActive,
                              isMuted: isMuted,
                              hasSwipedFeed: _hasSwipedFeed, // 🔥 Pass the state down
                              onToggleMute: (muteState) => _setGlobalMute(muteState),
                              onUnlockTap: _showVerificationBottomSheet,
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// 🎬 BULLETPROOF HARD-RESET & AUTO-KICK WATCHDOG ENGINE
class FeedVideoPlayer extends StatefulWidget {
  final Map<String, dynamic> videoData;
  final bool isLocked;
  final VoidCallback onUnlockTap;
  final bool isMuted;
  final ValueChanged<bool> onToggleMute;
  final bool isVisible;
  final bool hasSwipedFeed; // 🔥 The new state passed from parent

  const FeedVideoPlayer({
    super.key,
    required this.isVisible,
    required this.videoData,
    required this.isLocked,
    required this.onUnlockTap,
    required this.isMuted,
    required this.onToggleMute,
    required this.hasSwipedFeed, // 🔥 The new state
  });

  @override
  State<FeedVideoPlayer> createState() => _FeedVideoPlayerState();
}

class _FeedVideoPlayerState extends State<FeedVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isPlaying = false;
  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _showUi = true;
  Timer? _uiHideTimer;

  bool _isShowingSwipeGate = false; // 🔥 The Grandpa Gate state

  late int likeCount;

  @override
  void initState() {
    super.initState();
    likeCount = widget.videoData['like_count'] is int
        ? widget.videoData['like_count']
        : int.tryParse(widget.videoData['like_count']?.toString() ?? '0') ?? 0;

    if (widget.isVisible) {
      _initAndPlay();
    }
  }

  void _startUiHideTimer() {
    _uiHideTimer?.cancel();
    _uiHideTimer = Timer(const Duration(milliseconds: 3000), () {
      if (mounted && _isPlaying) {
        setState(() => _showUi = false);
      }
    });
  }

  String _formatLikes(int likes) {
    if (likes >= 1000000) return '${(likes / 1000000).toStringAsFixed(1)}m';
    if (likes >= 1000) return '${(likes / 1000).toStringAsFixed(1)}k';
    return likes.toString();
  }

  Future<void> _syncLikeToFirebase(bool isNowLiked, String videoId) async {
    final String? phone = di<AppState>().userPhone.value;
    if (phone == null || phone.isEmpty || videoId.isEmpty) return;

    final firestore = FirebaseFirestore.instance;
    try {
      if (isNowLiked) {
        await Future.wait([
          firestore.collection('feeds').doc(videoId).set({'like_count': FieldValue.increment(1)}, SetOptions(merge: true)),
          firestore.collection('citizens').doc(phone).set({'saved_clips': FieldValue.arrayUnion([videoId])}, SetOptions(merge: true)),
        ]);
      } else {
        await Future.wait([
          firestore.collection('feeds').doc(videoId).set({'like_count': FieldValue.increment(-1)}, SetOptions(merge: true)),
          firestore.collection('citizens').doc(phone).set({'saved_clips': FieldValue.arrayRemove([videoId])}, SetOptions(merge: true)),
        ]);
      }
    } catch (e) {
      print("🚨 Failed to sync like to Firebase: $e");
    }
  }

  void _toggleUiVisibility() {
    setState(() {
      _showUi = !_showUi;
    });
    if (_showUi) {
      _startUiHideTimer();
    } else {
      _uiHideTimer?.cancel();
    }
  }

  void _onUserInteraction() {
    if (!_showUi) {
      setState(() => _showUi = true);
    }
    _startUiHideTimer();
  }

  @override
  void didUpdateWidget(FeedVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isVisible && !oldWidget.isVisible) {
      _initAndPlay();
    } else if (!widget.isVisible && oldWidget.isVisible) {
      _disposeController();
    }

    if (_isInitialized && _controller != null && widget.isMuted != oldWidget.isMuted) {
      _controller!.setVolume(widget.isMuted ? 0.0 : 1.0);
    }
  }

  void _triggerTutorialGate(VideoPlayerController ctrl) {
    if (!mounted || !widget.isVisible) return;
    setState(() => _isShowingSwipeGate = true);

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && widget.isVisible && _controller == ctrl) {
        setState(() => _isShowingSwipeGate = false);
        ctrl.seekTo(Duration.zero);

        ctrl.play().then((_) {
          if (!mounted || _controller != ctrl) return;
          _startUiHideTimer();

          if (!widget.isMuted) {
            Future.delayed(const Duration(milliseconds: 150), () {
              if (mounted && _controller == ctrl && widget.isVisible) {
                ctrl.setVolume(1.0);
              }
            });
          }

          // 🐕 WATCHDOG: Catch the silent browser block caused by the 2-second delay
          Future.delayed(const Duration(milliseconds: 450), () {
            if (mounted && widget.isVisible && _controller == ctrl && _isInitialized) {
              if (!ctrl.value.isPlaying) {
                print("🐕 Watchdog auto-kick triggered after gate!");
                ctrl.setVolume(widget.isMuted ? 0.0 : 1.0);
                ctrl.play().catchError((_) {
                  // Do not loop here. If it hard-fails, the user can just tap the screen to play.
                });
              }
            }
          });

        }).catchError((_) {
          // Do not loop here. Let it fail gracefully so the play button stays visible.
          print("🚨 Autoplay blocked by browser after 2-second delay");
        });
      }
    });
  }

  void _initAndPlay() {
    if (widget.isLocked || _isInitializing) return;

    if (_controller != null && _isInitialized) {
      _controller!.setVolume(widget.isMuted ? 0.0 : 1.0);
      if (!widget.hasSwipedFeed) {
        _triggerTutorialGate(_controller!);
      } else {
        _controller!.play().then((_) {
          _startUiHideTimer();
        }).catchError((_) {
          _disposeController();
          _initAndPlay();
        });
      }
      return;
    }

    _isInitializing = true;
    final url = widget.videoData['url'].toString();
    if (url.isEmpty) {
      _isInitializing = false;
      return;
    }

    final newController = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = newController;

    newController.initialize().then((_) {
      if (!mounted || !widget.isVisible || _controller != newController) {
        newController.dispose();
        if (_controller == newController) _controller = null;
        _isInitializing = false;
        return;
      }

      setState(() => _isInitialized = true);
      _isInitializing = false;

      // 🔥 DISABLE LOOPING SO WE CAN HIJACK IT
      newController.setLooping(false);
      newController.setVolume(widget.isMuted ? 0.0 : 1.0);

      newController.addListener(() {
        if (!mounted || _controller != newController) return;

        bool actualPlaying = newController.value.isPlaying;

        if (actualPlaying && newController.value.position == Duration.zero) {
          actualPlaying = false;
        }

        if (_isPlaying != actualPlaying) {
          setState(() => _isPlaying = actualPlaying);
        }

        // 🔥 HIJACK THE END OF THE VIDEO
        if (newController.value.isInitialized &&
            newController.value.duration > Duration.zero &&
            newController.value.position >= newController.value.duration) {
          if (!widget.hasSwipedFeed) {
            _triggerTutorialGate(newController);
          } else {
            newController.seekTo(Duration.zero);
            newController.play();
          }
        }
      });

      if (!widget.hasSwipedFeed) {
        _triggerTutorialGate(newController);
      } else {
        newController.play().then((_) {
          if (!mounted || _controller != newController) return;
          _startUiHideTimer();

          if (!widget.isMuted) {
            Future.delayed(const Duration(milliseconds: 150), () {
              if (mounted && _controller == newController && widget.isVisible) {
                newController.setVolume(1.0);
              }
            });
          }

          Future.delayed(const Duration(milliseconds: 450), () {
            if (mounted && widget.isVisible && _controller == newController && _isInitialized) {
              if (!_controller!.value.isPlaying) {
                _controller!.setVolume(widget.isMuted ? 0.0 : 1.0);
                _controller!.play().catchError((_) {
                  _disposeController();
                  _initAndPlay();
                });
              }
            }
          });
        }).catchError((e) {
          if (mounted && _controller == newController) {
            _disposeController();
          }
        });
      }
    }).catchError((e) {
      if (mounted && _controller == newController) {
        _isInitializing = false;
        _controller = null;
        newController.dispose();
      }
    });
  }

  void _disposeController() {
    _uiHideTimer?.cancel();
    _isInitializing = false;
    final oldController = _controller;
    _controller = null;
    _isInitialized = false;
    _isPlaying = false;
    if (oldController != null) {
      oldController.pause();
      Future.microtask(() => oldController.dispose());
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String thumbUrl = widget.videoData['thumb']?.toString() ?? '';
    final String videoId = widget.videoData['id']?.toString() ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black),

        // Video Layer
        if (_isInitialized && _controller != null)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width > 0 ? _controller!.value.size.width : 100,
              height: _controller!.value.size.height > 0 ? _controller!.value.size.height : 100,
              child: VideoPlayer(_controller!),
            ),
          ),

        // 🖼️ Thumbnail Shield
        AnimatedOpacity(
          opacity: (_isInitialized && _isPlaying) ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            color: Colors.black, // Fills top/bottom letterboxes with solid black
            alignment: Alignment.center,
            child: thumbUrl.isNotEmpty
                ? Image.network(thumbUrl, fit: BoxFit.fitWidth)
                : const SizedBox.expand(),
          ),
        ),

        // 🛑 THE 2-SECOND GRANDPA GATE
// 🛑 THE 2-SECOND GRANDPA GATE
        // 🛑 THE 2-SECOND GRANDPA GATE
        if (_isShowingSwipeGate)
          Container(
            color: Colors.black.withOpacity(0.95),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.elasticOut, // Creates a natural physical bounce
                  builder: (context, val, child) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: val * 40), // Physically moves the icon up
                      child: const Icon(Icons.touch_app, color: Colors.amber, size: 90),
                    );
                  },
                ),
                const SizedBox(height: 15),
                Text(
                  "tutorial_swipe_up".tr(),
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  "tutorial_video_starts_shortly".tr(),
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          ),

        // Loading Spinner
        if ((!_isInitialized || _isInitializing) && widget.isVisible && !widget.isLocked)
          const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),

        // 🏷️ DEBUG OVERLAY: Identifies the black screen video (0.4 Opacity)
        // Center(
        //   child: IgnorePointer(
        //     child: Opacity(
        //       opacity: 0.4,
        //       child: Padding(
        //         padding: const EdgeInsets.symmetric(horizontal: 20),
        //         child: Column(
        //           mainAxisSize: MainAxisSize.min,
        //           children: [
        //             Text(
        //               widget.videoData['title']?.toString().isNotEmpty == true
        //                   ? widget.videoData['title'].toString()
        //                   : "No Title",
        //               textAlign: TextAlign.center,
        //               style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        //             ),
        //             const SizedBox(height: 8),
        //             Text(
        //               "Document: ${widget.videoData['id']}", // Shows the exact Firestore doc name
        //               textAlign: TextAlign.center,
        //               style: const TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold),
        //             ),
        //           ],
        //         ),
        //       ),
        //     ),
        //   ),
        // ),

        // 🛡️ HARD-RESET TAP DETECTOR
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (widget.isLocked) {
                widget.onUnlockTap();
                return;
              }

              if (_controller == null || !_isInitialized || !_controller!.value.isInitialized) {
                _disposeController();
                _initAndPlay();
              } else {
                if (_controller!.value.isPlaying) {
                  _controller!.pause();
                  setState(() => _isPlaying = false);
                } else {
                  _controller!.setVolume(widget.isMuted ? 0.0 : 1.0);
                  _controller!.play().catchError((_) {
                    _disposeController();
                    _initAndPlay();
                  });
                  setState(() => _isPlaying = true);
                }
              }
              _toggleUiVisibility();
            },
            child: const SizedBox.expand(),
          ),
        ),

        // Censored Overlay
        if (widget.isLocked)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.4),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_person, size: 70, color: Colors.redAccent),
                      const SizedBox(height: 15),
                      Text("secure_verification_title".tr().toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      Text("secure_verification_desc".tr(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
                        icon: const Icon(Icons.lock_open, size: 28),
                        label: Text("verifyAccountTitle".tr().toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        onPressed: widget.onUnlockTap,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Fading Gradient Background (Fades to 30%)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 120,
          child: AnimatedOpacity(
            opacity: _showUi ? 1.0 : 0.3,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !_showUi,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Action Buttons Row (Fades to 30%, always clickable)
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom,
          left: 15,
          right: 15,
          child: AnimatedOpacity(
            opacity: _showUi ? 1.0 : 0.3,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: false,
              child: Directionality(
                textDirection: ui.TextDirection.ltr,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ValueListenableBuilder<List<String>>(
                      valueListenable: di<AppState>().savedClips,
                      builder: (context, savedClipsList, child) {
                        final bool isLiked = savedClipsList.contains(videoId);
                        return ValueListenableBuilder<bool>(
                          valueListenable: di<AppState>().isLoggedIn,
                          builder: (context, isLoggedIn, child) {
                            return _buildActionButton(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              _formatLikes(likeCount),
                              isLiked ? Colors.red : Colors.white,
                              onTap: () {
                                _onUserInteraction();
                                if (!isLoggedIn) {
                                  widget.onUnlockTap();
                                  return;
                                }

                                final currentClips = List<String>.from(savedClipsList);
                                setState(() {
                                  if (isLiked) {
                                    currentClips.remove(videoId);
                                    likeCount = (likeCount > 0) ? likeCount - 1 : 0;
                                  } else {
                                    currentClips.add(videoId);
                                    likeCount += 1;
                                  }
                                });

                                di<AppState>().savedClips.value = currentClips;
                                _syncLikeToFirebase(!isLiked, videoId);
                              },
                            );
                          },
                        );
                      },
                    ),
                    _buildActionButton(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        _isPlaying ? "pause_btn".tr() : "play_btn".tr(),
                        Colors.white,
                        onTap: () {
                          _onUserInteraction();
                          if (widget.isLocked) {
                            widget.onUnlockTap();
                          } else if (_controller == null || !_isInitialized || !_controller!.value.isInitialized) {
                            _disposeController();
                            _initAndPlay();
                          } else {
                            if (_controller!.value.isPlaying) {
                              _controller!.pause();
                              setState(() => _isPlaying = false);
                            } else {
                              _controller!.setVolume(widget.isMuted ? 0.0 : 1.0);
                              _controller!.play().catchError((_) {
                                _disposeController();
                                _initAndPlay();
                              });
                              setState(() => _isPlaying = true);
                            }
                          }
                        }
                    ),
                    _buildActionButton(
                        widget.isMuted ? Icons.volume_off : Icons.volume_up,
                        "sound_btn".tr(),
                        Colors.white,
                        onTap: () {
                          _onUserInteraction();
                          if (widget.isLocked) {
                            widget.onUnlockTap();
                          } else {
                            widget.onToggleMute(!widget.isMuted);
                          }
                        }
                    ),
                    _buildActionButton(Icons.share, 'feed_share_btn'.tr(), Colors.white, onTap: () async {
                      _onUserInteraction();
                      final String title = widget.videoData['title']?.toString() ?? '';
                      final String shareTitle = title.isNotEmpty ? title : "app_name".tr();

                      String rawUrl = widget.videoData['url']?.toString() ?? "";
                      String htmlFileName = rawUrl.split('/').last.replaceAll('.mp4', '.html');
                      String exactLink = "https://gamfeiglintzadak.co.il/$htmlFileName";

                      final String contentToShare = "$shareTitle\n\n$exactLink";
                      await Share.share(contentToShare);
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 35),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}