import 'package:flutter/material.dart';

class LibraryActionToast extends StatefulWidget {
  final String title;
  final String status;
  final String label;

  const LibraryActionToast({
    super.key,
    required this.title,
    required this.status,
    this.label = 'Added to library',
  });

  @override
  State<LibraryActionToast> createState() => _LibraryActionToastState();
}

class _LibraryActionToastState extends State<LibraryActionToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2100), () {
      if (mounted) _ctrl.reverse();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _LibraryActionToastConfig.forStatus(widget.status);

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(1.2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [
                  config.primary.withValues(alpha: 0.9),
                  config.secondary.withValues(alpha: 0.45),
                  Colors.white.withValues(alpha: 0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: config.primary.withValues(alpha: 0.28),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.36),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF121826).withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [config.primary, config.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                          color: config.primary.withValues(alpha: 0.36),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(config.icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.label,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.58),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.status,
                          style: TextStyle(
                            color: config.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: config.primary.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: config.primary,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryActionToastConfig {
  final Color primary;
  final Color secondary;
  final IconData icon;

  const _LibraryActionToastConfig({
    required this.primary,
    required this.secondary,
    required this.icon,
  });

  static _LibraryActionToastConfig forStatus(String status) {
    switch (status) {
      case 'Want to read':
        return const _LibraryActionToastConfig(
          primary: Color(0xFF8B5CF6),
          secondary: Color(0xFF6366F1),
          icon: Icons.bookmark_rounded,
        );
      case 'Reading':
        return const _LibraryActionToastConfig(
          primary: Color(0xFF14B8A6),
          secondary: Color(0xFF38BDF8),
          icon: Icons.auto_stories_rounded,
        );
      case 'Finished':
        return const _LibraryActionToastConfig(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFFE879F9),
          icon: Icons.check_circle_rounded,
        );
      default:
        return const _LibraryActionToastConfig(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF8B5CF6),
          icon: Icons.library_add_check_rounded,
        );
    }
  }
}
