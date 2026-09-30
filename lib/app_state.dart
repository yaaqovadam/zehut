import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:watch_it/watch_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'dart:ui' as ui;
import 'dart:convert'; // 🎯 Added for Make.com Webhook payload
import 'package:http/http.dart' as http; // ß🎯 Added for Make.com Webhook trigger

class VerificationResult {
  final bool isAlreadyVerified;
  final String phone;
  final String uid;
  final String? authCode;

  VerificationResult({
    required this.isAlreadyVerified,
    required this.phone,
    required this.uid,
    this.authCode,
  });
}

class AppState {
  final navIndex = ValueNotifier<int>(0);

// 🎯 ADD THESE 4 LINES TO SHARE THE VIDEO WITH THE SCRUBBER
  final ValueNotifier<bool> isFeedEditMode = ValueNotifier<bool>(false);
  final ValueNotifier<dynamic> editVideoController = ValueNotifier<dynamic>(null);
  final ValueNotifier<String> editWaveformUrl = ValueNotifier<String>('');
  final ValueNotifier<List<dynamic>> editTrackWords = ValueNotifier<List<dynamic>>([]); // Single source of truth for auth state
  final isLoggedIn = ValueNotifier<bool>(false);
  final userPhone = ValueNotifier<String?>(null);
  final userUid = ValueNotifier<String?>(null);
  final a2hsCount = ValueNotifier<int>(0);
  final targetVideo = ValueNotifier<String?>(null);
  final savedClips = ValueNotifier<List<String>>([]);

  // Global Admin State
  final isAdmin = ValueNotifier<bool>(false);
  StreamSubscription<DocumentSnapshot>? _adminSub;

  void setNavIndex(int index) => navIndex.value = index;

  int authAttempts = 0;
  final lockoutSeconds = ValueNotifier<int>(0);
  Timer? _penaltyTimer;
  StreamSubscription<DocumentSnapshot>? _loginSub;

