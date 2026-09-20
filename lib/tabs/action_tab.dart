import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:watch_it/watch_it.dart';

import '../common/common.dart';
import '../app_state.dart';

class ActionTab extends StatefulWidget {
  const ActionTab({super.key});

  @override
  State<ActionTab> createState() => _ActionTabState();
}

class _ActionTabState extends State<ActionTab> {
  final MapController _mapController = MapController();
  final LatLng _centerIsrael = const LatLng(31.5, 34.8);

  Stream<QuerySnapshot>? _pinsStream;
  String selectedStatus = "armed";
  String? _pendingPhone;
  String? _authCode;
  final TextEditingController _phoneController = TextEditingController();
  bool _isMapMoved = false;
  bool _hasSavedPin = false;

  @override
  void initState() {
    super.initState();
    _pinsStream = FirebaseFirestore.instance.collection('public_pins').snapshots();
    _initInitialMapPosition();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initInitialMapPosition() async {
    if (di<AppState>().isLoggedIn.value) {
      String? uid = di<AppState>().userUid.value;

      if (uid != null) {
        try {
          DocumentSnapshot doc = await FirebaseFirestore.instance.collection('public_pins').doc(uid).get();
          if (doc.exists) {
            var data = doc.data() as Map<String, dynamic>?;
            if (data != null && data.containsKey('lat') && data.containsKey('lng')) {
              double lat = data['lat'];
              double lng = data['lng'];
              if (data.containsKey('map_status')) {
                selectedStatus = data['map_status'];
              }
              if (mounted) {
                setState(() {
                  _hasSavedPin = true;
                });
                _mapController.move(LatLng(lat, lng), 15.0);
              }
              return;
            }
          }
        } catch (e) {
          // Fallback
        }
      }
    }
    _initUserLocation();
  }

  Future<void> _initUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        _mapController.move(LatLng(position.latitude, position.longitude), 15.0);
      }
    } catch (e) {
      // Fallback
    }
  }

  Future<void> _resetToGeolocation() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.amber)),
    );

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted)  Navigator.pop(context);
      _showError("map_err_service".tr());
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted)   Navigator.pop(context);
        _showError("map_err_permission".tr());
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted)  Navigator.pop(context);
      _showError("map_err_blocked".tr());
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        Navigator.pop(context);
        _mapController.move(LatLng(position.latitude, position.longitude), 15.0);
        setState(() {
          _isMapMoved = true;
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showError("map_err_save".tr());
      }
    }
  }

  void _showPinDialog(LatLng latLng) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              insetPadding: EdgeInsets.zero,
              titlePadding: EdgeInsets.zero,
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 15),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(top: 4, right: 4, left: 4),
                        child: IconButton(
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(),
                          icon: const Text("X", style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold)),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                  Center(
                    child: Text(
                      "map_dialog_title".tr(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<String>(
                      title: Text("map_dialog_status_armed".tr(), style: const TextStyle(color: Colors.white, fontSize: 14)),
                      value: "armed",
                      groupValue: selectedStatus,
                      activeColor: Colors.amber,
                      onChanged: (val) => setDialogState(() => selectedStatus = val!),
                    ),
                    RadioListTile<String>(
                      title: Text("map_dialog_status_unarmed".tr(), style: const TextStyle(color: Colors.white, fontSize: 14)),
                      value: "unarmed",
                      groupValue: selectedStatus,
                      activeColor: Colors.redAccent,
                      onChanged: (val) => setDialogState(() => selectedStatus = val!),
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    if (di<AppState>().isLoggedIn.value) {
                      String? globalUid = di<AppState>().userUid.value;
                      if (globalUid != null) {
                        await _savePinToFirebase(latLng, globalUid);
                      }
                    } else {
                      _showVerificationBottomSheet(latLng);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                  child: Text("map_dialog_btn".tr(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                )
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _savePinToFirebase(LatLng latLng, String masterUid) async {
    try {
      await FirebaseFirestore.instance.collection('public_pins').doc(masterUid).set({
        'map_status': selectedStatus,
        'lat': latLng.latitude,
        'lng': latLng.longitude,
        'timestamp_map': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _isMapMoved = false;
        _hasSavedPin = true;
      });
    } catch (e) {
      _showError("map_err_save".tr());
    }
  }

  Future<void> _showA2HSBottomSheet() async {
    if (di<AppState>().a2hsCount.value > 0) return;
    if (!mounted) return; // Use the immortal state context check

    // 1. SHOW THE BOTTOM SHEET FIRST
    showModalBottomSheet(
      context: context, // Use the active state context
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.85),
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext modalContext) {
        return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    'icons/Icon-192.png',
                    width: 72,
                    height: 72,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.shield, size: 72, color: Colors.blueAccent),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "התנתק מהדפדפן. הישאר מחובר לרשת.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                "הוסף את 'זהות' למסך הבית שלך לגישה מהירה, מוצפנת וללא צנזורה - בדיוק כמו אפליקציה רגילה.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Column(
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.ios_share, color: Colors.amber, size: 22),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "1. לחץ על כפתור השיתוף (Share) בדפדפן",
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.add_box_outlined, color: Colors.amber, size: 22),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "2. בחר 'אל מסך הבית' (Add to Home Screen)",
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text(
                  "הבנתי, המשך לאפליקציה",
                  style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: () => Navigator.pop(modalContext),
              ),
            ],
          ),
            ),
        );
      },
    );

    // 2. INCREMENT THE COUNTER AFTER THE SHEET IS RENDERED
    String? phone = di<AppState>().userPhone.value;
    if (phone != null && phone.isNotEmpty) {
      di<AppState>().markA2HSPrompted(phone); // No await, runs in background
    }
  }

  void _showVerificationBottomSheet(LatLng latLng) {
    setState(() {
      _pendingPhone = null;
      _authCode = null;
      _phoneController.clear();
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.85),
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext bottomSheetContext) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: StatefulBuilder(
            builder: (statefulContext, setModalState) {

              // --- PHASE 2: THE WHATSAPP TRAP ---
              if (_pendingPhone != null && _authCode != null) {
                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('citizens').doc(_pendingPhone).snapshots(),
                  builder: (streamContext, snapshot) {
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final Map<String, dynamic>? data = snapshot.data!.data() as Map<String, dynamic>?;

                      var v = data?['verified'];
                      if (data != null && (v == true || v == 'true') && _pendingPhone != null) {

                        final String verifiedPhone = _pendingPhone!;
                        String masterUid = FirebaseAuth.instance.currentUser?.uid ?? '';

                        WidgetsBinding.instance.addPostFrameCallback((_) async {
                          if (_pendingPhone == null) return;

                          setState(() {
                            _pendingPhone = null;
                            _authCode = null;
                          });

                          // Pop WhatsApp UI immediately so it's out of the way
                          Navigator.of(bottomSheetContext).pop();

                          await di<AppState>().savePhone(verifiedPhone);
                          await _savePinToFirebase(latLng, masterUid);

                          if (mounted) {
                            Future.delayed(const Duration(milliseconds: 400), () {
                              if (mounted) {
                                _showA2HSBottomSheet();
                              }
                            });
                          }
                        });
                      }
                    }

                    return GestureDetector(
                      onTap: () {},
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(statefulContext).viewInsets.bottom + 30,
                            top: 30,
                            left: 30,
                            right: 30,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Icon(Icons.lock_outline, size: 80, color: Colors.orangeAccent),
                              const SizedBox(height: 20),
                              Text(
                                "verifyAccountTitle".tr(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 15),
                              Text(
                                "tapToAuthenticate".tr(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey, fontSize: 16, height: 1.4),
                              ),
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
                                    icon: Icon(
                                      isLocked ? Icons.timer : Icons.chat_bubble_outline,
                                      color: !isLocked ? const Color(0xff010126) : Colors.white,
                                    ),
                                    label: Text(
                                      isLocked
                                          ? "${'verify_locked_btn'.tr()}${secondsLeft.toString().padLeft(2, '0')}"
                                          : "verify_whatsapp_btn".tr(),
                                      style: TextStyle(color: !isLocked ? const Color(0xff010126) : Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: isLocked ? () {
                                      _showTopToast(statefulContext, "verify_toast_locked".tr());
                                    } : () async {
                                      di<AppState>().registerAuthAttempt();
                                      const burnerPhone = "972525822005";
                        
                                      // 1. Grab the localized string
                                      String instruction = "whatsappVerifyMsg".tr();
                        
                                      // 2. Build string: Code + EXACTLY ONE SPACE + Instruction
                                      String whatsappMessage = "$_authCode $instruction";
                        
                                      // 3. Encode to prevent URL breaking
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
                                  setModalState(() {
                                    setState(() {
                                      _pendingPhone = null;
                                      _authCode = null;
                                      _phoneController.clear();
                                    });
                                  });
                                },
                                child: Text(
                                  "change_phone_btn".tr(),
                                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              }

              // --- PHASE 1: INITIAL PHONE HARVEST ---
              return GestureDetector(
                onTap: () {},
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(statefulContext).viewInsets.bottom + 30,
                    top: 30,
                    left: 30,
                    right: 30,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.shield, size: 80, color: Colors.blueAccent),
                      const SizedBox(height: 20),
                      Text(
                        "map_dialog_title".tr(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        "map_verification_subtitle".tr(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey, fontSize: 16, height: 1.4),
                      ),
                      const SizedBox(height: 40),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        keyboardAppearance: Brightness.dark,
                        style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 2),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: "capture_hint".tr(),
                          hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5), fontSize: 16, letterSpacing: 0),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                          prefixIcon: const Icon(Icons.phone_android, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(statefulContext).primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "map_verify_action_btn".tr(),
                            style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        onPressed: () async {
                          FocusScope.of(statefulContext).unfocus();
                          String contactInfo = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');

                          if (contactInfo.length < 9) {
                            _showError("capture_error_phone".tr());
                            return;
                          }

                          try {
                            final result = await di<AppState>().processPhoneAuth(
                              contactInfo,
                              {
                                'map_status': selectedStatus,
                                'timestamp_map': FieldValue.serverTimestamp(),
                              },
                            );

                            if (result.isAlreadyVerified) {
                              Navigator.of(bottomSheetContext).pop();
                              await _savePinToFirebase(latLng, result.uid);

                              if (mounted) {
                                Future.delayed(const Duration(milliseconds: 400), () {
                                  if (mounted) _showA2HSBottomSheet();
                                });
                              }
                            } else {
                              setModalState(() {
                                setState(() {
                                  _pendingPhone = result.phone;
                                  _authCode = result.authCode;
                                });
                              });
                            }
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
        );
      },
    );
  }

  void _showTopToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 150,
          left: 20,
          right: 20,
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return; // <-- Add this shield
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _centerIsrael,
              initialZoom: 7.0,
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture && !_isMapMoved && _hasSavedPin) {
                  setState(() {
                    _isMapMoved = true;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                // 👇 Changed dark_all to light_all
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              StreamBuilder<QuerySnapshot>(
                stream: _pinsStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const MarkerLayer(markers: []);

                  String? currentUid = di<AppState>().userUid.value;

                  List<Marker> activeMarkers = [];
                  for (var doc in snapshot.data!.docs) {
                    var data = doc.data() as Map<String, dynamic>;
                    if (data['lat'] == null || data['lng'] == null) continue;

                    bool isSelf = (currentUid != null && doc.id == currentUid);
                    bool isArmed = data['map_status'] == 'armed';

                    activeMarkers.add(
                      Marker(
                        point: LatLng(data['lat'], data['lng']),
                        width: 45,
                        height: 45,
                        child: Icon(
                          Icons.location_on,
                          size: isSelf ? 46 : 40,
                          color: isSelf
                              ? const Color(0xFF103856) // Dark blue for the user's own pin
                              : (isArmed ? Colors.lightBlue : Colors.redAccent),
                        ),
                      ),
                    );
                  }
                  return MarkerLayer(markers: activeMarkers);
                },
              ),
            ],
          ),
          if (_isMapMoved)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Icon(
                  Icons.location_on,
                  size: 45,
                  // 👇 Update this to match the new logic
                  color: selectedStatus == 'armed' ? Colors.lightBlue : Colors.redAccent,
                ),
              ),
            ),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1f1a54).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.5)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "map_title".tr(),
                        style: TextStyle(fontSize: Localizations.localeOf(context).languageCode == 'en' ?21:24, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "map_subtitle".tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: Localizations.localeOf(context).languageCode == 'en' ? 11: 14.0,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 30, left: 20, right: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            LatLng currentCenter = _mapController.camera.center;
                            if (_isMapMoved) {
                              if (di<AppState>().isLoggedIn.value) {
                                String? globalUid = di<AppState>().userUid.value;
                                if (globalUid != null) {
                                  await _savePinToFirebase(currentCenter, globalUid);
                                }
                              } else {
                                _showVerificationBottomSheet(currentCenter);
                              }
                            } else {
                              _showPinDialog(currentCenter);
                            }
                          },
                          icon: Icon(
                            _isMapMoved ? Icons.save : (_hasSavedPin ? Icons.shield : Icons.add_moderator),
                            color: Theme.of(context).primaryColor,
                            size: 33,
                          ),
                          label: Text(
                            _isMapMoved
                                ? "map_btn_save".tr()
                                : (_hasSavedPin ? "map_btn_edit_status".tr() : "map_btn_organize".tr()),
                            style: TextStyle(
                              color: _hasSavedPin ? Colors.lightBlue : Colors.white60,
                              fontSize: context.locale.languageCode == 'he' ? 18 : 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _hasSavedPin ? const Color(0xFF1f1a54) : Theme.of(context).primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 10,
                          ),
                        ),
                      ),
                      if (_isMapMoved) ...[
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: _resetToGeolocation,
                          icon: const Icon(Icons.my_location, color: Colors.amber, size: 18),
                          label: Text(
                            "map_btn_reset".tr(),
                            style: const TextStyle(color: Colors.amber, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}