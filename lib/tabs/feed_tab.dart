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

import '../common/common.dart';
import '../app_state.dart';
import 'package:flutter/rendering.dart';

class FeedTab extends StatefulWidget {
  const FeedTab({super.key});

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  List<Map<String, dynamic>> _feedVideos = [];
  bool _isLoadingFeed = true;

  late PageController _pageController;

  // --- ZERO-STATE SCROLL ARCHITECTURE ---
  // Using ValueNotifiers prevents the screen from rebuilding during a swipe.
  // This guarantees buttery smooth, flawless snapping physics on Safari.
  late ValueNotifier<int> _currentScrollNotifier;
  final ValueNotifier<bool> _isGlobalMuted = ValueNotifier<bool>(true);

  String? _pendingPhone;
  String? _authCode;
  final TextEditingController _phoneController = TextEditingController();

  int _getActual(int i) {
    if (_feedVideos.isEmpty) return 0;
    return (i % _feedVideos.length + _feedVideos.length) % _feedVideos.length;
  }

  @override
  void initState() {
    super.initState();
    _currentScrollNotifier = ValueNotifier<int>(0);
    _fetchFeedFromFirebase();
  }

  Future<void> _fetchFeedFromFirebase() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('videos')
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
          _initApp();
        }
      }
    } catch (e) {
      print("🚨 FAILED TO LOAD FEED: $e");
      if (mounted) {
        setState(() => _isLoadingFeed = false);
      }
    }
  }

  void _initApp() async {
    int startingIndex = 0;

    if (kIsWeb) {
      final String? videoParam = Uri.base.queryParameters['v'];
      if (videoParam != null) {
        startingIndex = int.tryParse(videoParam) ?? 0;
        if (startingIndex >= _feedVideos.length || startingIndex < 0) {
          startingIndex = 0;
        }
      }
    }

    int virtualMiddleIndex = (_feedVideos.length * 500) + startingIndex;
    _currentScrollNotifier.value = virtualMiddleIndex;
    _pageController = PageController(initialPage: virtualMiddleIndex);
  }

  void _toggleGlobalMute() async {
    final prefs = await SharedPreferences.getInstance();
    bool newMuteState = !_isGlobalMuted.value;
    await prefs.setBool('feed_is_muted', newMuteState);
    _isGlobalMuted.value = newMuteState;
  }

  @override
  void dispose() {
    _pageController.dispose();
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
                    child: Image.network('icons/Icon-192.png', width: 72, height: 72, errorBuilder: (context, error, stackTrace) => const Icon(Icons.shield, size: 72, color: Colors.blueAccent)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text("התנתק מהדפדפן. הישאר מחובר לרשת.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text("הוסף את 'זהות' למסך הבית שלך לגישה מהירה, מוצפנת וללא צנזורה - בדיוק כמו אפליקציה רגילה.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.4)),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.amber.withOpacity(0.3))),
                  child: Column(
                    children: const [
                      Row(children: [Icon(Icons.ios_share, color: Colors.amber, size: 22), SizedBox(width: 12), Expanded(child: Text("1. לחץ על כפתור השיתוף (Share) בדפדפן", style: TextStyle(color: Colors.white, fontSize: 14)))]),
                      SizedBox(height: 12),
                      Row(children: [Icon(Icons.add_box_outlined, color: Colors.amber, size: 22), SizedBox(width: 12), Expanded(child: Text("2. בחר 'אל מסך הבית' (Add to Home Screen)", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)))]),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  child: const Text("הבנתי, המשך לאפליקציה", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: () => Navigator.pop(modalContext),
                ),
              ],
            ),
          ),
        );
      },
    );

    String? phone = di<AppState>().userPhone.value;
    if (phone != null && phone.isNotEmpty) {
      di<AppState>().markA2HSPrompted(phone);
    }
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
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

                        List<dynamic> rawClips = data['saved_clips'] ?? [];
                        di<AppState>().savedClips.value = rawClips.map((e) => e.toString()).toList();

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
                              if (mounted) _showA2HSBottomSheet();
                            });
                          }
                        });
                      }
                    }

                    return GestureDetector(
                      onTap: () {},
                      child: Padding(
                        padding: EdgeInsets.only(bottom: MediaQuery.of(statefulContext).viewInsets.bottom + 30, top: 30, left: 30, right: 30),
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
                                  style: ElevatedButton.styleFrom(backgroundColor: isLocked ? Colors.redAccent.shade700 : const Color(0xFF25D366), padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                                  icon: Icon(isLocked ? Icons.timer : Icons.chat_bubble_outline, color: !isLocked ? const Color(0xff010126) : Colors.white),
                                  label: Text(isLocked ? "${'verify_locked_btn'.tr()}${secondsLeft.toString().padLeft(2, '0')}" : "verify_whatsapp_btn".tr(), style: TextStyle(color: !isLocked ? const Color(0xff010126) : Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
                  padding: EdgeInsets.only(bottom: MediaQuery.of(statefulContext).viewInsets.bottom + 30, top: 30, left: 30, right: 30),
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
                        decoration: InputDecoration(hintText: "capture_hint".tr(), hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5), fontSize: 16, letterSpacing: 0), filled: true, fillColor: const Color(0xFF1E293B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none), prefixIcon: const Icon(Icons.phone_android, color: Colors.grey)),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Theme.of(statefulContext).primaryColor, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                        child: FittedBox(fit: BoxFit.scaleDown, child: Text("map_verify_action_btn".tr(), style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold))),
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

                              List<dynamic> rawClips = dataMap['saved_clips'] ?? [];
                              di<AppState>().savedClips.value = rawClips.map((e) => e.toString()).toList();

                              var v = dataMap['verified'];
                              alreadyVerified = (v == true || v == 'true');
                            }

                            if (alreadyVerified) {
                              Navigator.of(bottomSheetContext).pop();
                              await di<AppState>().savePhone(contactInfo);
                              if (mounted) {
                                Future.delayed(const Duration(milliseconds: 400), () {
                                  if (mounted) _showA2HSBottomSheet();
                                });
                              }
                              return;
                            }

                            String newAuthCode = generateSecureToken();
                            await FirebaseFirestore.instance.collection('citizens').doc(contactInfo).set({
                              'phone': contactInfo,
                              'uid': masterUid,
                              'timestamp_feed_login': FieldValue.serverTimestamp(),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating, margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height - 150, left: 20, right: 20), duration: const Duration(seconds: 3)));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SizedBox(
            width: isDesktop ? 650 : double.infinity,
            height: double.infinity,
            child: _isLoadingFeed
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)))
                : _feedVideos.isEmpty
                ? const Center(child: Text("No videos found.", style: TextStyle(color: Colors.white)))

            // 🛡️ THE GESTURE PROTECTOR
                : NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification notification) {
                // Ignore nested scrolls from dialogs
                if (notification.depth != 0) return false;

                // ONLY mutate the DOM when the scroll is 100% finished and finger is lifted!
                if (notification is ScrollEndNotification) {
                  if (_pageController.hasClients) {
                    double page = _pageController.page ?? 0;
                    int target = page.round();

                    // If Chrome's address bar shifted and stranded the page mid-air, force a snap!
                    if ((page - target).abs() > 0.005) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_pageController.hasClients) {
                          _pageController.animateToPage(
                            target,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                          );
                        }
                      });
                    } else {
                      // PERFECTLY ALIGNED! Safe to swap videos without breaking Chrome touches.
                      if (_currentScrollNotifier.value != target) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _currentScrollNotifier.value = target;
                        });
                      }
                    }
                  }
                }
                return false;
              },
              child: PageView.builder(
                controller: _pageController,
                physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
                scrollDirection: Axis.vertical,
                itemCount: _feedVideos.length * 1000,

                // 🚫 COMPLETELY EMPTY! We do NOT update videos at the 50% mark mid-drag!
                onPageChanged: (int rawIndex) {},

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
                                  bool videoRequiresLock = _feedVideos[actualIndex]['isLocked'] == true || _feedVideos[actualIndex]['isLocked'] == 'true';
                                  bool isLocked = videoRequiresLock && !isLoggedIn;

                                  return FeedVideoPlayer(
                                    videoData: _feedVideos[actualIndex],
                                    isLocked: isLocked,
                                    isVisible: isActive,
                                    isMuted: isMuted,
                                    onToggleMute: (_) => _toggleGlobalMute(),
                                    onUnlockTap: _showVerificationBottomSheet,
                                  );
                                },
                              );
                            }
                        );
                      }
                  );
                },
              ),
            )
        ),
      ),
    );
  }
}