  Future<String> executeWhatsAppLogin(String phone, String botNumber) async {
    if (phone.length < 9) throw Exception('Invalid phone number');

    // 1. Generate the code
    String authCode = generateSecureToken();

    // 2. Start listening for the token (Non-blocking)
    _loginSub?.cancel();
    _loginSub = FirebaseFirestore.instance
        .collection('auth_tokens')
        .doc(authCode)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists && snapshot.data()?['token'] != null) {
        _loginSub?.cancel();
        try {
          await FirebaseAuth.instance.signInWithCustomToken(snapshot.data()!['token']);
          userPhone.value = phone;
          isLoggedIn.value = true;
          await FirebaseFirestore.instance.collection('auth_tokens').doc(authCode).delete();
          await savePhone(phone);
        } catch (e) {
          debugPrint("Custom Token Login Failed: $e");
        }
      }
    });

    // 3. Return the code instantly to update the UI
    return authCode;
  }
  String generateSecureToken() {
    const chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    final rnd = Random.secure();
    return String.fromCharCodes(Iterable.generate(20, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  Future<VerificationResult> processPhoneAuth(String phone, Map<String, dynamic> tabData) async {
    if (phone.length < 9) throw Exception('Invalid phone number');

    User? fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser == null) {
      try {
        final cred = await FirebaseAuth.instance.signInAnonymously();
        fbUser = cred.user;
      } catch (e) {
        debugPrint("Error generating anonymous session: $e");
      }
    }
    final currentFbUid = fbUser?.uid;

    String uid = generateSecureToken();
    int a2hsCount = 0;
    bool isThisDeviceAllowed = false;

    // 🎯 NOTE: Unauthenticated reads are blocked in your new rules, so this get() will
    // gracefully fail for new users, which flows smoothly into the Make.com creation below.
    try {
      final doc = await FirebaseFirestore.instance.collection('citizens').doc(phone).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        uid = data['uid'] ?? uid;
        a2hsCount = data['a2hs_count'] ?? 0;

        final allowedDevices = data['allowed_devices'] as Map<String, dynamic>?;
        if (allowedDevices != null && currentFbUid != null && allowedDevices[currentFbUid] == true) {
          isThisDeviceAllowed = true;
        }
      }
    } catch (e) {
      debugPrint("Read shielded by rules. Proceeding to new user flow.");
    }

    if (isThisDeviceAllowed) {
      await savePhone(phone);
      return VerificationResult(isAlreadyVerified: true, phone: phone, uid: uid);
    }

    String authCode = generateSecureToken();
    final String generatedPublicId = generateSecureToken(); // 🎯 Generate ID here

    final payload = {
      'phone': phone,
      'uid': uid,
      'a2hs_count': a2hsCount,
      'auth_code': authCode,
      'public_id': generatedPublicId, // 🎯 Pass ID to Make
      if (currentFbUid != null) 'pending_uid': currentFbUid,
      ...tabData,
    };

    // 🎯 SERVER ARCHITECTURE: Hand the secondary payload to Make.com instead of Firestore
    try {
      await http.post(
        Uri.parse('https://hook.eu1.make.com/77do2nwi2q6xmhko0vgucg2y235w47qg'), // 🚨 PASTE YOUR URL HERE
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } catch (e) {
      debugPrint("Make.com Webhook Error: $e");
    }

    return VerificationResult(
      isAlreadyVerified: false,
      phone: phone,
      uid: uid,
      authCode: authCode,
    );
  }

  void registerAuthAttempt() {
    authAttempts++;
    if (authAttempts >= 3) {
      lockoutSeconds.value = 60;
      authAttempts = 0;

      _penaltyTimer?.cancel();
      _penaltyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (lockoutSeconds.value > 0) {
          lockoutSeconds.value--;
        } else {
          timer.cancel();
        }
      });
    }
  }

  void initAdminListener() {
    FirebaseAuth.instance.authStateChanges().listen((fbUser) {
      _adminSub?.cancel();

      if (fbUser == null) {
        debugPrint("🚨 ADMIN CHECK: No Firebase User found.");
        isAdmin.value = false;
        return;
      }

      debugPrint("🚨 ADMIN CHECK: Searching Firestore for UID: ${fbUser.uid}");

      _adminSub = FirebaseFirestore.instance
          .collection('admins')
          .doc(fbUser.uid)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          debugPrint("🚨 ADMIN CHECK: Success! Document found.");
          isAdmin.value = snapshot.data()!['isAdmin'] == true;
        } else {
          debugPrint("🚨 ADMIN CHECK: FAILED. No document exists for ${fbUser.uid}");
          isAdmin.value = false;
        }
      }, onError: (e) {
        debugPrint("🚨 ADMIN CHECK: Stream error: $e");
        isAdmin.value = false;
      });
    });
  }

  Future<void> bootCheck() async {
    initAdminListener();
    try {
      final uri = Uri.base;
      if (uri.queryParameters.containsKey('vid')) {
        targetVideo.value = uri.queryParameters['vid'];
        navIndex.value = 0;
      }

      final prefs = await SharedPreferences.getInstance();
      final savedPhone = prefs.getString('phone');

      if (savedPhone != null && savedPhone.isNotEmpty) {
        final doc = await FirebaseFirestore.instance.collection('citizens').doc(savedPhone).get();

        if (doc.exists) {
          final data = doc.data()!;
          var v = data['verified'];

          if (v == true || v == 'true') {
            userPhone.value = savedPhone;
            userUid.value = data['uid'];
            a2hsCount.value = data['a2hs_count'] ?? 0;

            if (data.containsKey('saved_clips') && data['saved_clips'] != null) {
              List<dynamic> rawClips = data['saved_clips'];
              savedClips.value = rawClips.map((e) => e.toString()).toList();
            } else {
              savedClips.value = [];
            }

            isLoggedIn.value = true;
            return;
          }
        } else {
          await clearSession();
        }
      }
    } catch (e) {
      debugPrint("Boot Check Error: $e");
    }
  }

  Future<void> savePhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('phone', phone);
    userPhone.value = phone;

    try {
      final doc = await FirebaseFirestore.instance.collection('citizens').doc(phone).get();
      if (doc.exists) {
        final data = doc.data()!;
        final String? fetchedUid = data['uid'];
        if (fetchedUid != null) {
          userUid.value = fetchedUid;
          await prefs.setString('uid', fetchedUid);
        }
        a2hsCount.value = data['a2hs_count'] ?? 0;
      }
    } catch (e) {
      debugPrint("Error fetching metadata on savePhone: $e");
    }

    isLoggedIn.value = true;
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('phone');
    await prefs.remove('uid');

    userPhone.value = null;
    userUid.value = null;
    a2hsCount.value = 0;
    isLoggedIn.value = false;
    savedClips.value = [];

    isAdmin.value = false;
    _adminSub?.cancel();
  }

  Future<void> markA2HSPrompted(String phone) async {
    a2hsCount.value = 1;
    if (phone.isNotEmpty) {
      try {
        // 🎯 Changed from set() to update() to comply with strict new rules
        await FirebaseFirestore.instance.collection('citizens').doc(phone).update({
          'a2hs_count': 1,
        });
      } catch (e) {
        debugPrint("Error updating a2hs_count in DB: $e");
      }
    }
  }
}

Future<void> setupLocator() async {
  final appState = AppState();
  await appState.bootCheck();
  di.registerSingleton<AppState>(appState);
}

Future<void> showUniversalAuthSheet(BuildContext context) async {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    barrierColor: Colors.black.withOpacity(0.85),
    backgroundColor: const Color(0xFF0F172A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
    ),
    builder: (context) => const UniversalAuthSheet(),
  );
}

class UniversalAuthSheet extends StatefulWidget {
  const UniversalAuthSheet({super.key});

  @override
  State<UniversalAuthSheet> createState() => _UniversalAuthSheetState();
}

class _UniversalAuthSheetState extends State<UniversalAuthSheet> {
  final TextEditingController _phoneController = TextEditingController();
  String? _pendingPhone;
  String? _authCode;
  String? _completePhoneNumber;

