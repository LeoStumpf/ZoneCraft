// ZoneCraft — composable zone layers on OpenStreetMap.
// Copyright (C) 2026 Leo Stumpf <leo.m.stumpf@gmail.com>
//
// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or (at your
// option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
// License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';

/// The app's look, grounded in the map it draws.
///
/// OpenStreetMap's standard style (`openstreetmap-carto`) has a tone nothing
/// else has, and it comes from three measurable things: the ground is **warm
/// paper** (`@land-color #f2efe9`, nine points more red than blue) where Google
/// and Apple use cool neutrals; land cover is actually *painted*, so the map is
/// a quilt of many low-saturation hues rather than grey fields with a few
/// coloured roads; and the ink on top is strongly saturated and dark against
/// that desaturated ground.
///
/// ZoneCraft used to fight all three from one line — `ColorScheme.fromSeed`
/// with Material Blue. Seeding runs HCT tonal mapping, which tints the neutral
/// palette toward the seed hue, so every surface in the app was a faintly
/// blue-grey white floating on a warm beige map: chrome and map lit by
/// different suns. The scheme below is therefore **written out**, not seeded —
/// there is no way to tell a seed that `surface` must *be* `#F2EFE9`, and that
/// one fact is what the whole theme hangs on.
///
/// Two rules follow from it and are the part worth remembering:
///
/// 1. **Chrome reads the `ColorScheme`; ink drawn on the map reads the
///    constants here** ([kMapInk], [kMapPlate]). The tile source is
///    user-overridable (`AppSettings.tileUrlOverride`), so a crosshair or a
///    name plate must not assume paper underneath it.
/// 2. **Nothing that floats over the map may use a bare `surface`.** It is now
///    byte-identical to the map's land colour — contrast ratio 1.00 — so a
///    paper button on a paper map is invisible as a shape. Floating chrome goes
///    through [MapChrome], which is white with a hairline.

/// The colours osm-carto itself uses, so every choice below cites a source
/// instead of a hex. Values are taken verbatim from the style's CartoCSS
/// (`style.mss`, `landcover.mss`, `roads.mss`, `amenity-points.mss`).
abstract final class OsmPalette {
  // Ground.
  static const Color land = Color(0xFFF2EFE9);
  static const Color water = Color(0xFFAAD3DF);
  static const Color residential = Color(0xFFE0DFDF);
  static const Color residentialLine = Color(0xFFB9B9B9);
  static const Color transportArea = Color(0xFFE9E7E2);
  static const Color bareGround = Color(0xFFEEE5DC);
  static const Color buildingFill = Color(0xFFD9D0C9);
  static const Color roadFill = Color(0xFFFFFFFF);
  static const Color roadCasing = Color(0xFFBBBBBB);

  // Green cover.
  static const Color park = Color(0xFFC8FACC);
  static const Color grass = Color(0xFFCDEBB0);
  static const Color forest = Color(0xFFADD19E);
  static const Color forestText = Color(0xFF46673B);
  static const Color scrub = Color(0xFFC8D7AB);

  // Warm cover.
  static const Color farmland = Color(0xFFEEF0D5);
  static const Color farmyard = Color(0xFFF5DCBA);
  static const Color sand = Color(0xFFF5E9C6);
  static const Color landform = Color(0xFFD08F55);
  static const Color track = Color(0xFF996600);

  // Ink: the icon and label colours, which are where osm-carto keeps its
  // saturation.
  static const Color leisureGreen = Color(0xFF0D8216); // darken(@park, 60%)
  static const Color amenityBrown = Color(0xFF734A08);
  static const Color gastronomy = Color(0xFFC77400);
  static const Color transportation = Color(0xFF0092DA);
  static const Color shop = Color(0xFFAC39AC);
  static const Color health = Color(0xFFBF0000);
  static const Color office = Color(0xFF4863A0);
  static const Color airTransport = Color(0xFF8461C4);
  static const Color junctionText = Color(0xFF960000);
}

/// The halo behind text the app draws **on the map**, and the ink of it.
///
/// osm-carto draws its own labels as glyphs with an `rgba(255,255,255,0.6)`
/// halo — no border, no corner radius, no little card. The app's plates now do
/// the same, so a POI name reads as part of the map rather than as a widget
/// sitting on it. 0.72 rather than the style's 0.6 because a halo is optically
/// weaker than the filled rectangles these replaced.
///
/// Deliberately **constants, not `ColorScheme` reads**: see rule 1 above.
const Color kMapPlate = Color(0xB8FFFFFF);
const Color kMapInk = Color(0xDD1F1D19);

