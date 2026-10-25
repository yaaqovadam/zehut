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
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final FocusNode _addressFocus = FocusNode();
  final FocusNode _timeFocus = FocusNode();

  bool _isSafedCity([String? city]) {
    final String c = (city ?? selectedCity ?? _cityController.text).toLowerCase();
    return c.contains("צפת") || c.contains("safed") || c.contains("zefat") || c.contains("tzfat");
  }

  String _defaultAddress(bool isHe) => isHe
      ? "שוק התקווה תל אביב (סיור שטח ומפגש בוחרים)"
      : "Shuk HaTikva, Tel Aviv (Street tour & voter meetup)";

  String _defaultTime(bool isHe) => isHe
      ? "יום שני, 26 באוקטובר 2026 | 20:00"
      : "Monday, Oct 26, 2026 | 20:00";
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
          if (_isSafedCity(text)) {
            _addressController.clear();
            _timeController.clear();
          }
        });
      }
    });
    _addressFocus.addListener(() {
      final String curCity = (selectedCity ?? _cityController.text).toLowerCase();
      final bool isSafed = curCity.contains("צפת") || curCity.contains("safed") || curCity.contains("zefat") || curCity.contains("tzfat");
      if (!isSafed && !_addressFocus.hasFocus && _addressController.text.trim().isEmpty && mounted) {
        final bool isHe = context.locale.languageCode == 'he';
        setState(() {
          _addressController.text = _defaultAddress(isHe);
        });
      }
    });
    _timeFocus.addListener(() {
      final String curCity = (selectedCity ?? _cityController.text).toLowerCase();
      final bool isSafed = curCity.contains("צפת") || curCity.contains("safed") || curCity.contains("zefat") || curCity.contains("tzfat");
      if (!isSafed && !_timeFocus.hasFocus && _timeController.text.trim().isEmpty && mounted) {
        final bool isHe = context.locale.languageCode == 'he';
        setState(() {
          _timeController.text = _defaultTime(isHe);
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
      final String? urlAddr = Uri.base.queryParameters['address']?.trim();
      final String? urlTime = Uri.base.queryParameters['time']?.trim();
      if (urlCity != null && urlCity.isNotEmpty) {
        selectedCity = urlCity;
        _cityController.text = urlCity;
      } else {
        final String defaultSafed = isHe ? "צפת" : "Zefat (Safed)";
        selectedCity = defaultSafed;
        _cityController.text = defaultSafed;
      }
      final String activeCity = (selectedCity ?? "").toLowerCase();
      final bool isSafedCity = activeCity.contains("צפת") || activeCity.contains("safed") || activeCity.contains("zefat") || activeCity.contains("tzfat");
      _addressController.text = (urlAddr != null && urlAddr.isNotEmpty)
          ? urlAddr
          : (isSafedCity ? "" : _defaultAddress(isHe));
      _timeController.text = (urlTime != null && urlTime.isNotEmpty)
          ? urlTime
          : (isSafedCity ? "" : _defaultTime(isHe));
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
      if (_addressController.text.contains("שוק התקווה") || _addressController.text.contains("Shuk HaTikva")) {
        _addressController.text = isHe
            ? "שוק התקווה תל אביב (סיור שטח ומפגש בוחרים)"
            : "Shuk HaTikva, Tel Aviv (Street tour & voter meetup)";
      }
      if (_timeController.text.contains("22") && _timeController.text.contains("10:00")) {
        _timeController.text = isHe
            ? "יום שני, 26 באוקטובר 2026 | 20:00"
            : "Monday, Oct 26, 2026 | 20:00";
      }
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    _addressController.dispose();
    _timeController.dispose();
    _addressFocus.dispose();
    _timeFocus.dispose();
    super.dispose();
  }

  Future<void> _shareHostMoshe({required bool includeCity}) async {
    final bool isHe = context.locale.languageCode == "he";
    final String currentCity = (selectedCity ?? _cityController.text).trim();
    final bool useSpecificCity = includeCity && currentCity.isNotEmpty;

    final bool isSafed = useSpecificCity &&
        (currentCity == "צפת" ||
         currentCity.toLowerCase().contains("safed") ||
         currentCity.toLowerCase().contains("zefat") ||
         currentCity.toLowerCase().contains("tzfat"));

    final String encodedCity = useSpecificCity ? Uri.encodeComponent(currentCity) : "";
    final String shareUrl = useSpecificCity
        ? "https://gamfeiglintzadak.co.il/parlor-meetings.html?city=$encodedCity&v=202"
        : "https://gamfeiglintzadak.co.il/parlor-meetings.html?v=202";

    final String addrText = _addressController.text.trim();
    final String timeText = _timeController.text.trim();
    final bool hasEventDetails = addrText.isNotEmpty || timeText.isNotEmpty;

    String shareText;
    if (useSpecificCity && hasEventDetails) {
      shareText = isHe
          ? "🎙️ מפגש עם משה פייגלין (זהות) ב$currentCity\n"
            "${timeText.isNotEmpty ? '📅 מועד: $timeText\n' : ''}"
            "${addrText.isNotEmpty ? '📍 מיקום: $addrText\n' : ''}\n"
            "להרשמה מראש (לאירוח או להשתתפות במפגש) לחצו כאן:\n$shareUrl"
          : "🎙️ MEET MOSHE FEIGLIN (Zehut) IN ${currentCity.toUpperCase()}\n"
            "${timeText.isNotEmpty ? '📅 Date & Time: $timeText\n' : ''}"
            "${addrText.isNotEmpty ? '📍 Location: $addrText\n' : ''}\n"
            "RSVP & Host/Attendee Registration at the link below:\n$shareUrl";
    } else if (isSafed) {
      shareText = isHe
          ? "🎙️ חוג בית בצפת לפני הבחירות — משה פייגלין (זהות)\n📅 תאריך: יום שני, 26 באוקטובר\n🕗 שעה: 20:00\n📍 מיקום: צפת (מיקום מדויק או קישור לשידור חי יישלחו לנרשמים המאומתים)\n\nלפני שהולכים לקלפי, בואו לשמוע את החזון של משה פייגלין לביטחון, כלכלה וריבונות, ולשאול את השאלות הקשות פנים אל פנים.\n\nלהרשמה מראש (לאירוח או להשתתפות במפגש) לחצו כאן:\n$shareUrl"
          : "🎙️ PRE-ELECTION PARLOR MEETING IN TZFAT — MOSHE FEIGLIN (Zehut)\n📅 Date: Monday, October 26th\n🕗 Time: 8:00 PM (20:00)\n📍 Location: Tzfat (Exact location or Live Briefing link sent to verified RSVPs)\n\nBefore going to the ballot box, come hear Moshe Feiglin\x27s vision for Israel\x27s security, economy, and sovereignty, and ask your questions in person.\n\nRSVP & Host/Attendee Registration required at the link below:\n$shareUrl";
    } else {
      shareText = isHe
          ? (useSpecificCity
              ? "🚨 48 השעות האחרונות לפני הבחירות ב$currentCity! מתפקדים עכשיו ב$currentCity לשידור החי עם משה פייגלין, מפגשי בזק והתארגנות ליום הבחירות:\n\n$shareUrl"
              : "🚨 48 השעות האחרונות לפני הבחירות! מתפקדים עכשיו בעיר שלכם לשידור החי עם משה פייגלין, מפגשי בזק והתארגנות ליום הבחירות:\n\n$shareUrl")
          : (useSpecificCity
              ? "🚨 FINAL 48 HOURS IN ${currentCity.toUpperCase()}! Lock in your spot in $currentCity for Moshe Feiglin's Live Pre-Election Briefing, last-minute stops & Election Day mobilization:\n\n$shareUrl"
              : "🚨 FINAL 48 HOURS BEFORE ELECTION DAY! Lock in your city for Moshe Feiglin's Live Pre-Election Briefing, last-minute stops & Election Day mobilization:\n\n$shareUrl");
    }

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
        'address': _addressController.text.trim(),
        'event_time': _timeController.text.trim(),
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

          return Stack(fit: StackFit.expand, children: [
Center(
child: SingleChildScrollView(
padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 30.0),
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
crossAxisAlignment: CrossAxisAlignment.center,
children: [
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
                    const SizedBox(height: 12),

                    // 📍 ADDRESS / LOCATION FIELD
                    if (!_isSafedCity()) ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _addressController,
                      builder: (context, addrVal, _) {
                        return TextField(
                          controller: _addressController,
                          focusNode: _addressFocus,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                          decoration: InputDecoration(
                            labelText: isHebrew ? 'כתובת / מיקום המפגש' : 'Address / Meeting Location',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            hintText: _defaultAddress(isHebrew),
                            prefixIcon: const Icon(Icons.place, color: Color(0xFF103856)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                addrVal.text.isNotEmpty ? Icons.clear : Icons.restore,
                                size: 20,
                                color: Colors.grey,
                              ),
                              tooltip: addrVal.text.isNotEmpty
                                  ? (isHebrew ? 'נקה' : 'Clear')
                                  : (isHebrew ? 'שחזר ברירת מחדל' : 'Restore default'),
                              onPressed: () {
                                if (addrVal.text.isNotEmpty) {
                                  _addressController.clear();
                                } else {
                                  _addressController.text = _defaultAddress(isHebrew);
                                }
                              },
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade400, width: 2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.lightBlue, width: 2.5),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // 🕒 DATE & TIME FIELD
                    if (!_isSafedCity()) ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _timeController,
                      builder: (context, timeVal, _) {
                        return TextField(
                          controller: _timeController,
                          focusNode: _timeFocus,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                          decoration: InputDecoration(
                            labelText: isHebrew ? 'תאריך ושעה' : 'Date & Time',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            hintText: _defaultTime(isHebrew),
                            prefixIcon: const Icon(Icons.access_time_filled, color: Color(0xFF103856)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                timeVal.text.isNotEmpty ? Icons.clear : Icons.restore,
                                size: 20,
                                color: Colors.grey,
                              ),
                              tooltip: timeVal.text.isNotEmpty
                                  ? (isHebrew ? 'נקה' : 'Clear')
                                  : (isHebrew ? 'שחזר ברירת מחדל' : 'Restore default'),
                              onPressed: () {
                                if (timeVal.text.isNotEmpty) {
                                  _timeController.clear();
                                } else {
                                  _timeController.text = _defaultTime(isHebrew);
                                }
                              },
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade400, width: 2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.lightBlue, width: 2.5),
                            ),
                          ),
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
                                        isHebrew ? "שתף התפקדות 48 שעות אחרונות" : "Share Final 48h Mobilization",
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
),
],
);
},
),
);
}
}
