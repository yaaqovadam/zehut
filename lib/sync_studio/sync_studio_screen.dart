import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import '../sync_studio/sync_studio_screen.dart';
import 'dart:ui' as ui;

class SyncStudioScreen extends StatefulWidget {
  final String docId;
  final String videoUrl;

  const SyncStudioScreen({Key? key, required this.docId, required this.videoUrl}) : super(key: key);

  @override
  State<SyncStudioScreen> createState() => _SyncStudioScreenState();
}

class _SyncStudioScreenState extends State<SyncStudioScreen> {
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;
  String _englishTranslation = "";

  // Scrubber Engine State
  bool _isScrubbing = false;
  double _scrubPositionMs = 0.0;
  DateTime _lastScrubTime = DateTime.now();
  String _hebrewRawText = "";
  String _englishRawText = "";

  // Language & Settings State
  String _activeLanguage = 'hebrew';
  bool _showHebrew = true;
  bool _showEnglish = true;

  // ValueNotifiers allow the bottom sheet to update the background UI instantly
  final ValueNotifier<double> _hebrewBaseSize = ValueNotifier(22.0);
  final ValueNotifier<double> _englishBaseSize = ValueNotifier(20.0);

  // Setup State
  bool _isTranscribing = false;
  bool _isGeneratingWaveform = false;
  String? _waveformUrl;
  final TextEditingController _scriptController = TextEditingController();

  // Dual-Track Engine State
  bool _isHebrewLocked = false;
  bool _isEnglishLocked = false;
  List<Map<String, dynamic>> _hebrewWords = [];
  List<Map<String, dynamic>> _englishWords = [];

  // Dynamic Getters point to whichever language you selected in Settings
  List<Map<String, dynamic>> get _activeWords => _activeLanguage == 'hebrew' ? _hebrewWords : _englishWords;
  bool get _isActiveScriptLocked => _activeLanguage == 'hebrew' ? _isHebrewLocked : _isEnglishLocked;