/// The white of a map-drawn disc — a crosshair, a drag handle, a cluster
/// badge. It is osm-carto's road fill: in this style's grammar, white is
/// already "the thing drawn on top of the land".
const Color kMapDisc = OsmPalette.roadFill;

/// [kMapInk] at the weight Material spells `black54`, for the secondary
/// strokes on the map (a guide line under a live measurement).
const Color kMapInkSoft = Color(0x8A1F1D19);

/// A warm lift for the few map-drawn discs that still need one (the cluster
/// badge). Material's `Colors.black26` is cold and reads blue over beige.
const Color kMapShadow = Color(0x332A2620);

/// The compass needle. Still red, now the map's red rather than Material's.
const Color kCompassNeedle = OsmPalette.health;

/// The one hairline colour, written once because three things cite it: the
/// scheme's `outline`, [MapChrome]'s border, and [kSwatchRing].
const Color _outline = Color(0xFF6F6961);

/// The dark scheme's hairline: warm, like everything else here, because a
/// neutral grey next to these browns reads blue.
const Color _outlineDark = Color(0xFF8A837A);

/// The ring around a colour swatch. A swatch shows a *data* colour, so its ring
/// has to read against both a saturated fill and paper — which Material's
/// `black26` does not, against a dark swatch. Not a `ColorScheme` read because
/// the smallest of these swatches is built without a context.
const Color kSwatchRing = _outline;

/// The halo itself, as text shadows. Five passes: four short offsets give the
/// glyph an edge, the wide blur gives it a ground.
const List<Shadow> kMapLabelHalo = <Shadow>[
  Shadow(color: kMapPlate, blurRadius: 1.5, offset: Offset(0.7, 0)),
  Shadow(color: kMapPlate, blurRadius: 1.5, offset: Offset(-0.7, 0)),
  Shadow(color: kMapPlate, blurRadius: 1.5, offset: Offset(0, 0.7)),
  Shadow(color: kMapPlate, blurRadius: 1.5, offset: Offset(0, -0.7)),
  Shadow(color: kMapPlate, blurRadius: 3.5),
];

/// Two colours Material has no role for.
///
/// `warning` is not `tertiary`: the brown is already what a pending import
/// draws in, and a warning that matches "unconfirmed import" would be saying
/// the wrong thing. osm-carto's own orange (`@gastronomy #C77400`) measures
/// 3.09:1 on paper and fails AA, so this is a darkened cousin at 4.73.
@immutable
class ZoneCraftColors extends ThemeExtension<ZoneCraftColors> {
  const ZoneCraftColors({required this.warning, required this.chromeBorder});

  final Color warning;

  /// The hairline that makes floating chrome a shape. Kept here as well as in
  /// the scheme so [MapChrome] and the FAB theme cite one thing.
  final Color chromeBorder;

  static const ZoneCraftColors light = ZoneCraftColors(
    warning: Color(0xFF9A5B00),
    chromeBorder: _outline,
  );

  /// The same two roles on a dark ground. The warning lifts to an amber that
  /// passes on the dark surfaces (the light one, #9A5B00, is 2.1:1 there and
  /// unreadable), and the hairline lightens rather than darkens — a border's
  /// job is to separate, and on dark that means going up, not down.
  static const ZoneCraftColors dark = ZoneCraftColors(
    warning: Color(0xFFE0A35C),
    chromeBorder: _outlineDark,
  );

  @override
  ZoneCraftColors copyWith({Color? warning, Color? chromeBorder}) =>
      ZoneCraftColors(
        warning: warning ?? this.warning,
        chromeBorder: chromeBorder ?? this.chromeBorder,
      );

  @override
  ZoneCraftColors lerp(ThemeExtension<ZoneCraftColors>? other, double t) {
    if (other is! ZoneCraftColors) return this;
    return ZoneCraftColors(
      warning: Color.lerp(warning, other.warning, t)!,
      chromeBorder: Color.lerp(chromeBorder, other.chromeBorder, t)!,
    );
  }
}

/// The warning colour, for the two import sheets that have one.
Color warningColor(BuildContext context) =>
    Theme.of(context).extension<ZoneCraftColors>()?.warning ??
    ZoneCraftColors.light.warning;

