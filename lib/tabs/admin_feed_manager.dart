import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;

class AdminFeedManager extends StatefulWidget {
  const AdminFeedManager({super.key});

  @override
  State<AdminFeedManager> createState() => _AdminFeedManagerState();
}

class _AdminFeedManagerState extends State<AdminFeedManager> {
  final String _baseUrl = "https://pub-142306085f2b48bda4045cd9efdd0d28.r2.dev/";

  // 📝 GENERATE CLEAN DOCUMENT ID FROM TITLE (Protects DB from bad characters)
  String generateDocId(String title) {
    return title
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\u0590-\u05FF]+'), '-') // Keeps English, Hebrew, and numbers
        .replaceAll(RegExp(r'-+'), '-'); // Removes double hyphens
  }

  // 🚀 AUTOMATED YOUTUBE TITLE FETCHER & DATABASE MIGRATOR
  Future<void> _migrateDatabaseOnce() async {
    final collection = FirebaseFirestore.instance.collection('feeds');
    final fixList = FirebaseFirestore.instance.collection('filenames-to-fix');
    final snapshot = await collection.get();

    final Map<String, String> fetchedTitles = {
      'wltfbb-j50': 'נפגש ביום ראשון באקספו תל אביב',
      '-wltfbb-j50': 'נפגש ביום ראשון באקספו תל אביב',
      '5kmtbow3m6u': 'במדינה מתוקנת יש דין יש סדר ויש כללים ברורים',
      '9x2pi7j4vso': 'מי מפחד מבית המקדש',
      'q4l5q5ulqzu': 'אל תצביעו שוב לאותו דבר כדי לקבל את אותה התוצאה',
      'sjhyrpfsney': 'זהבה אם לומר שהדרך היחידה לשים סוף למלחמות היא כיבוש גירוש והתיישבות בעזה זה קיצוני אז אני קיצוני',
      'anpewkvfrm4': 'המחנה הלאומי צריך להתאחד סביב דרך',
      'fdhl0qj3nwk': 'למה דווקא במלחמה הצודקת ביותר שלנו כל כך הרבה לוחמים חוזרים עם פוסט טראומה',
      'n8d7xteeqie': 'הצמא לאמת רק הולך וגובר',
      'pzd38dk69is': 'משיחי זו לא מילה גסה',
      'qs37ux1m5ny': 'האויב שורף ואנחנו בונים',
      'fwpwyqj6cag': 'צפו שתפו והרשמו',
      'dkz-dwkv1mw': 'כל עוד תודעת האורחים הלא רצויים בארצם תמשיך לנהל את הפיקוד הצהלי',
      'dkz_dwkv1mw': 'כל עוד תודעת האורחים הלא רצויים בארצם תמשיך לנהל את הפיקוד הצהלי',
      'fonluvkij8': 'מי שרוצה עתיד אחר למדינת ישראל מצביע זהות',
      '-fonluvkij8': 'מי שרוצה עתיד אחר למדינת ישראל מצביע זהות',
      '1axlcqx6mr0': 'אני מאמין לאויבים שלנו',
      'dqoncl23fmy': 'המצביעים שלי לא שייכים לכם ולא נמצאים אצלכם בכיס בואו לאיחוד',
      'o4iiilhjd88': '25 באוגוסט 2026',
    };

    int successCount = 0;

    for (var doc in snapshot.docs) {
      final oldDocId = doc.id;
      final data = doc.data() as Map<String, dynamic>;

      if (fetchedTitles.containsKey(oldDocId.toLowerCase())) {
        final realTitle = fetchedTitles[oldDocId.toLowerCase()]!;
        final newDocId = generateDocId(realTitle);

        if (newDocId.isNotEmpty && newDocId != oldDocId) {
          final newDocRef = collection.doc(newDocId);
          final newDocSnap = await newDocRef.get();

          if (!newDocSnap.exists) {
            String actualOldMp4 = data['url'] != null ? data['url'].toString().split('/').last : 'UNKNOWN_MP4';
            String actualOldJpg = data['thumb'] != null ? data['thumb'].toString().split('/').last : 'UNKNOWN_JPG';

            await fixList.add({
              'old_doc_id': oldDocId,
              'old_mp4_name': actualOldMp4,
              'old_jpg_name': actualOldJpg,
              'new_doc_id': newDocId,
              'new_mp4_name': '$newDocId.mp4',
              'new_jpg_name': '$newDocId.jpg',
              'timestamp': FieldValue.serverTimestamp(),
            });

            final newData = Map<String, dynamic>.from(data);
            newData['title'] = realTitle;
            newData['url'] = '$_baseUrl$newDocId.mp4';
            newData['thumb'] = '$_baseUrl$newDocId.jpg';

            await newDocRef.set(newData);
            await doc.reference.delete();
            successCount++;
          }
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Success: Renamed all $successCount videos perfectly!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // 🔄 DRAG & DROP RE-INDEXER
  Future<void> _onReorder(int oldIndex, int newIndex, List<DocumentSnapshot> currentDocs) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final mutableDocs = List<DocumentSnapshot>.from(currentDocs);
    final item = mutableDocs.removeAt(oldIndex);
    mutableDocs.insert(newIndex, item);

    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < mutableDocs.length; i++) {
      batch.update(mutableDocs[i].reference, {'index': i});
    }

    await batch.commit();
  }

  // ➕ ADD NEW VIDEO DIALOG
  void _showAddDialog(int nextIndex) {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'dialog_add_title'.tr(),
          style: const TextStyle(color: Color(0xFF103856), fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.black87),
          decoration: InputDecoration(
            hintText: 'dialog_filename_hint'.tr(),
            hintStyle: const TextStyle(color: Colors.black38),
            helperText: 'dialog_filename_helper'.tr(),
            helperStyle: const TextStyle(color: Colors.black54),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.lightBlue)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF103856), width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('btn_cancel'.tr(), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final fileName = nameController.text.trim();
              if (fileName.isNotEmpty) {
                final docId = generateDocId(fileName);
                final docRef = FirebaseFirestore.instance.collection('feeds').doc(docId);

                // 🛡️ DATABASE SHIELD
                final docSnap = await docRef.get();
                if (docSnap.exists) {
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Warning: A video with this name already exists in the database!'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                  return;
                }

                final displayTitle = fileName.replaceAll('-', ' ').toUpperCase();

                await docRef.set({
                  'index': nextIndex,
                  'title': displayTitle,
                  'subtitle': 'צפו עד הסוף',
                  'url': '$_baseUrl$fileName.mp4',
                  'thumb': '$_baseUrl$fileName.jpg',
                  'isLocked': false,
                  'online': true, // Added default true for new videos
                  'like_count': 0,
                });

                if (mounted) Navigator.pop(context);
              }
            },
            child: Text('btn_add_to_feed'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ✏️ EDIT EXISTING VIDEO DIALOG
// ✏️ EDIT EXISTING VIDEO DIALOG
  // ✏️ EDIT EXISTING VIDEO DIALOG
  // ✏️ EDIT EXISTING VIDEO DIALOG
  void _showEditDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String oldDocId = doc.id;

    String currentFileName = data['url'] != null ? data['url'].toString().split('/').last.replaceAll('.mp4', '') : oldDocId;

    final TextEditingController fileNameController = TextEditingController(text: currentFileName);
    final TextEditingController titleController = TextEditingController(text: data['title'] ?? '');
    final TextEditingController subtitleController = TextEditingController(text: data['subtitle'] ?? '');
    final TextEditingController likesController = TextEditingController(text: (data['like_count'] ?? 0).toString());

    bool isLocked = data['isLocked'] ?? false;
    bool isOnline = data['online'] ?? true;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              title: Text(
                'dialog_edit_title'.tr(),
                style: const TextStyle(color: Color(0xFF103856), fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: fileNameController,
                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        labelText: 'File Name (Changes DB & URLs)',
                        labelStyle: TextStyle(color: Colors.redAccent),
                        helperText: 'Warning: Must rename in Cloudflare later',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        labelText: 'field_title'.tr(),
                        labelStyle: const TextStyle(color: Colors.black54),
                      ),
                    ),
                    TextField(
                      controller: subtitleController,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        labelText: 'field_subtitle'.tr(),
                        labelStyle: const TextStyle(color: Colors.black54),
                      ),
                    ),
                    TextField(
                      controller: likesController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        labelText: 'field_likes'.tr(),
                        labelStyle: const TextStyle(color: Colors.black54),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // 🎯 2. STRICT LOCAL UPDATES
                    SwitchListTile(
                      title: const Text('Requires Auth:', style: TextStyle(color: Color(0xFF103856), fontWeight: FontWeight.w500)),
                      value: isLocked,
                      activeColor: Colors.white,
                      activeTrackColor: Colors.lightBlue,
                      inactiveThumbColor: Colors.grey.shade400,
                      inactiveTrackColor: Colors.grey.shade200,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setModalState(() { isLocked = val; });
                        doc.reference.update({'isLocked': val}); // 🎯 INSTANT FIRESTORE SAVE
                      },
                    ),

                    SwitchListTile(
                      title: const Text('Online:', style: TextStyle(color: Color(0xFF103856), fontWeight: FontWeight.w500)),
                      value: isOnline,
                      activeColor: Colors.white,
                      activeTrackColor: Colors.lightBlue,
                      inactiveThumbColor: Colors.grey.shade400,
                      inactiveTrackColor: Colors.grey.shade200,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setModalState(() { isOnline = val; });
                        doc.reference.update({'online': val}); // 🎯 INSTANT FIRESTORE SAVE
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('btn_cancel'.tr(), style: const TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {

                    // 🎯 3. GUARANTEED PAYLOAD (Grabs the exact variables you just toggled)
                    final Map<String, dynamic> updateData = {
                      'title': titleController.text.trim(),
                      'subtitle': subtitleController.text.trim(),
                      'like_count': int.tryParse(likesController.text) ?? 0,
                      'isLocked': isLocked,
                      'online': isOnline,
                    };

                    print("🚀 FIRING TO FIREBASE -> isLocked: $isLocked | online: $isOnline");

                    final newFileName = fileNameController.text.trim();
                    final newDocId = generateDocId(newFileName);

                    if (newDocId != oldDocId && newFileName.isNotEmpty) {
                      String actualOldMp4 = data['url'] != null ? data['url'].toString().split('/').last : 'UNKNOWN_MP4';
                      String actualOldJpg = data['thumb'] != null ? data['thumb'].toString().split('/').last : 'UNKNOWN_JPG';

                      await FirebaseFirestore.instance.collection('filenames-to-fix').add({
                        'old_doc_id': oldDocId,
                        'old_mp4_name': actualOldMp4,
                        'old_jpg_name': actualOldJpg,
                        'new_doc_id': newDocId,
                        'new_mp4_name': '$newDocId.mp4',
                        'new_jpg_name': '$newDocId.jpg',
                        'timestamp': FieldValue.serverTimestamp(),
                      });

                      final newData = Map<String, dynamic>.from(data);
                      newData.addAll(updateData); // Injects the clean toggles
                      newData['url'] = '$_baseUrl$newDocId.mp4';
                      newData['thumb'] = '$_baseUrl$newDocId.jpg';

                      await FirebaseFirestore.instance.collection('feeds').doc(newDocId).set(newData);
                      await doc.reference.delete();
                    } else {
                      // Standard update if filename didn't change
                      await doc.reference.update(updateData);
                    }

                    if (mounted) Navigator.pop(dialogContext);
                  },
                  child: Text('btn_save_changes'.tr()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 🚀 AUTOMATIC HTML GENERATOR (READ-ONLY: 100% SAFE)
  Future<void> _generateAndDownloadHtmlFiles() async {
    final snapshot = await FirebaseFirestore.instance.collection('feeds').get();
    int count = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final docId = doc.id;
      final title = data['title'] ?? 'צפו בווידאו';

      final thumb = data['thumb'] ?? '';
      final url = data['url'] ?? '';

      if (url.isEmpty) continue;

      final htmlFileName = url.split('/').last.replaceAll('.mp4', '.html');
      final exactLink = "https://gamfeiglintzadak.co.il/$htmlFileName";

      final htmlContent = '''<!DOCTYPE html>
<html lang="he">
<head>
  <base href="/">
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">

  <meta name="color-scheme" content="dark">
  <meta name="theme-color" content="#010126" media="(prefers-color-scheme: light)">
  <meta name="theme-color" content="#010126" media="(prefers-color-scheme: dark)">

  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  <meta name="apple-mobile-web-app-title" content="Zehut">

  <title>$title</title>
  <link rel="manifest" href="manifest.json">
  <link rel="icon" type="image/png" href="favicon.png"/>

  <link rel="apple-touch-icon" href="icons/Icon-192.png">
  <link rel="apple-touch-icon" sizes="512x512" href="icons/Icon-512.png">

  <meta name="video-id" content="$docId">

  <meta property="og:type" content="website">
  <meta property="og:url" content="$exactLink">
  <meta property="og:title" content="$title">
  <meta property="og:description" content="צפו לפני הכל כדי להבין את התמונה המלאה.">
  <meta property="og:image" itemprop="image" content="$thumb">
  <meta property="og:image:secure_url" itemprop="image" content="$thumb">
  <meta property="og:image:type" content="image/jpeg">

  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:url" content="$exactLink">
  <meta name="twitter:title" content="$title">
  <meta name="twitter:description" content="צפו לפני הכל כדי להבין את התמונה המלאה.">
  <meta name="twitter:image" content="$thumb">

  <style>
    body, html { margin: 0; padding: 0; width: 100vw; height: 100vh; background-color: #ffffff; overflow: hidden; }
    flt-text-field, input, textarea { background-color: transparent !important; color: white !important; }
    input:-webkit-autofill, input:-webkit-autofill:hover, input:-webkit-autofill:focus { -webkit-box-shadow: 0 0 0 1000px #1E293B inset !important; -webkit-text-fill-color: white !important; }
  </style>
</head>
<body>
<script>
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.getRegistrations().then(function(registrations) {
      for(let registration of registrations) { registration.unregister(); }
    });
  }
  if ('caches' in window) {
    caches.keys().then(function(names) {
      for (let name of names) { caches.delete(name); }
    });
  }
</script>
<script src="flutter_bootstrap.js?v256" async></script>
</body>
</html>''';

      final bytes = utf8.encode(htmlContent);
      final blob = html.Blob([bytes]);
      final urlBlob = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: urlBlob)
        ..setAttribute("download", htmlFileName)
        ..click();
      html.Url.revokeObjectUrl(urlBlob);

      count++;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Generated and downloaded $count HTML files successfully!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ⚠️ DELETE CONFIRMATION DIALOG
  void _confirmDelete(DocumentSnapshot doc, List<DocumentSnapshot> currentDocs) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'dialog_delete_title'.tr(),
          style: const TextStyle(color: Color(0xFF103856), fontWeight: FontWeight.bold),
        ),
        content: Text(
          'dialog_delete_confirm'.tr(),
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('btn_cancel'.tr(), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              _deleteVideo(doc, currentDocs);
            },
            child: Text('btn_delete'.tr()),
          ),
        ],
      ),
    );
  }



  // 🗑️ DELETE & RE-INDEX
  Future<void> _deleteVideo(DocumentSnapshot doc, List<DocumentSnapshot> currentDocs) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(doc.reference);

    final mutableDocs = List<DocumentSnapshot>.from(currentDocs);
    mutableDocs.removeWhere((element) => element.id == doc.id);

    for (int i = 0; i < mutableDocs.length; i++) {
      batch.update(mutableDocs[i].reference, {'index': i});
    }

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.lightBlue),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: const Color(0xFF103856).withOpacity(0.3),
                width: 2.0,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                offset: const Offset(0, 5),
                blurRadius: 14,
              ),
            ],
          ),
        ),
        title: Text(
          'admin_feed_title'.tr(),
          style: const TextStyle(color: Color(0xFF103856), fontWeight: FontWeight.w900, fontSize: 22),
        ),
        centerTitle: true,
        actions: [

          Center(
            child: InkWell(
              onTap: () {
                if (context.locale.languageCode == 'he') {
                  context.setLocale(const Locale('en'));
                } else {
                  context.setLocale(const Locale('he'));
                }
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 5),
                  const Icon(Icons.language, color: Colors.lightBlue, size: 28),
                  const SizedBox(height: 2),
                  Text(
                    context.locale.languageCode == 'he' ? 'English' : 'עברית',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('feeds').orderBy('index').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Colors.lightBlue));
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Text('admin_feed_empty'.tr(), style: const TextStyle(color: Colors.black54)),
            );
          }

          return ReorderableListView.builder(
            itemCount: docs.length,
            onReorder: (oldIndex, newIndex) => _onReorder(oldIndex, newIndex, docs),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              bool isOnline = data['online'] ?? true;
               return Card(
                  key: ValueKey(docs[index].id),
                  color: Colors.white,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  // 🎯 Wrap with InkWell to make the whole card tappable for the Edit menu
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _showEditDialog(docs[index]),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: isOnline ? Colors.lightBlue : Colors.grey.shade500, // 🎯 Grey when offline
                            child: Text(
                              data['index'].toString(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              data['title'] ?? 'label_no_title'.tr(),
                              style: const TextStyle(color: Color(0xFF103856), fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              data['url'].toString().split('/').last,
                              style: const TextStyle(color: Colors.black54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          InkWell(
                            onTap: () => _showEditDialog(docs[index]),
                            child: const Icon(Icons.edit, color: Colors.lightBlue, size: 26),
                          ),
                          const SizedBox(height: 12),
                          Transform.translate(
                            offset: const Offset(0, 3),
                            child: InkWell(
                              onTap: () => _confirmDelete(docs[index], docs),
                              child: const Icon(Icons.delete, color: Colors.red, size: 24),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                  )
              );
            },
          );
        },
      ),
      floatingActionButton: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('feeds').snapshots(),
        builder: (context, snapshot) {
          int nextIndex = snapshot.hasData ? snapshot.data!.docs.length : 0;
          return FloatingActionButton(
            backgroundColor: Colors.lightBlue,
            shape: const CircleBorder(),
            onPressed: () => _showAddDialog(nextIndex),
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          );
        },
      ),
    );
  }
}