import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:learnock_drm/models/workspace.dart';
import 'package:learnock_drm/providers/workspace_provider.dart';
import 'package:learnock_drm/providers/language_provider.dart';
import 'package:learnock_drm/providers/theme_provider.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<bool?> _showPremiumAlert(BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    required String cancelText,
    bool isDestructive = false,
  }) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final primaryColor = Theme.of(context).primaryColor;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: isDestructive ? const Color(0xFFEF4444) : onSurface, fontSize: 18)),
        content: Text(message, style: TextStyle(color: onSurfaceVariant, fontSize: 14, height: 1.4)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: Text(langRef(context).translate('cancel'), style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 13))
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? const Color(0xFFEF4444) : primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(confirmText, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  LanguageProvider langRef(BuildContext context) => Provider.of<LanguageProvider>(context, listen: false);

  @override
  Widget build(BuildContext context) {
    final wp = Provider.of<WorkspaceProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);
    final theme = Provider.of<ThemeProvider>(context);
    final workspace = wp.activeWorkspace;
    final otherWorkspaces = wp.workspaces.where((w) => w.id != workspace?.id).toList();
    final isRTL = lang.currentLocale.languageCode == 'ar';
    
    final cardColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        toolbarHeight: 56,
        leading: IconButton(
          icon: Icon(isRTL ? Icons.arrow_back_ios_new_rounded : Icons.arrow_back_ios_rounded, color: onSurface, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lang.translate('profile'),
          style: TextStyle(color: onSurface, fontSize: 16, fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(theme.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: primaryColor, size: 20),
            onPressed: () => theme.toggleTheme(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // COMPACT HEADER
            Center(
              child: Column(
                children: [
                   Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: primaryColor.withOpacity(0.1), width: 2)),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: primaryColor,
                          child: Text(
                            (workspace?.studentName ?? 'S')[0],
                            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                      Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle, border: Border.all(color: cardColor, width: 2)), child: const Icon(Icons.verified_rounded, color: Colors.white, size: 14))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(workspace?.studentName ?? lang.translate('student_Learnock'), style: TextStyle(color: onSurface, fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(100)),
                    child: Text(workspace?.email ?? '', style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            _buildSectionHeader(context, lang.translate('academy'), center: false),
            const SizedBox(height: 12),
            if (workspace != null) _buildWorkspaceCard(context, workspace, true, lang, wp),

            if (otherWorkspaces.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSectionHeader(context, lang.translate('other_workspaces'), center: false),
              const SizedBox(height: 12),
              ...otherWorkspaces.map((w) => _buildWorkspaceCard(context, w, false, lang, wp)),
            ],

            const SizedBox(height: 32),
            _buildActionSection(context, wp, lang),

            const SizedBox(height: 32),
            _buildSectionHeader(context, lang.translate('tech_info'), center: false),
            const SizedBox(height: 12),
            _buildInfoCard(context, Icons.fingerprint_rounded, lang.translate('device_id'), wp.deviceId),
            _buildInfoCard(context, Icons.info_outline_rounded, lang.translate('version'), '1.0.0+1'),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSection(BuildContext context, WorkspaceProvider wp, LanguageProvider lang) {
    final primaryColor = Theme.of(context).primaryColor;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/wallet'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 4,
              shadowColor: primaryColor.withOpacity(0.3),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.stars_rounded, size: 20),
                const SizedBox(width: 10),
                Text((lang.translate('redeem_voucher') ?? 'CHARGE WALLET').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => Navigator.pushNamed(context, '/favorites'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 56,
            width: double.infinity,
            decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_rounded, size: 20, color: primaryColor),
                const SizedBox(width: 10),
                Text((lang.translate('favorites') ?? 'FAVORITES').toUpperCase(), style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => Navigator.pushNamed(context, '/onboarding'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 56,
            width: double.infinity,
            decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_scanner_rounded, size: 20, color: primaryColor),
                const SizedBox(width: 10),
                Text(lang.translate('scan_new_code').toUpperCase(), style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final nav = Navigator.of(context);
            final confirmed = await _showPremiumAlert(context, title: lang.translate('logout'), message: lang.translate('logout_confirm'), confirmText: lang.translate('logout'), cancelText: lang.translate('cancel'), isDestructive: true);
            if (confirmed == true) { 
              await wp.logout(); 
              nav.pushNamedAndRemoveUntil('/onboarding', (route) => false); 
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 18),
                const SizedBox(width: 10),
                Text(lang.translate('logout'), style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w900, fontSize: 14)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, {required bool center}) {
    final primaryColor = Theme.of(context).primaryColor;
    return Container(
      width: double.infinity,
      alignment: center ? Alignment.center : AlignmentDirectional.centerStart,
      child: Text(
        title.toUpperCase(),
        style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildWorkspaceCard(BuildContext context, Workspace w, bool isActive, LanguageProvider lang, WorkspaceProvider wp) {
    final dividerColor = Theme.of(context).dividerColor;
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, 
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(color: isActive ? primaryColor : dividerColor, width: 2),
        boxShadow: isActive ? [BoxShadow(color: primaryColor.withOpacity(0.1), blurRadius: 20)] : null,
      ),
      child: InkWell(
        onTap: () async { await wp.switchWorkspace(w.id, context); if (context.mounted) Navigator.pushReplacementNamed(context, '/dashboard'); },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (w.logoUrl != null)
                Container(
                  width: 48, height: 48, padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: primaryColor.withOpacity(0.1), width: 1)),
                  child: ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.network(w.logoUrl!, fit: BoxFit.contain, errorBuilder: (c,e,s) => Icon(Icons.business_rounded, color: primaryColor))),
                )
              else
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: dividerColor, shape: BoxShape.circle), child: Icon(Icons.business_rounded, color: primaryColor, size: 24)),
              
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(w.name.toUpperCase(), style: TextStyle(color: onSurface, fontWeight: FontWeight.w900, fontSize: 14)),
                  Text(w.host, style: TextStyle(color: primaryColor.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
              ),
              if (isActive) Icon(Icons.check_circle_rounded, color: primaryColor, size: 22)
              else const SizedBox(width: 22),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () async {
                  final isLast = wp.workspaces.length == 1;
                  final confirmed = await _showPremiumAlert(context, title: isLast ? lang.translate('logout') : lang.translate('remove_academy'), message: isLast ? lang.translate('logout_confirm') : lang.translate('remove_academy_confirm'), confirmText: isLast ? lang.translate('logout') : lang.translate('remove'), cancelText: lang.translate('cancel'), isDestructive: true);
                  if (confirmed == true) { if (isLast) { await wp.logout(); Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (route) => false); } else { await wp.removeWorkspace(w.id); } }
                },
                icon: Icon(wp.workspaces.length == 1 ? Icons.logout_rounded : Icons.delete_outline_rounded, color: const Color(0xFFEF4444), size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, IconData icon, String label, String value) {
    final primaryColor = Theme.of(context).primaryColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: primaryColor.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: primaryColor.withOpacity(0.05), width: 1)),
      child: Row(
        children: [
          Icon(icon, color: primaryColor.withOpacity(0.4), size: 18),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(), style: TextStyle(color: primaryColor.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            Text(value, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 13)),
          ])),
        ],
      ),
    );
  }
}