/// Every pair below was measured against the pairs the app actually renders;
/// the ratios are in the comments where the choice was not free.
const ColorScheme zoneCraftLight = ColorScheme(
  brightness: Brightness.light,

  // osm-carto's `darken(@park, 60%)` is #0D8216, which measures 4.33:1 on
  // paper and fails AA. One step darker passes on every surface tier the app
  // has (5.62 / 5.42 / 4.72), which matters because a TextButton label sits
  // inside raised banners.
  primary: Color(0xFF0B6E13),
  onPrimary: Color(0xFFFFFFFF), // 6.45 on primary
  primaryContainer: Color(0xFFCFE9CD), // park green, off its neon
  onPrimaryContainer: Color(0xFF08320C), // 11.0

  // The water blue as ink. #0092DA is 2.99 on paper — fails — so the fill
  // keeps the style's colour and the ink is a deeper cousin at 6.13.
  secondary: Color(0xFF005F87),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: OsmPalette.water,
  onSecondaryContainer: Color(0xFF05323F),

  tertiary: OsmPalette.amenityBrown, // 6.75 on paper, already AA-dark
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: OsmPalette.farmyard,
  onTertiaryContainer: Color(0xFF4A2F05),

  error: OsmPalette.health, // the style's own red, 5.69 on paper
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFF7DCD8), // paper-warm, not Material's #FFDAD6
  onErrorContainer: Color(0xFF5C0000),

  // The land colour. Everything else in this scheme follows from it — and see
  // rule 2 at the top before reaching for it over the map.
  surface: OsmPalette.land,
  onSurface: Color(0xFF1F1D19), // warm near-black; pure #000 reads blue here
  onSurfaceVariant: Color(0xFF5B564E), // 6.34 on paper, 5.32 at worst
  surfaceDim: Color(0xFFDED9CE),
  surfaceBright: Color(0xFFFAF8F4),
  surfaceContainerLowest: Color(0xFFFFFFFF), // road-fill white: floating chrome
  surfaceContainerLow: Color(0xFFF7F5F1),
  surfaceContainer: Color(0xFFEEEBE4),
  surfaceContainerHigh: Color(0xFFE8E4DB),
  surfaceContainerHighest: Color(0xFFE1DCD1),

  outline: _outline, // 4.73 on paper, >=3:1 over most cover
  outlineVariant: Color(0xFFCFC8BB), // dividers inside sheets only

  inverseSurface: Color(0xFF33302A), // snackbars, tooltips: warm charcoal
  onInverseSurface: OsmPalette.land,
  inversePrimary: Color(0xFF86D089),

  // Warm, because a black shadow on beige reads as a blue-grey smudge.
  shadow: Color(0xFF2A2620),
  scrim: Color(0xFF2A2620),
  surfaceTint: Color(0xFF0B6E13),
);