  // Playback & Audio State
  double _playbackSpeed = 1.0;
  final List<double> _speeds = [0.25, 0.5, 1.0, 1.5, 2.0];
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
    _loadFirestoreData();
  }

  Future<void> _initVideo() async {
    _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    await _videoController.initialize();
    setState(() {
      _isVideoInitialized = true;
    });
  }

  void _openSettingsPanel() {
    showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF103856),
        isScrollControlled: true,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setModalState) {
                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('sync_settings_title'.tr(), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),

                      // ACTIVE SYNC TRACK SELECTOR
                      Text('sync_active_track'.tr(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _activeLanguage == 'hebrew' ? Colors.blueAccent : Colors.transparent,
                                side: BorderSide(color: _activeLanguage == 'hebrew' ? Colors.blueAccent : Colors.white54),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () {
                                if (_activeLanguage == 'english') _englishRawText = _scriptController.text; // Save edits
                                setModalState(() => _activeLanguage = 'hebrew');
                                setState(() {
                                  _activeLanguage = 'hebrew';
                                  if (!_isHebrewLocked) _scriptController.text = _hebrewRawText;
                                });
                              },
                              child: Text('sync_hebrew_btn'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _activeLanguage == 'english' ? Colors.orangeAccent : Colors.transparent,
                                side: BorderSide(color: _activeLanguage == 'english' ? Colors.orangeAccent : Colors.white54),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () {
                                if (_activeLanguage == 'hebrew') _hebrewRawText = _scriptController.text; // Save edits
                                setModalState(() => _activeLanguage = 'english');
                                setState(() {
                                  _activeLanguage = 'english';
                                  if (!_isEnglishLocked) _scriptController.text = _englishRawText;
                                });
                              },
                              child: Text('sync_english_btn'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
// 🎯 THE SMART RESET BUTTON (Fully Localized)
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            // 1. Grab the translated name of the active track (e.g. "עברית" or "English")
                            String localizedLangName = _activeLanguage == 'hebrew' ? 'sync_hebrew_btn'.tr() : 'sync_english_btn'.tr();

                            // 🛑 PREVENT ACCIDENTAL TAPS: The Confirmation Dialog
                            showDialog(
                                context: context,
                                builder: (BuildContext dialogContext) {
                                  return AlertDialog(
                                    backgroundColor: const Color(0xFF103856),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: Text('sync_reset_warning_title'.tr(), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                    content: Text(
                                      'sync_reset_warning_desc'.tr(args: [localizedLangName]), // 🎯 Injects the language dynamically
                                      style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dialogContext),
                                        child: Text('sync_reset_cancel'.tr(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            if (_activeLanguage == 'hebrew') {
                                              for (var w in _hebrewWords) { w['startMs'] = null; }
                                            } else {
                                              for (var w in _englishWords) { w['startMs'] = null; }
                                            }
                                          });
                                          _silentAutoSave();
                                          Navigator.pop(dialogContext);
                                          Navigator.pop(context);
                                        },
                                        child: Text('sync_reset_confirm'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  );
                                }
                            );
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: (_activeLanguage == 'hebrew' ? Colors.blueAccent : Colors.orangeAccent).withOpacity(0.1),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                  color: _activeLanguage == 'hebrew' ? Colors.blueAccent : Colors.orangeAccent,
                                  width: 1.5
                              ),
                            ),
                          ),
                          icon: Icon(
                              Icons.warning_amber_rounded,
                              color: _activeLanguage == 'hebrew' ? Colors.blueAccent : Colors.orangeAccent
                          ),
                          label: Text(
                            // 🎯 Translates the button text and injects the language name
                              'sync_reset_btn'.tr(args: [_activeLanguage == 'hebrew' ? 'sync_hebrew_btn'.tr() : 'sync_english_btn'.tr()]),
                              style: TextStyle(
                                  color: _activeLanguage == 'hebrew' ? Colors.blueAccent : Colors.orangeAccent,
                                  fontWeight: FontWeight.bold
                              )
                          ),
                        ),
                      ),                     const SizedBox(height: 20),
                      const Divider(color: Colors.white24),

                      // Visibility Toggles
                      SwitchListTile(
                        title: Text('sync_show_hebrew'.tr(), style: const TextStyle(color: Colors.white)),
                        value: _showHebrew,
                        activeColor: Colors.lightBlueAccent,
                        onChanged: (val) {
                          setModalState(() => _showHebrew = val);
                          setState(() => _showHebrew = val);
                          _updateSetting('showHebrew', val);
                        },
                      ),
                      SwitchListTile(
                        title: Text('sync_show_english'.tr(), style: const TextStyle(color: Colors.white)),
                        value: _showEnglish,
                        activeColor: Colors.orangeAccent,
                        onChanged: (val) {
                          setModalState(() => _showEnglish = val);
                          setState(() => _showEnglish = val);
                          _updateSetting('showEnglish', val);
                        },
                      ),
                      const Divider(color: Colors.white24),

                      // Hebrew Font Size Slider & Live Preview
                      Text('sync_heb_font_size'.tr(), style: const TextStyle(color: Colors.white70)),
                      ValueListenableBuilder<double>(
                          valueListenable: _hebrewBaseSize,
                          builder: (context, size, child) {
                            return Row(
                              children: [
                                Expanded(
                                  child: Slider(
                                    value: size,
                                    min: 14.0, max: 50.0,
                                    activeColor: Colors.blueAccent,
                                    onChanged: (val) => _hebrewBaseSize.value = val,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Text("זהות", style: TextStyle(
                                      fontSize: size, fontWeight: FontWeight.w900,
                                      foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = 4.0..color = Colors.purpleAccent.shade100, // 🎯 Lavender border
                                    )),
                                    Text("זהות", style: TextStyle(
                                      fontSize: size, fontWeight: FontWeight.w900, color: Colors.black, // 🎯 Black font
                                    )),
                                  ],
                                ),
                              ],
                            );
                          }
                      ),

                      const SizedBox(height: 10),

                      // English Font Size Slider & Live Preview
                      Text('sync_eng_font_size'.tr(), style: const TextStyle(color: Colors.white70)),
                      ValueListenableBuilder<double>(
                          valueListenable: _englishBaseSize,
                          builder: (context, size, child) {
                            return Row(
                              children: [
                                Expanded(
                                  child: Slider(
                                    value: size,
                                    min: 14.0, max: 50.0,
                                    activeColor: Colors.orangeAccent,
                                    onChanged: (val) => _englishBaseSize.value = val,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Text("Sync", style: TextStyle(
                                      fontSize: size, fontWeight: FontWeight.w900,
                                      foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = 3.0..color = Colors.lightBlueAccent,
                                    )),
                                    Text("Sync", style: TextStyle(
                                      fontSize: size, fontWeight: FontWeight.w900, color: Colors.black,
                                    )),
                                  ],
                                ),
                              ],
                            );
                          }
                      ),
                    ],
                  ),
                );
              }
          );
        }
    );
  }




  Future<void> _updateSetting(String key, dynamic value) async {
    try {
      await FirebaseFirestore.instance.collection('feeds').doc(widget.docId).set({
        key: value,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Failed to update $key: $e");
    }
  }

  Future<void> _loadFirestoreData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('feeds').doc(widget.docId).get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          if (data['showHebrew'] != null) _showHebrew = data['showHebrew'];
          if (data['showEnglish'] != null) _showEnglish = data['showEnglish'];

          if (data['hebrewScript'] != null) _hebrewRawText = data['hebrewScript'];
          if (data['englishScript'] != null) _englishRawText = data['englishScript'];
          _scriptController.text = _activeLanguage == 'hebrew' ? _hebrewRawText : _englishRawText;
          if (data['waveformUrl'] != null) _waveformUrl = data['waveformUrl'];

          if (data['syncedWords'] != null) {
            _hebrewWords = List<dynamic>.from(data['syncedWords']).map((w) => Map<String, dynamic>.from(w)).toList();
            _isHebrewLocked = true;
          }
          if (data['syncedWordsEN'] != null) {
            _englishWords = List<dynamic>.from(data['syncedWordsEN']).map((w) => Map<String, dynamic>.from(w)).toList();
            _isEnglishLocked = true;
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading from DB: $e");
    }

    if (_waveformUrl == null) _checkWaveform();
  }

  Future<void> _silentAutoSave() async {
    try {
      await FirebaseFirestore.instance.collection('feeds').doc(widget.docId).set({
        'syncedWords': _hebrewWords,
        'syncedWordsEN': _englishWords,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Auto-save failed: $e");
    }
  }

  Future<void> _checkWaveform() async {
    final targetUrl = 'https://pub-142306085f2b48bda4045cd9efdd0d28.r2.dev/${widget.docId}_wave.png?v=3';
    final response = await http.head(Uri.parse(targetUrl));
    if (response.statusCode == 200) {
      setState(() { _waveformUrl = targetUrl; });
    }
  }

  // --- ACTIONS ---

  void _lockScript() {
    // Lock in whatever the user was currently typing in the box
    if (_activeLanguage == 'hebrew') {
      _hebrewRawText = _scriptController.text.trim();
    } else {
      _englishRawText = _scriptController.text.trim();
    }

    setState(() {
      // Chop & Lock Hebrew if it exists
      if (_hebrewRawText.isNotEmpty && !_isHebrewLocked) {
        _hebrewWords = _hebrewRawText.split(RegExp(r'\s+')).map((w) => {'word': w, 'startMs': null}).toList();
        _isHebrewLocked = true;
      }

      // Chop & Lock English if it exists
      if (_englishRawText.isNotEmpty && !_isEnglishLocked) {
        _englishWords = _englishRawText.split(RegExp(r'\s+')).map((w) => {'word': w, 'startMs': null}).toList();
        _isEnglishLocked = true;
      }
    });

    _silentAutoSave();
  }

  void _addNextMarker() {
    final currentMillis = _videoController.value.position.inMilliseconds;
    final targetList = _activeWords;

    int targetIndex = targetList.indexWhere((w) => w['startMs'] == null);

    if (targetIndex != -1) {
      int minBound = (targetIndex == 0) ? 0 : (targetList[targetIndex - 1]['startMs'] ?? 0);
      setState(() {
        targetList[targetIndex]['startMs'] = currentMillis < minBound ? minBound : currentMillis;
      });
      _silentAutoSave();
    }
  }

  void _removeLastMarker() {
    final targetList = _activeWords;
    int lastIndex = targetList.lastIndexWhere((w) => w['startMs'] != null);

    if (lastIndex != -1) {
      setState(() {
        targetList[lastIndex]['startMs'] = null;
      });
      _silentAutoSave();
    }
  }

  void _togglePlayStop() {
    if (_videoController.value.isPlaying) {
      _videoController.pause();
    } else {
      _videoController.play();
    }
    setState(() {});
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _videoController.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _cycleSpeed() {
    int currentIndex = _speeds.indexOf(_playbackSpeed);
    int nextIndex = (currentIndex + 1) % _speeds.length;
    double newSpeed = _speeds[nextIndex];

    _videoController.setPlaybackSpeed(newSpeed);
    setState(() {
      _playbackSpeed = newSpeed;
    });
  }

// --- SMART MONITOR LOGIC ---

// --- SMART MONITOR LOGIC ---

  List<int> _getRowStarts(List<Map<String, dynamic>> trackWords) {
    List<int> starts = [];
    int i = 0;
    while (i < trackWords.length) {
      starts.add(i);
      int size = (trackWords[i]['groupSize'] as num?)?.toInt() ?? 3;
      if (size < 1) size = 3; // Failsafe
      i += size;
    }
    return starts;
  }

  int _calculateFocusGroup(int currentMillis, List<Map<String, dynamic>> trackWords) {
    if (trackWords.isEmpty) return 0;
    List<int> starts = _getRowStarts(trackWords);
    int lastDroppedTotal = trackWords.lastIndexWhere((w) => w['startMs'] != null);
    if (lastDroppedTotal == -1) return 0;

    // 🎯 Bulletproof cast
    int maxDroppedTime = (trackWords[lastDroppedTotal]['startMs'] as num).toInt();

    if (currentMillis >= maxDroppedTime) {
      int nextTarget = lastDroppedTotal + 1;
      for (int r = 0; r < starts.length; r++) {
        int rowEnd = (r + 1 < starts.length) ? starts[r + 1] : trackWords.length;
        if (nextTarget >= starts[r] && nextTarget < rowEnd) return r;
      }
      return starts.length - 1;
    } else {
      // 🎯 Bulletproof cast
      int reviewIndex = trackWords.lastIndexWhere((w) => w['startMs'] != null && ((w['startMs'] as num).toInt()) <= currentMillis);
      if (reviewIndex == -1) return 0;
      for (int r = 0; r < starts.length; r++) {
        int rowEnd = (r + 1 < starts.length) ? starts[r + 1] : trackWords.length;
        if (reviewIndex >= starts[r] && reviewIndex < rowEnd) return r;
      }
      return 0;
    }
  }

// --- BOILERPLATE API ---

  Future<void> _autoTranscribeWithAI() async {
    setState(() => _isTranscribing = true);
    try {
      final response = await http.post(
        Uri.parse('https://zehut-server-production.up.railway.app/transcribe'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': widget.videoUrl, 'docId': widget.docId}),
      );
      final data = jsonDecode(response.body);

      if (data['success'] == true && data['data'] != null) {
        final he = data['data']['he'] ?? '';
        final en = data['data']['en'] ?? '';

        setState(() {
          _hebrewRawText = he;
          _englishRawText = en;
          _scriptController.text = _activeLanguage == 'hebrew' ? he : en;
        });

        await FirebaseFirestore.instance.collection('feeds').doc(widget.docId).set({
          'hebrewScript': he,
          'englishScript': en,
        }, SetOptions(merge: true));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${'sync_backend_err'.tr()}${data['error']}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${'sync_app_err'.tr()}$e')));
    } finally {
      setState(() => _isTranscribing = false);
    }
  }

  void _showEditScriptDialog() {
    if (_videoController.value.isPlaying) _videoController.pause();

    StringBuffer sb = StringBuffer();

    if (_activeWords.isNotEmpty) {
      List<int> starts = _getRowStarts(_activeWords);
      int currentGroupIndex = 0;

      for (int i = 0; i < _activeWords.length; i++) {
        final word = _activeWords[i]['word'] as String;
        if (word.isEmpty) continue;
        sb.write(word);

        int currentGroupStart = starts[currentGroupIndex];
        int currentSize = (_activeWords[currentGroupStart]['groupSize'] as num?)?.toInt() ?? 3;
        int groupEndIndex = currentGroupStart + currentSize - 1;

        if (i == groupEndIndex) {
          sb.write('\n');
          if (currentGroupIndex < starts.length - 1) currentGroupIndex++;
        } else {
          sb.write(' ');
        }
      }
    } else {
      final currentWords = _scriptController.text.trim().split(RegExp(r'\s+'));
      for (int i = 0; i < currentWords.length; i++) {
        if (currentWords[i].isEmpty) continue;
        sb.write(currentWords[i]);
        if ((i + 1) % 3 == 0) sb.write('\n');
        else sb.write(' ');
      }
    }

    TextEditingController dialogController = TextEditingController(text: sb.toString().trim());

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF103856),
            insetPadding: const EdgeInsets.all(10), // 🎯 Minimized outer margins
            contentPadding: const EdgeInsets.all(10), // 🎯 Minimized inner padding
            title: Text("${'sync_edit_script_title'.tr()} (${_activeLanguage == 'hebrew' ? 'sync_hebrew_btn'.tr() : 'sync_english_btn'.tr()})", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.7, // 🎯 Fills 70% of the screen height
              child: TextField(
                controller: dialogController,
                maxLines: null, // 🎯 Required for expands
                expands: true, // 🎯 Stretches text box to fill the entire available height
                textDirection: _activeLanguage == 'hebrew' ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                textAlign: _activeLanguage == 'hebrew' ? TextAlign.right : TextAlign.left,
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4), // 🎯 Smaller font
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: 'sync_edit_hint'.tr(),
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF0A192F),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ),
            actions: [

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('btn_cancel'.tr(), style: const TextStyle(color: Colors.redAccent)),
              ),
              TextButton(
                onPressed: () {
                  final newText = dialogController.text.trim();
                  if (newText.isNotEmpty) {
                    final splitWords = newText.split(RegExp(r'\s+'));

                    setState(() {
                      _scriptController.text = newText;

                      List<Map<String, dynamic>> newWordsList = [];
                      for (int i = 0; i < splitWords.length; i++) {
                        int? existingTime = (i < _activeWords.length) ? (_activeWords[i]['startMs'] as num?)?.toInt() : null;
                        int? existingSize = (i < _activeWords.length) ? (_activeWords[i]['groupSize'] as num?)?.toInt() : null;
                        double? existingY = (i < _activeWords.length) ? (_activeWords[i]['y'] as num?)?.toDouble() : null;

                        Map<String, dynamic> newWordData = {'word': splitWords[i], 'startMs': existingTime};
                        if (existingSize != null) newWordData['groupSize'] = existingSize;
                        if (existingY != null) newWordData['y'] = existingY;

                        newWordsList.add(newWordData);
                      }

                      if (_activeLanguage == 'hebrew') {
                        _hebrewWords = newWordsList;
                        _isHebrewLocked = true;
                      } else {
                        _englishWords = newWordsList;
                        _isEnglishLocked = true;
                      }
                    });

                    _silentAutoSave();
                  }
                  Navigator.pop(context);
                },
                child: Text('btn_save'.tr(), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
    );
  }

  Future<void> _generateMissingWaveform() async {
    setState(() => _isGeneratingWaveform = true);
    try {
      final response = await http.post(
        Uri.parse('https://zehut-server-production.up.railway.app/generateMissingWaveform'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': widget.videoUrl, 'docId': widget.docId}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final waveUrl = data['waveUrl'];
        setState(() => _waveformUrl = waveUrl);

        await FirebaseFirestore.instance.collection('feeds').doc(widget.docId).set({
          'waveformUrl': waveUrl,
        }, SetOptions(merge: true));
      }
    } catch (e) { debugPrint("Waveform error: $e"); }
    finally { setState(() => _isGeneratingWaveform = false); }
  }

  @override
  void dispose() {
    _videoController.dispose();
    _scriptController.dispose();
    super.dispose();
  }

  Widget _buildFlashcardRow(List<Map<String, dynamic>> trackWords, String lang) {
    return ValueListenableBuilder<double>(
        valueListenable: lang == 'hebrew' ? _hebrewBaseSize : _englishBaseSize,
        builder: (context, baseSize, child) {
          return AnimatedBuilder(
              animation: _videoController,
              builder: (context, child) {
                if (!_videoController.value.isInitialized) return const SizedBox.shrink();

                final currentMillis = _videoController.value.position.inMilliseconds;
                List<int> starts = _getRowStarts(trackWords);
                int activeGroup = _calculateFocusGroup(currentMillis, trackWords);

                if (activeGroup >= starts.length) return const SizedBox.shrink();

                int startIndex = starts[activeGroup];
                int currentSize = (trackWords[startIndex]['groupSize'] as num?)?.toInt() ?? 3;
                int endIndex = (startIndex + currentSize > trackWords.length) ? trackWords.length : startIndex + currentSize;

                List<Map<String, dynamic>> activeTriplets = trackWords.sublist(startIndex, endIndex);

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    textDirection: lang == 'hebrew' ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                    children: List.generate(activeTriplets.length, (index) {
                      final wordData = activeTriplets[index];
                      final word = wordData['word'] as String;
                      final markerTime = (wordData['startMs'] as num?)?.toInt();

                      bool isHighlighted = false;
                      if (markerTime != null && currentMillis >= markerTime) {
                        int globalIndex = startIndex + index;
                        int nextMarkerTime = (globalIndex < trackWords.length - 1 && trackWords[globalIndex + 1]['startMs'] != null)
                            ? (trackWords[globalIndex + 1]['startMs'] as num).toInt()
                            : _videoController.value.duration.inMilliseconds;

                        if (currentMillis < nextMarkerTime) isHighlighted = true;
                      }

                      double fontSize = isHighlighted ? baseSize + 8.0 : baseSize;

                      // 🎯 ADVANCED DYNAMIC COLOR THEMES
                      Color strokeColor;
                      Color fillColor;

                      if (lang == 'hebrew') {
                        // Hebrew: Lavender border -> Hot Pink border. Black text -> Lavender text.
                        strokeColor = isHighlighted ? Colors.pinkAccent : Colors.purpleAccent.shade100;
                        fillColor = isHighlighted ? Colors.purpleAccent.shade100 : Colors.black;
                      } else {
                        // English: Light Blue border always. Black text -> Yellow text.
                        strokeColor = Colors.lightBlueAccent;
                        fillColor = isHighlighted ? Colors.yellowAccent : Colors.black;
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                        child: Directionality(
                          textDirection: lang == 'hebrew' ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(word, textAlign: TextAlign.center, textDirection: lang == 'hebrew' ? ui.TextDirection.rtl : ui.TextDirection.ltr, style: TextStyle(
                                fontSize: fontSize, fontWeight: FontWeight.w900,
                                foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = 4.0..color = strokeColor, // 🎯 Dynamic Stroke
                                shadows: const [Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 2))],
                              )),
                              Text(word, textAlign: TextAlign.center, textDirection: lang == 'hebrew' ? ui.TextDirection.rtl : ui.TextDirection.ltr, style: TextStyle(
                                fontSize: fontSize, fontWeight: FontWeight.w900, color: fillColor, // 🎯 Dynamic Fill
                              )),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }
          );
        }
    );
  }
// 🎯 THE NEW SNAP-TO-DEFAULT LOGIC
  Future<void> _snapActiveRowToDefault() async {
    final double defaultY = 0.2577227722772277;
    final int currentMillis = _videoController.value.position.inMilliseconds;

    int activeGroup = _calculateFocusGroup(currentMillis, _activeWords);
    List<int> starts = _getRowStarts(_activeWords);

    if (activeGroup >= starts.length) return;

    int startIndex = starts[activeGroup];
    int currentSize = (_activeWords[startIndex]['groupSize'] as num?)?.toInt() ?? 3;
    int endIndex = startIndex + currentSize;

    bool needsUpdate = false;

    setState(() {
      for (int i = startIndex; i < endIndex && i < _hebrewWords.length; i++) {
        _hebrewWords[i]['y'] = defaultY;
        needsUpdate = true;
      }
      for (int i = startIndex; i < endIndex && i < _englishWords.length; i++) {
        _englishWords[i]['y'] = defaultY;
        needsUpdate = true;
      }
    });

    if (needsUpdate) {
      await _silentAutoSave();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Both languages aligned for this row.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF103856),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        leadingWidth: 170,
        leading: Row(
          children: [
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.lightBlueAccent.withOpacity(0.15),
                  border: Border.all(color: Colors.lightBlueAccent, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.arrow_back, color: Colors.lightBlueAccent, size: 16),
                    SizedBox(width: 6),
                    Text('VERTICAL', style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.w900, fontSize: 12)),
                  ],
                ),
              ),
            ),
            if (_isActiveScriptLocked)
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white70),
                onPressed: _showEditScriptDialog,
              ),
          ],
        ),
        title: Text('sync_appbar_title'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: _openSettingsPanel,
          ),
          InkWell(
            onTap: () {
              if (context.locale.languageCode == 'he') {
                context.setLocale(const Locale('en'));
              } else {
                context.setLocale(const Locale('he'));
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.language, color: Colors.lightBlue, size: 22),
                  const SizedBox(height: 2),
                  Text(
                      context.locale.languageCode == 'he' ? 'English' : 'עברית',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),

            // HEBREW SUBS (ABOVE VIDEO)
            if (_showHebrew && _isHebrewLocked)
              _buildFlashcardRow(_hebrewWords, 'hebrew'),

            // ZONE 0: VIDEO PLAYER (Feed-Matched Dimensions)
            if (_isVideoInitialized)
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.4,
                width: MediaQuery.of(context).size.width,
                child: ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController.value.size.width,
                      height: _videoController.value.size.height,
                      child: VideoPlayer(_videoController),
                    ),
                  ),
                ),
              )
            else
              const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.purpleAccent))),

            // ENGLISH SUBS (BELOW VIDEO)
            if (_showEnglish && _isEnglishLocked)
              _buildFlashcardRow(_englishWords, 'english'),

