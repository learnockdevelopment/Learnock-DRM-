import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:learnock_drm/providers/language_provider.dart';
import 'package:learnock_drm/providers/workspace_provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _isProcessing = false;
  Map<String, dynamic>? _dashboardData;
  String _walletBalanceStr = "0.00";

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isProcessing = true);
    try {
      final wp = Provider.of<WorkspaceProvider>(context, listen: false);
      final data = await wp.getDashboard();
      String fetchedBalance = "0.00";
      try {
        final balRes = await wp.getWalletBalance();
        fetchedBalance = (balRes['balance'] ?? balRes['wallet_balance'] ?? "0").toString();
      } catch (_) {}

      if (mounted) setState(() { _dashboardData = data; _walletBalanceStr = fetchedBalance; });
    } catch (_) {}
    if (mounted) setState(() => _isProcessing = false);
  }

  void _showResultPrompt({required bool success, String? message}) {
    if (!mounted) return;
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: (success ? Colors.green : Colors.red).withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(success ? Icons.check_circle_rounded : Icons.error_rounded, color: success ? Colors.green : Colors.red, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              success ? (lang.translate('success') ?? 'Success!') : (lang.translate('failure') ?? 'Error'),
              style: TextStyle(color: onSurface, fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              message ?? (success ? lang.translate('operation_success') ?? 'Operation completed.' : lang.translate('operation_failure') ?? 'Please try again.'),
              style: TextStyle(color: onSurface.withOpacity(0.5), fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(lang.translate('confirm') ?? 'OK', style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVoucherDialog(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final primaryColor = Theme.of(context).primaryColor;
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 40),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.stars_rounded, color: primaryColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  lang.translate('redeem_voucher') ?? 'Top-up Wallet',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              lang.translate('coupon_hint') ?? 'Enter your recharge code here (Booklet Code)',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'MA-XXXX-XXXX',
                filled: true,
                fillColor: primaryColor.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                prefixIcon: Icon(Icons.qr_code_rounded, color: primaryColor),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (controller.text.isEmpty) return;
                  final nav = Navigator.of(context);
                  nav.pop(); // Close sheet
                  setState(() => _isProcessing = true);
                  try {
                    final res = await wp.redeemVoucher(controller.text);
                    _showResultPrompt(success: true, message: res['message']);
                    _fetch(); // Refresh balance
                  } catch (e) {
                    _showResultPrompt(success: false, message: e.toString());
                  } finally {
                    if (mounted) setState(() => _isProcessing = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(lang.translate('confirm') ?? 'RECHARGE NOW', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isRTL = lang.currentLocale.languageCode == 'ar';

    final dynamic rawData = _dashboardData?['data'] ?? _dashboardData;
    final Map<String, dynamic> statsData = (rawData is Map && rawData['stats'] is Map) ? rawData['stats'] : {};
    final Map<String, dynamic> userData = (rawData is Map && rawData['user'] is Map) ? rawData['user'] : {};
    
    // PRECISION DISCOVERY: Check User -> Statistics -> Root for balance
    final balanceVal = userData['wallet_balance'] ?? 
                       userData['balance'] ?? 
                       statsData['wallet_balance'] ?? 
                       statsData['balance'] ?? 
                       (rawData is Map ? rawData['wallet_balance'] : null) ?? 
                       (rawData is Map ? rawData['balance'] : null) ?? 
                       "0.00";
    
    final balance = _walletBalanceStr != "0.00" ? _walletBalanceStr : balanceVal.toString();

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(isRTL ? Icons.arrow_back_ios_new_rounded : Icons.arrow_back_ios_rounded, color: onSurface),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(lang.translate('wallet_balance') ?? 'Academy Wallet', style: TextStyle(color: onSurface, fontWeight: FontWeight.w900, fontSize: 18)),
            centerTitle: true,
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // PREMIUM BALANCE CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, primaryColor.withOpacity(0.8)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    children: [
                      Text(lang.translate('wallet_balance').toUpperCase(), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(balance, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
                          const SizedBox(width: 8),
                          Text(lang.translate('currency_le'), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // TRANSACTIONS BUTTON
                _buildActionCard(
                  title: lang.translate('transactions') ?? 'Transactions History',
                  subtitle: lang.translate('transactions_hint') ?? 'View all your wallet activity',
                  icon: Icons.receipt_long_rounded,
                  color: Colors.blueGrey,
                  onTap: () => Navigator.pushNamed(context, '/transactions'),
                ),
                
                const SizedBox(height: 16),
                
                // RECHARGE SECTION
                _buildActionCard(
                  title: lang.translate('redeem_voucher') ?? 'Top-up using Booklet Code',
                  subtitle: lang.translate('voucher_desc') ?? 'Use a recharge code to increase your balance',
                  icon: Icons.qr_code_scanner_rounded,
                  color: primaryColor,
                  onTap: () => _showVoucherDialog(context),
                ),
                
                const Spacer(),
                
                // SAFETY INFO
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: primaryColor.withOpacity(0.05), borderRadius: BorderRadius.circular(24)),
                  child: Row(
                    children: [
                      Icon(Icons.security_rounded, color: primaryColor, size: 24),
                      const SizedBox(width: 16),
                      Expanded(child: Text(lang.translate('wallet_secure') ?? 'Your transactions are encrypted and managed directly by the academy administration.', style: TextStyle(color: onSurface.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isProcessing)
          Container(
            color: Colors.black26,
            child: Center(child: SpinKitFadingCircle(color: primaryColor, size: 50)),
          ),
      ],
    );
  }

  Widget _buildActionCard({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Theme.of(context).dividerColor, width: 2),
        ),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: color, size: 28)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Theme.of(context).dividerColor),
          ],
        ),
      ),
    );
  }
}
