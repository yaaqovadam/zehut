import 'package:flutter/foundation.dart';
import 'package:watch_it/watch_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class AppState {
  final navIndex = ValueNotifier<int>(0);

  // Single source of truth for auth state
  final isLoggedIn = ValueNotifier<bool>(false);
  final userPhone = ValueNotifier<String?>(null);
  final userUid = ValueNotifier<String?>(null);
  final a2hsCount = ValueNotifier<int>(0);
  final targetVideo = ValueNotifier<String?>(null);
  final savedClips = ValueNotifier<List<String>>([]);

  void setNavIndex(int index) => navIndex.value = index;

  int authAttempts = 0;
  final lockoutSeconds = ValueNotifier<int>(0);
  Timer? _penaltyTimer;

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

  // BOOT CHECK: Reads phone from prefs -> queries Firestore -> validates verification
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

          // Strict check for boolean true or string 'true'
          if (v == true || v == 'true') {
            userPhone.value = cleanPhone;
            userUid.value = data['uid'];
            a2hsCount.value = data['a2hs_count'] ?? 0;

            // Safely hydrate saved clips
            if (data.containsKey('saved_clips') && data['saved_clips'] != null) {
              List<dynamic> rawClips = data['saved_clips'];
              savedClips.value = rawClips.map((e) => e.toString()).toList();
            } else {
              savedClips.value = [];
            }

            isLoggedIn.value = true; // 🔥 THIS IS WHAT GOT DELETED
            return; // SUCCESS: EXIT HERE
          }
        } else {
          // Document was physically deleted from DB
          await clearSession();
        }
      }
    } catch (e) {
      debugPrint("Boot Check Error: $e");
      // CRITICAL FIX: Do NOT clearSession() here. If Firebase is offline or loading late,
      // wiping the cache destroys the user's permanent login!
    }
  }

  // SAVE PHONE: Centralized handler called upon successful verification OR successful bypass
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
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('phone');
    await prefs.remove('uid');

    userPhone.value = null;
    userUid.value = null;
    a2hsCount.value = 0;
    isLoggedIn.value = false;
    savedClips.value=[];
  }

  Future<void> markA2HSPrompted(String phone) async {
    a2hsCount.value = 1; // Sync local state
    if (phone.isNotEmpty) {
      final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      try {
        await FirebaseFirestore.instance.collection('citizens').doc(cleanPhone).set({
          'a2hs_count': 1, // Set strict DB flag to 1
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