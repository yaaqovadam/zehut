import 'dart:math';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:watch_it/watch_it.dart';

// import '../app_state.dart';


// Color topAndBottomNavigationBarColor= Color(0xFF1f1a54);
const Color topAndBottomNavigationBarColor = Color(0xFF103856);
String generateSecureToken() {
  const chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  final rnd = Random.secure();
  return String.fromCharCodes(Iterable.generate(20, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
}



void logit(s) => print('🇮🇱🇮🇱🇮🇱REG LOG-🇮🇱🇮🇱🇮🇱 ::️️ $s️');

void titleit(s) => print('💧💧💧-TITLE--💧💧💧 ::️️ $s');

void noticeit(s) => print('🔥🔥🔥-NOTICE-🔥🔥🔥 ::️️ $s');

void specialit(s) => print('🔮🔮🔮SPECIAL-🔮🔮🔮 ::️️ $s');
//🦄☂️🔮💜✡️🕎🇮🇱
void errit(error) => print('⛔‼️️⛔️️--ERROR-⛔‼️️⛔️️ :: ${error.toString()}');

void successit(error) => print('✅✅✅-SUCCESS✅✅✅ :: ${error.toString()}');

void trueit(error) => print('💧👍🏻💧-TRUE💧👍🏻💧 :: \n          ${error.toString()}');

void falseit(error) => print('‼️🔥‼️-FALSE‼️🔥‼️ :: \n         ${error.toString()}');

var errir = errit;
var labelit = titleit;


Future<bool> verifyAdminAccess(String userPhoneNumber) async {
  try {
    // Looks up the specific phone number document in the 'admins' collection
    DocumentSnapshot adminDoc = await FirebaseFirestore.instance
        .collection('admins')
        .doc(userPhoneNumber)
        .get();

    // Checks if the document exists and if the 'isAdmin' field is true
    if (adminDoc.exists) {
      final data = adminDoc.data() as Map<String, dynamic>;
      return data['isAdmin'] == true;
    }

    return false; // Returns false if the phone number isn't in the collection
  } catch (e) {
    errit("Error checking admin status: $e");
    return false;
  }
}