class FeedVideoPlayer extends StatefulWidget {
  final Map<String, dynamic> videoData;
  final bool isLocked;
  final VoidCallback onUnlockTap;
  final bool isMuted;
  final ValueChanged<bool> onToggleMute;
  final bool isVisible;

  const FeedVideoPlayer({
    super.key,
    required this.isVisible,
    required this.videoData,
    required this.isLocked,
    required this.onUnlockTap,
    required this.isMuted,
    required this.onToggleMute
  });

  @override
  State<FeedVideoPlayer> createState() => _FeedVideoPlayerState();
}

class _FeedVideoPlayerState extends State<FeedVideoPlayer> with WidgetsBindingObserver {
  late int _likeCount;
  VideoPlayerController? _controller;
  bool _isPlaying = false;
  bool _hasStartedPlaying = false; // 🛡️ NEW: The Thumbnail Shield

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    di<AppState>().navIndex.addListener(_checkPlayState);

    _likeCount = widget.videoData['like_count'] is int
        ? widget.videoData['like_count']
        : int.tryParse(widget.videoData['like_count']?.toString() ?? '0') ?? 0;

    if (widget.isVisible) {
      _initVideo();
    }
  }

  @override
  void didUpdateWidget(FeedVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isVisible && !oldWidget.isVisible) {
      if (_controller == null) {
        _initVideo();
      } else if (!widget.isLocked && _controller!.value.isInitialized) {
        _safePlay();
      }
    } else if (!widget.isVisible && oldWidget.isVisible) {
      _disposeVideo();
    }

    if (widget.isMuted != oldWidget.isMuted && _controller != null) {
      _controller!.setVolume(widget.isMuted ? 0.0 : 1.0);
      // Failsafe: if changing volume, ensure it plays if it was stuck
      if (widget.isVisible && !widget.isLocked && !_isPlaying) {
        _safePlay();
      }
    }

    if (!widget.isLocked && oldWidget.isLocked && widget.isVisible && _controller != null) {
      _safePlay();
    }
  }

  void _disposeVideo() {
    if (_controller == null) return;
    final oldController = _controller!;

    // Instantly detach the UI to fall back to the thumbnail shield
    _controller = null;
    _isPlaying = false;
    _hasStartedPlaying = false;

    oldController.pause();

    Future.microtask(() {
      try {
        oldController.dispose();
      } catch (_) {}
    });
  }

  void _safePlay() {
    if (_controller == null) return;
    _controller!.play().catchError((e) {
      if (mounted && _controller != null) {
        // If Chrome blocked it due to unmuted autoplay, force mute and retry!
        _controller!.setVolume(0.0);
        if (!widget.isMuted) {
          widget.onToggleMute(true);
        }
        _controller!.play().catchError((_) {});
      }
    });
  }

  void _initVideo() {
    if (_controller != null) return;
    String url = widget.videoData['url'].toString();
    _controller = VideoPlayerController.asset(url);
    final controller = _controller!;

    controller.addListener(() {
      if (mounted && _controller == controller) {
        // 🛡️ Drop the Thumbnail Shield ONLY when the video officially starts rendering frames!
        if (controller.value.isPlaying && !_hasStartedPlaying) {
          setState(() {
            _hasStartedPlaying = true;
          });
        }
        if (controller.value.isPlaying != _isPlaying) {
          setState(() {
            _isPlaying = controller.value.isPlaying;
          });
        }
      }
    });

    controller.initialize().then((_) {
      if (!mounted || _controller != controller) return;

      controller.setLooping(true);
      controller.setVolume(widget.isMuted ? 0.0 : 1.0);

      // 1. FORCE FLUTTER TO PHYSICALLY MOUNT THE HTML VIDEO INTO CHROME'S DOM
      setState(() {});

      // 2. WAIT EXACTLY 1 FRAME FOR CHROME TO RENDER IT, THEN COMMAND PLAY
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller == controller && widget.isVisible && !widget.isLocked) {
          _safePlay();
        }
      });
    }).catchError((e) {
      print("🚨 Video Init Error: $e");
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _controller!.pause();
    } else if (state == AppLifecycleState.resumed) {
      _checkPlayState();
    }
  }

  void _checkPlayState() {
    if (!mounted || _controller == null || !_controller!.value.isInitialized) return;

    bool isFeedTabActive = di<AppState>().navIndex.value == 0;

    if (isFeedTabActive && widget.isVisible && !widget.isLocked) {
      _controller!.setVolume(widget.isMuted ? 0.0 : 1.0);
      _safePlay();
    } else {
      _controller!.pause();
      if (widget.isLocked) {
        _controller!.seekTo(Duration.zero);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    di<AppState>().navIndex.removeListener(_checkPlayState);
    _disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String thumbUrl = widget.videoData['thumb']?.toString() ?? '';
    final String title = widget.videoData['title']?.toString() ?? '';
    final String videoId = widget.videoData['id']?.toString() ?? '';
    bool isReady = _controller != null && _controller!.value.isInitialized;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. ABSOLUTE BASE LAYER
        Container(color: Colors.black),

        // 2. HTML VIDEO LAYER (Always behind the thumbnail, silently buffering!)
        if (isReady && _controller != null)
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: _controller!,
            builder: (context, value, child) {
              if (value.hasError) return const Center(child: Icon(Icons.error_outline, color: Colors.redAccent, size: 60));

              return FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: value.size.width > 0 ? value.size.width : 100,
                  height: value.size.height > 0 ? value.size.height : 100,
                  child: IgnorePointer(
                    child: VideoPlayer(_controller!),
                  ),
                ),
              );
            },
          ),

        // 3. TIKTOK THUMBNAIL SHIELD
        // Covers the black screen until the exact millisecond the video starts playing frames
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _hasStartedPlaying ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            child: thumbUrl.isNotEmpty
                ? Image.network(thumbUrl, fit: BoxFit.cover)
                : Container(color: Colors.black),
          ),
        ),

        // 4. LOADING SPINNER
        if (!isReady && widget.isVisible)
          const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),

        // 5. TOUCH DETECTOR
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (widget.isLocked) {
                widget.onUnlockTap();
                return;
              }
              if (_controller != null) {
                _controller!.value.isPlaying ? _controller!.pause() : _safePlay();
              }
            },
            child: const SizedBox.expand(),
          ),
        ),

        // 6. CENSORED OVERLAY
        if (widget.isLocked)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.4),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_person, size: 70, color: Colors.redAccent),
                    const SizedBox(height: 15),
                    const Text(
                        "CENSORED",
                        style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 2, shadows: [Shadow(color: Colors.black, blurRadius: 10)])
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 10, shadowColor: Colors.redAccent),
                      icon: const Icon(Icons.lock_open, size: 28),
                      label: const Text("VERIFY TO WATCH", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      onPressed: widget.onUnlockTap,
                    ),
                  ],
                ),
              ),
            ),
          ),

        // 7. TEXT LEGIBILITY GRADIENT
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0.75, 1.0], colors: [Colors.transparent, Colors.black.withOpacity(0.6)])),
          ),
        ),

        // 8. UI OVERLAY
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 15,
          left: 15,
          right: 15,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, shadows: [Shadow(color: Colors.black, blurRadius: 4)]), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),

              Directionality(
                textDirection: ui.TextDirection.ltr,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ValueListenableBuilder<List<String>>(
                      valueListenable: di<AppState>().savedClips,
                      builder: (context, savedClipsList, child) {
                        final bool isLiked = savedClipsList.contains(videoId);
                        return _buildActionButton(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          _formatLikes(_likeCount),
                          isLiked ? Colors.red : Colors.white,
                          onTap: () {
                            if (widget.isLocked) {
                              widget.onUnlockTap();
                              return;
                            }
                            setState(() {
                              _likeCount += isLiked ? -1 : 1;
                            });
                            final currentClips = List<String>.from(savedClipsList);
                            if (isLiked) {
                              currentClips.remove(videoId);
                            } else {
                              currentClips.add(videoId);
                            }
                            di<AppState>().savedClips.value = currentClips;
                            _syncLikeToFirebase(!isLiked);
                          },
                        );
                      },
                    ),

                    _buildActionButton(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      _isPlaying ? 'Pause' : 'Play',
                      Colors.white,
                      onTap: () {
                        if (widget.isLocked) {
                          widget.onUnlockTap();
                          return;
                        }
                        if (_controller != null) {
                          _isPlaying ? _controller!.pause() : _safePlay();
                        }
                      },
                    ),

                    _buildActionButton(
                      widget.isMuted ? Icons.volume_off : Icons.volume_up,
                      widget.isMuted ? 'Muted' : 'Sound',
                      Colors.white,
                      onTap: () {
                        if (widget.isLocked) {
                          widget.onUnlockTap();
                          return;
                        }
                        widget.onToggleMute(!widget.isMuted);
                      },
                    ),

                    _buildActionButton(
                      Icons.share,
                      'feed_share_btn'.tr(),
                      Colors.white,
                      onTap: () async {
                        final String shareTitle = title.isNotEmpty ? title : "Zehut 100 Days";
                        String rawUrl = widget.videoData['url']?.toString() ?? "";
                        String fileName = rawUrl.split('/').last.replaceAll('.mp4', '.html');
                        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
                        String dynamicLink = "https://gamfeiglintzadak.co.il/$fileName?v=$timestamp";
                        final String contentToShare = "$shareTitle\n\n$dynamicLink";
                        await Share.share(contentToShare);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatLikes(int likes) {
    if (likes >= 1000000) return '${(likes / 1000000).toStringAsFixed(1)}m';
    if (likes >= 1000) return '${(likes / 1000).toStringAsFixed(1)}k';
    return likes.toString();
  }

  Future<void> _syncLikeToFirebase(bool isNowLiked) async {
    final String? phone = di<AppState>().userPhone.value;
    if (phone == null || phone.isEmpty) return;

    final String videoId = widget.videoData['id']?.toString() ?? '';
    if (videoId.isEmpty) return;

    final firestore = FirebaseFirestore.instance;
    try {
      if (isNowLiked) {
        await Future.wait([
          firestore.collection('videos').doc(videoId).set({'like_count': FieldValue.increment(1)}, SetOptions(merge: true)),
          firestore.collection('citizens').doc(phone).set({'saved_clips': FieldValue.arrayUnion([videoId])}, SetOptions(merge: true)),
        ]);
      } else {
        await Future.wait([
          firestore.collection('videos').doc(videoId).set({'like_count': FieldValue.increment(-1)}, SetOptions(merge: true)),
          firestore.collection('citizens').doc(phone).set({'saved_clips': FieldValue.arrayRemove([videoId])}, SetOptions(merge: true)),
        ]);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _likeCount += isNowLiked ? -1 : 1);
        final currentClips = List<String>.from(di<AppState>().savedClips.value);
        if (isNowLiked) {
          currentClips.remove(videoId);
        } else {
          currentClips.add(videoId);
        }
        di<AppState>().savedClips.value = currentClips;
      }
    }
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
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}