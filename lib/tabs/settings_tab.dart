import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';
import '../app_state.dart'; // Adjust this path if your file structure is different

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.grey.shade900,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          // Admin Toggles
          ValueListenableBuilder<bool>(
            valueListenable: di<AppState>().isAdmin,
            builder: (context, isAdmin, _) {
              if (!isAdmin) return const SizedBox.shrink(); // Hides from public users

              // 🎯 Wrap both switches in a Column so they can both be returned safely
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Force Show Hidden Subs
                  ValueListenableBuilder<bool>(
                    valueListenable: di<AppState>().adminForceShowSubs,
                    builder: (context, forceSubs, _) {
                      return SwitchListTile(
                        title: const Text('Force Show Hidden Subs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Admin override to see disabled subtitles in the feed', style: TextStyle(color: Colors.grey)),
                        value: forceSubs,
                        activeColor: Colors.orangeAccent,
                        onChanged: (bool value) {
                          di<AppState>().adminForceShowSubs.value = value;
                        },
                      );
                    },
                  ),

                  // 2. Enable Edit UI Button
                  ValueListenableBuilder<bool>(
                    valueListenable: di<AppState>().adminShowEditButton,
                    builder: (context, showEditBtn, _) {
                      return SwitchListTile(
                        title: const Text('Enable Edit UI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Show the "EDIT SUBS" button on the video feed', style: TextStyle(color: Colors.grey)),
                        value: showEditBtn,
                        activeColor: Colors.lightBlue,
                        onChanged: (bool value) {
                          di<AppState>().adminShowEditButton.value = value;
                        },
                      );
                    },
                  ),
                ],
              );
            },
          ),

          // You can add your "adminShowOffline" toggle right below this later!
        ],
      ),
    );
  }
}