// STATE A: SETUP
            if (!_isActiveScriptLocked)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _scriptController,
                          maxLines: null,
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                          decoration: InputDecoration(
                            hintText: 'sync_script_hint'.tr(),
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orangeAccent.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: _isGeneratingWaveform ? null : _generateMissingWaveform,
                              child: _isGeneratingWaveform
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.waves, size: 24),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purpleAccent.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: _isTranscribing ? null : _autoTranscribeWithAI,
                              icon: _isTranscribing
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.auto_awesome, size: 18),
                              label: Text(_isTranscribing ? 'sync_btn_wait'.tr() : 'sync_btn_transcribe'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.lightBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: _lockScript,
                              child: Text('sync_btn_chop_lock'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // STATE B: SYNC ENGINE (Lollipops & Controls)
            if (_isActiveScriptLocked) ...[

              // ZONE 2: INFINITE DRAGGABLE LOLLIPOPS & WAVEFORM
              AnimatedBuilder(
                animation: _videoController,
                builder: (context, child) {
                  if (!_isVideoInitialized) return const SizedBox.shrink();

                  final double pixelsPerMs = 0.1 / _playbackSpeed;
                  final screenWidth = MediaQuery.of(context).size.width;
                  final centerPlayhead = screenWidth / 2;

                  final int currentMillis = _isScrubbing
                      ? _scrubPositionMs.round()
                      : _videoController.value.position.inMilliseconds;

                  final leftOffset = centerPlayhead - (currentMillis * pixelsPerMs);

                  return Container(
                    height: 125,
                    width: double.infinity,
                    color: Colors.transparent,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
// Scrubbing Background
                        Positioned(
                          top: 0, left: 0, right: 0, height: 65,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanStart: (details) {
                              _videoController.pause();
                              setState(() {
                                _isScrubbing = true;
                                _scrubPositionMs = _videoController.value.position.inMilliseconds.toDouble();
                              });
                            },
                            onPanUpdate: (details) {
                              final dragMillis = -(details.delta.dx / pixelsPerMs);
                              final isDraggingForward = dragMillis > 0;

                              setState(() {
                                _scrubPositionMs += dragMillis;
                                _scrubPositionMs = _scrubPositionMs.clamp(0.0, _videoController.value.duration.inMilliseconds.toDouble());
                              });

                              // Refreshes every 150ms to prevent audio stuttering while dragging
                              if (DateTime.now().difference(_lastScrubTime).inMilliseconds > 150) {
                                _lastScrubTime = DateTime.now();

                                _videoController.seekTo(Duration(milliseconds: _scrubPositionMs.round()));

                                // 🎯 Play audio if moving forward, pause if dragging backward
                                if (isDraggingForward) {
                                  _videoController.play();
                                } else {
                                  _videoController.pause();
                                }
                              }
                            },
                            onPanEnd: (details) {
                              // 🎯 KILL THE MOTOR the exact millisecond your finger leaves the glass
                              _videoController.pause();
                              setState(() => _isScrubbing = false);
                              _videoController.seekTo(Duration(milliseconds: _scrubPositionMs.round()));
                            },
                            onPanCancel: () {
                              _videoController.pause();
                              setState(() => _isScrubbing = false);
                            },
                            child: Container(
                              color: Colors.transparent,
                              alignment: Alignment.topCenter,
                              child: Container(
                                height: 45,
                                color: Colors.grey.shade900,
                              ),
                            ),
                          ),
                        ),

                        // Waveform Image
                        Positioned(
                          left: leftOffset,
                          top: 0,
                          height: 45,
                          width: (_videoController.value.duration.inMilliseconds * pixelsPerMs),
                          child: IgnorePointer(
                            child: Image.network(
                              _waveformUrl ?? '',
                              fit: BoxFit.fill,
                              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                            ),
                          ),
                        ),

                        // Fixed Playhead
                        Positioned(
                          left: centerPlayhead - 1,
                          top: 0,
                          height: 45,
                          child: Container(width: 2, color: Colors.redAccent),
                        ),

                        // Dynamic Lollipops for the Active Language Track
                        ...List.generate(_activeWords.length, (index) {
                          final markerTime = _activeWords[index]['startMs'] as int?;
                          if (markerTime == null) return const SizedBox.shrink();

                          final markerLeftOffset = centerPlayhead + ((markerTime - currentMillis) * pixelsPerMs);
                          if (markerLeftOffset < -50 || markerLeftOffset > screenWidth + 50) return const SizedBox.shrink();

                          // Dynamic group logic for coloring lollipops accurately
                          List<int> rowStarts = _getRowStarts(_activeWords);
                          int groupNumber = 0;
                          int numberInGroup = 1;
                          for (int r = 0; r < rowStarts.length; r++) {
                            int rowEnd = (r + 1 < rowStarts.length) ? rowStarts[r+1] : _activeWords.length;
                            if (index >= rowStarts[r] && index < rowEnd) {
                              groupNumber = r;
                              numberInGroup = index - rowStarts[r] + 1;
                              break;
                            }
                          }
                          bool isBlueGroup = (groupNumber % 2 == 0);
                          Color lollipopColor = isBlueGroup ? Colors.blue : Colors.deepOrange;

                          return Positioned(
                            left: markerLeftOffset - 30,
                            top: 0,
                            bottom: 0,
                            width: 60,
                            child: Column(
                              children: [
                                Container(width: 2, height: 60, color: Colors.white),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onPanUpdate: (details) {
                                    if (details.delta.dy > 5) {
                                      setState(() { _activeWords[index]['startMs'] = null; });
                                      _silentAutoSave();
                                      return;
                                    }
                                    final dragMillis = (details.delta.dx / pixelsPerMs).round();
                                    int newMillis = markerTime + dragMillis;
                                    int minBound = (index == 0) ? 0 : (_activeWords[index - 1]['startMs'] as int? ?? 0);
                                    int maxBound = (index == _activeWords.length - 1 || _activeWords[index + 1]['startMs'] == null)
                                        ? _videoController.value.duration.inMilliseconds
                                        : (_activeWords[index + 1]['startMs'] as int);

                                    setState(() => _activeWords[index]['startMs'] = newMillis.clamp(minBound, maxBound));
                                  },
                                  onPanEnd: (details) => _silentAutoSave(),
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.transparent,
                                    alignment: Alignment.topCenter, // 🎯 FIX: Lifts ball exactly 12px to touch the pole
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(color: lollipopColor, shape: BoxShape.circle),
                                      child: Center(
                                        child: Text('$numberInGroup', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),

              // Spacer to push the controls down, keeping everything tight
              const Spacer(),




// ZONE 3: CONTROLS (Slim Profile & Bottom Aligned)
              Container(
                color: Colors.black,
                padding: const EdgeInsets.only(top: 5, bottom: 10, left: 16, right: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 32,
                      color: _isMuted ? Colors.grey : Colors.orangeAccent,
                      icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
                      onPressed: _toggleMute,
                    ),

                    // 🎯 SMART Words Per Row Popup
                    PopupMenuButton<int>(
                      color: const Color(0xFF103856),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (int size) {
                        // 1. Find the exact index of the next marker you are about to drop
                        int targetIndex = _activeWords.indexWhere((w) => w['startMs'] == null);
                        if (targetIndex == -1) targetIndex = _activeWords.length - 1;

                        List<int> starts = _getRowStarts(_activeWords);
                        int groupToChange = 0;

                        for (int r = 0; r < starts.length; r++) {
                          int rowEnd = (r + 1 < starts.length) ? starts[r + 1] : _activeWords.length;
                          if (targetIndex >= starts[r] && targetIndex < rowEnd) {
                            groupToChange = r;
                            // 🎯 THE FIX: If you just completed a row and are about to start a new one,
                            // but you hit this button, we assume you want to expand the PREVIOUS row to absorb this new word!
                            if (targetIndex == starts[r] && r > 0) {
                              groupToChange = r - 1;
                            }
                            break;
                          }
                        }

                        int startIndex = starts[groupToChange];
                        setState(() {
                          _activeWords[startIndex]['groupSize'] = size;
                        });
                        _silentAutoSave();
                      },
                      itemBuilder: (BuildContext context) {
                        return [3, 4, 5, 6].map((int size) {
                          return PopupMenuItem<int>(
                            value: size,
                            child: Text("$size Words", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          );
                        }).toList();
                      },
                      child: const Icon(Icons.view_week_rounded, color: Colors.blueAccent, size: 28),
                    ),

                    IconButton(
                      iconSize: 42,
                      color: Colors.lightBlue,
                      icon: Icon(_videoController.value.isPlaying ? Icons.pause : Icons.play_arrow),
                      onPressed: _togglePlayStop,
                    ),
                    IconButton(
                      iconSize: 34,
                      color: Colors.greenAccent,
                      icon: const Icon(Icons.add),
                      onPressed: _addNextMarker,
                    ),

                    IconButton(
                      iconSize: 28,
                      color: Colors.redAccent,
                      icon: const Icon(Icons.redo),
                      onPressed: _snapActiveRowToDefault, // 🎯 Hijacked to snap the row to default
                    ),

                    // ⏩ SPEED POPUP MENU
                    PopupMenuButton<double>(
                      initialValue: _playbackSpeed,
                      color: const Color(0xFF103856),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (double speed) {
                        _videoController.setPlaybackSpeed(speed);
                        setState(() => _playbackSpeed = speed);
                      },
                      itemBuilder: (BuildContext context) {
                        return _speeds.map((double speed) {
                          return PopupMenuItem<double>(
                            value: speed,
                            child: Text("${speed}x", style: TextStyle(
                              color: _playbackSpeed == speed ? Colors.orangeAccent : Colors.white,
                              fontWeight: FontWeight.bold,
                            )),
                          );
                        }).toList();
                      },
                      child: Text(
                        "${_playbackSpeed}x",
                        style: const TextStyle(color: Colors.orangeAccent, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              // THE FIX: 5px address bar clearance (lowered row by 25px)
              const SizedBox(height: 5),
            ]
          ],
        ),
      ),
    );
  }
}