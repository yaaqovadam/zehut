import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:watch_it/watch_it.dart';
import 'package:share_plus/share_plus.dart';
import '../app_state.dart';
import '../common/common.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../translations.dart';
import 'package:zehut_app/star_of_david_house.dart';

class HostMosheTab extends StatefulWidget {
  const HostMosheTab({super.key});

  @override
  State<HostMosheTab> createState() => _HostMosheTabState();
}

class _HostMosheTabState extends State<HostMosheTab> {
  String? selectedCity;
  bool isSubmitting = false;
  String _hostIntent = 'attend';
  final TextEditingController _cityController = TextEditingController();
  String? _lastLangCode;

  final List<Map<String, String>> citiesData = [
    {"en": "Zefat (Safed)", "he": "צפת"},
    {"en": "Jerusalem", "he": "ירושלים"},
    {"en": "Tel Aviv-Yafo", "he": "תל אביב-יפו"},
    {"en": "Haifa", "he": "חיפה"},
    {"en": "Rishon LeZion", "he": "ראשון לציון"},
    {"en": "Petah Tikva", "he": "פתח תקווה"},
    {"en": "Ashdod", "he": "אשדוד"},
    {"en": "Netanya", "he": "נתניה"},
    {"en": "Beersheba", "he": "באר שבע"},
    {"en": "Bnei Brak", "he": "בני ברק"},
    {"en": "Holon", "he": "חולון"},
    {"en": "Ramat Gan", "he": "רמת גן"},
    {"en": "Ashkelon", "he": "אשקלון"},
    {"en": "Rehovot", "he": "רחובות"},
    {"en": "Bat Yam", "he": "בת ים"},
    {"en": "Beit Shemesh", "he": "בית שמש"},
    {"en": "Kfar Saba", "he": "כפר סבא"},
    {"en": "Herzliya", "he": "הרצליה"},
    {"en": "Hadera", "he": "חדרה"},
    {"en": "Modi'in-Maccabim-Re'ut", "he": "מודיעין-מכבים-רעות"},
    {"en": "Nazareth", "he": "נצרת"},
    {"en": "Lod", "he": "לוד"},
    {"en": "Ramla", "he": "רמלה"},
    {"en": "Ra'anana", "he": "רעננה"},
    {"en": "Rahat", "he": "רהט"},
    {"en": "Modi'in Illit", "he": "מודיעין עילית"},
    {"en": "Hod HaSharon", "he": "הוד השרון"},
    {"en": "Givatayim", "he": "גבעתיים"},
    {"en": "Kiryat Ata", "he": "קריית אתא"},
    {"en": "Nahariya", "he": "נהריה"},
    {"en": "Beitar Illit", "he": "ביתר עילית"},
    {"en": "Umm al-Fahm", "he": "אום אל-פחם"},
    {"en": "Kiryat Gat", "he": "קריית גת"},
    {"en": "Eilat", "he": "אילת"},
    {"en": "Rosh HaAyin", "he": "ראש העין"},
    {"en": "Afula", "he": "עפולה"},
    {"en": "Nes Ziona", "he": "נס ציונה"},
    {"en": "Akko (Acre)", "he": "עכו"},
    {"en": "Elad", "he": "אלעד"},
    {"en": "Ramat HaSharon", "he": "רמת השרון"},
    {"en": "Karmiel", "he": "כרמיאל"},
    {"en": "Yavne", "he": "יבנה"},
    {"en": "Tiberias", "he": "טבריה"},
    {"en": "Tayibe", "he": "טייבה"},
    {"en": "Kiryat Motzkin", "he": "קריית מוצקין"},
    {"en": "Shfaram", "he": "שפרעם"},
    {"en": "Nof HaGalil", "he": "נוף הגליל"},
    {"en": "Kiryat Bialik", "he": "קריית ביאליק"},
    {"en": "Kiryat Ono", "he": "קריית אונו"},
    {"en": "Or Yehuda", "he": "אור יהודה"},
    {"en": "Ma'ale Adumim", "he": "מעלה אדומים"},
    {"en": "Kiryat Yam", "he": "קריית ים"},
    {"en": "Tamra", "he": "טמרה"},
    {"en": "Netivot", "he": "נתיבות"},
    {"en": "Sakhnin", "he": "סח'נין"},
    {"en": "Yehud-Monosson", "he": "יהוד-מונוסון"},
    {"en": "Baqa al-Gharbiyye", "he": "באקה אל-גרביה"},
    {"en": "Dimona", "he": "דימונה"},
    {"en": "Ofakim", "he": "אופקים"},
    {"en": "Sderot", "he": "שדרות"},
    {"en": "Tira", "he": "טירה"},
    {"en": "Arad", "he": "ערד"},
    {"en": "Migdal HaEmek", "he": "מגדל העמק"},
    {"en": "Kiryat Malakhi", "he": "קריית מלאכי"},
    {"en": "Kfar Qasim", "he": "כפר קאסם"},
    {"en": "Tirat Carmel", "he": "טירת כרמל"},
    {"en": "Kiryat Shmona", "he": "קריית שמונה"},
    {"en": "Qalansawe", "he": "קלנסווה"},
    {"en": "Yokneam Illit", "he": "יקנעם עילית"},
    {"en": "Ariel", "he": "אריאל"},
    {"en": "Mevaseret Zion", "he": "מבשרת ציון"},
    {"en": "Givat Shmuel", "he": "גבעת שמואל"},
    {"en": "Or Akiva", "he": "אור עקיבא"},
    {"en": "Kfar Yona", "he": "כפר יונה"},
    {"en": "Beit She'an", "he": "בית שאן"},
    {"en": "Ganei Tikva", "he": "גני תקווה"},
    {"en": "Pardes Hanna-Karkur", "he": "פרדס חנה-כרכור"},
    {"en": "Zikhron Ya'akov", "he": "זכרון יעקב"},
    {"en": "Even Yehuda", "he": "אבן יהודה"},
    {"en": "Gedera", "he": "גדרה"},
    {"en": "Kadima-Zoran", "he": "קדימה-צורן"},
    {"en": "Tel Mond", "he": "תל מונד"},
    {"en": "Katzrin", "he": "קצרין"},
    {"en": "Rosh Pinna", "he": "ראש פינה"},
    {"en": "Metula", "he": "מטולה"},
    {"en": "Mitzpe Ramon", "he": "מצפה רמון"},
    {"en": "Jericho", "he": "יריחו"},
  ];

