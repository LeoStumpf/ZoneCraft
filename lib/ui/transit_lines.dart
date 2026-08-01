import '../data/transit.dart';

/// Grouping and ordering for the transit "Lines" menu. Pure — no Flutter, no
/// drift — so the tri-state and natural-sort rules are unit-testable.
///
/// The unit the user thinks in is a **line** ("U6"), but OSM stores one relation
/// per *direction* (and often per variant), so a line is a set of routes sharing
/// a `ref`. Folding them means ~400 bus relations become ~200 rows and hiding
/// "U6" is one tap rather than two.

/// The minimum a route must expose to be grouped. Keeps this file independent
/// of the generated drift row class (and trivially constructible in tests).
abstract class TransitRouteLike {
  String get id;
  String get modeKey;
  String? get ref;
  String? get name;
  String? get operatorName;
  bool get isVisible;
  int? get colorArgb;
}

/// The visibility of a group of routes.
enum GroupState { none, some, all }

/// Tri-state over a group's routes: `all`/`none` when they agree, `some` when
/// mixed. An empty group reads as [GroupState.none].
GroupState groupState(Iterable<bool> visibilities) {
  var seenTrue = false, seenFalse = false;
  for (final v in visibilities) {
    if (v) {
      seenTrue = true;
    } else {
      seenFalse = true;
    }
    if (seenTrue && seenFalse) return GroupState.some;
  }
  return seenTrue ? GroupState.all : GroupState.none;
}

/// Maps [GroupState] to a `Checkbox(tristate: true)` value.
bool? groupCheckboxValue(GroupState s) => switch (s) {
      GroupState.all => true,
      GroupState.none => false,
      GroupState.some => null,
    };

/// One line: every route relation sharing a display name within a mode.
class TransitLine {
  TransitLine({
    required this.label,
    required this.modeKey,
    required this.routeIds,
    required this.visibleCount,
    this.colorArgb,
    this.subtitle,
  });

  /// What the row shows: the `ref` where there is one.
  final String label;
  final String modeKey;
  final List<String> routeIds;
  final int visibleCount;

  /// The first non-null route colour, or null to fall back to the mode palette.
  final int? colorArgb;

  /// The route name/operator, when it adds anything beyond [label].
  final String? subtitle;

  GroupState get state => visibleCount == 0
      ? GroupState.none
      : visibleCount == routeIds.length
          ? GroupState.all
          : GroupState.some;
}

/// One mode's lines.
class TransitLineGroup {
  TransitLineGroup({required this.mode, required this.lines});

  final TransitMode mode;
  final List<TransitLine> lines;

  int get routeCount =>
      lines.fold(0, (a, l) => a + l.routeIds.length);
  int get visibleRouteCount => lines.fold(0, (a, l) => a + l.visibleCount);
  List<String> get routeIds => [for (final l in lines) ...l.routeIds];

  GroupState get state => visibleRouteCount == 0
      ? GroupState.none
      : visibleRouteCount == routeCount
          ? GroupState.all
          : GroupState.some;
}

/// The display label for a route: its `ref`, else its `name`, else the OSM id.
String transitRouteLabel(TransitRouteLike r, {String? fallback}) {
  final ref = r.ref?.trim();
  if (ref != null && ref.isNotEmpty) return ref;
  final name = r.name?.trim();
  if (name != null && name.isNotEmpty) return name;
  return fallback ?? 'Route';
}

/// Compares line refs the way people read them: `2` before `10`, `U1` before
/// `U6`, `S8` before `S20`. Digit runs compare numerically, everything else
/// case-insensitively.
int compareRefs(String a, String b) {
  final ra = _tokens(a), rb = _tokens(b);
  for (var i = 0; i < ra.length && i < rb.length; i++) {
    final x = ra[i], y = rb[i];
    final int c;
    if (x.number != null && y.number != null) {
      c = x.number!.compareTo(y.number!);
    } else if (x.number != null) {
      c = -1; // numbers sort before words ("10" before "Express")
    } else if (y.number != null) {
      c = 1;
    } else {
      c = x.text.compareTo(y.text);
    }
    if (c != 0) return c;
  }
  return ra.length.compareTo(rb.length);
}

class _Token {
  const _Token(this.text, this.number);
  final String text;
  final int? number;
}

List<_Token> _tokens(String s) {
  final out = <_Token>[];
  final buf = StringBuffer();
  bool? inDigits;
  void flush() {
    if (buf.isEmpty) return;
    final t = buf.toString();
    out.add(_Token(t.toLowerCase(), inDigits == true ? int.tryParse(t) : null));
    buf.clear();
  }

  for (final rune in s.trim().runes) {
    final ch = String.fromCharCode(rune);
    final digit = ch.codeUnitAt(0) >= 0x30 && ch.codeUnitAt(0) <= 0x39;
    if (inDigits != null && digit != inDigits) flush();
    inDigits = digit;
    buf.write(ch);
  }
  flush();
  return out;
}

/// Groups [routes] by mode and then by line, filtered by a free-text [query]
/// matched against ref / name / operator.
///
/// Groups come back in [transitModes] order (rail before bus reads better than
/// alphabetical), and empty groups are dropped so the sheet only shows what was
/// actually imported.
List<TransitLineGroup> groupTransitLines(
  Iterable<TransitRouteLike> routes, {
  String query = '',
}) {
  final q = query.trim().toLowerCase();
  bool matches(TransitRouteLike r) {
    if (q.isEmpty) return true;
    for (final s in [r.ref, r.name, r.operatorName]) {
      if (s != null && s.toLowerCase().contains(q)) return true;
    }
    return false;
  }

  final byMode = <String, List<TransitRouteLike>>{};
  for (final r in routes) {
    if (!matches(r)) continue;
    byMode.putIfAbsent(r.modeKey, () => []).add(r);
  }

  final groups = <TransitLineGroup>[];
  for (final mode in transitModes) {
    final rs = byMode[mode.key];
    if (rs == null || rs.isEmpty) continue;

    final byLabel = <String, List<TransitRouteLike>>{};
    for (final r in rs) {
      byLabel.putIfAbsent(transitRouteLabel(r), () => []).add(r);
    }
    final lines = <TransitLine>[];
    byLabel.forEach((label, members) {
      // A ref-only label is terse; show the route name underneath when it adds
      // something (and only once, since both directions carry different names).
      final name = members
          .map((m) => m.name?.trim())
          .whereType<String>()
          .where((n) => n.isNotEmpty && n != label)
          .firstOrNull;
      lines.add(TransitLine(
        label: label,
        modeKey: mode.key,
        routeIds: [for (final m in members) m.id],
        visibleCount: members.where((m) => m.isVisible).length,
        colorArgb: members.map((m) => m.colorArgb).whereType<int>().firstOrNull,
        subtitle: name,
      ));
    });
    lines.sort((a, b) => compareRefs(a.label, b.label));
    groups.add(TransitLineGroup(mode: mode, lines: lines));
  }
  return groups;
}
