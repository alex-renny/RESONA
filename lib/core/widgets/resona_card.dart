import 'package:flutter/material.dart';
import '../theme/spacing.dart';

class ResonaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const ResonaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(ResonaSpacing.lg),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Card(child: Padding(padding: padding, child: child));
    if (onTap == null) return card;
    final radius = (Theme.of(context).cardTheme.shape as RoundedRectangleBorder?)
            ?.borderRadius as BorderRadius? ??
        BorderRadius.circular(12);
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: radius, onTap: onTap, child: card),
    );
  }
}
