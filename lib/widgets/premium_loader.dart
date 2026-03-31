import 'package:flutter/material.dart';
import 'package:learnock_drm/providers/workspace_provider.dart';
import 'package:learnock_drm/providers/language_provider.dart';
import 'package:provider/provider.dart' show Provider;

class PremiumLoader extends StatefulWidget {
  final Color? color;
  final bool useAppLogoOnly;
  const PremiumLoader({super.key, this.color, this.useAppLogoOnly = false});

  @override
  State<PremiumLoader> createState() => _PremiumLoaderState();
}

class _PremiumLoaderState extends State<PremiumLoader> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.color ?? Theme.of(context).primaryColor;
    final wp = Provider.of<WorkspaceProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);
    final activeWorkspace = wp.activeWorkspace;
    final logoUrl = activeWorkspace?.logoUrl;
    
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              ScaleTransition(
                scale: Tween<double>(begin: 0.8, end: 1.1).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)),
                child: Container(
                  width: 150, height: 150,
                  decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: primary.withOpacity(0.12), blurRadius: 60, spreadRadius: 10)]),
                ),
              ),
              
              SizedBox(
                width: 100, height: 100,
                child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(primary), backgroundColor: primary.withOpacity(0.05)),
              ),

              Container(
                width: 70, height: 70,
                child: (logoUrl != null && logoUrl.isNotEmpty && !widget.useAppLogoOnly) 
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(40),
                        child: Image.network(
                          logoUrl, 
                          fit: BoxFit.cover,
                          loadingBuilder: (c,w,p) => (p == null) ? w : Icon(Icons.school_rounded, color: primary, size: 40),
                          errorBuilder: (c,e,s) => Icon(Icons.school_rounded, color: primary, size: 40),
                        ),
                      )
                    : Image.asset('assets/logo.png', color: primary, fit: BoxFit.contain, errorBuilder: (c,e,s) => Icon(Icons.school_rounded, color: primary, size: 40)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            (activeWorkspace?.name ?? lang.translate("initializing_security")),
            style: TextStyle(color: primary.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
        ],
      ),
    );
  }
}
