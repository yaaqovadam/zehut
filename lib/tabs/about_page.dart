import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:watch_it/watch_it.dart';
import '../app_state.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Future<void> _launchUrl() async {
    final Uri url = Uri.parse('http://zehut.org.il');

    if (!await launchUrl(
      url,
      webOnlyWindowName: '_self', // Instructs the browser to use the current tab
    )) {
      debugPrint('Could not launch $url');
    }
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

        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            di<AppState>().setNavIndex(0);
            Navigator.pop(context);
          },
        ),

        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: const Color(0xFF103856).withOpacity(0.3),
                width: 2.0,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                offset: const Offset(0, 5),
                blurRadius: 14,
              ),
            ],
          ),
        ),
        title: Text(
          'about_title'.tr(),
          style:  TextStyle(
            color: Color(0xFF103856),
            fontWeight: FontWeight.w900,
            fontSize: context.locale.languageCode == 'he' ? 22 : 18,
          ),
        ),
        centerTitle: true,
        actions: [
          Center(
            child: InkWell(
              onTap: () {
                if (context.locale.languageCode == 'he') {
                  context.setLocale(const Locale('en'));
                } else {
                  context.setLocale(const Locale('he'));
                }
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(height: 5),
                  const Icon(Icons.language, color: Colors.lightBlue, size: 28),
                  const SizedBox(height: 2),
                  Text(
                    context.locale.languageCode == 'he' ? 'English' : 'עברית',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        // 🎯 FIX: Forces the wrapper to full screen width, snapping everything to true center
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 0),

                Image.asset(
                  'assets/images/zahut-logo.png',
                  width: 160,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 20),

                Text(
                  'about_description'.tr(),
                  textAlign: TextAlign.justify,

                  style: const TextStyle(
                    color: Color(0xFF103856),
                    fontSize: 18,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 20),

                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    icon: const Icon(Icons.language, color: Colors.white, size: 24),
                    label: Text(
                      'visit_website'.tr(),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _launchUrl,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}