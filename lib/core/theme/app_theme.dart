import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand & Palette matching the Deep Crimson Wine theme
  static const Color primary = Color(0xFF7D0A26);         // Deep Crimson / Wine Red
  static const Color primaryDark = Color(0xFF5E071D);
  static const Color primaryLight = Color(0xFFFDF2F4);    // Light Rose Tint
  static const Color primaryBorder = Color(0xFFF4B5C3);   // Soft Crimson Border

  // Neutral Background & Surfaces - Ultra-clean modern canvas
  static const Color background = Color(0xFFF8FAFC);      // Clean Soft Off-White
  static const Color surface = Color(0xFFFFFFFF);         // Crisp White Card Surface
  static const Color surfaceLight = Color(0xFFF1F5F9);    // Soft Slate Gray
  static const Color surfaceBorder = Color(0xFFE2E8F0);   // Subtle Modern Border
  static const Color cardBorder = Color(0x0E000000);      // Hairline ambient border

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A);     // High Contrast Charcoal Slate
  static const Color textSecondary = Color(0xFF64748B);   // Modern Neutral Slate
  static const Color textMuted = Color(0xFF94A3B8);       // Muted Slate

  // Payment & Metric Pills
  static const Color cashGreen = Color(0xFF15803D);       // Forest Green
  static const Color cashGreenBg = Color(0xFFDCFCE7);     // Mint Pill Background
  static const Color upiBlue = Color(0xFF0369A1);         // Deep Sky Blue
  static const Color upiBlueBg = Color(0xFFE0F2FE);       // Light Blue Pill Background
  static const Color cardOrange = Color(0xFFC2410C);
  static const Color cardOrangeBg = Color(0xFFFFEDD5);

  // Smooth Curves & Glassmorphism Defaults
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusDefault = 16.0;
  static const double radiusLarge = 20.0;
  static const double radiusPill = 30.0;

  // Multi-layered diffuse ambient shadows for organic depth
  static const List<BoxShadow> shadowSoft = [
    BoxShadow(
      color: Color(0x06000000),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> shadowCard = [
    BoxShadow(
      color: Color(0x05000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 16,
      offset: Offset(0, 5),
    ),
  ];

  static const List<BoxShadow> shadowFloating = [
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 8,
      offset: Offset(0, 3),
    ),
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];

  static const List<BoxShadow> shadowGlow = [
    BoxShadow(
      color: Color(0x337D0A26),
      blurRadius: 14,
      offset: Offset(0, 4),
    ),
  ];

  static List<BoxShadow> glow(Color color, {double opacity = 0.25}) {
    return [
      BoxShadow(
        color: color.withAlpha((opacity * 255).toInt()),
        blurRadius: 14,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static BoxDecoration cardDecoration({
    Color? color,
    Color? borderColor,
    double radius = radiusDefault,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: color ?? surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? cardBorder,
        width: 0.9,
      ),
      boxShadow: shadows ?? shadowCard,
    );
  }

  static BoxDecoration glassDecoration({
    Color? color,
    Color? borderColor,
    double radius = radiusDefault,
    double opacity = 0.92,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: (color ?? surface).withAlpha((opacity * 255).toInt()),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? Colors.white.withAlpha(160),
        width: 1.0,
      ),
      boxShadow: shadows ?? shadowCard,
    );
  }

  // Table Status Colors
  static const Color tableAvailable = Color(0xFF16A34A);  // Emerald Green
  static const Color tableAvailableBg = Color(0xFFDCFCE7);
  static const Color tableOccupied = Color(0xFF7D0A26);   // Deep Crimson / Wine
  static const Color tableOccupiedBg = Color(0xFFFDF2F4);
  static const Color tableMerged = Color(0xFF7C3AED);     // Violet
  static const Color tableMergedBg = Color(0xFFF5F3FF);
  static const Color tableReserved = Color(0xFFDB2777);   // Pink

  // Order Type Colors
  static const Color orderDineIn = Color(0xFF7D0A26);     // Crimson
  static const Color orderWalkIn = Color(0xFFD97706);     // Amber
  static const Color orderParcel = Color(0xFF0D9488);     // Teal
  static const Color orderTakeAway = Color(0xFFD97706);   // Amber (backward compat)
  static const Color orderDelivery = Color(0xFF0284C7);   // Sky Blue

  // Shop Badge Colors (for instant visual identification)
  static const List<Color> shopColors = [
    Color(0xFFBE123C), // Shop 1: Thejaj (Flame Crimson)
    Color(0xFF059669), // Shop 2: Fruvia (Fresh Fruit Green)
    Color(0xFFD97706), // Shop 3: Chai Latte (Warm Caramel Amber)
    Color(0xFF9333EA), // Shop 4: Smoocho (Dessert Berry Violet)
    Color(0xFF475569), // Fallback / Inactive
  ];

  static Color getShopColor(int index) {
    return shopColors[index % shopColors.length];
  }

  static String getShopEmoji(int index, String shopName) {
    final lower = shopName.toLowerCase();
    if (lower.contains('thejaj') || lower.contains('shawarma') || lower.contains('shawaya')) return '🌯';
    if (lower.contains('fruvia') || lower.contains('juice') || lower.contains('shake')) return '🍹';
    if (lower.contains('chai') || lower.contains('latte') || lower.contains('tea') || lower.contains('coffee')) return '☕';
    if (lower.contains('smoocho') || lower.contains('kunafa') || lower.contains('dessert') || lower.contains('cake')) return '🍨';
    if (lower.contains('biriyani') || lower.contains('meal')) return '🍛';
    if (lower.contains('snack') || lower.contains('roll') || lower.contains('fry')) return '🥟';
    if (lower.contains('burger') || lower.contains('fast') || lower.contains('pizza')) return '🍔';
    return ['🌯', '🍹', '☕', '🍨'][index % 4];
  }

  static String getShopShortName(int index, String shopName) {
    final lower = shopName.toLowerCase();
    if (lower.contains('thejaj')) return 'Thejaj';
    if (lower.contains('fruvia')) return 'Fruvia';
    if (lower.contains('chai') || lower.contains('latte')) return 'Chai Latte';
    if (lower.contains('smoocho')) return 'Smoocho';
    if (lower.contains('biriyani') || lower.contains('meal')) return 'Thejaj';
    if (lower.contains('tea') || lower.contains('beverage') || lower.contains('coffee')) return 'Chai Latte';
    if (lower.contains('snack') || lower.contains('roll') || lower.contains('shawarma')) return 'Thejaj';
    if (lower.contains('burger') || lower.contains('fast')) return 'Smoocho';
    if (lower.contains('bake') || lower.contains('cake') || lower.contains('dessert')) return 'Smoocho';
    if (shopName.contains('-')) {
      return shopName.split('-').last.trim();
    }
    return shopName;
  }

  static IconData getShopIcon(int index, String shopName) {
    final lower = shopName.toLowerCase();
    if (lower.contains('thejaj') || lower.contains('shawarma') || lower.contains('shawaya')) return Icons.lunch_dining_rounded;
    if (lower.contains('fruvia') || lower.contains('juice') || lower.contains('shake')) return Icons.local_bar_rounded;
    if (lower.contains('chai') || lower.contains('latte') || lower.contains('tea') || lower.contains('coffee')) return Icons.local_cafe_rounded;
    if (lower.contains('smoocho') || lower.contains('kunafa') || lower.contains('dessert') || lower.contains('cake')) return Icons.icecream_rounded;
    if (lower.contains('biriyani') || lower.contains('meal')) return Icons.restaurant_rounded;
    return Icons.storefront_rounded;
  }

  static LinearGradient getShopGradient(int index) {
    switch (index % 4) {
      case 0: // Shop 1: Thejaj (Flame Crimson)
        return const LinearGradient(
          colors: [Color(0xFFBE123C), Color(0xFF881337)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 1: // Shop 2: Fruvia (Lush Fresh Green)
        return const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 2: // Shop 3: Chai Latte (Caramel Amber)
        return const LinearGradient(
          colors: [Color(0xFFD97706), Color(0xFFB45309)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 3: // Shop 4: Smoocho (Dessert Berry Violet)
      default:
        return const LinearGradient(
          colors: [Color(0xFF9333EA), Color(0xFF6B21A8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: primary,
        surface: surface,
        surfaceContainerHighest: surfaceLight,
        outline: surfaceBorder,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: cardBorder, width: 0.8),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 12,
        shadowColor: Colors.black.withAlpha(40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: cardBorder, width: 0.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primaryBorder, width: 1.1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: surfaceBorder, width: 0.9),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: surfaceBorder, width: 0.9),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: const TextStyle(color: textMuted, fontSize: 13),
      ),
      dividerTheme: const DividerThemeData(
        color: surfaceBorder,
        thickness: 0.8,
        space: 1,
      ),
    );
  }
}
