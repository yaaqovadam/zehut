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

import '../common/common.dart';
import '../app_state.dart';
import 'package:firebase_auth/firebase_auth.dart';

bool sessionAudioUnlocked = false;

class FeedTab extends StatefulWidget {
  final String? targetVideoId; // 🎯 Added this parameter to catch the incoming video ID

  const FeedTab({super.key, this.targetVideoId});

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  List<Map<String, dynamic>> _feedVideos = [];
  bool _isLoadingFeed = true;
  late PageController _pageController;
  bool sessionAudioUnlocked = false;

  final ValueNotifier<int> _currentScrollNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> _isGlobalMuted = ValueNotifier<bool>(true);

  String? _pendingPhone;
  String? _authCode;
  final TextEditingController _phoneController = TextEditingController();
  bool _hasSwipedFeed = false;

  StreamSubscription<QuerySnapshot>? _feedSubscription; // 🎯 Auto-update listener

  int _getActual(int i) {
    if (_feedVideos.isEmpty) return 0;
    return (i % _feedVideos.length + _feedVideos.length) % _feedVideos.length;
  }

  void _nukeSafariPlayButton() {
    if (kIsWeb) {
      if (html.document.getElementById('nuke-safari-button') == null) {
        final style = html.StyleElement()
          ..id = 'nuke-safari-button'
          ..text = '''
            video::-webkit-media-controls-start-playback-button,
            video::-webkit-media-controls,
            video::-webkit-media-controls-enclosure {
              display: none !important;
              -webkit-appearance: none !important;
            }
          ''';
        html.document.head?.append(style);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _nukeSafariPlayButton();
    _fetchFeedFromFirebase();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) setState(() => _hasSwipedFeed = prefs.getBool('has_swiped_feed') ?? false);
    });
  }

  void _fetchFeedFromFirebase() {
    _feedSubscription?.cancel();
    _feedSubscription = FirebaseFirestore.instance
        .collection('feeds')
        .orderBy('index', descending: false)
        .snapshots() // 🎯 Real-time listener: instantly catches new uploads!
        .listen((snapshot) {
      final List<Map<String, dynamic>> loadedVideos = snapshot.docs
          .where((doc) {
        final data = doc.data();
        return data['online'] != false && data['online'] != 'false';
      })
          .map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'url': data['url'] ?? '',
          'title': data['title'] ?? '',
          'subtitle': data['subtitle'] ?? '',
          'thumb': data['thumb'] ?? '',
          'like_count': data['like_count'] ?? 0,
          'isLocked': data['isLocked'] == true || data['isLocked'] == 'true',
          'online': data['online'] ?? true,
        };
      }).toList();

      if (mounted) {
        final bool isFirstLoad = _feedVideos.isEmpty;
        setState(() {
          _feedVideos = loadedVideos;
          _isLoadingFeed = false;
        });

        if (isFirstLoad && _feedVideos.isNotEmpty) {
          int startingIndex = 0;

          // 🎯 1. First, check if the Admin panel sent us a specific video ID
          if (widget.targetVideoId != null) {
            int foundIndex = _feedVideos.indexWhere((v) => v['id'] == widget.targetVideoId);
            if (foundIndex != -1) {
              startingIndex = foundIndex;
            }
          }
          // 2. Otherwise, fall back to checking the web HTML metadata
          else if (kIsWeb) {
            try {
              final metaTag = html.document.querySelector('meta[name="video-id"]');
              if (metaTag != null) {
                final targetId = metaTag.attributes['content'];
                if (targetId != null) {
                  int foundIndex = _feedVideos.indexWhere((v) => v['id'] == targetId);
                  if (foundIndex != -1) {
                    startingIndex = foundIndex;
                  }
                }
              }
            } catch (_) {}
          }

          if (startingIndex >= _feedVideos.length || startingIndex < 0) {
            startingIndex = 0;
          }

          int virtualMiddleIndex = (_feedVideos.length * 500) + startingIndex;
          _currentScrollNotifier.value = virtualMiddleIndex;
          _pageController = PageController(initialPage: virtualMiddleIndex);
        }
      }
    }, onError: (e) {
      debugPrint("🚨 FAILED TO LISTEN TO FEED: $e");
      if (mounted) setState(() => _isLoadingFeed = false);
    });
  }

  @override
  void dispose() {
    _feedSubscription?.cancel(); // 🎯 Clean up the listener
    if (_feedVideos.isNotEmpty) _pageController.dispose();
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

                        WidgetsBinding.instance.addPostFrameCallback((_) async {
                          if (_pendingPhone == null) return;

                          // 🎯 1. Pop the sheet FIRST while bottomSheetContext is completely mounted
                          if (bottomSheetContext.mounted) {
                            Navigator.of(bottomSheetContext).pop();
                          }

                          // 🎯 2. Save credentials to local storage
                          await di<AppState>().savePhone(verifiedPhone);

                          // 🎯 3. Clear temporary state
                          if (mounted) {
                            setState(() {
                              _pendingPhone = null;
                              _authCode = null;
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
                child: SingleChildScrollView(
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
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(Icons.shield, size: 80, color: Colors.blueAccent),
                              // Positioned slightly higher to visually center inside the shield's curves
                              const Positioned(
                                top: 18,
                                child: MagenDavid(size:40, color: Colors.white, strokeWidth: 3.0),
                              ),
                            ],
                          ),
                        ),
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
                              final result = await di<AppState>().processPhoneAuth(
                                contactInfo,
                                {},
                              );

                              if (result.isAlreadyVerified) {
                                // 🎯 Save to state so lock overlay clears
                                await di<AppState>().savePhone(contactInfo);
                                if (bottomSheetContext.mounted) {
                                  Navigator.of(bottomSheetContext).pop();
                                }
                                if (mounted) setState(() {});
                              } else {
                                setModalState(() {
                                  setState(() {
                                    _pendingPhone = result.phone;
                                    _authCode = result.authCode;
                                  });
                                });
                              }
                            } catch (e) {
                              _showError("map_err_save".tr());
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
  void _setGlobalMute(bool isMuted) async {
    if (_isGlobalMuted.value == isMuted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('feed_is_muted', isMuted);
    _isGlobalMuted.value = isMuted;
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
    if (!mounted) return; // <-- Add this shield
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    // 🎯 STRICT WIDTH GATE: Only lock to 650 if the screen is ACTUALLY wider than 650
    final double containerWidth = screenWidth > 650 ? 650 : double.infinity;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SizedBox(
          width: containerWidth,
          height: double.infinity,
          child: _isLoadingFeed
              ? const Center(child: CircularProgressIndicator(color: Colors.lightBlue))
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
  bool isAdmin = false;
  bool isLoading = true;

  bool _isShowingSwipeGate = false; // 🔥 The Grandpa Gate state

  late int likeCount;
  bool _hasTappedInitialPlay = false;


  Future<void> _initFeed() async {
    if (!mounted) return;

    bool isAdminUser = false;
    final String? phone = di<AppState>().userPhone.value;

    if (phone != null && phone.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance.collection('admins').doc(phone).get();
        if (doc.exists && doc.data()?['isAdmin'] == true) {
          isAdminUser = true;
        }
      } catch (e) {
        debugPrint("Admin check failed: $e");
      }
    }

    if (mounted) {
      setState(() {
        isAdmin = isAdminUser;
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();;
    _initFeed();
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

        // Only autoplay if they haven't tapped yet. (If they tapped, _togglePlayPause handles it).
        if (!sessionAudioUnlocked) {
          ctrl.play().then((_) {
            if (mounted) setState(() => _isPlaying = true);
          });
        }
      }
    });
  }

  void _initAndPlay() {
    if (widget.isLocked || _isInitializing) return;

    if (_controller != null && _isInitialized) {
      _controller!.setVolume(widget.isMuted ? 0.0 : 1.0);

      // 🛑 STRICT GATE: MUST TAP TO PLAY
      if (!sessionAudioUnlocked) {
        _controller!.pause();
        setState(() => _isPlaying = false);
        if (!widget.hasSwipedFeed) _triggerTutorialGate(_controller!); // <-- Add here
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

        if (newController.value.isInitialized &&
            newController.value.duration > Duration.zero &&
            newController.value.position >= newController.value.duration) {

          // 🔥 If they still haven't swiped when the video ends, trigger the gate and pause
          if (!widget.hasSwipedFeed) {
            _triggerTutorialGate(newController);
          } else {
            newController.seekTo(Duration.zero);
            newController.play();
          }
        }
      });

      // 🛑 STRICT GATE: MUST TAP TO PLAY
      if (!sessionAudioUnlocked) {
        newController.pause();
        setState(() => _isPlaying = false);
        if (!widget.hasSwipedFeed) _triggerTutorialGate(newController); // <-- And add here
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
        });
      }
    });
  }
  void _disposeController() {
    _uiHideTimer?.cancel();
    _isInitializing = false;
    final oldController = _controller;
    _controller = null;
    _isInitialized = false;
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

  void _togglePlayPause() {
    _onUserInteraction();

    // 🔥 KILL THE GATE INSTANTLY ON ANY TAP
    if (_isShowingSwipeGate) {
      setState(() => _isShowingSwipeGate = false);
    }

    if (widget.isLocked) {
      widget.onUnlockTap();
      return;
    }

    // Unlocks session and un-mutes on first manual interaction
    if (!sessionAudioUnlocked) {
      setState(() => sessionAudioUnlocked = true);
      widget.onToggleMute(false);
    }

    if (_controller == null || !_isInitialized || !_controller!.value.isInitialized) {
      _disposeController();
      _initAndPlay();
      return;
    }

    if (_controller!.value.isPlaying) {
      _controller!.pause();
      setState(() {
        _isPlaying = false;
        _showUi = true;
      });
      _uiHideTimer?.cancel();
    } else {
      _controller!.setVolume(widget.isMuted ? 0.0 : 1.0);
      _controller!.play().then((_) {
        if (mounted) {
          setState(() => _isPlaying = true);
          _startUiHideTimer();
        }
      }).catchError((_) {
        _disposeController();
        _initAndPlay();
      });
    }
  }
  Widget _buildMarbleButton() {
    // 1. Grab the current video's Firestore ID
    final String videoId = widget.videoData['id']?.toString() ?? '';

    // // 2. Kill the button if audio is unlocked, the video is locked, OR it's NOT the intro video
    // if (sessionAudioUnlocked || widget.isLocked || videoId != 'moshe-feiglin-intro-zehut-') {
    //   return const SizedBox.shrink();
    // }
// Show the marble button on whichever video is currently visible before audio is unlocked
    if (sessionAudioUnlocked || widget.isLocked || !widget.isVisible) {
      return const SizedBox.shrink();
    }
    // 3. Back to perfectly centered without the 100px offset
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            sessionAudioUnlocked = true;
          });

          widget.onToggleMute(false);

          if (_controller != null && _controller!.value.isInitialized) {
            _controller!.setVolume(1.0);
            _controller!.play().then((_) {
              if (mounted) {
                setState(() => _isPlaying = true);
                _startUiHideTimer();
              }
            });
          } else {
            _initAndPlay();
          }
        },
        child: Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 7),
              ),
              BoxShadow(
                color: const Color(0xFF2979FF).withOpacity(0.45),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.25, -0.35),
                    radius: 0.9,
                    colors: [
                      const Color(0xFF82B1FF).withOpacity(0.35),
                      const Color(0xFF2979FF).withOpacity(0.50),
                      const Color(0xFF2962FF).withOpacity(0.55),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1.4,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      bottom: 7,
                      child: Container(
                        width: 52,
                        height: 18,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.all(Radius.elliptical(52, 18)),
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withOpacity(0.35),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      child: Container(
                        width: 58,
                        height: 27,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.all(Radius.elliptical(58, 27)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.85),
                              Colors.white.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 5),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 52,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }




  @override
  Widget build(BuildContext context) {
    final String thumbUrl = widget.videoData['thumb']?.toString() ?? '';
    final String videoId = widget.videoData['id']?.toString() ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black),

        // 1. Video Player Layer
        if (_isInitialized && _controller != null)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width > 0 ? _controller!.value.size.width : 100,
              height: _controller!.value.size.height > 0 ? _controller!.value.size.height : 100,
              child: VideoPlayer(_controller!),
            ),
          ),

        // 2. Thumbnail Shield (Stays dead once the video moves)
        IgnorePointer(
          ignoring: sessionAudioUnlocked && _isPlaying,
          child: AnimatedOpacity(
            // Only show if it's NOT playing AND the video hasn't moved past 0 seconds
            opacity: (_isInitialized && (_isPlaying || _controller!.value.position.inMilliseconds > 0)) ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: thumbUrl.isNotEmpty
                  ? Image.network(thumbUrl, fit: BoxFit.fitWidth)
                  : const SizedBox.expand(),
            ),
          ),
        ),

        // 3. Full-Screen Tap Layer (MUST sit below the bottom bar)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _togglePlayPause,
          ),
        ),

        // 4. Initial Blue Glass Marble (First load only, isolated to specific video ID)
        // _buildMarbleButton(),

