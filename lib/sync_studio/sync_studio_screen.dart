import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Setup State
  bool _isTranscribing = false;
  bool _isGeneratingWaveform = false;
  String? _waveformUrl;
  final TextEditingController _scriptController = TextEditingController();

  // Engine State
  bool _isScriptLocked = false;
  List<Map<String, dynamic>> _words = [];

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

  Future<void> _loadFirestoreData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('feeds').doc(widget.docId).get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          if (data['hebrewScript'] != null) _scriptController.text = data['hebrewScript'];
          if (data['englishScript'] != null) _englishTranslation = data['englishScript'];
          if (data['waveformUrl'] != null) _waveformUrl = data['waveformUrl'];

          // Auto-restore timeline progress
          if (data['syncedWords'] != null) {
            List<dynamic> savedWords = data['syncedWords'];
            _words = savedWords.map((w) => Map<String, dynamic>.from(w)).toList();
            _isScriptLocked = true;
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading from DB: $e");
    }

    // Fallback: Check Cloudflare directly if no URL was saved
    if (_waveformUrl == null) {
      final targetUrl = 'https://pub-142306085f2b48bda4045cd9efdd0d28.r2.dev/${widget.docId}_wave.png?v=3';
      final response = await http.head(Uri.parse(targetUrl));
      if (response.statusCode == 200) {
        setState(() => _waveformUrl = targetUrl);
        FirebaseFirestore.instance.collection('feeds').doc(widget.docId)
            .set({'waveformUrl': targetUrl}, SetOptions(merge: true));
      }
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
    final text = _scriptController.text.trim();
    if (text.isEmpty) return;

    final splitWords = text.split(RegExp(r'\s+'));
    setState(() {
      // null startMs means it hasn't been dropped on the timeline yet
      _words = splitWords.map((w) => {'word': w, 'startMs': null}).toList();
      _isScriptLocked = true;
    });
  }

  Future<void> _silentAutoSave() async {
    try {
      await FirebaseFirestore.instance.collection('feeds').doc(widget.docId).set({
        'syncedWords': _words,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Auto-save failed: $e");
    }
  }

  void _addNextMarker() {
    final currentMillis = _videoController.value.position.inMilliseconds;
    int targetIndex = _words.indexWhere((w) => w['startMs'] == null);

    if (targetIndex != -1) {
      int minBound = (targetIndex == 0) ? 0 : (_words[targetIndex - 1]['startMs'] ?? 0);
      setState(() {
        _words[targetIndex]['startMs'] = currentMillis < minBound ? minBound : currentMillis;
      });
      _silentAutoSave(); // <-- INSTANT SAVE
    }
  }

  void _removeLastMarker() {
    int lastIndex = _words.lastIndexWhere((w) => w['startMs'] != null);
    if (lastIndex != -1) {
      setState(() {
        _words[lastIndex]['startMs'] = null;
      });
      _silentAutoSave(); // <-- INSTANT SAVE
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

  int _calculateFocusGroup(int currentMillis) {
    int lastDroppedTotal = _words.lastIndexWhere((w) => w['startMs'] != null);

    if (lastDroppedTotal == -1) return 0; // Fresh slate, start at group 0

    int maxDroppedTime = _words[lastDroppedTotal]['startMs'] as int;

    if (currentMillis >= maxDroppedTime) {
      // Sync Mode: Playhead is at the frontier. Show the group for the NEXT word to drop.
      int nextTarget = lastDroppedTotal + 1;
      if (nextTarget >= _words.length) return lastDroppedTotal ~/ 3; // Reached the end
      return nextTarget ~/ 3;
    } else {
      // Review Mode: Scrubbed backwards. Show the group associated with the playhead.
      int reviewIndex = _words.lastIndexWhere((w) => w['startMs'] != null && (w['startMs'] as int) <= currentMillis);
      if (reviewIndex == -1) return 0;
      return reviewIndex ~/ 3;
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
            _scriptController.text = he;
            _englishTranslation = en;
          });

          // Auto-save to feeds immediately
          await FirebaseFirestore.instance.collection('feeds').doc(widget.docId).set({
            'hebrewScript': he,
            'englishScript': en,
          }, SetOptions(merge: true));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backend error: ${data['error']}')));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('App error: $e')));
      } finally {
        setState(() => _isTranscribing = false);
      }
    }


  void _showEditScriptDialog() {
    if (_videoController.value.isPlaying) _videoController.pause();

    final currentWords = _words.isNotEmpty
        ? _words.map((w) => w['word'] as String).toList()
        : _scriptController.text.trim().split(RegExp(r'\s+'));

    StringBuffer sb = StringBuffer();
    for (int i = 0; i < currentWords.length; i++) {
      if (currentWords[i].isEmpty) continue;
      sb.write(currentWords[i]);
      if ((i + 1) % 3 == 0) sb.write('\n');
      else sb.write(' ');
    }

    TextEditingController dialogController = TextEditingController(text: sb.toString().trim());

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF103856),
            insetPadding: const EdgeInsets.all(16), // Gives it breathing room from screen edges
            title: const Text("Edit Script", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: TextField(
                  controller: dialogController,
                  maxLines: 15, // Let it expand naturally up to 15 lines
                  minLines: 5,  // Starts with plenty of space
                  textDirection: TextDirection.rtl, // <--- CRITICAL: Forces Hebrew text direction
                  textAlign: TextAlign.right,       // <--- CRITICAL: Aligns cursor correctly
                  style: const TextStyle(color: Colors.white, fontSize: 22, height: 1.5),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: "Script goes here...",
                    hintStyle: TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Color(0xFF0A192F),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("CANCEL", style: TextStyle(color: Colors.redAccent)),
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
                        int? existingTime = (i < _words.length) ? _words[i]['startMs'] as int? : null;
                        newWordsList.add({'word': splitWords[i], 'startMs': existingTime});
                      }
                      _words = newWordsList;
                      _isScriptLocked = true;
                    });
                  }
                  Navigator.pop(context);
                },
                child: const Text("SAVE", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A192F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF103856),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Sync Studio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (_isScriptLocked)
            TextButton.icon(
              icon: const Icon(Icons.edit, color: Colors.white70, size: 18),
              label: const Text("EDIT", style: TextStyle(color: Colors.white70)),
              onPressed: _showEditScriptDialog, // Launches the new Pop-Up Editor
            ),
          TextButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance.collection('feeds').doc(widget.docId).set({
                  'hebrewScript': _scriptController.text.trim(),
                  'englishScript': _englishTranslation,
                  'syncedWords': _words,
                }, SetOptions(merge: true));

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Saved to DB!'), backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text("SAVE", style: TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: Column(
        children: [
          // ZONE 0: VIDEO PLAYER
          if (_isVideoInitialized)
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: _videoController.value.aspectRatio,
                  child: VideoPlayer(_videoController),
                ),
              ),
            )
          else
            const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.purpleAccent))),

          // STATE A: SETUP
          if (!_isScriptLocked)
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
                          hintText: "Paste script or hit Auto-Transcribe...",
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
                            label: Text(_isTranscribing ? "WAIT..." : "TRANSCRIBE", style: const TextStyle(fontWeight: FontWeight.bold)),
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
                            child: const Text("CHOP & LOCK", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // STATE B: SYNC ENGINE
          if (_isScriptLocked) ...[

            // ZONE 1: DYNAMIC FLASHCARDS (Smart Monitor)
            AnimatedBuilder(
                animation: _videoController,
                builder: (context, child) {
                  final currentMillis = _videoController.value.position.inMilliseconds;

                  int activeGroup = _calculateFocusGroup(currentMillis);
                  int startIndex = activeGroup * 3;
                  int endIndex = (startIndex + 3 > _words.length) ? _words.length : startIndex + 3;

                  List<Map<String, dynamic>> activeTriplets = _words.sublist(startIndex, endIndex);

                  // Group 0 (Words 1-3) = Blue. Group 1 (Words 4-6) = Orange. Group 2 (Words 7-9) = Blue.
                  bool isBlueGroup = (activeGroup % 2 == 0);
                  Color groupColor = isBlueGroup ? Colors.blue : Colors.deepOrange;
                  Color groupShadowColor = isBlueGroup ? Colors.blue.shade900 : Colors.deepOrange.shade900;

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(activeTriplets.length, (index) {
                        final wordData = activeTriplets[index];
                        final word = wordData['word'] as String;
                        final markerTime = wordData['startMs'] as int?;

                        // Highlight Logic
                        bool isHighlighted = false;
                        if (markerTime != null && currentMillis >= markerTime) {
                          int globalIndex = startIndex + index;
                          int nextMarkerTime = (globalIndex < _words.length - 1 && _words[globalIndex + 1]['startMs'] != null)
                              ? _words[globalIndex + 1]['startMs'] as int
                              : _videoController.value.duration.inMilliseconds;

                          if (currentMillis < nextMarkerTime) {
                            isHighlighted = true;
                          }
                        }

                        return Expanded(
                          child: Center(
                            child: Text(
                              word,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: isHighlighted ? Colors.greenAccent : groupColor.withOpacity(0.5),
                                shadows: [
                                  Shadow(color: groupShadowColor, blurRadius: 8, offset: const Offset(2, 2)),
                                  const Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                }
            ),

            // ZONE 2: INFINITE DRAGGABLE LOLLIPOPS & WAVEFORM
            // ZONE 2: INFINITE DRAGGABLE LOLLIPOPS & WAVEFORM
            // ZONE 2: INFINITE DRAGGABLE LOLLIPOPS & WAVEFORM
            AnimatedBuilder(
              animation: _videoController,
              builder: (context, child) {
                if (!_isVideoInitialized) return const SizedBox.shrink();

                final double pixelsPerMs = 0.1 / _playbackSpeed;
                final screenWidth = MediaQuery.of(context).size.width;
                final centerPlayhead = screenWidth / 2;
                final currentMillis = _videoController.value.position.inMilliseconds;
                final leftOffset = centerPlayhead - (currentMillis * pixelsPerMs);

                return Container(
                  height: 140, // <--- Height increased to push controls further down
                  width: double.infinity,
                  color: Colors.transparent,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 1. Scrubbing Background
                      Positioned(
                        top: 0, left: 0, right: 0, height: 45,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanUpdate: (details) {
                            final dragMillis = -(details.delta.dx / pixelsPerMs);
                            final newTarget = currentMillis + dragMillis.round();
                            _videoController.seekTo(Duration(
                                milliseconds: newTarget.clamp(0, _videoController.value.duration.inMilliseconds)
                            ));
                          },
                          child: Container(color: Colors.grey.shade900),
                        ),
                      ),

                      // 2. Waveform Image
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

                      // 3. Fixed Playhead
                      Positioned(
                        left: centerPlayhead - 1,
                        top: 0,
                        height: 45,
                        child: Container(width: 2, color: Colors.redAccent),
                      ),

                      // 4. Dynamic Lollipops
                      ...List.generate(_words.length, (index) {
                        final markerTime = _words[index]['startMs'] as int?;
                        if (markerTime == null) return const SizedBox.shrink();

                        final markerLeftOffset = centerPlayhead + ((markerTime - currentMillis) * pixelsPerMs);

                        if (markerLeftOffset < -50 || markerLeftOffset > screenWidth + 50) {
                          return const SizedBox.shrink();
                        }

                        int groupNumber = (index ~/ 3);
                        bool isBlueGroup = (groupNumber % 2 == 0);
                        Color lollipopColor = isBlueGroup ? Colors.blue : Colors.deepOrange;
                        int numberInGroup = (index % 3) + 1;

                        return Positioned(
                          left: markerLeftOffset - 18, // Adjusted for new 36px ball
                          top: 0,
                          bottom: 0,
                          width: 36,
                          child: Column(
                            children: [
                              // The line is now purely visual, no touches registered here
                              Container(width: 2, height: 85, color: Colors.white),

                              // The touch target is restricted entirely to this ball
                              // The touch target is restricted entirely to this ball
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onPanUpdate: (details) {
                                  if (details.delta.dy > 5) { // Swipe down to delete
                                    setState(() { _words[index]['startMs'] = null; });
                                    _silentAutoSave(); // <-- INSTANT SAVE ON DELETE
                                    return;
                                  }

                                  // Visual drag happens here locally
                                  final dragMillis = (details.delta.dx / pixelsPerMs).round();
                                  int newMillis = markerTime + dragMillis;

                                  int minBound = (index == 0) ? 0 : (_words[index - 1]['startMs'] as int? ?? 0);
                                  int maxBound = (index == _words.length - 1 || _words[index + 1]['startMs'] == null)
                                      ? _videoController.value.duration.inMilliseconds
                                      : (_words[index + 1]['startMs'] as int);

                                  setState(() {
                                    _words[index]['startMs'] = newMillis.clamp(minBound, maxBound);
                                  });
                                },
                                onPanEnd: (details) {
                                  // Saves to DB the moment you let go of the ball
                                  _silentAutoSave();
                                },
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(color: lollipopColor, shape: BoxShape.circle),
                                  child: Center(
                                    child: Text(
                                        '$numberInGroup',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
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

            // ZONE 3: CONTROLS (Add / Remove / Play / Mute)
            // ZONE 3: CONTROLS (Add / Play / Mute)
            // ZONE 3: CONTROLS (Mute / Speed / Undo / Play / Add)
            Container(
              color: const Color(0xFF103856),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute Toggle
                  IconButton(
                    iconSize: 28,
                    icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
                    color: Colors.white70,
                    onPressed: _toggleMute,
                  ),

                  // Speed Badge
                  InkWell(
                    onTap: _cycleSpeed,
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white54)
                      ),
                      child: Text("${_playbackSpeed}x", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  // Remove Last Marker (UNDO)
                  IconButton(
                    iconSize: 36,
                    color: Colors.redAccent,
                    icon: const Icon(Icons.undo),
                    onPressed: _removeLastMarker,
                  ),

                  // Play/Pause
                  IconButton(
                    iconSize: 55,
                    color: Colors.lightBlue,
                    icon: Icon(_videoController.value.isPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: _togglePlayStop,
                  ),

                  // Add Next Marker (DROP)
                  IconButton(
                    iconSize: 42,
                    color: Colors.greenAccent,
                    icon: const Icon(Icons.add),
                    onPressed: _addNextMarker,
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }
}