import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:convert';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';
import 'package:path_provider/path_provider.dart';

class AdminFeedManager extends StatefulWidget {
  const AdminFeedManager({super.key});

  @override
  State<AdminFeedManager> createState() => _AdminFeedManagerState();
}

class _AdminFeedManagerState extends State<AdminFeedManager> {
  final String _baseUrl = "https://gamfeiglintzadak.co.il/";

  String generateDocId(String title) {
    return title
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\u0590-\u05FF]+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
  }

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
              title: Text('dialog_edit_title'.tr(), style: const TextStyle(color: Color(0xFF103856), fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: fileNameController, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold), decoration: const InputDecoration(labelText: 'File Name (Changes DB & URLs)', labelStyle: TextStyle(color: Colors.redAccent), helperText: 'Warning: Must rename in Cloudflare later')),
                    const SizedBox(height: 10),
                    TextField(controller: titleController, style: const TextStyle(color: Colors.black87), decoration: InputDecoration(labelText: 'field_title'.tr(), labelStyle: const TextStyle(color: Colors.black54))),
                    TextField(controller: subtitleController, style: const TextStyle(color: Colors.black87), decoration: InputDecoration(labelText: 'field_subtitle'.tr(), labelStyle: const TextStyle(color: Colors.black54))),
                    TextField(controller: likesController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.black87), decoration: InputDecoration(labelText: 'field_likes'.tr(), labelStyle: const TextStyle(color: Colors.black54))),
                    const SizedBox(height: 15),
                    SwitchListTile(title: const Text('Requires Auth:', style: TextStyle(color: Color(0xFF103856), fontWeight: FontWeight.w500)), value: isLocked, activeColor: Colors.white, activeTrackColor: Colors.lightBlue, inactiveThumbColor: Colors.grey.shade400, inactiveTrackColor: Colors.grey.shade200, contentPadding: EdgeInsets.zero, onChanged: (val) { setModalState(() { isLocked = val; }); doc.reference.update({'isLocked': val}); }),
                    SwitchListTile(title: const Text('Online:', style: TextStyle(color: Color(0xFF103856), fontWeight: FontWeight.w500)), value: isOnline, activeColor: Colors.white, activeTrackColor: Colors.lightBlue, inactiveThumbColor: Colors.grey.shade400, inactiveTrackColor: Colors.grey.shade200, contentPadding: EdgeInsets.zero, onChanged: (val) { setModalState(() { isOnline = val; }); doc.reference.update({'online': val}); }),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('btn_cancel'.tr(), style: const TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue, foregroundColor: Colors.white),
                  onPressed: () async {
                    final Map<String, dynamic> updateData = {
                      'title': titleController.text.trim(),
                      'subtitle': subtitleController.text.trim(),
                      'like_count': int.tryParse(likesController.text) ?? 0,
                      'isLocked': isLocked,
                      'online': isOnline,
                    };
                    final newFileName = fileNameController.text.trim();
                    final newDocId = generateDocId(newFileName);

                    if (newDocId != oldDocId && newFileName.isNotEmpty) {
                      String actualOldMp4 = data['url'] != null ? data['url'].toString().split('/').last : 'UNKNOWN_MP4';
                      String actualOldJpg = data['thumb'] != null ? data['thumb'].toString().split('/').last : 'UNKNOWN_JPG';
                      await FirebaseFirestore.instance.collection('filenames-to-fix').add({'old_doc_id': oldDocId, 'old_mp4_name': actualOldMp4, 'old_jpg_name': actualOldJpg, 'new_doc_id': newDocId, 'new_mp4_name': '$newDocId.mp4', 'new_jpg_name': '$newDocId.jpg', 'timestamp': FieldValue.serverTimestamp()});
                      final newData = Map<String, dynamic>.from(data);
                      newData.addAll(updateData);
                      newData['url'] = '$_baseUrl$newDocId.mp4';
                      newData['thumb'] = '$_baseUrl$newDocId.jpg';
                      await FirebaseFirestore.instance.collection('feeds').doc(newDocId).set(newData);
                      await doc.reference.delete();
                    } else {
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
      final htmlContent = '''<!DOCTYPE html>\n<html lang="he">\n<head>\n<base href="/">\n<meta charset="UTF-8">\n<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">\n<meta name="color-scheme" content="dark">\n<meta name="theme-color" content="#010126" media="(prefers-color-scheme: light)">\n<meta name="theme-color" content="#010126" media="(prefers-color-scheme: dark)">\n<meta name="apple-mobile-web-app-capable" content="yes">\n<meta name="mobile-web-app-capable" content="yes">\n<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">\n<meta name="apple-mobile-web-app-title" content="Zehut">\n<title>$title</title>\n<link rel="manifest" href="manifest.json">\n<link rel="icon" type="image/png" href="favicon.png"/>\n<link rel="apple-touch-icon" href="icons/Icon-192.png">\n<link rel="apple-touch-icon" sizes="512x512" href="icons/Icon-512.png">\n<meta name="video-id" content="$docId">\n<meta property="og:type" content="website">\n<meta property="og:url" content="$exactLink">\n<meta property="og:title" content="$title">\n<meta property="og:description" content="צפו לפני הכל כדי להבין את התמונה המלאה.">\n<meta property="og:image" itemprop="image" content="$thumb">\n<meta property="og:image:secure_url" itemprop="image" content="$thumb">\n<meta property="og:image:type" content="image/jpeg">\n<meta name="twitter:card" content="summary_large_image">\n<meta name="twitter:url" content="$exactLink">\n<meta name="twitter:title" content="$title">\n<meta name="twitter:description" content="צפו לפני הכל כדי להבין את התמונה המלאה.">\n<meta name="twitter:image" content="$thumb">\n<style>\nbody, html { margin: 0; padding: 0; width: 100vw; height: 100vh; background-color: #ffffff; overflow: hidden; }\nflt-text-field, input, textarea { background-color: transparent !important; color: white !important; }\ninput:-webkit-autofill, input:-webkit-autofill:hover, input:-webkit-autofill:focus { -webkit-box-shadow: 0 0 0 1000px #1E293B inset !important; -webkit-text-fill-color: white !important; }\n</style>\n</head>\n<body>\n<script>\nif ('serviceWorker' in navigator) { navigator.serviceWorker.getRegistrations().then(function(registrations) { for(let registration of registrations) { registration.unregister(); } }); }\nif ('caches' in window) { caches.keys().then(function(names) { for (let name of names) { caches.delete(name); } }); }\n</script>\n<script src="flutter_bootstrap.js?v256" async></script>\n</body>\n</html>''';
      final bytes = utf8.encode(htmlContent);
      final blob = html.Blob([bytes]);
      final urlBlob = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: urlBlob)..setAttribute("download", htmlFileName)..click();
      html.Url.revokeObjectUrl(urlBlob);
      count++;
    }
    if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Generated and downloaded $count HTML files successfully!'), backgroundColor: Colors.green, duration: const Duration(seconds: 4))); }
  }

  void _confirmDelete(DocumentSnapshot doc, List<DocumentSnapshot> currentDocs) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text('dialog_delete_title'.tr(), style: const TextStyle(color: Color(0xFF103856), fontWeight: FontWeight.bold)),
        content: Text('dialog_delete_confirm'.tr(), style: const TextStyle(color: Colors.black87)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('btn_cancel'.tr(), style: const TextStyle(color: Colors.grey))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white), onPressed: () { Navigator.pop(context); _deleteVideo(doc, currentDocs); }, child: Text('btn_delete'.tr())),
        ],
      ),
    );
  }

  Future<void> _deleteVideo(DocumentSnapshot doc, List<DocumentSnapshot> currentDocs) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(doc.reference);
    final mutableDocs = List<DocumentSnapshot>.from(currentDocs);
    mutableDocs.removeWhere((element) => element.id == doc.id);
    for (int i = 0; i < mutableDocs.length; i++) { batch.update(mutableDocs[i].reference, {'index': i}); }
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
          decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: const Color(0xFF103856).withOpacity(0.3), width: 2.0)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), offset: const Offset(0, 5), blurRadius: 14)]),
        ),
        title: Text('admin_feed_title'.tr(), style: const TextStyle(color: Color(0xFF103856), fontWeight: FontWeight.w900, fontSize: 22)),
        centerTitle: true,
        actions: [
          Center(
            child: InkWell(
              onTap: () {
                if (context.locale.languageCode == 'he') { context.setLocale(const Locale('en')); } else { context.setLocale(const Locale('he')); }
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 5),
                  const Icon(Icons.language, color: Colors.lightBlue, size: 28),
                  const SizedBox(height: 2),
                  Text(context.locale.languageCode == 'he' ? 'English' : 'עברית', style: const TextStyle(color: Colors.black, fontSize: 11.5, fontWeight: FontWeight.bold)),
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
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.lightBlue));
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return Center(child: Text('admin_feed_empty'.tr(), style: const TextStyle(color: Colors.black54)));

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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withOpacity(0.2))),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                    child: Row(
                      children: [
                        // 🎯 THE CLICKABLE FILM REEL ICON
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            final String? videoUrl = data['url'];
                            if (videoUrl != null && videoUrl.isNotEmpty) {
                              html.window.open(videoUrl, '_blank');
                            }
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(Icons.movie, color: isOnline ? Colors.lightBlue : Colors.grey.shade500, size: 44),
                              Positioned(
                                child: Text(
                                  data['index'].toString(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _showEditDialog(docs[index]),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(data['title'] ?? 'label_no_title'.tr(), style: const TextStyle(color: Color(0xFF103856), fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(data['url'].toString().split('/').last, style: const TextStyle(color: Colors.black54, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            InkWell(onTap: () => _showEditDialog(docs[index]), child: const Icon(Icons.edit, color: Colors.lightBlue, size: 26)),
                            const SizedBox(height: 12),
                            Transform.translate(offset: const Offset(0, 3), child: InkWell(onTap: () => _confirmDelete(docs[index], docs), child: const Icon(Icons.delete, color: Colors.red, size: 24))),
                          ],
                        ),
                      ],
                    ),
                  )
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.lightBlue,
        shape: const CircleBorder(),
        onPressed: () {
          showDialog(
            context: context,
            barrierColor: Colors.black.withOpacity(0.70),
            builder: (BuildContext context) {
              return const Dialog(
                backgroundColor: Colors.transparent,
                // 🎯 REMOVED height: 650 to allow natural wrapping
                child: SizedBox(
                  width: 500,
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    child: VideoDeployWidget(),
                  ),
                ),
              );
            },
          );
        },
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}

class VideoDeployWidget extends StatefulWidget {
  const VideoDeployWidget({super.key});
  @override
  State<VideoDeployWidget> createState() => _VideoDeployWidgetState();
}

class _VideoDeployWidgetState extends State<VideoDeployWidget> {
  final _urlController = TextEditingController();
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  final _titleController = TextEditingController();

  bool _isDeploying = false;

  Future<void> _deployVideo() async {
    if (_urlController.text.isEmpty ||
        _startController.text.isEmpty ||
        _endController.text.isEmpty ||
        _titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('deploy_err_fields'.tr()), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() { _isDeploying = true; });

    try {
      final url = _urlController.text.trim();
      final title = _titleController.text.trim();
      final startSec = int.parse(_startController.text.trim());
      final endSec = int.parse(_endController.text.trim());

      final String safeTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9א-ת]'), '-');
      final String fileName = '$safeTitle.mp4';
      final String docId = safeTitle;
      final String r2BaseUrl = "https://gamfeiglintzadak.co.il/";

      debugPrint("Triggering Railway Cloud Extractor...");
      final response = await http.post(
        Uri.parse('https://zehut-server-production.up.railway.app/processAndDeployVideo'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'url': url,
          'start': startSec,
          'end': endSec,
          'title': title,
          'docId': docId,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception("${'deploy_err_fail'.tr()} ${response.body}");
      }

      debugPrint("Writing to Firestore database...");
      final snapshot = await FirebaseFirestore.instance
          .collection('feeds')
          .orderBy('index', descending: true)
          .limit(1)
          .get();

      int newIndex = 0;
      if (snapshot.docs.isNotEmpty) {
        newIndex = (snapshot.docs.first.data()['index'] ?? 0) + 1;
      }

      await FirebaseFirestore.instance.collection('feeds').doc(docId).set({
        'title': title,
        'subtitle': '',
        'url': '$r2BaseUrl$fileName',
        'thumb': '$r2BaseUrl$docId.jpg',
        'index': newIndex,
        'online': true,
        'isLocked': false,
        'like_count': 0,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('deploy_success'.tr()), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${'deploy_err_fail'.tr()} $e"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isDeploying = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          title: Text('deploy_title'.tr(), style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF103856),
          automaticallyImplyLeading: false
      ),
      body: SingleChildScrollView(
        // 🎯 REDUCED PADDING AND ADDED BOTTOM PADDING
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 24.0, bottom: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('deploy_pipeline'.tr(), style: const TextStyle(color: Colors.lightBlue, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 29), // 🎯 +5px SPACING
            _buildTextField(controller: _titleController, label: 'deploy_clip_title'.tr(), enabled: !_isDeploying),
            const SizedBox(height: 21), // 🎯 +5px SPACING
            _buildTextField(controller: _urlController, label: 'deploy_url'.tr(), enabled: !_isDeploying),
            const SizedBox(height: 21), // 🎯 +5px SPACING
            Row(
              children: [
                Expanded(child: _buildTextField(controller: _startController, label: 'deploy_start'.tr(), isNumber: true, enabled: !_isDeploying)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField(controller: _endController, label: 'deploy_end'.tr(), isNumber: true, enabled: !_isDeploying)),
              ],
            ),
            const SizedBox(height: 37), // 🎯 +5px SPACING
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isDeploying ? null : _deployVideo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isDeploying ? Colors.grey.shade300 : Colors.lightBlue,
                  foregroundColor: _isDeploying ? Colors.grey.shade500 : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: _isDeploying
                    ? const CircularProgressIndicator(color: Colors.lightBlue)
                    : Text('deploy_btn'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, bool isNumber = false, bool enabled = true}) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600),
        filled: true,
        fillColor: Colors.grey.shade200,
        // 🎯 TIGHTENED INTERNAL PADDING TO PREVENT TEXT CLIPPING
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        disabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.lightBlue), borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// NATIVE DEVICE CLIPPER SERVICE
class VideoClipperService {
  final YoutubeExplode _yt = YoutubeExplode();

  Future<File?> clipVideo({
    required String url,
    required int startSec,
    required int endSec,
    required String outputTitle,
  }) async {
    try {
      debugPrint("1. Resolving YouTube stream on phone...");
      final video = await _yt.videos.get(url);
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);

      final streamInfo = manifest.muxed.withHighestBitrate();
      final streamUrl = streamInfo.url.toString();

      final duration = (endSec > startSec) ? (endSec - startSec) : 15;
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/$outputTitle.mp4';

      final existingFile = File(outputPath);
      if (await existingFile.exists()) {
        await existingFile.delete();
      }

      debugPrint("2. Native FFmpeg trimming ${duration}s directly from stream...");
      final command = '-ss $startSec -i "$streamUrl" -t $duration -c copy -avoid_negative_ts make_zero "$outputPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        debugPrint("3. Clip ready on device at: $outputPath");
        return File(outputPath);
      } else {
        final logs = await session.getAllLogsAsString();
        debugPrint("FFmpeg error: $logs");
        return null;
      }
    } catch (e) {
      debugPrint("Clipper error: $e");
      return null;
    } finally {
      _yt.close();
    }
  }
}