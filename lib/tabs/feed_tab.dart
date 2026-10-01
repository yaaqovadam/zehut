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
  final String? targetVideoId;

  const FeedTab({super.key, this.targetVideoId});

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  List<Map<String, dynamic>> _feedVideos = [];
  bool _isLoadingFeed = true;
  late PageController _pageController;

  String? _lastVideoId;
  Map<int, double> _hebOverrides = {};
  Map<int, double> _engOverrides = {};
  final ValueNotifier<int> manualEditRow = ValueNotifier<int>(0);

  final ValueNotifier<int> _currentScrollNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> _isGlobalMuted = ValueNotifier<bool>(true);

  String? _pendingPhone;
  String? _authCode;
  final TextEditingController _phoneController = TextEditingController();
  bool _hasSwipedFeed = false;
  bool sessionAudioUnlocked = false;

  StreamSubscription<QuerySnapshot>? _feedSubscription;

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

    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() {
          _hasSwipedFeed = prefs.getBool('has_swiped_feed') ?? false;
          _lastVideoId = prefs.getString('last_watched_video_id');
        });
        _fetchFeedFromFirebase();
      }
    });
  }

  void _fetchFeedFromFirebase() {
    _feedSubscription?.cancel();
    _feedSubscription = FirebaseFirestore.instance
        .collection('feeds')
        .orderBy('index', descending: false)
        .snapshots()
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
          'showHebrew': data['showHebrew'] ?? true,
          'showEnglish': data['showEnglish'] ?? true,
          'hebrewYPos': (data['hebrewYPos'] ?? 0.1).toDouble(),
          'englishYPos': (data['englishYPos'] ?? 0.65).toDouble(),
          'waveformUrl': data['waveformUrl'],
          'syncedWords': data['syncedWords'] ?? [],
          'syncedWordsEN': data['syncedWordsEN'] ?? [],
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

          if (widget.targetVideoId != null) {
            int foundIndex = _feedVideos.indexWhere((v) => v['id'] == widget.targetVideoId);
            if (foundIndex != -1) startingIndex = foundIndex;
          }
          else if (kIsWeb) {
            try {
              final metaTag = html.document.querySelector('meta[name="video-id"]');
              if (metaTag != null && metaTag.attributes['content'] != null) {
                int foundIndex = _feedVideos.indexWhere((v) => v['id'] == metaTag.attributes['content']);
                if (foundIndex != -1) startingIndex = foundIndex;
              }
            } catch (_) {}
          }

          if (startingIndex == 0 && _lastVideoId != null) {
            int foundIndex = _feedVideos.indexWhere((v) => v['id'] == _lastVideoId);
            if (foundIndex != -1) startingIndex = foundIndex;
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
    _feedSubscription?.cancel();
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
    showUniversalAuthSheet(context);
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
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

                  final actualIndex = _getActual(target);
                  final currentVideoId = _feedVideos[actualIndex]['id'];
                  SharedPreferences.getInstance().then((prefs) =>
                      prefs.setString('last_watched_video_id', currentVideoId.toString()));
                }
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              physics: di<AppState>().isFeedEditMode.value
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(parent: ClampingScrollPhysics()),
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

                            return ValueListenableBuilder<bool>(
                                valueListenable: di<AppState>().isFeedEditMode,
                                builder: (context, isEditMode, child) {
                                  bool isLocked = (_feedVideos[actualIndex]['isLocked'] == true || _feedVideos[actualIndex]['isLocked'] == 'true') && !isLoggedIn;

                                  return FeedVideoPlayer(
                                    videoData: _feedVideos[actualIndex],
                                    isLocked: isLocked,
                                    isVisible: isActive,
                                    isMuted: isMuted,
                                    hasSwipedFeed: _hasSwipedFeed,
                                    onToggleMute: (muteState) => _setGlobalMute(muteState),
                                    onUnlockTap: _showVerificationBottomSheet,
                                    isEditMode: isEditMode,
                                    onToggleEditMode: (bool isEditing) {
                                      di<AppState>().isFeedEditMode.value = isEditing;
                                    },
                                  );
                                }
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

class FeedVideoPlayer extends StatefulWidget {
  final Map<String, dynamic> videoData;
  final bool isLocked;
  final VoidCallback onUnlockTap;
  final bool isMuted;
  final ValueChanged<bool> onToggleMute;
  final bool isVisible;
  final bool hasSwipedFeed;
  final bool isEditMode;
  final ValueChanged<bool> onToggleEditMode;

  const FeedVideoPlayer({
    super.key,
    required this.isVisible,
    required this.videoData,
    required this.isLocked,
    required this.onUnlockTap,
    required this.isMuted,
    required this.onToggleMute,
    required this.hasSwipedFeed,
    required this.isEditMode,
    required this.onToggleEditMode,
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

  bool _isShowingSwipeGate = false;

  late int likeCount;
  bool _hasTappedInitialPlay = false;

  Map<int, double> _hebOverrides = {};
  Map<int, double> _engOverrides = {};

  void _updateSubtitlePosition(String key, dynamic val) {
    FirebaseFirestore.instance
        .collection('feeds')
        .doc(widget.videoData['id'])
        .set({key: val}, SetOptions(merge: true));
  }

  int _calculateFocusGroup(int currentMillis, List<dynamic> trackWords) {
    int lastDroppedTotal = trackWords.lastIndexWhere((w) => w['startMs'] != null);
    if (lastDroppedTotal == -1) return 0;
    int maxDroppedTime = (trackWords[lastDroppedTotal]['startMs'] as num).toInt();

    if (currentMillis >= maxDroppedTime) {
      int nextTarget = lastDroppedTotal + 1;
      if (nextTarget >= trackWords.length) return lastDroppedTotal ~/ 3;
      return nextTarget ~/ 3;
    } else {
      int reviewIndex = trackWords.lastIndexWhere((w) => w['startMs'] != null && ((w['startMs'] as num).toInt()) <= currentMillis);
      if (reviewIndex == -1) return 0;
      return reviewIndex ~/ 3;
    }
  }

  Widget _buildFeedFlashcardRow(List<dynamic> trackWords, int currentMillis, String lang, double videoHeight, double videoWidth, int activeGroup) {
    if (trackWords.isEmpty) return const SizedBox.shrink();

    // 🎯 We now use the passed-in activeGroup (which listens to manualRow in edit mode)
    int startIndex = activeGroup * 3;
    int endIndex = (startIndex + 3 > trackWords.length) ? trackWords.length : startIndex + 3;
    List<dynamic> activeTriplets = trackWords.sublist(startIndex, endIndex);

    double baseSize = videoHeight * 0.035;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      textDirection: lang == 'hebrew' ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      children: List.generate(activeTriplets.length, (index) {
        final wordData = activeTriplets[index];
        final word = wordData['word'] as String;
        final rawTime = wordData['startMs'];
        final markerTime = rawTime != null ? (rawTime as num).toInt() : null;

        bool isHighlighted = false;
        if (markerTime != null && currentMillis >= markerTime) {
          int globalIndex = startIndex + index;
          int nextMarkerTime = (globalIndex < trackWords.length - 1 && trackWords[globalIndex + 1]['startMs'] != null)
              ? (trackWords[globalIndex + 1]['startMs'] as num).toInt()
              : _controller!.value.duration.inMilliseconds;

          if (currentMillis < nextMarkerTime) isHighlighted = true;
        }

        double fontSize = isHighlighted ? baseSize * 1.3 : baseSize;
        Color fillColor = isHighlighted ? Colors.yellowAccent : Colors.black;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: videoWidth * 0.015),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(word, textAlign: TextAlign.center, style: TextStyle(
                fontSize: fontSize, fontWeight: FontWeight.w900,
                foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = videoHeight * 0.005..color = Colors.lightBlueAccent,
                shadows: const [Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 2))],
              )),
              Text(word, textAlign: TextAlign.center, style: TextStyle(
                fontSize: fontSize, fontWeight: FontWeight.w900, color: fillColor,
              )),
            ],
          ),
        );
      }),
    );
  }

  double _getLocalStickyY(int targetGroup, Map<int, double> overrides, double fallback) {
    // 1. If this exact row was moved, use its specific position (Local Exception)
    if (overrides.containsKey(targetGroup)) {
      return overrides[targetGroup]!;
    }

    // 2. Otherwise, check if Row 1 (group 0) was set and use it as the Master Baseline
    if (overrides.containsKey(0)) {
      return overrides[0]!;
    }

    // 3. If neither is set, use the hardcoded default
    return fallback;
  }

  double _getSavedStickyY(int targetGroup, List<dynamic> words, double defaultY) {
    // 1. Exact match for the current row (Local Exception)
    int exactIdx = targetGroup * 3;
    if (exactIdx < words.length && words[exactIdx] is Map && words[exactIdx]['y'] != null) {
      return (words[exactIdx]['y'] as num).toDouble();
    }

    // 2. Master Baseline check (Row 1 / group 0)
    if (words.isNotEmpty && words[0] is Map && words[0]['y'] != null) {
      return (words[0]['y'] as num).toDouble();
    }

    return defaultY;
  }

  Future<void> _initFeed() async {
    if (!mounted) return;

    bool isAdminUser = false;
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        final String rawId = (user.phoneNumber != null && user.phoneNumber!.isNotEmpty)
            ? user.phoneNumber!
            : user.uid;

        final String safePhone = rawId.replaceAll('+', '').trim();

        if (safePhone.isNotEmpty && safePhone.length > 5) {
          final doc = await FirebaseFirestore.instance.collection('admins').doc(safePhone).get();

          // Check if document exists AND the isAdmin field is explicitly true
          if (doc.exists) {
            final data = doc.data();
            if (data != null && data['isAdmin'] == true) {
              isAdminUser = true;
            }
          }
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
    super.initState();
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || videoId.isEmpty) return;

    final String safePhone = user.uid.replaceAll('+', '').trim();
    final firestore = FirebaseFirestore.instance;
    try {
      if (isNowLiked) {
        await Future.wait([
          firestore.collection('feeds').doc(videoId).set({'like_count': FieldValue.increment(1)}, SetOptions(merge: true)),
          firestore.collection('citizens').doc(safePhone).set({'saved_clips': FieldValue.arrayUnion([videoId])}, SetOptions(merge: true)),
        ]);
      } else {
        await Future.wait([
          firestore.collection('feeds').doc(videoId).set({'like_count': FieldValue.increment(-1)}, SetOptions(merge: true)),
          firestore.collection('citizens').doc(safePhone).set({'saved_clips': FieldValue.arrayRemove([videoId])}, SetOptions(merge: true)),
        ]);
      }
    } catch (e) {
      debugPrint("🚨 Failed to sync like to Firebase: $e");
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

    if (!widget.isLocked && oldWidget.isLocked && widget.isVisible) {
      _initAndPlay();
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

      if (!sessionAudioUnlocked) {
        _controller!.pause();
        setState(() => _isPlaying = false);
        if (!widget.hasSwipedFeed) _triggerTutorialGate(_controller!);
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
          if (!widget.hasSwipedFeed) {
            _triggerTutorialGate(newController);
          } else {
            newController.seekTo(Duration.zero);
            newController.play();
          }
        }
      });

      if (!sessionAudioUnlocked) {
        newController.pause();
        setState(() => _isPlaying = false);
        if (!widget.hasSwipedFeed) _triggerTutorialGate(newController);
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

    if (_isShowingSwipeGate) {
      setState(() => _isShowingSwipeGate = false);
    }

    if (widget.isLocked) {
      widget.onUnlockTap();
      return;
    }

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
    if (sessionAudioUnlocked || widget.isLocked || !widget.isVisible) {
      return const SizedBox.shrink();
    }
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

    final double videoWidth = (_isInitialized && _controller != null && _controller!.value.size.width > 0)
        ? _controller!.value.size.width
        : 100.0;
    final double videoHeight = (_isInitialized && _controller != null && _controller!.value.size.height > 0)
        ? _controller!.value.size.height
        : 100.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black),

        // 1. BASE LAYER: The Video itself
        if (_isInitialized && _controller != null)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: videoWidth,
              height: videoHeight,
              child: VideoPlayer(_controller!),
            ),
          ),

        // 2. Thumbnail Shield
        IgnorePointer(
          ignoring: sessionAudioUnlocked && _isPlaying,
          child: AnimatedOpacity(
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

        // 3. MIDDLE LAYER: Full-Screen Tap Layer
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _togglePlayPause,
          ),
        ),

        // 🎯 3.5 THE EDIT MODE GLASS SHIELD
        if (isAdmin && widget.isEditMode)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (_) {},
              child: Container(
                color: Colors.blueAccent.withOpacity(0.15),
              ),
            ),
          ),

        // 4. TOP LAYER: Touchable, Draggable Subtitles
        // 4. TOP LAYER: Touchable, Draggable Subtitles
        if (_isInitialized && _controller != null)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: videoWidth,
              height: videoHeight,
              child: AnimatedBuilder(
                animation: _controller!,
                builder: (context, child) {
                  return ValueListenableBuilder<int>(
                    valueListenable: di<AppState>().manualEditRow,
                    builder: (context, manualRow, _) {
                      final currentMillis = _controller!.value.position.inMilliseconds;
                      final bool showHeb = widget.videoData['showHebrew'] == true || isAdmin;
                      final bool showEng = widget.videoData['showEnglish'] == true || isAdmin;
                      final List<dynamic> hebWords = widget.videoData['syncedWords'] ?? [];
                      final List<dynamic> engWords = widget.videoData['syncedWordsEN'] ?? [];

                      // 🎯 Detaches text from video time during edit mode
                      final int hebGroup = (isAdmin && widget.isEditMode) ? manualRow : _calculateFocusGroup(currentMillis, hebWords);
                      final int engGroup = (isAdmin && widget.isEditMode) ? manualRow : _calculateFocusGroup(currentMillis, engWords);

                      final double defaultHeb = widget.videoData['hebrewYPos']?.toDouble() ?? 0.1;
                      final double defaultEng = widget.videoData['englishYPos']?.toDouble() ?? 0.65;

                      final double savedHebY = _getSavedStickyY(hebGroup, hebWords, defaultHeb);
                      final double savedEngY = _getSavedStickyY(engGroup, engWords, defaultEng);

                      final double hebY = _getLocalStickyY(hebGroup, _hebOverrides, savedHebY);
                      final double engY = _getLocalStickyY(engGroup, _engOverrides, savedEngY);

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          if (showHeb)
                            Positioned(
                              top: videoHeight * hebY,
                              left: 0, right: 0,
                              child: (isAdmin && widget.isEditMode)
                                  ? GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onVerticalDragUpdate: (details) { // 🎯 Switched to vertical drag
                                  double newY = hebY + (details.delta.dy / videoHeight);
                                  setState(() => _hebOverrides[hebGroup] = newY.clamp(0.0, 1.0));
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 30.0), // 🎯 Massive hitbox
                                  child: _buildFeedFlashcardRow(hebWords, currentMillis, 'hebrew', videoHeight, videoWidth, hebGroup),
                                ),
                              )
                                  : _buildFeedFlashcardRow(hebWords, currentMillis, 'hebrew', videoHeight, videoWidth, hebGroup),
                            ),
                          if (showEng)
                            Positioned(
                              top: videoHeight * engY,
                              left: 0, right: 0,
                              child: (isAdmin && widget.isEditMode)
                                  ? GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onVerticalDragUpdate: (details) { // 🎯 Switched to vertical drag
                                  double newY = engY + (details.delta.dy / videoHeight);
                                  setState(() => _engOverrides[engGroup] = newY.clamp(0.0, 1.0));
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 30.0), // 🎯 Massive hitbox
                                  child: _buildFeedFlashcardRow(engWords, currentMillis, 'english', videoHeight, videoWidth, engGroup),
                                ),
                              )
                                  : _buildFeedFlashcardRow(engWords, currentMillis, 'english', videoHeight, videoWidth, engGroup),
                            ),


                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),

        // 🎯 THE ADMIN EDIT TOGGLE BUTTON (WITH CANCEL)
        if (isAdmin)
          Positioned(
            top: 15,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isEditMode)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        _hebOverrides.clear();
                        _engOverrides.clear();
                      });
                      widget.onToggleEditMode(false);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.redAccent, width: 2),
                      ),
                      child: const Text("CANCEL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),

                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (!widget.isEditMode) {
                      _controller?.pause();
                      setState(() { _showUi = true; _isPlaying = false; });

                      final List<dynamic> hebW = widget.videoData['syncedWords'] ?? [];
                      final List<dynamic> engW = widget.videoData['syncedWordsEN'] ?? [];
                      final List<dynamic> targetW = hebW.isNotEmpty ? hebW : engW;

                      di<AppState>().manualEditRow.value = _calculateFocusGroup(_controller?.value.position.inMilliseconds ?? 0, targetW);

                      di<AppState>().editVideoController.value = _controller;
                      di<AppState>().editWaveformUrl.value = widget.videoData['waveformUrl'] ?? '';
                      di<AppState>().editTrackWords.value = targetW;

                      widget.onToggleEditMode(true);
                    } else {
                      _controller?.pause();
                      setState(() { _isPlaying = false; });

                      final List<dynamic> hebWords = widget.videoData['syncedWords'] ?? [];
                      final List<dynamic> engWords = widget.videoData['syncedWordsEN'] ?? [];

                      if (_hebOverrides.isNotEmpty) {
                        List<dynamic> updatedHeb = List.from(hebWords);
                        _hebOverrides.forEach((group, yVal) {
                          int idx = group * 3;
                          if (idx < updatedHeb.length) {
                            updatedHeb[idx] = Map<String, dynamic>.from(updatedHeb[idx]);
                            updatedHeb[idx]['y'] = yVal;
                          }
                        });
                        _updateSubtitlePosition('syncedWords', updatedHeb);
                      }

                      if (_engOverrides.isNotEmpty) {
                        List<dynamic> updatedEng = List.from(engWords);
                        _engOverrides.forEach((group, yVal) {
                          int idx = group * 3;
                          if (idx < updatedEng.length) {
                            updatedEng[idx] = Map<String, dynamic>.from(updatedEng[idx]);
                            updatedEng[idx]['y'] = yVal;
                          }
                        });
                        _updateSubtitlePosition('syncedWordsEN', updatedEng);
                      }

                      _hebOverrides.clear();
                      _engOverrides.clear();
                      widget.onToggleEditMode(false);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: widget.isEditMode ? Colors.lightBlue : Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
                    ),
                    child: Text(
                      widget.isEditMode ? "SAVE" : "EDIT SUBS",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // 5. Grandpa Gate
        if (!widget.hasSwipedFeed)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _isShowingSwipeGate ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 800),
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

        // 8. Bottom UI Layer
        Positioned(
          bottom: kIsWeb && html.window.matchMedia('(display-mode: standalone)').matches ? 15.0 : 5.0,
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
                                  final user = FirebaseAuth.instance.currentUser;
                                  if (user == null) {
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
                        onTap: _togglePlayPause,
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
                        },
                      ),
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
}

Widget _buildActionButton(IconData icon, String label, Color color, {VoidCallback? onTap}) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 35),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
        ],
      ),
    ),
  );
}