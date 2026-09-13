import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:js_interop';

import 'admin_feed_manager.dart';
import 'about_page.dart';

// 🎯 Your original JS interop (Requires a String argument to match the JS)
@JS('triggerAppInstall')
external void triggerAppInstall(JSString lang);

class AppDrawer extends StatelessWidget {
  final bool isAdmin;

  const AppDrawer({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: const Color(0xFF103856).withOpacity(0.1), width: 2)),
            ),
            child: Center(
              child: Image.asset('assets/images/zahut-logo.png', width: 106),
            ),
          ),

          if (isAdmin) ...[
            ListTile(
              leading: const Icon(Icons.security, color: Color(0xFFF59E0B), size: 26),
              title: Text(
                'menu_manage_videos'.tr(),
                style: const TextStyle(color: Color(0xFF103856), fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminFeedManager()));
              },
            ),
            const Divider(color: Colors.black12, height: 1),
          ],

          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.lightBlue, size: 26),
            title: Text(
              'menu_about'.tr(),
              style: const TextStyle(color: Color(0xFF103856), fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutPage()));
            },
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.install_mobile, color: Colors.white),
              label:  Text(
                'menu_install'.tr(),
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF103856),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                // 1. Save the language code BEFORE closing the drawer
                final String currentLang = context.locale.languageCode;

                // 2. Close the drawer
                Navigator.pop(context);

                // 3. Trigger the JS directly with the saved language
                if (kIsWeb) {
                  triggerAppInstall(currentLang.toJS);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}