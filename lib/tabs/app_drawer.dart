import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:js_interop';

import 'admin_feed_manager.dart';
import 'about_page.dart';
import '../app_state.dart';
import 'package:watch_it/watch_it.dart';
import 'settings_tab.dart';
import 'thumbnail_studio_screen.dart';

@JS('triggerAppInstall')
external void triggerAppInstall(JSString lang);

class AppDrawer extends StatelessWidget {
  final bool isAdmin;
  const AppDrawer({super.key, this.isAdmin = false});

  @override
  Widget build(BuildContext context) {
    final _ = context.locale;
    final isAdminUser = isAdmin;
    final bool isHe = context.locale.languageCode == 'he';

    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFF103856).withOpacity(0.1),
                  width: 2,
                ),
              ),
            ),
            child: Center(
              child: Image.asset('assets/images/zahut-logo.png', width: 106),
            ),
          ),
          if (isAdminUser) ...[
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
            ListTile(
              leading: const Icon(Icons.image_outlined, color: Colors.purpleAccent, size: 26),
              title: Text(
                isHe ? 'אולפן תמונות (Thumbnails)' : 'Thumbnail Studio',
                style: const TextStyle(color: Color(0xFF103856), fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ThumbnailStudioScreen()));
              },
            ),
            const Divider(color: Colors.black12, height: 1),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.grey, size: 26),
              title: Text(
                isHe ? 'הגדרות' : 'Settings',
                style: const TextStyle(color: Color(0xFF103856), fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsTab()));
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
              label: Text(
                'menu_install'.tr(),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF103856),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final String currentLang = context.locale.languageCode;
                Navigator.pop(context);
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