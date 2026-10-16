import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:watch_it/watch_it.dart';
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

  final List<Map<String, String>> citiesData = [
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
    {"en": "Zefat (Safed)", "he": "צפת"},
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

  void _submitRequest(String phone) async {
    if (selectedCity == null || selectedCity!.isEmpty) return;
    setState(() => isSubmitting = true);

    final String safePhone = phone.replaceAll('+', '').trim();

    try {
      await FirebaseFirestore.instance.collection('parlor_meetings').doc(safePhone).set({'phone': safePhone, 'city': selectedCity, 'intent': _hostIntent, 'timestamp': FieldValue.serverTimestamp(), 'status': 'pending'}, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('host_success'.tr()), backgroundColor: Colors.green, duration: const Duration(seconds: 4)));
      }
    } catch (e) {
      debugPrint("Error saving meeting request: $e");
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  String _getCleanCityName() {
    if (selectedCity == null || selectedCity!.isEmpty) return "my city";
    return selectedCity!;
  }

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;

    final bool isHebrew = context.locale.languageCode == 'he';
    final List<String> localizedCities = citiesData.map((c) => isHebrew ? c['he']! : c['en']!).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: ValueListenableBuilder<bool>(
        valueListenable: di<AppState>().isLoggedIn,
        builder: (context, isLoggedIn, child) {
          final phone = di<AppState>().userPhone.value;
          final bool isVerified = isLoggedIn && phone != null && phone.isNotEmpty;

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30.0),
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
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF103856)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'host_desc'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.4),
                  ),
                  const SizedBox(height: 40),

                  if (!isVerified) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      // 🎯 Swapped to standard Material Icon to beat the web compiler
                      icon: const Icon(Icons.lock_open, size: 24),
                      label: Text("host_verify_btn".tr().toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      onPressed: () => showUniversalAuthSheet(context),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400, width: 2),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade50,
                      ),
                      child: Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<String>.empty();
                          }
                          return localizedCities.where((String city) {
                            return city.toLowerCase().contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        onSelected: (String selection) {
                          setState(() {
                            selectedCity = selection;
                          });
                          FocusManager.instance.primaryFocus?.unfocus();
                        },
                        fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
                          if (selectedCity != null && textEditingController.text.isEmpty) {
                            textEditingController.text = selectedCity!;
                          }
                          return TextField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            scrollPadding: const EdgeInsets.only(bottom: 250.0),
                            decoration: InputDecoration(
                              hintText: 'host_city_hint'.tr(),
                              border: InputBorder.none,
                              suffixIcon: const Icon(Icons.search, color: Color(0xFF103856)),
                            ),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxHeight: 200, maxWidth: MediaQuery.of(context).size.width - 60),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder: (BuildContext context, int index) {
                                    final String option = options.elementAt(index);
                                    return InkWell(
                                      onTap: () => onSelected(option),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Text(
                                          option,
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    Theme(
                      data: Theme.of(context).copyWith(unselectedWidgetColor: Colors.grey.shade500),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'host_intent_host'.tr(),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF103856)),
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
                              'host_intent_attend'.tr(args: [_getCleanCityName()]),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF103856)),
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
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isSubmitting ? null : () => _submitRequest(phone!),
                        child: isSubmitting
                            ? const SizedBox(height: 30, width: 30, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                            : Text(
                                'host_submit'.tr(),
                                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
