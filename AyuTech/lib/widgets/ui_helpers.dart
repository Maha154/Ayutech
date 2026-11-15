import 'package:flutter/material.dart';
import 'package:ayutech/theme/app_theme.dart';

class SectionContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const SectionContainer({Key? key, required this.child, this.padding = const EdgeInsets.all(18)}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: AppTheme.sectionDecoration(),
      child: child,
    );
  }
}

class CardContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  const CardContainer({Key? key, required this.child, this.padding = const EdgeInsets.all(12), this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: AppTheme.cardDecoration(color: color),
      child: child,
    );
  }
}

class ChipBadge extends StatelessWidget {
  final String text;
  const ChipBadge(this.text, {Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppPalette.ayuBadge,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.ayuCardBorder),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF2C4A2C), fontWeight: FontWeight.w600)),
    );
  }
}
