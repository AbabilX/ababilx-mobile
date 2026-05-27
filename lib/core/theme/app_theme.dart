import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF141318), // Symmetrical flat M3 dark background

      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFD0BCFF), // M3 Primary
        onPrimary: Color(0xFF381E72),
        secondary: Color(0xFFCCC2DC), // M3 Secondary
        onSecondary: Color(0xFF332D41),
        surface: Color(0xFF1D1B20), // M3 Surface
        onSurface: Color(0xFFE6E1E5),
        surfaceContainerLow: Color(0xFF211F26), // M3 surface container
        surfaceContainer: Color(0xFF25232A),
        error: Color(0xFFF2B8B5),
        onError: Color(0xFF601410),
        outline: Color(0xFF35343B), // Symmetrical clean M3 border outline
      ),

      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 57,
          fontWeight: FontWeight.w800,
          color: const Color(0xFFE6E1E5),
        ),
        displayMedium: GoogleFonts.outfit(
          fontSize: 45,
          fontWeight: FontWeight.w800,
          color: const Color(0xFFE6E1E5),
        ),
        displaySmall: GoogleFonts.outfit(
          fontSize: 36,
          fontWeight: FontWeight.w800,
          color: const Color(0xFFE6E1E5),
        ),
        headlineLarge: GoogleFonts.outfit(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: const Color(0xFFE6E1E5),
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: const Color(0xFFE6E1E5),
        ),
        headlineSmall: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFE6E1E5),
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFE6E1E5),
        ),
        titleMedium: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFE6E1E5),
        ),
        titleSmall: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFE6E1E5),
        ),
      ).apply(
        bodyColor: const Color(0xFFE6E1E5),
        displayColor: const Color(0xFFE6E1E5),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Color(0xFFE6E1E5),
        ),
        iconTheme: IconThemeData(color: Color(0xFFE6E1E5)),
      ),

      cardTheme: CardThemeData(
        color: const Color(0xFF211F26), // Symmetrical surface sheet
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: Color(0xFF35343B), width: 1.0),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF25232A),
        labelStyle: const TextStyle(color: Color(0xFFCAC4D0), fontSize: 13, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: Color(0xFFCAC4D0), fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF35343B)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF35343B)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD0BCFF), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF2B8B5)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFF35343B),
        thickness: 0.8,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1D1B20),
        elevation: 0,
        height: 72,
        indicatorColor: const Color(0xFF381E72), // M3 Primary container indicator color
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFFE8DEF8), size: 24);
          }
          return const IconThemeData(color: Color(0xFFCAC4D0), size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.plusJakartaSans(
              color: const Color(0xFFE8DEF8),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            );
          }
          return GoogleFonts.plusJakartaSans(
            color: const Color(0xFFCAC4D0),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          );
        }),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFFE8DEF8);
          }
          return const Color(0xFFCAC4D0);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF381E72);
          }
          return const Color(0xFF2A282F);
        }),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF25232A),
        selectedColor: const Color(0xFF381E72),
        labelStyle: const TextStyle(color: Color(0xFFE6E1E5), fontSize: 13, fontWeight: FontWeight.w600),
        side: const BorderSide(color: Color(0xFF35343B)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)), // stadium shape for chip
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF211F26),
        contentTextStyle: const TextStyle(color: Color(0xFFE6E1E5)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF35343B)),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
