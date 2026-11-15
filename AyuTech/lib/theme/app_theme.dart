import 'package:flutter/material.dart';

class AppPalette {
  // Primary greens / neutrals from the screenshot
  static const Color ayuGreen = Color(0xFF3A6631);
  static const Color ayuDarkGreen = Color(0xFF25482F);
  static const Color ayuAccent = Color(0xFFEFF7F0);
  static const Color ayuLightGreen = Color(0xFFEFFBF0);
  static const Color ayuPale = Color(0xFFF5F6F2);
  static const Color ayuCardBorder = Color(0xFFDFE8E0);
  static const Color ayuBadge = Color(0xFFDFF7E6);
  static const Color bodyBeige = Color(0xFFE7E5D1);
  static const Color sectionBg = Color(0xFFF1EFE0);

  // Accent red/orange for warnings
  static const Color warnRed = Color(0xFFDE6B6B);
  static const Color warnOrange = Color(0xFFFFB37A);

  // subtle shadow color
  static const Color shadow = Color(0x11000000);
}

class AppTheme {
  static ThemeData light(BuildContext context) {
    return ThemeData(
      scaffoldBackgroundColor: AppPalette.bodyBeige,
      primaryColor: AppPalette.ayuGreen,
      fontFamily: 'Inter', // optional: if not available, default is fine
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontSize: 20.0, fontWeight: FontWeight.w700, color: AppPalette.ayuDarkGreen),
        bodyMedium: TextStyle(fontSize: 15.0, color: Colors.black87),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.ayuGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
      ),
    );
  }

  // Reusable box decorations
  static BoxDecoration cardDecoration({Color? color}) {
    return BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(color: AppPalette.shadow, blurRadius: 8, offset: Offset(0, 4)),
      ],
      border: Border.all(color: AppPalette.ayuCardBorder.withOpacity(0.6)),
    );
  }

  static BoxDecoration sectionDecoration() {
    return BoxDecoration(
      color: AppPalette.sectionBg,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: AppPalette.shadow, blurRadius: 8, offset: Offset(0, 4))],
    );
  }

  static BoxDecoration smallPill({Color? bg}) {
    return BoxDecoration(
      color: bg ?? AppPalette.ayuPale,
      borderRadius: BorderRadius.circular(12),
    );
  }

  // a single place for small consistent shadows
  static const List<BoxShadow> subtleSh = [
    BoxShadow(color: AppPalette.shadow, blurRadius: 6, offset: Offset(0, 3))
  ];
}
