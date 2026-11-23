// Adapted from QianYuan1437/OpenSpeak (MIT). See THIRD_PARTY_NOTICES.md.
import 'package:flutter/material.dart';

const kListening = Color(0xFFE5484D);
const kProcessing = Color(0xFFF5A524);

/// Accent presets offered in Settings (value = ARGB seed).
const kAccentPresets = <(int, String, String)>[
  (0xFF5B5BD6, '靛紫', 'Indigo'),
  (0xFF2563EB, '海蓝', 'Blue'),
  (0xFF0891B2, '湖青', 'Cyan'),
  (0xFF0D9488, '青绿', 'Teal'),
  (0xFF16A34A, '翠绿', 'Green'),
  (0xFFA47C16, '浅金', 'Gold'),
  (0xFFE11D48, '珊瑚', 'Rose'),
  (0xFF9333EA, '紫罗兰', 'Violet'),
];

const kDefaultAccent = 0xFFA47C16;

/// Shared corner radii so every control has the same rounded look.
const kRadius = 14.0;
const kCardRadius = 18.0;
final kControlShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(kRadius),
);

/// Height shared by buttons, dropdowns and segmented buttons.
const kControlHeight = 36.0;

/// Rounded highlight of an item inside a menu (inset from the menu edge).
final kMenuItemShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(kRadius - 4),
);

ThemeData buildTheme(Brightness b, {int accent = kDefaultAccent}) {
  final scheme = ColorScheme.fromSeed(seedColor: Color(accent), brightness: b);
  final dark = b == Brightness.dark;
  final background = Color.alphaBlend(
    scheme.primary.withValues(alpha: dark ? 0.04 : 0.025),
    dark ? const Color(0xFF111118) : const Color(0xFFF7F7FB),
  );
  final surface = dark
      ? Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.05),
          const Color(0xFF1B1B24),
        )
      : Colors.white;
  final fieldFill = scheme.surfaceContainerHighest.withValues(
    alpha: dark ? 0.45 : 0.55,
  );
  final outline = scheme.outlineVariant.withValues(alpha: dark ? 0.35 : 0.6);
  final menuStyle = MenuStyle(
    backgroundColor: WidgetStatePropertyAll(surface),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    elevation: const WidgetStatePropertyAll(6),
    shape: WidgetStatePropertyAll(kControlShape),
    side: WidgetStatePropertyAll(BorderSide(color: outline)),
    padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
    maximumSize: const WidgetStatePropertyAll(Size(double.infinity, 420)),
  );

  return ThemeData(
    visualDensity: VisualDensity.compact,
    useMaterial3: true,
    colorScheme: scheme,
    brightness: b,
    scaffoldBackgroundColor: background,
    canvasColor: surface,
    focusColor: scheme.primaryContainer.withValues(alpha: dark ? 0.35 : 0.55),
    hoverColor: scheme.primary.withValues(alpha: 0.06),
    highlightColor: scheme.primary.withValues(alpha: 0.08),
    splashColor: scheme.primary.withValues(alpha: 0.10),
    fontFamilyFallback: const [
      'Microsoft YaHei UI',
      'PingFang SC',
      'Noto Sans CJK SC',
      'Noto Sans SC',
    ],
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kCardRadius),
        side: BorderSide(color: outline),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      labelType: NavigationRailLabelType.all,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: scheme.primaryContainer,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: fieldFill,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(menuStyle: menuStyle),
    menuTheme: MenuThemeData(style: menuStyle),
    menuButtonTheme: MenuButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(kMenuItemShape),
        minimumSize: const WidgetStatePropertyAll(Size(160, kControlHeight)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12),
        ),
        overlayColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.pressed)
              ? scheme.primary.withValues(alpha: 0.12)
              : s.contains(WidgetState.hovered) ||
                    s.contains(WidgetState.focused)
              ? scheme.primary.withValues(alpha: 0.08)
              : null,
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shape: kControlShape,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kCardRadius + 4),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, kControlHeight)),
        shape: WidgetStatePropertyAll(kControlShape),
        side: WidgetStatePropertyAll(BorderSide(color: outline)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide(color: outline),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: kControlShape),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: kControlShape,
        side: BorderSide(color: outline),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: kControlShape),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF2A2A36) : const Color(0xFF30303A),
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    listTileTheme: ListTileThemeData(shape: kControlShape),
    sliderTheme: SliderThemeData(
      tickMarkShape: SliderTickMarkShape.noTickMark,
      showValueIndicator: ShowValueIndicator.onDrag,
    ),
    switchTheme: SwitchThemeData(
      thumbIcon: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? const Icon(Icons.check_rounded, size: 14)
            : null,
      ),
    ),
  );
}