  @override
  void initState() {
    super.initState();
    di<AppState>().isLoggedIn.addListener(_checkAutoClose);
  }

  void _checkAutoClose() {
    if (mounted && di<AppState>().isLoggedIn.value) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    di<AppState>().isLoggedIn.removeListener(_checkAutoClose);
    _phoneController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: Colors.blueAccent,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: ValueListenableBuilder<bool>(
          valueListenable: di<AppState>().isLoggedIn,
          builder: (context, isLoggedIn, child) {

            if (_pendingPhone != null && _authCode != null) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 30,
                  top: 30, left: 30, right: 30,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.lock_outline, size: 80, color: Colors.orangeAccent),
                    const SizedBox(height: 20),
                    Text("verifyAccountTitle".tr(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 15),
                    Text("tapToAuthenticate".tr(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 16, height: 1.4)),
                    const SizedBox(height: 40),

                    ValueListenableBuilder<int>(
                      valueListenable: di<AppState>().lockoutSeconds,
                      builder: (context, secondsLeft, child) {
                        final bool isLocked = secondsLeft > 0;
                        return ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isLocked ? Colors.redAccent.shade700 : const Color(0xFF25D366),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          icon: Icon(isLocked ? Icons.timer : Icons.chat_bubble_outline, color: !isLocked ? const Color(0xff010126) : Colors.white),
                          label: Text(
                            isLocked ? "${'verify_locked_btn'.tr()}${secondsLeft.toString().padLeft(2, '0')}" : "verify_whatsapp_btn".tr(),
                            style: TextStyle(color: !isLocked ? const Color(0xff010126) : Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          onPressed: isLocked ? () {
                            _showError("verify_toast_locked".tr());
                          } : () async {
                            di<AppState>().registerAuthAttempt();
                            const burnerPhone = "972525822005";
                            String instruction = "whatsappVerifyMsg".tr();
                            String whatsappMessage = "$_authCode $instruction";
                            String encodedMessage = Uri.encodeComponent(whatsappMessage);
                            final url = Uri.parse("https://wa.me/$burnerPhone?text=$encodedMessage");
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 15),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _pendingPhone = null;
                          _authCode = null;
                          _phoneController.clear();
                          _completePhoneNumber = null;
                        });
                      },
                      child: Text("change_phone_btn".tr(), style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 30,
                  top: 30, left: 30, right: 30,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 80, height: 80,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(Icons.shield, size: 80, color: Colors.blueAccent),
                          const Positioned(top: 18, child: MagenDavid(size:40, color: Colors.white, strokeWidth: 3.0)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text("map_dialog_title".tr(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 15),
                    Text("map_verification_subtitle".tr(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 16, height: 1.4)),
                    const SizedBox(height: 40),

                    Directionality(
                      textDirection: ui.TextDirection.ltr,
                      child: IntlPhoneField(
                        controller: _phoneController,
                        initialCountryCode: 'IL',
                        keyboardType: TextInputType.phone,
                        keyboardAppearance: Brightness.dark,
                        style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 2),
                        textAlign: TextAlign.left,
                        dropdownTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
                        dropdownIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        decoration: InputDecoration(
                          hintText: "capture_hint".tr(),
                          hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5), fontSize: 16, letterSpacing: 0),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none
                          ),
                          counterText: "",
                        ),
                        onChanged: (phone) {
                          _completePhoneNumber = phone.completeNumber.replaceAll('+', '');
                        },
                      ),
                    ),

                    const SizedBox(height: 30),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text("map_verify_action_btn".tr(), style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      onPressed: () async {
                        FocusScope.of(context).unfocus();

                        String contactInfo = _completePhoneNumber ?? '';
                        if (contactInfo.length < 9) {
                          _showError("capture_error_phone".tr());
                          return;
                        }

                        try {
                          String generatedCode = await di<AppState>().executeWhatsAppLogin(contactInfo, '972525822005');

                          setState(() {
                            _pendingPhone = contactInfo;
                            _authCode = generatedCode;
                          });
                        } catch (e) {
                          _showError("map_err_save".tr());
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class MagenDavid extends StatelessWidget {
  final double size;
  final Color color;
  final double strokeWidth;

  const MagenDavid({
    super.key,
    this.size = 80,
    this.color = Colors.white,
    this.strokeWidth = 4.5,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CustomPaint(
        size: Size(size, size),
        painter: _MagenDavidPainter(color: color, strokeWidth: strokeWidth),
      ),
    );
  }
}

class _MagenDavidPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _MagenDavidPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = (size.width < size.height ? size.width : size.height) / 2 - strokeWidth;

    const sin30 = 0.5;
    const cos30 = 0.8660254;

    final path1 = Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r * cos30, cy + r * sin30)
      ..lineTo(cx - r * cos30, cy + r * sin30)
      ..close();

    final path2 = Path()
      ..moveTo(cx, cy + r)
      ..lineTo(cx - r * cos30, cy - r * sin30)
      ..lineTo(cx + r * cos30, cy - r * sin30)
      ..close();

    canvas.drawPath(path1, paint);
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}