// 5. Grandpa Gate
        if (!widget.hasSwipedFeed)
          Positioned.fill(
            child: IgnorePointer( // Lets the user tap the video to unmute
              child: AnimatedOpacity(
                opacity: _isShowingSwipeGate ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 800), // Smooth fade out
                child: Container(
                  color: Colors.black.withOpacity(0.85),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.elasticOut,
                        builder: (context, val, child) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: val * 40),
                            child: const Icon(Icons.touch_app, color: Colors.amber, size: 90),
                          );
                        },
                      ),
                      const SizedBox(height: 15),
                      Text(
                        "tutorial_swipe_up".tr(),
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // 6. Lock Overlays
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

        // 7. Gradient Background
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 120,
          child: AnimatedOpacity(
            opacity: _showUi ? 1.0 : 0.3,
            duration: const Duration(milliseconds: 250),
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

        // 8. Action Buttons Row
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom,
          left: 0,
          right: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onUserInteraction,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: AnimatedOpacity(
                opacity: _showUi ? 1.0 : 0.3,
                duration: const Duration(milliseconds: 250),
                child: Directionality(
                  textDirection: ui.TextDirection.ltr,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Heart Button
                      // Heart Button
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

                                  // 🛑 STRICT SECURITY GATE: Check both isLoggedIn AND the actual phone value
                                  final bool hasValidPhone = di<AppState>().userPhone.value != null &&
                                      di<AppState>().userPhone.value!.isNotEmpty;

                                  if (!isLoggedIn || !hasValidPhone) {
                                    // Trigger the exact same verification overlay used for locked videos
                                    widget.onUnlockTap();
                                    // 🚨 CRITICAL: Exit immediately so the UI does not fake a successful like
                                    return;
                                  }

                                  // Only fully verified users will reach this point
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

                      // Dedicated Play / Pause Button
                      _buildActionButton(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        _isPlaying ? "pause_btn".tr() : "play_btn".tr(),
                        Colors.white,
                        onTap: _togglePlayPause,
                      ),

                      // Sound / Mute Button
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
                        },
                      ),

                      // Share Button
                      _buildActionButton(
                        Icons.share,
                        'feed_share_btn'.tr(),
                        Colors.white,
                        onTap: () async {
                          _onUserInteraction();
                          final String title = widget.videoData['title']?.toString() ?? '';
                          final String shareTitle = title.isNotEmpty ? title : "app_name".tr();

                          String rawUrl = widget.videoData['url']?.toString() ?? "";
                          String htmlFileName = rawUrl.split('/').last.replaceAll('.mp4', '.html');
                          String exactLink = "https://gamfeiglintzadak.co.il/$htmlFileName";

                          final String contentToShare = "$shareTitle\n\n$exactLink";
                          await Share.share(contentToShare);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, {VoidCallback? onTap}) {
    return Padding(
      // The dead zone: keeps the visual layout identical but lifts the tap target away from the bottom bar
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // Reduced the vertical padding to shrink the clickable area
          padding: const EdgeInsets.only(left: 10, right: 10, top: 8, bottom: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Ensures the tap target wraps tightly around the content
            children: [
              Icon(icon, color: color, size: 35),
              // Removed the 4px SizedBox to pull the text flush against the icon
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  height: 1.1, // Tightens the invisible box around the text
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }}



class MagenDavid extends StatelessWidget {
  final double size;
  final Color color;
  final double strokeWidth;

  const MagenDavid({
    super.key,
    this.size = 80,
    this.color = Colors.white,
    this.strokeWidth = 4.5, // Thick, modern outline
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CustomPaint(
        size: Size(size, size),
        painter: _MagenDavidPainter(color: color, strokeWidth: strokeWidth),
      ),
    );
  }
}

class _MagenDavidPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _MagenDavidPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    // Shrink radius slightly so the thick stroke doesn't get clipped at the edges
    final r = (size.width < size.height ? size.width : size.height) / 2 - strokeWidth;

    const sin30 = 0.5;
    const cos30 = 0.8660254; // Exact geometry: sqrt(3) / 2

    // Triangle 1 (pointing up)
    final path1 = Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r * cos30, cy + r * sin30)
      ..lineTo(cx - r * cos30, cy + r * sin30)
      ..close();

    // Triangle 2 (pointing down)
    final path2 = Path()
      ..moveTo(cx, cy + r)
      ..lineTo(cx - r * cos30, cy - r * sin30)
      ..lineTo(cx + r * cos30, cy - r * sin30)
      ..close();

    canvas.drawPath(path1, paint);
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}