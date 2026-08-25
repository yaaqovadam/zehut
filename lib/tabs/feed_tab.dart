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


  int _getActual(int i) {
    if (_feedVideos.isEmpty) return 0;
    return (i % _feedVideos.length + _feedVideos.length) % _feedVideos.length;
  }

  @override
  void initState() {
    super.initState();
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
          int virtualMiddleIndex = (_feedVideos.length * 500);
          _currentScrollNotifier.value = virtualMiddleIndex;
          _pageController = PageController(initialPage: virtualMiddleIndex);
        }
      }
    } catch (e) {
      print("🚨 FAILED TO LOAD FEED: $e");
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (BuildContext bottomSheetContext) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 30, top: 30, left: 30, right: 30),
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
                style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 2),
                textAlign: TextAlign.center,
                decoration: InputDecoration(hintText: "capture_hint".tr(), hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5), fontSize: 16), filled: true, fillColor: const Color(0xFF1E293B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none), prefixIcon: const Icon(Icons.phone_android, color: Colors.grey)),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(bottomSheetContext).primaryColor, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text("map_verify_action_btn".tr(), style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: () => Navigator.pop(bottomSheetContext),
              ),
            ],
          ),
        );
      },
    );
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
              : NotificationListener<ScrollNotification>(
            onNotification: (notification) {
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

// 🎬 BULLETPROOF SINGLE-CONTROLLER ENGINE (Chrome iOS Audio-Lock Fix)
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
    required this.onToggleMute,
  });

  @override
  State<FeedVideoPlayer> createState() => _FeedVideoPlayerState();
}

class _FeedVideoPlayerState extends State<FeedVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isPlaying = false;
  bool _isInitialized = false;
  bool _showUi = true;
  Timer? _uiHideTimer;

  @override
  void initState() {
    super.initState();
    if (widget.isVisible) {
      _initAndPlay();
    }
  }

  void _startUiHideTimer() {
    _uiHideTimer?.cancel();
    // ⚡ Reduced timeout to 1.5 seconds as requested
    _uiHideTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted && _isPlaying) {
        setState(() => _showUi = false);
      }
    });
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

  // Helper so tapping any button also refreshes the 1.5s countdown
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

  void _initAndPlay() {
    if (_controller != null || widget.isLocked) return;

    final url = widget.videoData['url'].toString();
    _controller = VideoPlayerController.asset(url)
      ..initialize().then((_) {
        if (!mounted || !widget.isVisible) return;
        setState(() => _isInitialized = true);

        _controller!.setLooping(true);
        _controller!.setVolume(0.0);
        _controller!.play().then((_) {
          if (!mounted) return;
          setState(() => _isPlaying = true);
          _startUiHideTimer();

          if (!widget.isMuted) {
            Future.delayed(const Duration(milliseconds: 150), () {
              if (mounted && _controller != null && widget.isVisible) {
                _controller!.setVolume(1.0);
              }
            });
          }
        }).catchError((_) {
          widget.onToggleMute(true);
        });
      });
  }

  void _disposeController() {
    _uiHideTimer?.cancel();
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
    int likeCount = int.tryParse(widget.videoData['like_count']?.toString() ?? '0') ?? 0;

    if (_isInitialized && _controller != null) {
      final actualPlaying = _controller!.value.isPlaying;
      if (actualPlaying != _isPlaying && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _controller != null) {
            setState(() => _isPlaying = _controller!.value.isPlaying);
          }
        });
      }
    }

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

        // Thumbnail Shield
        AnimatedOpacity(
          opacity: (_isInitialized && _isPlaying) ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 300),
          child: thumbUrl.isNotEmpty
              ? Image.network(thumbUrl, fit: BoxFit.cover)
              : Container(color: Colors.black),
        ),

        // Loading Spinner
        if (!_isInitialized && widget.isVisible && !widget.isLocked)
          const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),

        // 🛡️ CLEAN TAP DETECTOR: Toggles UI visibility only, never messes with video canvas state!
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (widget.isLocked) {
                widget.onUnlockTap();
                return;
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

        // Fading Gradient Background for Buttons
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 120,
          child: AnimatedOpacity(
            opacity: _showUi ? 1.0 : 0.0,
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

        // Action Buttons Row (Lowered, 1.5s auto-hide timeout)
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom,
          left: 15,
          right: 15,
          child: AnimatedOpacity(
            opacity: _showUi ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !_showUi,
              child: Directionality(
                textDirection: ui.TextDirection.ltr,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildActionButton(Icons.favorite_border, likeCount.toString(), Colors.white, onTap: () {
                      _onUserInteraction();
                      if (widget.isLocked) {
                        widget.onUnlockTap();
                      }
                    }),
                    _buildActionButton(_isPlaying ? Icons.pause : Icons.play_arrow, _isPlaying ? 'Pause' : 'Play', Colors.white, onTap: () {
                      _onUserInteraction();
                      if (widget.isLocked) {
                        widget.onUnlockTap();
                      } else if (_controller != null && _isInitialized) {
                        if (_controller!.value.isPlaying) {
                          _controller!.pause();
                        } else {
                          _controller!.setVolume(widget.isMuted ? 0.0 : 1.0);
                          _controller!.play();
                        }
                        setState(() => _isPlaying = _controller!.value.isPlaying);
                      }
                    }),
                    _buildActionButton(widget.isMuted ? Icons.volume_off : Icons.volume_up, widget.isMuted ? "tap_to_unmute".tr() : 'Sound', Colors.white, onTap: () {
                      _onUserInteraction();
                      if (widget.isLocked) {
                        widget.onUnlockTap();
                      } else {
                        widget.onToggleMute(!widget.isMuted);
                      }
                    }),
                    _buildActionButton(Icons.share, 'feed_share_btn'.tr(), Colors.white, onTap: () async {
                      _onUserInteraction();
                      await Share.share("https://gamfeiglintzadak.co.il/");
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