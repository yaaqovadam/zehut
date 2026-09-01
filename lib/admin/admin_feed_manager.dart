import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminFeedManager extends StatefulWidget {
  const AdminFeedManager({super.key});

  @override
  State<AdminFeedManager> createState() => _AdminFeedManagerState();
}

class _AdminFeedManagerState extends State<AdminFeedManager> {
  final String _baseUrl = "https://pub-142306085f2b48bda4045cd9efdd0d28.r2.dev/";

  // 🔄 DRAG & DROP RE-INDEXER
  Future<void> _onReorder(int oldIndex, int newIndex, List<DocumentSnapshot> currentDocs) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    // Create a mutable copy of the current list to calculate the new order
    final mutableDocs = List<DocumentSnapshot>.from(currentDocs);
    final item = mutableDocs.removeAt(oldIndex);
    mutableDocs.insert(newIndex, item);

    // Batch update all new index numbers in Firestore instantly
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < mutableDocs.length; i++) {
      batch.update(mutableDocs[i].reference, {'index': i});
    }

    await batch.commit();
  }

  // ➕ ADD NEW VIDEO DIALOG
  void _showAddDialog(int nextIndex) {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Add New Video", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "e.g. moshe-feiglin-intro-zehut",
            hintStyle: TextStyle(color: Colors.grey),
            helperText: "Just the filename, no .mp4 or .jpg",
            helperStyle: TextStyle(color: Colors.blueGrey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () async {
              final fileName = nameController.text.trim();
              if (fileName.isNotEmpty) {
                await FirebaseFirestore.instance.collection('feeds').add({
                  'index': nextIndex,
                  'title': fileName.replaceAll('-', ' ').toUpperCase(),
                  'subtitle': 'צפו עד הסוף', // Default subtitle
                  'url': '$_baseUrl$fileName.mp4',
                  'thumb': '$_baseUrl$fileName.jpg',
                  'isLocked': false,
                  'like_count': 0,
                });
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Add to Feed", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 🗑️ DELETE & FIX INDEXES
  Future<void> _deleteVideo(DocumentSnapshot doc, List<DocumentSnapshot> currentDocs) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(doc.reference);

    // Remove from local list and recalculate indexes so there are no gaps
    final mutableDocs = List<DocumentSnapshot>.from(currentDocs);
    mutableDocs.removeWhere((element) => element.id == doc.id);

    for (int i = 0; i < mutableDocs.length; i++) {
      batch.update(mutableDocs[i].reference, {'index': i});
    }

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Feed Manager", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      // 📡 THE FIRESTORE LISTENER
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('feeds').orderBy('index').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("Feed is empty. Click + to add a video.", style: TextStyle(color: Colors.white)));
          }

          return ReorderableListView.builder(
            itemCount: docs.length,
            onReorder: (oldIndex, newIndex) => _onReorder(oldIndex, newIndex, docs),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              return Card(
                key: ValueKey(docs[index].id),
                color: const Color(0xFF1E293B),
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Text(data['index'].toString(), style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(data['title'] ?? 'No Title', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(data['url'].toString().split('/').last, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _deleteVideo(docs[index], docs),
                      ),
                      const Icon(Icons.drag_handle, color: Colors.grey),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('feeds').snapshots(),
        builder: (context, snapshot) {
          int nextIndex = snapshot.hasData ? snapshot.data!.docs.length : 0;
          return FloatingActionButton.extended(
            backgroundColor: Colors.blueAccent,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text("Add Video", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () => _showAddDialog(nextIndex),
          );
        },
      ),
    );
  }
}