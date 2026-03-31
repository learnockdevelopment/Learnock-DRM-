import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:learnock_drm/providers/workspace_provider.dart';
import 'package:learnock_drm/providers/language_provider.dart';
import 'dart:convert';

class HighlightsScreen extends StatelessWidget {
  const HighlightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wp = Provider.of<WorkspaceProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);
    final workspace = wp.activeWorkspace;
    final isRTL = lang.currentLocale.languageCode == 'ar';
    
    final List features = json.decode(workspace?.featuresJson ?? '[]');
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            elevation: 0,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            leading: IconButton(
              icon: Icon(isRTL ? Icons.arrow_back_ios_new_rounded : Icons.arrow_back_ios_rounded, color: onSurface, size: 20), 
              onPressed: () => Navigator.pop(context)
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 20),
              centerTitle: false,
              title: Text(
                lang.translate('academy_highlights') ?? 'Academy Highlights',
                style: TextStyle(color: onSurface, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [primaryColor.withOpacity(0.12), Colors.transparent],
                  ),
                ),
                child: Center(
                  child: Icon(Icons.auto_awesome_rounded, color: primaryColor.withOpacity(0.1), size: 120),
                ),
              ),
            ),
          ),
          
          if (features.isEmpty)
            SliverFillRemaining(
              child: Center(child: Text(lang.translate('no_features') ?? 'No special highlights for this academy.', style: TextStyle(color: onSurface.withOpacity(0.4), fontWeight: FontWeight.bold))),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == 0 && (workspace?.heroSubtitle != null && workspace!.heroSubtitle!.isNotEmpty)) {
                       return _buildHeroDescCard(workspace.heroTitle ?? '', workspace.heroSubtitle!, primaryColor, onSurface, context);
                    }
                    final featIndex = (workspace?.heroSubtitle != null && workspace!.heroSubtitle!.isNotEmpty) ? index - 1 : index;
                    if (featIndex < 0 || featIndex >= features.length) return const SizedBox();
                    return _buildGlowingFeatureCard(features[featIndex], primaryColor, onSurface, context);
                  },
                  childCount: features.length + ((workspace?.heroSubtitle != null && workspace!.heroSubtitle!.isNotEmpty) ? 1 : 0),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroDescCard(String title, String desc, Color primary, Color onSurface, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: primary.withOpacity(0.2), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text((title.isNotEmpty ? title : 'Academy Vision').toUpperCase(), style: TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          Text(desc, style: TextStyle(color: onSurface, fontSize: 15, fontWeight: FontWeight.bold, height: 1.6)),
        ],
      ),
    );
  }

  Widget _buildGlowingFeatureCard(Map<String, dynamic> feat, Color primary, Color onSurface, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: primary.withOpacity(0.15), width: 2),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.08),
            blurRadius: 30,
            spreadRadius: -10,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            // DYNAMIC GRADIENT OVERLAY
            Positioned(
              top: -50, right: -50,
              child: Container(
                width: 150, height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [primary.withOpacity(0.08), Colors.transparent],
                  ),
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primary,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: primary.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5)),
                          ],
                        ),
                        child: const Icon(Icons.auto_awesome_mosaic_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Text(
                          feat['title'] ?? '',
                          style: TextStyle(color: onSurface, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: primary.withOpacity(0.05), width: 1),
                    ),
                    child: Text(
                      feat['description'] ?? '',
                      style: TextStyle(
                        color: onSurface.withOpacity(0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
