import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:watch_it/watch_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';


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

  // Single source of truth for auth state
  final isLoggedIn = ValueNotifier<bool>(false);
  final userPhone = ValueNotifier<String?>(null);
  final userUid = ValueNotifier<String?>(null);
  final a2hsCount = ValueNotifier<int>(0);
  final targetVideo = ValueNotifier<String?>(null);
  final savedClips = ValueNotifier<List<String>>([]);

  // 🎯 NEW: Global Admin State
  final isAdmin = ValueNotifier<bool>(false);
  StreamSubscription<DocumentSnapshot>? _adminSub;

  void setNavIndex(int index) => navIndex.value = index;

  int authAttempts = 0;
  final lockoutSeconds = ValueNotifier<int>(0);
  Timer? _penaltyTimer;
  String generateSecureToken() {
    return const Uuid().v4();
  }



// The master funnel for all 4 entry points
  Future<VerificationResult> processPhoneAuth(String rawPhone, Map<String, dynamic> tabData) async {
    String phone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.length < 9) throw Exception('Invalid phone number');

    String uid = generateSecureToken();
    int a2hsCount = 0;
    bool isVerified = false;

    final doc = await FirebaseFirestore.instance.collection('citizens').doc(phone).get();

    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      uid = data['uid'] ?? uid;
      a2hsCount = data['a2hs_count'] ?? 0;
      isVerified = (data['verified'] == true || data['verified'] == 'true');
    }

    // Merge the core user data with whatever specific tab data (map pin, quiz score) was passed in
    final payload = {
      'phone': phone,
      'uid': uid,
      'a2hs_count': a2hsCount,
      ...tabData,
    };

    if (isVerified) {
      await FirebaseFirestore.instance.collection('citizens').doc(phone).set(payload, SetOptions(merge: true));
      await savePhone(phone);
      return VerificationResult(isAlreadyVerified: true, phone: phone, uid: uid);
    }

    // If new or unverified, generate the WhatsApp code and wait
    String authCode = generateSecureToken();
    payload['auth_code'] = authCode;
    payload['verified'] = false;

    await FirebaseFirestore.instance.collection('citizens').doc(phone).set(payload, SetOptions(merge: true));

    return VerificationResult(
        isAlreadyVerified: false,
        phone: phone,
        uid: uid,
        authCode: authCode
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



  // 🎯 NEW: Attaches a real-time listener to the user's admin document
  void _listenToAdminStatus(String phone) {
    _adminSub?.cancel(); // Cancel any existing listener
    _adminSub = FirebaseFirestore.instance
        .collection('admins')
        .doc(phone)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        isAdmin.value = data['isAdmin'] == true;
      } else {
        isAdmin.value = false;
      }
    }, onError: (e) {
      debugPrint("Admin stream error: $e");
      isAdmin.value = false;
    });
  }

  // BOOT CHECK
  Future<void> bootCheck() async {
    try {
      final uri = Uri.base;
      if (uri.queryParameters.containsKey('vid')) {
        targetVideo.value = uri.queryParameters['vid'];
        navIndex.value = 0;
      }

      final prefs = await SharedPreferences.getInstance();
      final savedPhone = prefs.getString('phone');

      if (savedPhone != null && savedPhone.isNotEmpty) {
        final cleanPhone = savedPhone.replaceAll(RegExp(r'[^0-9]'), '');
        final doc = await FirebaseFirestore.instance.collection('citizens').doc(cleanPhone).get();

        if (doc.exists) {
          final data = doc.data()!;
          var v = data['verified'];

          if (v == true || v == 'true') {
            userPhone.value = cleanPhone;
            userUid.value = data['uid'];
            a2hsCount.value = data['a2hs_count'] ?? 0;

            if (data.containsKey('saved_clips') && data['saved_clips'] != null) {
              List<dynamic> rawClips = data['saved_clips'];
              savedClips.value = rawClips.map((e) => e.toString()).toList();
            } else {
              savedClips.value = [];
            }

            isLoggedIn.value = true;

            // 🎯 Start listening for admin changes immediately on boot
            _listenToAdminStatus(cleanPhone);
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



  // SAVE PHONE
  Future<void> savePhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('phone', cleanPhone);
    userPhone.value = cleanPhone;

    try {
      final doc = await FirebaseFirestore.instance.collection('citizens').doc(cleanPhone).get();
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

    // 🎯 Start listening for admin changes on fresh login
    _listenToAdminStatus(cleanPhone);
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

    // 🎯 Wipe admin privileges and kill the database listener
    isAdmin.value = false;
    _adminSub?.cancel();
  }

  Future<void> markA2HSPrompted(String phone) async {
    a2hsCount.value = 1;
    if (phone.isNotEmpty) {
      final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      try {
        await FirebaseFirestore.instance.collection('citizens').doc(cleanPhone).set({
          'a2hs_count': 1,
        }, SetOptions(merge: true));
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
