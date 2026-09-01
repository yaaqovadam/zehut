import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:screenshot/screenshot.dart';

import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;


class VanguardTab extends StatefulWidget {
  const VanguardTab({super.key});

  @override
  State<VanguardTab> createState() => _VanguardTabState();
}

class _VanguardTabState extends State<VanguardTab> {
  double _daysServed = 120;
  double _monthlySalary = 15000;
  bool _isCapturing = false;

  final ScreenshotController _screenshotController = ScreenshotController();

  double get _calculatedSavings {
    if (_daysServed < 30) return 0;
    double annualTax = (_monthlySalary * 12) * 0.20;
    double exemptionMultiplier = (_daysServed / 100).clamp(0.0, 1.0);
    return annualTax * exemptionMultiplier;
  }

  Future<void> _shareCardAsImage() async {
    setState(() {
      _isCapturing = true;
    });

    // Wait for Flutter to finish drawing the masked UI to the actual screen
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final imageBytes = await _screenshotController.capture(
          pixelRatio: 2.0, // High-res capture
        );

        setState(() {
          _isCapturing = false;
        });

        if (imageBytes != null) {
          String savings = _calculatedSavings
              .toStringAsFixed(0)
              .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');

          String viralMessage = context.locale.languageCode == 'he'
              ? "אחי, בדקתי עכשיו. לפי מגן המילואים של זהות, המדינה חייבת לי $savings ש״ח פטור ממס השנה על המילואים.\n\nבדוק כמה אתה אמור לקבל פה:\nhttps://zehut-100-days.web.app"
              : "Bro, I just checked. Under Zehut's Reservist Shield, the state owes me $savings NIS in tax exemptions this year.\n\nCalculate your refund here:\nhttps://zehut-100-days.web.app";

          final xFile = XFile.fromData(
            imageBytes,
            mimeType: 'image/png',
            name: 'zehut_vanguard_shield.png',
          );

          await Share.shareXFiles([xFile], text: viralMessage);
        }
      } catch (e) {
        setState(() {
          _isCapturing = false;
        });
        debugPrint("Could not capture image: $e");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // THE EXPORTABLE AREA
              Screenshot(
                controller: _screenshotController,
                child: Container(
                  decoration: BoxDecoration(
                    color: _isCapturing ? Colors.white : Colors.transparent,                    borderRadius: BorderRadius.circular(_isCapturing ? 20 : 0),
                  ),
                  padding: _isCapturing ? const EdgeInsets.all(20.0) : EdgeInsets.zero,
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      // 👇 THE SHIELD WITH MAGEN DAVID 👇
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.shield, size: 70, color: Theme.of(context).primaryColor),
                          const Padding(
                            // Nudges the star up slightly to sit perfectly in the wider chest of the shield
                            padding: EdgeInsets.only(bottom: 6.0),
                            child: Text(
                              '\u2721\uFE0E', // Magen David unicode + Text presentation selector
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                height: 1.0,
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text(
                        "shield_title".tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF103856),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        "shield_subtitle".tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: context.locale.languageCode == 'he' ? 16 : 14,
                          color: const Color(0xFF103856).withOpacity(0.9), // Darker, higher contrast                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Input 1
                      _buildSlider(
                        "days_served".tr(),
                        _daysServed,
                        0,
                        250,
                            (val) => setState(() => _daysServed = val),
                        "",
                        _isCapturing ? "XXX" : null,
                      ),
                      const SizedBox(height: 30),

                      // Input 2
                      _buildSlider(
                        "monthly_salary".tr(),
                        _monthlySalary,
                        7000,
                        45000,
                            (val) => setState(() => _monthlySalary = val),
                        " ₪",
                        _isCapturing ? "XXXXX ₪" : null,
                      ),

                      const SizedBox(height: 40),

                      // Result Card
                      // Result Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF25D366).withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 1. Safe, standard Text widget (No RichText)
                            Text(
                              context.locale.languageCode == 'he'
                                  ? "המדינה אשכרה חייבת לך:"
                                  : "The state really owes you:",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF1E293B), // Dark slate/grey
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            // 2. FittedBox to safely scale the giant number
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                "₪${_calculatedSavings.toStringAsFixed(0)}",
                                maxLines: 1,
                                style: const TextStyle(
                                  color: Color(0xFF1E293B), // Dark slate/grey
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
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

              const SizedBox(height: 30),

              // THE SHARE BUTTON
              ElevatedButton.icon(
                onPressed: _shareCardAsImage,
                icon: const Icon(Icons.share, color: Colors.black),
                label: Text(
                  "share_platoon".tr(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlider(
      String title,
      double value,
      double min,
      double max,
      Function(double) onChanged,
      String suffix,
      String? maskedValue,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    style: const TextStyle(color: Color(0xFF103856), fontSize: 16, fontWeight: FontWeight.bold),                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              maskedValue ?? "${value.toInt()}$suffix",
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: 50,
          activeColor: Theme.of(context).primaryColor,
          inactiveColor: Colors.grey.withOpacity(0.3),
          onChanged: onChanged,
        ),
      ],
    );
  }
}