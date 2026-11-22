import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    this.size = 36,
    this.showText = false,
    this.subtitle,
    this.logoUrl,
    super.key,
  });

  final double size;
  final bool showText;
  final String? subtitle;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF2E7D32),
                  const Color(0xFF1B5E20),
                ]
              : [
                  const Color(0xFF2E6930),
                  const Color(0xFF1B4332),
                ],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E6930).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: logoUrl != null && logoUrl!.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(size * 0.28),
                child: Image.network(
                  logoUrl!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _defaultIcon(size),
                ),
              )
            : _defaultIcon(size),
      ),
    );

    if (!showText) {
      return badge;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        badge,
        const SizedBox(width: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CableCare',
                  style: TextStyle(
                    fontSize: size * 0.52,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(left: 3, top: 4),
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2E6930),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            Text(
              subtitle ?? 'Network & Cable Operations',
              style: TextStyle(
                fontSize: size * 0.30,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static Widget _defaultIcon(double size) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.tv_rounded,
          color: Colors.white,
          size: size * 0.58,
        ),
        Positioned(
          right: size * 0.18,
          top: size * 0.18,
          child: Container(
            width: size * 0.18,
            height: size * 0.18,
            decoration: BoxDecoration(
              color: const Color(0xFF4ADE80),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