/// The same scheme after dark, for the screens that are **not** the map.
///
/// Derived from the light one rather than from Material's dark baseline: the
/// app's identity is osm-carto's warm paper, and the usual near-black
/// (#1C1B1F) is faintly blue, which next to these greens and browns reads as
/// a different app. So the ground is a warm charcoal — the same hue family as
/// `surface`, several steps down — and the accents lift instead of deepening,
/// because a colour chosen to be dark *on* paper (primary is #0B6E13, 5.6:1
/// there) is 1.4:1 on charcoal and effectively invisible.
///
/// This scheme never touches the map. See [zoneCraftDarkTheme].
const ColorScheme zoneCraftDark = ColorScheme(
  brightness: Brightness.dark,

  // The park green lifted until it carries on charcoal: 7.4:1 on `surface`.
  primary: Color(0xFF7FCB86),
  onPrimary: Color(0xFF05320C),
  primaryContainer: Color(0xFF17491D),
  onPrimaryContainer: Color(0xFFCFE9CD),

  // The water blue, lifted the same way. #005F87 is 1.6:1 here.
  secondary: Color(0xFF86CCE8),
  onSecondary: Color(0xFF04303F),
  secondaryContainer: Color(0xFF12414F),
  onSecondaryContainer: Color(0xFFC6E7F3),

  tertiary: Color(0xFFD9B382),
  onTertiary: Color(0xFF3A2405),
  tertiaryContainer: Color(0xFF52391A),
  onTertiaryContainer: Color(0xFFF5DCBA),

  // #BF0000 is 2.0:1 on charcoal; this is the same red opened up to 6.0.
  error: Color(0xFFF08A82),
  onError: Color(0xFF4A0000),
  errorContainer: Color(0xFF6B1410),
  onErrorContainer: Color(0xFFF7DCD8),

  // Warm charcoal, not Material's blue-black: the light scheme is built on
  // #F2EFE9, nine points more red than blue, and the dark one keeps that cast.
  surface: Color(0xFF1B1A17),
  onSurface: Color(0xFFE9E5DD),
  onSurfaceVariant: Color(0xFFBDB7AC), // 9.1 on surface
  surfaceDim: Color(0xFF141311),
  surfaceBright: Color(0xFF3A3833),
  surfaceContainerLowest: Color(0xFF100F0D),
  surfaceContainerLow: Color(0xFF232120),
  surfaceContainer: Color(0xFF272522),
  surfaceContainerHigh: Color(0xFF322F2B),
  surfaceContainerHighest: Color(0xFF3D3A35),

  outline: _outlineDark, // 4.6 on surface
  outlineVariant: Color(0xFF4A453E),

  inverseSurface: Color(0xFFE9E5DD),
  onInverseSurface: Color(0xFF1B1A17),
  inversePrimary: Color(0xFF0B6E13),

  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  surfaceTint: Color(0xFF7FCB86),
);

/// Corner radii, stepped down from Material's 28/16/12. A map is drawn with
/// rules and fine lines; the M3 pill is the loudest "stock Flutter" tell.
const double kRadiusLarge = 12;
const double kRadiusMedium = 8;
const double kRadiusSmall = 6;

/// Elevation for chrome that floats over the map. Low, because on beige a
/// shadow carries almost no signal — the hairline does the separating.
const double kMapChromeElevation = 1;

/// The light theme: the map's own colours, and the app's default.
ThemeData zoneCraftLightTheme() =>
    zoneCraftTheme(zoneCraftLight, ZoneCraftColors.light);

/// The dark theme, for **full screens only** — Settings, About, the button
/// guide, the OpenStreetMap outbox, the error screens.
///
/// The map itself stays light in every case, and so does anything floating
/// over it. That is not an omission: osm-carto has no dark variant, the tiles
/// are bright paper whatever the system says, and dark chrome on a bright map
/// is not dark mode, it is a contrast bug. `MapScreen` pins its own subtree to
/// [zoneCraftLightTheme] for exactly that reason — which also keeps the
/// sheets and dialogs it raises light, since they sit on top of the map.
///
/// The invariant that makes this safe already existed, written down when the
/// palette was built: *chrome reads the `ColorScheme`, ink drawn on the map
/// reads constants*. `kMapInk`, `kMapPlate` and [MapLabel] are constants and
/// are untouched here.
ThemeData zoneCraftDarkTheme() =>
    zoneCraftTheme(zoneCraftDark, ZoneCraftColors.dark);

