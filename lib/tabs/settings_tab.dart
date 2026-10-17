import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import '../app_state.dart';


Future<void> _resetSubtitleHeight(BuildContext context, bool isEnglish) async {
  final String langName = isEnglish ? 'English' : 'עברית';

  double defaultHebrewY = 0.15;
  double defaultEnglishY = 0;

  final double targetY = isEnglish ? defaultEnglishY : defaultHebrewY;

  bool? confirm = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: const Color(0xFF010126),
        title: Text('settings_reset_dialog_title'.tr(args: [langName]), style: const TextStyle(color: Colors.white)),
        content: Text(
          'settings_reset_dialog_desc'.tr(args: [langName]),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('settings_btn_cancel'.tr(), style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('settings_btn_reset'.tr(), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
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
          content: Text('settings_msg_success'.tr(args: [langName])),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings_msg_error'.tr(args: [e.toString()])), backgroundColor: Colors.red),
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
        title: Text('settings_title'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.grey.shade900,
        iconTheme: const IconThemeData(color: Colors.white),
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
                    title: Text('settings_force_subs'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text('settings_force_subs_desc'.tr(), style: const TextStyle(color: Colors.grey)),
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
                  return Column(
                    children: [
                      SwitchListTile(
                        title: Text('settings_enable_edit'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text('settings_enable_edit_desc'.tr(), style: const TextStyle(color: Colors.grey)),
                        value: showEditBtn,
                        activeColor: Colors.lightBlue,
                        onChanged: (bool value) {
                          di<AppState>().adminShowEditButton.value = value;
                        },
                      ),

                      // 3. Subtitle Maintenance (Only visible when Edit UI is ON)
                      if (showEditBtn) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Divider(color: Colors.white24, thickness: 1),
                        ),
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
                                  Text(
                                    'settings_maint_title'.tr(),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.restore, color: Colors.white),
                                    label: Text('settings_reset_eng'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1E293B),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => _resetSubtitleHeight(context, true),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.restore, color: Colors.white),
                                    label: Text('settings_reset_heb'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1E293B),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => _resetSubtitleHeight(context, false),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ]
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