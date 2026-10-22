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
import '../sync_studio/sync_studio_screen.dart';
import 'dart:async';
import 'dart:html' as html;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../common/common.dart';
import '../app_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../sync_studio/sync_studio_screen.dart';

bool sessionAudioUnlocked = false;

class FeedTab extends StatefulWidget {
  final String? targetVideoId;

  const FeedTab({super.key, this.targetVideoId});

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

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

  Future<void> _checkAndTriggerPushPrompt() async {
    if (!kIsWeb) return;

    // Platform Check: Android/Desktop web or iOS standalone PWA mode only
    final bool isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final bool isStandalone = html.window.matchMedia('(display-mode: standalone)').matches;
    if (isIOS && !isStandalone) return;

    final prefs = await SharedPreferences.getInstance();
    bool alreadyPrompted = prefs.getBool('push_prompted_v1') ?? false;
    if (alreadyPrompted) return;

    await prefs.setBool('push_prompted_v1', true);
    _showPushPermissionBanner();
  }


  void _showPushPermissionBanner() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("🔔", style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            const Text(
              "רוצה לקבל התראה כשמשה פייגלין מעלה סרטון חדש או מגיע לדבר באזור שלך?",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.3),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("אפשר התראות", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              onPressed: () async {
                Navigator.pop(context);
                await di<AppState>().enableWebPushNotifications();
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("לא עכשיו", style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
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

    // 🎯 Refresh feed immediately when Admin status or Show Offline toggle changes!
    di<AppState>().adminShowOffline.addListener(_fetchFeedFromFirebase);
    di<AppState>().isAdmin.addListener(_fetchFeedFromFirebase);

    // 🎯 NEW: Listen for remote jump commands from the Admin Manager
    di<AppState>().targetVideo.addListener(() {
      final target = di<AppState>().targetVideo.value;
      if (target != null && _feedVideos.isNotEmpty && _pageController.hasClients) {
        int foundIndex = _feedVideos.indexWhere((v) => v['id'] == target);
        if (foundIndex != -1) {
          int virtualMiddleIndex = (_feedVideos.length * 500) + foundIndex;
          _pageController.jumpToPage(virtualMiddleIndex);
          di<AppState>().targetVideo.value = null; // Reset the trap
        }
      }
    });

    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() {
          _hasSwipedFeed = prefs.getBool('has_swiped_feed') ?? false;

          // 🎯 Timebound memory check (1 hour)
          final lastWatchedTime = prefs.getInt('last_watched_timestamp') ?? 0;
          final currentTime = DateTime.now().millisecondsSinceEpoch;
          final int expirationMs = 1 * 60 * 60 * 1000; // 1 hour in milliseconds

          if (currentTime - lastWatchedTime < expirationMs) {
            _lastVideoId = prefs.getString('last_watched_video_id');
          } else {
            _lastVideoId = null; // Memory expired! Boot to default.
          }
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

        // 1. Is the video marked as online?
        final bool isOnline = data['online'] != false && data['online'] != 'false';

        // 2. Is the user a verified admin AND do they have the override toggle turned on?
        final bool adminOverride = di<AppState>().isAdmin.value && di<AppState>().adminShowOffline.value;

        // 3. Show the video if either condition is true
        return isOnline || adminOverride;
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
          'hebrewBaseSize': data['hebrewBaseSize'],
          'englishBaseSize': data['englishBaseSize'], // 🎯 Matches your DB key
          'waveformUrl': data['waveformUrl'],
          'syncedWords': data['syncedWords'] ?? [],
          'syncedWordsEN': data['syncedWordsEN'] ?? [],
          'videoFitMode': data['videoFitMode'] ?? 'cover',
          'videoScale': (data['videoScale'] as num?)?.toDouble() ?? 1.0,
          'videoAlignX': (data['videoAlignX'] as num?)?.toDouble() ?? 0.0,
          'videoAlignY': (data['videoAlignY'] as num?)?.toDouble() ?? 0.0,
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
          // 🎯 1. Force Flutter to read the actual URL address first
          else if (kIsWeb) {
            try {
              final currentPath = html.window.location.pathname ?? '';
              if (currentPath.contains('.html') && !currentPath.contains('index.html')) {
                final extractId = currentPath.split('/').last.replaceAll('.html', '');
                int foundIndex = _feedVideos.indexWhere((v) => v['id'] == extractId);
                if (foundIndex != -1) {
                  startingIndex = foundIndex;
                  _lastVideoId = extractId; // Overwrite local storage immediately
                }
              }
            } catch (_) {}

            // 🎯 2. If the URL didn't help, try the meta tag
            if (startingIndex == 0) {
              try {
                final metaTag = html.document.querySelector('meta[name="video-id"]');
                if (metaTag != null && metaTag.attributes['content'] != null) {
                  int foundIndex = _feedVideos.indexWhere((v) => v['id'] == metaTag.attributes['content']);
                  if (foundIndex != -1) startingIndex = foundIndex;
                }
              } catch (_) {}
            }
          }

          // 🎯 3. If all else fails, load their last watched video
          if (startingIndex == 0 && _lastVideoId != null) {
            int foundIndex = _feedVideos.indexWhere((v) => v['id'] == _lastVideoId);
            if (foundIndex != -1) startingIndex = foundIndex;
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
    super.build(context); // 🎯 1. REQUIRED for keep-alive to function

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
              ? Center(child: Text('feed_no_videos'.tr(), style: const TextStyle(color: Colors.white)))
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

                  // 🎯 Check unique count through AppState
                  di<AppState>().checkAndIncrementWatchedVideo(currentVideoId).then((reachedThird) async {
                    if (reachedThird) {
                      final prefs = await SharedPreferences.getInstance();
                      bool alreadyPrompted = prefs.getBool('push_prompted_v1') ?? false;
                      if (!alreadyPrompted) {
                        _checkAndTriggerPushPrompt();
                      }
                      if (false) {
                        await prefs.setBool('push_prompted_v1', true);
                        _showPushPermissionBanner();
                      }
                    }
                  });

                  SharedPreferences.getInstance().then((prefs) =>
                      prefs.setString('last_watched_video_id', currentVideoId.toString()));
                }
              }
              return false;
            },
            // 🎯 2. Wrap PageView so it dynamically locks scrolling in Edit Mode
            child: ValueListenableBuilder<bool>(
              valueListenable: di<AppState>().isFeedEditMode,
              builder: (context, isEditMode, _) {
                return PageView.builder(
                  controller: _pageController,
                  physics: isEditMode
                      ? const NeverScrollableScrollPhysics() // 🔒 Locks swiping while editing
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
                                // Note: We already have isEditMode from the outer builder, so we don't need to listen to it again here!
                                bool isLocked = (_feedVideos[actualIndex]['isLocked'] == true || _feedVideos[actualIndex]['isLocked'] == 'true') && !isLoggedIn;

                                return FeedVideoPlayer(
                                  key: ValueKey(_feedVideos[actualIndex]['id']),
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
                              },
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
  bool _showArrow = false;
  bool _hasStartedPlaying = false; // 🎯 1. Add this tripwire
  String? _videoFitOverride;
  double? _videoScaleOverride;
  double? _videoAlignXOverride;
  double? _videoAlignYOverride;

  bool _showUi = true;
  Timer? _uiHideTimer;
  bool isAdmin = false;
  bool isLoading = true;
  int _lastJumpTime = 0; // 🎯 Tracks rapid taps
  Timer? _jumpSpamTimer;
  int? _targetJumpRow;


  bool _isShowingSwipeGate = false;

  late int likeCount;
  bool _hasTappedInitialPlay = false;

  Map<int, double> _hebOverrides = {};
  Map<int, double> _engOverrides = {};

// 🎯 Helper to find exact row boundaries
  List<int> _getRowStarts(List<dynamic> words) {
    List<int> starts = [];
    int i = 0;
    while (i < words.length) {
      starts.add(i);
      int size = (words[i] is Map && words[i]['groupSize'] != null) ? (words[i]['groupSize'] as num).toInt() : 3;
      i += size;
    }
    return starts;
  }

  // 🎯 Smart Skip Logic (Built for rapid spamming!)
  // 🎯 Absolute Time-Scanner Jump Logic (Completely bypasses row calculation)
// 🎯 Absolute Time-Scanner Jump Logic (Completely bypasses row calculation)
  void _jump(int direction, List<dynamic> words) {
    if (words.isEmpty || _controller == null) return;

    int currentMillis = _controller!.value.position.inMilliseconds;
    List<int> starts = _getRowStarts(words);

    int? targetMs;
    int targetRow = 0;

    if (direction > 0) {
      // ⏩ FAST FORWARD: Scan forward for the next row that starts AFTER the current time
      for (int r = 0; r < starts.length; r++) {
        int rowStartIdx = starts[r];
        int? rowTime;

        // Scan up to 4 words deep in this row to find a valid timestamp
        for (int i = rowStartIdx; i < words.length && i < rowStartIdx + 4; i++) {
          if (words[i] is Map && words[i]['startMs'] != null) {
            rowTime = (words[i]['startMs'] as num).toInt();
            break;
          }
        }

        // If we found a time that is strictly in the future (+50ms buffer), lock it in!
        if (rowTime != null && rowTime > currentMillis + 50) {
          targetMs = rowTime;
          targetRow = r;
          break;
        }
      }
    } else {
      // ⏪ REWIND: Scan backward for the first row that starts BEFORE the current time
      for (int r = starts.length - 1; r >= 0; r--) {
        int rowStartIdx = starts[r];
        int? rowTime;

        // Scan up to 4 words deep in this row to find a valid timestamp
        for (int i = rowStartIdx; i < words.length && i < rowStartIdx + 4; i++) {
          if (words[i] is Map && words[i]['startMs'] != null) {
            rowTime = (words[i]['startMs'] as num).toInt();
            break;
          }
        }

        // If we found a time that is strictly in the past (-50ms buffer), lock it in!
        if (rowTime != null && rowTime < currentMillis - 50) {
          targetMs = rowTime;
          targetRow = r;
          break;
        }
      }
    }

    // Force the jump to that exact time (+10ms to trigger the highlight)
    if (targetMs != null) {
      di<AppState>().manualEditRow.value = targetRow;
      _controller!.seekTo(Duration(milliseconds: targetMs + 10));
    }
  }

  int _calculateFocusGroup(int currentMillis, List<dynamic> trackWords) {
    if (trackWords.isEmpty) return 0;
    List<int> starts = _getRowStarts(trackWords);
    int lastDroppedTotal = trackWords.lastIndexWhere((w) => w is Map && w['startMs'] != null);
    if (lastDroppedTotal == -1) return 0;
    int maxDroppedTime = (trackWords[lastDroppedTotal]['startMs'] as num).toInt();

    if (currentMillis >= maxDroppedTime) {
      int nextTarget = lastDroppedTotal + 1;
      for (int r = 0; r < starts.length; r++) {
        int rowEnd = (r + 1 < starts.length) ? starts[r + 1] : trackWords.length;
        if (nextTarget >= starts[r] && nextTarget < rowEnd) return r;
      }
      return starts.length - 1;
    } else {
      int reviewIndex = trackWords.lastIndexWhere((w) => w is Map && w['startMs'] != null && ((w['startMs'] as num).toInt()) <= currentMillis);
      if (reviewIndex == -1) return 0;
      for (int r = 0; r < starts.length; r++) {
        int rowEnd = (r + 1 < starts.length) ? starts[r + 1] : trackWords.length;
        if (reviewIndex >= starts[r] && reviewIndex < rowEnd) return r;
      }
      return 0;
    }
  }

  Widget _buildFeedFlashcardRow(List<dynamic> trackWords, int currentMillis, String lang, double videoHeight, double videoWidth, int activeGroup, {double? customFontSize}) {
    if (trackWords.isEmpty) return const SizedBox.shrink();

    List<int> starts = _getRowStarts(trackWords);
    if (activeGroup >= starts.length) return const SizedBox.shrink();

    int startIndex = starts[activeGroup];
    int currentSize = (trackWords[startIndex] is Map && trackWords[startIndex]['groupSize'] != null)
        ? (trackWords[startIndex]['groupSize'] as num).toInt()
        : 3;
    int endIndex = (startIndex + currentSize > trackWords.length) ? trackWords.length : startIndex + currentSize;

    List<dynamic> activeTriplets = trackWords.sublist(startIndex, endIndex);

    // 🎯 USE THE DB SIZE IF IT EXISTS, OTHERWISE FALLBACK TO 0.035
// 🎯 SCALE LOGICAL PIXELS TO INTRINSIC VIDEO RESOLUTION
    // Sync Studio treats 22.0 as normal. We use that baseline to map the slider mathematically!
    double defaultScale = videoHeight * 0.035;
    double baseSize = customFontSize != null
        ? (customFontSize / 22.0) * defaultScale
        : defaultScale;
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
          int nextMarkerTime = (globalIndex < trackWords.length - 1 && trackWords[globalIndex + 1] is Map && trackWords[globalIndex + 1]['startMs'] != null)
              ? (trackWords[globalIndex + 1]['startMs'] as num).toInt()
              : _controller!.value.duration.inMilliseconds;

          if (currentMillis < nextMarkerTime) isHighlighted = true;
        }

        double fontSize = isHighlighted ? baseSize * 1.3 : baseSize;

        // 🎯 ADVANCED DYNAMIC COLOR THEMES (Matches Sync Studio)
// 🎯 ADVANCED DYNAMIC COLOR THEMES
        Color strokeColor;

        // 🎯 ONE SINGLE FILL COLOR FOR BOTH LANGUAGES
        // If Colors.yellowAccent still looks too orange/warm on your screen,
        // change this right here to Colors.limeAccent or a specific hex like const Color(0xFFCCFF00)
        Color fillColor = isHighlighted ? Colors.yellowAccent : Colors.black;

        if (lang == 'hebrew') {
          strokeColor = isHighlighted ? Colors.pinkAccent : Colors.purpleAccent.shade100;
        } else {
          strokeColor = Colors.lightBlueAccent;
        }

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: videoWidth * 0.015),
          child: Directionality(
            textDirection: lang == 'hebrew' ? ui.TextDirection.rtl : ui.TextDirection.ltr,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 🎯 1. THE GLOW & BORDER LAYER
                Text(word,
                    textAlign: TextAlign.center,
                    textDirection: lang == 'hebrew' ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = videoHeight * 0.005
                        ..color = strokeColor, // The border color
                      shadows: [
                        // 🎯 THE NEON GLOW: Uses the stroke color, zero offset, high blur!
                        Shadow(color: strokeColor, blurRadius: 15, offset: Offset.zero),
                        // 🎯 THE DROP SHADOW: Keeps it readable on bright white backgrounds
                        const Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 2)),
                      ],
                    )
                ),
                // 🎯 2. THE SOLID FILL LAYER (Yellow or Black)
                Text(word,
                    textAlign: TextAlign.center,
                    textDirection: lang == 'hebrew' ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      color: fillColor,
                    )
                ),
              ],
            ),
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
    List<int> starts = _getRowStarts(words);
    if (targetGroup < starts.length) {
      int exactIdx = starts[targetGroup];
      if (exactIdx < words.length && words[exactIdx] is Map && words[exactIdx]['y'] != null) {
        return (words[exactIdx]['y'] as num).toDouble();
      }
    }
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
      di<AppState>().isAdmin.value = isAdminUser;
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
    if (widget.isEditMode) return; // 🎯 Prevents screen taps from waking the UI while editing

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
  void _updateSubtitlePosition(String key, dynamic val) {
    FirebaseFirestore.instance
        .collection('feeds')
        .doc(widget.videoData['id'])
        .set({key: val}, SetOptions(merge: true));
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
        // 🎯 ADD THIS: The absolute second the video paints its first real frames, lock the tripwire forever.
        if (newController.value.position.inMilliseconds > 100 && !_hasStartedPlaying) {
          setState(() {
            _hasStartedPlaying = true;
          });
        }
        bool actualPlaying = newController.value.isPlaying;
        if (actualPlaying && newController.value.position == Duration.zero) {
          actualPlaying = false;
        }
        if (_isPlaying != actualPlaying) {
          setState(() => _isPlaying = actualPlaying);
        }
        // 🎯 2. ADD THIS: Once it plays for the first time, lock the tripwire
        if (actualPlaying && !_hasStartedPlaying) {
          setState(() => _hasStartedPlaying = true);
        }
// 🎯 2. DROP THE FINGER LOGIC EXACTLY HERE:
        if (widget.videoData['id']?.toString().contains('host-moshe') == true) {
          final currentSecond = newController.value.position.inSeconds;
          if (currentSecond >= 8 && !_showArrow) {
            setState(() => _showArrow = true);
          } else if (currentSecond < 8 && _showArrow) {
            setState(() => _showArrow = false);
          }
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
    final _ = context.locale;
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

        // 1. BASE LAYER: The Video itself (With saved 9:16 Cover vs 16:9 Fit, Zoom & Pan!)
        if (_isInitialized && _controller != null)
          Builder(
            builder: (context) {
              final String activeFit = _videoFitOverride ?? (widget.videoData['videoFitMode']?.toString() ?? 'cover');
              final double activeScale = _videoScaleOverride ?? ((widget.videoData['videoScale'] as num?)?.toDouble() ?? 1.0);
              final double activeAlignX = _videoAlignXOverride ?? ((widget.videoData['videoAlignX'] as num?)?.toDouble() ?? 0.0);
              final double activeAlignY = _videoAlignYOverride ?? ((widget.videoData['videoAlignY'] as num?)?.toDouble() ?? 0.0);

              return ClipRect(
                child: Transform.scale(
                  scale: activeScale,
                  child: FittedBox(
                    fit: activeFit == 'contain' ? BoxFit.contain : BoxFit.cover,
                    alignment: Alignment(activeAlignX, activeAlignY),
                    child: SizedBox(
                      width: videoWidth,
                      height: videoHeight,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                ),
              );
            },
          ),


// 2. Thumbnail Shield
        if (!_hasStartedPlaying && !_isPlaying) // 🎯 Instantly un-renders the image when play is pressed
          IgnorePointer(
            ignoring: true,
            child: Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: thumbUrl.isNotEmpty
                  ? Image.network(thumbUrl, fit: BoxFit.fitWidth)
                  : const SizedBox.expand(),
            ),
          ),

        // 3. MIDDLE LAYER: Full-Screen Tap Layer
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _togglePlayPause,
          ),
        ),

        // 🎯 3.5 THE EDIT MODE GLASS SHIELD (Drag anywhere on background to pan video X/Y!)
        if (isAdmin && widget.isEditMode)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) {
                final double curX = _videoAlignXOverride ?? ((widget.videoData['videoAlignX'] as num?)?.toDouble() ?? 0.0);
                final double curY = _videoAlignYOverride ?? ((widget.videoData['videoAlignY'] as num?)?.toDouble() ?? 0.0);
                setState(() {
                  _videoAlignXOverride = (curX - details.delta.dx * 0.006).clamp(-1.0, 1.0);
                  _videoAlignYOverride = (curY - details.delta.dy * 0.006).clamp(-1.0, 1.0);
                });
              },
              child: Container(
                color: Colors.blueAccent.withOpacity(0.10),
              ),
            ),
          ),

        // 4. TOP LAYER: Touchable, Draggable Subtitles
        if (_isInitialized && _controller != null && (_hasStartedPlaying || _isPlaying))
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: videoWidth,
              height: videoHeight,
              child: AnimatedBuilder(
                animation: _controller!,
                builder: (context, child) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: di<AppState>().adminForceShowSubs,
                    builder: (context, forceShow, _) {

                      final currentMillis = _controller!.value.position.inMilliseconds;

                      // 1. Safely check if the public Sync Studio toggle is ON
                      final bool isGlobalHebOn = widget.videoData['showHebrew'] == true || widget.videoData['showHebrew'] == 'true';
                      final bool isGlobalEngOn = widget.videoData['showEnglish'] == true || widget.videoData['showEnglish'] == 'true';

                      // 2. STRICT VISIBILITY: Only show the language if it is explicitly turned ON in Sync Studio.
                      // (We removed the force-show in Edit Mode so the extra row stops ruining your vertical positioning!)
                      final bool showHeb = isGlobalHebOn;
                      final bool showEng = isGlobalEngOn;

                      final List<dynamic> hebWords = widget.videoData['syncedWords'] ?? [];
                      final List<dynamic> engWords = widget.videoData['syncedWordsEN'] ?? [];

                      // 🎯 Let the subtitles sync to the actual video time even in edit mode!
                      final int hebGroup = _calculateFocusGroup(currentMillis, hebWords);
                      final int engGroup = _calculateFocusGroup(currentMillis, engWords);

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
                            AnimatedPositioned(
                              duration: widget.isEditMode ? Duration.zero : const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              top: videoHeight * hebY,
                              left: 0, right: 0,
                              child: (isAdmin && widget.isEditMode)
                                  ? GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onVerticalDragUpdate: (details) {
                                  double newY = hebY + (details.delta.dy / videoHeight);
                                  setState(() => _hebOverrides[hebGroup] = newY.clamp(0.0, 1.0));
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 30.0),
                                  child: _buildFeedFlashcardRow(hebWords, currentMillis, 'hebrew', videoHeight, videoWidth, hebGroup,customFontSize: widget.videoData['hebrewBaseSize']?.toDouble(),),
                                ),
                              )
                                  : _buildFeedFlashcardRow(hebWords, currentMillis, 'hebrew', videoHeight, videoWidth, hebGroup,customFontSize: widget.videoData['hebrewBaseSize']?.toDouble(),),
                            ),
                          if (showEng)
                            AnimatedPositioned(
                              duration: widget.isEditMode ? Duration.zero : const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              top: videoHeight * engY,
                              left: 0, right: 0,
                              child: (isAdmin && widget.isEditMode)
                                  ? GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onVerticalDragUpdate: (details) {
                                  double newY = engY + (details.delta.dy / videoHeight);
                                  setState(() => _engOverrides[engGroup] = newY.clamp(0.0, 1.0));
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 30.0),
                                  child: _buildFeedFlashcardRow(engWords, currentMillis, 'english', videoHeight, videoWidth, engGroup,customFontSize: widget.videoData['englishBaseSize']?.toDouble(),),
                                ),
                              )
                                  : _buildFeedFlashcardRow(engWords, currentMillis, 'english', videoHeight, videoWidth, engGroup,customFontSize: widget.videoData['englishBaseSize']?.toDouble(),),
                            ),
                        ],
                      );
                    },
                  );
                },
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
          child: IgnorePointer(
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
        ),

        // 🎯 3. DROP THE ARROW EXACTLY HERE:
        if (widget.videoData['id']?.toString().contains('host-moshe') == true)
          Positioned(
            bottom: 0, // Adjust to hover perfectly above your center icon
            left: 0,
            right: 0,
            child: IgnorePointer( // Prevents the arrow from blocking taps
              child: Center(
                child: BouncingArrow(show: _showArrow),
              ),
            ),
          ),

        // 8. Bottom UI Layer
        if (!widget.isEditMode)
          Positioned(
            bottom: kIsWeb && html.window.matchMedia('(display-mode: standalone)').matches ? 5.0 : -5.0,
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
                            String rawUrl = (widget.videoData['url']?.toString() ?? "").split('?').first;
                                String docId = widget.videoData['id']?.toString() ?? "";
                                String htmlFileName = rawUrl.split('/').last.replaceAll('.mp4', '.html');
                                if (htmlFileName.contains('host-moshe') || docId.contains('host-moshe')) {
                                  htmlFileName = 'host-moshe-national.html';
                                }
                                String exactLink = "https://gamfeiglintzadak.co.il/$htmlFileName?v=77";
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


        // 🎯 TOP-LEFT (TL) PORTAL TO SYNC STUDIO (Paper & Pen Icon ONLY — No Box, No Pill!)
        if (isAdmin && widget.isEditMode)
          PositionedDirectional(
            top: 4,
            start: 10,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _controller?.pause();
                setState(() => _isPlaying = false);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SyncStudioScreen(
                      docId: widget.videoData['id']?.toString() ?? '',
                      videoUrl: widget.videoData['url']?.toString() ?? '',
                    ),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.all(12.0),
                child: FaIcon(
                  FontAwesomeIcons.fileSignature,
                  color: Colors.orangeAccent,
                  size: 24,
                ),
              ),
            ),
          ),

        // 🎯 TOP-RIGHT (TR) CANCEL / EDIT SUBS
        if (isAdmin)
          PositionedDirectional(
            top: -10,
            end: -15,
            child: ValueListenableBuilder<bool>(
              valueListenable: di<AppState>().adminShowEditButton,
              builder: (context, showEditBtn, _) {
                if (!showEditBtn) return const SizedBox.shrink();

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (!widget.isEditMode) {
                      _controller?.pause();
                      setState(() { _showUi = false; _isPlaying = false; });
                      final List<dynamic> hebW = widget.videoData['syncedWords'] ?? [];
                      final List<dynamic> engW = widget.videoData['syncedWordsEN'] ?? [];
                      final List<dynamic> targetW = (hebW.length > engW.length) ? hebW : engW;

                      di<AppState>().manualEditRow.value = _calculateFocusGroup(_controller?.value.position.inMilliseconds ?? 0, targetW);
                      di<AppState>().editVideoController.value = _controller;
                      di<AppState>().editWaveformUrl.value = widget.videoData['waveformUrl'] ?? '';
                      di<AppState>().editTrackWords.value = targetW;
                      widget.onToggleEditMode(true);
                    } else {
                      setState(() {
                        _hebOverrides.clear();
                        _engOverrides.clear();
                        _videoFitOverride = null;
                        _videoScaleOverride = null;
                        _videoAlignXOverride = null;
                        _videoAlignYOverride = null;
                        _showUi = true;
                      });
                      widget.onToggleEditMode(false);
                      _startUiHideTimer();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          widget.isEditMode ? 'btn_cancel'.tr() : 'btn_edit_subs'.tr(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            foreground: Paint()
                              ..style = PaintingStyle.stroke
                              ..strokeWidth = 2.5
                              ..color = widget.isEditMode ? Colors.grey.shade400 : Colors.lightBlueAccent,
                          ),
                        ),
                        Text(
                          widget.isEditMode ? 'btn_cancel'.tr() : 'btn_edit_subs'.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        // 🎯 10. THE UNIFIED SINGLE BOTTOM ROW EDITOR
        if (isAdmin && widget.isEditMode)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: EdgeInsets.only(
                  top: 8,
                  bottom: kIsWeb && html.window.matchMedia('(display-mode: standalone)').matches ? 20.0 : 8.0,
                  left: 8,
                  right: 8,
                ),
                decoration: const BoxDecoration(color: Colors.black),
                child: Builder(
                  builder: (context) {
                    final String curFit = _videoFitOverride ?? (widget.videoData['videoFitMode']?.toString() ?? 'cover');
                    final double curScale = _videoScaleOverride ?? ((widget.videoData['videoScale'] as num?)?.toDouble() ?? 1.0);
                    final bool isContain = curFit == 'contain';

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 1. LEFT ARROW (Flipped: Icons.fast_rewind / _jump(-1))
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                          icon: const Icon(Icons.fast_rewind, color: Colors.white, size: 26),
                          onPressed: () => _jump(-1, di<AppState>().editTrackWords.value),
                        ),

                        // 2. PLAIN TEXT 9:16 / 16:9 TOGGLE (No icon, no pill)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() {
                              _videoFitOverride = isContain ? 'cover' : 'contain';
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            child: Text(
                              isContain ? '16:9' : '9:16',
                              style: TextStyle(
                                color: isContain ? Colors.orangeAccent : Colors.lightBlueAccent,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),

                        // 3. TIGHT - 1.0x + ZOOM CONTROLS
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                setState(() {
                                  _videoScaleOverride = (curScale - 0.1).clamp(0.6, 2.5);
                                });
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                                child: Text('−', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                              ),
                            ),
                            Text(
                              curScale.toStringAsFixed(1),
                              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                setState(() {
                                  _videoScaleOverride = (curScale + 0.1).clamp(0.6, 2.5);
                                });
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                                child: Text('+', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ],
                        ),

                        // 4. PURPLE RESET BUTTON (Grouped with Clear Demarcation: Subtitles vs. Video Frame)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                          icon: const Icon(Icons.restore, color: Colors.deepPurpleAccent, size: 26),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (dialogCtx) => AlertDialog(
                                backgroundColor: const Color(0xFF103856),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: const Text(
                                  'Reset Options',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      'SUBTITLE POSITIONS',
                                      style: TextStyle(color: Colors.lightBlueAccent, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.lightBlue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(dialogCtx);
                                        final currentMillis = _controller?.value.position.inMilliseconds ?? 0;
                                        final hebW = widget.videoData['syncedWords'] ?? [];
                                        final engW = widget.videoData['syncedWordsEN'] ?? [];
                                        setState(() {
                                          _hebOverrides[_calculateFocusGroup(currentMillis, hebW)] = 0.30;
                                          _engOverrides[_calculateFocusGroup(currentMillis, engW)] = 0.60;
                                        });
                                      },
                                      child: const Text('RESET CURRENT ROW', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(dialogCtx);
                                        final hebW = widget.videoData['syncedWords'] ?? [];
                                        final engW = widget.videoData['syncedWordsEN'] ?? [];
                                        setState(() {
                                          for (int i = 0; i < _getRowStarts(hebW).length; i++) {
                                            _hebOverrides[i] = 0.20;
                                          }
                                          for (int i = 0; i < _getRowStarts(engW).length; i++) {
                                            _engOverrides[i] = 0.80;
                                          }
                                        });
                                      },
                                      child: const Text('RESET ALL SUBTITLE ROWS', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),

                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                      child: Divider(color: Colors.white38, thickness: 1.5),
                                    ),

                                    const Text(
                                      'VIDEO FRAME & ZOOM',
                                      style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orangeAccent,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(dialogCtx);
                                        setState(() {
                                          _videoFitOverride = 'cover';
                                          _videoScaleOverride = 1.0;
                                          _videoAlignXOverride = 0.0;
                                          _videoAlignYOverride = 0.0;
                                        });
                                      },
                                      child: const Text('RESET FRAME (9:16 • 1.0x)', style: TextStyle(fontWeight: FontWeight.w900)),
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton(
                                      onPressed: () => Navigator.pop(dialogCtx),
                                      child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        // 5. PLAY / PAUSE
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (_controller != null) {
                              if (_controller!.value.isPlaying) {
                                _controller!.pause();
                                setState(() => _isPlaying = false);
                              } else {
                                _controller!.setVolume(1.0);
                                _controller!.play();
                                setState(() => _isPlaying = true);
                              }
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                            child: (_controller != null && _controller!.value.isPlaying)
                                ? const Icon(Icons.pause, color: Colors.white, size: 28)
                                : const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                          ),
                        ),

                        // 6. SAVE
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                          icon: const Icon(Icons.save, color: Colors.lightBlue, size: 26),
                          onPressed: () async {
                            _controller?.pause();
                            setState(() { _showUi = true; _isPlaying = false; });

                            List<dynamic> hebWords = widget.videoData['syncedWords'] != null ? List.from(widget.videoData['syncedWords']) : [];
                            List<dynamic> engWords = widget.videoData['syncedWordsEN'] != null ? List.from(widget.videoData['syncedWordsEN']) : [];

                            double finalHebrewY = 0.15;
                            if (_hebOverrides.isNotEmpty) {
                              finalHebrewY = _hebOverrides.values.first;
                            } else if (hebWords.isNotEmpty && hebWords[0] is Map && hebWords[0]['y'] != null) {
                              finalHebrewY = (hebWords[0]['y'] as num).toDouble();
                            }

                            double finalEnglishY = 0.65;
                            if (_engOverrides.isNotEmpty) {
                              finalEnglishY = _engOverrides.values.first;
                            } else if (engWords.isNotEmpty && engWords[0] is Map && engWords[0]['y'] != null) {
                              finalEnglishY = (engWords[0]['y'] as num).toDouble();
                            }

                            for (int i = 0; i < hebWords.length; i++) {
                              hebWords[i] = Map<String, dynamic>.from(hebWords[i]);
                              hebWords[i]['y'] = finalHebrewY;
                            }
                            for (int i = 0; i < engWords.length; i++) {
                              engWords[i] = Map<String, dynamic>.from(engWords[i]);
                              engWords[i]['y'] = finalEnglishY;
                            }

                            final String finalFitMode = _videoFitOverride ?? (widget.videoData['videoFitMode']?.toString() ?? 'cover');
                            final double finalScale = _videoScaleOverride ?? ((widget.videoData['videoScale'] as num?)?.toDouble() ?? 1.0);
                            final double finalAlignX = _videoAlignXOverride ?? ((widget.videoData['videoAlignX'] as num?)?.toDouble() ?? 0.0);
                            final double finalAlignY = _videoAlignYOverride ?? ((widget.videoData['videoAlignY'] as num?)?.toDouble() ?? 0.0);

                            widget.videoData['videoFitMode'] = finalFitMode;
                            widget.videoData['videoScale'] = finalScale;
                            widget.videoData['videoAlignX'] = finalAlignX;
                            widget.videoData['videoAlignY'] = finalAlignY;

                            await FirebaseFirestore.instance.collection('feeds').doc(widget.videoData['id']).update({
                              'hebrewYPos': finalHebrewY,
                              'englishYPos': finalEnglishY,
                              'syncedWords': hebWords,
                              'syncedWordsEN': engWords,
                              'videoFitMode': finalFitMode,
                              'videoScale': finalScale,
                              'videoAlignX': finalAlignX,
                              'videoAlignY': finalAlignY,
                            });

                            _hebOverrides.clear();
                            _engOverrides.clear();
                            widget.onToggleEditMode(false);
                            _startUiHideTimer();
                          },
                        ),

                        // 7. RIGHT ARROW (Flipped: FastForwardIcon / _jump(1))
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                          icon: const FastForwardIcon(size: 22, color: Colors.white),
                          onPressed: () => _jump(1, di<AppState>().editTrackWords.value),
                        ),
                      ],
                    );
                  },
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

