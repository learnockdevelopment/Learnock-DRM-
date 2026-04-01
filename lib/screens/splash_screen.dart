import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:learnock_drm/providers/workspace_provider.dart';
import 'package:learnock_drm/providers/language_provider.dart';
import 'package:learnock_drm/widgets/premium_loader.dart';
import 'package:no_screenshot/no_screenshot.dart';
import 'package:safe_device/safe_device.dart';
import 'dart:io';

import '../providers/theme_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _securityFailure = false;
  String _securityMessage = "";
  String _securitySubMessage = "";

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _controller.forward();
    _init();
  }
  Future<void> _init() async {
    // Load language first (default to ar)
    await Provider.of<LanguageProvider>(context, listen: false)
        .loadLanguage(const Locale('ar'));

    // ACTIVATE ANTI-CAPTURE PROTOCOL
    await NoScreenshot.instance.screenshotOff();

    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    
    // RUN EVERYTHING IN PARALLEL
    final results = await Future.wait([
      wp.init(),
      SafeDevice.isRealDevice,
      SafeDevice.isDevelopmentModeEnable,
      SafeDevice.isJailBroken,
    ]);

    final bool isReal = results[1] as bool;
    final bool isDev = results[2] as bool;
    final bool isJailBroken = results[3] as bool;

    // SECURITY CONFIGURATION (Set bypassSecurity to true for testing on emulator)
    const bool bypassSecurity = false; 

    // OVERRIDE: IF RUNNING ON EMULATOR OR ROOTED, BLOCK ACCESS PERMANENTLY
    bool shouldBlock = (!isReal || isDev || isJailBroken) && bypassSecurity; 

    if (shouldBlock) {
       if (mounted) {
         setState(() {
           _securityFailure = true;
         });
       }
       return;
    }

    // Hold splash for at least 2.5 seconds for branding
    await Future.delayed(const Duration(milliseconds: 2500));

    if (mounted) {
      if (wp.activeWorkspace != null) {
        final w = wp.activeWorkspace!;
        Provider.of<ThemeProvider>(context, listen: false).setTenant(w.theme, themeColor: w.themeColor);
        Navigator.of(context).pushReplacementNamed('/dashboard');
      } else {
        Navigator.of(context).pushReplacementNamed('/onboarding');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_securityFailure) return _buildSecurityLockUI();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: PremiumLoader(color: const Color(0xFF6366f1), useAppLogoOnly: true), 
      ),
    );
  }

  Widget _buildSecurityLockUI() {
    final wp = Provider.of<WorkspaceProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);
    final logo = wp.activeWorkspace?.logoUrl;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // DEEP DARK SLATE
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.12), 
                shape: BoxShape.circle,
                border: Border.all(color: Colors.redAccent.withOpacity(0.2), width: 2),
                boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.1), blurRadius: 40, spreadRadius: 10)],
              ),
              child: Image.asset('assets/logo.png', width: 80, height: 80, color: Colors.white),
            ),
            const SizedBox(height: 40),
            
            Text(
              lang.translate('security_block'),
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              lang.translate('drm_protection'),
              style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white10)),
              child: Column(
                children: [
                  Text(
                    lang.translate('security_failure_msg'),
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.6, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 20),
                  Text(
                    lang.translate('disable_dev_options'),
                    style: TextStyle(color: Colors.redAccent.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w900),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 60),
            Text(
               lang.translate('drm_engine'),
               style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          ],
        ),
      ),
    );
  }
}
