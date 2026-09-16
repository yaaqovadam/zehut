import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class GodModeDeployWidget extends StatefulWidget {
  const GodModeDeployWidget({super.key});
  @override
  State<GodModeDeployWidget> createState() => _GodModeDeployWidgetState();
}

class _GodModeDeployWidgetState extends State<GodModeDeployWidget> {
  final _urlController = TextEditingController();
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  final _titleController = TextEditingController();

  bool _isDeploying = false;

  Future<void> _deployVideo() async {
    if (_urlController.text.isEmpty ||
        _startController.text.isEmpty ||
        _endController.text.isEmpty ||
        _titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all fields"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isDeploying = true;
    });

    try {
      final response = await http.post(
        Uri.parse('https://zehut-videos-452934157748.europe-west1.run.app'),
        headers: {'Content-Type': 'application/json'},

        body: jsonEncode({
          'url': _urlController.text.trim(),
          'start': int.parse(_startController.text.trim()),
          'end': int.parse(_endController.text.trim()),
          'title': _titleController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Deployed Successfully!"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception("Server returned ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Deployment Failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeploying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(title: const Text('God Mode: Video Deploy', style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF103856), automaticallyImplyLeading: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Zehut Media Pipeline", style: TextStyle(color: Colors.lightBlue, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            _buildTextField(controller: _titleController, label: "Clip Title (e.g. Bibi Speech)"),
            const SizedBox(height: 16),
            _buildTextField(controller: _urlController, label: "YouTube URL"),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTextField(controller: _startController, label: "Start (sec)", isNumber: true)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField(controller: _endController, label: "End (sec)", isNumber: true)),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isDeploying ? null : _deployVideo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: const Color(0xFF103856),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isDeploying ? const CircularProgressIndicator(color: Color(0xFF103856)) : const Text("RIP & DEPLOY", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: const Color(0xFF103856).withOpacity(0.5)), borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.lightBlue), borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}