class BouncingArrow extends StatefulWidget {
  final bool show;
  const BouncingArrow({super.key, required this.show});

  @override
  State<BouncingArrow> createState() => _BouncingArrowState();
}

class _BouncingArrowState extends State<BouncingArrow> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final String currentPath = html.window.location.pathname?.toLowerCase() ?? '';
    if (currentPath.contains('parlor-meetings') || currentPath.contains('eight-point-plan') || currentPath.contains('kitat-konenut')) {
      return; // Stop execution so the feed tab stays out of the way!
    }
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: widget.show ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _controller.value * -15),
            child: const Icon(
              Icons.keyboard_double_arrow_down_rounded,
              color: Colors.yellowAccent,
              size: 70, // Massive and unmissable
              shadows: [
                Shadow(color: Colors.black, blurRadius: 10, offset: Offset(0, 2))
              ],
            ),
          );
        },
      ),
    );
  }
}

class FastForwardIcon extends StatelessWidget {
  final double size;
  final Color color;
  const FastForwardIcon({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size, size), painter: _MediaIconPainter(color: color, isForward: true));
  }
}

class FastRewindIcon extends StatelessWidget {
  final double size;
  final Color color;
  const FastRewindIcon({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size, size), painter: _MediaIconPainter(color: color, isForward: false));
  }
}

class _MediaIconPainter extends CustomPainter {
  final Color color;
  final bool isForward;

  _MediaIconPainter({required this.color, required this.isForward});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final Path path = Path();
    final double w = size.width;
    final double h = size.height;

    // Nudge top and bottom to create standard media proportions
    final double top = h * 0.2;
    final double bottom = h * 0.8;
    final double midY = h * 0.5;

    if (isForward) {
      // Left triangle
      path.moveTo(0, top);
      path.lineTo(w * 0.45, midY);
      path.lineTo(0, bottom);
      path.close();
      // Right triangle
      path.moveTo(w * 0.45, top);
      path.lineTo(w * 0.90, midY);
      path.lineTo(w * 0.45, bottom);
      path.close();
    } else {
      // Right triangle
      path.moveTo(w, top);
      path.lineTo(w * 0.55, midY);
      path.lineTo(w, bottom);
      path.close();
      // Left triangle
      path.moveTo(w * 0.55, top);
      path.lineTo(w * 0.10, midY);
      path.lineTo(w * 0.55, bottom);
      path.close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}