  @override
  void initState() {
    super.initState();
    _cityController.addListener(() {
      final text = _cityController.text.trim();
      if (text != selectedCity) {
        setState(() {
          selectedCity = text;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final String currentLang = context.locale.languageCode;
    final bool isHe = currentLang == 'he';

    if (_lastLangCode == null) {
      _lastLangCode = currentLang;
      final String? urlCity = Uri.base.queryParameters['city']?.trim();
      if (urlCity != null && urlCity.isNotEmpty) {
        selectedCity = urlCity;
        _cityController.text = urlCity;
      } else {
        final String defaultSafed = isHe ? "צפת" : "Zefat (Safed)";
        selectedCity = defaultSafed;
        _cityController.text = defaultSafed;
      }
    } else if (_lastLangCode != currentLang) {
      _lastLangCode = currentLang;
      if (selectedCity != null && selectedCity!.isNotEmpty) {
        for (final city in citiesData) {
          if (city['en'] == selectedCity || city['he'] == selectedCity) {
            final String translated = isHe ? city['he']! : city['en']!;
            selectedCity = translated;
            _cityController.text = translated;
            break;
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _shareHostMoshe({required bool includeCity}) async {
    final bool isHe = context.locale.languageCode == 'he';
    final String currentCity = (selectedCity ?? _cityController.text).trim();
    final bool useSpecificCity = includeCity && currentCity.isNotEmpty;

    final String encodedCity = useSpecificCity ? Uri.encodeComponent(currentCity) : '';
    final String shareUrl = useSpecificCity
        ? "https://gamfeiglintzadak.co.il/parlor-meetings.html?city=$encodedCity&v=99"
        : "https://gamfeiglintzadak.co.il/parlor-meetings.html?v=99";

    final String shareText = isHe
        ? (useSpecificCity
            ? "רוצים להביא את משה פייגלין לחוג בית ב$currentCity! רוצים לארח או להשתתף במפגש הקרוב ב$currentCity? הירשמו כאן:\n\n$shareUrl"
            : "רוצים להביא את משה פייגלין לעיר שלכם! רוצים לארח חוג בית או להצטרף למפגש הקרוב באזורכם? הירשמו כאן:\n\n$shareUrl")
        : (useSpecificCity
            ? "We want to bring Moshe Feiglin for a parlor meeting in $currentCity! Want to host or attend in $currentCity? Sign up here:\n\n$shareUrl"
            : "Want to bring Moshe Feiglin to your city? Sign up to host or attend a parlor meeting near you:\n\n$shareUrl");

    await Share.share(shareText);
  }

  void _submitRequest(String phone) async {
    final String cityToSave = _cityController.text.trim().isNotEmpty
        ? _cityController.text.trim()
        : (selectedCity ?? '').trim();

    if (cityToSave.isEmpty) return;
    setState(() => isSubmitting = true);

    final String safePhone = phone.replaceAll('+', '').trim();

    try {
      await FirebaseFirestore.instance.collection('parlor_meetings').doc(safePhone).set({
        'phone': safePhone,
        'city': cityToSave,
        'intent': _hostIntent,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending'
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('host_success'.tr()),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error saving meeting request: $e");
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  String _getCleanCityName() {
    final String current = _cityController.text.trim().isNotEmpty
        ? _cityController.text.trim()
        : (selectedCity ?? '').trim();
    if (current.isEmpty) {
      return context.locale.languageCode == 'he' ? "עירך" : "my city";
    }
    return current;
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;
    final bool isHebrew = context.locale.languageCode == 'he';
    final List<String> localizedCities =
        citiesData.map((c) => isHebrew ? c['he']! : c['en']!).toList()..sort();

    return Scaffold(
      backgroundColor: Colors.white,
      body: ValueListenableBuilder<bool>(
        valueListenable: di<AppState>().isLoggedIn,
        builder: (context, isLoggedIn, child) {
          final phone = di<AppState>().userPhone.value;
          final bool isVerified = isLoggedIn && phone != null && phone.isNotEmpty;
          final String activeCity = _getCleanCityName();

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Align(
                    alignment: isHebrew ? Alignment.topLeft : Alignment.topRight,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _shareHostMoshe(includeCity: false),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.share,
                                color: Color(0xFF103856),
                                size: 28,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                isHebrew ? "שתף\nעמוד" : "Share\nPage",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF103856),
                                  fontSize: 11,
                                  height: 1.1,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  MagenDavidHouseIcon(
                    size: 70,
                    houseColor: Colors.lightBlue,
                    starColor: Colors.white,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'host_title'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF103856),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'host_desc'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 35),

                  if (!isVerified) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.lock_open, size: 24),
                        label: Text(
                          "host_verify_btn".tr().toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () => showUniversalAuthSheet(context),
                      ),
                    ),
                  ] else ...[
                    // 🎯 HYBRID TYPABLE TEXTFIELD + DROPDOWN MENU (Defaulted to Safed)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return DropdownMenu<String>(
                          width: constraints.maxWidth,
                          controller: _cityController,
                          enableFilter: true,
                          enableSearch: true,
                          requestFocusOnTap: true,
                          menuHeight: 260,
                          hintText: 'host_city_hint'.tr(),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                          leadingIcon: const Icon(
                            Icons.location_city,
                            color: Color(0xFF103856),
                          ),
                          trailingIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_cityController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    size: 20,
                                    color: Colors.grey,
                                  ),
                                  tooltip: isHebrew ? 'נקה' : 'Clear',
                                  onPressed: () {
                                    setState(() {
                                      _cityController.clear();
                                      selectedCity = '';
                                    });
                                  },
                                ),
                              const Icon(
                                Icons.arrow_drop_down,
                                color: Color(0xFF103856),
                                size: 28,
                              ),
                            ],
                          ),
                          selectedTrailingIcon: const Icon(
                            Icons.arrow_drop_up,
                            color: Color(0xFF103856),
                            size: 28,
                          ),
                          inputDecorationTheme: InputDecorationTheme(
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade400,
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.lightBlue,
                                width: 2.5,
                              ),
                            ),
                          ),
                          menuStyle: MenuStyle(
                            backgroundColor: WidgetStateProperty.all(Colors.white),
                            elevation: WidgetStateProperty.all(6),
                            shape: WidgetStateProperty.all(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          onSelected: (String? selection) {
                            if (selection != null) {
                              setState(() {
                                selectedCity = selection;
                                _cityController.text = selection;
                              });
                              FocusManager.instance.primaryFocus?.unfocus();
                            }
                          },
                          dropdownMenuEntries: localizedCities
                              .map<DropdownMenuEntry<String>>((String city) {
                            return DropdownMenuEntry<String>(
                              value: city,
                              label: city,
                              style: MenuItemButton.styleFrom(
                                foregroundColor: Colors.black87,
                                textStyle: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    Theme(
                      data: Theme.of(context).copyWith(
                        unselectedWidgetColor: Colors.grey.shade500,
                      ),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'host_intent_host'.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF103856),
                              ),
                            ),
                            value: 'host',
                            groupValue: _hostIntent,
                            activeColor: Colors.lightBlue,
                            onChanged: (String? value) {
                              setState(() => _hostIntent = value!);
                            },
                          ),
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'host_intent_attend'.tr(args: [activeCity]),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF103856),
                              ),
                            ),
                            value: 'attend',
                            groupValue: _hostIntent,
                            activeColor: Colors.lightBlue,
                            onChanged: (String? value) {
                              setState(() => _hostIntent = value!);
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlue,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: isSubmitting ? null : () => _submitRequest(phone!),
                        child: isSubmitting
                            ? const SizedBox(
                                height: 30,
                                width: 30,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : Text(
                                'host_submit'.tr(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // 🎯 BOTTOM BUTTON: Share Parlor Meeting Invite (60px side icon + centered 2-row title & city)
                  SizedBox(
                    width: double.infinity,
                    child: Material(
                      color: const Color(0xFFF0F7FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Color(0xFF103856), width: 2.5),
                      ),
                      elevation: 2,
                      shadowColor: Colors.black26,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _shareHostMoshe(includeCity: true),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // 60px Share Icon pinned to the side
                              Align(
                                alignment: isHebrew ? Alignment.centerRight : Alignment.centerLeft,
                                child: const Icon(
                                  Icons.share_rounded,
                                  color: Color(0xFF103856),
                                  size: 56,
                                ),
                              ),
                              // Centered 2-Row Text (Row 1: Title, Row 2: City)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 64),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        isHebrew ? "שתף הזמנה לחוג בית" : "Share Parlor Meeting Invite",
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Color(0xFF103856),
                                          fontSize: 19,
                                          fontWeight: FontWeight.w900,
                                          height: 1.15,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        _cityController.text.trim().isNotEmpty
                                            ? (isHebrew ? "ב$activeCity" : activeCity)
                                            : (isHebrew ? "בעיר שלך" : "In Your City"),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.lightBlue,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          height: 1.15,
                                        ),
                                      ),
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