ThemeData zoneCraftTheme(ColorScheme scheme, ZoneCraftColors colors) {
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final hairline = BorderSide(color: scheme.outline);
  final medium = BorderRadius.circular(kRadiusMedium);

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    // Material's black38 measures ~3.4:1 on paper, and this carries the "this
    // layer is hidden" labels — dimmed has to stay readable.
    disabledColor: scheme.brightness == Brightness.light
        ? const Color(0xFF6B655C)
        : const Color(0xFF8F887E),
    extensions: <ThemeExtension<dynamic>>[colors],

    // ---- surfaces and shapes ------------------------------------------------
    appBarTheme: AppBarThemeData(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      // Without this the bar turns mint the moment a list scrolls under it.
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      shape: Border(bottom: BorderSide(color: scheme.outlineVariant)),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      // Square-edged: a legend panel, not a floating card.
      shape: const RoundedRectangleBorder(),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      modalBackgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusLarge)),
      ),
      dragHandleColor: scheme.onSurfaceVariant,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusLarge),
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      // Outline, not shadow: the cartographic move.
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: medium,
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      // The on-map long-press menus are floating chrome and follow its rule.
      color: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: medium, side: hairline),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),

    // ---- controls -----------------------------------------------------------
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        // The map banners pack up to three of these beside ellipsising text;
        // Material's 64px minimum width is what squeezes those labels.
        minimumSize: const Size(48, 36),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        textStyle: const TextStyle(fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: medium),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: medium),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        side: hairline,
        shape: RoundedRectangleBorder(borderRadius: medium),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      selectedColor: scheme.secondaryContainer,
      checkmarkColor: scheme.onSecondaryContainer,
      side: hairline,
      shape: const StadiumBorder(),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: scheme.secondaryContainer,
        selectedForegroundColor: scheme.onSecondaryContainer,
        side: hairline,
        shape: RoundedRectangleBorder(borderRadius: medium),
      ),
    ),
    listTileTheme: ListTileThemeData(
      selectedTileColor: scheme.primaryContainer,
      selectedColor: scheme.onPrimaryContainer,
      iconColor: scheme.onSurfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusSmall),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      // Dense buys back vertical room inside the editor sheets, which are
      // capped at 60% of the viewport and clip silently.
      isDense: true,
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      border: OutlineInputBorder(
        borderRadius: medium,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: medium,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: medium,
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    switchTheme: SwitchThemeData(
      // Keeps "off" visible on paper.
      trackOutlineColor: WidgetStatePropertyAll<Color>(scheme.outline),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      inactiveTrackColor: scheme.outlineVariant,
      thumbColor: scheme.primary,
      overlayColor: scheme.primary.withValues(alpha: 0.12),
      valueIndicatorColor: scheme.inverseSurface,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.outlineVariant,
    ),

    // ---- feedback -----------------------------------------------------------
    snackBarTheme: SnackBarThemeData(
      // Snackbars are this app's "why did that button do nothing" channel and
      // they appear over the map; a dark warm plate is the only thing that
      // reads there.
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      actionTextColor: scheme.inversePrimary,
      behavior: SnackBarBehavior.floating,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: medium),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: scheme.inverseSurface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(kRadiusSmall),
      ),
      textStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 12),
      // Keeps a bottom-row FAB's tooltip on screen.
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 500),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      // M3's default here is `primaryContainer`, which in this scheme is a park
      // polygon — and near enough to the lit green that `_mapFab`'s on/off
      // distinction would read as two shades of pale green. White with a
      // hairline makes idle unmistakably chrome and lit unmistakably on.
      backgroundColor: scheme.surfaceContainerLowest,
      foregroundColor: scheme.onSurface,
      elevation: 3,
      focusElevation: 3,
      hoverElevation: 4,
      highlightElevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusLarge),
        side: hairline,
      ),
    ),
  );
}

/// Chrome that floats over the map: white, hairlined, barely lifted.
///
/// Every piece of it used to pick `colorScheme.surface` for itself. That worked
/// only by accident — the old seeded scheme produced a cool white that happened
/// to differ from beige. With `surface` now *being* the land colour the
/// accident is gone (1.00:1 against land, 1.02 against park), so the rule lives
/// here and the call sites stop deciding.
class MapChrome extends StatelessWidget {
  const MapChrome({
    super.key,
    required this.child,
    this.radius = kRadiusMedium,
    this.circle = false,
    this.color,
    this.borderColor,
    this.elevation = kMapChromeElevation,
    this.clipBehavior = Clip.none,
  });

  final Widget child;
  final double radius;
  final bool circle;

  /// Overridden only where the piece must *not* look like the others — the
  /// tile-failure banner, which keeps `errorContainer`.
  final Color? color;
  final Color? borderColor;
  final double elevation;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final side = BorderSide(color: borderColor ?? scheme.outline);
    return Material(
      color: color ?? scheme.surfaceContainerLowest,
      elevation: elevation,
      clipBehavior: clipBehavior,
      shape: circle
          ? CircleBorder(side: side)
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
              side: side,
            ),
      child: child,
    );
  }
}

/// A label the app draws **on the map**, haloed the way osm-carto haloes its
/// own — so a POI name reads as part of the map rather than as a small card
/// sitting on it.
class MapLabel extends StatelessWidget {
  const MapLabel(
    this.text, {
    super.key,
    this.fontSize = 10,
    this.fontWeight,
  });

  final String text;
  final double fontSize;
  final FontWeight? fontWeight;

  @override
  Widget build(BuildContext context) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.0,
          color: kMapInk,
          fontWeight: fontWeight,
          shadows: kMapLabelHalo,
        ),
      );
}
