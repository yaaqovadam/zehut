import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_state.dart'; // Adjust this path if your file structure is different

// 🔪 THE BATCH UPDATE LOGIC
Future<void> _resetSubtitleHeight(BuildContext context, bool isEnglish) async {
  final langName = isEnglish ? 'English' : 'Hebrew';

  // The exact default Y position for Segment 1 from your database
  final double defaultY = 0.2577227722772277;

  bool? confirm = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: const Color(0xFF010126),
        title: Text('Reset $langName Subtitles?', style: const TextStyle(color: Colors.white)),
        content: Text(
          'This will lock every individual $langName word and the global marker to Y: $defaultY. This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('RESET ALL', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      );
    },
  );

  if (confirm != true) return;

  try {
    final db = FirebaseFirestore.instance;
    const collectionName = 'video_feeds';

    final snapshot = await db.collection(collectionName).get();
    if (snapshot.docs.isEmpty) return;

    final batch = db.batch();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      Map<String, dynamic> updates = {};

      if (isEnglish) {
        updates['englishYPos'] = defaultY;

        if (data['syncedWordsEN'] != null) {
          List<dynamic> updatedWordsEN = (data['syncedWordsEN'] as List).map((wordObj) {
            if (wordObj is Map) {
              var newObj = Map<String, dynamic>.from(wordObj);
              newObj['y'] = defaultY;
              return newObj;
            }
            return wordObj;
          }).toList();
          updates['syncedWordsEN'] = updatedWordsEN;
        }
      } else {
        updates['hebrewYPos'] = defaultY; // Assuming you have a global hebrew marker too

        if (data['syncedWords'] != null) {
          List<dynamic> updatedWordsHEB = (data['syncedWords'] as List).map((wordObj) {
            if (wordObj is Map) {
              var newObj = Map<String, dynamic>.from(wordObj);
              newObj['y'] = defaultY;
              return newObj;
            }
            return wordObj;
          }).toList();
          updates['syncedWords'] = updatedWordsHEB;
        }
      }

      if (updates.isNotEmpty) {
        batch.update(doc.reference, updates);
      }
    }

    await batch.commit();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ All $langName words locked to Y: $defaultY'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error resetting: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.grey.shade900,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          // Admin Toggles
          ValueListenableBuilder<bool>(
            valueListenable: di<AppState>().isAdmin,
            builder: (context, isAdmin, _) {
              if (!isAdmin) return const SizedBox.shrink(); // Hides from public users

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Force Show Hidden Subs
                  ValueListenableBuilder<bool>(
                    valueListenable: di<AppState>().adminForceShowSubs,
                    builder: (context, forceSubs, _) {
                      return SwitchListTile(
                        title: const Text('Force Show Hidden Subs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Admin override to see disabled subtitles in the feed', style: TextStyle(color: Colors.grey)),
                        value: forceSubs,
                        activeColor: Colors.orangeAccent,
                        onChanged: (bool value) {
                          di<AppState>().adminForceShowSubs.value = value;
                        },
                      );
                    },
                  ),

                  // 2. Enable Edit UI Button
                  ValueListenableBuilder<bool>(
                    valueListenable: di<AppState>().adminShowEditButton,
                    builder: (context, showEditBtn, _) {
                      return SwitchListTile(
                        title: const Text('Enable Edit UI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Show the "EDIT SUBS" button on the video feed', style: TextStyle(color: Colors.grey)),
                        value: showEditBtn,
                        activeColor: Colors.lightBlue,
                        onChanged: (bool value) {
                          di<AppState>().adminShowEditButton.value = value;
                        },
                      );
                    },
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Divider(color: Colors.white24, thickness: 1),
                  ),

                  // 3. Subtitle Maintenance (Admin Only)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      color: Colors.white.withOpacity(0.05),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Subtitle Maintenance',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.restore, color: Colors.blueAccent),
                              label: const Text('Reset vertical marker height to default - ENG'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.blueAccent),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: () => _resetSubtitleHeight(context, true),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.restore, color: Colors.blueAccent),
                              label: const Text('Reset vertical marker height to default - HEB'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.blueAccent),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: () => _resetSubtitleHeight(context, false),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}