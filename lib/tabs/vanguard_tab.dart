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
                    color: _isCapturing ? const Color(0xFF0A0A1A) : Colors.transparent,
                    borderRadius: BorderRadius.circular(_isCapturing ? 20 : 0),
                  ),
                  padding: _isCapturing ? const EdgeInsets.all(20.0) : EdgeInsets.zero,
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Icon(Icons.shield, size: 70, color: Theme.of(context).primaryColor),
                      const SizedBox(height: 15),
                      Text(
                        "shield_title".tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        "shield_subtitle".tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: context.locale.languageCode == 'he' ? 16 : 14,
                          color: Colors.grey,
                          height: 1.4,
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
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF166534), Color(0xFF14532D)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.15),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            context.locale.languageCode == 'he'
                                ? RichText(
                              textAlign: TextAlign.center,
                              text: const TextSpan(
                                style: TextStyle(color: Colors.white70, fontSize: 18),
                                children: [
                                  TextSpan(text: "המדינה "),
                                  TextSpan(
                                    text: "אשכרה ",
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  TextSpan(text: "חייבת לך:"),
                                ],
                              ),
                            )
                                : RichText(
                              textAlign: TextAlign.center,
                              text: const TextSpan(
                                style: TextStyle(color: Colors.white70, fontSize: 18),
                                children: [
                                  TextSpan(text: "The state "),
                                  TextSpan(
                                    text: "really ",
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  TextSpan(text: "owes you:"),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                "₪${_calculatedSavings.toStringAsFixed(0)}",
                                maxLines: 1,
                                style: const TextStyle(
                                  color: Colors.white,
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
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
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