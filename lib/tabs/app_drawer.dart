import 'package:http/http.dart' as http;
import 'dart:convert';
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
            const _AdminVisitorStatsCard(),
            const Divider(color: Colors.black12, height: 1),
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
class _AdminVisitorStatsCard extends StatefulWidget {
  const _AdminVisitorStatsCard();

  @override
  State<_AdminVisitorStatsCard> createState() => _AdminVisitorStatsCardState();
}

class _AdminVisitorStatsCardState extends State<_AdminVisitorStatsCard> {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _loading = true);
    try {
      final resp = await http.get(Uri.parse('https://zehut-server.onrender.com/getStats'));
      if (resp.statusCode == 200 && mounted) {
        setState(() {
          _stats = jsonDecode(resp.body);
          _loading = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final bool isHe = context.locale.languageCode == 'he';
    final int todayUnique = _stats?['todayUnique'] ?? 0;
    final int totalUnique = _stats?['totalUnique'] ?? 0;
    final int totalSessions = _stats?['totalSessions'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amberAccent.withOpacity(0.6), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt, color: Colors.amberAccent, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    isHe ? 'מבקרים אמיתיים (ללא בוטים)' : 'Real Human Visitors',
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _fetchStats,
                child: const Icon(Icons.refresh, color: Colors.white70, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(6.0),
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amberAccent)),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statCol(isHe ? 'היום (ייחודי)' : 'Today Unique', '$todayUnique', Colors.greenAccent),
                _statCol(isHe ? 'סה״כ ייחודיים' : 'Total Unique', '$totalUnique', Colors.lightBlueAccent),
                _statCol(isHe ? 'סה״כ כניסות' : 'Total Visits', '$totalSessions', Colors.white),
              ],
            ),
        ],
      ),
    );
  }

  Widget _statCol(String label, String val, Color color) {
    return Column(
      children: [
        Text(val, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}
