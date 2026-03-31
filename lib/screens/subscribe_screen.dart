import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:learnock_drm/providers/language_provider.dart';
import 'package:learnock_drm/providers/workspace_provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class SubscribeScreen extends StatefulWidget {
  final Map<String, dynamic> course;
  const SubscribeScreen({super.key, required this.course});

  @override
  State<SubscribeScreen> createState() => _SubscribeScreenState();
}

class _SubscribeScreenState extends State<SubscribeScreen> {
  bool _isProcessing = false;

  void _showCodeDialog(BuildContext context, {required bool isVoucher}) {
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
            Text(
              isVoucher ? (lang.translate('redeem_voucher') ?? 'Top-up Wallet') : (lang.translate('redeem_coupon') ?? 'Activate Coupon'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              lang.translate('coupon_hint') ?? 'Enter your code here to proceed',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'XXXX-XXXX-XXXX',
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
                  final sm = ScaffoldMessenger.of(context);
                  nav.pop(); // Close sheet
                  setState(() => _isProcessing = true);
                  try {
                    final res = isVoucher 
                        ? await wp.redeemVoucher(controller.text)
                        : await wp.redeemCoupon(controller.text);
                    sm.showSnackBar(SnackBar(content: Text(res['message'] ?? 'Success!'), backgroundColor: Colors.green));
                    nav.pushReplacementNamed('/dashboard');
                  } catch (e) {
                    sm.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
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
                child: Text(lang.translate('confirm') ?? 'Confirm', style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleWalletCheckout() async {
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final nav = Navigator.of(context);
    final sm = ScaffoldMessenger.of(context);
    
    setState(() => _isProcessing = true);
    try {
      final cid = int.tryParse(widget.course['id']?.toString() ?? '0') ?? 0;
      final res = await wp.checkoutWallet(cid);
      sm.showSnackBar(SnackBar(content: Text(res['message'] ?? 'Enrolled successfully!'), backgroundColor: Colors.green));
      nav.pushReplacementNamed('/dashboard');
    } catch (e) {
      sm.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        widget.course['thumbnail_url'] ?? 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=800&q=80',
                        fit: BoxFit.cover,
                      ),
                      Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.8)]))),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
                        child: Text(
                          (lang.translate('premium_course') ?? 'Premium Course').toUpperCase(),
                          style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.course['title'] ?? '',
                        style: TextStyle(color: onSurface, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${widget.course['total_materials'] ?? 0} ${lang.translate('materials_count')}",
                        style: TextStyle(color: onSurface.withOpacity(0.4), fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 32),
                      
                      _buildFeatureRow(Icons.lock_clock_rounded, lang.translate('subscribe_to_unlock') ?? 'Subscribe to unlock all lessons', primaryColor, onSurface),
                      _buildFeatureRow(Icons.verified_user_rounded, lang.translate('lifetime_access') ?? 'Lifetime access to all materials', primaryColor, onSurface),
                      _buildFeatureRow(Icons.support_agent_rounded, lang.translate('teacher_support') ?? 'Direct support from the teacher', primaryColor, onSurface),
                      
                      const SizedBox(height: 48),
                      
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _handleWalletCheckout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.wallet_rounded),
                              const SizedBox(width: 12),
                              Text(lang.translate('redeem_wallet') ?? 'Subscribe using Wallet', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ),
                      

                    ],
                  ),
                ),
              ),
            ],
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

  Widget _buildFeatureRow(IconData icon, String text, Color primary, Color onSurface) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: TextStyle(color: onSurface, fontSize: 14, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
