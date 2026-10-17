import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import '../app_state.dart';

Future<void> _resetSubtitleHeight(BuildContext context, bool isEnglish) async {
  final bool isHe = context.locale.languageCode == 'he';
  final String langName = isEnglish
      ? (isHe ? 'אנגלית' : 'English')
      : (isHe ? 'עברית' : 'Hebrew');

  const double defaultHebrewY = 0.15;
  const double defaultEnglishY = 0.65;

  final double targetY = isEnglish ? defaultEnglishY : defaultHebrewY;

  bool? confirm = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        backgroundColor: const Color(0xFF103856),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isHe ? 'לאפס גובה כתוביות ($langName)?' : 'Reset $langName Subtitles?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isHe
              ? 'פעולה זו תנעל את כל המילים ב$langName בכל הסרטונים לגובה ברירת המחדל ($targetY). לא ניתן לבטל פעולה זו.'
              : 'This will lock every $langName word across all videos to default height ($targetY). This cannot be undone.',
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              isHe ? 'ביטול' : 'CANCEL',
              style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              isHe ? 'אפס הכל' : 'RESET ALL',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    },
  );

  if (confirm != true) return;

  try {
    final db = FirebaseFirestore.instance;
    // 🎯 FIXED: Points to 'feeds' instead of 'video_feeds'
    const collectionName = 'feeds';

    final snapshot = await db.collection(collectionName).get();
    if (snapshot.docs.isEmpty) return;

    final batch = db.batch();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      Map<String, dynamic> updates = {};

      if (isEnglish) {
        updates['englishYPos'] = targetY;

        if (data['syncedWordsEN'] != null) {
          List<dynamic> updatedWordsEN = (data['syncedWordsEN'] as List).map((wordObj) {
            if (wordObj is Map) {
              var newObj = Map<String, dynamic>.from(wordObj);
              newObj['y'] = targetY;
              return newObj;
            }
            return wordObj;
          }).toList();
          updates['syncedWordsEN'] = updatedWordsEN;
        }
      } else {
        updates['hebrewYPos'] = targetY;

        if (data['syncedWords'] != null) {
          List<dynamic> updatedWordsHEB = (data['syncedWords'] as List).map((wordObj) {
            if (wordObj is Map) {
              var newObj = Map<String, dynamic>.from(wordObj);
              newObj['y'] = targetY;
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
          content: Text(
            isHe
                ? '✅ כל הכתוביות ($langName) אופסו לגובה ברירת המחדל'
                : '✅ All $langName subtitles reset to default height',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isHe ? 'שגיאה באיפוס: $e' : 'Error resetting: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isHe = context.locale.languageCode == 'he';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          isHe ? 'הגדרות מנהל' : 'Admin Settings',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF103856),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Force Show Hidden Subs
              ValueListenableBuilder<bool>(
                valueListenable: di<AppState>().adminForceShowSubs,
                builder: (context, forceSubs, _) {
                  return SwitchListTile(
                    title: Text(
                      isHe ? 'הצג כתוביות מוסתרות' : 'Force Show Hidden Subs',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      isHe
                          ? 'עקיפת מנהל לצפייה בכתוביות כבויות בפיד'
                          : 'Admin override to see disabled subtitles in the feed',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    value: forceSubs,
                    activeColor: Colors.orangeAccent,
                    onChanged: (bool value) {
                      di<AppState>().adminForceShowSubs.value = value;
                    },
                  );
                },
              ),

              // 2. Enable Edit UI Button + Conditional Maintenance Card
              ValueListenableBuilder<bool>(
                valueListenable: di<AppState>().adminShowEditButton,
                builder: (context, showEditBtn, _) {
                  return Column(
                    children: [
                      SwitchListTile(
                        title: Text(
                          isHe ? 'הפעל ממשק עריכה בפיד' : 'Enable Live Feed Editor',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          isHe
                              ? 'הצג את כפתור עריכת הכתוביות על גבי הסרטונים בפיד'
                              : 'Show the "EDIT SUBS" button directly on the video feed',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        value: showEditBtn,
                        activeColor: Colors.lightBlue,
                        onChanged: (bool value) {
                          di<AppState>().adminShowEditButton.value = value;
                        },
                      ),

                      if (showEditBtn) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Divider(color: Colors.white24, thickness: 1),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Card(
                            color: const Color(0xFF1E293B),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              side: BorderSide(color: Colors.lightBlue.withOpacity(0.3), width: 1.5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.align_vertical_center, color: Colors.lightBlue, size: 22),
                                      const SizedBox(width: 10),
                                      Text(
                                        isHe ? 'תחזוקת גובה כתוביות (גלובלי)' : 'Global Subtitle Alignment',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.restore, color: Colors.white),
                                    label: Text(
                                      isHe ? 'אפס גובה כתוביות – עברית (למעלה)' : 'Reset Hebrew Heights (Top 15%)',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF103856),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        side: const BorderSide(color: Colors.lightBlueAccent, width: 1),
                                      ),
                                    ),
                                    onPressed: () => _resetSubtitleHeight(context, false),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.restore, color: Colors.white),
                                    label: Text(
                                      isHe ? 'אפס גובה כתוביות – אנגלית (למטה)' : 'Reset English Heights (Bottom 65%)',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF103856),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        side: const BorderSide(color: Colors.orangeAccent, width: 1),
                                      ),
                                    ),
                                    onPressed: () => _resetSubtitleHeight(context, true),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}