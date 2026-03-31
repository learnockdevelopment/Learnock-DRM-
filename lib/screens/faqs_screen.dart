import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:learnock_drm/providers/workspace_provider.dart';
import 'package:learnock_drm/providers/language_provider.dart';
import 'dart:convert';

class FaqsScreen extends StatelessWidget {
  const FaqsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wp = Provider.of<WorkspaceProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);
    final workspace = wp.activeWorkspace;
    final isRTL = lang.currentLocale.languageCode == 'ar';
    final List faqs = json.decode(workspace?.faqsJson ?? '[]');
    
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            elevation: 0,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            leading: IconButton(
              icon: Icon(isRTL ? Icons.arrow_back_ios_new_rounded : Icons.arrow_back_ios_rounded, color: onSurface, size: 20), 
              onPressed: () => Navigator.pop(context)
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 16),
              title: Text(
                lang.translate('faqs') ?? 'Academy FAQ', 
                style: TextStyle(color: onSurface, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [primaryColor.withOpacity(0.08), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          
          if (faqs.isEmpty)
            SliverFillRemaining(
              child: Center(child: Text(lang.translate('no_faqs') ?? 'No questions available yet.', style: TextStyle(color: onSurface.withOpacity(0.4), fontWeight: FontWeight.bold))),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildFaqItem(faqs[index], primaryColor, onSurface, context, isRTL),
                  childCount: faqs.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(Map<String, dynamic> faq, Color primary, Color onSurface, BuildContext context, bool isRTL) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor, width: 2),
        boxShadow: [BoxShadow(color: primary.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          expandedAlignment: isRTL ? Alignment.topRight : Alignment.topLeft,
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          iconColor: primary,
          collapsedIconColor: onSurface.withOpacity(0.4),
          title: Text(
            faq['question'] ?? '', 
            style: TextStyle(color: onSurface, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: -0.2)
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: primary.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
              child: Text(
                faq['answer'] ?? '', 
                style: TextStyle(color: onSurface.withOpacity(0.8), fontSize: 13, height: 1.6, fontWeight: FontWeight.bold)
              ),
            ),
          ],
        ),
      ),
    );
  }
}
