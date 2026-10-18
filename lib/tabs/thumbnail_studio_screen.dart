import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:screenshot/screenshot.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class ThumbnailStudioScreen extends StatefulWidget {
  final String? initialDocId;
  const ThumbnailStudioScreen({super.key, this.initialDocId});

  @override
  State<ThumbnailStudioScreen> createState() => _ThumbnailStudioScreenState();
}

class _ThumbnailStudioScreenState extends State<ThumbnailStudioScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  final String _serverBaseUrl = 'https://zehut-server.onrender.com';
  final String _r2BaseUrl = 'https://pub-142306085f2b48bda4045cd9efdd0d28.r2.dev';

  Uint8List? _selectedImageBytes;
  String? _existingThumbUrl;
  bool _isViewingExisting = false;
  bool _isDirty = false;

  double _imageOffsetX = 0.0;
  double _imageOffsetY = 0.0;
  double _imageScale = 1.25;
  String _iconType = 'play_blue';
  String? _selectedDocId;

  final TextEditingController _aiPromptController = TextEditingController();
  final TextEditingController _heb1Controller = TextEditingController();
  final TextEditingController _heb2Controller = TextEditingController();
  final TextEditingController _eng1Controller = TextEditingController();
  final TextEditingController _eng2Controller = TextEditingController();
  final TextEditingController _fileNameController = TextEditingController(text: 'thumbnail.jpg');

  bool _isUploading = false;
  bool _isGeneratingAi = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialDocId != null && widget.initialDocId!.isNotEmpty) {
      _selectedDocId = widget.initialDocId;
      _fileNameController.text = '${widget.initialDocId}.jpg';
      _loadExistingThumbnailForDoc(widget.initialDocId!);
    }
  }

  @override
  void dispose() {
    _aiPromptController.dispose();
    _heb1Controller.dispose();
    _heb2Controller.dispose();
    _eng1Controller.dispose();
    _eng2Controller.dispose();
    _fileNameController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingThumbnailForDoc(String docId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('feeds').doc(docId).get();
      String url = '$_r2BaseUrl/$docId.jpg?v=${DateTime.now().millisecondsSinceEpoch}';
      if (doc.exists && doc.data()?['thumb'] != null) {
        final String rawThumb = doc.data()!['thumb'].toString();
        if (rawThumb.isNotEmpty) {
          final String cleanBase = rawThumb.split('?').first.replaceAll(
            'https://gamfeiglintzadak.co.il/',
            '$_r2BaseUrl/',
          );
          url = '$cleanBase?v=${DateTime.now().millisecondsSinceEpoch}';
        }
      }
      if (mounted) {
        setState(() {
          _existingThumbUrl = url;
          _selectedImageBytes = null;
          _isViewingExisting = true;
          _isDirty = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading existing thumb: $e');
    }
  }

  void _clearCanvasToBlank() {
    setState(() {
      _selectedImageBytes = null;
      _isViewingExisting = false;
      _imageOffsetX = 0.0;
      _imageOffsetY = 0.0;
      _imageScale = 1.25;
      _heb1Controller.clear();
      _heb2Controller.clear();
      _eng1Controller.clear();
      _eng2Controller.clear();
      _isDirty = true;
    });
  }

  void _reloadExistingThumb() {
    if (_selectedDocId != null) {
      _loadExistingThumbnailForDoc(_selectedDocId!);
    } else if (_fileNameController.text.trim().isNotEmpty) {
      final String cleanName = _fileNameController.text
          .trim()
          .replaceAll(RegExp(r'\.(jpg|jpeg|png|mp4|html)$', caseSensitive: false), '');
      setState(() {
        _existingThumbUrl = '$_r2BaseUrl/$cleanName.jpg?v=${DateTime.now().millisecondsSinceEpoch}';
        _selectedImageBytes = null;
        _isViewingExisting = true;
        _isDirty = false;
      });
    }
  }

  Future<bool> _confirmDiscardIfNeeded() async {
    if (!_isDirty) return true;
    final bool isHe = context.locale.languageCode == 'he';

    final bool? shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF103856),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isHe ? 'לצאת ללא שמירה?' : 'Leave Without Saving?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isHe
              ? 'יש לך שינויים שלא הועלו ל-Cloudflare R2. האם אתה בטוח שברצונך לצאת?'
              : 'You have unsaved work on the canvas that hasn\'t been uploaded to Cloudflare R2 yet. Leave anyway?',
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              isHe ? 'הישאר בעמוד' : 'STAY',
              style: const TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isHe ? 'צא ללא שמירה' : 'LEAVE',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    return shouldLeave ?? false;
  }

  void _pickImage() {
    final html.FileUploadInputElement input = html.FileUploadInputElement()..accept = 'image/*';
    input.click();

    input.onChange.listen((event) {
      final file = input.files?.first;
      if (file == null) return;

      if (_selectedDocId == null) {
        final String baseName = file.name.replaceAll(RegExp(r'\.[^\.]+$'), '');
        _fileNameController.text = '$baseName.jpg';
      }

      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onLoadEnd.listen((_) {
        if (reader.result != null && mounted) {
          setState(() {
            _selectedImageBytes = reader.result as Uint8List;
            _isViewingExisting = false;
            _imageOffsetX = 0.0;
            _imageOffsetY = 0.0;
            _imageScale = 1.25;
            _isDirty = true;
          });
        }
      });
    });
  }

  Future<void> _generateAiImage() async {
    final bool isHe = context.locale.languageCode == 'he';
    final String prompt = _aiPromptController.text.trim();

    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isHe ? 'כתוב תיאור לתמונה שאתה רוצה לייצר' : 'Enter a description for the AI image first'),
          backgroundColor: Colors.orangeAccent.shade700,
        ),
      );
      return;
    }

    setState(() => _isGeneratingAi = true);
    try {
      final response = await http.post(
        Uri.parse('$_serverBaseUrl/generateAiImage'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt}),
      );

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }

      final data = jsonDecode(response.body);
      if (data['imageBase64'] != null) {
        final Uint8List bytes = base64Decode(data['imageBase64']);
        setState(() {
          _selectedImageBytes = bytes;
          _isViewingExisting = false;
          _imageOffsetX = 0.0;
          _imageOffsetY = 0.0;
          _imageScale = 1.25;
          _isDirty = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isHe ? 'שגיאה ביצירת תמונה: $e' : 'AI generation error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingAi = false);
    }
  }

  Future<Uint8List?> _captureHighResBytes() async {
    return await _screenshotController.captureFromWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: ui.TextDirection.ltr,
          child: Material(
            color: Colors.transparent,
            child: _build1080Canvas(),
          ),
        ),
      ),
      pixelRatio: 1.0,
      targetSize: const Size(1080, 1080),
    );
  }

  Future<void> _uploadToCloudflareR2() async {
    final bool isHe = context.locale.languageCode == 'he';

    if (_selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isHe
                ? 'אנא בחר תמונה חדשה או צור תמונה ב-AI לפני העלאה'
                : 'Please select a new image or generate with AI before uploading',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      final Uint8List? imageBytes = await _captureHighResBytes();
      if (imageBytes == null) throw Exception('Failed to capture canvas');

      String prefix = (_selectedDocId != null && _selectedDocId!.isNotEmpty)
          ? _selectedDocId!
          : _fileNameController.text.trim().replaceAll(RegExp(r'\.(jpg|jpeg|png|mp4|html)$', caseSensitive: false), '');

      if (prefix.isEmpty) prefix = 'thumbnail';
      final String exactFileName = '$prefix.jpg';

      final String base64Image = base64Encode(imageBytes);

      final response = await http.post(
        Uri.parse('$_serverBaseUrl/uploadThumbnail'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'docId': prefix,
          'fileName': exactFileName,
          'imageBase64': base64Image,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }

      final int cacheBuster = DateTime.now().millisecondsSinceEpoch;
      final String r2Url = '$_r2BaseUrl/$exactFileName?v=$cacheBuster';

      if (_selectedDocId != null && _selectedDocId!.isNotEmpty) {
        await FirebaseFirestore.instance.collection('feeds').doc(_selectedDocId).set({
          'thumb': r2Url,
        }, SetOptions(merge: true));
      }

      if (mounted) {
        setState(() {
          _existingThumbUrl = r2Url;
          _isDirty = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isHe
                  ? '✅ $exactFileName הועלה ל-Cloudflare R2 ועודכן!'
                  : '✅ $exactFileName uploaded to Cloudflare R2 & synced!',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isHe ? 'שגיאה בהעלאה לענן: $e' : 'Cloud upload error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _downloadLocalCopy() async {
    setState(() => _isUploading = true);
    try {
      final Uint8List? pngBytes = await _captureHighResBytes();
      if (pngBytes == null) return;

      String prefix = (_selectedDocId != null && _selectedDocId!.isNotEmpty)
          ? _selectedDocId!
          : _fileNameController.text.trim().replaceAll(RegExp(r'\.(jpg|jpeg|png|mp4|html)$', caseSensitive: false), '');
      if (prefix.isEmpty) prefix = 'thumbnail';
      final String fileName = '$prefix.jpg';

      final blob = html.Blob([pngBytes], 'image/jpeg');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      debugPrint('Download error: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Widget _build1080Canvas() {
    if (_isViewingExisting && _existingThumbUrl != null && _selectedImageBytes == null) {
      return Container(
        width: 1080,
        height: 1080,
        color: const Color(0xFF0F172A),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              _existingThumbUrl!,
              width: 1080,
              height: 1080,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.broken_image_outlined, size: 110, color: Colors.white38),
                      SizedBox(height: 16),
                      Text(
                        'No existing thumbnail found on R2.\nTap "Clear Canvas" or select an image below.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              top: 24,
              left: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.greenAccent, width: 3),
                ),
                child: const Text(
                  'LIVE ON CLOUDFLARE R2',
                  style: TextStyle(color: Colors.greenAccent, fontSize: 24, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 1080,
      height: 1080,
      color: const Color(0xFF0F172A),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 680,
            child: ClipRect(
              child: _selectedImageBytes != null
                  ? GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) {
                  setState(() {
                    _imageOffsetX = (_imageOffsetX + details.delta.dx * 2.0).clamp(-600.0, 600.0);
                    _imageOffsetY = (_imageOffsetY + details.delta.dy * 2.0).clamp(-600.0, 600.0);
                    _isDirty = true;
                  });
                },
                child: Transform.translate(
                  offset: Offset(_imageOffsetX, _imageOffsetY),
                  child: Transform.scale(
                    scale: _imageScale,
                    child: Image.memory(
                      _selectedImageBytes!,
                      width: 1080,
                      height: 680,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              )
                  : Container(
                color: const Color(0xFF1E293B),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.auto_awesome, size: 110, color: Colors.purpleAccent),
                    SizedBox(height: 20),
                    Text(
                      'Blank Canvas — Select File or Generate AI',
                      style: TextStyle(color: Colors.white70, fontSize: 36, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 680,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: const Color(0xFFDC0000),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildBannerText(
                    _heb1Controller.text.isEmpty ? 'שורה 1 בעברית' : _heb1Controller.text,
                    fontSize: 64,
                    color: const Color(0xFFFFE600),
                    isRtl: true,
                  ),
                  if (_heb2Controller.text.isNotEmpty)
                    _buildBannerText(
                      _heb2Controller.text,
                      fontSize: 54,
                      color: const Color(0xFFFFE600),
                      isRtl: true,
                    ),
                  if (_eng1Controller.text.isNotEmpty)
                    _buildBannerText(
                      _eng1Controller.text,
                      fontSize: 54,
                      color: Colors.white,
                      isRtl: false,
                    ),
                  if (_eng2Controller.text.isNotEmpty)
                    _buildBannerText(
                      _eng2Controller.text,
                      fontSize: 46,
                      color: Colors.white,
                      isRtl: false,
                    ),
                ],
              ),
            ),
          ),
          if (_iconType != 'none')
            Positioned(
              top: 320,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: _buildCenterBadge(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBannerText(String text, {required double fontSize, required Color color, required bool isRtl}) {
    return Directionality(
      textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                height: 1.1,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 10
                  ..color = Colors.black.withOpacity(0.9),
                shadows: const [
                  Shadow(color: Colors.black, blurRadius: 14, offset: Offset(0, 5)),
                ],
              ),
            ),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                height: 1.1,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterBadge() {
    if (_iconType == 'play_blue') {
      return Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(-0.25, -0.35),
            radius: 0.9,
            colors: [
              Color(0xEB82B1FF),
              Color(0xE02979FF),
              Color(0xF21565C0),
            ],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.7), width: 5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: 25, offset: const Offset(0, 10)),
          ],
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.only(left: 14),
            child: Icon(Icons.play_arrow_rounded, size: 175, color: Color(0xFF090D16)),
          ),
        ),
      );
    } else if (_iconType == 'play_dark') {
      return Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF103856).withOpacity(0.75),
          border: Border.all(color: Colors.white.withOpacity(0.5), width: 4),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.only(left: 14),
            child: Icon(Icons.play_arrow_rounded, size: 175, color: Colors.white),
          ),
        ),
      );
    } else if (_iconType == 'radar') {
      return Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF103856).withOpacity(0.88),
          border: Border.all(color: Colors.lightBlueAccent, width: 6),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 25, offset: const Offset(0, 8)),
          ],
        ),
        child: const Center(
          child: Icon(Icons.location_on, size: 155, color: Colors.redAccent),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required bool isRtl,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        textAlign: isRtl ? TextAlign.right : TextAlign.left,
        onChanged: (_) {
          setState(() {
            _isViewingExisting = false;
            _isDirty = true;
          });
        },
        style: TextStyle(
          color: readOnly ? Colors.lightBlueAccent : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70, fontSize: 14),
          filled: true,
          fillColor: const Color(0xFF0F172A),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.lightBlue, width: 2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isHe = context.locale.languageCode == 'he';

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final bool canLeave = await _confirmDiscardIfNeeded();
        if (canLeave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF103856),
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () async {
              final bool canLeave = await _confirmDiscardIfNeeded();
              if (canLeave && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            isHe ? 'אולפן תמונות ממוזערות' : 'Thumbnail Studio',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          actions: [
            InkWell(
              onTap: () {
                if (isHe) {
                  context.setLocale(const Locale('en'));
                } else {
                  context.setLocale(const Locale('he'));
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.language, color: Colors.lightBlue, size: 24),
                    Text(
                      isHe ? 'English' : 'עברית',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(14.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. VIDEO TARGET SELECTOR AT TOP
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.lightBlue.withOpacity(0.4)),
                      ),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('feeds').orderBy('index').snapshots(),
                        builder: (context, snapshot) {
                          final docs = snapshot.data?.docs ?? [];
                          return DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: docs.any((d) => d.id == _selectedDocId) ? _selectedDocId : null,
                              dropdownColor: const Color(0xFF103856),
                              isDense: true,
                              hint: Text(
                                isHe ? 'בחר סרטון לעריכה (טוען תמונה קיימת)...' : 'Select Video Target (Auto-loads existing)...',
                                style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              isExpanded: true,
                              items: [
                                DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(isHe ? 'שם קובץ ידני (למשל kitat-konenut.jpg)' : 'Custom Filename (e.g. kitat-konenut.jpg)'),
                                ),
                                ...docs.map((doc) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  final title = data['title']?.toString() ?? doc.id;
                                  return DropdownMenuItem<String?>(
                                    value: doc.id,
                                    child: Text('$title (${doc.id}.jpg)', overflow: TextOverflow.ellipsis),
                                  );
                                }),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _selectedDocId = val;
                                  if (val != null) {
                                    _fileNameController.text = '$val.jpg';
                                    _loadExistingThumbnailForDoc(val);
                                  } else {
                                    _isViewingExisting = false;
                                    _existingThumbUrl = null;
                                  }
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 2. PROPORTIONAL LIVE PREVIEW
                    AspectRatio(
                      aspectRatio: 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white24, width: 2),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Screenshot(
                              controller: _screenshotController,
                              child: _build1080Canvas(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 🎯 3. COMPACT SLIDERS DIRECTLY UNDER THE PHOTO (Before Select Image File!)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orangeAccent.withOpacity(0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.zoom_in, color: Colors.orangeAccent, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                isHe
                                    ? 'זום (${_imageScale.toStringAsFixed(1)}x)'
                                    : 'Zoom (${_imageScale.toStringAsFixed(1)}x)',
                                style: const TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 3,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                  ),
                                  child: Slider(
                                    value: _imageScale,
                                    min: 0.6,
                                    max: 4.0,
                                    activeColor: Colors.orangeAccent,
                                    onChanged: (val) => setState(() {
                                      _imageScale = val;
                                      _isViewingExisting = false;
                                      _isDirty = true;
                                    }),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.swap_vert, color: Colors.lightBlueAccent, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                isHe ? 'גובה' : 'Pan Y',
                                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 3,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                  ),
                                  child: Slider(
                                    value: _imageOffsetY,
                                    min: -600,
                                    max: 600,
                                    activeColor: Colors.lightBlueAccent,
                                    onChanged: (val) => setState(() {
                                      _imageOffsetY = val;
                                      _isViewingExisting = false;
                                      _isDirty = true;
                                    }),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.swap_horiz, color: Colors.lightBlueAccent, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                isHe ? 'רוחב' : 'Pan X',
                                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 3,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                  ),
                                  child: Slider(
                                    value: _imageOffsetX,
                                    min: -600,
                                    max: 600,
                                    activeColor: Colors.lightBlueAccent,
                                    onChanged: (val) => setState(() {
                                      _imageOffsetX = val;
                                      _isViewingExisting = false;
                                      _isDirty = true;
                                    }),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 4. QUICK CANVAS ACTION BAR: CLEAR CANVAS vs RELOAD EXISTING
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _clearCanvasToBlank,
                            icon: const Icon(Icons.layers_clear, color: Colors.orangeAccent, size: 18),
                            label: Text(
                              isHe ? 'נקה משטח' : 'Clear Canvas',
                              style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.orangeAccent),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _reloadExistingThumb,
                            icon: const Icon(Icons.refresh, color: Colors.lightBlueAccent, size: 18),
                            label: Text(
                              isHe ? 'טען קיים' : 'Reload Existing',
                              style: const TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.lightBlueAccent),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 5. CONTROLS CARD (Select Image File + AI + Text Lines)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.upload_file, color: Colors.white),
                            label: Text(
                              isHe ? 'בחר תמונה מהמכשיר' : 'Select Image File',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.lightBlue,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ✨ AI BACKGROUND GENERATOR ROW
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.purpleAccent.withOpacity(0.5)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _aiPromptController,
                                  textDirection: isHe ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                                  style: const TextStyle(color: Colors.white, fontSize: 15),
                                  maxLines: 2,
                                  minLines: 1,
                                  decoration: InputDecoration(
                                    hintText: isHe
                                        ? 'או תאר תמונה ליצירה ב-AI (בעברית או באנגלית)...'
                                        : 'Or describe an image to generate with AI...',
                                    hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: _isGeneratingAi ? null : _generateAiImage,
                                  icon: _isGeneratingAi
                                      ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                      : const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                                  label: Text(
                                    _isGeneratingAi
                                        ? (isHe ? 'מייצר תמונה ב-AI...' : 'Generating AI Image...')
                                        : (isHe ? 'צור תמונת רקע ב-AI' : 'Generate AI Background'),
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purpleAccent.shade700,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          Text(
                            isHe ? 'סמל מרכזי (כפתור הפעלה)' : 'Center Button Style',
                            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _iconType,
                                dropdownColor: const Color(0xFF103856),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                isExpanded: true,
                                items: [
                                  DropdownMenuItem(
                                    value: 'play_blue',
                                    child: Text(isHe ? 'כפתור Play כחול מבריק' : 'Glossy Blue Play Button'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'play_dark',
                                    child: Text(isHe ? 'כפתור Play כהה שקוף' : 'Translucent Dark Play Button'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'radar',
                                    child: Text(isHe ? 'סמל מפה / נעץ מיקום' : 'Map Pin / Radar Badge'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'none',
                                    child: Text(isHe ? 'ללא סמל (None)' : 'No Center Icon (None)'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _iconType = val;
                                      _isViewingExisting = false;
                                      _isDirty = true;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          _buildInputField(
                            controller: _heb1Controller,
                            label: isHe ? 'עברית - שורה 1 (צהוב)' : 'Hebrew Line 1 (Yellow)',
                            isRtl: true,
                          ),
                          _buildInputField(
                            controller: _heb2Controller,
                            label: isHe ? 'עברית - שורה 2 (צהוב)' : 'Hebrew Line 2 (Yellow)',
                            isRtl: true,
                          ),
                          _buildInputField(
                            controller: _eng1Controller,
                            label: isHe ? 'אנגלית - שורה 1 (לבן)' : 'English Line 1 (White)',
                            isRtl: false,
                          ),
                          _buildInputField(
                            controller: _eng2Controller,
                            label: isHe ? 'אנגלית - שורה 2 (לבן)' : 'English Line 2 (White)',
                            isRtl: false,
                          ),
                          _buildInputField(
                            controller: _fileNameController,
                            label: isHe ? 'שם קובץ ב-Cloudflare R2 (חייב לתאום ל-MP4/HTML)' : 'Cloudflare R2 Filename (Matches MP4/HTML prefix)',
                            isRtl: false,
                            readOnly: _selectedDocId != null,
                          ),
                          const SizedBox(height: 10),

                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isUploading ? null : _uploadToCloudflareR2,
                                  icon: _isUploading
                                      ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                                  )
                                      : const Icon(Icons.cloud_upload_rounded, color: Colors.black, size: 26),
                                  label: Text(
                                    isHe ? 'העלה ל-Cloudflare R2' : 'Upload to Cloudflare R2',
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.black),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF25D366),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton.filled(
                                onPressed: _isUploading ? null : _downloadLocalCopy,
                                tooltip: isHe ? 'הורד עותק למכשיר' : 'Download local copy',
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFF103856),
                                  padding: const EdgeInsets.all(16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: const BorderSide(color: Colors.lightBlueAccent),
                                  ),
                                ),
                                icon: const Icon(Icons.download_rounded, color: Colors.white),
                              ),
                            ],
                          ),
                        ],
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
}