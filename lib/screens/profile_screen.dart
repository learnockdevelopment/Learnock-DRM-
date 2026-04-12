import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:learnock_drm/models/workspace.dart';
import 'package:learnock_drm/providers/workspace_provider.dart';
import 'package:learnock_drm/providers/language_provider.dart';
import 'package:learnock_drm/providers/theme_provider.dart';
import 'package:learnock_drm/widgets/premium_loader.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isGroupsLoading = false;
  List<dynamic> _groups = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchGroups());
  }

  Future<void> _fetchGroups() async {
    setState(() => _isGroupsLoading = true);
    try {
      final wp = Provider.of<WorkspaceProvider>(context, listen: false);
      final res = await wp.getGroups();
      if (mounted) setState(() => _groups = res['groups'] ?? []);
    } catch (_) {} finally {
      if (mounted) setState(() => _isGroupsLoading = false);
    }
  }

  Future<void> _joinGroup(Map<String, dynamic> g) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("JOIN GROUP", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        content: Text("Join group ${g['name']}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("CANCEL")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("YES, JOIN")),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isGroupsLoading = true);
    try {
      final wp = Provider.of<WorkspaceProvider>(context, listen: false);
      await wp.joinGroup(g['id']);
      await _fetchGroups(); // Refresh
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Joined successfully!"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isGroupsLoading = false);
    }
  }

  String _stripHtml(String? html) {
    if (html == null) return '';
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return html.replaceAll(exp, '').trim();
  }

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
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: isDestructive ? const Color(0xFFEF4444) : onSurface, fontSize: 18)),
        content: Text(message, style: TextStyle(color: onSurfaceVariant, fontSize: 14, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(lang.translate('cancel'), style: const TextStyle(color: Color(0xFF94A3B8)))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: isDestructive ? const Color(0xFFEF4444) : primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }
  
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

    // SPLIT GROUPS
    final joinedGroups = _groups.where((g) => g['is_member'] == true || g['is_member'] == 1).toList();
    final availableGroups = _groups.where((g) => g['is_member'] == false || g['is_member'] == 0 || g['is_member'] == null).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cardColor, elevation: 0,
        leading: IconButton(icon: Icon(isRTL ? Icons.arrow_back_ios_new_rounded : Icons.arrow_back_ios_rounded, color: onSurface, size: 18), onPressed: () => Navigator.pop(context)),
        title: Text(lang.translate('profile'), style: TextStyle(color: onSurface, fontSize: 16, fontWeight: FontWeight.w900)),
        centerTitle: true,
        actions: [IconButton(icon: Icon(theme.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: primaryColor, size: 20), onPressed: () => theme.toggleTheme())],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Center(
              child: Column(
                children: [
                   Stack(
                    children: [
                      Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: primaryColor.withOpacity(0.1), width: 2)), child: CircleAvatar(radius: 40, backgroundColor: primaryColor, child: Text((workspace?.studentName ?? 'S')[0], style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)))),
                      Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle, border: Border.all(color: cardColor, width: 2)), child: const Icon(Icons.verified_rounded, color: Colors.white, size: 14))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(workspace?.studentName ?? lang.translate('student_Learnock'), style: TextStyle(color: onSurface, fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(100)), child: Text(workspace?.email ?? '', style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.w900))),
                ],
              ),
            ),
            const SizedBox(height: 32),

            if (joinedGroups.isNotEmpty) ...[
              _buildSectionHeader(context, lang.translate('my_current_groups') ?? 'MY CURRENT GROUPS'),
              const SizedBox(height: 12),
              ...joinedGroups.map((g) => _buildGroupCard(context, g, primaryColor, onSurface, lang)),
              const SizedBox(height: 24),
            ],

            _buildSectionHeader(context, lang.translate('available_groups') ?? 'AVAILABLE BATCHES'),
            const SizedBox(height: 12),
            if (_isGroupsLoading) const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: PremiumLoader(size: 30))
            else if (availableGroups.isEmpty && joinedGroups.isEmpty) Text(lang.translate('no_groups') ?? 'No groups available', style: TextStyle(color: onSurface.withOpacity(0.3), fontSize: 11, fontWeight: FontWeight.bold))
            else if (availableGroups.isEmpty) Text(lang.translate('all_joined') ?? 'You have joined all available groups', style: TextStyle(color: onSurface.withOpacity(0.3), fontSize: 11, fontWeight: FontWeight.bold))
            else ...availableGroups.map((g) => _buildGroupCard(context, g, primaryColor, onSurface, lang)),
            
            const SizedBox(height: 32),

            _buildSectionHeader(context, lang.translate('academy')),
            const SizedBox(height: 12),
            if (workspace != null) _buildWorkspaceCard(context, workspace, true, lang, wp),

            if (otherWorkspaces.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSectionHeader(context, lang.translate('other_workspaces')),
              const SizedBox(height: 12),
              ...otherWorkspaces.map((w) => _buildWorkspaceCard(context, w, false, lang, wp)),
            ],

            const SizedBox(height: 32),
            _buildActionSection(context, wp, lang),

            const SizedBox(height: 32),
            _buildSectionHeader(context, lang.translate('tech_info')),
            const SizedBox(height: 12),
            _buildInfoCard(context, Icons.fingerprint_rounded, lang.translate('device_id'), wp.deviceId),
            _buildInfoCard(context, Icons.info_outline_rounded, lang.translate('version'), '1.0.14'),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard(BuildContext context, Map<String, dynamic> g, Color primary, Color onSurface, LanguageProvider lang) {
    bool isMember = g['is_member'] == true || g['is_member'] == 1 || g['is_member'] == 'true';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: isMember ? primary : Theme.of(context).dividerColor, width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.people_rounded, color: primary, size: 20)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g['name'] ?? '', style: TextStyle(color: onSurface, fontWeight: FontWeight.w900, fontSize: 15)),
                Text("${g['day_name'] ?? ''} @ ${g['session_time'] ?? ''}", style: TextStyle(color: onSurface.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold)),
              ])),
              if (isMember) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(100)), child: Text(lang.translate('joined') ?? "JOINED", style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)))
              else ElevatedButton(
                onPressed: () => _joinGroup(g),
                style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 16), elevation: 0),
                child: Text(lang.translate('select_action') ?? "SELECT", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          if (g['description'] != null) ...[
            const SizedBox(height: 12),
            Text(_stripHtml(g['description']), style: TextStyle(color: onSurface.withOpacity(0.4), fontSize: 11, height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final primaryColor = Theme.of(context).primaryColor;
    return Container(width: double.infinity, alignment: AlignmentDirectional.centerStart, child: Text(title.toUpperCase(), style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)));
  }

  Widget _buildActionSection(BuildContext context, WorkspaceProvider wp, LanguageProvider lang) {
    final primaryColor = Theme.of(context).primaryColor;
    return Column(
      children: [
        SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: () => Navigator.pushNamed(context, '/wallet'), style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 4, shadowColor: primaryColor.withOpacity(0.3)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.stars_rounded, size: 20), const SizedBox(width: 10), Text((lang.translate('redeem_voucher') ?? 'CHARGE WALLET').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5))]))),
        const SizedBox(height: 12),
        InkWell(onTap: () => Navigator.pushNamed(context, '/favorites'), borderRadius: BorderRadius.circular(16), child: Container(height: 56, width: double.infinity, decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.favorite_rounded, size: 20, color: primaryColor), const SizedBox(width: 10), Text((lang.translate('favorites') ?? 'FAVORITES').toUpperCase(), style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5))]))),
        const SizedBox(height: 12),
        InkWell(onTap: () => Navigator.pushNamed(context, '/onboarding'), borderRadius: BorderRadius.circular(16), child: Container(height: 56, width: double.infinity, decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.qr_code_scanner_rounded, size: 20, color: primaryColor), const SizedBox(width: 10), Text(lang.translate('scan_new_code').toUpperCase(), style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5))]))),
        const SizedBox(height: 12),
        InkWell(onTap: () async { final nav = Navigator.of(context); final confirmed = await _showPremiumAlert(context, title: lang.translate('logout'), message: lang.translate('logout_confirm'), confirmText: lang.translate('logout'), cancelText: lang.translate('cancel'), isDestructive: true); if (confirmed == true) { await wp.logout(); nav.pushNamedAndRemoveUntil('/onboarding', (route) => false); } }, borderRadius: BorderRadius.circular(12), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), width: double.infinity, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 18), const SizedBox(width: 10), Text(lang.translate('logout'), style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w900, fontSize: 14))]))),
      ],
    );
  }

  Widget _buildWorkspaceCard(BuildContext context, Workspace w, bool isActive, LanguageProvider lang, WorkspaceProvider wp) {
    final dividerColor = Theme.of(context).dividerColor;
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: isActive ? primaryColor : dividerColor, width: 2), boxShadow: isActive ? [BoxShadow(color: primaryColor.withOpacity(0.1), blurRadius: 20)] : null), child: InkWell(onTap: () async { await wp.switchWorkspace(w.id, context); if (context.mounted) Navigator.pushReplacementNamed(context, '/dashboard'); }, borderRadius: BorderRadius.circular(24), child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [if (w.logoUrl != null) Container(width: 48, height: 48, padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: primaryColor.withOpacity(0.1), width: 1)), child: ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.network(w.logoUrl!, fit: BoxFit.contain, errorBuilder: (c,e,s) => Icon(Icons.business_rounded, color: primaryColor)))) else Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: dividerColor, shape: BoxShape.circle), child: Icon(Icons.business_rounded, color: primaryColor, size: 24)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(w.name.toUpperCase(), style: TextStyle(color: onSurface, fontWeight: FontWeight.w900, fontSize: 14)), Text(w.host, style: TextStyle(color: primaryColor.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold))])), if (isActive) Icon(Icons.check_circle_rounded, color: primaryColor, size: 22) else const SizedBox(width: 22), const SizedBox(width: 12), IconButton(onPressed: () async { final isLast = wp.workspaces.length == 1; final confirmed = await _showPremiumAlert(context, title: isLast ? lang.translate('logout') : lang.translate('remove_academy'), message: isLast ? lang.translate('logout_confirm') : lang.translate('remove_academy_confirm'), confirmText: isLast ? lang.translate('logout') : lang.translate('remove'), cancelText: lang.translate('cancel'), isDestructive: true); if (confirmed == true) { if (isLast) { await wp.logout(); Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (route) => false); } else { await wp.removeWorkspace(w.id); } } }, icon: Icon(wp.workspaces.length == 1 ? Icons.logout_rounded : Icons.delete_outline_rounded, color: const Color(0xFFEF4444), size: 20), padding: EdgeInsets.zero, constraints: const BoxConstraints())]))));
  }

  Widget _buildInfoCard(BuildContext context, IconData icon, String label, String value) {
    final primaryColor = Theme.of(context).primaryColor;
    return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: primaryColor.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: primaryColor.withOpacity(0.05), width: 1)), child: Row(children: [Icon(icon, color: primaryColor.withOpacity(0.4), size: 18), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label.toUpperCase(), style: TextStyle(color: primaryColor.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)), Text(value, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 13))]))]));
  }
}

