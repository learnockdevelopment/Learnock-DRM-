import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:learnock_drm/providers/workspace_provider.dart';
import 'package:learnock_drm/providers/language_provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:learnock_drm/widgets/premium_loader.dart';

import '../models/workspace.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isManual = false;
  bool _isLoading = false;
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  
  bool _isScanning = true;

  void _onCodeScanned(String code) async {
    if (!_isScanning) return;
    setState(() => _isScanning = false);

    try {
      final data = json.decode(code);
      final wp = Provider.of<WorkspaceProvider>(context, listen: false);

      if (data['version'] == '1.2' && data['token'] != null) {
        setState(() => _isLoading = true);
        await wp.addWorkspaceWithToken(
          data['host'] ?? (data['tenant'] != null ? "${data['tenant']}.derasy.com" : ""),
          data['token'],
          data['email'] ?? "",
          data['name'] ?? "Student",
        );
        if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
        return;
      }

      if (data['version'] == '1.0' || data['tenant'] != null || data['host'] != null) {
        _hostController.text = data['host'] ?? (data['tenant'] != null ? "${data['tenant']}.derasy.com" : "");
        _userController.text = data['email'] ?? "";
        if (data['password'] != null) {
          _passController.text = data['password'];
          _loginManual();
        } else {
          setState(() => _isManual = true);
        }
        return;
      }
      throw 'Invalid QR Format';
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Provider.of<LanguageProvider>(context, listen: false).translate('invalid_code'))));
      }
    }
  }

  void _loginManual() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    if (_hostController.text.isEmpty || _userController.text.isEmpty || _passController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.translate('fill_fields'))));
      setState(() => _isManual = true);
      return;
    }

    setState(() => _isLoading = true);
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    
    try {
       await wp.addWorkspaceManual(
        _hostController.text.trim(),
        _userController.text.trim(),
        _passController.text.trim(),
      );
      if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.translate('login_failed')}: ${e.toString()}')));
        setState(() => _isScanning = true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wp = Provider.of<WorkspaceProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);
    final isRTL = lang.currentLocale.languageCode == 'ar';
    
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (wp.workspaces.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: IconButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard'),
                    icon: Icon(
                      lang.currentLocale.languageCode == 'ar' ? Icons.arrow_back_ios_new_rounded : Icons.arrow_forward_ios_rounded,
                      color: onSurface, 
                      size: 20
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Hero(
                tag: 'app-logo',
                child: Image.asset('assets/logo.png', height: 64, color: onSurface),
              ),
              const SizedBox(height: 24),
              Text(
                lang.translate('welcome_to_Learnock'),
                style: TextStyle(color: onSurface, fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                lang.translate('start_journey'),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              
              if (wp.workspaces.isNotEmpty) ...[
                Align(
                  alignment: isRTL ? Alignment.centerRight : Alignment.centerLeft,
                  child: Text(
                    lang.translate('other_workspaces').toUpperCase(),
                    style: TextStyle(color: onSurface.withOpacity(0.35), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                  ),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: wp.workspaces.length,
                  itemBuilder: (context, i) {
                    final w = wp.workspaces[i];
                    return _buildAcademySelectionCard(context, w, wp, primaryColor, onSurface);
                  },
                ),
                const SizedBox(height: 32),
                Divider(color: Theme.of(context).dividerColor, thickness: 1),
                const SizedBox(height: 32),
              ],

              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Expanded(child: _buildTabButton(0, lang.translate('scan_qr'))),
                    Expanded(child: _buildTabButton(1, lang.translate('manual_entry'))),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isManual ? _buildManualForm(lang) : (_isLoading ? _buildLoading() : _buildQRSection(lang)),
              ),
              const SizedBox(height: 40),
              Text(
                lang.translate('copyright'),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      key: ValueKey('loading'),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: PremiumLoader(),
      ),
    );
  }

  Widget _buildQRSection(LanguageProvider lang) {
    return Column(
      key: const ValueKey('qr'),
      children: [
        Container(
          height: 260,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Theme.of(context).dividerColor, width: 3),
          ),
          clipBehavior: Clip.antiAlias,
          child: MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _onCodeScanned(barcode.rawValue!);
                }
              }
            },
          ),
        ),
        const SizedBox(height: 20),
        Text(
          lang.translate('scan_qr').toUpperCase(),
          style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
        ),
      ],
    );
  }

  Widget _buildManualForm(LanguageProvider lang) {
    return Column(
      key: const ValueKey('manual'),
      children: [
        _buildTextField(controller: _hostController, label: lang.translate('academy_host'), icon: Icons.link_rounded, hint: 'academy.Learnock.app'),
        const SizedBox(height: 16),
        _buildTextField(controller: _userController, label: lang.translate('email'), icon: Icons.alternate_email_rounded),
        const SizedBox(height: 16),
        _buildTextField(controller: _passController, label: lang.translate('password'), icon: Icons.lock_outline_rounded, isObscure: true),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _loginManual,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _isLoading 
                ? const SpinKitThreeBounce(color: Colors.white, size: 20) 
                : Text(lang.translate('login').toUpperCase(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ),
        ),
      ], 
    );
  }

  Widget _buildTabButton(int index, String label) {
    final bool isActive = (index == 1) == _isManual;
    final primaryColor = Theme.of(context).primaryColor;
    return GestureDetector(
      onTap: () => setState(() {
        _isManual = index == 1;
        if (!_isManual) _isScanning = true;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Theme.of(context).cardColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isActive ? Border.all(color: Theme.of(context).dividerColor, width: 2) : null,
        ),
        child: Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(color: isActive ? primaryColor : Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, String? hint, bool isObscure = false}) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: onSurface, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isObscure,
          style: TextStyle(color: onSurface, fontWeight: FontWeight.bold, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5), size: 18),
            fillColor: Theme.of(context).cardColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Theme.of(context).dividerColor, width: 2)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Theme.of(context).dividerColor, width: 2)),
          ),
        ),
      ],
    );
  }

  Widget _buildAcademySelectionCard(BuildContext context, Workspace w, WorkspaceProvider wp, Color primary, Color onSurface) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor, width: 2),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle),
          child: w.logoUrl != null 
            ? ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.network(w.logoUrl!, fit: BoxFit.contain, errorBuilder: (c,e,s) => Icon(Icons.school_rounded, color: primary)))
            : Icon(Icons.school_rounded, color: primary),
        ),
        title: Text(w.name.toUpperCase(), style: TextStyle(color: onSurface, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
        subtitle: Text(w.studentName, style: TextStyle(color: onSurface.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold)),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: onSurface.withOpacity(0.2)),
        onTap: () async {
          setState(() => _isLoading = true);
          await wp.switchWorkspace(w.id, context);
          if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
        },
      ),
    );
  }
}
