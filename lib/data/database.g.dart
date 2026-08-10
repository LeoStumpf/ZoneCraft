// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $LayersTable extends Layers with TableInfo<$LayersTable, Layer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LayersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorArgbMeta = const VerificationMeta(
    'colorArgb',
  );
  @override
  late final GeneratedColumn<int> colorArgb = GeneratedColumn<int>(
    'color_argb',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isVisibleMeta = const VerificationMeta(
    'isVisible',
  );
  @override
  late final GeneratedColumn<bool> isVisible = GeneratedColumn<bool>(
    'is_visible',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_visible" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('circles'),
  );
  static const VerificationMeta _isInvertedMeta = const VerificationMeta(
    'isInverted',
  );
  @override
  late final GeneratedColumn<bool> isInverted = GeneratedColumn<bool>(
    'is_inverted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_inverted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _opacityMeta = const VerificationMeta(
    'opacity',
  );
  @override
  late final GeneratedColumn<double> opacity = GeneratedColumn<double>(
    'opacity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  static const VerificationMeta _borderLevelMeta = const VerificationMeta(
    'borderLevel',
  );
  @override
  late final GeneratedColumn<String> borderLevel = GeneratedColumn<String>(
    'border_level',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _borderFillAreasMeta = const VerificationMeta(
    'borderFillAreas',
  );
  @override
  late final GeneratedColumn<bool> borderFillAreas = GeneratedColumn<bool>(
    'border_fill_areas',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("border_fill_areas" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _borderShowNamesMeta = const VerificationMeta(
    'borderShowNames',
  );
  @override
  late final GeneratedColumn<bool> borderShowNames = GeneratedColumn<bool>(
    'border_show_names',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("border_show_names" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    colorArgb,
    isVisible,
    sortOrder,
    type,
    isInverted,
    opacity,
    borderLevel,
    borderFillAreas,
    borderShowNames,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'layers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Layer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_argb')) {
      context.handle(
        _colorArgbMeta,
        colorArgb.isAcceptableOrUnknown(data['color_argb']!, _colorArgbMeta),
      );
    } else if (isInserting) {
      context.missing(_colorArgbMeta);
    }
    if (data.containsKey('is_visible')) {
      context.handle(
        _isVisibleMeta,
        isVisible.isAcceptableOrUnknown(data['is_visible']!, _isVisibleMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('is_inverted')) {
      context.handle(
        _isInvertedMeta,
        isInverted.isAcceptableOrUnknown(data['is_inverted']!, _isInvertedMeta),
      );
    }
    if (data.containsKey('opacity')) {
      context.handle(
        _opacityMeta,
        opacity.isAcceptableOrUnknown(data['opacity']!, _opacityMeta),
      );
    }
    if (data.containsKey('border_level')) {
      context.handle(
        _borderLevelMeta,
        borderLevel.isAcceptableOrUnknown(
          data['border_level']!,
          _borderLevelMeta,
        ),
      );
    }
    if (data.containsKey('border_fill_areas')) {
      context.handle(
        _borderFillAreasMeta,
        borderFillAreas.isAcceptableOrUnknown(
          data['border_fill_areas']!,
          _borderFillAreasMeta,
        ),
      );
    }
    if (data.containsKey('border_show_names')) {
      context.handle(
        _borderShowNamesMeta,
        borderShowNames.isAcceptableOrUnknown(
          data['border_show_names']!,
          _borderShowNamesMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Layer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Layer(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorArgb: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_argb'],
      )!,
      isVisible: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_visible'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      isInverted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_inverted'],
      )!,
      opacity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}opacity'],
      )!,
      borderLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}border_level'],
      ),
      borderFillAreas: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}border_fill_areas'],
      )!,
      borderShowNames: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}border_show_names'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LayersTable createAlias(String alias) {
    return $LayersTable(attachedDatabase, alias);
  }
}

class Layer extends DataClass implements Insertable<Layer> {
  final String id;
  final String name;

  /// Fill/stroke colour as a packed ARGB int (see [Color.toARGB32]).
  final int colorArgb;
  final bool isVisible;
  final int sortOrder;

  /// Object kind this layer holds: 'circles' or 'planes'.
  final String type;

  /// When true, render the complement (outside the objects) instead.
  final bool isInverted;

  /// Layer opacity in [0, 1], multiplying the whole layer's paint (fills,
  /// band, outline / markers). 1 = fully opaque (the default); lower values let
  /// the map and lower layers show through.
  final double opacity;

  /// **`borders` layers only.** The OSM `admin_level` this layer holds, as a
  /// string ('2', '4', '6', '8', '9', '10'); null on every other type.
  ///
  /// Chosen when the layer is created and never changed: one layer holds one
  /// level, which is what makes "no two neighbours share a colour" well defined
  /// (areas of different levels nest rather than tile, so mixing them would
  /// make adjacency meaningless).
  final String? borderLevel;

  /// **`borders` only.** Fill each area with its [BorderAreas.colorIndex]
  /// palette colour, instead of drawing outlines alone.
  final bool borderFillAreas;

  /// **`borders` only.** Draw each area's name on a plate at its label anchor.
  final bool borderShowNames;
  final DateTime createdAt;
  const Layer({
    required this.id,
    required this.name,
    required this.colorArgb,
    required this.isVisible,
    required this.sortOrder,
    required this.type,
    required this.isInverted,
    required this.opacity,
    this.borderLevel,
    required this.borderFillAreas,
    required this.borderShowNames,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['color_argb'] = Variable<int>(colorArgb);
    map['is_visible'] = Variable<bool>(isVisible);
    map['sort_order'] = Variable<int>(sortOrder);
    map['type'] = Variable<String>(type);
    map['is_inverted'] = Variable<bool>(isInverted);
    map['opacity'] = Variable<double>(opacity);
    if (!nullToAbsent || borderLevel != null) {
      map['border_level'] = Variable<String>(borderLevel);
    }
    map['border_fill_areas'] = Variable<bool>(borderFillAreas);
    map['border_show_names'] = Variable<bool>(borderShowNames);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LayersCompanion toCompanion(bool nullToAbsent) {
    return LayersCompanion(
      id: Value(id),
      name: Value(name),
      colorArgb: Value(colorArgb),
      isVisible: Value(isVisible),
      sortOrder: Value(sortOrder),
      type: Value(type),
      isInverted: Value(isInverted),
      opacity: Value(opacity),
      borderLevel: borderLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(borderLevel),
      borderFillAreas: Value(borderFillAreas),
      borderShowNames: Value(borderShowNames),
      createdAt: Value(createdAt),
    );
  }

  factory Layer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Layer(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colorArgb: serializer.fromJson<int>(json['colorArgb']),
      isVisible: serializer.fromJson<bool>(json['isVisible']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      type: serializer.fromJson<String>(json['type']),
      isInverted: serializer.fromJson<bool>(json['isInverted']),
      opacity: serializer.fromJson<double>(json['opacity']),
      borderLevel: serializer.fromJson<String?>(json['borderLevel']),
      borderFillAreas: serializer.fromJson<bool>(json['borderFillAreas']),
      borderShowNames: serializer.fromJson<bool>(json['borderShowNames']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'colorArgb': serializer.toJson<int>(colorArgb),
      'isVisible': serializer.toJson<bool>(isVisible),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'type': serializer.toJson<String>(type),
      'isInverted': serializer.toJson<bool>(isInverted),
      'opacity': serializer.toJson<double>(opacity),
      'borderLevel': serializer.toJson<String?>(borderLevel),
      'borderFillAreas': serializer.toJson<bool>(borderFillAreas),
      'borderShowNames': serializer.toJson<bool>(borderShowNames),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Layer copyWith({
    String? id,
    String? name,
    int? colorArgb,
    bool? isVisible,
    int? sortOrder,
    String? type,
    bool? isInverted,
    double? opacity,
    Value<String?> borderLevel = const Value.absent(),
    bool? borderFillAreas,
    bool? borderShowNames,
    DateTime? createdAt,
  }) => Layer(
    id: id ?? this.id,
    name: name ?? this.name,
    colorArgb: colorArgb ?? this.colorArgb,
    isVisible: isVisible ?? this.isVisible,
    sortOrder: sortOrder ?? this.sortOrder,
    type: type ?? this.type,
    isInverted: isInverted ?? this.isInverted,
    opacity: opacity ?? this.opacity,
    borderLevel: borderLevel.present ? borderLevel.value : this.borderLevel,
    borderFillAreas: borderFillAreas ?? this.borderFillAreas,
    borderShowNames: borderShowNames ?? this.borderShowNames,
    createdAt: createdAt ?? this.createdAt,
  );
  Layer copyWithCompanion(LayersCompanion data) {
    return Layer(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorArgb: data.colorArgb.present ? data.colorArgb.value : this.colorArgb,
      isVisible: data.isVisible.present ? data.isVisible.value : this.isVisible,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      type: data.type.present ? data.type.value : this.type,
      isInverted: data.isInverted.present
          ? data.isInverted.value
          : this.isInverted,
      opacity: data.opacity.present ? data.opacity.value : this.opacity,
      borderLevel: data.borderLevel.present
          ? data.borderLevel.value
          : this.borderLevel,
      borderFillAreas: data.borderFillAreas.present
          ? data.borderFillAreas.value
          : this.borderFillAreas,
      borderShowNames: data.borderShowNames.present
          ? data.borderShowNames.value
          : this.borderShowNames,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Layer(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorArgb: $colorArgb, ')
          ..write('isVisible: $isVisible, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('type: $type, ')
          ..write('isInverted: $isInverted, ')
          ..write('opacity: $opacity, ')
          ..write('borderLevel: $borderLevel, ')
          ..write('borderFillAreas: $borderFillAreas, ')
          ..write('borderShowNames: $borderShowNames, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    colorArgb,
    isVisible,
    sortOrder,
    type,
    isInverted,
    opacity,
    borderLevel,
    borderFillAreas,
    borderShowNames,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Layer &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorArgb == this.colorArgb &&
          other.isVisible == this.isVisible &&
          other.sortOrder == this.sortOrder &&
          other.type == this.type &&
          other.isInverted == this.isInverted &&
          other.opacity == this.opacity &&
          other.borderLevel == this.borderLevel &&
          other.borderFillAreas == this.borderFillAreas &&
          other.borderShowNames == this.borderShowNames &&
          other.createdAt == this.createdAt);
}

class LayersCompanion extends UpdateCompanion<Layer> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> colorArgb;
  final Value<bool> isVisible;
  final Value<int> sortOrder;
  final Value<String> type;
  final Value<bool> isInverted;
  final Value<double> opacity;
  final Value<String?> borderLevel;
  final Value<bool> borderFillAreas;
  final Value<bool> borderShowNames;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LayersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorArgb = const Value.absent(),
    this.isVisible = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.type = const Value.absent(),
    this.isInverted = const Value.absent(),
    this.opacity = const Value.absent(),
    this.borderLevel = const Value.absent(),
    this.borderFillAreas = const Value.absent(),
    this.borderShowNames = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LayersCompanion.insert({
    required String id,
    required String name,
    required int colorArgb,
    this.isVisible = const Value.absent(),
    required int sortOrder,
    this.type = const Value.absent(),
    this.isInverted = const Value.absent(),
    this.opacity = const Value.absent(),
    this.borderLevel = const Value.absent(),
    this.borderFillAreas = const Value.absent(),
    this.borderShowNames = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       colorArgb = Value(colorArgb),
       sortOrder = Value(sortOrder);
  static Insertable<Layer> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? colorArgb,
    Expression<bool>? isVisible,
    Expression<int>? sortOrder,
    Expression<String>? type,
    Expression<bool>? isInverted,
    Expression<double>? opacity,
    Expression<String>? borderLevel,
    Expression<bool>? borderFillAreas,
    Expression<bool>? borderShowNames,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorArgb != null) 'color_argb': colorArgb,
      if (isVisible != null) 'is_visible': isVisible,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (type != null) 'type': type,
      if (isInverted != null) 'is_inverted': isInverted,
      if (opacity != null) 'opacity': opacity,
      if (borderLevel != null) 'border_level': borderLevel,
      if (borderFillAreas != null) 'border_fill_areas': borderFillAreas,
      if (borderShowNames != null) 'border_show_names': borderShowNames,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LayersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? colorArgb,
    Value<bool>? isVisible,
    Value<int>? sortOrder,
    Value<String>? type,
    Value<bool>? isInverted,
    Value<double>? opacity,
    Value<String?>? borderLevel,
    Value<bool>? borderFillAreas,
    Value<bool>? borderShowNames,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return LayersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colorArgb: colorArgb ?? this.colorArgb,
      isVisible: isVisible ?? this.isVisible,
      sortOrder: sortOrder ?? this.sortOrder,
      type: type ?? this.type,
      isInverted: isInverted ?? this.isInverted,
      opacity: opacity ?? this.opacity,
      borderLevel: borderLevel ?? this.borderLevel,
      borderFillAreas: borderFillAreas ?? this.borderFillAreas,
      borderShowNames: borderShowNames ?? this.borderShowNames,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorArgb.present) {
      map['color_argb'] = Variable<int>(colorArgb.value);
    }
    if (isVisible.present) {
      map['is_visible'] = Variable<bool>(isVisible.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (isInverted.present) {
      map['is_inverted'] = Variable<bool>(isInverted.value);
    }
    if (opacity.present) {
      map['opacity'] = Variable<double>(opacity.value);
    }
    if (borderLevel.present) {
      map['border_level'] = Variable<String>(borderLevel.value);
    }
    if (borderFillAreas.present) {
      map['border_fill_areas'] = Variable<bool>(borderFillAreas.value);
    }
    if (borderShowNames.present) {
      map['border_show_names'] = Variable<bool>(borderShowNames.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LayersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorArgb: $colorArgb, ')
          ..write('isVisible: $isVisible, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('type: $type, ')
          ..write('isInverted: $isInverted, ')
          ..write('opacity: $opacity, ')
          ..write('borderLevel: $borderLevel, ')
          ..write('borderFillAreas: $borderFillAreas, ')
          ..write('borderShowNames: $borderShowNames, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CirclesTable extends Circles with TableInfo<$CirclesTable, Circle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CirclesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _layerIdMeta = const VerificationMeta(
    'layerId',
  );
  @override
  late final GeneratedColumn<String> layerId = GeneratedColumn<String>(
    'layer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES layers (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _centerLatMeta = const VerificationMeta(
    'centerLat',
  );
  @override
  late final GeneratedColumn<double> centerLat = GeneratedColumn<double>(
    'center_lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _centerLngMeta = const VerificationMeta(
    'centerLng',
  );
  @override
  late final GeneratedColumn<double> centerLng = GeneratedColumn<double>(
    'center_lng',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _radiusMetersMeta = const VerificationMeta(
    'radiusMeters',
  );
  @override
  late final GeneratedColumn<double> radiusMeters = GeneratedColumn<double>(
    'radius_meters',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    layerId,
    centerLat,
    centerLng,
    radiusMeters,
    label,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'circles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Circle> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('layer_id')) {
      context.handle(
        _layerIdMeta,
        layerId.isAcceptableOrUnknown(data['layer_id']!, _layerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_layerIdMeta);
    }
    if (data.containsKey('center_lat')) {
      context.handle(
        _centerLatMeta,
        centerLat.isAcceptableOrUnknown(data['center_lat']!, _centerLatMeta),
      );
    } else if (isInserting) {
      context.missing(_centerLatMeta);
    }
    if (data.containsKey('center_lng')) {
      context.handle(
        _centerLngMeta,
        centerLng.isAcceptableOrUnknown(data['center_lng']!, _centerLngMeta),
      );
    } else if (isInserting) {
      context.missing(_centerLngMeta);
    }
    if (data.containsKey('radius_meters')) {
      context.handle(
        _radiusMetersMeta,
        radiusMeters.isAcceptableOrUnknown(
          data['radius_meters']!,
          _radiusMetersMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_radiusMetersMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Circle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Circle(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      layerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}layer_id'],
      )!,
      centerLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}center_lat'],
      )!,
      centerLng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}center_lng'],
      )!,
      radiusMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}radius_meters'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CirclesTable createAlias(String alias) {
    return $CirclesTable(attachedDatabase, alias);
  }
}

class Circle extends DataClass implements Insertable<Circle> {
  final String id;
  final String layerId;
  final double centerLat;
  final double centerLng;
  final double radiusMeters;
  final String? label;
  final DateTime createdAt;
  const Circle({
    required this.id,
    required this.layerId,
    required this.centerLat,
    required this.centerLng,
    required this.radiusMeters,
    this.label,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['layer_id'] = Variable<String>(layerId);
    map['center_lat'] = Variable<double>(centerLat);
    map['center_lng'] = Variable<double>(centerLng);
    map['radius_meters'] = Variable<double>(radiusMeters);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CirclesCompanion toCompanion(bool nullToAbsent) {
    return CirclesCompanion(
      id: Value(id),
      layerId: Value(layerId),
      centerLat: Value(centerLat),
      centerLng: Value(centerLng),
      radiusMeters: Value(radiusMeters),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      createdAt: Value(createdAt),
    );
  }

  factory Circle.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Circle(
      id: serializer.fromJson<String>(json['id']),
      layerId: serializer.fromJson<String>(json['layerId']),
      centerLat: serializer.fromJson<double>(json['centerLat']),
      centerLng: serializer.fromJson<double>(json['centerLng']),
      radiusMeters: serializer.fromJson<double>(json['radiusMeters']),
      label: serializer.fromJson<String?>(json['label']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'layerId': serializer.toJson<String>(layerId),
      'centerLat': serializer.toJson<double>(centerLat),
      'centerLng': serializer.toJson<double>(centerLng),
      'radiusMeters': serializer.toJson<double>(radiusMeters),
      'label': serializer.toJson<String?>(label),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Circle copyWith({
    String? id,
    String? layerId,
    double? centerLat,
    double? centerLng,
    double? radiusMeters,
    Value<String?> label = const Value.absent(),
    DateTime? createdAt,
  }) => Circle(
    id: id ?? this.id,
    layerId: layerId ?? this.layerId,
    centerLat: centerLat ?? this.centerLat,
    centerLng: centerLng ?? this.centerLng,
    radiusMeters: radiusMeters ?? this.radiusMeters,
    label: label.present ? label.value : this.label,
    createdAt: createdAt ?? this.createdAt,
  );
  Circle copyWithCompanion(CirclesCompanion data) {
    return Circle(
      id: data.id.present ? data.id.value : this.id,
      layerId: data.layerId.present ? data.layerId.value : this.layerId,
      centerLat: data.centerLat.present ? data.centerLat.value : this.centerLat,
      centerLng: data.centerLng.present ? data.centerLng.value : this.centerLng,
      radiusMeters: data.radiusMeters.present
          ? data.radiusMeters.value
          : this.radiusMeters,
      label: data.label.present ? data.label.value : this.label,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Circle(')
          ..write('id: $id, ')
          ..write('layerId: $layerId, ')
          ..write('centerLat: $centerLat, ')
          ..write('centerLng: $centerLng, ')
          ..write('radiusMeters: $radiusMeters, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    layerId,
    centerLat,
    centerLng,
    radiusMeters,
    label,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Circle &&
          other.id == this.id &&
          other.layerId == this.layerId &&
          other.centerLat == this.centerLat &&
          other.centerLng == this.centerLng &&
          other.radiusMeters == this.radiusMeters &&
          other.label == this.label &&
          other.createdAt == this.createdAt);
}

class CirclesCompanion extends UpdateCompanion<Circle> {
  final Value<String> id;
  final Value<String> layerId;
  final Value<double> centerLat;
  final Value<double> centerLng;
  final Value<double> radiusMeters;
  final Value<String?> label;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const CirclesCompanion({
    this.id = const Value.absent(),
    this.layerId = const Value.absent(),
    this.centerLat = const Value.absent(),
    this.centerLng = const Value.absent(),
    this.radiusMeters = const Value.absent(),
    this.label = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CirclesCompanion.insert({
    required String id,
    required String layerId,
    required double centerLat,
    required double centerLng,
    required double radiusMeters,
    this.label = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       layerId = Value(layerId),
       centerLat = Value(centerLat),
       centerLng = Value(centerLng),
       radiusMeters = Value(radiusMeters);
  static Insertable<Circle> custom({
    Expression<String>? id,
    Expression<String>? layerId,
    Expression<double>? centerLat,
    Expression<double>? centerLng,
    Expression<double>? radiusMeters,
    Expression<String>? label,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (layerId != null) 'layer_id': layerId,
      if (centerLat != null) 'center_lat': centerLat,
      if (centerLng != null) 'center_lng': centerLng,
      if (radiusMeters != null) 'radius_meters': radiusMeters,
      if (label != null) 'label': label,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CirclesCompanion copyWith({
    Value<String>? id,
    Value<String>? layerId,
    Value<double>? centerLat,
    Value<double>? centerLng,
    Value<double>? radiusMeters,
    Value<String?>? label,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return CirclesCompanion(
      id: id ?? this.id,
      layerId: layerId ?? this.layerId,
      centerLat: centerLat ?? this.centerLat,
      centerLng: centerLng ?? this.centerLng,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (layerId.present) {
      map['layer_id'] = Variable<String>(layerId.value);
    }
    if (centerLat.present) {
      map['center_lat'] = Variable<double>(centerLat.value);
    }
    if (centerLng.present) {
      map['center_lng'] = Variable<double>(centerLng.value);
    }
    if (radiusMeters.present) {
      map['radius_meters'] = Variable<double>(radiusMeters.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CirclesCompanion(')
          ..write('id: $id, ')
          ..write('layerId: $layerId, ')
          ..write('centerLat: $centerLat, ')
          ..write('centerLng: $centerLng, ')
          ..write('radiusMeters: $radiusMeters, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlanesTable extends Planes with TableInfo<$PlanesTable, Plane> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlanesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _layerIdMeta = const VerificationMeta(
    'layerId',
  );
  @override
  late final GeneratedColumn<String> layerId = GeneratedColumn<String>(
    'layer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES layers (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _aLatMeta = const VerificationMeta('aLat');
  @override
  late final GeneratedColumn<double> aLat = GeneratedColumn<double>(
    'a_lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aLngMeta = const VerificationMeta('aLng');
  @override
  late final GeneratedColumn<double> aLng = GeneratedColumn<double>(
    'a_lng',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bLatMeta = const VerificationMeta('bLat');
  @override
  late final GeneratedColumn<double> bLat = GeneratedColumn<double>(
    'b_lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bLngMeta = const VerificationMeta('bLng');
  @override
  late final GeneratedColumn<double> bLng = GeneratedColumn<double>(
    'b_lng',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nearAMeta = const VerificationMeta('nearA');
  @override
  late final GeneratedColumn<bool> nearA = GeneratedColumn<bool>(
    'near_a',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("near_a" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    layerId,
    aLat,
    aLng,
    bLat,
    bLng,
    nearA,
    label,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'planes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Plane> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('layer_id')) {
      context.handle(
        _layerIdMeta,
        layerId.isAcceptableOrUnknown(data['layer_id']!, _layerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_layerIdMeta);
    }
    if (data.containsKey('a_lat')) {
      context.handle(
        _aLatMeta,
        aLat.isAcceptableOrUnknown(data['a_lat']!, _aLatMeta),
      );
    } else if (isInserting) {
      context.missing(_aLatMeta);
    }
    if (data.containsKey('a_lng')) {
      context.handle(
        _aLngMeta,
        aLng.isAcceptableOrUnknown(data['a_lng']!, _aLngMeta),
      );
    } else if (isInserting) {
      context.missing(_aLngMeta);
    }
    if (data.containsKey('b_lat')) {
      context.handle(
        _bLatMeta,
        bLat.isAcceptableOrUnknown(data['b_lat']!, _bLatMeta),
      );
    } else if (isInserting) {
      context.missing(_bLatMeta);
    }
    if (data.containsKey('b_lng')) {
      context.handle(
        _bLngMeta,
        bLng.isAcceptableOrUnknown(data['b_lng']!, _bLngMeta),
      );
    } else if (isInserting) {
      context.missing(_bLngMeta);
    }
    if (data.containsKey('near_a')) {
      context.handle(
        _nearAMeta,
        nearA.isAcceptableOrUnknown(data['near_a']!, _nearAMeta),
      );
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Plane map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Plane(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      layerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}layer_id'],
      )!,
      aLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}a_lat'],
      )!,
      aLng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}a_lng'],
      )!,
      bLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}b_lat'],
      )!,
      bLng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}b_lng'],
      )!,
      nearA: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}near_a'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PlanesTable createAlias(String alias) {
    return $PlanesTable(attachedDatabase, alias);
  }
}

class Plane extends DataClass implements Insertable<Plane> {
  final String id;
  final String layerId;
  final double aLat;
  final double aLng;
  final double bLat;
  final double bLng;
  final bool nearA;
  final String? label;
  final DateTime createdAt;
  const Plane({
    required this.id,
    required this.layerId,
    required this.aLat,
    required this.aLng,
    required this.bLat,
    required this.bLng,
    required this.nearA,
    this.label,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['layer_id'] = Variable<String>(layerId);
    map['a_lat'] = Variable<double>(aLat);
    map['a_lng'] = Variable<double>(aLng);
    map['b_lat'] = Variable<double>(bLat);
    map['b_lng'] = Variable<double>(bLng);
    map['near_a'] = Variable<bool>(nearA);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PlanesCompanion toCompanion(bool nullToAbsent) {
    return PlanesCompanion(
      id: Value(id),
      layerId: Value(layerId),
      aLat: Value(aLat),
      aLng: Value(aLng),
      bLat: Value(bLat),
      bLng: Value(bLng),
      nearA: Value(nearA),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      createdAt: Value(createdAt),
    );
  }

  factory Plane.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Plane(
      id: serializer.fromJson<String>(json['id']),
      layerId: serializer.fromJson<String>(json['layerId']),
      aLat: serializer.fromJson<double>(json['aLat']),
      aLng: serializer.fromJson<double>(json['aLng']),
      bLat: serializer.fromJson<double>(json['bLat']),
      bLng: serializer.fromJson<double>(json['bLng']),
      nearA: serializer.fromJson<bool>(json['nearA']),
      label: serializer.fromJson<String?>(json['label']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'layerId': serializer.toJson<String>(layerId),
      'aLat': serializer.toJson<double>(aLat),
      'aLng': serializer.toJson<double>(aLng),
      'bLat': serializer.toJson<double>(bLat),
      'bLng': serializer.toJson<double>(bLng),
      'nearA': serializer.toJson<bool>(nearA),
      'label': serializer.toJson<String?>(label),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Plane copyWith({
    String? id,
    String? layerId,
    double? aLat,
    double? aLng,
    double? bLat,
    double? bLng,
    bool? nearA,
    Value<String?> label = const Value.absent(),
    DateTime? createdAt,
  }) => Plane(
    id: id ?? this.id,
    layerId: layerId ?? this.layerId,
    aLat: aLat ?? this.aLat,
    aLng: aLng ?? this.aLng,
    bLat: bLat ?? this.bLat,
    bLng: bLng ?? this.bLng,
    nearA: nearA ?? this.nearA,
    label: label.present ? label.value : this.label,
    createdAt: createdAt ?? this.createdAt,
  );
  Plane copyWithCompanion(PlanesCompanion data) {
    return Plane(
      id: data.id.present ? data.id.value : this.id,
      layerId: data.layerId.present ? data.layerId.value : this.layerId,
      aLat: data.aLat.present ? data.aLat.value : this.aLat,
      aLng: data.aLng.present ? data.aLng.value : this.aLng,
      bLat: data.bLat.present ? data.bLat.value : this.bLat,
      bLng: data.bLng.present ? data.bLng.value : this.bLng,
      nearA: data.nearA.present ? data.nearA.value : this.nearA,
      label: data.label.present ? data.label.value : this.label,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Plane(')
          ..write('id: $id, ')
          ..write('layerId: $layerId, ')
          ..write('aLat: $aLat, ')
          ..write('aLng: $aLng, ')
          ..write('bLat: $bLat, ')
          ..write('bLng: $bLng, ')
          ..write('nearA: $nearA, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, layerId, aLat, aLng, bLat, bLng, nearA, label, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Plane &&
          other.id == this.id &&
          other.layerId == this.layerId &&
          other.aLat == this.aLat &&
          other.aLng == this.aLng &&
          other.bLat == this.bLat &&
          other.bLng == this.bLng &&
          other.nearA == this.nearA &&
          other.label == this.label &&
          other.createdAt == this.createdAt);
}

class PlanesCompanion extends UpdateCompanion<Plane> {
  final Value<String> id;
  final Value<String> layerId;
  final Value<double> aLat;
  final Value<double> aLng;
  final Value<double> bLat;
  final Value<double> bLng;
  final Value<bool> nearA;
  final Value<String?> label;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PlanesCompanion({
    this.id = const Value.absent(),
    this.layerId = const Value.absent(),
    this.aLat = const Value.absent(),
    this.aLng = const Value.absent(),
    this.bLat = const Value.absent(),
    this.bLng = const Value.absent(),
    this.nearA = const Value.absent(),
    this.label = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlanesCompanion.insert({
    required String id,
    required String layerId,
    required double aLat,
    required double aLng,
    required double bLat,
    required double bLng,
    this.nearA = const Value.absent(),
    this.label = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       layerId = Value(layerId),
       aLat = Value(aLat),
       aLng = Value(aLng),
       bLat = Value(bLat),
       bLng = Value(bLng);
  static Insertable<Plane> custom({
    Expression<String>? id,
    Expression<String>? layerId,
    Expression<double>? aLat,
    Expression<double>? aLng,
    Expression<double>? bLat,
    Expression<double>? bLng,
    Expression<bool>? nearA,
    Expression<String>? label,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (layerId != null) 'layer_id': layerId,
      if (aLat != null) 'a_lat': aLat,
      if (aLng != null) 'a_lng': aLng,
      if (bLat != null) 'b_lat': bLat,
      if (bLng != null) 'b_lng': bLng,
      if (nearA != null) 'near_a': nearA,
      if (label != null) 'label': label,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlanesCompanion copyWith({
    Value<String>? id,
    Value<String>? layerId,
    Value<double>? aLat,
    Value<double>? aLng,
    Value<double>? bLat,
    Value<double>? bLng,
    Value<bool>? nearA,
    Value<String?>? label,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PlanesCompanion(
      id: id ?? this.id,
      layerId: layerId ?? this.layerId,
      aLat: aLat ?? this.aLat,
      aLng: aLng ?? this.aLng,
      bLat: bLat ?? this.bLat,
      bLng: bLng ?? this.bLng,
      nearA: nearA ?? this.nearA,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (layerId.present) {
      map['layer_id'] = Variable<String>(layerId.value);
    }
    if (aLat.present) {
      map['a_lat'] = Variable<double>(aLat.value);
    }
    if (aLng.present) {
      map['a_lng'] = Variable<double>(aLng.value);
    }
    if (bLat.present) {
      map['b_lat'] = Variable<double>(bLat.value);
    }
    if (bLng.present) {
      map['b_lng'] = Variable<double>(bLng.value);
    }
    if (nearA.present) {
      map['near_a'] = Variable<bool>(nearA.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlanesCompanion(')
          ..write('id: $id, ')
          ..write('layerId: $layerId, ')
          ..write('aLat: $aLat, ')
          ..write('aLng: $aLng, ')
          ..write('bLat: $bLat, ')
          ..write('bLng: $bLng, ')
          ..write('nearA: $nearA, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _uncertaintyMetersMeta = const VerificationMeta(
    'uncertaintyMeters',
  );
  @override
  late final GeneratedColumn<double> uncertaintyMeters =
      GeneratedColumn<double>(
        'uncertainty_meters',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(500),
      );
  static const VerificationMeta _lastLatMeta = const VerificationMeta(
    'lastLat',
  );
  @override
  late final GeneratedColumn<double> lastLat = GeneratedColumn<double>(
    'last_lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastLngMeta = const VerificationMeta(
    'lastLng',
  );
  @override
  late final GeneratedColumn<double> lastLng = GeneratedColumn<double>(
    'last_lng',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastZoomMeta = const VerificationMeta(
    'lastZoom',
  );
  @override
  late final GeneratedColumn<double> lastZoom = GeneratedColumn<double>(
    'last_zoom',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transportOverlayMeta = const VerificationMeta(
    'transportOverlay',
  );
  @override
  late final GeneratedColumn<bool> transportOverlay = GeneratedColumn<bool>(
    'transport_overlay',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("transport_overlay" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _transitEndpointMeta = const VerificationMeta(
    'transitEndpoint',
  );
  @override
  late final GeneratedColumn<String> transitEndpoint = GeneratedColumn<String>(
    'transit_endpoint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _poiCategoriesMeta = const VerificationMeta(
    'poiCategories',
  );
  @override
  late final GeneratedColumn<int> poiCategories = GeneratedColumn<int>(
    'poi_categories',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _borderLevelsMeta = const VerificationMeta(
    'borderLevels',
  );
  @override
  late final GeneratedColumn<int> borderLevels = GeneratedColumn<int>(
    'border_levels',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _toolsExpandedMeta = const VerificationMeta(
    'toolsExpanded',
  );
  @override
  late final GeneratedColumn<bool> toolsExpanded = GeneratedColumn<bool>(
    'tools_expanded',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("tools_expanded" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _basemapVisibleMeta = const VerificationMeta(
    'basemapVisible',
  );
  @override
  late final GeneratedColumn<bool> basemapVisible = GeneratedColumn<bool>(
    'basemap_visible',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("basemap_visible" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _basemapOpacityMeta = const VerificationMeta(
    'basemapOpacity',
  );
  @override
  late final GeneratedColumn<double> basemapOpacity = GeneratedColumn<double>(
    'basemap_opacity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uncertaintyMeters,
    lastLat,
    lastLng,
    lastZoom,
    transportOverlay,
    transitEndpoint,
    poiCategories,
    borderLevels,
    toolsExpanded,
    basemapVisible,
    basemapOpacity,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uncertainty_meters')) {
      context.handle(
        _uncertaintyMetersMeta,
        uncertaintyMeters.isAcceptableOrUnknown(
          data['uncertainty_meters']!,
          _uncertaintyMetersMeta,
        ),
      );
    }
    if (data.containsKey('last_lat')) {
      context.handle(
        _lastLatMeta,
        lastLat.isAcceptableOrUnknown(data['last_lat']!, _lastLatMeta),
      );
    }
    if (data.containsKey('last_lng')) {
      context.handle(
        _lastLngMeta,
        lastLng.isAcceptableOrUnknown(data['last_lng']!, _lastLngMeta),
      );
    }
    if (data.containsKey('last_zoom')) {
      context.handle(
        _lastZoomMeta,
        lastZoom.isAcceptableOrUnknown(data['last_zoom']!, _lastZoomMeta),
      );
    }
    if (data.containsKey('transport_overlay')) {
      context.handle(
        _transportOverlayMeta,
        transportOverlay.isAcceptableOrUnknown(
          data['transport_overlay']!,
          _transportOverlayMeta,
        ),
      );
    }
    if (data.containsKey('transit_endpoint')) {
      context.handle(
        _transitEndpointMeta,
        transitEndpoint.isAcceptableOrUnknown(
          data['transit_endpoint']!,
          _transitEndpointMeta,
        ),
      );
    }
    if (data.containsKey('poi_categories')) {
      context.handle(
        _poiCategoriesMeta,
        poiCategories.isAcceptableOrUnknown(
          data['poi_categories']!,
          _poiCategoriesMeta,
        ),
      );
    }
    if (data.containsKey('border_levels')) {
      context.handle(
        _borderLevelsMeta,
        borderLevels.isAcceptableOrUnknown(
          data['border_levels']!,
          _borderLevelsMeta,
        ),
      );
    }
    if (data.containsKey('tools_expanded')) {
      context.handle(
        _toolsExpandedMeta,
        toolsExpanded.isAcceptableOrUnknown(
          data['tools_expanded']!,
          _toolsExpandedMeta,
        ),
      );
    }
    if (data.containsKey('basemap_visible')) {
      context.handle(
        _basemapVisibleMeta,
        basemapVisible.isAcceptableOrUnknown(
          data['basemap_visible']!,
          _basemapVisibleMeta,
        ),
      );
    }
    if (data.containsKey('basemap_opacity')) {
      context.handle(
        _basemapOpacityMeta,
        basemapOpacity.isAcceptableOrUnknown(
          data['basemap_opacity']!,
          _basemapOpacityMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uncertaintyMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}uncertainty_meters'],
      )!,
      lastLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}last_lat'],
      ),
      lastLng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}last_lng'],
      ),
      lastZoom: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}last_zoom'],
      ),
      transportOverlay: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}transport_overlay'],
      )!,
      transitEndpoint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transit_endpoint'],
      ),
      poiCategories: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}poi_categories'],
      )!,
      borderLevels: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}border_levels'],
      )!,
      toolsExpanded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}tools_expanded'],
      )!,
      basemapVisible: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}basemap_visible'],
      )!,
      basemapOpacity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}basemap_opacity'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final int id;

  /// Global measurement uncertainty in metres; rendered as a lighter band.
  final double uncertaintyMeters;

  /// Last map camera, restored on launch. Null until the user has moved the map.
  final double? lastLat;
  final double? lastLng;
  final double? lastZoom;

  /// When true, transparent public-transport tile overlays (ÖPNVKarte +
  /// OpenRailwayMap) are drawn above the base map.
  final bool transportOverlay;

  /// The Overpass endpoint that last served a transit import, so the next one
  /// starts with the instance that was actually up. Null = start at the top of
  /// `transitEndpoints`.
  final String? transitEndpoint;

  /// Packed bitmask of enabled map-POI categories (see `poiCategories` in
  /// `overpass.dart`). 0 = none shown.
  final int poiCategories;

  /// Packed bitmask of enabled administrative-border levels (see `borderLevels`
  /// in `borders.dart`). 0 = none shown.
  final int borderLevels;

  /// Whether the right-side utility FABs are shown (vs. collapsed behind the
  /// expand/hide toggle). Persisted so the choice survives a relaunch.
  final bool toolsExpanded;

  /// Whether the base OSM tile layer is drawn. The base map behaves like a
  /// pinned bottom "layer": it can be hidden (this flag) but never deleted.
  final bool basemapVisible;

  /// Opacity of the base OSM tile layer in [0, 1] — how strongly the map shows
  /// through beneath the zone layers. 1 = fully opaque (the default).
  final double basemapOpacity;
  const AppSetting({
    required this.id,
    required this.uncertaintyMeters,
    this.lastLat,
    this.lastLng,
    this.lastZoom,
    required this.transportOverlay,
    this.transitEndpoint,
    required this.poiCategories,
    required this.borderLevels,
    required this.toolsExpanded,
    required this.basemapVisible,
    required this.basemapOpacity,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uncertainty_meters'] = Variable<double>(uncertaintyMeters);
    if (!nullToAbsent || lastLat != null) {
      map['last_lat'] = Variable<double>(lastLat);
    }
    if (!nullToAbsent || lastLng != null) {
      map['last_lng'] = Variable<double>(lastLng);
    }
    if (!nullToAbsent || lastZoom != null) {
      map['last_zoom'] = Variable<double>(lastZoom);
    }
    map['transport_overlay'] = Variable<bool>(transportOverlay);
    if (!nullToAbsent || transitEndpoint != null) {
      map['transit_endpoint'] = Variable<String>(transitEndpoint);
    }
    map['poi_categories'] = Variable<int>(poiCategories);
    map['border_levels'] = Variable<int>(borderLevels);
    map['tools_expanded'] = Variable<bool>(toolsExpanded);
    map['basemap_visible'] = Variable<bool>(basemapVisible);
    map['basemap_opacity'] = Variable<double>(basemapOpacity);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      id: Value(id),
      uncertaintyMeters: Value(uncertaintyMeters),
      lastLat: lastLat == null && nullToAbsent
          ? const Value.absent()
          : Value(lastLat),
      lastLng: lastLng == null && nullToAbsent
          ? const Value.absent()
          : Value(lastLng),
      lastZoom: lastZoom == null && nullToAbsent
          ? const Value.absent()
          : Value(lastZoom),
      transportOverlay: Value(transportOverlay),
      transitEndpoint: transitEndpoint == null && nullToAbsent
          ? const Value.absent()
          : Value(transitEndpoint),
      poiCategories: Value(poiCategories),
      borderLevels: Value(borderLevels),
      toolsExpanded: Value(toolsExpanded),
      basemapVisible: Value(basemapVisible),
      basemapOpacity: Value(basemapOpacity),
    );
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      id: serializer.fromJson<int>(json['id']),
      uncertaintyMeters: serializer.fromJson<double>(json['uncertaintyMeters']),
      lastLat: serializer.fromJson<double?>(json['lastLat']),
      lastLng: serializer.fromJson<double?>(json['lastLng']),
      lastZoom: serializer.fromJson<double?>(json['lastZoom']),
      transportOverlay: serializer.fromJson<bool>(json['transportOverlay']),
      transitEndpoint: serializer.fromJson<String?>(json['transitEndpoint']),
      poiCategories: serializer.fromJson<int>(json['poiCategories']),
      borderLevels: serializer.fromJson<int>(json['borderLevels']),
      toolsExpanded: serializer.fromJson<bool>(json['toolsExpanded']),
      basemapVisible: serializer.fromJson<bool>(json['basemapVisible']),
      basemapOpacity: serializer.fromJson<double>(json['basemapOpacity']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uncertaintyMeters': serializer.toJson<double>(uncertaintyMeters),
      'lastLat': serializer.toJson<double?>(lastLat),
      'lastLng': serializer.toJson<double?>(lastLng),
      'lastZoom': serializer.toJson<double?>(lastZoom),
      'transportOverlay': serializer.toJson<bool>(transportOverlay),
      'transitEndpoint': serializer.toJson<String?>(transitEndpoint),
      'poiCategories': serializer.toJson<int>(poiCategories),
      'borderLevels': serializer.toJson<int>(borderLevels),
      'toolsExpanded': serializer.toJson<bool>(toolsExpanded),
      'basemapVisible': serializer.toJson<bool>(basemapVisible),
      'basemapOpacity': serializer.toJson<double>(basemapOpacity),
    };
  }

  AppSetting copyWith({
    int? id,
    double? uncertaintyMeters,
    Value<double?> lastLat = const Value.absent(),
    Value<double?> lastLng = const Value.absent(),
    Value<double?> lastZoom = const Value.absent(),
    bool? transportOverlay,
    Value<String?> transitEndpoint = const Value.absent(),
    int? poiCategories,
    int? borderLevels,
    bool? toolsExpanded,
    bool? basemapVisible,
    double? basemapOpacity,
  }) => AppSetting(
    id: id ?? this.id,
    uncertaintyMeters: uncertaintyMeters ?? this.uncertaintyMeters,
    lastLat: lastLat.present ? lastLat.value : this.lastLat,
    lastLng: lastLng.present ? lastLng.value : this.lastLng,
    lastZoom: lastZoom.present ? lastZoom.value : this.lastZoom,
    transportOverlay: transportOverlay ?? this.transportOverlay,
    transitEndpoint: transitEndpoint.present
        ? transitEndpoint.value
        : this.transitEndpoint,
    poiCategories: poiCategories ?? this.poiCategories,
    borderLevels: borderLevels ?? this.borderLevels,
    toolsExpanded: toolsExpanded ?? this.toolsExpanded,
    basemapVisible: basemapVisible ?? this.basemapVisible,
    basemapOpacity: basemapOpacity ?? this.basemapOpacity,
  );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      id: data.id.present ? data.id.value : this.id,
      uncertaintyMeters: data.uncertaintyMeters.present
          ? data.uncertaintyMeters.value
          : this.uncertaintyMeters,
      lastLat: data.lastLat.present ? data.lastLat.value : this.lastLat,
      lastLng: data.lastLng.present ? data.lastLng.value : this.lastLng,
      lastZoom: data.lastZoom.present ? data.lastZoom.value : this.lastZoom,
      transportOverlay: data.transportOverlay.present
          ? data.transportOverlay.value
          : this.transportOverlay,
      transitEndpoint: data.transitEndpoint.present
          ? data.transitEndpoint.value
          : this.transitEndpoint,
      poiCategories: data.poiCategories.present
          ? data.poiCategories.value
          : this.poiCategories,
      borderLevels: data.borderLevels.present
          ? data.borderLevels.value
          : this.borderLevels,
      toolsExpanded: data.toolsExpanded.present
          ? data.toolsExpanded.value
          : this.toolsExpanded,
      basemapVisible: data.basemapVisible.present
          ? data.basemapVisible.value
          : this.basemapVisible,
      basemapOpacity: data.basemapOpacity.present
          ? data.basemapOpacity.value
          : this.basemapOpacity,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('id: $id, ')
          ..write('uncertaintyMeters: $uncertaintyMeters, ')
          ..write('lastLat: $lastLat, ')
          ..write('lastLng: $lastLng, ')
          ..write('lastZoom: $lastZoom, ')
          ..write('transportOverlay: $transportOverlay, ')
          ..write('transitEndpoint: $transitEndpoint, ')
          ..write('poiCategories: $poiCategories, ')
          ..write('borderLevels: $borderLevels, ')
          ..write('toolsExpanded: $toolsExpanded, ')
          ..write('basemapVisible: $basemapVisible, ')
          ..write('basemapOpacity: $basemapOpacity')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uncertaintyMeters,
    lastLat,
    lastLng,
    lastZoom,
    transportOverlay,
    transitEndpoint,
    poiCategories,
    borderLevels,
    toolsExpanded,
    basemapVisible,
    basemapOpacity,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.id == this.id &&
          other.uncertaintyMeters == this.uncertaintyMeters &&
          other.lastLat == this.lastLat &&
          other.lastLng == this.lastLng &&
          other.lastZoom == this.lastZoom &&
          other.transportOverlay == this.transportOverlay &&
          other.transitEndpoint == this.transitEndpoint &&
          other.poiCategories == this.poiCategories &&
          other.borderLevels == this.borderLevels &&
          other.toolsExpanded == this.toolsExpanded &&
          other.basemapVisible == this.basemapVisible &&
          other.basemapOpacity == this.basemapOpacity);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<int> id;
  final Value<double> uncertaintyMeters;
  final Value<double?> lastLat;
  final Value<double?> lastLng;
  final Value<double?> lastZoom;
  final Value<bool> transportOverlay;
  final Value<String?> transitEndpoint;
  final Value<int> poiCategories;
  final Value<int> borderLevels;
  final Value<bool> toolsExpanded;
  final Value<bool> basemapVisible;
  final Value<double> basemapOpacity;
  const AppSettingsCompanion({
    this.id = const Value.absent(),
    this.uncertaintyMeters = const Value.absent(),
    this.lastLat = const Value.absent(),
    this.lastLng = const Value.absent(),
    this.lastZoom = const Value.absent(),
    this.transportOverlay = const Value.absent(),
    this.transitEndpoint = const Value.absent(),
    this.poiCategories = const Value.absent(),
    this.borderLevels = const Value.absent(),
    this.toolsExpanded = const Value.absent(),
    this.basemapVisible = const Value.absent(),
    this.basemapOpacity = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.uncertaintyMeters = const Value.absent(),
    this.lastLat = const Value.absent(),
    this.lastLng = const Value.absent(),
    this.lastZoom = const Value.absent(),
    this.transportOverlay = const Value.absent(),
    this.transitEndpoint = const Value.absent(),
    this.poiCategories = const Value.absent(),
    this.borderLevels = const Value.absent(),
    this.toolsExpanded = const Value.absent(),
    this.basemapVisible = const Value.absent(),
    this.basemapOpacity = const Value.absent(),
  });
  static Insertable<AppSetting> custom({
    Expression<int>? id,
    Expression<double>? uncertaintyMeters,
    Expression<double>? lastLat,
    Expression<double>? lastLng,
    Expression<double>? lastZoom,
    Expression<bool>? transportOverlay,
    Expression<String>? transitEndpoint,
    Expression<int>? poiCategories,
    Expression<int>? borderLevels,
    Expression<bool>? toolsExpanded,
    Expression<bool>? basemapVisible,
    Expression<double>? basemapOpacity,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uncertaintyMeters != null) 'uncertainty_meters': uncertaintyMeters,
      if (lastLat != null) 'last_lat': lastLat,
      if (lastLng != null) 'last_lng': lastLng,
      if (lastZoom != null) 'last_zoom': lastZoom,
      if (transportOverlay != null) 'transport_overlay': transportOverlay,
      if (transitEndpoint != null) 'transit_endpoint': transitEndpoint,
      if (poiCategories != null) 'poi_categories': poiCategories,
      if (borderLevels != null) 'border_levels': borderLevels,
      if (toolsExpanded != null) 'tools_expanded': toolsExpanded,
      if (basemapVisible != null) 'basemap_visible': basemapVisible,
      if (basemapOpacity != null) 'basemap_opacity': basemapOpacity,
    });
  }

  AppSettingsCompanion copyWith({
    Value<int>? id,
    Value<double>? uncertaintyMeters,
    Value<double?>? lastLat,
    Value<double?>? lastLng,
    Value<double?>? lastZoom,
    Value<bool>? transportOverlay,
    Value<String?>? transitEndpoint,
    Value<int>? poiCategories,
    Value<int>? borderLevels,
    Value<bool>? toolsExpanded,
    Value<bool>? basemapVisible,
    Value<double>? basemapOpacity,
  }) {
    return AppSettingsCompanion(
      id: id ?? this.id,
      uncertaintyMeters: uncertaintyMeters ?? this.uncertaintyMeters,
      lastLat: lastLat ?? this.lastLat,
      lastLng: lastLng ?? this.lastLng,
      lastZoom: lastZoom ?? this.lastZoom,
      transportOverlay: transportOverlay ?? this.transportOverlay,
      transitEndpoint: transitEndpoint ?? this.transitEndpoint,
      poiCategories: poiCategories ?? this.poiCategories,
      borderLevels: borderLevels ?? this.borderLevels,
      toolsExpanded: toolsExpanded ?? this.toolsExpanded,
      basemapVisible: basemapVisible ?? this.basemapVisible,
      basemapOpacity: basemapOpacity ?? this.basemapOpacity,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uncertaintyMeters.present) {
      map['uncertainty_meters'] = Variable<double>(uncertaintyMeters.value);
    }
    if (lastLat.present) {
      map['last_lat'] = Variable<double>(lastLat.value);
    }
    if (lastLng.present) {
      map['last_lng'] = Variable<double>(lastLng.value);
    }
    if (lastZoom.present) {
      map['last_zoom'] = Variable<double>(lastZoom.value);
    }
    if (transportOverlay.present) {
      map['transport_overlay'] = Variable<bool>(transportOverlay.value);
    }
    if (transitEndpoint.present) {
      map['transit_endpoint'] = Variable<String>(transitEndpoint.value);
    }
    if (poiCategories.present) {
      map['poi_categories'] = Variable<int>(poiCategories.value);
    }
    if (borderLevels.present) {
      map['border_levels'] = Variable<int>(borderLevels.value);
    }
    if (toolsExpanded.present) {
      map['tools_expanded'] = Variable<bool>(toolsExpanded.value);
    }
    if (basemapVisible.present) {
      map['basemap_visible'] = Variable<bool>(basemapVisible.value);
    }
    if (basemapOpacity.present) {
      map['basemap_opacity'] = Variable<double>(basemapOpacity.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('id: $id, ')
          ..write('uncertaintyMeters: $uncertaintyMeters, ')
          ..write('lastLat: $lastLat, ')
          ..write('lastLng: $lastLng, ')
          ..write('lastZoom: $lastZoom, ')
          ..write('transportOverlay: $transportOverlay, ')
          ..write('transitEndpoint: $transitEndpoint, ')
          ..write('poiCategories: $poiCategories, ')
          ..write('borderLevels: $borderLevels, ')
          ..write('toolsExpanded: $toolsExpanded, ')
          ..write('basemapVisible: $basemapVisible, ')
          ..write('basemapOpacity: $basemapOpacity')
          ..write(')'))
        .toString();
  }
}

class $SubspacesTable extends Subspaces
    with TableInfo<$SubspacesTable, Subspace> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubspacesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _layerIdMeta = const VerificationMeta(
    'layerId',
  );
  @override
  late final GeneratedColumn<String> layerId = GeneratedColumn<String>(
    'layer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES layers (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, layerId, label, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subspaces';
  @override
  VerificationContext validateIntegrity(
    Insertable<Subspace> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('layer_id')) {
      context.handle(
        _layerIdMeta,
        layerId.isAcceptableOrUnknown(data['layer_id']!, _layerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_layerIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Subspace map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Subspace(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      layerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}layer_id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SubspacesTable createAlias(String alias) {
    return $SubspacesTable(attachedDatabase, alias);
  }
}

class Subspace extends DataClass implements Insertable<Subspace> {
  final String id;
  final String layerId;
  final String? label;
  final DateTime createdAt;
  const Subspace({
    required this.id,
    required this.layerId,
    this.label,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['layer_id'] = Variable<String>(layerId);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SubspacesCompanion toCompanion(bool nullToAbsent) {
    return SubspacesCompanion(
      id: Value(id),
      layerId: Value(layerId),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      createdAt: Value(createdAt),
    );
  }

  factory Subspace.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Subspace(
      id: serializer.fromJson<String>(json['id']),
      layerId: serializer.fromJson<String>(json['layerId']),
      label: serializer.fromJson<String?>(json['label']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'layerId': serializer.toJson<String>(layerId),
      'label': serializer.toJson<String?>(label),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Subspace copyWith({
    String? id,
    String? layerId,
    Value<String?> label = const Value.absent(),
    DateTime? createdAt,
  }) => Subspace(
    id: id ?? this.id,
    layerId: layerId ?? this.layerId,
    label: label.present ? label.value : this.label,
    createdAt: createdAt ?? this.createdAt,
  );
  Subspace copyWithCompanion(SubspacesCompanion data) {
    return Subspace(
      id: data.id.present ? data.id.value : this.id,
      layerId: data.layerId.present ? data.layerId.value : this.layerId,
      label: data.label.present ? data.label.value : this.label,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Subspace(')
          ..write('id: $id, ')
          ..write('layerId: $layerId, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, layerId, label, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Subspace &&
          other.id == this.id &&
          other.layerId == this.layerId &&
          other.label == this.label &&
          other.createdAt == this.createdAt);
}

class SubspacesCompanion extends UpdateCompanion<Subspace> {
  final Value<String> id;
  final Value<String> layerId;
  final Value<String?> label;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SubspacesCompanion({
    this.id = const Value.absent(),
    this.layerId = const Value.absent(),
    this.label = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SubspacesCompanion.insert({
    required String id,
    required String layerId,
    this.label = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       layerId = Value(layerId);
  static Insertable<Subspace> custom({
    Expression<String>? id,
    Expression<String>? layerId,
    Expression<String>? label,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (layerId != null) 'layer_id': layerId,
      if (label != null) 'label': label,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SubspacesCompanion copyWith({
    Value<String>? id,
    Value<String>? layerId,
    Value<String?>? label,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return SubspacesCompanion(
      id: id ?? this.id,
      layerId: layerId ?? this.layerId,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (layerId.present) {
      map['layer_id'] = Variable<String>(layerId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubspacesCompanion(')
          ..write('id: $id, ')
          ..write('layerId: $layerId, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SubspacePointsTable extends SubspacePoints
    with TableInfo<$SubspacePointsTable, SubspacePoint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubspacePointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subspaceIdMeta = const VerificationMeta(
    'subspaceId',
  );
  @override
  late final GeneratedColumn<String> subspaceId = GeneratedColumn<String>(
    'subspace_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES subspaces (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
    'lng',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isMainMeta = const VerificationMeta('isMain');
  @override
  late final GeneratedColumn<bool> isMain = GeneratedColumn<bool>(
    'is_main',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_main" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    subspaceId,
    lat,
    lng,
    sortOrder,
    isMain,
    label,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subspace_points';
  @override
  VerificationContext validateIntegrity(
    Insertable<SubspacePoint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('subspace_id')) {
      context.handle(
        _subspaceIdMeta,
        subspaceId.isAcceptableOrUnknown(data['subspace_id']!, _subspaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subspaceIdMeta);
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    } else if (isInserting) {
      context.missing(_latMeta);
    }
    if (data.containsKey('lng')) {
      context.handle(
        _lngMeta,
        lng.isAcceptableOrUnknown(data['lng']!, _lngMeta),
      );
    } else if (isInserting) {
      context.missing(_lngMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('is_main')) {
      context.handle(
        _isMainMeta,
        isMain.isAcceptableOrUnknown(data['is_main']!, _isMainMeta),
      );
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SubspacePoint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SubspacePoint(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      subspaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subspace_id'],
      )!,
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      )!,
      lng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lng'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isMain: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_main'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SubspacePointsTable createAlias(String alias) {
    return $SubspacePointsTable(attachedDatabase, alias);
  }
}

class SubspacePoint extends DataClass implements Insertable<SubspacePoint> {
  final String id;
  final String subspaceId;
  final double lat;
  final double lng;
  final int sortOrder;
  final bool isMain;

  /// Optional name, e.g. the OSM `name` of an imported POI.
  final String? label;
  final DateTime createdAt;
  const SubspacePoint({
    required this.id,
    required this.subspaceId,
    required this.lat,
    required this.lng,
    required this.sortOrder,
    required this.isMain,
    this.label,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['subspace_id'] = Variable<String>(subspaceId);
    map['lat'] = Variable<double>(lat);
    map['lng'] = Variable<double>(lng);
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_main'] = Variable<bool>(isMain);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SubspacePointsCompanion toCompanion(bool nullToAbsent) {
    return SubspacePointsCompanion(
      id: Value(id),
      subspaceId: Value(subspaceId),
      lat: Value(lat),
      lng: Value(lng),
      sortOrder: Value(sortOrder),
      isMain: Value(isMain),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      createdAt: Value(createdAt),
    );
  }

  factory SubspacePoint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SubspacePoint(
      id: serializer.fromJson<String>(json['id']),
      subspaceId: serializer.fromJson<String>(json['subspaceId']),
      lat: serializer.fromJson<double>(json['lat']),
      lng: serializer.fromJson<double>(json['lng']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isMain: serializer.fromJson<bool>(json['isMain']),
      label: serializer.fromJson<String?>(json['label']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'subspaceId': serializer.toJson<String>(subspaceId),
      'lat': serializer.toJson<double>(lat),
      'lng': serializer.toJson<double>(lng),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isMain': serializer.toJson<bool>(isMain),
      'label': serializer.toJson<String?>(label),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SubspacePoint copyWith({
    String? id,
    String? subspaceId,
    double? lat,
    double? lng,
    int? sortOrder,
    bool? isMain,
    Value<String?> label = const Value.absent(),
    DateTime? createdAt,
  }) => SubspacePoint(
    id: id ?? this.id,
    subspaceId: subspaceId ?? this.subspaceId,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    sortOrder: sortOrder ?? this.sortOrder,
    isMain: isMain ?? this.isMain,
    label: label.present ? label.value : this.label,
    createdAt: createdAt ?? this.createdAt,
  );
  SubspacePoint copyWithCompanion(SubspacePointsCompanion data) {
    return SubspacePoint(
      id: data.id.present ? data.id.value : this.id,
      subspaceId: data.subspaceId.present
          ? data.subspaceId.value
          : this.subspaceId,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isMain: data.isMain.present ? data.isMain.value : this.isMain,
      label: data.label.present ? data.label.value : this.label,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SubspacePoint(')
          ..write('id: $id, ')
          ..write('subspaceId: $subspaceId, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isMain: $isMain, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    subspaceId,
    lat,
    lng,
    sortOrder,
    isMain,
    label,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubspacePoint &&
          other.id == this.id &&
          other.subspaceId == this.subspaceId &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.sortOrder == this.sortOrder &&
          other.isMain == this.isMain &&
          other.label == this.label &&
          other.createdAt == this.createdAt);
}

class SubspacePointsCompanion extends UpdateCompanion<SubspacePoint> {
  final Value<String> id;
  final Value<String> subspaceId;
  final Value<double> lat;
  final Value<double> lng;
  final Value<int> sortOrder;
  final Value<bool> isMain;
  final Value<String?> label;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SubspacePointsCompanion({
    this.id = const Value.absent(),
    this.subspaceId = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isMain = const Value.absent(),
    this.label = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SubspacePointsCompanion.insert({
    required String id,
    required String subspaceId,
    required double lat,
    required double lng,
    required int sortOrder,
    this.isMain = const Value.absent(),
    this.label = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       subspaceId = Value(subspaceId),
       lat = Value(lat),
       lng = Value(lng),
       sortOrder = Value(sortOrder);
  static Insertable<SubspacePoint> custom({
    Expression<String>? id,
    Expression<String>? subspaceId,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<int>? sortOrder,
    Expression<bool>? isMain,
    Expression<String>? label,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subspaceId != null) 'subspace_id': subspaceId,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isMain != null) 'is_main': isMain,
      if (label != null) 'label': label,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SubspacePointsCompanion copyWith({
    Value<String>? id,
    Value<String>? subspaceId,
    Value<double>? lat,
    Value<double>? lng,
    Value<int>? sortOrder,
    Value<bool>? isMain,
    Value<String?>? label,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return SubspacePointsCompanion(
      id: id ?? this.id,
      subspaceId: subspaceId ?? this.subspaceId,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      sortOrder: sortOrder ?? this.sortOrder,
      isMain: isMain ?? this.isMain,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (subspaceId.present) {
      map['subspace_id'] = Variable<String>(subspaceId.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isMain.present) {
      map['is_main'] = Variable<bool>(isMain.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubspacePointsCompanion(')
          ..write('id: $id, ')
          ..write('subspaceId: $subspaceId, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isMain: $isMain, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FreeLinesTable extends FreeLines
    with TableInfo<$FreeLinesTable, FreeLine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FreeLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _layerIdMeta = const VerificationMeta(
    'layerId',
  );
  @override
  late final GeneratedColumn<String> layerId = GeneratedColumn<String>(
    'layer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES layers (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _offsetMetersMeta = const VerificationMeta(
    'offsetMeters',
  );
  @override
  late final GeneratedColumn<double> offsetMeters = GeneratedColumn<double>(
    'offset_meters',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _inclusionLatMeta = const VerificationMeta(
    'inclusionLat',
  );
  @override
  late final GeneratedColumn<double> inclusionLat = GeneratedColumn<double>(
    'inclusion_lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _inclusionLngMeta = const VerificationMeta(
    'inclusionLng',
  );
  @override
  late final GeneratedColumn<double> inclusionLng = GeneratedColumn<double>(
    'inclusion_lng',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _inclusionRadiusMetersMeta =
      const VerificationMeta('inclusionRadiusMeters');
  @override
  late final GeneratedColumn<double> inclusionRadiusMeters =
      GeneratedColumn<double>(
        'inclusion_radius_meters',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    layerId,
    label,
    offsetMeters,
    inclusionLat,
    inclusionLng,
    inclusionRadiusMeters,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'free_lines';
  @override
  VerificationContext validateIntegrity(
    Insertable<FreeLine> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('layer_id')) {
      context.handle(
        _layerIdMeta,
        layerId.isAcceptableOrUnknown(data['layer_id']!, _layerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_layerIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('offset_meters')) {
      context.handle(
        _offsetMetersMeta,
        offsetMeters.isAcceptableOrUnknown(
          data['offset_meters']!,
          _offsetMetersMeta,
        ),
      );
    }
    if (data.containsKey('inclusion_lat')) {
      context.handle(
        _inclusionLatMeta,
        inclusionLat.isAcceptableOrUnknown(
          data['inclusion_lat']!,
          _inclusionLatMeta,
        ),
      );
    }
    if (data.containsKey('inclusion_lng')) {
      context.handle(
        _inclusionLngMeta,
        inclusionLng.isAcceptableOrUnknown(
          data['inclusion_lng']!,
          _inclusionLngMeta,
        ),
      );
    }
    if (data.containsKey('inclusion_radius_meters')) {
      context.handle(
        _inclusionRadiusMetersMeta,
        inclusionRadiusMeters.isAcceptableOrUnknown(
          data['inclusion_radius_meters']!,
          _inclusionRadiusMetersMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FreeLine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FreeLine(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      layerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}layer_id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      offsetMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}offset_meters'],
      )!,
      inclusionLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}inclusion_lat'],
      ),
      inclusionLng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}inclusion_lng'],
      ),
      inclusionRadiusMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}inclusion_radius_meters'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FreeLinesTable createAlias(String alias) {
    return $FreeLinesTable(attachedDatabase, alias);
  }
}

class FreeLine extends DataClass implements Insertable<FreeLine> {
  final String id;
  final String layerId;
  final String? label;

  /// Signed offset in metres (see class doc). 0 = boundary sits on the line.
  final double offsetMeters;

  /// The line is bounded to an **inclusion circle**: the filled region is
  /// `(disk) ∩ (one side of the line)`, so the two sides read as two clean
  /// half-disks. Null until set (legacy rows / unset) — the renderer then
  /// derives a default circle from the line's own extent.
  final double? inclusionLat;
  final double? inclusionLng;
  final double? inclusionRadiusMeters;
  final DateTime createdAt;
  const FreeLine({
    required this.id,
    required this.layerId,
    this.label,
    required this.offsetMeters,
    this.inclusionLat,
    this.inclusionLng,
    this.inclusionRadiusMeters,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['layer_id'] = Variable<String>(layerId);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    map['offset_meters'] = Variable<double>(offsetMeters);
    if (!nullToAbsent || inclusionLat != null) {
      map['inclusion_lat'] = Variable<double>(inclusionLat);
    }
    if (!nullToAbsent || inclusionLng != null) {
      map['inclusion_lng'] = Variable<double>(inclusionLng);
    }
    if (!nullToAbsent || inclusionRadiusMeters != null) {
      map['inclusion_radius_meters'] = Variable<double>(inclusionRadiusMeters);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  FreeLinesCompanion toCompanion(bool nullToAbsent) {
    return FreeLinesCompanion(
      id: Value(id),
      layerId: Value(layerId),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      offsetMeters: Value(offsetMeters),
      inclusionLat: inclusionLat == null && nullToAbsent
          ? const Value.absent()
          : Value(inclusionLat),
      inclusionLng: inclusionLng == null && nullToAbsent
          ? const Value.absent()
          : Value(inclusionLng),
      inclusionRadiusMeters: inclusionRadiusMeters == null && nullToAbsent
          ? const Value.absent()
          : Value(inclusionRadiusMeters),
      createdAt: Value(createdAt),
    );
  }

  factory FreeLine.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FreeLine(
      id: serializer.fromJson<String>(json['id']),
      layerId: serializer.fromJson<String>(json['layerId']),
      label: serializer.fromJson<String?>(json['label']),
      offsetMeters: serializer.fromJson<double>(json['offsetMeters']),
      inclusionLat: serializer.fromJson<double?>(json['inclusionLat']),
      inclusionLng: serializer.fromJson<double?>(json['inclusionLng']),
      inclusionRadiusMeters: serializer.fromJson<double?>(
        json['inclusionRadiusMeters'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'layerId': serializer.toJson<String>(layerId),
      'label': serializer.toJson<String?>(label),
      'offsetMeters': serializer.toJson<double>(offsetMeters),
      'inclusionLat': serializer.toJson<double?>(inclusionLat),
      'inclusionLng': serializer.toJson<double?>(inclusionLng),
      'inclusionRadiusMeters': serializer.toJson<double?>(
        inclusionRadiusMeters,
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  FreeLine copyWith({
    String? id,
    String? layerId,
    Value<String?> label = const Value.absent(),
    double? offsetMeters,
    Value<double?> inclusionLat = const Value.absent(),
    Value<double?> inclusionLng = const Value.absent(),
    Value<double?> inclusionRadiusMeters = const Value.absent(),
    DateTime? createdAt,
  }) => FreeLine(
    id: id ?? this.id,
    layerId: layerId ?? this.layerId,
    label: label.present ? label.value : this.label,
    offsetMeters: offsetMeters ?? this.offsetMeters,
    inclusionLat: inclusionLat.present ? inclusionLat.value : this.inclusionLat,
    inclusionLng: inclusionLng.present ? inclusionLng.value : this.inclusionLng,
    inclusionRadiusMeters: inclusionRadiusMeters.present
        ? inclusionRadiusMeters.value
        : this.inclusionRadiusMeters,
    createdAt: createdAt ?? this.createdAt,
  );
  FreeLine copyWithCompanion(FreeLinesCompanion data) {
    return FreeLine(
      id: data.id.present ? data.id.value : this.id,
      layerId: data.layerId.present ? data.layerId.value : this.layerId,
      label: data.label.present ? data.label.value : this.label,
      offsetMeters: data.offsetMeters.present
          ? data.offsetMeters.value
          : this.offsetMeters,
      inclusionLat: data.inclusionLat.present
          ? data.inclusionLat.value
          : this.inclusionLat,
      inclusionLng: data.inclusionLng.present
          ? data.inclusionLng.value
          : this.inclusionLng,
      inclusionRadiusMeters: data.inclusionRadiusMeters.present
          ? data.inclusionRadiusMeters.value
          : this.inclusionRadiusMeters,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FreeLine(')
          ..write('id: $id, ')
          ..write('layerId: $layerId, ')
          ..write('label: $label, ')
          ..write('offsetMeters: $offsetMeters, ')
          ..write('inclusionLat: $inclusionLat, ')
          ..write('inclusionLng: $inclusionLng, ')
          ..write('inclusionRadiusMeters: $inclusionRadiusMeters, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    layerId,
    label,
    offsetMeters,
    inclusionLat,
    inclusionLng,
    inclusionRadiusMeters,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FreeLine &&
          other.id == this.id &&
          other.layerId == this.layerId &&
          other.label == this.label &&
          other.offsetMeters == this.offsetMeters &&
          other.inclusionLat == this.inclusionLat &&
          other.inclusionLng == this.inclusionLng &&
          other.inclusionRadiusMeters == this.inclusionRadiusMeters &&
          other.createdAt == this.createdAt);
}

class FreeLinesCompanion extends UpdateCompanion<FreeLine> {
  final Value<String> id;
  final Value<String> layerId;
  final Value<String?> label;
  final Value<double> offsetMeters;
  final Value<double?> inclusionLat;
  final Value<double?> inclusionLng;
  final Value<double?> inclusionRadiusMeters;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const FreeLinesCompanion({
    this.id = const Value.absent(),
    this.layerId = const Value.absent(),
    this.label = const Value.absent(),
    this.offsetMeters = const Value.absent(),
    this.inclusionLat = const Value.absent(),
    this.inclusionLng = const Value.absent(),
    this.inclusionRadiusMeters = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FreeLinesCompanion.insert({
    required String id,
    required String layerId,
    this.label = const Value.absent(),
    this.offsetMeters = const Value.absent(),
    this.inclusionLat = const Value.absent(),
    this.inclusionLng = const Value.absent(),
    this.inclusionRadiusMeters = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       layerId = Value(layerId);
  static Insertable<FreeLine> custom({
    Expression<String>? id,
    Expression<String>? layerId,
    Expression<String>? label,
    Expression<double>? offsetMeters,
    Expression<double>? inclusionLat,
    Expression<double>? inclusionLng,
    Expression<double>? inclusionRadiusMeters,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (layerId != null) 'layer_id': layerId,
      if (label != null) 'label': label,
      if (offsetMeters != null) 'offset_meters': offsetMeters,
      if (inclusionLat != null) 'inclusion_lat': inclusionLat,
      if (inclusionLng != null) 'inclusion_lng': inclusionLng,
      if (inclusionRadiusMeters != null)
        'inclusion_radius_meters': inclusionRadiusMeters,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FreeLinesCompanion copyWith({
    Value<String>? id,
    Value<String>? layerId,
    Value<String?>? label,
    Value<double>? offsetMeters,
    Value<double?>? inclusionLat,
    Value<double?>? inclusionLng,
    Value<double?>? inclusionRadiusMeters,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return FreeLinesCompanion(
      id: id ?? this.id,
      layerId: layerId ?? this.layerId,
      label: label ?? this.label,
      offsetMeters: offsetMeters ?? this.offsetMeters,
      inclusionLat: inclusionLat ?? this.inclusionLat,
      inclusionLng: inclusionLng ?? this.inclusionLng,
      inclusionRadiusMeters:
          inclusionRadiusMeters ?? this.inclusionRadiusMeters,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (layerId.present) {
      map['layer_id'] = Variable<String>(layerId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (offsetMeters.present) {
      map['offset_meters'] = Variable<double>(offsetMeters.value);
    }
    if (inclusionLat.present) {
      map['inclusion_lat'] = Variable<double>(inclusionLat.value);
    }
    if (inclusionLng.present) {
      map['inclusion_lng'] = Variable<double>(inclusionLng.value);
    }
    if (inclusionRadiusMeters.present) {
      map['inclusion_radius_meters'] = Variable<double>(
        inclusionRadiusMeters.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FreeLinesCompanion(')
          ..write('id: $id, ')
          ..write('layerId: $layerId, ')
          ..write('label: $label, ')
          ..write('offsetMeters: $offsetMeters, ')
          ..write('inclusionLat: $inclusionLat, ')
          ..write('inclusionLng: $inclusionLng, ')
          ..write('inclusionRadiusMeters: $inclusionRadiusMeters, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FreeLinePointsTable extends FreeLinePoints
    with TableInfo<$FreeLinePointsTable, FreeLinePoint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FreeLinePointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _freeLineIdMeta = const VerificationMeta(
    'freeLineId',
  );
  @override
  late final GeneratedColumn<String> freeLineId = GeneratedColumn<String>(
    'free_line_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES free_lines (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
    'lng',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    freeLineId,
    lat,
    lng,
    sortOrder,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'free_line_points';
  @override
  VerificationContext validateIntegrity(
    Insertable<FreeLinePoint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('free_line_id')) {
      context.handle(
        _freeLineIdMeta,
        freeLineId.isAcceptableOrUnknown(
          data['free_line_id']!,
          _freeLineIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_freeLineIdMeta);
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    } else if (isInserting) {
      context.missing(_latMeta);
    }
    if (data.containsKey('lng')) {
      context.handle(
        _lngMeta,
        lng.isAcceptableOrUnknown(data['lng']!, _lngMeta),
      );
    } else if (isInserting) {
      context.missing(_lngMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FreeLinePoint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FreeLinePoint(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      freeLineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}free_line_id'],
      )!,
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      )!,
      lng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lng'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FreeLinePointsTable createAlias(String alias) {
    return $FreeLinePointsTable(attachedDatabase, alias);
  }
}

class FreeLinePoint extends DataClass implements Insertable<FreeLinePoint> {
  final String id;
  final String freeLineId;
  final double lat;
  final double lng;
  final int sortOrder;
  final DateTime createdAt;
  const FreeLinePoint({
    required this.id,
    required this.freeLineId,
    required this.lat,
    required this.lng,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['free_line_id'] = Variable<String>(freeLineId);
    map['lat'] = Variable<double>(lat);
    map['lng'] = Variable<double>(lng);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  FreeLinePointsCompanion toCompanion(bool nullToAbsent) {
    return FreeLinePointsCompanion(
      id: Value(id),
      freeLineId: Value(freeLineId),
      lat: Value(lat),
      lng: Value(lng),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory FreeLinePoint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FreeLinePoint(
      id: serializer.fromJson<String>(json['id']),
      freeLineId: serializer.fromJson<String>(json['freeLineId']),
      lat: serializer.fromJson<double>(json['lat']),
      lng: serializer.fromJson<double>(json['lng']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'freeLineId': serializer.toJson<String>(freeLineId),
      'lat': serializer.toJson<double>(lat),
      'lng': serializer.toJson<double>(lng),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  FreeLinePoint copyWith({
    String? id,
    String? freeLineId,
    double? lat,
    double? lng,
    int? sortOrder,
    DateTime? createdAt,
  }) => FreeLinePoint(
    id: id ?? this.id,
    freeLineId: freeLineId ?? this.freeLineId,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  FreeLinePoint copyWithCompanion(FreeLinePointsCompanion data) {
    return FreeLinePoint(
      id: data.id.present ? data.id.value : this.id,
      freeLineId: data.freeLineId.present
          ? data.freeLineId.value
          : this.freeLineId,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FreeLinePoint(')
          ..write('id: $id, ')
          ..write('freeLineId: $freeLineId, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, freeLineId, lat, lng, sortOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FreeLinePoint &&
          other.id == this.id &&
          other.freeLineId == this.freeLineId &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class FreeLinePointsCompanion extends UpdateCompanion<FreeLinePoint> {
  final Value<String> id;
  final Value<String> freeLineId;
  final Value<double> lat;
  final Value<double> lng;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const FreeLinePointsCompanion({
    this.id = const Value.absent(),
    this.freeLineId = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FreeLinePointsCompanion.insert({
    required String id,
    required String freeLineId,
    required double lat,
    required double lng,
    required int sortOrder,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       freeLineId = Value(freeLineId),
       lat = Value(lat),
       lng = Value(lng),
       sortOrder = Value(sortOrder);
  static Insertable<FreeLinePoint> custom({
    Expression<String>? id,
    Expression<String>? freeLineId,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (freeLineId != null) 'free_line_id': freeLineId,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FreeLinePointsCompanion copyWith({
    Value<String>? id,
    Value<String>? freeLineId,
    Value<double>? lat,
    Value<double>? lng,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return FreeLinePointsCompanion(
      id: id ?? this.id,
      freeLineId: freeLineId ?? this.freeLineId,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (freeLineId.present) {
      map['free_line_id'] = Variable<String>(freeLineId.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FreeLinePointsCompanion(')
          ..write('id: $id, ')
          ..write('freeLineId: $freeLineId, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FreeAreasTable extends FreeAreas
    with TableInfo<$FreeAreasTable, FreeArea> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FreeAreasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _layerIdMeta = const VerificationMeta(
    'layerId',
  );
  @override
  late final GeneratedColumn<String> layerId = GeneratedColumn<String>(
    'layer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES layers (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _offsetMetersMeta = const VerificationMeta(
    'offsetMeters',
  );
  @override
  late final GeneratedColumn<double> offsetMeters = GeneratedColumn<double>(
    'offset_meters',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    layerId,
    label,
    offsetMeters,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'free_areas';
  @override
  VerificationContext validateIntegrity(
    Insertable<FreeArea> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('layer_id')) {
      context.handle(
        _layerIdMeta,
        layerId.isAcceptableOrUnknown(data['layer_id']!, _layerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_layerIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('offset_meters')) {
      context.handle(
        _offsetMetersMeta,
        offsetMeters.isAcceptableOrUnknown(
          data['offset_meters']!,
          _offsetMetersMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FreeArea map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FreeArea(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      layerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}layer_id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      offsetMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}offset_meters'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FreeAreasTable createAlias(String alias) {
    return $FreeAreasTable(attachedDatabase, alias);
  }
}

class FreeArea extends DataClass implements Insertable<FreeArea> {
  final String id;
  final String layerId;
  final String? label;

  /// Signed inward offset in metres (see class doc). 0 = boundary on the ring.
  final double offsetMeters;
  final DateTime createdAt;
  const FreeArea({
    required this.id,
    required this.layerId,
    this.label,
    required this.offsetMeters,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['layer_id'] = Variable<String>(layerId);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    map['offset_meters'] = Variable<double>(offsetMeters);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  FreeAreasCompanion toCompanion(bool nullToAbsent) {
    return FreeAreasCompanion(
      id: Value(id),
      layerId: Value(layerId),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      offsetMeters: Value(offsetMeters),
      createdAt: Value(createdAt),
    );
  }

  factory FreeArea.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FreeArea(
      id: serializer.fromJson<String>(json['id']),
      layerId: serializer.fromJson<String>(json['layerId']),
      label: serializer.fromJson<String?>(json['label']),
      offsetMeters: serializer.fromJson<double>(json['offsetMeters']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'layerId': serializer.toJson<String>(layerId),
      'label': serializer.toJson<String?>(label),
      'offsetMeters': serializer.toJson<double>(offsetMeters),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  FreeArea copyWith({
    String? id,
    String? layerId,
    Value<String?> label = const Value.absent(),
    double? offsetMeters,
    DateTime? createdAt,
  }) => FreeArea(
    id: id ?? this.id,
    layerId: layerId ?? this.layerId,
    label: label.present ? label.value : this.label,
    offsetMeters: offsetMeters ?? this.offsetMeters,
    createdAt: createdAt ?? this.createdAt,
  );
  FreeArea copyWithCompanion(FreeAreasCompanion data) {
    return FreeArea(
      id: data.id.present ? data.id.value : this.id,
      layerId: data.layerId.present ? data.layerId.value : this.layerId,
      label: data.label.present ? data.label.value : this.label,
      offsetMeters: data.offsetMeters.present
          ? data.offsetMeters.value
          : this.offsetMeters,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FreeArea(')
          ..write('id: $id, ')
          ..write('layerId: $layerId, ')
          ..write('label: $label, ')
          ..write('offsetMeters: $offsetMeters, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, layerId, label, offsetMeters, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FreeArea &&
          other.id == this.id &&
          other.layerId == this.layerId &&
          other.label == this.label &&
          other.offsetMeters == this.offsetMeters &&
          other.createdAt == this.createdAt);
}

class FreeAreasCompanion extends UpdateCompanion<FreeArea> {
  final Value<String> id;
  final Value<String> layerId;
  final Value<String?> label;
  final Value<double> offsetMeters;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const FreeAreasCompanion({
    this.id = const Value.absent(),
    this.layerId = const Value.absent(),
    this.label = const Value.absent(),
    this.offsetMeters = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FreeAreasCompanion.insert({
    required String id,
    required String layerId,
    this.label = const Value.absent(),
    this.offsetMeters = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       layerId = Value(layerId);
  static Insertable<FreeArea> custom({
    Expression<String>? id,
    Expression<String>? layerId,
    Expression<String>? label,
    Expression<double>? offsetMeters,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (layerId != null) 'layer_id': layerId,
      if (label != null) 'label': label,
      if (offsetMeters != null) 'offset_meters': offsetMeters,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FreeAreasCompanion copyWith({
    Value<String>? id,
    Value<String>? layerId,
    Value<String?>? label,
    Value<double>? offsetMeters,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return FreeAreasCompanion(
      id: id ?? this.id,
      layerId: layerId ?? this.layerId,
      label: label ?? this.label,
      offsetMeters: offsetMeters ?? this.offsetMeters,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (layerId.present) {
      map['layer_id'] = Variable<String>(layerId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (offsetMeters.present) {
      map['offset_meters'] = Variable<double>(offsetMeters.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FreeAreasCompanion(')
          ..write('id: $id, ')
          ..write('layerId: $layerId, ')
          ..write('label: $label, ')
          ..write('offsetMeters: $offsetMeters, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FreeAreaPointsTable extends FreeAreaPoints
    with TableInfo<$FreeAreaPointsTable, FreeAreaPoint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FreeAreaPointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _freeAreaIdMeta = const VerificationMeta(
    'freeAreaId',
  );
  @override
  late final GeneratedColumn<String> freeAreaId = GeneratedColumn<String>(
    'free_area_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES free_areas (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
    'lng',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    freeAreaId,
    lat,
    lng,
    sortOrder,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'free_area_points';
  @override
  VerificationContext validateIntegrity(
    Insertable<FreeAreaPoint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('free_area_id')) {
      context.handle(
        _freeAreaIdMeta,
        freeAreaId.isAcceptableOrUnknown(
          data['free_area_id']!,
          _freeAreaIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_freeAreaIdMeta);
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    } else if (isInserting) {
      context.missing(_latMeta);
    }
    if (data.containsKey('lng')) {
      context.handle(
        _lngMeta,
        lng.isAcceptableOrUnknown(data['lng']!, _lngMeta),
      );
    } else if (isInserting) {
      context.missing(_lngMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FreeAreaPoint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FreeAreaPoint(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      freeAreaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}free_area_id'],
      )!,
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      )!,
      lng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lng'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FreeAreaPointsTable createAlias(String alias) {
    return $FreeAreaPointsTable(attachedDatabase, alias);
  }
}

class FreeAreaPoint extends DataClass implements Insertable<FreeAreaPoint> {
  final String id;
  final String freeAreaId;
  final double lat;
  final double lng;
  final int sortOrder;
  final DateTime createdAt;
  const FreeAreaPoint({
    required this.id,
    required this.freeAreaId,
    required this.lat,
    required this.lng,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['free_area_id'] = Variable<String>(freeAreaId);
    map['lat'] = Variable<double>(lat);
    map['lng'] = Variable<double>(lng);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  FreeAreaPointsCompanion toCompanion(bool nullToAbsent) {
    return FreeAreaPointsCompanion(
      id: Value(id),
      freeAreaId: Value(freeAreaId),
      lat: Value(lat),
      lng: Value(lng),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory FreeAreaPoint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FreeAreaPoint(
      id: serializer.fromJson<String>(json['id']),
      freeAreaId: serializer.fromJson<String>(json['freeAreaId']),
      lat: serializer.fromJson<double>(json['lat']),
      lng: serializer.fromJson<double>(json['lng']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'freeAreaId': serializer.toJson<String>(freeAreaId),
      'lat': serializer.toJson<double>(lat),
      'lng': serializer.toJson<double>(lng),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  FreeAreaPoint copyWith({
    String? id,
    String? freeAreaId,
    double? lat,
    double? lng,
    int? sortOrder,
    DateTime? createdAt,
  }) => FreeAreaPoint(
    id: id ?? this.id,
    freeAreaId: freeAreaId ?? this.freeAreaId,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  FreeAreaPoint copyWithCompanion(FreeAreaPointsCompanion data) {
    return FreeAreaPoint(
      id: data.id.present ? data.id.value : this.id,
      freeAreaId: data.freeAreaId.present
          ? data.freeAreaId.value
          : this.freeAreaId,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FreeAreaPoint(')
          ..write('id: $id, ')
          ..write('freeAreaId: $freeAreaId, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, freeAreaId, lat, lng, sortOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FreeAreaPoint &&
          other.id == this.id &&
          other.freeAreaId == this.freeAreaId &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class FreeAreaPointsCompanion extends UpdateCompanion<FreeAreaPoint> {
  final Value<String> id;
  final Value<String> freeAreaId;
  final Value<double> lat;
  final Value<double> lng;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const FreeAreaPointsCompanion({
    this.id = const Value.absent(),
    this.freeAreaId = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FreeAreaPointsCompanion.insert({
    required String id,
    required String freeAreaId,
    required double lat,
    required double lng,
    required int sortOrder,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       freeAreaId = Value(freeAreaId),
       lat = Value(lat),
       lng = Value(lng),
       sortOrder = Value(sortOrder);
  static Insertable<FreeAreaPoint> custom({
    Expression<String>? id,
    Expression<String>? freeAreaId,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (freeAreaId != null) 'free_area_id': freeAreaId,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FreeAreaPointsCompanion copyWith({
    Value<String>? id,
    Value<String>? freeAreaId,
    Value<double>? lat,
    Value<double>? lng,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return FreeAreaPointsCompanion(
      id: id ?? this.id,
      freeAreaId: freeAreaId ?? this.freeAreaId,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (freeAreaId.present) {
      map['free_area_id'] = Variable<String>(freeAreaId.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FreeAreaPointsCompanion(')
          ..write('id: $id, ')
          ..write('freeAreaId: $freeAreaId, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HeightRegionsTable extends HeightRegions
    with TableInfo<$HeightRegionsTable, HeightRegion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HeightRegionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _layerIdMeta = const VerificationMeta(
    'layerId',
  );
  @override
  late final GeneratedColumn<String> layerId = GeneratedColumn<String>(
    'layer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES layers (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _centerLatMeta = const VerificationMeta(
    'centerLat',
  );
  @override
  late final GeneratedColumn<double> centerLat = GeneratedColumn<double>(
    'center_lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _centerLngMeta = const VerificationMeta(
    'centerLng',
  );
  @override
  late final GeneratedColumn<double> centerLng = GeneratedColumn<double>(
    'center_lng',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _radiusMetersMeta = const VerificationMeta(
    'radiusMeters',
  );
  @override
  late final GeneratedColumn<double> radiusMeters = GeneratedColumn<double>(
    'radius_meters',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thresholdMetersMeta = const VerificationMeta(
    'thresholdMeters',
  );
  @override
  late final GeneratedColumn<double> thresholdMeters = GeneratedColumn<double>(
    'threshold_meters',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _aboveThresholdMeta = const VerificationMeta(
    'aboveThreshold',
  );
  @override
  late final GeneratedColumn<bool> aboveThreshold = GeneratedColumn<bool>(
    'above_threshold',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("above_threshold" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sampleZoomMeta = const VerificationMeta(
    'sampleZoom',
  );
  @override
  late final GeneratedColumn<int> sampleZoom = GeneratedColumn<int>(
    'sample_zoom',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(13),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _generatedAtMeta = const VerificationMeta(
    'generatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> generatedAt = GeneratedColumn<DateTime>(
    'generated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    layerId,
    centerLat,
    centerLng,
    radiusMeters,
    thresholdMeters,
    aboveThreshold,
    sampleZoom,
    label,
    generatedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'height_regions';
  @override
  VerificationContext validateIntegrity(
    Insertable<HeightRegion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('layer_id')) {
      context.handle(
        _layerIdMeta,
        layerId.isAcceptableOrUnknown(data['layer_id']!, _layerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_layerIdMeta);
    }
    if (data.containsKey('center_lat')) {
      context.handle(
        _centerLatMeta,
        centerLat.isAcceptableOrUnknown(data['center_lat']!, _centerLatMeta),
      );
    } else if (isInserting) {
      context.missing(_centerLatMeta);
    }
    if (data.containsKey('center_lng')) {
      context.handle(
        _centerLngMeta,
        centerLng.isAcceptableOrUnknown(data['center_lng']!, _centerLngMeta),
      );
    } else if (isInserting) {
      context.missing(_centerLngMeta);
    }
    if (data.containsKey('radius_meters')) {
      context.handle(
        _radiusMetersMeta,
        radiusMeters.isAcceptableOrUnknown(
          data['radius_meters']!,
          _radiusMetersMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_radiusMetersMeta);
    }
    if (data.containsKey('threshold_meters')) {
      context.handle(
        _thresholdMetersMeta,
        thresholdMeters.isAcceptableOrUnknown(
          data['threshold_meters']!,
          _thresholdMetersMeta,
        ),
      );
    }
    if (data.containsKey('above_threshold')) {
      context.handle(
        _aboveThresholdMeta,
        aboveThreshold.isAcceptableOrUnknown(
          data['above_threshold']!,
          _aboveThresholdMeta,
        ),
      );
    }
    if (data.containsKey('sample_zoom')) {
      context.handle(
        _sampleZoomMeta,
        sampleZoom.isAcceptableOrUnknown(data['sample_zoom']!, _sampleZoomMeta),
      );
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('generated_at')) {
      context.handle(
        _generatedAtMeta,
        generatedAt.isAcceptableOrUnknown(
          data['generated_at']!,
          _generatedAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HeightRegion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HeightRegion(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      layerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}layer_id'],
      )!,
      centerLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}center_lat'],
      )!,
      centerLng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}center_lng'],
      )!,
      radiusMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}radius_meters'],
      )!,
      thresholdMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}threshold_meters'],
      )!,
      aboveThreshold: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}above_threshold'],
      )!,
      sampleZoom: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sample_zoom'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      generatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}generated_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $HeightRegionsTable createAlias(String alias) {
    return $HeightRegionsTable(attachedDatabase, alias);
  }
}

class HeightRegion extends DataClass implements Insertable<HeightRegion> {
  final String id;
  final String layerId;
  final double centerLat;
  final double centerLng;
  final double radiusMeters;

  /// Elevation threshold in metres above sea level (may be negative).
  final double thresholdMeters;

  /// True = fill terrain above the threshold; false = below.
  final bool aboveThreshold;

  /// Slippy zoom of the terrain tiles sampled when generating (12–14).
  final int sampleZoom;
  final String? label;

  /// When the fill polygons were last generated; null until first generation.
  final DateTime? generatedAt;
  final DateTime createdAt;
  const HeightRegion({
    required this.id,
    required this.layerId,
    required this.centerLat,
    required this.centerLng,
    required this.radiusMeters,
    required this.thresholdMeters,
    required this.aboveThreshold,
    required this.sampleZoom,
    this.label,
    this.generatedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['layer_id'] = Variable<String>(layerId);
    map['center_lat'] = Variable<double>(centerLat);
    map['center_lng'] = Variable<double>(centerLng);
    map['radius_meters'] = Variable<double>(radiusMeters);
    map['threshold_meters'] = Variable<double>(thresholdMeters);
    map['above_threshold'] = Variable<bool>(aboveThreshold);
    map['sample_zoom'] = Variable<int>(sampleZoom);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    if (!nullToAbsent || generatedAt != null) {
      map['generated_at'] = Variable<DateTime>(generatedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  HeightRegionsCompanion toCompanion(bool nullToAbsent) {
    return HeightRegionsCompanion(
      id: Value(id),
      layerId: Value(layerId),
      centerLat: Value(centerLat),
      centerLng: Value(centerLng),
      radiusMeters: Value(radiusMeters),
      thresholdMeters: Value(thresholdMeters),
      aboveThreshold: Value(aboveThreshold),
      sampleZoom: Value(sampleZoom),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      generatedAt: generatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(generatedAt),
      createdAt: Value(createdAt),
    );
  }

  factory HeightRegion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HeightRegion(
      id: serializer.fromJson<String>(json['id']),
      layerId: serializer.fromJson<String>(json['layerId']),
      centerLat: serializer.fromJson<double>(json['centerLat']),
      centerLng: serializer.fromJson<double>(json['centerLng']),
      radiusMeters: serializer.fromJson<double>(json['radiusMeters']),
      thresholdMeters: serializer.fromJson<double>(json['thresholdMeters']),
      aboveThreshold: serializer.fromJson<bool>(json['aboveThreshold']),
      sampleZoom: serializer.fromJson<int>(json['sampleZoom']),
      label: serializer.fromJson<String?>(json['label']),
      generatedAt: serializer.fromJson<DateTime?>(json['generatedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'layerId': serializer.toJson<String>(layerId),
      'centerLat': serializer.toJson<double>(centerLat),
      'centerLng': serializer.toJson<double>(centerLng),
      'radiusMeters': serializer.toJson<double>(radiusMeters),
      'thresholdMeters': serializer.toJson<double>(thresholdMeters),
      'aboveThreshold': serializer.toJson<bool>(aboveThreshold),
      'sampleZoom': serializer.toJson<int>(sampleZoom),
      'label': serializer.toJson<String?>(label),
      'generatedAt': serializer.toJson<DateTime?>(generatedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  HeightRegion copyWith({
    String? id,
    String? layerId,
    double? centerLat,
    double? centerLng,
    double? radiusMeters,
    double? thresholdMeters,
    bool? aboveThreshold,
    int? sampleZoom,
    Value<String?> label = const Value.absent(),
    Value<DateTime?> generatedAt = const Value.absent(),
    DateTime? createdAt,
  }) => HeightRegion(
    id: id ?? this.id,
    layerId: layerId ?? this.layerId,
    centerLat: centerLat ?? this.centerLat,
    centerLng: centerLng ?? this.centerLng,
    radiusMeters: radiusMeters ?? this.radiusMeters,
    thresholdMeters: thresholdMeters ?? this.thresholdMeters,
    aboveThreshold: aboveThreshold ?? this.aboveThreshold,
    sampleZoom: sampleZoom ?? this.sampleZoom,
    label: label.present ? label.value : this.label,
    generatedAt: generatedAt.present ? generatedAt.value : this.generatedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  HeightRegion copyWithCompanion(HeightRegionsCompanion data) {
    return HeightRegion(
      id: data.id.present ? data.id.value : this.id,
      layerId: data.layerId.present ? data.layerId.value : this.layerId,
      centerLat: data.centerLat.present ? data.centerLat.value : this.centerLat,
      centerLng: data.centerLng.present ? data.centerLng.value : this.centerLng,
      radiusMeters: data.radiusMeters.present
          ? data.radiusMeters.value
          : this.radiusMeters,
      thresholdMeters: data.thresholdMeters.present
          ? data.thresholdMeters.value
          : this.thresholdMeters,
      aboveThreshold: data.aboveThreshold.present
          ? data.aboveThreshold.value
          : this.aboveThreshold,
      sampleZoom: data.sampleZoom.present
          ? data.sampleZoom.value
          : this.sampleZoom,
      label: data.label.present ? data.label.value : this.label,
      generatedAt: data.generatedAt.present
          ? data.generatedAt.value
          : this.generatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HeightRegion(')
          ..write('id: $id, ')
          ..write('layerId: $layerId, ')
          ..write('centerLat: $centerLat, ')
          ..write('centerLng: $centerLng, ')
          ..write('radiusMeters: $radiusMeters, ')
          ..write('thresholdMeters: $thresholdMeters, ')
          ..write('aboveThreshold: $aboveThreshold, ')
          ..write('sampleZoom: $sampleZoom, ')
          ..write('label: $label, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    layerId,
    centerLat,
    centerLng,
    radiusMeters,
    thresholdMeters,
    aboveThreshold,
    sampleZoom,
    label,
    generatedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HeightRegion &&
          other.id == this.id &&
          other.layerId == this.layerId &&
          other.centerLat == this.centerLat &&
          other.centerLng == this.centerLng &&
          other.radiusMeters == this.radiusMeters &&
          other.thresholdMeters == this.thresholdMeters &&
          other.aboveThreshold == this.aboveThreshold &&
          other.sampleZoom == this.sampleZoom &&
          other.label == this.label &&
          other.generatedAt == this.generatedAt &&
          other.createdAt == this.createdAt);
}

class HeightRegionsCompanion extends UpdateCompanion<HeightRegion> {
  final Value<String> id;
  final Value<String> layerId;
  final Value<double> centerLat;
  final Value<double> centerLng;
  final Value<double> radiusMeters;
  final Value<double> thresholdMeters;
  final Value<bool> aboveThreshold;
  final Value<int> sampleZoom;
  final Value<String?> label;
  final Value<DateTime?> generatedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const HeightRegionsCompanion({
    this.id = const Value.absent(),
    this.layerId = const Value.absent(),
    this.centerLat = const Value.absent(),
    this.centerLng = const Value.absent(),
    this.radiusMeters = const Value.absent(),
    this.thresholdMeters = const Value.absent(),
    this.aboveThreshold = const Value.absent(),
    this.sampleZoom = const Value.absent(),
    this.label = const Value.absent(),
    this.generatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HeightRegionsCompanion.insert({
    required String id,
    required String layerId,
    required double centerLat,
    required double centerLng,
    required double radiusMeters,
    this.thresholdMeters = const Value.absent(),
    this.aboveThreshold = const Value.absent(),
    this.sampleZoom = const Value.absent(),
    this.label = const Value.absent(),
    this.generatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       layerId = Value(layerId),
       centerLat = Value(centerLat),
       centerLng = Value(centerLng),
       radiusMeters = Value(radiusMeters);
  static Insertable<HeightRegion> custom({
    Expression<String>? id,
    Expression<String>? layerId,
    Expression<double>? centerLat,
    Expression<double>? centerLng,
    Expression<double>? radiusMeters,
    Expression<double>? thresholdMeters,
    Expression<bool>? aboveThreshold,
    Expression<int>? sampleZoom,
    Expression<String>? label,
    Expression<DateTime>? generatedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (layerId != null) 'layer_id': layerId,
      if (centerLat != null) 'center_lat': centerLat,
      if (centerLng != null) 'center_lng': centerLng,
      if (radiusMeters != null) 'radius_meters': radiusMeters,
      if (thresholdMeters != null) 'threshold_meters': thresholdMeters,
      if (aboveThreshold != null) 'above_threshold': aboveThreshold,
      if (sampleZoom != null) 'sample_zoom': sampleZoom,
      if (label != null) 'label': label,
      if (generatedAt != null) 'generated_at': generatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HeightRegionsCompanion copyWith({
    Value<String>? id,
    Value<String>? layerId,
    Value<double>? centerLat,
    Value<double>? centerLng,
    Value<double>? radiusMeters,
    Value<double>? thresholdMeters,
    Value<bool>? aboveThreshold,
    Value<int>? sampleZoom,
    Value<String?>? label,
    Value<DateTime?>? generatedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return HeightRegionsCompanion(
      id: id ?? this.id,
      layerId: layerId ?? this.layerId,
      centerLat: centerLat ?? this.centerLat,
      centerLng: centerLng ?? this.centerLng,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      thresholdMeters: thresholdMeters ?? this.thresholdMeters,
      aboveThreshold: aboveThreshold ?? this.aboveThreshold,
      sampleZoom: sampleZoom ?? this.sampleZoom,
      label: label ?? this.label,
      generatedAt: generatedAt ?? this.generatedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (layerId.present) {
      map['layer_id'] = Variable<String>(layerId.value);
    }
    if (centerLat.present) {
      map['center_lat'] = Variable<double>(centerLat.value);
    }
    if (centerLng.present) {
      map['center_lng'] = Variable<double>(centerLng.value);
    }
    if (radiusMeters.present) {
      map['radius_meters'] = Variable<double>(radiusMeters.value);
    }
    if (thresholdMeters.present) {
      map['threshold_meters'] = Variable<double>(thresholdMeters.value);
    }
    if (aboveThreshold.present) {
      map['above_threshold'] = Variable<bool>(aboveThreshold.value);
    }
    if (sampleZoom.present) {
      map['sample_zoom'] = Variable<int>(sampleZoom.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (generatedAt.present) {
      map['generated_at'] = Variable<DateTime>(generatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HeightRegionsCompanion(')
          ..write('id: $id, ')
          ..write('layerId: $layerId, ')
          ..write('centerLat: $centerLat, ')
          ..write('centerLng: $centerLng, ')
          ..write('radiusMeters: $radiusMeters, ')
          ..write('thresholdMeters: $thresholdMeters, ')
          ..write('aboveThreshold: $aboveThreshold, ')
          ..write('sampleZoom: $sampleZoom, ')
          ..write('label: $label, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HeightPolygonsTable extends HeightPolygons
    with TableInfo<$HeightPolygonsTable, HeightPolygon> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HeightPolygonsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heightRegionIdMeta = const VerificationMeta(
    'heightRegionId',
  );
  @override
  late final GeneratedColumn<String> heightRegionId = GeneratedColumn<String>(
    'height_region_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES height_regions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    heightRegionId,
    sortOrder,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'height_polygons';
  @override
  VerificationContext validateIntegrity(
    Insertable<HeightPolygon> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('height_region_id')) {
      context.handle(
        _heightRegionIdMeta,
        heightRegionId.isAcceptableOrUnknown(
          data['height_region_id']!,
          _heightRegionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_heightRegionIdMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HeightPolygon map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HeightPolygon(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      heightRegionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}height_region_id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $HeightPolygonsTable createAlias(String alias) {
    return $HeightPolygonsTable(attachedDatabase, alias);
  }
}

class HeightPolygon extends DataClass implements Insertable<HeightPolygon> {
  final String id;
  final String heightRegionId;
  final int sortOrder;
  final DateTime createdAt;
  const HeightPolygon({
    required this.id,
    required this.heightRegionId,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['height_region_id'] = Variable<String>(heightRegionId);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  HeightPolygonsCompanion toCompanion(bool nullToAbsent) {
    return HeightPolygonsCompanion(
      id: Value(id),
      heightRegionId: Value(heightRegionId),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory HeightPolygon.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HeightPolygon(
      id: serializer.fromJson<String>(json['id']),
      heightRegionId: serializer.fromJson<String>(json['heightRegionId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'heightRegionId': serializer.toJson<String>(heightRegionId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  HeightPolygon copyWith({
    String? id,
    String? heightRegionId,
    int? sortOrder,
    DateTime? createdAt,
  }) => HeightPolygon(
    id: id ?? this.id,
    heightRegionId: heightRegionId ?? this.heightRegionId,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  HeightPolygon copyWithCompanion(HeightPolygonsCompanion data) {
    return HeightPolygon(
      id: data.id.present ? data.id.value : this.id,
      heightRegionId: data.heightRegionId.present
          ? data.heightRegionId.value
          : this.heightRegionId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HeightPolygon(')
          ..write('id: $id, ')
          ..write('heightRegionId: $heightRegionId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, heightRegionId, sortOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HeightPolygon &&
          other.id == this.id &&
          other.heightRegionId == this.heightRegionId &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class HeightPolygonsCompanion extends UpdateCompanion<HeightPolygon> {
  final Value<String> id;
  final Value<String> heightRegionId;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const HeightPolygonsCompanion({
    this.id = const Value.absent(),
    this.heightRegionId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HeightPolygonsCompanion.insert({
    required String id,
    required String heightRegionId,
    required int sortOrder,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       heightRegionId = Value(heightRegionId),
       sortOrder = Value(sortOrder);
  static Insertable<HeightPolygon> custom({
    Expression<String>? id,
    Expression<String>? heightRegionId,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (heightRegionId != null) 'height_region_id': heightRegionId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HeightPolygonsCompanion copyWith({
    Value<String>? id,
    Value<String>? heightRegionId,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return HeightPolygonsCompanion(
      id: id ?? this.id,
      heightRegionId: heightRegionId ?? this.heightRegionId,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (heightRegionId.present) {
      map['height_region_id'] = Variable<String>(heightRegionId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HeightPolygonsCompanion(')
          ..write('id: $id, ')
          ..write('heightRegionId: $heightRegionId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HeightPolygonPointsTable extends HeightPolygonPoints
    with TableInfo<$HeightPolygonPointsTable, HeightPolygonPoint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HeightPolygonPointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _polygonIdMeta = const VerificationMeta(
    'polygonId',
  );
  @override
  late final GeneratedColumn<String> polygonId = GeneratedColumn<String>(
    'polygon_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES height_polygons (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
    'lng',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    polygonId,
    lat,
    lng,
    sortOrder,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'height_polygon_points';
  @override
  VerificationContext validateIntegrity(
    Insertable<HeightPolygonPoint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('polygon_id')) {
      context.handle(
        _polygonIdMeta,
        polygonId.isAcceptableOrUnknown(data['polygon_id']!, _polygonIdMeta),
      );
    } else if (isInserting) {
      context.missing(_polygonIdMeta);
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    } else if (isInserting) {
      context.missing(_latMeta);
    }
    if (data.containsKey('lng')) {
      context.handle(
        _lngMeta,
        lng.isAcceptableOrUnknown(data['lng']!, _lngMeta),
      );
    } else if (isInserting) {
      context.missing(_lngMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HeightPolygonPoint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HeightPolygonPoint(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      polygonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}polygon_id'],
      )!,
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      )!,
      lng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lng'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $HeightPolygonPointsTable createAlias(String alias) {
    return $HeightPolygonPointsTable(attachedDatabase, alias);
  }
}

class HeightPolygonPoint extends DataClass
    implements Insertable<HeightPolygonPoint> {
  final String id;
  final String polygonId;
  final double lat;
  final double lng;
  final int sortOrder;
  final DateTime createdAt;
  const HeightPolygonPoint({
    required this.id,
    required this.polygonId,
    required this.lat,
    required this.lng,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['polygon_id'] = Variable<String>(polygonId);
    map['lat'] = Variable<double>(lat);
    map['lng'] = Variable<double>(lng);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  HeightPolygonPointsCompanion toCompanion(bool nullToAbsent) {
    return HeightPolygonPointsCompanion(
      id: Value(id),
      polygonId: Value(polygonId),
      lat: Value(lat),
      lng: Value(lng),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory HeightPolygonPoint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HeightPolygonPoint(
      id: serializer.fromJson<String>(json['id']),
      polygonId: serializer.fromJson<String>(json['polygonId']),
      lat: serializer.fromJson<double>(json['lat']),
      lng: serializer.fromJson<double>(json['lng']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'polygonId': serializer.toJson<String>(polygonId),
      'lat': serializer.toJson<double>(lat),
      'lng': serializer.toJson<double>(lng),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  HeightPolygonPoint copyWith({
    String? id,
    String? polygonId,
    double? lat,
    double? lng,
    int? sortOrder,
    DateTime? createdAt,
  }) => HeightPolygonPoint(
    id: id ?? this.id,
    polygonId: polygonId ?? this.polygonId,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  HeightPolygonPoint copyWithCompanion(HeightPolygonPointsCompanion data) {
    return HeightPolygonPoint(
      id: data.id.present ? data.id.value : this.id,
      polygonId: data.polygonId.present ? data.polygonId.value : this.polygonId,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HeightPolygonPoint(')
          ..write('id: $id, ')
          ..write('polygonId: $polygonId, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, polygonId, lat, lng, sortOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HeightPolygonPoint &&
          other.id == this.id &&
          other.polygonId == this.polygonId &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class HeightPolygonPointsCompanion extends UpdateCompanion<HeightPolygonPoint> {
  final Value<String> id;
  final Value<String> polygonId;
  final Value<double> lat;
  final Value<double> lng;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const HeightPolygonPointsCompanion({
    this.id = const Value.absent(),
    this.polygonId = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HeightPolygonPointsCompanion.insert({
    required String id,
    required String polygonId,
    required double lat,
    required double lng,
    required int sortOrder,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       polygonId = Value(polygonId),
       lat = Value(lat),
       lng = Value(lng),
       sortOrder = Value(sortOrder);
  static Insertable<HeightPolygonPoint> custom({
    Expression<String>? id,
    Expression<String>? polygonId,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (polygonId != null) 'polygon_id': polygonId,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HeightPolygonPointsCompanion copyWith({
    Value<String>? id,
    Value<String>? polygonId,
    Value<double>? lat,
    Value<double>? lng,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return HeightPolygonPointsCompanion(
      id: id ?? this.id,
      polygonId: polygonId ?? this.polygonId,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (polygonId.present) {
      map['polygon_id'] = Variable<String>(polygonId.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HeightPolygonPointsCompanion(')
          ..write('id: $id, ')
          ..write('polygonId: $polygonId, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PoiSetsTable extends PoiSets with TableInfo<$PoiSetsTable, PoiSet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PoiSetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _layerIdMeta = const VerificationMeta(
    'layerId',
  );
  @override
  late final GeneratedColumn<String> layerId = GeneratedColumn<String>(
    'layer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES layers (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _categoryKeyMeta = const VerificationMeta(
    'categoryKey',
  );
  @override
  late final GeneratedColumn<String> categoryKey = GeneratedColumn<String>(
    'category_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _centerLatMeta = const VerificationMeta(
    'centerLat',
  );
  @override
  late final GeneratedColumn<double> centerLat = GeneratedColumn<double>(
    'center_lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _centerLngMeta = const VerificationMeta(
    'centerLng',
  );
  @override
  late final GeneratedColumn<double> centerLng = GeneratedColumn<double>(
    'center_lng',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _radiusMetersMeta = const VerificationMeta(
    'radiusMeters',
  );
  @override
  late final GeneratedColumn<double> radiusMeters = GeneratedColumn<double>(
    'radius_meters',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    layerId,
    categoryKey,
    centerLat,
    centerLng,
    radiusMeters,
    label,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'poi_sets';
  @override
  VerificationContext validateIntegrity(
    Insertable<PoiSet> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('layer_id')) {
      context.handle(
        _layerIdMeta,
        layerId.isAcceptableOrUnknown(data['layer_id']!, _layerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_layerIdMeta);
    }
    if (data.containsKey('category_key')) {
      context.handle(
        _categoryKeyMeta,
        categoryKey.isAcceptableOrUnknown(
          data['category_key']!,
          _categoryKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_categoryKeyMeta);
    }
    if (data.containsKey('center_lat')) {
      context.handle(
        _centerLatMeta,
        centerLat.isAcceptableOrUnknown(data['center_lat']!, _centerLatMeta),
      );
    } else if (isInserting) {
      context.missing(_centerLatMeta);
    }
    if (data.containsKey('center_lng')) {
      context.handle(
        _centerLngMeta,
        centerLng.isAcceptableOrUnknown(data['center_lng']!, _centerLngMeta),
      );
    } else if (isInserting) {
      context.missing(_centerLngMeta);
    }
    if (data.containsKey('radius_meters')) {
      context.handle(
        _radiusMetersMeta,
        radiusMeters.isAcceptableOrUnknown(
          data['radius_meters']!,
          _radiusMetersMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_radiusMetersMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PoiSet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PoiSet(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      layerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}layer_id'],
      )!,
      categoryKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_key'],
      )!,
      centerLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}center_lat'],
      )!,
      centerLng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}center_lng'],
      )!,
      radiusMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}radius_meters'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PoiSetsTable createAlias(String alias) {
    return $PoiSetsTable(attachedDatabase, alias);
  }
}

class PoiSet extends DataClass implements Insertable<PoiSet> {
  final String id;
  final String layerId;

  /// [PoiCategory.key] of the imported category (picks the marker icon).
  final String categoryKey;
  final double centerLat;
  final double centerLng;
  final double radiusMeters;
  final String? label;
  final DateTime createdAt;
  const PoiSet({
    required this.id,
    required this.layerId,
    required this.categoryKey,
    required this.centerLat,
    required this.centerLng,
    required this.radiusMeters,
    this.label,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['layer_id'] = Variable<String>(layerId);
    map['category_key'] = Variable<String>(categoryKey);
    map['center_lat'] = Variable<double>(centerLat);
    map['center_lng'] = Variable<double>(centerLng);
    map['radius_meters'] = Variable<double>(radiusMeters);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PoiSetsCompanion toCompanion(bool nullToAbsent) {
    return PoiSetsCompanion(
      id: Value(id),
      layerId: Value(layerId),
      categoryKey: Value(categoryKey),
      centerLat: Value(centerLat),
      centerLng: Value(centerLng),
      radiusMeters: Value(radiusMeters),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      createdAt: Value(createdAt),
    );
  }

  factory PoiSet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PoiSet(
      id: serializer.fromJson<String>(json['id']),
      layerId: serializer.fromJson<String>(json['layerId']),
      categoryKey: serializer.fromJson<String>(json['categoryKey']),
      centerLat: serializer.fromJson<double>(json['centerLat']),
      centerLng: serializer.fromJson<double>(json['centerLng']),
      radiusMeters: serializer.fromJson<double>(json['radiusMeters']),
      label: serializer.fromJson<String?>(json['label']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'layerId': serializer.toJson<String>(layerId),
      'categoryKey': serializer.toJson<String>(categoryKey),
      'centerLat': serializer.toJson<double>(centerLat),
      'centerLng': serializer.toJson<double>(centerLng),
      'radiusMeters': serializer.toJson<double>(radiusMeters),
      'label': serializer.toJson<String?>(label),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PoiSet copyWith({
    String? id,
    String? layerId,
    String? categoryKey,
    double? centerLat,
    double? centerLng,
    double? radiusMeters,
    Value<String?> label = const Value.absent(),
    DateTime? createdAt,
  }) => PoiSet(
    id: id ?? this.id,
    layerId: layerId ?? this.layerId,
    categoryKey: categoryKey ?? this.categoryKey,
    centerLat: centerLat ?? this.centerLat,
    centerLng: centerLng ?? this.centerLng,
    radiusMeters: radiusMeters ?? this.radiusMeters,
    label: label.present ? label.value : this.label,
    createdAt: createdAt ?? this.createdAt,
  );
  PoiSet copyWithCompanion(PoiSetsCompanion data) {
    return PoiSet(
      id: data.id.present ? data.id.value : this.id,
      layerId: data.layerId.present ? data.layerId.value : this.layerId,
      categoryKey: data.categoryKey.present
          ? data.categoryKey.value
          : this.categoryKey,
      centerLat: data.centerLat.present ? data.centerLat.value : this.centerLat,
      centerLng: data.centerLng.present ? data.centerLng.value : this.centerLng,
      radiusMeters: data.radiusMeters.present
          ? data.radiusMeters.value
          : this.radiusMeters,
      label: data.label.present ? data.label.value : this.label,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PoiSet(')
          ..write('id: $id, ')
          ..write('layerId: $layerId, ')
          ..write('categoryKey: $categoryKey, ')
          ..write('centerLat: $centerLat, ')
          ..write('centerLng: $centerLng, ')
          ..write('radiusMeters: $radiusMeters, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    layerId,
    categoryKey,
    centerLat,
    centerLng,
    radiusMeters,
    label,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PoiSet &&
          other.id == this.id &&
          other.layerId == this.layerId &&
          other.categoryKey == this.categoryKey &&
          other.centerLat == this.centerLat &&
          other.centerLng == this.centerLng &&
          other.radiusMeters == this.radiusMeters &&
          other.label == this.label &&
          other.createdAt == this.createdAt);
}

class PoiSetsCompanion extends UpdateCompanion<PoiSet> {
  final Value<String> id;
  final Value<String> layerId;
  final Value<String> categoryKey;
  final Value<double> centerLat;
  final Value<double> centerLng;
  final Value<double> radiusMeters;
  final Value<String?> label;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PoiSetsCompanion({
    this.id = const Value.absent(),
    this.layerId = const Value.absent(),
    this.categoryKey = const Value.absent(),
    this.centerLat = const Value.absent(),
    this.centerLng = const Value.absent(),
    this.radiusMeters = const Value.absent(),
    this.label = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PoiSetsCompanion.insert({
    required String id,
    required String layerId,
    required String categoryKey,
    required double centerLat,
    required double centerLng,
    required double radiusMeters,
    this.label = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       layerId = Value(layerId),
       categoryKey = Value(categoryKey),
       centerLat = Value(centerLat),
       centerLng = Value(centerLng),
       radiusMeters = Value(radiusMeters);
  static Insertable<PoiSet> custom({
    Expression<String>? id,
    Expression<String>? layerId,
    Expression<String>? categoryKey,
    Expression<double>? centerLat,
    Expression<double>? centerLng,
    Expression<double>? radiusMeters,
    Expression<String>? label,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (layerId != null) 'layer_id': layerId,
      if (categoryKey != null) 'category_key': categoryKey,
      if (centerLat != null) 'center_lat': centerLat,
      if (centerLng != null) 'center_lng': centerLng,
      if (radiusMeters != null) 'radius_meters': radiusMeters,
      if (label != null) 'label': label,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PoiSetsCompanion copyWith({
    Value<String>? id,
    Value<String>? layerId,
    Value<String>? categoryKey,
    Value<double>? centerLat,
    Value<double>? centerLng,
    Value<double>? radiusMeters,
    Value<String?>? label,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PoiSetsCompanion(
      id: id ?? this.id,
      layerId: layerId ?? this.layerId,
      categoryKey: categoryKey ?? this.categoryKey,
      centerLat: centerLat ?? this.centerLat,
      centerLng: centerLng ?? this.centerLng,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (layerId.present) {
      map['layer_id'] = Variable<String>(layerId.value);
    }
    if (categoryKey.present) {
      map['category_key'] = Variable<String>(categoryKey.value);
    }
    if (centerLat.present) {
      map['center_lat'] = Variable<double>(centerLat.value);
    }
    if (centerLng.present) {
      map['center_lng'] = Variable<double>(centerLng.value);
    }
    if (radiusMeters.present) {
      map['radius_meters'] = Variable<double>(radiusMeters.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PoiSetsCompanion(')
          ..write('id: $id, ')
          ..write('layerId: $layerId, ')
          ..write('categoryKey: $categoryKey, ')
          ..write('centerLat: $centerLat, ')
          ..write('centerLng: $centerLng, ')
          ..write('radiusMeters: $radiusMeters, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PoiPointsTable extends PoiPoints
    with TableInfo<$PoiPointsTable, PoiPoint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PoiPointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _poiSetIdMeta = const VerificationMeta(
    'poiSetId',
  );
  @override
  late final GeneratedColumn<String> poiSetId = GeneratedColumn<String>(
    'poi_set_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES poi_sets (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
    'lng',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _osmTypeMeta = const VerificationMeta(
    'osmType',
  );
  @override
  late final GeneratedColumn<String> osmType = GeneratedColumn<String>(
    'osm_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _osmIdMeta = const VerificationMeta('osmId');
  @override
  late final GeneratedColumn<int> osmId = GeneratedColumn<int>(
    'osm_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    poiSetId,
    lat,
    lng,
    name,
    sortOrder,
    createdAt,
    osmType,
    osmId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'poi_points';
  @override
  VerificationContext validateIntegrity(
    Insertable<PoiPoint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('poi_set_id')) {
      context.handle(
        _poiSetIdMeta,
        poiSetId.isAcceptableOrUnknown(data['poi_set_id']!, _poiSetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_poiSetIdMeta);
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    } else if (isInserting) {
      context.missing(_latMeta);
    }
    if (data.containsKey('lng')) {
      context.handle(
        _lngMeta,
        lng.isAcceptableOrUnknown(data['lng']!, _lngMeta),
      );
    } else if (isInserting) {
      context.missing(_lngMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('osm_type')) {
      context.handle(
        _osmTypeMeta,
        osmType.isAcceptableOrUnknown(data['osm_type']!, _osmTypeMeta),
      );
    }
    if (data.containsKey('osm_id')) {
      context.handle(
        _osmIdMeta,
        osmId.isAcceptableOrUnknown(data['osm_id']!, _osmIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PoiPoint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PoiPoint(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      poiSetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}poi_set_id'],
      )!,
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      )!,
      lng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lng'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      osmType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}osm_type'],
      ),
      osmId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}osm_id'],
      ),
    );
  }

  @override
  $PoiPointsTable createAlias(String alias) {
    return $PoiPointsTable(attachedDatabase, alias);
  }
}

class PoiPoint extends DataClass implements Insertable<PoiPoint> {
  final String id;
  final String poiSetId;
  final double lat;
  final double lng;
  final String? name;
  final int sortOrder;
  final DateTime createdAt;

  /// The OSM element this POI came from, so a second import over overlapping
  /// ground can recognise it (v21). **Both** parts are needed: ids are only
  /// unique *within* a type, so node 240109189 and way 240109189 are different
  /// things.
  ///
  /// Nullable because rows imported before v21 never recorded it, and a
  /// backfill is impossible — the id was not merely unstored, it was never
  /// fetched. An unidentified row simply doesn't participate in dedup; see
  /// [Repository.addPoiPoints].
  final String? osmType;
  final int? osmId;
  const PoiPoint({
    required this.id,
    required this.poiSetId,
    required this.lat,
    required this.lng,
    this.name,
    required this.sortOrder,
    required this.createdAt,
    this.osmType,
    this.osmId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['poi_set_id'] = Variable<String>(poiSetId);
    map['lat'] = Variable<double>(lat);
    map['lng'] = Variable<double>(lng);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || osmType != null) {
      map['osm_type'] = Variable<String>(osmType);
    }
    if (!nullToAbsent || osmId != null) {
      map['osm_id'] = Variable<int>(osmId);
    }
    return map;
  }

  PoiPointsCompanion toCompanion(bool nullToAbsent) {
    return PoiPointsCompanion(
      id: Value(id),
      poiSetId: Value(poiSetId),
      lat: Value(lat),
      lng: Value(lng),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      osmType: osmType == null && nullToAbsent
          ? const Value.absent()
          : Value(osmType),
      osmId: osmId == null && nullToAbsent
          ? const Value.absent()
          : Value(osmId),
    );
  }

  factory PoiPoint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PoiPoint(
      id: serializer.fromJson<String>(json['id']),
      poiSetId: serializer.fromJson<String>(json['poiSetId']),
      lat: serializer.fromJson<double>(json['lat']),
      lng: serializer.fromJson<double>(json['lng']),
      name: serializer.fromJson<String?>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      osmType: serializer.fromJson<String?>(json['osmType']),
      osmId: serializer.fromJson<int?>(json['osmId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'poiSetId': serializer.toJson<String>(poiSetId),
      'lat': serializer.toJson<double>(lat),
      'lng': serializer.toJson<double>(lng),
      'name': serializer.toJson<String?>(name),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'osmType': serializer.toJson<String?>(osmType),
      'osmId': serializer.toJson<int?>(osmId),
    };
  }

  PoiPoint copyWith({
    String? id,
    String? poiSetId,
    double? lat,
    double? lng,
    Value<String?> name = const Value.absent(),
    int? sortOrder,
    DateTime? createdAt,
    Value<String?> osmType = const Value.absent(),
    Value<int?> osmId = const Value.absent(),
  }) => PoiPoint(
    id: id ?? this.id,
    poiSetId: poiSetId ?? this.poiSetId,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    name: name.present ? name.value : this.name,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    osmType: osmType.present ? osmType.value : this.osmType,
    osmId: osmId.present ? osmId.value : this.osmId,
  );
  PoiPoint copyWithCompanion(PoiPointsCompanion data) {
    return PoiPoint(
      id: data.id.present ? data.id.value : this.id,
      poiSetId: data.poiSetId.present ? data.poiSetId.value : this.poiSetId,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      osmType: data.osmType.present ? data.osmType.value : this.osmType,
      osmId: data.osmId.present ? data.osmId.value : this.osmId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PoiPoint(')
          ..write('id: $id, ')
          ..write('poiSetId: $poiSetId, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('osmType: $osmType, ')
          ..write('osmId: $osmId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    poiSetId,
    lat,
    lng,
    name,
    sortOrder,
    createdAt,
    osmType,
    osmId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PoiPoint &&
          other.id == this.id &&
          other.poiSetId == this.poiSetId &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.osmType == this.osmType &&
          other.osmId == this.osmId);
}

class PoiPointsCompanion extends UpdateCompanion<PoiPoint> {
  final Value<String> id;
  final Value<String> poiSetId;
  final Value<double> lat;
  final Value<double> lng;
  final Value<String?> name;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<String?> osmType;
  final Value<int?> osmId;
  final Value<int> rowid;
  const PoiPointsCompanion({
    this.id = const Value.absent(),
    this.poiSetId = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.osmType = const Value.absent(),
    this.osmId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PoiPointsCompanion.insert({
    required String id,
    required String poiSetId,
    required double lat,
    required double lng,
    this.name = const Value.absent(),
    required int sortOrder,
    this.createdAt = const Value.absent(),
    this.osmType = const Value.absent(),
    this.osmId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       poiSetId = Value(poiSetId),
       lat = Value(lat),
       lng = Value(lng),
       sortOrder = Value(sortOrder);
  static Insertable<PoiPoint> custom({
    Expression<String>? id,
    Expression<String>? poiSetId,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<String>? name,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<String>? osmType,
    Expression<int>? osmId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (poiSetId != null) 'poi_set_id': poiSetId,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (osmType != null) 'osm_type': osmType,
      if (osmId != null) 'osm_id': osmId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PoiPointsCompanion copyWith({
    Value<String>? id,
    Value<String>? poiSetId,
    Value<double>? lat,
    Value<double>? lng,
    Value<String?>? name,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<String?>? osmType,
    Value<int?>? osmId,
    Value<int>? rowid,
  }) {
    return PoiPointsCompanion(
      id: id ?? this.id,
      poiSetId: poiSetId ?? this.poiSetId,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      osmType: osmType ?? this.osmType,
      osmId: osmId ?? this.osmId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (poiSetId.present) {
      map['poi_set_id'] = Variable<String>(poiSetId.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (osmType.present) {
      map['osm_type'] = Variable<String>(osmType.value);
    }
    if (osmId.present) {
      map['osm_id'] = Variable<int>(osmId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PoiPointsCompanion(')
          ..write('id: $id, ')
          ..write('poiSetId: $poiSetId, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('osmType: $osmType, ')
          ..write('osmId: $osmId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransitSetsTable extends TransitSets
    with TableInfo<$TransitSetsTable, TransitSet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransitSetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _layerIdMeta = const VerificationMeta(
    'layerId',
  );
  @override
  late final GeneratedColumn<String> layerId = GeneratedColumn<String>(
    'layer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES layers (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _southMeta = const VerificationMeta('south');
  @override
  late final GeneratedColumn<double> south = GeneratedColumn<double>(
    'south',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _westMeta = const VerificationMeta('west');
  @override
  late final GeneratedColumn<double> west = GeneratedColumn<double>(
    'west',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _northMeta = const VerificationMeta('north');
  @override
  late final GeneratedColumn<double> north = GeneratedColumn<double>(
    'north',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eastMeta = const VerificationMeta('east');
  @override
  late final GeneratedColumn<double> east = GeneratedColumn<double>(
    'east',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modeMaskMeta = const VerificationMeta(
    'modeMask',
  );
  @override
  late final GeneratedColumn<int> modeMask = GeneratedColumn<int>(
    'mode_mask',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _visibleModeMaskMeta = const VerificationMeta(
    'visibleModeMask',
  );
  @override
  late final GeneratedColumn<int> visibleModeMask = GeneratedColumn<int>(
    'visible_mode_mask',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(-1),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stationCountMeta = const VerificationMeta(
    'stationCount',
  );
  @override
  late final GeneratedColumn<int> stationCount = GeneratedColumn<int>(
    'station_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nodeCountMeta = const VerificationMeta(
    'nodeCount',
  );
  @override
  late final GeneratedColumn<int> nodeCount = GeneratedColumn<int>(
    'node_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    layerId,
    south,
    west,
    north,
    east,
    modeMask,
    visibleModeMask,
    label,
    fetchedAt,
    lastError,
    stationCount,
    nodeCount,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transit_sets';
  @override
  VerificationContext validateIntegrity(
    Insertable<TransitSet> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('layer_id')) {
      context.handle(
        _layerIdMeta,
        layerId.isAcceptableOrUnknown(data['layer_id']!, _layerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_layerIdMeta);
    }
    if (data.containsKey('south')) {
      context.handle(
        _southMeta,
        south.isAcceptableOrUnknown(data['south']!, _southMeta),
      );
    } else if (isInserting) {
      context.missing(_southMeta);
    }
    if (data.containsKey('west')) {
      context.handle(
        _westMeta,
        west.isAcceptableOrUnknown(data['west']!, _westMeta),
      );
    } else if (isInserting) {
      context.missing(_westMeta);
    }
    if (data.containsKey('north')) {
      context.handle(
        _northMeta,
        north.isAcceptableOrUnknown(data['north']!, _northMeta),
      );
    } else if (isInserting) {
      context.missing(_northMeta);
    }
    if (data.containsKey('east')) {
      context.handle(
        _eastMeta,
        east.isAcceptableOrUnknown(data['east']!, _eastMeta),
      );
    } else if (isInserting) {
      context.missing(_eastMeta);
    }
    if (data.containsKey('mode_mask')) {
      context.handle(
        _modeMaskMeta,
        modeMask.isAcceptableOrUnknown(data['mode_mask']!, _modeMaskMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMaskMeta);
    }
    if (data.containsKey('visible_mode_mask')) {
      context.handle(
        _visibleModeMaskMeta,
        visibleModeMask.isAcceptableOrUnknown(
          data['visible_mode_mask']!,
          _visibleModeMaskMeta,
        ),
      );
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('station_count')) {
      context.handle(
        _stationCountMeta,
        stationCount.isAcceptableOrUnknown(
          data['station_count']!,
          _stationCountMeta,
        ),
      );
    }
    if (data.containsKey('node_count')) {
      context.handle(
        _nodeCountMeta,
        nodeCount.isAcceptableOrUnknown(data['node_count']!, _nodeCountMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TransitSet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransitSet(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      layerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}layer_id'],
      )!,
      south: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}south'],
      )!,
      west: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}west'],
      )!,
      north: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}north'],
      )!,
      east: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}east'],
      )!,
      modeMask: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mode_mask'],
      )!,
      visibleModeMask: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}visible_mode_mask'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      stationCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}station_count'],
      )!,
      nodeCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}node_count'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TransitSetsTable createAlias(String alias) {
    return $TransitSetsTable(attachedDatabase, alias);
  }
}

class TransitSet extends DataClass implements Insertable<TransitSet> {
  final String id;
  final String layerId;

  /// The imported bounding box.
  final double south;
  final double west;
  final double north;
  final double east;

  /// Which modes were fetched (packed `TransitMode.bit`s), chosen in the import
  /// dialog. This is the **contents** of the set, not a filter: what it omits
  /// was never stored, so widening it means importing again — which is exactly
  /// what a retry of a failed import must not do differently.
  final int modeMask;

  /// Which of those modes are **shown**. This is what the filter sheet writes;
  /// it starts from `modeMask & defaultVisibleModes(diagonal)`, which hides
  /// buses on a city-sized import because they outnumber everything else ~7:1.
  final int visibleModeMask;
  final String? label;

  /// When the data was pulled from OSM. **Null = the import hasn't succeeded
  /// yet** — the layer shows it as a retry row until it does, so a failure is
  /// something you can come back to rather than a lost snackbar.
  final DateTime? fetchedAt;

  /// Why the last attempt failed, shown on that retry row.
  final String? lastError;

  /// Denormalised for the Elements subtitle without a join: stations stored,
  /// and how many raw OSM nodes merged into them.
  final int stationCount;
  final int nodeCount;
  final DateTime createdAt;
  const TransitSet({
    required this.id,
    required this.layerId,
    required this.south,
    required this.west,
    required this.north,
    required this.east,
    required this.modeMask,
    required this.visibleModeMask,
    this.label,
    this.fetchedAt,
    this.lastError,
    required this.stationCount,
    required this.nodeCount,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['layer_id'] = Variable<String>(layerId);
    map['south'] = Variable<double>(south);
    map['west'] = Variable<double>(west);
    map['north'] = Variable<double>(north);
    map['east'] = Variable<double>(east);
    map['mode_mask'] = Variable<int>(modeMask);
    map['visible_mode_mask'] = Variable<int>(visibleModeMask);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    if (!nullToAbsent || fetchedAt != null) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['station_count'] = Variable<int>(stationCount);
    map['node_count'] = Variable<int>(nodeCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TransitSetsCompanion toCompanion(bool nullToAbsent) {
    return TransitSetsCompanion(
      id: Value(id),
      layerId: Value(layerId),
      south: Value(south),
      west: Value(west),
      north: Value(north),
      east: Value(east),
      modeMask: Value(modeMask),
      visibleModeMask: Value(visibleModeMask),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      fetchedAt: fetchedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(fetchedAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      stationCount: Value(stationCount),
      nodeCount: Value(nodeCount),
      createdAt: Value(createdAt),
    );
  }

  factory TransitSet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransitSet(
      id: serializer.fromJson<String>(json['id']),
      layerId: serializer.fromJson<String>(json['layerId']),
      south: serializer.fromJson<double>(json['south']),
      west: serializer.fromJson<double>(json['west']),
      north: serializer.fromJson<double>(json['north']),
      east: serializer.fromJson<double>(json['east']),
      modeMask: serializer.fromJson<int>(json['modeMask']),
      visibleModeMask: serializer.fromJson<int>(json['visibleModeMask']),
      label: serializer.fromJson<String?>(json['label']),
      fetchedAt: serializer.fromJson<DateTime?>(json['fetchedAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      stationCount: serializer.fromJson<int>(json['stationCount']),
      nodeCount: serializer.fromJson<int>(json['nodeCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'layerId': serializer.toJson<String>(layerId),
      'south': serializer.toJson<double>(south),
      'west': serializer.toJson<double>(west),
      'north': serializer.toJson<double>(north),
      'east': serializer.toJson<double>(east),
      'modeMask': serializer.toJson<int>(modeMask),
      'visibleModeMask': serializer.toJson<int>(visibleModeMask),
      'label': serializer.toJson<String?>(label),
      'fetchedAt': serializer.toJson<DateTime?>(fetchedAt),
      'lastError': serializer.toJson<String?>(lastError),
      'stationCount': serializer.toJson<int>(stationCount),
      'nodeCount': serializer.toJson<int>(nodeCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TransitSet copyWith({
    String? id,
    String? layerId,
    double? south,
    double? west,
    double? north,
    double? east,
    int? modeMask,
    int? visibleModeMask,
    Value<String?> label = const Value.absent(),
    Value<DateTime?> fetchedAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    int? stationCount,
    int? nodeCount,
    DateTime? createdAt,
  }) => TransitSet(
    id: id ?? this.id,
    layerId: layerId ?? this.layerId,
    south: south ?? this.south,
    west: west ?? this.west,
    north: north ?? this.north,
    east: east ?? this.east,
    modeMask: modeMask ?? this.modeMask,
    visibleModeMask: visibleModeMask ?? this.visibleModeMask,
    label: label.present ? label.value : this.label,
    fetchedAt: fetchedAt.present ? fetchedAt.value : this.fetchedAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    stationCount: stationCount ?? this.stationCount,
    nodeCount: nodeCount ?? this.nodeCount,
    createdAt: createdAt ?? this.createdAt,
  );
  TransitSet copyWithCompanion(TransitSetsCompanion data) {
    return TransitSet(
      id: data.id.present ? data.id.value : this.id,
      layerId: data.layerId.present ? data.layerId.value : this.layerId,
      south: data.south.present ? data.south.value : this.south,
      west: data.west.present ? data.west.value : this.west,
      north: data.north.present ? data.north.value : this.north,
      east: data.east.present ? data.east.value : this.east,
      modeMask: data.modeMask.present ? data.modeMask.value : this.modeMask,
      visibleModeMask: data.visibleModeMask.present
          ? data.visibleModeMask.value
          : this.visibleModeMask,
      label: data.label.present ? data.label.value : this.label,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      stationCount: data.stationCount.present
          ? data.stationCount.value
          : this.stationCount,
      nodeCount: data.nodeCount.present ? data.nodeCount.value : this.nodeCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransitSet(')
          ..write('id: $id, ')
          ..write('layerId: $layerId, ')
          ..write('south: $south, ')
          ..write('west: $west, ')
          ..write('north: $north, ')
          ..write('east: $east, ')
          ..write('modeMask: $modeMask, ')
          ..write('visibleModeMask: $visibleModeMask, ')
          ..write('label: $label, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('lastError: $lastError, ')
          ..write('stationCount: $stationCount, ')
          ..write('nodeCount: $nodeCount, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    layerId,
    south,
    west,
    north,
    east,
    modeMask,
    visibleModeMask,
    label,
    fetchedAt,
    lastError,
    stationCount,
    nodeCount,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransitSet &&
          other.id == this.id &&
          other.layerId == this.layerId &&
          other.south == this.south &&
          other.west == this.west &&
          other.north == this.north &&
          other.east == this.east &&
          other.modeMask == this.modeMask &&
          other.visibleModeMask == this.visibleModeMask &&
          other.label == this.label &&
          other.fetchedAt == this.fetchedAt &&
          other.lastError == this.lastError &&
          other.stationCount == this.stationCount &&
          other.nodeCount == this.nodeCount &&
          other.createdAt == this.createdAt);
}

class TransitSetsCompanion extends UpdateCompanion<TransitSet> {
  final Value<String> id;
  final Value<String> layerId;
  final Value<double> south;
  final Value<double> west;
  final Value<double> north;
  final Value<double> east;
  final Value<int> modeMask;
  final Value<int> visibleModeMask;
  final Value<String?> label;
  final Value<DateTime?> fetchedAt;
  final Value<String?> lastError;
  final Value<int> stationCount;
  final Value<int> nodeCount;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TransitSetsCompanion({
    this.id = const Value.absent(),
    this.layerId = const Value.absent(),
    this.south = const Value.absent(),
    this.west = const Value.absent(),
    this.north = const Value.absent(),
    this.east = const Value.absent(),
    this.modeMask = const Value.absent(),
    this.visibleModeMask = const Value.absent(),
    this.label = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.stationCount = const Value.absent(),
    this.nodeCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransitSetsCompanion.insert({
    required String id,
    required String layerId,
    required double south,
    required double west,
    required double north,
    required double east,
    required int modeMask,
    this.visibleModeMask = const Value.absent(),
    this.label = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.stationCount = const Value.absent(),
    this.nodeCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       layerId = Value(layerId),
       south = Value(south),
       west = Value(west),
       north = Value(north),
       east = Value(east),
       modeMask = Value(modeMask);
  static Insertable<TransitSet> custom({
    Expression<String>? id,
    Expression<String>? layerId,
    Expression<double>? south,
    Expression<double>? west,
    Expression<double>? north,
    Expression<double>? east,
    Expression<int>? modeMask,
    Expression<int>? visibleModeMask,
    Expression<String>? label,
    Expression<DateTime>? fetchedAt,
    Expression<String>? lastError,
    Expression<int>? stationCount,
    Expression<int>? nodeCount,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (layerId != null) 'layer_id': layerId,
      if (south != null) 'south': south,
      if (west != null) 'west': west,
      if (north != null) 'north': north,
      if (east != null) 'east': east,
      if (modeMask != null) 'mode_mask': modeMask,
      if (visibleModeMask != null) 'visible_mode_mask': visibleModeMask,
      if (label != null) 'label': label,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (lastError != null) 'last_error': lastError,
      if (stationCount != null) 'station_count': stationCount,
      if (nodeCount != null) 'node_count': nodeCount,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransitSetsCompanion copyWith({
    Value<String>? id,
    Value<String>? layerId,
    Value<double>? south,
    Value<double>? west,
    Value<double>? north,
    Value<double>? east,
    Value<int>? modeMask,
    Value<int>? visibleModeMask,
    Value<String?>? label,
    Value<DateTime?>? fetchedAt,
    Value<String?>? lastError,
    Value<int>? stationCount,
    Value<int>? nodeCount,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return TransitSetsCompanion(
      id: id ?? this.id,
      layerId: layerId ?? this.layerId,
      south: south ?? this.south,
      west: west ?? this.west,
      north: north ?? this.north,
      east: east ?? this.east,
      modeMask: modeMask ?? this.modeMask,
      visibleModeMask: visibleModeMask ?? this.visibleModeMask,
      label: label ?? this.label,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      lastError: lastError ?? this.lastError,
      stationCount: stationCount ?? this.stationCount,
      nodeCount: nodeCount ?? this.nodeCount,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (layerId.present) {
      map['layer_id'] = Variable<String>(layerId.value);
    }
    if (south.present) {
      map['south'] = Variable<double>(south.value);
    }
    if (west.present) {
      map['west'] = Variable<double>(west.value);
    }
    if (north.present) {
      map['north'] = Variable<double>(north.value);
    }
    if (east.present) {
      map['east'] = Variable<double>(east.value);
    }
    if (modeMask.present) {
      map['mode_mask'] = Variable<int>(modeMask.value);
    }
    if (visibleModeMask.present) {
      map['visible_mode_mask'] = Variable<int>(visibleModeMask.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (stationCount.present) {
      map['station_count'] = Variable<int>(stationCount.value);
    }
    if (nodeCount.present) {
      map['node_count'] = Variable<int>(nodeCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransitSetsCompanion(')
          ..write('id: $id, ')
          ..write('layerId: $layerId, ')
          ..write('south: $south, ')
          ..write('west: $west, ')
          ..write('north: $north, ')
          ..write('east: $east, ')
          ..write('modeMask: $modeMask, ')
          ..write('visibleModeMask: $visibleModeMask, ')
          ..write('label: $label, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('lastError: $lastError, ')
          ..write('stationCount: $stationCount, ')
          ..write('nodeCount: $nodeCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransitStopsTable extends TransitStops
    with TableInfo<$TransitStopsTable, TransitStop> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransitStopsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _setIdMeta = const VerificationMeta('setId');
  @override
  late final GeneratedColumn<String> setId = GeneratedColumn<String>(
    'set_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES transit_sets (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _osmIdMeta = const VerificationMeta('osmId');
  @override
  late final GeneratedColumn<int> osmId = GeneratedColumn<int>(
    'osm_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
    'lng',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modeMaskMeta = const VerificationMeta(
    'modeMask',
  );
  @override
  late final GeneratedColumn<int> modeMask = GeneratedColumn<int>(
    'mode_mask',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nodeCountMeta = const VerificationMeta(
    'nodeCount',
  );
  @override
  late final GeneratedColumn<int> nodeCount = GeneratedColumn<int>(
    'node_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _routeRefMeta = const VerificationMeta(
    'routeRef',
  );
  @override
  late final GeneratedColumn<String> routeRef = GeneratedColumn<String>(
    'route_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    setId,
    osmId,
    lat,
    lng,
    name,
    modeMask,
    nodeCount,
    routeRef,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transit_stops';
  @override
  VerificationContext validateIntegrity(
    Insertable<TransitStop> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('set_id')) {
      context.handle(
        _setIdMeta,
        setId.isAcceptableOrUnknown(data['set_id']!, _setIdMeta),
      );
    } else if (isInserting) {
      context.missing(_setIdMeta);
    }
    if (data.containsKey('osm_id')) {
      context.handle(
        _osmIdMeta,
        osmId.isAcceptableOrUnknown(data['osm_id']!, _osmIdMeta),
      );
    } else if (isInserting) {
      context.missing(_osmIdMeta);
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    } else if (isInserting) {
      context.missing(_latMeta);
    }
    if (data.containsKey('lng')) {
      context.handle(
        _lngMeta,
        lng.isAcceptableOrUnknown(data['lng']!, _lngMeta),
      );
    } else if (isInserting) {
      context.missing(_lngMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('mode_mask')) {
      context.handle(
        _modeMaskMeta,
        modeMask.isAcceptableOrUnknown(data['mode_mask']!, _modeMaskMeta),
      );
    }
    if (data.containsKey('node_count')) {
      context.handle(
        _nodeCountMeta,
        nodeCount.isAcceptableOrUnknown(data['node_count']!, _nodeCountMeta),
      );
    }
    if (data.containsKey('route_ref')) {
      context.handle(
        _routeRefMeta,
        routeRef.isAcceptableOrUnknown(data['route_ref']!, _routeRefMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TransitStop map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransitStop(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      setId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}set_id'],
      )!,
      osmId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}osm_id'],
      )!,
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      )!,
      lng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lng'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      modeMask: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mode_mask'],
      )!,
      nodeCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}node_count'],
      )!,
      routeRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}route_ref'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TransitStopsTable createAlias(String alias) {
    return $TransitStopsTable(attachedDatabase, alias);
  }
}

class TransitStop extends DataClass implements Insertable<TransitStop> {
  final String id;
  final String setId;

  /// The OSM node the station was keyed on (the `station` node when there was
  /// one), so it can be looked up on osm.org.
  final int osmId;
  final double lat;
  final double lng;
  final String? name;

  /// The modes serving this station (packed bits); 0 = the data doesn't say.
  /// A station is drawn iff `modeMask & set.visibleModeMask != 0`.
  final int modeMask;

  /// How many OSM nodes merged into this station.
  final int nodeCount;

  /// The OSM `route_ref` tag when present (~18 % of stops) — free text shown as
  /// a hint. Never parsed, never relied on.
  final String? routeRef;
  final DateTime createdAt;
  const TransitStop({
    required this.id,
    required this.setId,
    required this.osmId,
    required this.lat,
    required this.lng,
    this.name,
    required this.modeMask,
    required this.nodeCount,
    this.routeRef,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['set_id'] = Variable<String>(setId);
    map['osm_id'] = Variable<int>(osmId);
    map['lat'] = Variable<double>(lat);
    map['lng'] = Variable<double>(lng);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    map['mode_mask'] = Variable<int>(modeMask);
    map['node_count'] = Variable<int>(nodeCount);
    if (!nullToAbsent || routeRef != null) {
      map['route_ref'] = Variable<String>(routeRef);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TransitStopsCompanion toCompanion(bool nullToAbsent) {
    return TransitStopsCompanion(
      id: Value(id),
      setId: Value(setId),
      osmId: Value(osmId),
      lat: Value(lat),
      lng: Value(lng),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      modeMask: Value(modeMask),
      nodeCount: Value(nodeCount),
      routeRef: routeRef == null && nullToAbsent
          ? const Value.absent()
          : Value(routeRef),
      createdAt: Value(createdAt),
    );
  }

  factory TransitStop.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransitStop(
      id: serializer.fromJson<String>(json['id']),
      setId: serializer.fromJson<String>(json['setId']),
      osmId: serializer.fromJson<int>(json['osmId']),
      lat: serializer.fromJson<double>(json['lat']),
      lng: serializer.fromJson<double>(json['lng']),
      name: serializer.fromJson<String?>(json['name']),
      modeMask: serializer.fromJson<int>(json['modeMask']),
      nodeCount: serializer.fromJson<int>(json['nodeCount']),
      routeRef: serializer.fromJson<String?>(json['routeRef']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'setId': serializer.toJson<String>(setId),
      'osmId': serializer.toJson<int>(osmId),
      'lat': serializer.toJson<double>(lat),
      'lng': serializer.toJson<double>(lng),
      'name': serializer.toJson<String?>(name),
      'modeMask': serializer.toJson<int>(modeMask),
      'nodeCount': serializer.toJson<int>(nodeCount),
      'routeRef': serializer.toJson<String?>(routeRef),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TransitStop copyWith({
    String? id,
    String? setId,
    int? osmId,
    double? lat,
    double? lng,
    Value<String?> name = const Value.absent(),
    int? modeMask,
    int? nodeCount,
    Value<String?> routeRef = const Value.absent(),
    DateTime? createdAt,
  }) => TransitStop(
    id: id ?? this.id,
    setId: setId ?? this.setId,
    osmId: osmId ?? this.osmId,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    name: name.present ? name.value : this.name,
    modeMask: modeMask ?? this.modeMask,
    nodeCount: nodeCount ?? this.nodeCount,
    routeRef: routeRef.present ? routeRef.value : this.routeRef,
    createdAt: createdAt ?? this.createdAt,
  );
  TransitStop copyWithCompanion(TransitStopsCompanion data) {
    return TransitStop(
      id: data.id.present ? data.id.value : this.id,
      setId: data.setId.present ? data.setId.value : this.setId,
      osmId: data.osmId.present ? data.osmId.value : this.osmId,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      name: data.name.present ? data.name.value : this.name,
      modeMask: data.modeMask.present ? data.modeMask.value : this.modeMask,
      nodeCount: data.nodeCount.present ? data.nodeCount.value : this.nodeCount,
      routeRef: data.routeRef.present ? data.routeRef.value : this.routeRef,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransitStop(')
          ..write('id: $id, ')
          ..write('setId: $setId, ')
          ..write('osmId: $osmId, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('name: $name, ')
          ..write('modeMask: $modeMask, ')
          ..write('nodeCount: $nodeCount, ')
          ..write('routeRef: $routeRef, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    setId,
    osmId,
    lat,
    lng,
    name,
    modeMask,
    nodeCount,
    routeRef,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransitStop &&
          other.id == this.id &&
          other.setId == this.setId &&
          other.osmId == this.osmId &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.name == this.name &&
          other.modeMask == this.modeMask &&
          other.nodeCount == this.nodeCount &&
          other.routeRef == this.routeRef &&
          other.createdAt == this.createdAt);
}

class TransitStopsCompanion extends UpdateCompanion<TransitStop> {
  final Value<String> id;
  final Value<String> setId;
  final Value<int> osmId;
  final Value<double> lat;
  final Value<double> lng;
  final Value<String?> name;
  final Value<int> modeMask;
  final Value<int> nodeCount;
  final Value<String?> routeRef;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const TransitStopsCompanion({
    this.id = const Value.absent(),
    this.setId = const Value.absent(),
    this.osmId = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.name = const Value.absent(),
    this.modeMask = const Value.absent(),
    this.nodeCount = const Value.absent(),
    this.routeRef = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransitStopsCompanion.insert({
    required String id,
    required String setId,
    required int osmId,
    required double lat,
    required double lng,
    this.name = const Value.absent(),
    this.modeMask = const Value.absent(),
    this.nodeCount = const Value.absent(),
    this.routeRef = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       setId = Value(setId),
       osmId = Value(osmId),
       lat = Value(lat),
       lng = Value(lng);
  static Insertable<TransitStop> custom({
    Expression<String>? id,
    Expression<String>? setId,
    Expression<int>? osmId,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<String>? name,
    Expression<int>? modeMask,
    Expression<int>? nodeCount,
    Expression<String>? routeRef,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (setId != null) 'set_id': setId,
      if (osmId != null) 'osm_id': osmId,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (name != null) 'name': name,
      if (modeMask != null) 'mode_mask': modeMask,
      if (nodeCount != null) 'node_count': nodeCount,
      if (routeRef != null) 'route_ref': routeRef,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransitStopsCompanion copyWith({
    Value<String>? id,
    Value<String>? setId,
    Value<int>? osmId,
    Value<double>? lat,
    Value<double>? lng,
    Value<String?>? name,
    Value<int>? modeMask,
    Value<int>? nodeCount,
    Value<String?>? routeRef,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return TransitStopsCompanion(
      id: id ?? this.id,
      setId: setId ?? this.setId,
      osmId: osmId ?? this.osmId,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      name: name ?? this.name,
      modeMask: modeMask ?? this.modeMask,
      nodeCount: nodeCount ?? this.nodeCount,
      routeRef: routeRef ?? this.routeRef,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (setId.present) {
      map['set_id'] = Variable<String>(setId.value);
    }
    if (osmId.present) {
      map['osm_id'] = Variable<int>(osmId.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (modeMask.present) {
      map['mode_mask'] = Variable<int>(modeMask.value);
    }
    if (nodeCount.present) {
      map['node_count'] = Variable<int>(nodeCount.value);
    }
    if (routeRef.present) {
      map['route_ref'] = Variable<String>(routeRef.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransitStopsCompanion(')
          ..write('id: $id, ')
          ..write('setId: $setId, ')
          ..write('osmId: $osmId, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('name: $name, ')
          ..write('modeMask: $modeMask, ')
          ..write('nodeCount: $nodeCount, ')
          ..write('routeRef: $routeRef, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BorderSetsTable extends BorderSets
    with TableInfo<$BorderSetsTable, BorderSet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BorderSetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _layerIdMeta = const VerificationMeta(
    'layerId',
  );
  @override
  late final GeneratedColumn<String> layerId = GeneratedColumn<String>(
    'layer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES layers (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _southMeta = const VerificationMeta('south');
  @override
  late final GeneratedColumn<double> south = GeneratedColumn<double>(
    'south',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _westMeta = const VerificationMeta('west');
  @override
  late final GeneratedColumn<double> west = GeneratedColumn<double>(
    'west',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _northMeta = const VerificationMeta('north');
  @override
  late final GeneratedColumn<double> north = GeneratedColumn<double>(
    'north',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eastMeta = const VerificationMeta('east');
  @override
  late final GeneratedColumn<double> east = GeneratedColumn<double>(
    'east',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _adminLevelMeta = const VerificationMeta(
    'adminLevel',
  );
  @override
  late final GeneratedColumn<String> adminLevel = GeneratedColumn<String>(
    'admin_level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _areaCountMeta = const VerificationMeta(
    'areaCount',
  );
  @override
  late final GeneratedColumn<int> areaCount = GeneratedColumn<int>(
    'area_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pointCountMeta = const VerificationMeta(
    'pointCount',
  );
  @override
  late final GeneratedColumn<int> pointCount = GeneratedColumn<int>(
    'point_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    layerId,
    south,
    west,
    north,
    east,
    adminLevel,
    label,
    fetchedAt,
    areaCount,
    pointCount,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'border_sets';
  @override
  VerificationContext validateIntegrity(
    Insertable<BorderSet> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('layer_id')) {
      context.handle(
        _layerIdMeta,
        layerId.isAcceptableOrUnknown(data['layer_id']!, _layerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_layerIdMeta);
    }
    if (data.containsKey('south')) {
      context.handle(
        _southMeta,
        south.isAcceptableOrUnknown(data['south']!, _southMeta),
      );
    } else if (isInserting) {
      context.missing(_southMeta);
    }
    if (data.containsKey('west')) {
      context.handle(
        _westMeta,
        west.isAcceptableOrUnknown(data['west']!, _westMeta),
      );
    } else if (isInserting) {
      context.missing(_westMeta);
    }
    if (data.containsKey('north')) {
      context.handle(
        _northMeta,
        north.isAcceptableOrUnknown(data['north']!, _northMeta),
      );
    } else if (isInserting) {
      context.missing(_northMeta);
    }
    if (data.containsKey('east')) {
      context.handle(
        _eastMeta,
        east.isAcceptableOrUnknown(data['east']!, _eastMeta),
      );
    } else if (isInserting) {
      context.missing(_eastMeta);
    }
    if (data.containsKey('admin_level')) {
      context.handle(
        _adminLevelMeta,
        adminLevel.isAcceptableOrUnknown(data['admin_level']!, _adminLevelMeta),
      );
    } else if (isInserting) {
      context.missing(_adminLevelMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    if (data.containsKey('area_count')) {
      context.handle(
        _areaCountMeta,
        areaCount.isAcceptableOrUnknown(data['area_count']!, _areaCountMeta),
      );
    }
    if (data.containsKey('point_count')) {
      context.handle(
        _pointCountMeta,
        pointCount.isAcceptableOrUnknown(data['point_count']!, _pointCountMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BorderSet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BorderSet(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      layerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}layer_id'],
      )!,
      south: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}south'],
      )!,
      west: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}west'],
      )!,
      north: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}north'],
      )!,
      east: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}east'],
      )!,
      adminLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}admin_level'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
      areaCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}area_count'],
      )!,
      pointCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}point_count'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BorderSetsTable createAlias(String alias) {
    return $BorderSetsTable(attachedDatabase, alias);
  }
}

class BorderSet extends DataClass implements Insertable<BorderSet> {
  final String id;
  final String layerId;

  /// The imported box. Doubles as the clip rectangle the stored geometry was
  /// cut to, which is what lets the painter drop outline segments lying on it.
  final double south;
  final double west;
  final double north;
  final double east;

  /// The OSM `admin_level` fetched, copied from the layer so a set stays
  /// self-describing.
  final String adminLevel;
  final String? label;

  /// When the data was pulled from OSM. A failed import writes **nothing** —
  /// unlike transit there is no retry row, because re-running an import is two
  /// taps and a half-written set would have to remember the whole query.
  final DateTime fetchedAt;

  /// Denormalised for the Elements subtitle without a join.
  final int areaCount;
  final int pointCount;
  final DateTime createdAt;
  const BorderSet({
    required this.id,
    required this.layerId,
    required this.south,
    required this.west,
    required this.north,
    required this.east,
    required this.adminLevel,
    this.label,
    required this.fetchedAt,
    required this.areaCount,
    required this.pointCount,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['layer_id'] = Variable<String>(layerId);
    map['south'] = Variable<double>(south);
    map['west'] = Variable<double>(west);
    map['north'] = Variable<double>(north);
    map['east'] = Variable<double>(east);
    map['admin_level'] = Variable<String>(adminLevel);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    map['area_count'] = Variable<int>(areaCount);
    map['point_count'] = Variable<int>(pointCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BorderSetsCompanion toCompanion(bool nullToAbsent) {
    return BorderSetsCompanion(
      id: Value(id),
      layerId: Value(layerId),
      south: Value(south),
      west: Value(west),
      north: Value(north),
      east: Value(east),
      adminLevel: Value(adminLevel),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      fetchedAt: Value(fetchedAt),
      areaCount: Value(areaCount),
      pointCount: Value(pointCount),
      createdAt: Value(createdAt),
    );
  }

  factory BorderSet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BorderSet(
      id: serializer.fromJson<String>(json['id']),
      layerId: serializer.fromJson<String>(json['layerId']),
      south: serializer.fromJson<double>(json['south']),
      west: serializer.fromJson<double>(json['west']),
      north: serializer.fromJson<double>(json['north']),
      east: serializer.fromJson<double>(json['east']),
      adminLevel: serializer.fromJson<String>(json['adminLevel']),
      label: serializer.fromJson<String?>(json['label']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
      areaCount: serializer.fromJson<int>(json['areaCount']),
      pointCount: serializer.fromJson<int>(json['pointCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'layerId': serializer.toJson<String>(layerId),
      'south': serializer.toJson<double>(south),
      'west': serializer.toJson<double>(west),
      'north': serializer.toJson<double>(north),
      'east': serializer.toJson<double>(east),
      'adminLevel': serializer.toJson<String>(adminLevel),
      'label': serializer.toJson<String?>(label),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
      'areaCount': serializer.toJson<int>(areaCount),
      'pointCount': serializer.toJson<int>(pointCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  BorderSet copyWith({
    String? id,
    String? layerId,
    double? south,
    double? west,
    double? north,
    double? east,
    String? adminLevel,
    Value<String?> label = const Value.absent(),
    DateTime? fetchedAt,
    int? areaCount,
    int? pointCount,
    DateTime? createdAt,
  }) => BorderSet(
    id: id ?? this.id,
    layerId: layerId ?? this.layerId,
    south: south ?? this.south,
    west: west ?? this.west,
    north: north ?? this.north,
    east: east ?? this.east,
    adminLevel: adminLevel ?? this.adminLevel,
    label: label.present ? label.value : this.label,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    areaCount: areaCount ?? this.areaCount,
    pointCount: pointCount ?? this.pointCount,
    createdAt: createdAt ?? this.createdAt,
  );
  BorderSet copyWithCompanion(BorderSetsCompanion data) {
    return BorderSet(
      id: data.id.present ? data.id.value : this.id,
      layerId: data.layerId.present ? data.layerId.value : this.layerId,
      south: data.south.present ? data.south.value : this.south,
      west: data.west.present ? data.west.value : this.west,
      north: data.north.present ? data.north.value : this.north,
      east: data.east.present ? data.east.value : this.east,
      adminLevel: data.adminLevel.present
          ? data.adminLevel.value
          : this.adminLevel,
      label: data.label.present ? data.label.value : this.label,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
      areaCount: data.areaCount.present ? data.areaCount.value : this.areaCount,
      pointCount: data.pointCount.present
          ? data.pointCount.value
          : this.pointCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BorderSet(')
          ..write('id: $id, ')
          ..write('layerId: $layerId, ')
          ..write('south: $south, ')
          ..write('west: $west, ')
          ..write('north: $north, ')
          ..write('east: $east, ')
          ..write('adminLevel: $adminLevel, ')
          ..write('label: $label, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('areaCount: $areaCount, ')
          ..write('pointCount: $pointCount, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    layerId,
    south,
    west,
    north,
    east,
    adminLevel,
    label,
    fetchedAt,
    areaCount,
    pointCount,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BorderSet &&
          other.id == this.id &&
          other.layerId == this.layerId &&
          other.south == this.south &&
          other.west == this.west &&
          other.north == this.north &&
          other.east == this.east &&
          other.adminLevel == this.adminLevel &&
          other.label == this.label &&
          other.fetchedAt == this.fetchedAt &&
          other.areaCount == this.areaCount &&
          other.pointCount == this.pointCount &&
          other.createdAt == this.createdAt);
}

class BorderSetsCompanion extends UpdateCompanion<BorderSet> {
  final Value<String> id;
  final Value<String> layerId;
  final Value<double> south;
  final Value<double> west;
  final Value<double> north;
  final Value<double> east;
  final Value<String> adminLevel;
  final Value<String?> label;
  final Value<DateTime> fetchedAt;
  final Value<int> areaCount;
  final Value<int> pointCount;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const BorderSetsCompanion({
    this.id = const Value.absent(),
    this.layerId = const Value.absent(),
    this.south = const Value.absent(),
    this.west = const Value.absent(),
    this.north = const Value.absent(),
    this.east = const Value.absent(),
    this.adminLevel = const Value.absent(),
    this.label = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.areaCount = const Value.absent(),
    this.pointCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BorderSetsCompanion.insert({
    required String id,
    required String layerId,
    required double south,
    required double west,
    required double north,
    required double east,
    required String adminLevel,
    this.label = const Value.absent(),
    required DateTime fetchedAt,
    this.areaCount = const Value.absent(),
    this.pointCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       layerId = Value(layerId),
       south = Value(south),
       west = Value(west),
       north = Value(north),
       east = Value(east),
       adminLevel = Value(adminLevel),
       fetchedAt = Value(fetchedAt);
  static Insertable<BorderSet> custom({
    Expression<String>? id,
    Expression<String>? layerId,
    Expression<double>? south,
    Expression<double>? west,
    Expression<double>? north,
    Expression<double>? east,
    Expression<String>? adminLevel,
    Expression<String>? label,
    Expression<DateTime>? fetchedAt,
    Expression<int>? areaCount,
    Expression<int>? pointCount,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (layerId != null) 'layer_id': layerId,
      if (south != null) 'south': south,
      if (west != null) 'west': west,
      if (north != null) 'north': north,
      if (east != null) 'east': east,
      if (adminLevel != null) 'admin_level': adminLevel,
      if (label != null) 'label': label,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (areaCount != null) 'area_count': areaCount,
      if (pointCount != null) 'point_count': pointCount,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BorderSetsCompanion copyWith({
    Value<String>? id,
    Value<String>? layerId,
    Value<double>? south,
    Value<double>? west,
    Value<double>? north,
    Value<double>? east,
    Value<String>? adminLevel,
    Value<String?>? label,
    Value<DateTime>? fetchedAt,
    Value<int>? areaCount,
    Value<int>? pointCount,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return BorderSetsCompanion(
      id: id ?? this.id,
      layerId: layerId ?? this.layerId,
      south: south ?? this.south,
      west: west ?? this.west,
      north: north ?? this.north,
      east: east ?? this.east,
      adminLevel: adminLevel ?? this.adminLevel,
      label: label ?? this.label,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      areaCount: areaCount ?? this.areaCount,
      pointCount: pointCount ?? this.pointCount,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (layerId.present) {
      map['layer_id'] = Variable<String>(layerId.value);
    }
    if (south.present) {
      map['south'] = Variable<double>(south.value);
    }
    if (west.present) {
      map['west'] = Variable<double>(west.value);
    }
    if (north.present) {
      map['north'] = Variable<double>(north.value);
    }
    if (east.present) {
      map['east'] = Variable<double>(east.value);
    }
    if (adminLevel.present) {
      map['admin_level'] = Variable<String>(adminLevel.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (areaCount.present) {
      map['area_count'] = Variable<int>(areaCount.value);
    }
    if (pointCount.present) {
      map['point_count'] = Variable<int>(pointCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BorderSetsCompanion(')
          ..write('id: $id, ')
          ..write('layerId: $layerId, ')
          ..write('south: $south, ')
          ..write('west: $west, ')
          ..write('north: $north, ')
          ..write('east: $east, ')
          ..write('adminLevel: $adminLevel, ')
          ..write('label: $label, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('areaCount: $areaCount, ')
          ..write('pointCount: $pointCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BorderAreasTable extends BorderAreas
    with TableInfo<$BorderAreasTable, BorderArea> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BorderAreasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _setIdMeta = const VerificationMeta('setId');
  @override
  late final GeneratedColumn<String> setId = GeneratedColumn<String>(
    'set_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES border_sets (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _osmIdMeta = const VerificationMeta('osmId');
  @override
  late final GeneratedColumn<int> osmId = GeneratedColumn<int>(
    'osm_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorIndexMeta = const VerificationMeta(
    'colorIndex',
  );
  @override
  late final GeneratedColumn<int> colorIndex = GeneratedColumn<int>(
    'color_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _southMeta = const VerificationMeta('south');
  @override
  late final GeneratedColumn<double> south = GeneratedColumn<double>(
    'south',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _westMeta = const VerificationMeta('west');
  @override
  late final GeneratedColumn<double> west = GeneratedColumn<double>(
    'west',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _northMeta = const VerificationMeta('north');
  @override
  late final GeneratedColumn<double> north = GeneratedColumn<double>(
    'north',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eastMeta = const VerificationMeta('east');
  @override
  late final GeneratedColumn<double> east = GeneratedColumn<double>(
    'east',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelLatMeta = const VerificationMeta(
    'labelLat',
  );
  @override
  late final GeneratedColumn<double> labelLat = GeneratedColumn<double>(
    'label_lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelLngMeta = const VerificationMeta(
    'labelLng',
  );
  @override
  late final GeneratedColumn<double> labelLng = GeneratedColumn<double>(
    'label_lng',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pointCountMeta = const VerificationMeta(
    'pointCount',
  );
  @override
  late final GeneratedColumn<int> pointCount = GeneratedColumn<int>(
    'point_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ringsMeta = const VerificationMeta('rings');
  @override
  late final GeneratedColumn<String> rings = GeneratedColumn<String>(
    'rings',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wayIdsMeta = const VerificationMeta('wayIds');
  @override
  late final GeneratedColumn<String> wayIds = GeneratedColumn<String>(
    'way_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    setId,
    osmId,
    name,
    colorIndex,
    south,
    west,
    north,
    east,
    labelLat,
    labelLng,
    pointCount,
    rings,
    wayIds,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'border_areas';
  @override
  VerificationContext validateIntegrity(
    Insertable<BorderArea> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('set_id')) {
      context.handle(
        _setIdMeta,
        setId.isAcceptableOrUnknown(data['set_id']!, _setIdMeta),
      );
    } else if (isInserting) {
      context.missing(_setIdMeta);
    }
    if (data.containsKey('osm_id')) {
      context.handle(
        _osmIdMeta,
        osmId.isAcceptableOrUnknown(data['osm_id']!, _osmIdMeta),
      );
    } else if (isInserting) {
      context.missing(_osmIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('color_index')) {
      context.handle(
        _colorIndexMeta,
        colorIndex.isAcceptableOrUnknown(data['color_index']!, _colorIndexMeta),
      );
    }
    if (data.containsKey('south')) {
      context.handle(
        _southMeta,
        south.isAcceptableOrUnknown(data['south']!, _southMeta),
      );
    } else if (isInserting) {
      context.missing(_southMeta);
    }
    if (data.containsKey('west')) {
      context.handle(
        _westMeta,
        west.isAcceptableOrUnknown(data['west']!, _westMeta),
      );
    } else if (isInserting) {
      context.missing(_westMeta);
    }
    if (data.containsKey('north')) {
      context.handle(
        _northMeta,
        north.isAcceptableOrUnknown(data['north']!, _northMeta),
      );
    } else if (isInserting) {
      context.missing(_northMeta);
    }
    if (data.containsKey('east')) {
      context.handle(
        _eastMeta,
        east.isAcceptableOrUnknown(data['east']!, _eastMeta),
      );
    } else if (isInserting) {
      context.missing(_eastMeta);
    }
    if (data.containsKey('label_lat')) {
      context.handle(
        _labelLatMeta,
        labelLat.isAcceptableOrUnknown(data['label_lat']!, _labelLatMeta),
      );
    } else if (isInserting) {
      context.missing(_labelLatMeta);
    }
    if (data.containsKey('label_lng')) {
      context.handle(
        _labelLngMeta,
        labelLng.isAcceptableOrUnknown(data['label_lng']!, _labelLngMeta),
      );
    } else if (isInserting) {
      context.missing(_labelLngMeta);
    }
    if (data.containsKey('point_count')) {
      context.handle(
        _pointCountMeta,
        pointCount.isAcceptableOrUnknown(data['point_count']!, _pointCountMeta),
      );
    } else if (isInserting) {
      context.missing(_pointCountMeta);
    }
    if (data.containsKey('rings')) {
      context.handle(
        _ringsMeta,
        rings.isAcceptableOrUnknown(data['rings']!, _ringsMeta),
      );
    } else if (isInserting) {
      context.missing(_ringsMeta);
    }
    if (data.containsKey('way_ids')) {
      context.handle(
        _wayIdsMeta,
        wayIds.isAcceptableOrUnknown(data['way_ids']!, _wayIdsMeta),
      );
    } else if (isInserting) {
      context.missing(_wayIdsMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BorderArea map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BorderArea(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      setId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}set_id'],
      )!,
      osmId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}osm_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      colorIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_index'],
      )!,
      south: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}south'],
      )!,
      west: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}west'],
      )!,
      north: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}north'],
      )!,
      east: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}east'],
      )!,
      labelLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}label_lat'],
      )!,
      labelLng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}label_lng'],
      )!,
      pointCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}point_count'],
      )!,
      rings: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rings'],
      )!,
      wayIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}way_ids'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BorderAreasTable createAlias(String alias) {
    return $BorderAreasTable(attachedDatabase, alias);
  }
}

class BorderArea extends DataClass implements Insertable<BorderArea> {
  final String id;
  final String setId;

  /// The OSM relation id, so the area can be looked up on osm.org — and the key
  /// adjacency is computed against.
  final int osmId;
  final String? name;

  /// Index into the painter's palette, assigned so no two areas sharing a
  /// border get the same one. Stored rather than derived, so the palette can be
  /// retuned without re-importing.
  final int colorIndex;

  /// The area's own bounding box, for viewport culling without decoding
  /// [rings].
  final double south;
  final double west;
  final double north;
  final double east;

  /// Precomputed anchor for the name plate.
  final double labelLat;
  final double labelLng;
  final int pointCount;

  /// `encodeRings` output: `[[[lat,lng], …], …]`, outer ring first, holes
  /// after. **Holes carry no role flag** — the painter fills with
  /// [PathFillType.evenOdd], exactly as the height layer does.
  final String rings;

  /// JSON array of the relation's member way ids, kept only for adjacency:
  /// two areas share a border iff they share a way id, which is exact and free.
  final String wayIds;
  final DateTime createdAt;
  const BorderArea({
    required this.id,
    required this.setId,
    required this.osmId,
    this.name,
    required this.colorIndex,
    required this.south,
    required this.west,
    required this.north,
    required this.east,
    required this.labelLat,
    required this.labelLng,
    required this.pointCount,
    required this.rings,
    required this.wayIds,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['set_id'] = Variable<String>(setId);
    map['osm_id'] = Variable<int>(osmId);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    map['color_index'] = Variable<int>(colorIndex);
    map['south'] = Variable<double>(south);
    map['west'] = Variable<double>(west);
    map['north'] = Variable<double>(north);
    map['east'] = Variable<double>(east);
    map['label_lat'] = Variable<double>(labelLat);
    map['label_lng'] = Variable<double>(labelLng);
    map['point_count'] = Variable<int>(pointCount);
    map['rings'] = Variable<String>(rings);
    map['way_ids'] = Variable<String>(wayIds);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BorderAreasCompanion toCompanion(bool nullToAbsent) {
    return BorderAreasCompanion(
      id: Value(id),
      setId: Value(setId),
      osmId: Value(osmId),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      colorIndex: Value(colorIndex),
      south: Value(south),
      west: Value(west),
      north: Value(north),
      east: Value(east),
      labelLat: Value(labelLat),
      labelLng: Value(labelLng),
      pointCount: Value(pointCount),
      rings: Value(rings),
      wayIds: Value(wayIds),
      createdAt: Value(createdAt),
    );
  }

  factory BorderArea.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BorderArea(
      id: serializer.fromJson<String>(json['id']),
      setId: serializer.fromJson<String>(json['setId']),
      osmId: serializer.fromJson<int>(json['osmId']),
      name: serializer.fromJson<String?>(json['name']),
      colorIndex: serializer.fromJson<int>(json['colorIndex']),
      south: serializer.fromJson<double>(json['south']),
      west: serializer.fromJson<double>(json['west']),
      north: serializer.fromJson<double>(json['north']),
      east: serializer.fromJson<double>(json['east']),
      labelLat: serializer.fromJson<double>(json['labelLat']),
      labelLng: serializer.fromJson<double>(json['labelLng']),
      pointCount: serializer.fromJson<int>(json['pointCount']),
      rings: serializer.fromJson<String>(json['rings']),
      wayIds: serializer.fromJson<String>(json['wayIds']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'setId': serializer.toJson<String>(setId),
      'osmId': serializer.toJson<int>(osmId),
      'name': serializer.toJson<String?>(name),
      'colorIndex': serializer.toJson<int>(colorIndex),
      'south': serializer.toJson<double>(south),
      'west': serializer.toJson<double>(west),
      'north': serializer.toJson<double>(north),
      'east': serializer.toJson<double>(east),
      'labelLat': serializer.toJson<double>(labelLat),
      'labelLng': serializer.toJson<double>(labelLng),
      'pointCount': serializer.toJson<int>(pointCount),
      'rings': serializer.toJson<String>(rings),
      'wayIds': serializer.toJson<String>(wayIds),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  BorderArea copyWith({
    String? id,
    String? setId,
    int? osmId,
    Value<String?> name = const Value.absent(),
    int? colorIndex,
    double? south,
    double? west,
    double? north,
    double? east,
    double? labelLat,
    double? labelLng,
    int? pointCount,
    String? rings,
    String? wayIds,
    DateTime? createdAt,
  }) => BorderArea(
    id: id ?? this.id,
    setId: setId ?? this.setId,
    osmId: osmId ?? this.osmId,
    name: name.present ? name.value : this.name,
    colorIndex: colorIndex ?? this.colorIndex,
    south: south ?? this.south,
    west: west ?? this.west,
    north: north ?? this.north,
    east: east ?? this.east,
    labelLat: labelLat ?? this.labelLat,
    labelLng: labelLng ?? this.labelLng,
    pointCount: pointCount ?? this.pointCount,
    rings: rings ?? this.rings,
    wayIds: wayIds ?? this.wayIds,
    createdAt: createdAt ?? this.createdAt,
  );
  BorderArea copyWithCompanion(BorderAreasCompanion data) {
    return BorderArea(
      id: data.id.present ? data.id.value : this.id,
      setId: data.setId.present ? data.setId.value : this.setId,
      osmId: data.osmId.present ? data.osmId.value : this.osmId,
      name: data.name.present ? data.name.value : this.name,
      colorIndex: data.colorIndex.present
          ? data.colorIndex.value
          : this.colorIndex,
      south: data.south.present ? data.south.value : this.south,
      west: data.west.present ? data.west.value : this.west,
      north: data.north.present ? data.north.value : this.north,
      east: data.east.present ? data.east.value : this.east,
      labelLat: data.labelLat.present ? data.labelLat.value : this.labelLat,
      labelLng: data.labelLng.present ? data.labelLng.value : this.labelLng,
      pointCount: data.pointCount.present
          ? data.pointCount.value
          : this.pointCount,
      rings: data.rings.present ? data.rings.value : this.rings,
      wayIds: data.wayIds.present ? data.wayIds.value : this.wayIds,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BorderArea(')
          ..write('id: $id, ')
          ..write('setId: $setId, ')
          ..write('osmId: $osmId, ')
          ..write('name: $name, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('south: $south, ')
          ..write('west: $west, ')
          ..write('north: $north, ')
          ..write('east: $east, ')
          ..write('labelLat: $labelLat, ')
          ..write('labelLng: $labelLng, ')
          ..write('pointCount: $pointCount, ')
          ..write('rings: $rings, ')
          ..write('wayIds: $wayIds, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    setId,
    osmId,
    name,
    colorIndex,
    south,
    west,
    north,
    east,
    labelLat,
    labelLng,
    pointCount,
    rings,
    wayIds,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BorderArea &&
          other.id == this.id &&
          other.setId == this.setId &&
          other.osmId == this.osmId &&
          other.name == this.name &&
          other.colorIndex == this.colorIndex &&
          other.south == this.south &&
          other.west == this.west &&
          other.north == this.north &&
          other.east == this.east &&
          other.labelLat == this.labelLat &&
          other.labelLng == this.labelLng &&
          other.pointCount == this.pointCount &&
          other.rings == this.rings &&
          other.wayIds == this.wayIds &&
          other.createdAt == this.createdAt);
}

class BorderAreasCompanion extends UpdateCompanion<BorderArea> {
  final Value<String> id;
  final Value<String> setId;
  final Value<int> osmId;
  final Value<String?> name;
  final Value<int> colorIndex;
  final Value<double> south;
  final Value<double> west;
  final Value<double> north;
  final Value<double> east;
  final Value<double> labelLat;
  final Value<double> labelLng;
  final Value<int> pointCount;
  final Value<String> rings;
  final Value<String> wayIds;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const BorderAreasCompanion({
    this.id = const Value.absent(),
    this.setId = const Value.absent(),
    this.osmId = const Value.absent(),
    this.name = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.south = const Value.absent(),
    this.west = const Value.absent(),
    this.north = const Value.absent(),
    this.east = const Value.absent(),
    this.labelLat = const Value.absent(),
    this.labelLng = const Value.absent(),
    this.pointCount = const Value.absent(),
    this.rings = const Value.absent(),
    this.wayIds = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BorderAreasCompanion.insert({
    required String id,
    required String setId,
    required int osmId,
    this.name = const Value.absent(),
    this.colorIndex = const Value.absent(),
    required double south,
    required double west,
    required double north,
    required double east,
    required double labelLat,
    required double labelLng,
    required int pointCount,
    required String rings,
    required String wayIds,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       setId = Value(setId),
       osmId = Value(osmId),
       south = Value(south),
       west = Value(west),
       north = Value(north),
       east = Value(east),
       labelLat = Value(labelLat),
       labelLng = Value(labelLng),
       pointCount = Value(pointCount),
       rings = Value(rings),
       wayIds = Value(wayIds);
  static Insertable<BorderArea> custom({
    Expression<String>? id,
    Expression<String>? setId,
    Expression<int>? osmId,
    Expression<String>? name,
    Expression<int>? colorIndex,
    Expression<double>? south,
    Expression<double>? west,
    Expression<double>? north,
    Expression<double>? east,
    Expression<double>? labelLat,
    Expression<double>? labelLng,
    Expression<int>? pointCount,
    Expression<String>? rings,
    Expression<String>? wayIds,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (setId != null) 'set_id': setId,
      if (osmId != null) 'osm_id': osmId,
      if (name != null) 'name': name,
      if (colorIndex != null) 'color_index': colorIndex,
      if (south != null) 'south': south,
      if (west != null) 'west': west,
      if (north != null) 'north': north,
      if (east != null) 'east': east,
      if (labelLat != null) 'label_lat': labelLat,
      if (labelLng != null) 'label_lng': labelLng,
      if (pointCount != null) 'point_count': pointCount,
      if (rings != null) 'rings': rings,
      if (wayIds != null) 'way_ids': wayIds,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BorderAreasCompanion copyWith({
    Value<String>? id,
    Value<String>? setId,
    Value<int>? osmId,
    Value<String?>? name,
    Value<int>? colorIndex,
    Value<double>? south,
    Value<double>? west,
    Value<double>? north,
    Value<double>? east,
    Value<double>? labelLat,
    Value<double>? labelLng,
    Value<int>? pointCount,
    Value<String>? rings,
    Value<String>? wayIds,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return BorderAreasCompanion(
      id: id ?? this.id,
      setId: setId ?? this.setId,
      osmId: osmId ?? this.osmId,
      name: name ?? this.name,
      colorIndex: colorIndex ?? this.colorIndex,
      south: south ?? this.south,
      west: west ?? this.west,
      north: north ?? this.north,
      east: east ?? this.east,
      labelLat: labelLat ?? this.labelLat,
      labelLng: labelLng ?? this.labelLng,
      pointCount: pointCount ?? this.pointCount,
      rings: rings ?? this.rings,
      wayIds: wayIds ?? this.wayIds,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (setId.present) {
      map['set_id'] = Variable<String>(setId.value);
    }
    if (osmId.present) {
      map['osm_id'] = Variable<int>(osmId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorIndex.present) {
      map['color_index'] = Variable<int>(colorIndex.value);
    }
    if (south.present) {
      map['south'] = Variable<double>(south.value);
    }
    if (west.present) {
      map['west'] = Variable<double>(west.value);
    }
    if (north.present) {
      map['north'] = Variable<double>(north.value);
    }
    if (east.present) {
      map['east'] = Variable<double>(east.value);
    }
    if (labelLat.present) {
      map['label_lat'] = Variable<double>(labelLat.value);
    }
    if (labelLng.present) {
      map['label_lng'] = Variable<double>(labelLng.value);
    }
    if (pointCount.present) {
      map['point_count'] = Variable<int>(pointCount.value);
    }
    if (rings.present) {
      map['rings'] = Variable<String>(rings.value);
    }
    if (wayIds.present) {
      map['way_ids'] = Variable<String>(wayIds.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BorderAreasCompanion(')
          ..write('id: $id, ')
          ..write('setId: $setId, ')
          ..write('osmId: $osmId, ')
          ..write('name: $name, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('south: $south, ')
          ..write('west: $west, ')
          ..write('north: $north, ')
          ..write('east: $east, ')
          ..write('labelLat: $labelLat, ')
          ..write('labelLng: $labelLng, ')
          ..write('pointCount: $pointCount, ')
          ..write('rings: $rings, ')
          ..write('wayIds: $wayIds, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TileCacheTable extends TileCache
    with TableInfo<$TileCacheTable, TileCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TileCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<Uint8List> bytes = GeneratedColumn<Uint8List>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<int> fetchedAt = GeneratedColumn<int>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastUsedAtMeta = const VerificationMeta(
    'lastUsedAt',
  );
  @override
  late final GeneratedColumn<int> lastUsedAt = GeneratedColumn<int>(
    'last_used_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    url,
    bytes,
    etag,
    sizeBytes,
    fetchedAt,
    lastUsedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tile_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<TileCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    if (data.containsKey('last_used_at')) {
      context.handle(
        _lastUsedAtMeta,
        lastUsedAt.isAcceptableOrUnknown(
          data['last_used_at']!,
          _lastUsedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastUsedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {url};
  @override
  TileCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TileCacheData(
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}bytes'],
      )!,
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      ),
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fetched_at'],
      )!,
      lastUsedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_used_at'],
      )!,
    );
  }

  @override
  $TileCacheTable createAlias(String alias) {
    return $TileCacheTable(attachedDatabase, alias);
  }
}

class TileCacheData extends DataClass implements Insertable<TileCacheData> {
  /// Full resolved tile URL (`{z}/{x}/{y}` already substituted).
  final String url;

  /// Raw image bytes (PNG) as returned by the tile server.
  final Uint8List bytes;

  /// HTTP ETag if the server sent one (currently stored, not yet revalidated).
  final String? etag;

  /// Byte length of [bytes], denormalised so the size cap can sum cheaply.
  final int sizeBytes;

  /// When the tile was fetched (ms since epoch).
  final int fetchedAt;

  /// When the tile was last served from cache (ms since epoch). Drives LRU
  /// eviction.
  final int lastUsedAt;
  const TileCacheData({
    required this.url,
    required this.bytes,
    this.etag,
    required this.sizeBytes,
    required this.fetchedAt,
    required this.lastUsedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['url'] = Variable<String>(url);
    map['bytes'] = Variable<Uint8List>(bytes);
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['fetched_at'] = Variable<int>(fetchedAt);
    map['last_used_at'] = Variable<int>(lastUsedAt);
    return map;
  }

  TileCacheCompanion toCompanion(bool nullToAbsent) {
    return TileCacheCompanion(
      url: Value(url),
      bytes: Value(bytes),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      sizeBytes: Value(sizeBytes),
      fetchedAt: Value(fetchedAt),
      lastUsedAt: Value(lastUsedAt),
    );
  }

  factory TileCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TileCacheData(
      url: serializer.fromJson<String>(json['url']),
      bytes: serializer.fromJson<Uint8List>(json['bytes']),
      etag: serializer.fromJson<String?>(json['etag']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      fetchedAt: serializer.fromJson<int>(json['fetchedAt']),
      lastUsedAt: serializer.fromJson<int>(json['lastUsedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'url': serializer.toJson<String>(url),
      'bytes': serializer.toJson<Uint8List>(bytes),
      'etag': serializer.toJson<String?>(etag),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'fetchedAt': serializer.toJson<int>(fetchedAt),
      'lastUsedAt': serializer.toJson<int>(lastUsedAt),
    };
  }

  TileCacheData copyWith({
    String? url,
    Uint8List? bytes,
    Value<String?> etag = const Value.absent(),
    int? sizeBytes,
    int? fetchedAt,
    int? lastUsedAt,
  }) => TileCacheData(
    url: url ?? this.url,
    bytes: bytes ?? this.bytes,
    etag: etag.present ? etag.value : this.etag,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    lastUsedAt: lastUsedAt ?? this.lastUsedAt,
  );
  TileCacheData copyWithCompanion(TileCacheCompanion data) {
    return TileCacheData(
      url: data.url.present ? data.url.value : this.url,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      etag: data.etag.present ? data.etag.value : this.etag,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
      lastUsedAt: data.lastUsedAt.present
          ? data.lastUsedAt.value
          : this.lastUsedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TileCacheData(')
          ..write('url: $url, ')
          ..write('bytes: $bytes, ')
          ..write('etag: $etag, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('lastUsedAt: $lastUsedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    url,
    $driftBlobEquality.hash(bytes),
    etag,
    sizeBytes,
    fetchedAt,
    lastUsedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TileCacheData &&
          other.url == this.url &&
          $driftBlobEquality.equals(other.bytes, this.bytes) &&
          other.etag == this.etag &&
          other.sizeBytes == this.sizeBytes &&
          other.fetchedAt == this.fetchedAt &&
          other.lastUsedAt == this.lastUsedAt);
}

class TileCacheCompanion extends UpdateCompanion<TileCacheData> {
  final Value<String> url;
  final Value<Uint8List> bytes;
  final Value<String?> etag;
  final Value<int> sizeBytes;
  final Value<int> fetchedAt;
  final Value<int> lastUsedAt;
  final Value<int> rowid;
  const TileCacheCompanion({
    this.url = const Value.absent(),
    this.bytes = const Value.absent(),
    this.etag = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TileCacheCompanion.insert({
    required String url,
    required Uint8List bytes,
    this.etag = const Value.absent(),
    required int sizeBytes,
    required int fetchedAt,
    required int lastUsedAt,
    this.rowid = const Value.absent(),
  }) : url = Value(url),
       bytes = Value(bytes),
       sizeBytes = Value(sizeBytes),
       fetchedAt = Value(fetchedAt),
       lastUsedAt = Value(lastUsedAt);
  static Insertable<TileCacheData> custom({
    Expression<String>? url,
    Expression<Uint8List>? bytes,
    Expression<String>? etag,
    Expression<int>? sizeBytes,
    Expression<int>? fetchedAt,
    Expression<int>? lastUsedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (url != null) 'url': url,
      if (bytes != null) 'bytes': bytes,
      if (etag != null) 'etag': etag,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TileCacheCompanion copyWith({
    Value<String>? url,
    Value<Uint8List>? bytes,
    Value<String?>? etag,
    Value<int>? sizeBytes,
    Value<int>? fetchedAt,
    Value<int>? lastUsedAt,
    Value<int>? rowid,
  }) {
    return TileCacheCompanion(
      url: url ?? this.url,
      bytes: bytes ?? this.bytes,
      etag: etag ?? this.etag,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<Uint8List>(bytes.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<int>(fetchedAt.value);
    }
    if (lastUsedAt.present) {
      map['last_used_at'] = Variable<int>(lastUsedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TileCacheCompanion(')
          ..write('url: $url, ')
          ..write('bytes: $bytes, ')
          ..write('etag: $etag, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OverpassCacheTable extends OverpassCache
    with TableInfo<$OverpassCacheTable, OverpassCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OverpassCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _southMeta = const VerificationMeta('south');
  @override
  late final GeneratedColumn<double> south = GeneratedColumn<double>(
    'south',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _westMeta = const VerificationMeta('west');
  @override
  late final GeneratedColumn<double> west = GeneratedColumn<double>(
    'west',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _northMeta = const VerificationMeta('north');
  @override
  late final GeneratedColumn<double> north = GeneratedColumn<double>(
    'north',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eastMeta = const VerificationMeta('east');
  @override
  late final GeneratedColumn<double> east = GeneratedColumn<double>(
    'east',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _maskBitsMeta = const VerificationMeta(
    'maskBits',
  );
  @override
  late final GeneratedColumn<int> maskBits = GeneratedColumn<int>(
    'mask_bits',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<int> fetchedAt = GeneratedColumn<int>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    kind,
    payload,
    south,
    west,
    north,
    east,
    maskBits,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'overpass_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<OverpassCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('south')) {
      context.handle(
        _southMeta,
        south.isAcceptableOrUnknown(data['south']!, _southMeta),
      );
    } else if (isInserting) {
      context.missing(_southMeta);
    }
    if (data.containsKey('west')) {
      context.handle(
        _westMeta,
        west.isAcceptableOrUnknown(data['west']!, _westMeta),
      );
    } else if (isInserting) {
      context.missing(_westMeta);
    }
    if (data.containsKey('north')) {
      context.handle(
        _northMeta,
        north.isAcceptableOrUnknown(data['north']!, _northMeta),
      );
    } else if (isInserting) {
      context.missing(_northMeta);
    }
    if (data.containsKey('east')) {
      context.handle(
        _eastMeta,
        east.isAcceptableOrUnknown(data['east']!, _eastMeta),
      );
    } else if (isInserting) {
      context.missing(_eastMeta);
    }
    if (data.containsKey('mask_bits')) {
      context.handle(
        _maskBitsMeta,
        maskBits.isAcceptableOrUnknown(data['mask_bits']!, _maskBitsMeta),
      );
    } else if (isInserting) {
      context.missing(_maskBitsMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {kind};
  @override
  OverpassCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OverpassCacheData(
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      south: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}south'],
      )!,
      west: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}west'],
      )!,
      north: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}north'],
      )!,
      east: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}east'],
      )!,
      maskBits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mask_bits'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $OverpassCacheTable createAlias(String alias) {
    return $OverpassCacheTable(attachedDatabase, alias);
  }
}

class OverpassCacheData extends DataClass
    implements Insertable<OverpassCacheData> {
  /// 'poi' or 'border'.
  final String kind;

  /// JSON-encoded list of results (see toJson helpers in overpass/borders.dart).
  final String payload;
  final double south;
  final double west;
  final double north;
  final double east;

  /// The category/level bitmask (POI categories or active border-level bits)
  /// the payload was fetched with.
  final int maskBits;

  /// When the payload was fetched (ms since epoch).
  final int fetchedAt;
  const OverpassCacheData({
    required this.kind,
    required this.payload,
    required this.south,
    required this.west,
    required this.north,
    required this.east,
    required this.maskBits,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['kind'] = Variable<String>(kind);
    map['payload'] = Variable<String>(payload);
    map['south'] = Variable<double>(south);
    map['west'] = Variable<double>(west);
    map['north'] = Variable<double>(north);
    map['east'] = Variable<double>(east);
    map['mask_bits'] = Variable<int>(maskBits);
    map['fetched_at'] = Variable<int>(fetchedAt);
    return map;
  }

  OverpassCacheCompanion toCompanion(bool nullToAbsent) {
    return OverpassCacheCompanion(
      kind: Value(kind),
      payload: Value(payload),
      south: Value(south),
      west: Value(west),
      north: Value(north),
      east: Value(east),
      maskBits: Value(maskBits),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory OverpassCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OverpassCacheData(
      kind: serializer.fromJson<String>(json['kind']),
      payload: serializer.fromJson<String>(json['payload']),
      south: serializer.fromJson<double>(json['south']),
      west: serializer.fromJson<double>(json['west']),
      north: serializer.fromJson<double>(json['north']),
      east: serializer.fromJson<double>(json['east']),
      maskBits: serializer.fromJson<int>(json['maskBits']),
      fetchedAt: serializer.fromJson<int>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'kind': serializer.toJson<String>(kind),
      'payload': serializer.toJson<String>(payload),
      'south': serializer.toJson<double>(south),
      'west': serializer.toJson<double>(west),
      'north': serializer.toJson<double>(north),
      'east': serializer.toJson<double>(east),
      'maskBits': serializer.toJson<int>(maskBits),
      'fetchedAt': serializer.toJson<int>(fetchedAt),
    };
  }

  OverpassCacheData copyWith({
    String? kind,
    String? payload,
    double? south,
    double? west,
    double? north,
    double? east,
    int? maskBits,
    int? fetchedAt,
  }) => OverpassCacheData(
    kind: kind ?? this.kind,
    payload: payload ?? this.payload,
    south: south ?? this.south,
    west: west ?? this.west,
    north: north ?? this.north,
    east: east ?? this.east,
    maskBits: maskBits ?? this.maskBits,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  OverpassCacheData copyWithCompanion(OverpassCacheCompanion data) {
    return OverpassCacheData(
      kind: data.kind.present ? data.kind.value : this.kind,
      payload: data.payload.present ? data.payload.value : this.payload,
      south: data.south.present ? data.south.value : this.south,
      west: data.west.present ? data.west.value : this.west,
      north: data.north.present ? data.north.value : this.north,
      east: data.east.present ? data.east.value : this.east,
      maskBits: data.maskBits.present ? data.maskBits.value : this.maskBits,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OverpassCacheData(')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write('south: $south, ')
          ..write('west: $west, ')
          ..write('north: $north, ')
          ..write('east: $east, ')
          ..write('maskBits: $maskBits, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(kind, payload, south, west, north, east, maskBits, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OverpassCacheData &&
          other.kind == this.kind &&
          other.payload == this.payload &&
          other.south == this.south &&
          other.west == this.west &&
          other.north == this.north &&
          other.east == this.east &&
          other.maskBits == this.maskBits &&
          other.fetchedAt == this.fetchedAt);
}

class OverpassCacheCompanion extends UpdateCompanion<OverpassCacheData> {
  final Value<String> kind;
  final Value<String> payload;
  final Value<double> south;
  final Value<double> west;
  final Value<double> north;
  final Value<double> east;
  final Value<int> maskBits;
  final Value<int> fetchedAt;
  final Value<int> rowid;
  const OverpassCacheCompanion({
    this.kind = const Value.absent(),
    this.payload = const Value.absent(),
    this.south = const Value.absent(),
    this.west = const Value.absent(),
    this.north = const Value.absent(),
    this.east = const Value.absent(),
    this.maskBits = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OverpassCacheCompanion.insert({
    required String kind,
    required String payload,
    required double south,
    required double west,
    required double north,
    required double east,
    required int maskBits,
    required int fetchedAt,
    this.rowid = const Value.absent(),
  }) : kind = Value(kind),
       payload = Value(payload),
       south = Value(south),
       west = Value(west),
       north = Value(north),
       east = Value(east),
       maskBits = Value(maskBits),
       fetchedAt = Value(fetchedAt);
  static Insertable<OverpassCacheData> custom({
    Expression<String>? kind,
    Expression<String>? payload,
    Expression<double>? south,
    Expression<double>? west,
    Expression<double>? north,
    Expression<double>? east,
    Expression<int>? maskBits,
    Expression<int>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (kind != null) 'kind': kind,
      if (payload != null) 'payload': payload,
      if (south != null) 'south': south,
      if (west != null) 'west': west,
      if (north != null) 'north': north,
      if (east != null) 'east': east,
      if (maskBits != null) 'mask_bits': maskBits,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OverpassCacheCompanion copyWith({
    Value<String>? kind,
    Value<String>? payload,
    Value<double>? south,
    Value<double>? west,
    Value<double>? north,
    Value<double>? east,
    Value<int>? maskBits,
    Value<int>? fetchedAt,
    Value<int>? rowid,
  }) {
    return OverpassCacheCompanion(
      kind: kind ?? this.kind,
      payload: payload ?? this.payload,
      south: south ?? this.south,
      west: west ?? this.west,
      north: north ?? this.north,
      east: east ?? this.east,
      maskBits: maskBits ?? this.maskBits,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (south.present) {
      map['south'] = Variable<double>(south.value);
    }
    if (west.present) {
      map['west'] = Variable<double>(west.value);
    }
    if (north.present) {
      map['north'] = Variable<double>(north.value);
    }
    if (east.present) {
      map['east'] = Variable<double>(east.value);
    }
    if (maskBits.present) {
      map['mask_bits'] = Variable<int>(maskBits.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<int>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OverpassCacheCompanion(')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write('south: $south, ')
          ..write('west: $west, ')
          ..write('north: $north, ')
          ..write('east: $east, ')
          ..write('maskBits: $maskBits, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LayersTable layers = $LayersTable(this);
  late final $CirclesTable circles = $CirclesTable(this);
  late final $PlanesTable planes = $PlanesTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $SubspacesTable subspaces = $SubspacesTable(this);
  late final $SubspacePointsTable subspacePoints = $SubspacePointsTable(this);
  late final $FreeLinesTable freeLines = $FreeLinesTable(this);
  late final $FreeLinePointsTable freeLinePoints = $FreeLinePointsTable(this);
  late final $FreeAreasTable freeAreas = $FreeAreasTable(this);
  late final $FreeAreaPointsTable freeAreaPoints = $FreeAreaPointsTable(this);
  late final $HeightRegionsTable heightRegions = $HeightRegionsTable(this);
  late final $HeightPolygonsTable heightPolygons = $HeightPolygonsTable(this);
  late final $HeightPolygonPointsTable heightPolygonPoints =
      $HeightPolygonPointsTable(this);
  late final $PoiSetsTable poiSets = $PoiSetsTable(this);
  late final $PoiPointsTable poiPoints = $PoiPointsTable(this);
  late final $TransitSetsTable transitSets = $TransitSetsTable(this);
  late final $TransitStopsTable transitStops = $TransitStopsTable(this);
  late final $BorderSetsTable borderSets = $BorderSetsTable(this);
  late final $BorderAreasTable borderAreas = $BorderAreasTable(this);
  late final $TileCacheTable tileCache = $TileCacheTable(this);
  late final $OverpassCacheTable overpassCache = $OverpassCacheTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    layers,
    circles,
    planes,
    appSettings,
    subspaces,
    subspacePoints,
    freeLines,
    freeLinePoints,
    freeAreas,
    freeAreaPoints,
    heightRegions,
    heightPolygons,
    heightPolygonPoints,
    poiSets,
    poiPoints,
    transitSets,
    transitStops,
    borderSets,
    borderAreas,
    tileCache,
    overpassCache,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'layers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('circles', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'layers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('planes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'layers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('subspaces', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'subspaces',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('subspace_points', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'layers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('free_lines', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'free_lines',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('free_line_points', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'layers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('free_areas', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'free_areas',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('free_area_points', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'layers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('height_regions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'height_regions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('height_polygons', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'height_polygons',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('height_polygon_points', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'layers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('poi_sets', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'poi_sets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('poi_points', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'layers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('transit_sets', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'transit_sets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('transit_stops', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'layers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('border_sets', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'border_sets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('border_areas', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$LayersTableCreateCompanionBuilder =
    LayersCompanion Function({
      required String id,
      required String name,
      required int colorArgb,
      Value<bool> isVisible,
      required int sortOrder,
      Value<String> type,
      Value<bool> isInverted,
      Value<double> opacity,
      Value<String?> borderLevel,
      Value<bool> borderFillAreas,
      Value<bool> borderShowNames,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$LayersTableUpdateCompanionBuilder =
    LayersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> colorArgb,
      Value<bool> isVisible,
      Value<int> sortOrder,
      Value<String> type,
      Value<bool> isInverted,
      Value<double> opacity,
      Value<String?> borderLevel,
      Value<bool> borderFillAreas,
      Value<bool> borderShowNames,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$LayersTableReferences
    extends BaseReferences<_$AppDatabase, $LayersTable, Layer> {
  $$LayersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CirclesTable, List<Circle>> _circlesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.circles,
    aliasName: $_aliasNameGenerator(db.layers.id, db.circles.layerId),
  );

  $$CirclesTableProcessedTableManager get circlesRefs {
    final manager = $$CirclesTableTableManager(
      $_db,
      $_db.circles,
    ).filter((f) => f.layerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_circlesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PlanesTable, List<Plane>> _planesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.planes,
    aliasName: $_aliasNameGenerator(db.layers.id, db.planes.layerId),
  );

  $$PlanesTableProcessedTableManager get planesRefs {
    final manager = $$PlanesTableTableManager(
      $_db,
      $_db.planes,
    ).filter((f) => f.layerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_planesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SubspacesTable, List<Subspace>>
  _subspacesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.subspaces,
    aliasName: $_aliasNameGenerator(db.layers.id, db.subspaces.layerId),
  );

  $$SubspacesTableProcessedTableManager get subspacesRefs {
    final manager = $$SubspacesTableTableManager(
      $_db,
      $_db.subspaces,
    ).filter((f) => f.layerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_subspacesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FreeLinesTable, List<FreeLine>>
  _freeLinesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.freeLines,
    aliasName: $_aliasNameGenerator(db.layers.id, db.freeLines.layerId),
  );

  $$FreeLinesTableProcessedTableManager get freeLinesRefs {
    final manager = $$FreeLinesTableTableManager(
      $_db,
      $_db.freeLines,
    ).filter((f) => f.layerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_freeLinesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FreeAreasTable, List<FreeArea>>
  _freeAreasRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.freeAreas,
    aliasName: $_aliasNameGenerator(db.layers.id, db.freeAreas.layerId),
  );

  $$FreeAreasTableProcessedTableManager get freeAreasRefs {
    final manager = $$FreeAreasTableTableManager(
      $_db,
      $_db.freeAreas,
    ).filter((f) => f.layerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_freeAreasRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$HeightRegionsTable, List<HeightRegion>>
  _heightRegionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.heightRegions,
    aliasName: $_aliasNameGenerator(db.layers.id, db.heightRegions.layerId),
  );

  $$HeightRegionsTableProcessedTableManager get heightRegionsRefs {
    final manager = $$HeightRegionsTableTableManager(
      $_db,
      $_db.heightRegions,
    ).filter((f) => f.layerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_heightRegionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PoiSetsTable, List<PoiSet>> _poiSetsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.poiSets,
    aliasName: $_aliasNameGenerator(db.layers.id, db.poiSets.layerId),
  );

  $$PoiSetsTableProcessedTableManager get poiSetsRefs {
    final manager = $$PoiSetsTableTableManager(
      $_db,
      $_db.poiSets,
    ).filter((f) => f.layerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_poiSetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TransitSetsTable, List<TransitSet>>
  _transitSetsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transitSets,
    aliasName: $_aliasNameGenerator(db.layers.id, db.transitSets.layerId),
  );

  $$TransitSetsTableProcessedTableManager get transitSetsRefs {
    final manager = $$TransitSetsTableTableManager(
      $_db,
      $_db.transitSets,
    ).filter((f) => f.layerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_transitSetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BorderSetsTable, List<BorderSet>>
  _borderSetsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.borderSets,
    aliasName: $_aliasNameGenerator(db.layers.id, db.borderSets.layerId),
  );

  $$BorderSetsTableProcessedTableManager get borderSetsRefs {
    final manager = $$BorderSetsTableTableManager(
      $_db,
      $_db.borderSets,
    ).filter((f) => f.layerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_borderSetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LayersTableFilterComposer
    extends Composer<_$AppDatabase, $LayersTable> {
  $$LayersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorArgb => $composableBuilder(
    column: $table.colorArgb,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isVisible => $composableBuilder(
    column: $table.isVisible,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isInverted => $composableBuilder(
    column: $table.isInverted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get opacity => $composableBuilder(
    column: $table.opacity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get borderLevel => $composableBuilder(
    column: $table.borderLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get borderFillAreas => $composableBuilder(
    column: $table.borderFillAreas,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get borderShowNames => $composableBuilder(
    column: $table.borderShowNames,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> circlesRefs(
    Expression<bool> Function($$CirclesTableFilterComposer f) f,
  ) {
    final $$CirclesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.circles,
      getReferencedColumn: (t) => t.layerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CirclesTableFilterComposer(
            $db: $db,
            $table: $db.circles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> planesRefs(
    Expression<bool> Function($$PlanesTableFilterComposer f) f,
  ) {
    final $$PlanesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.planes,
      getReferencedColumn: (t) => t.layerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlanesTableFilterComposer(
            $db: $db,
            $table: $db.planes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> subspacesRefs(
    Expression<bool> Function($$SubspacesTableFilterComposer f) f,
  ) {
    final $$SubspacesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.subspaces,
      getReferencedColumn: (t) => t.layerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubspacesTableFilterComposer(
            $db: $db,
            $table: $db.subspaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> freeLinesRefs(
    Expression<bool> Function($$FreeLinesTableFilterComposer f) f,
  ) {
    final $$FreeLinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.freeLines,
      getReferencedColumn: (t) => t.layerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FreeLinesTableFilterComposer(
            $db: $db,
            $table: $db.freeLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> freeAreasRefs(
    Expression<bool> Function($$FreeAreasTableFilterComposer f) f,
  ) {
    final $$FreeAreasTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.freeAreas,
      getReferencedColumn: (t) => t.layerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FreeAreasTableFilterComposer(
            $db: $db,
            $table: $db.freeAreas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> heightRegionsRefs(
    Expression<bool> Function($$HeightRegionsTableFilterComposer f) f,
  ) {
    final $$HeightRegionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.heightRegions,
      getReferencedColumn: (t) => t.layerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HeightRegionsTableFilterComposer(
            $db: $db,
            $table: $db.heightRegions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> poiSetsRefs(
    Expression<bool> Function($$PoiSetsTableFilterComposer f) f,
  ) {
    final $$PoiSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.poiSets,
      getReferencedColumn: (t) => t.layerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoiSetsTableFilterComposer(
            $db: $db,
            $table: $db.poiSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> transitSetsRefs(
    Expression<bool> Function($$TransitSetsTableFilterComposer f) f,
  ) {
    final $$TransitSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transitSets,
      getReferencedColumn: (t) => t.layerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransitSetsTableFilterComposer(
            $db: $db,
            $table: $db.transitSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> borderSetsRefs(
    Expression<bool> Function($$BorderSetsTableFilterComposer f) f,
  ) {
    final $$BorderSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.borderSets,
      getReferencedColumn: (t) => t.layerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BorderSetsTableFilterComposer(
            $db: $db,
            $table: $db.borderSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LayersTableOrderingComposer
    extends Composer<_$AppDatabase, $LayersTable> {
  $$LayersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorArgb => $composableBuilder(
    column: $table.colorArgb,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isVisible => $composableBuilder(
    column: $table.isVisible,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isInverted => $composableBuilder(
    column: $table.isInverted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get opacity => $composableBuilder(
    column: $table.opacity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get borderLevel => $composableBuilder(
    column: $table.borderLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get borderFillAreas => $composableBuilder(
    column: $table.borderFillAreas,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get borderShowNames => $composableBuilder(
    column: $table.borderShowNames,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LayersTableAnnotationComposer
    extends Composer<_$AppDatabase, $LayersTable> {
  $$LayersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get colorArgb =>
      $composableBuilder(column: $table.colorArgb, builder: (column) => column);

  GeneratedColumn<bool> get isVisible =>
      $composableBuilder(column: $table.isVisible, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<bool> get isInverted => $composableBuilder(
    column: $table.isInverted,
    builder: (column) => column,
  );

  GeneratedColumn<double> get opacity =>
      $composableBuilder(column: $table.opacity, builder: (column) => column);

  GeneratedColumn<String> get borderLevel => $composableBuilder(
    column: $table.borderLevel,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get borderFillAreas => $composableBuilder(
    column: $table.borderFillAreas,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get borderShowNames => $composableBuilder(
    column: $table.borderShowNames,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> circlesRefs<T extends Object>(
    Expression<T> Function($$CirclesTableAnnotationComposer a) f,
  ) {
    final $$CirclesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.circles,
      getReferencedColumn: (t) => t.layerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CirclesTableAnnotationComposer(
            $db: $db,
            $table: $db.circles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> planesRefs<T extends Object>(
    Expression<T> Function($$PlanesTableAnnotationComposer a) f,
  ) {
    final $$PlanesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.planes,
      getReferencedColumn: (t) => t.layerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlanesTableAnnotationComposer(
            $db: $db,
            $table: $db.planes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> subspacesRefs<T extends Object>(
    Expression<T> Function($$SubspacesTableAnnotationComposer a) f,
  ) {
    final $$SubspacesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.subspaces,
      getReferencedColumn: (t) => t.layerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubspacesTableAnnotationComposer(
            $db: $db,
            $table: $db.subspaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> freeLinesRefs<T extends Object>(
    Expression<T> Function($$FreeLinesTableAnnotationComposer a) f,
  ) {
    final $$FreeLinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.freeLines,
      getReferencedColumn: (t) => t.layerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FreeLinesTableAnnotationComposer(
            $db: $db,
            $table: $db.freeLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> freeAreasRefs<T extends Object>(
    Expression<T> Function($$FreeAreasTableAnnotationComposer a) f,
  ) {
    final $$FreeAreasTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.freeAreas,
      getReferencedColumn: (t) => t.layerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FreeAreasTableAnnotationComposer(
            $db: $db,
            $table: $db.freeAreas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> heightRegionsRefs<T extends Object>(
    Expression<T> Function($$HeightRegionsTableAnnotationComposer a) f,
  ) {
    final $$HeightRegionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.heightRegions,
      getReferencedColumn: (t) => t.layerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HeightRegionsTableAnnotationComposer(
            $db: $db,
            $table: $db.heightRegions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> poiSetsRefs<T extends Object>(
    Expression<T> Function($$PoiSetsTableAnnotationComposer a) f,
  ) {
    final $$PoiSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.poiSets,
      getReferencedColumn: (t) => t.layerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoiSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.poiSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> transitSetsRefs<T extends Object>(
    Expression<T> Function($$TransitSetsTableAnnotationComposer a) f,
  ) {
    final $$TransitSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transitSets,
      getReferencedColumn: (t) => t.layerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransitSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.transitSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> borderSetsRefs<T extends Object>(
    Expression<T> Function($$BorderSetsTableAnnotationComposer a) f,
  ) {
    final $$BorderSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.borderSets,
      getReferencedColumn: (t) => t.layerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BorderSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.borderSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LayersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LayersTable,
          Layer,
          $$LayersTableFilterComposer,
          $$LayersTableOrderingComposer,
          $$LayersTableAnnotationComposer,
          $$LayersTableCreateCompanionBuilder,
          $$LayersTableUpdateCompanionBuilder,
          (Layer, $$LayersTableReferences),
          Layer,
          PrefetchHooks Function({
            bool circlesRefs,
            bool planesRefs,
            bool subspacesRefs,
            bool freeLinesRefs,
            bool freeAreasRefs,
            bool heightRegionsRefs,
            bool poiSetsRefs,
            bool transitSetsRefs,
            bool borderSetsRefs,
          })
        > {
  $$LayersTableTableManager(_$AppDatabase db, $LayersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LayersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LayersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LayersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> colorArgb = const Value.absent(),
                Value<bool> isVisible = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<bool> isInverted = const Value.absent(),
                Value<double> opacity = const Value.absent(),
                Value<String?> borderLevel = const Value.absent(),
                Value<bool> borderFillAreas = const Value.absent(),
                Value<bool> borderShowNames = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LayersCompanion(
                id: id,
                name: name,
                colorArgb: colorArgb,
                isVisible: isVisible,
                sortOrder: sortOrder,
                type: type,
                isInverted: isInverted,
                opacity: opacity,
                borderLevel: borderLevel,
                borderFillAreas: borderFillAreas,
                borderShowNames: borderShowNames,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int colorArgb,
                Value<bool> isVisible = const Value.absent(),
                required int sortOrder,
                Value<String> type = const Value.absent(),
                Value<bool> isInverted = const Value.absent(),
                Value<double> opacity = const Value.absent(),
                Value<String?> borderLevel = const Value.absent(),
                Value<bool> borderFillAreas = const Value.absent(),
                Value<bool> borderShowNames = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LayersCompanion.insert(
                id: id,
                name: name,
                colorArgb: colorArgb,
                isVisible: isVisible,
                sortOrder: sortOrder,
                type: type,
                isInverted: isInverted,
                opacity: opacity,
                borderLevel: borderLevel,
                borderFillAreas: borderFillAreas,
                borderShowNames: borderShowNames,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$LayersTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                circlesRefs = false,
                planesRefs = false,
                subspacesRefs = false,
                freeLinesRefs = false,
                freeAreasRefs = false,
                heightRegionsRefs = false,
                poiSetsRefs = false,
                transitSetsRefs = false,
                borderSetsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (circlesRefs) db.circles,
                    if (planesRefs) db.planes,
                    if (subspacesRefs) db.subspaces,
                    if (freeLinesRefs) db.freeLines,
                    if (freeAreasRefs) db.freeAreas,
                    if (heightRegionsRefs) db.heightRegions,
                    if (poiSetsRefs) db.poiSets,
                    if (transitSetsRefs) db.transitSets,
                    if (borderSetsRefs) db.borderSets,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (circlesRefs)
                        await $_getPrefetchedData<Layer, $LayersTable, Circle>(
                          currentTable: table,
                          referencedTable: $$LayersTableReferences
                              ._circlesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LayersTableReferences(
                                db,
                                table,
                                p0,
                              ).circlesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.layerId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (planesRefs)
                        await $_getPrefetchedData<Layer, $LayersTable, Plane>(
                          currentTable: table,
                          referencedTable: $$LayersTableReferences
                              ._planesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LayersTableReferences(db, table, p0).planesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.layerId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (subspacesRefs)
                        await $_getPrefetchedData<
                          Layer,
                          $LayersTable,
                          Subspace
                        >(
                          currentTable: table,
                          referencedTable: $$LayersTableReferences
                              ._subspacesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LayersTableReferences(
                                db,
                                table,
                                p0,
                              ).subspacesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.layerId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (freeLinesRefs)
                        await $_getPrefetchedData<
                          Layer,
                          $LayersTable,
                          FreeLine
                        >(
                          currentTable: table,
                          referencedTable: $$LayersTableReferences
                              ._freeLinesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LayersTableReferences(
                                db,
                                table,
                                p0,
                              ).freeLinesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.layerId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (freeAreasRefs)
                        await $_getPrefetchedData<
                          Layer,
                          $LayersTable,
                          FreeArea
                        >(
                          currentTable: table,
                          referencedTable: $$LayersTableReferences
                              ._freeAreasRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LayersTableReferences(
                                db,
                                table,
                                p0,
                              ).freeAreasRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.layerId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (heightRegionsRefs)
                        await $_getPrefetchedData<
                          Layer,
                          $LayersTable,
                          HeightRegion
                        >(
                          currentTable: table,
                          referencedTable: $$LayersTableReferences
                              ._heightRegionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LayersTableReferences(
                                db,
                                table,
                                p0,
                              ).heightRegionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.layerId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (poiSetsRefs)
                        await $_getPrefetchedData<Layer, $LayersTable, PoiSet>(
                          currentTable: table,
                          referencedTable: $$LayersTableReferences
                              ._poiSetsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LayersTableReferences(
                                db,
                                table,
                                p0,
                              ).poiSetsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.layerId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (transitSetsRefs)
                        await $_getPrefetchedData<
                          Layer,
                          $LayersTable,
                          TransitSet
                        >(
                          currentTable: table,
                          referencedTable: $$LayersTableReferences
                              ._transitSetsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LayersTableReferences(
                                db,
                                table,
                                p0,
                              ).transitSetsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.layerId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (borderSetsRefs)
                        await $_getPrefetchedData<
                          Layer,
                          $LayersTable,
                          BorderSet
                        >(
                          currentTable: table,
                          referencedTable: $$LayersTableReferences
                              ._borderSetsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LayersTableReferences(
                                db,
                                table,
                                p0,
                              ).borderSetsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.layerId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LayersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LayersTable,
      Layer,
      $$LayersTableFilterComposer,
      $$LayersTableOrderingComposer,
      $$LayersTableAnnotationComposer,
      $$LayersTableCreateCompanionBuilder,
      $$LayersTableUpdateCompanionBuilder,
      (Layer, $$LayersTableReferences),
      Layer,
      PrefetchHooks Function({
        bool circlesRefs,
        bool planesRefs,
        bool subspacesRefs,
        bool freeLinesRefs,
        bool freeAreasRefs,
        bool heightRegionsRefs,
        bool poiSetsRefs,
        bool transitSetsRefs,
        bool borderSetsRefs,
      })
    >;
typedef $$CirclesTableCreateCompanionBuilder =
    CirclesCompanion Function({
      required String id,
      required String layerId,
      required double centerLat,
      required double centerLng,
      required double radiusMeters,
      Value<String?> label,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$CirclesTableUpdateCompanionBuilder =
    CirclesCompanion Function({
      Value<String> id,
      Value<String> layerId,
      Value<double> centerLat,
      Value<double> centerLng,
      Value<double> radiusMeters,
      Value<String?> label,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$CirclesTableReferences
    extends BaseReferences<_$AppDatabase, $CirclesTable, Circle> {
  $$CirclesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LayersTable _layerIdTable(_$AppDatabase db) => db.layers.createAlias(
    $_aliasNameGenerator(db.circles.layerId, db.layers.id),
  );

  $$LayersTableProcessedTableManager get layerId {
    final $_column = $_itemColumn<String>('layer_id')!;

    final manager = $$LayersTableTableManager(
      $_db,
      $_db.layers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_layerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CirclesTableFilterComposer
    extends Composer<_$AppDatabase, $CirclesTable> {
  $$CirclesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get centerLat => $composableBuilder(
    column: $table.centerLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get centerLng => $composableBuilder(
    column: $table.centerLng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get radiusMeters => $composableBuilder(
    column: $table.radiusMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LayersTableFilterComposer get layerId {
    final $$LayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.layerId,
      referencedTable: $db.layers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayersTableFilterComposer(
            $db: $db,
            $table: $db.layers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CirclesTableOrderingComposer
    extends Composer<_$AppDatabase, $CirclesTable> {
  $$CirclesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get centerLat => $composableBuilder(
    column: $table.centerLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get centerLng => $composableBuilder(
    column: $table.centerLng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get radiusMeters => $composableBuilder(
    column: $table.radiusMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LayersTableOrderingComposer get layerId {
    final $$LayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.layerId,
      referencedTable: $db.layers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayersTableOrderingComposer(
            $db: $db,
            $table: $db.layers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CirclesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CirclesTable> {
  $$CirclesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get centerLat =>
      $composableBuilder(column: $table.centerLat, builder: (column) => column);

  GeneratedColumn<double> get centerLng =>
      $composableBuilder(column: $table.centerLng, builder: (column) => column);

  GeneratedColumn<double> get radiusMeters => $composableBuilder(
    column: $table.radiusMeters,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$LayersTableAnnotationComposer get layerId {
    final $$LayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.layerId,
      referencedTable: $db.layers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayersTableAnnotationComposer(
            $db: $db,
            $table: $db.layers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CirclesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CirclesTable,
          Circle,
          $$CirclesTableFilterComposer,
          $$CirclesTableOrderingComposer,
          $$CirclesTableAnnotationComposer,
          $$CirclesTableCreateCompanionBuilder,
          $$CirclesTableUpdateCompanionBuilder,
          (Circle, $$CirclesTableReferences),
          Circle,
          PrefetchHooks Function({bool layerId})
        > {
  $$CirclesTableTableManager(_$AppDatabase db, $CirclesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CirclesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CirclesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CirclesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> layerId = const Value.absent(),
                Value<double> centerLat = const Value.absent(),
                Value<double> centerLng = const Value.absent(),
                Value<double> radiusMeters = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CirclesCompanion(
                id: id,
                layerId: layerId,
                centerLat: centerLat,
                centerLng: centerLng,
                radiusMeters: radiusMeters,
                label: label,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String layerId,
                required double centerLat,
                required double centerLng,
                required double radiusMeters,
                Value<String?> label = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CirclesCompanion.insert(
                id: id,
                layerId: layerId,
                centerLat: centerLat,
                centerLng: centerLng,
                radiusMeters: radiusMeters,
                label: label,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CirclesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({layerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (layerId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.layerId,
                                referencedTable: $$CirclesTableReferences
                                    ._layerIdTable(db),
                                referencedColumn: $$CirclesTableReferences
                                    ._layerIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CirclesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CirclesTable,
      Circle,
      $$CirclesTableFilterComposer,
      $$CirclesTableOrderingComposer,
      $$CirclesTableAnnotationComposer,
      $$CirclesTableCreateCompanionBuilder,
      $$CirclesTableUpdateCompanionBuilder,
      (Circle, $$CirclesTableReferences),
      Circle,
      PrefetchHooks Function({bool layerId})
    >;
typedef $$PlanesTableCreateCompanionBuilder =
    PlanesCompanion Function({
      required String id,
      required String layerId,
      required double aLat,
      required double aLng,
      required double bLat,
      required double bLng,
      Value<bool> nearA,
      Value<String?> label,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$PlanesTableUpdateCompanionBuilder =
    PlanesCompanion Function({
      Value<String> id,
      Value<String> layerId,
      Value<double> aLat,
      Value<double> aLng,
      Value<double> bLat,
      Value<double> bLng,
      Value<bool> nearA,
      Value<String?> label,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$PlanesTableReferences
    extends BaseReferences<_$AppDatabase, $PlanesTable, Plane> {
  $$PlanesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LayersTable _layerIdTable(_$AppDatabase db) => db.layers.createAlias(
    $_aliasNameGenerator(db.planes.layerId, db.layers.id),
  );

  $$LayersTableProcessedTableManager get layerId {
    final $_column = $_itemColumn<String>('layer_id')!;

    final manager = $$LayersTableTableManager(
      $_db,
      $_db.layers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_layerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlanesTableFilterComposer
    extends Composer<_$AppDatabase, $PlanesTable> {
  $$PlanesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get aLat => $composableBuilder(
    column: $table.aLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get aLng => $composableBuilder(
    column: $table.aLng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get bLat => $composableBuilder(
    column: $table.bLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get bLng => $composableBuilder(
    column: $table.bLng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get nearA => $composableBuilder(
    column: $table.nearA,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LayersTableFilterComposer get layerId {
    final $$LayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.layerId,
      referencedTable: $db.layers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayersTableFilterComposer(
            $db: $db,
            $table: $db.layers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlanesTableOrderingComposer
    extends Composer<_$AppDatabase, $PlanesTable> {
  $$PlanesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get aLat => $composableBuilder(
    column: $table.aLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get aLng => $composableBuilder(
    column: $table.aLng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get bLat => $composableBuilder(
    column: $table.bLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get bLng => $composableBuilder(
    column: $table.bLng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get nearA => $composableBuilder(
    column: $table.nearA,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LayersTableOrderingComposer get layerId {
    final $$LayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.layerId,
      referencedTable: $db.layers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayersTableOrderingComposer(
            $db: $db,
            $table: $db.layers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlanesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlanesTable> {
  $$PlanesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get aLat =>
      $composableBuilder(column: $table.aLat, builder: (column) => column);

  GeneratedColumn<double> get aLng =>
      $composableBuilder(column: $table.aLng, builder: (column) => column);

  GeneratedColumn<double> get bLat =>
      $composableBuilder(column: $table.bLat, builder: (column) => column);

  GeneratedColumn<double> get bLng =>
      $composableBuilder(column: $table.bLng, builder: (column) => column);

  GeneratedColumn<bool> get nearA =>
      $composableBuilder(column: $table.nearA, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$LayersTableAnnotationComposer get layerId {
    final $$LayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.layerId,
      referencedTable: $db.layers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayersTableAnnotationComposer(
            $db: $db,
            $table: $db.layers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlanesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlanesTable,
          Plane,
          $$PlanesTableFilterComposer,
          $$PlanesTableOrderingComposer,
          $$PlanesTableAnnotationComposer,
          $$PlanesTableCreateCompanionBuilder,
          $$PlanesTableUpdateCompanionBuilder,
          (Plane, $$PlanesTableReferences),
          Plane,
          PrefetchHooks Function({bool layerId})
        > {
  $$PlanesTableTableManager(_$AppDatabase db, $PlanesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlanesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlanesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlanesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> layerId = const Value.absent(),
                Value<double> aLat = const Value.absent(),
                Value<double> aLng = const Value.absent(),
                Value<double> bLat = const Value.absent(),
                Value<double> bLng = const Value.absent(),
                Value<bool> nearA = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlanesCompanion(
                id: id,
                layerId: layerId,
                aLat: aLat,
                aLng: aLng,
                bLat: bLat,
                bLng: bLng,
                nearA: nearA,
                label: label,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String layerId,
                required double aLat,
                required double aLng,
                required double bLat,
                required double bLng,
                Value<bool> nearA = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlanesCompanion.insert(
                id: id,
                layerId: layerId,
                aLat: aLat,
                aLng: aLng,
                bLat: bLat,
                bLng: bLng,
                nearA: nearA,
                label: label,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$PlanesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({layerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (layerId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.layerId,
                                referencedTable: $$PlanesTableReferences
                                    ._layerIdTable(db),
                                referencedColumn: $$PlanesTableReferences
                                    ._layerIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlanesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlanesTable,
      Plane,
      $$PlanesTableFilterComposer,
      $$PlanesTableOrderingComposer,
      $$PlanesTableAnnotationComposer,
      $$PlanesTableCreateCompanionBuilder,
      $$PlanesTableUpdateCompanionBuilder,
      (Plane, $$PlanesTableReferences),
      Plane,
      PrefetchHooks Function({bool layerId})
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<double> uncertaintyMeters,
      Value<double?> lastLat,
      Value<double?> lastLng,
      Value<double?> lastZoom,
      Value<bool> transportOverlay,
      Value<String?> transitEndpoint,
      Value<int> poiCategories,
      Value<int> borderLevels,
      Value<bool> toolsExpanded,
      Value<bool> basemapVisible,
      Value<double> basemapOpacity,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<double> uncertaintyMeters,
      Value<double?> lastLat,
      Value<double?> lastLng,
      Value<double?> lastZoom,
      Value<bool> transportOverlay,
      Value<String?> transitEndpoint,
      Value<int> poiCategories,
      Value<int> borderLevels,
      Value<bool> toolsExpanded,
      Value<bool> basemapVisible,
      Value<double> basemapOpacity,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get uncertaintyMeters => $composableBuilder(
    column: $table.uncertaintyMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lastLat => $composableBuilder(
    column: $table.lastLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lastLng => $composableBuilder(
    column: $table.lastLng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lastZoom => $composableBuilder(
    column: $table.lastZoom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get transportOverlay => $composableBuilder(
    column: $table.transportOverlay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transitEndpoint => $composableBuilder(
    column: $table.transitEndpoint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get poiCategories => $composableBuilder(
    column: $table.poiCategories,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get borderLevels => $composableBuilder(
    column: $table.borderLevels,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get toolsExpanded => $composableBuilder(
    column: $table.toolsExpanded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get basemapVisible => $composableBuilder(
    column: $table.basemapVisible,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get basemapOpacity => $composableBuilder(
    column: $table.basemapOpacity,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get uncertaintyMeters => $composableBuilder(
    column: $table.uncertaintyMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lastLat => $composableBuilder(
    column: $table.lastLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lastLng => $composableBuilder(
    column: $table.lastLng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lastZoom => $composableBuilder(
    column: $table.lastZoom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get transportOverlay => $composableBuilder(
    column: $table.transportOverlay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transitEndpoint => $composableBuilder(
    column: $table.transitEndpoint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get poiCategories => $composableBuilder(
    column: $table.poiCategories,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get borderLevels => $composableBuilder(
    column: $table.borderLevels,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get toolsExpanded => $composableBuilder(
    column: $table.toolsExpanded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get basemapVisible => $composableBuilder(
    column: $table.basemapVisible,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get basemapOpacity => $composableBuilder(
    column: $table.basemapOpacity,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get uncertaintyMeters => $composableBuilder(
    column: $table.uncertaintyMeters,
    builder: (column) => column,
  );

  GeneratedColumn<double> get lastLat =>
      $composableBuilder(column: $table.lastLat, builder: (column) => column);

  GeneratedColumn<double> get lastLng =>
      $composableBuilder(column: $table.lastLng, builder: (column) => column);

  GeneratedColumn<double> get lastZoom =>
      $composableBuilder(column: $table.lastZoom, builder: (column) => column);

  GeneratedColumn<bool> get transportOverlay => $composableBuilder(
    column: $table.transportOverlay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transitEndpoint => $composableBuilder(
    column: $table.transitEndpoint,
    builder: (column) => column,
  );

  GeneratedColumn<int> get poiCategories => $composableBuilder(
    column: $table.poiCategories,
    builder: (column) => column,
  );

  GeneratedColumn<int> get borderLevels => $composableBuilder(
    column: $table.borderLevels,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get toolsExpanded => $composableBuilder(
    column: $table.toolsExpanded,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get basemapVisible => $composableBuilder(
    column: $table.basemapVisible,
    builder: (column) => column,
  );

  GeneratedColumn<double> get basemapOpacity => $composableBuilder(
    column: $table.basemapOpacity,
    builder: (column) => column,
  );
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<double> uncertaintyMeters = const Value.absent(),
                Value<double?> lastLat = const Value.absent(),
                Value<double?> lastLng = const Value.absent(),
                Value<double?> lastZoom = const Value.absent(),
                Value<bool> transportOverlay = const Value.absent(),
                Value<String?> transitEndpoint = const Value.absent(),
                Value<int> poiCategories = const Value.absent(),
                Value<int> borderLevels = const Value.absent(),
                Value<bool> toolsExpanded = const Value.absent(),
                Value<bool> basemapVisible = const Value.absent(),
                Value<double> basemapOpacity = const Value.absent(),
              }) => AppSettingsCompanion(
                id: id,
                uncertaintyMeters: uncertaintyMeters,
                lastLat: lastLat,
                lastLng: lastLng,
                lastZoom: lastZoom,
                transportOverlay: transportOverlay,
                transitEndpoint: transitEndpoint,
                poiCategories: poiCategories,
                borderLevels: borderLevels,
                toolsExpanded: toolsExpanded,
                basemapVisible: basemapVisible,
                basemapOpacity: basemapOpacity,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<double> uncertaintyMeters = const Value.absent(),
                Value<double?> lastLat = const Value.absent(),
                Value<double?> lastLng = const Value.absent(),
                Value<double?> lastZoom = const Value.absent(),
                Value<bool> transportOverlay = const Value.absent(),
                Value<String?> transitEndpoint = const Value.absent(),
                Value<int> poiCategories = const Value.absent(),
                Value<int> borderLevels = const Value.absent(),
                Value<bool> toolsExpanded = const Value.absent(),
                Value<bool> basemapVisible = const Value.absent(),
                Value<double> basemapOpacity = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                id: id,
                uncertaintyMeters: uncertaintyMeters,
                lastLat: lastLat,
                lastLng: lastLng,
                lastZoom: lastZoom,
                transportOverlay: transportOverlay,
                transitEndpoint: transitEndpoint,
                poiCategories: poiCategories,
                borderLevels: borderLevels,
                toolsExpanded: toolsExpanded,
                basemapVisible: basemapVisible,
                basemapOpacity: basemapOpacity,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $$SubspacesTableCreateCompanionBuilder =
    SubspacesCompanion Function({
      required String id,
      required String layerId,
      Value<String?> label,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$SubspacesTableUpdateCompanionBuilder =
    SubspacesCompanion Function({
      Value<String> id,
      Value<String> layerId,
      Value<String?> label,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$SubspacesTableReferences
    extends BaseReferences<_$AppDatabase, $SubspacesTable, Subspace> {
  $$SubspacesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LayersTable _layerIdTable(_$AppDatabase db) => db.layers.createAlias(
    $_aliasNameGenerator(db.subspaces.layerId, db.layers.id),
  );

  $$LayersTableProcessedTableManager get layerId {
    final $_column = $_itemColumn<String>('layer_id')!;

    final manager = $$LayersTableTableManager(
      $_db,
      $_db.layers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_layerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SubspacePointsTable, List<SubspacePoint>>
  _subspacePointsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.subspacePoints,
    aliasName: $_aliasNameGenerator(
      db.subspaces.id,
      db.subspacePoints.subspaceId,
    ),
  );

  $$SubspacePointsTableProcessedTableManager get subspacePointsRefs {
    final manager = $$SubspacePointsTableTableManager(
      $_db,
      $_db.subspacePoints,
    ).filter((f) => f.subspaceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_subspacePointsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SubspacesTableFilterComposer
    extends Composer<_$AppDatabase, $SubspacesTable> {
  $$SubspacesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LayersTableFilterComposer get layerId {
    final $$LayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.layerId,
      referencedTable: $db.layers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayersTableFilterComposer(
            $db: $db,
            $table: $db.layers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> subspacePointsRefs(
    Expression<bool> Function($$SubspacePointsTableFilterComposer f) f,
  ) {
    final $$SubspacePointsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.subspacePoints,
      getReferencedColumn: (t) => t.subspaceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubspacePointsTableFilterComposer(
            $db: $db,
            $table: $db.subspacePoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SubspacesTableOrderingComposer
    extends Composer<_$AppDatabase, $SubspacesTable> {
  $$SubspacesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LayersTableOrderingComposer get layerId {
    final $$LayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.layerId,
      referencedTable: $db.layers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayersTableOrderingComposer(
            $db: $db,
            $table: $db.layers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SubspacesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubspacesTable> {
  $$SubspacesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$LayersTableAnnotationComposer get layerId {
    final $$LayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.layerId,
      referencedTable: $db.layers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayersTableAnnotationComposer(
            $db: $db,
            $table: $db.layers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> subspacePointsRefs<T extends Object>(
    Expression<T> Function($$SubspacePointsTableAnnotationComposer a) f,
  ) {
    final $$SubspacePointsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.subspacePoints,
      getReferencedColumn: (t) => t.subspaceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubspacePointsTableAnnotationComposer(
            $db: $db,
            $table: $db.subspacePoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SubspacesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SubspacesTable,
          Subspace,
          $$SubspacesTableFilterComposer,
          $$SubspacesTableOrderingComposer,
          $$SubspacesTableAnnotationComposer,
          $$SubspacesTableCreateCompanionBuilder,
          $$SubspacesTableUpdateCompanionBuilder,
          (Subspace, $$SubspacesTableReferences),
          Subspace,
          PrefetchHooks Function({bool layerId, bool subspacePointsRefs})
        > {
  $$SubspacesTableTableManager(_$AppDatabase db, $SubspacesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubspacesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubspacesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubspacesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> layerId = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubspacesCompanion(
                id: id,
                layerId: layerId,
                label: label,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String layerId,
                Value<String?> label = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubspacesCompanion.insert(
                id: id,
                layerId: layerId,
                label: label,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SubspacesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({layerId = false, subspacePointsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (subspacePointsRefs) db.subspacePoints,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (layerId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.layerId,
                                    referencedTable: $$SubspacesTableReferences
                                        ._layerIdTable(db),
                                    referencedColumn: $$SubspacesTableReferences
                                        ._layerIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (subspacePointsRefs)
                        await $_getPrefetchedData<
                          Subspace,
                          $SubspacesTable,
                          SubspacePoint
                        >(
                          currentTable: table,
                          referencedTable: $$SubspacesTableReferences
                              ._subspacePointsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SubspacesTableReferences(
                                db,
                                table,
                                p0,
                              ).subspacePointsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.subspaceId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SubspacesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SubspacesTable,
      Subspace,
      $$SubspacesTableFilterComposer,
      $$SubspacesTableOrderingComposer,
      $$SubspacesTableAnnotationComposer,
      $$SubspacesTableCreateCompanionBuilder,
      $$SubspacesTableUpdateCompanionBuilder,
      (Subspace, $$SubspacesTableReferences),
      Subspace,
      PrefetchHooks Function({bool layerId, bool subspacePointsRefs})
    >;
typedef $$SubspacePointsTableCreateCompanionBuilder =
    SubspacePointsCompanion Function({
      required String id,
      required String subspaceId,
      required double lat,
      required double lng,
      required int sortOrder,
      Value<bool> isMain,
      Value<String?> label,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$SubspacePointsTableUpdateCompanionBuilder =
    SubspacePointsCompanion Function({
      Value<String> id,
      Value<String> subspaceId,
      Value<double> lat,
      Value<double> lng,
      Value<int> sortOrder,
      Value<bool> isMain,
      Value<String?> label,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$SubspacePointsTableReferences
    extends BaseReferences<_$AppDatabase, $SubspacePointsTable, SubspacePoint> {
  $$SubspacePointsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SubspacesTable _subspaceIdTable(_$AppDatabase db) =>
      db.subspaces.createAlias(
        $_aliasNameGenerator(db.subspacePoints.subspaceId, db.subspaces.id),
      );

  $$SubspacesTableProcessedTableManager get subspaceId {
    final $_column = $_itemColumn<String>('subspace_id')!;

    final manager = $$SubspacesTableTableManager(
      $_db,
      $_db.subspaces,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_subspaceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SubspacePointsTableFilterComposer
    extends Composer<_$AppDatabase, $SubspacePointsTable> {
  $$SubspacePointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMain => $composableBuilder(
    column: $table.isMain,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SubspacesTableFilterComposer get subspaceId {
    final $$SubspacesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subspaceId,
      referencedTable: $db.subspaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubspacesTableFilterComposer(
            $db: $db,
            $table: $db.subspaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SubspacePointsTableOrderingComposer
    extends Composer<_$AppDatabase, $SubspacePointsTable> {
  $$SubspacePointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMain => $composableBuilder(
    column: $table.isMain,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SubspacesTableOrderingComposer get subspaceId {
    final $$SubspacesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subspaceId,
      referencedTable: $db.subspaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubspacesTableOrderingComposer(
            $db: $db,
            $table: $db.subspaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SubspacePointsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubspacePointsTable> {
  $$SubspacePointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isMain =>
      $composableBuilder(column: $table.isMain, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$SubspacesTableAnnotationComposer get subspaceId {
    final $$SubspacesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subspaceId,
      referencedTable: $db.subspaces,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubspacesTableAnnotationComposer(
            $db: $db,
            $table: $db.subspaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SubspacePointsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SubspacePointsTable,
          SubspacePoint,
          $$SubspacePointsTableFilterComposer,
          $$SubspacePointsTableOrderingComposer,
          $$SubspacePointsTableAnnotationComposer,
          $$SubspacePointsTableCreateCompanionBuilder,
          $$SubspacePointsTableUpdateCompanionBuilder,
          (SubspacePoint, $$SubspacePointsTableReferences),
          SubspacePoint,
          PrefetchHooks Function({bool subspaceId})
        > {
  $$SubspacePointsTableTableManager(
    _$AppDatabase db,
    $SubspacePointsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubspacePointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubspacePointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubspacePointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> subspaceId = const Value.absent(),
                Value<double> lat = const Value.absent(),
                Value<double> lng = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isMain = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubspacePointsCompanion(
                id: id,
                subspaceId: subspaceId,
                lat: lat,
                lng: lng,
                sortOrder: sortOrder,
                isMain: isMain,
                label: label,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String subspaceId,
                required double lat,
                required double lng,
                required int sortOrder,
                Value<bool> isMain = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubspacePointsCompanion.insert(
                id: id,
                subspaceId: subspaceId,
                lat: lat,
                lng: lng,
                sortOrder: sortOrder,
                isMain: isMain,
                label: label,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SubspacePointsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({subspaceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (subspaceId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.subspaceId,
                                referencedTable: $$SubspacePointsTableReferences
                                    ._subspaceIdTable(db),
                                referencedColumn:
                                    $$SubspacePointsTableReferences
                                        ._subspaceIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SubspacePointsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SubspacePointsTable,
      SubspacePoint,
      $$SubspacePointsTableFilterComposer,
      $$SubspacePointsTableOrderingComposer,
      $$SubspacePointsTableAnnotationComposer,
      $$SubspacePointsTableCreateCompanionBuilder,
      $$SubspacePointsTableUpdateCompanionBuilder,
      (SubspacePoint, $$SubspacePointsTableReferences),
      SubspacePoint,
      PrefetchHooks Function({bool subspaceId})
    >;
typedef $$FreeLinesTableCreateCompanionBuilder =
    FreeLinesCompanion Function({
      required String id,
      required String layerId,
      Value<String?> label,
      Value<double> offsetMeters,
      Value<double?> inclusionLat,
      Value<double?> inclusionLng,
      Value<double?> inclusionRadiusMeters,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$FreeLinesTableUpdateCompanionBuilder =
    FreeLinesCompanion Function({
      Value<String> id,
      Value<String> layerId,
      Value<String?> label,
      Value<double> offsetMeters,
      Value<double?> inclusionLat,
      Value<double?> inclusionLng,
      Value<double?> inclusionRadiusMeters,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$FreeLinesTableReferences
    extends BaseReferences<_$AppDatabase, $FreeLinesTable, FreeLine> {
  $$FreeLinesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LayersTable _layerIdTable(_$AppDatabase db) => db.layers.createAlias(
    $_aliasNameGenerator(db.freeLines.layerId, db.layers.id),
  );

  $$LayersTableProcessedTableManager get layerId {
    final $_column = $_itemColumn<String>('layer_id')!;

    final manager = $$LayersTableTableManager(
      $_db,
      $_db.layers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_layerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$FreeLinePointsTable, List<FreeLinePoint>>
  _freeLinePointsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.freeLinePoints,
    aliasName: $_aliasNameGenerator(
      db.freeLines.id,
      db.freeLinePoints.freeLineId,
    ),
  );

  $$FreeLinePointsTableProcessedTableManager get freeLinePointsRefs {
    final manager = $$FreeLinePointsTableTableManager(
      $_db,
      $_db.freeLinePoints,
    ).filter((f) => f.freeLineId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_freeLinePointsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FreeLinesTableFilterComposer
    extends Composer<_$AppDatabase, $FreeLinesTable> {
  $$FreeLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get offsetMeters => $composableBuilder(
    column: $table.offsetMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get inclusionLat => $composableBuilder(
    column: $table.inclusionLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get inclusionLng => $composableBuilder(
    column: $table.inclusionLng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get inclusionRadiusMeters => $composableBuilder(
    column: $table.inclusionRadiusMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LayersTableFilterComposer get layerId {
    final $$LayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.layerId,
      referencedTable: $db.layers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayersTableFilterComposer(
            $db: $db,
            $table: $db.layers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> freeLinePointsRefs(
    Expression<bool> Function($$FreeLinePointsTableFilterComposer f) f,
  ) {
    final $$FreeLinePointsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.freeLinePoints,
      getReferencedColumn: (t) => t.freeLineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FreeLinePointsTableFilterComposer(
            $db: $db,
            $table: $db.freeLinePoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FreeLinesTableOrderingComposer
    extends Composer<_$AppDatabase, $FreeLinesTable> {
  $$FreeLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get offsetMeters => $composableBuilder(
    column: $table.offsetMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get inclusionLat => $composableBuilder(
    column: $table.inclusionLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get inclusionLng => $composableBuilder(
    column: $table.inclusionLng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get inclusionRadiusMeters => $composableBuilder(
    column: $table.inclusionRadiusMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LayersTableOrderingComposer get layerId {
    final $$LayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.layerId,
      referencedTable: $db.layers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayersTableOrderingComposer(
            $db: $db,
            $table: $db.layers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FreeLinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FreeLinesTable> {
  $$FreeLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<double> get offsetMeters => $composableBuilder(
    column: $table.offsetMeters,
    builder: (column) => column,
  );

  GeneratedColumn<double> get inclusionLat => $composableBuilder(
    column: $table.inclusionLat,
    builder: (column) => column,
  );

  GeneratedColumn<double> get inclusionLng => $composableBuilder(
    column: $table.inclusionLng,
    builder: (column) => column,
  );

  GeneratedColumn<double> get inclusionRadiusMeters => $composableBuilder(
    column: $table.inclusionRadiusMeters,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$LayersTableAnnotationComposer get layerId {
    final $$LayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.layerId,
      referencedTable: $db.layers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayersTableAnnotationComposer(
            $db: $db,
            $table: $db.layers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> freeLinePointsRefs<T extends Object>(
    Expression<T> Function($$FreeLinePointsTableAnnotationComposer a) f,
  ) {
    final $$FreeLinePointsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.freeLinePoints,
      getReferencedColumn: (t) => t.freeLineId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FreeLinePointsTableAnnotationComposer(
            $db: $db,
            $table: $db.freeLinePoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FreeLinesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FreeLinesTable,
          FreeLine,
          $$FreeLinesTableFilterComposer,
          $$FreeLinesTableOrderingComposer,
          $$FreeLinesTableAnnotationComposer,
          $$FreeLinesTableCreateCompanionBuilder,
          $$FreeLinesTableUpdateCompanionBuilder,
          (FreeLine, $$FreeLinesTableReferences),
          FreeLine,
          PrefetchHooks Function({bool layerId, bool freeLinePointsRefs})
        > {
  $$FreeLinesTableTableManager(_$AppDatabase db, $FreeLinesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FreeLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FreeLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FreeLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> layerId = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<double> offsetMeters = const Value.absent(),
                Value<double?> inclusionLat = const Value.absent(),
                Value<double?> inclusionLng = const Value.absent(),
                Value<double?> inclusionRadiusMeters = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FreeLinesCompanion(
                id: id,
                layerId: layerId,
                label: label,
                offsetMeters: offsetMeters,
                inclusionLat: inclusionLat,
                inclusionLng: inclusionLng,
                inclusionRadiusMeters: inclusionRadiusMeters,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String layerId,
                Value<String?> label = const Value.absent(),
                Value<double> offsetMeters = const Value.absent(),
                Value<double?> inclusionLat = const Value.absent(),
                Value<double?> inclusionLng = const Value.absent(),
                Value<double?> inclusionRadiusMeters = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FreeLinesCompanion.insert(
                id: id,
                layerId: layerId,
                label: label,
                offsetMeters: offsetMeters,
                inclusionLat: inclusionLat,
                inclusionLng: inclusionLng,
                inclusionRadiusMeters: inclusionRadiusMeters,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FreeLinesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({layerId = false, freeLinePointsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (freeLinePointsRefs) db.freeLinePoints,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (layerId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.layerId,
                                    referencedTable: $$FreeLinesTableReferences
                                        ._layerIdTable(db),
                                    referencedColumn: $$FreeLinesTableReferences
                                        ._layerIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (freeLinePointsRefs)
                        await $_getPrefetchedData<
                          FreeLine,
                          $FreeLinesTable,
                          FreeLinePoint
                        >(
                          currentTable: table,
                          referencedTable: $$FreeLinesTableReferences
                              ._freeLinePointsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FreeLinesTableReferences(
                                db,
                                table,
                                p0,
                              ).freeLinePointsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.freeLineId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$FreeLinesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FreeLinesTable,
      FreeLine,
      $$FreeLinesTableFilterComposer,
      $$FreeLinesTableOrderingComposer,
      $$FreeLinesTableAnnotationComposer,
      $$FreeLinesTableCreateCompanionBuilder,
      $$FreeLinesTableUpdateCompanionBuilder,
      (FreeLine, $$FreeLinesTableReferences),
      FreeLine,
      PrefetchHooks Function({bool layerId, bool freeLinePointsRefs})
    >;
typedef $$FreeLinePointsTableCreateCompanionBuilder =
    FreeLinePointsCompanion Function({
      required String id,
      required String freeLineId,
      required double lat,
      required double lng,
      required int sortOrder,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$FreeLinePointsTableUpdateCompanionBuilder =
    FreeLinePointsCompanion Function({
      Value<String> id,
      Value<String> freeLineId,
      Value<double> lat,
      Value<double> lng,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$FreeLinePointsTableReferences
    extends BaseReferences<_$AppDatabase, $FreeLinePointsTable, FreeLinePoint> {
  $$FreeLinePointsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FreeLinesTable _freeLineIdTable(_$AppDatabase db) =>
      db.freeLines.createAlias(
        $_aliasNameGenerator(db.freeLinePoints.freeLineId, db.freeLines.id),
      );

  $$FreeLinesTableProcessedTableManager get freeLineId {
    final $_column = $_itemColumn<String>('free_line_id')!;

    final manager = $$FreeLinesTableTableManager(
      $_db,
      $_db.freeLines,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_freeLineIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FreeLinePointsTableFilterComposer
    extends Composer<_$AppDatabase, $FreeLinePointsTable> {
  $$FreeLinePointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$FreeLinesTableFilterComposer get freeLineId {
    final $$FreeLinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.freeLineId,
      referencedTable: $db.freeLines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FreeLinesTableFilterComposer(
            $db: $db,
            $table: $db.freeLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FreeLinePointsTableOrderingComposer
    extends Composer<_$AppDatabase, $FreeLinePointsTable> {
  $$FreeLinePointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$FreeLinesTableOrderingComposer get freeLineId {
    final $$FreeLinesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.freeLineId,
      referencedTable: $db.freeLines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FreeLinesTableOrderingComposer(
            $db: $db,
            $table: $db.freeLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FreeLinePointsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FreeLinePointsTable> {
  $$FreeLinePointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$FreeLinesTableAnnotationComposer get freeLineId {
    final $$FreeLinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.freeLineId,
      referencedTable: $db.freeLines,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FreeLinesTableAnnotationComposer(
            $db: $db,
            $table: $db.freeLines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FreeLinePointsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FreeLinePointsTable,
          FreeLinePoint,
          $$FreeLinePointsTableFilterComposer,
          $$FreeLinePointsTableOrderingComposer,
          $$FreeLinePointsTableAnnotationComposer,
          $$FreeLinePointsTableCreateCompanionBuilder,
          $$FreeLinePointsTableUpdateCompanionBuilder,
          (FreeLinePoint, $$FreeLinePointsTableReferences),
          FreeLinePoint,
          PrefetchHooks Function({bool freeLineId})
        > {
  $$FreeLinePointsTableTableManager(
    _$AppDatabase db,
    $FreeLinePointsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FreeLinePointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FreeLinePointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FreeLinePointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> freeLineId = const Value.absent(),
                Value<double> lat = const Value.absent(),
                Value<double> lng = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FreeLinePointsCompanion(
                id: id,
                freeLineId: freeLineId,
                lat: lat,
                lng: lng,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String freeLineId,
                required double lat,
                required double lng,
                required int sortOrder,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FreeLinePointsCompanion.insert(
                id: id,
                freeLineId: freeLineId,
                lat: lat,
                lng: lng,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FreeLinePointsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({freeLineId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (freeLineId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.freeLineId,
                                referencedTable: $$FreeLinePointsTableReferences
                                    ._freeLineIdTable(db),
                                referencedColumn:
                                    $$FreeLinePointsTableReferences
                                        ._freeLineIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FreeLinePointsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FreeLinePointsTable,
      FreeLinePoint,
      $$FreeLinePointsTableFilterComposer,
      $$FreeLinePointsTableOrderingComposer,
      $$FreeLinePointsTableAnnotationComposer,
      $$FreeLinePointsTableCreateCompanionBuilder,
      $$FreeLinePointsTableUpdateCompanionBuilder,
      (FreeLinePoint, $$FreeLinePointsTableReferences),
      FreeLinePoint,
      PrefetchHooks Function({bool freeLineId})
    >;
typedef $$FreeAreasTableCreateCompanionBuilder =
    FreeAreasCompanion Function({
      required String id,
      required String layerId,
      Value<String?> label,
      Value<double> offsetMeters,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$FreeAreasTableUpdateCompanionBuilder =
    FreeAreasCompanion Function({
      Value<String> id,
      Value<String> layerId,
      Value<String?> label,
      Value<double> offsetMeters,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$FreeAreasTableReferences
    extends BaseReferences<_$AppDatabase, $FreeAreasTable, FreeArea> {
  $$FreeAreasTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LayersTable _layerIdTable(_$AppDatabase db) => db.layers.createAlias(
    $_aliasNameGenerator(db.freeAreas.layerId, db.layers.id),
  );

  $$LayersTableProcessedTableManager get layerId {
    final $_column = $_itemColumn<String>('layer_id')!;

    final manager = $$LayersTableTableManager(
      $_db,
      $_db.layers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_layerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$FreeAreaPointsTable, List<FreeAreaPoint>>
  _freeAreaPointsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.freeAreaPoints,
    aliasName: $_aliasNameGenerator(
      db.freeAreas.id,
      db.freeAreaPoints.freeAreaId,
    ),
  );

  $$FreeAreaPointsTableProcessedTableManager get freeAreaPointsRefs {
    final manager = $$FreeAreaPointsTableTableManager(
      $_db,
      $_db.freeAreaPoints,
    ).filter((f) => f.freeAreaId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_freeAreaPointsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FreeAreasTableFilterComposer
    extends Composer<_$AppDatabase, $FreeAreasTable> {
  $$FreeAreasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get offsetMeters => $composableBuilder(
    column: $table.offsetMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LayersTableFilterComposer get layerId {
    final $$LayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.layerId,
      referencedTable: $db.layers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayersTableFilterComposer(
            $db: $db,
            $table: $db.layers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> freeAreaPointsRefs(
    Expression<bool> Function($$FreeAreaPointsTableFilterComposer f) f,
  ) {
    final $$FreeAreaPointsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.freeAreaPoints,
      getReferencedColumn: (t) => t.freeAreaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FreeAreaPointsTableFilterComposer(
            $db: $db,
            $table: $db.freeAreaPoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FreeAreasTableOrderingComposer
    extends Composer<_$AppDatabase, $FreeAreasTable> {
  $$FreeAreasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get offsetMeters => $composableBuilder(
    column: $table.offsetMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LayersTableOrderingComposer get layerId {
    final $$LayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.layerId,
      referencedTable: $db.layers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayersTableOrderingComposer(
            $db: $db,
            $table: $db.layers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FreeAreasTableAnnotationComposer
    extends Composer<_$AppDatabase, $FreeAreasTable> {
  $$FreeAreasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<double> get offsetMeters => $composableBuilder(
    column: $table.offsetMeters,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$LayersTableAnnotationComposer get layerId {
    final $$LayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.layerId,
      referencedTable: $db.layers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayersTableAnnotationComposer(
            $db: $db,
            $table: $db.layers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> freeAreaPointsRefs<T extends Object>(
    Expression<T> Function($$FreeAreaPointsTableAnnotationComposer a) f,
  ) {
    final $$FreeAreaPointsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.freeAreaPoints,
      getReferencedColumn: (t) => t.freeAreaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FreeAreaPointsTableAnnotationComposer(
            $db: $db,
            $table: $db.freeAreaPoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FreeAreasTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FreeAreasTable,
          FreeArea,
          $$FreeAreasTableFilterComposer,
          $$FreeAreasTableOrderingComposer,
          $$FreeAreasTableAnnotationComposer,
          $$FreeAreasTableCreateCompanionBuilder,
          $$FreeAreasTableUpdateCompanionBuilder,
          (FreeArea, $$FreeAreasTableReferences),
          FreeArea,
          PrefetchHooks Function({bool layerId, bool freeAreaPointsRefs})
        > {
  $$FreeAreasTableTableManager(_$AppDatabase db, $FreeAreasTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FreeAreasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FreeAreasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FreeAreasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> layerId = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<double> offsetMeters = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FreeAreasCompanion(
                id: id,
                layerId: layerId,
                label: label,
                offsetMeters: offsetMeters,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String layerId,
                Value<String?> label = const Value.absent(),
                Value<double> offsetMeters = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FreeAreasCompanion.insert(
                id: id,
                layerId: layerId,
                label: label,
                offsetMeters: offsetMeters,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FreeAreasTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({layerId = false, freeAreaPointsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (freeAreaPointsRefs) db.freeAreaPoints,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (layerId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.layerId,
                                    referencedTable: $$FreeAreasTableReferences
                                        ._layerIdTable(db),
                                    referencedColumn: $$FreeAreasTableReferences
                                        ._layerIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (freeAreaPointsRefs)
                        await $_getPrefetchedData<
                          FreeArea,
                          $FreeAreasTable,
                          FreeAreaPoint
                        >(
                          currentTable: table,
                          referencedTable: $$FreeAreasTableReferences
                              ._freeAreaPointsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FreeAreasTableReferences(
                                db,
                                table,
                                p0,
                              ).freeAreaPointsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.freeAreaId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$FreeAreasTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FreeAreasTable,
      FreeArea,
      $$FreeAreasTableFilterComposer,
      $$FreeAreasTableOrderingComposer,
      $$FreeAreasTableAnnotationComposer,
      $$FreeAreasTableCreateCompanionBuilder,
      $$FreeAreasTableUpdateCompanionBuilder,
      (FreeArea, $$FreeAreasTableReferences),
      FreeArea,
      PrefetchHooks Function({bool layerId, bool freeAreaPointsRefs})
    >;
typedef $$FreeAreaPointsTableCreateCompanionBuilder =
    FreeAreaPointsCompanion Function({
      required String id,
      required String freeAreaId,
      required double lat,
      required double lng,
      required int sortOrder,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$FreeAreaPointsTableUpdateCompanionBuilder =
    FreeAreaPointsCompanion Function({
      Value<String> id,
      Value<String> freeAreaId,
      Value<double> lat,
      Value<double> lng,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$FreeAreaPointsTableReferences
    extends BaseReferences<_$AppDatabase, $FreeAreaPointsTable, FreeAreaPoint> {
  $$FreeAreaPointsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FreeAreasTable _freeAreaIdTable(_$AppDatabase db) =>
      db.freeAreas.createAlias(
        $_aliasNameGenerator(db.freeAreaPoints.freeAreaId, db.freeAreas.id),
      );

  $$FreeAreasTableProcessedTableManager get freeAreaId {
    final $_column = $_itemColumn<String>('free_area_id')!;

    final manager = $$FreeAreasTableTableManager(
      $_db,
      $_db.freeAreas,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_freeAreaIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FreeAreaPointsTableFilterComposer
    extends Composer<_$AppDatabase, $FreeAreaPointsTable> {
  $$FreeAreaPointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$FreeAreasTableFilterComposer get freeAreaId {
    final $$FreeAreasTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.freeAreaId,
      referencedTable: $db.freeAreas,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FreeAreasTableFilterComposer(
            $db: $db,
            $table: $db.freeAreas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FreeAreaPointsTableOrderingComposer
    extends Composer<_$AppDatabase, $FreeAreaPointsTable> {
  $$FreeAreaPointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$FreeAreasTableOrderingComposer get freeAreaId {
    final $$FreeAreasTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.freeAreaId,
      referencedTable: $db.freeAreas,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FreeAreasTableOrderingComposer(
            $db: $db,
            $table: $db.freeAreas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FreeAreaPointsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FreeAreaPointsTable> {
  $$FreeAreaPointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$FreeAreasTableAnnotationComposer get freeAreaId {
    final $$FreeAreasTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.freeAreaId,
      referencedTable: $db.freeAreas,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FreeAreasTableAnnotationComposer(
            $db: $db,
            $table: $db.freeAreas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FreeAreaPointsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FreeAreaPointsTable,
          FreeAreaPoint,
          $$FreeAreaPointsTableFilterComposer,
          $$FreeAreaPointsTableOrderingComposer,
          $$FreeAreaPointsTableAnnotationComposer,
          $$FreeAreaPointsTableCreateCompanionBuilder,
          $$FreeAreaPointsTableUpdateCompanionBuilder,
          (FreeAreaPoint, $$FreeAreaPointsTableReferences),
          FreeAreaPoint,
          PrefetchHooks Function({bool freeAreaId})
        > {
  $$FreeAreaPointsTableTableManager(
    _$AppDatabase db,
    $FreeAreaPointsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FreeAreaPointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FreeAreaPointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FreeAreaPointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> freeAreaId = const Value.absent(),
                Value<double> lat = const Value.absent(),
                Value<double> lng = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FreeAreaPointsCompanion(
                id: id,
                freeAreaId: freeAreaId,
                lat: lat,
                lng: lng,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String freeAreaId,
                required double lat,
                required double lng,
                required int sortOrder,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FreeAreaPointsCompanion.insert(
                id: id,
                freeAreaId: freeAreaId,
                lat: lat,
                lng: lng,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FreeAreaPointsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({freeAreaId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (freeAreaId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.freeAreaId,
                                referencedTable: $$FreeAreaPointsTableReferences
                                    ._freeAreaIdTable(db),
                                referencedColumn:
                                    $$FreeAreaPointsTableReferences
                                        ._freeAreaIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FreeAreaPointsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FreeAreaPointsTable,
      FreeAreaPoint,
      $$FreeAreaPointsTableFilterComposer,
      $$FreeAreaPointsTableOrderingComposer,
      $$FreeAreaPointsTableAnnotationComposer,
      $$FreeAreaPointsTableCreateCompanionBuilder,
      $$FreeAreaPointsTableUpdateCompanionBuilder,
      (FreeAreaPoint, $$FreeAreaPointsTableReferences),
      FreeAreaPoint,
      PrefetchHooks Function({bool freeAreaId})
    >;
typedef $$HeightRegionsTableCreateCompanionBuilder =
    HeightRegionsCompanion Function({
      required String id,
      required String layerId,
      required double centerLat,
      required double centerLng,
      required double radiusMeters,
      Value<double> thresholdMeters,
      Value<bool> aboveThreshold,
      Value<int> sampleZoom,
      Value<String?> label,
      Value<DateTime?> generatedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$HeightRegionsTableUpdateCompanionBuilder =
    HeightRegionsCompanion Function({
      Value<String> id,
      Value<String> layerId,
      Value<double> centerLat,
      Value<double> centerLng,
      Value<double> radiusMeters,
      Value<double> thresholdMeters,
      Value<bool> aboveThreshold,
      Value<int> sampleZoom,
      Value<String?> label,
      Value<DateTime?> generatedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$HeightRegionsTableReferences
    extends BaseReferences<_$AppDatabase, $HeightRegionsTable, HeightRegion> {
  $$HeightRegionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LayersTable _layerIdTable(_$AppDatabase db) => db.layers.createAlias(
    $_aliasNameGenerator(db.heightRegions.layerId, db.layers.id),
  );

  $$LayersTableProcessedTableManager get layerId {
    final $_column = $_itemColumn<String>('layer_id')!;

    final manager = $$LayersTableTableManager(
      $_db,
      $_db.layers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_layerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$HeightPolygonsTable, List<HeightPolygon>>
  _heightPolygonsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.heightPolygons,
    aliasName: $_aliasNameGenerator(
      db.heightRegions.id,
      db.heightPolygons.heightRegionId,
    ),
  );

  $$HeightPolygonsTableProcessedTableManager get heightPolygonsRefs {
    final manager = $$HeightPolygonsTableTableManager(
      $_db,
      $_db.heightPolygons,
    ).filter((f) => f.heightRegionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_heightPolygonsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$HeightRegionsTableFilterComposer
    extends Composer<_$AppDatabase, $HeightRegionsTable> {
  $$HeightRegionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get centerLat => $composableBuilder(
    column: $table.centerLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get centerLng => $composableBuilder(
    column: $table.centerLng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get radiusMeters => $composableBuilder(
    column: $table.radiusMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get thresholdMeters => $composableBuilder(
    column: $table.thresholdMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get aboveThreshold => $composableBuilder(
    column: $table.aboveThreshold,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sampleZoom => $composableBuilder(
    column: $table.sampleZoom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LayersTableFilterComposer get layerId {
    final $$LayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.layerId,
      referencedTable: $db.layers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayersTableFilterComposer(
            $db: $db,
            $table: $db.layers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> heightPolygonsRefs(
    Expression<bool> Function($$HeightPolygonsTableFilterComposer f) f,
  ) {
    final $$HeightPolygonsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.heightPolygons,
      getReferencedColumn: (t) => t.heightRegionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HeightPolygonsTableFilterComposer(
            $db: $db,
            $table: $db.heightPolygons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$HeightRegionsTableOrderingComposer
    extends Composer<_$AppDatabase, $HeightRegionsTable> {
  $$HeightRegionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get centerLat => $composableBuilder(
    column: $table.centerLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get centerLng => $composableBuilder(
    column: $table.centerLng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get radiusMeters => $composableBuilder(
    column: $table.radiusMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get thresholdMeters => $composableBuilder(
    column: $table.thresholdMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get aboveThreshold => $composableBuilder(
    column: $table.aboveThreshold,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sampleZoom => $composableBuilder(
    column: $table.sampleZoom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LayersTableOrderingComposer get layerId {
    final $$LayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.layerId,
      referencedTable: $db.layers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayersTableOrderingComposer(
            $db: $db,
            $table: $db.layers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HeightRegionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HeightRegionsTable> {
  $$HeightRegionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get centerLat =>
      $composableBuilder(column: $table.centerLat, builder: (column) => column);

  GeneratedColumn<double> get centerLng =>
      $composableBuilder(column: $table.centerLng, builder: (column) => column);

  GeneratedColumn<double> get radiusMeters => $composableBuilder(
    column: $table.radiusMeters,
    builder: (column) => column,
  );

  GeneratedColumn<double> get thresholdMeters => $composableBuilder(
    column: $table.thresholdMeters,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get aboveThreshold => $composableBuilder(
    column: $table.aboveThreshold,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sampleZoom => $composableBuilder(
    column: $table.sampleZoom,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$LayersTableAnnotationComposer get layerId {
    final $$LayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.layerId,
      referencedTable: $db.layers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayersTableAnnotationComposer(
            $db: $db,
            $table: $db.layers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> heightPolygonsRefs<T extends Object>(
    Expression<T> Function($$HeightPolygonsTableAnnotationComposer a) f,
  ) {
    final $$HeightPolygonsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.heightPolygons,
      getReferencedColumn: (t) => t.heightRegionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HeightPolygonsTableAnnotationComposer(
            $db: $db,
            $table: $db.heightPolygons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$HeightRegionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HeightRegionsTable,
          HeightRegion,
          $$HeightRegionsTableFilterComposer,
          $$HeightRegionsTableOrderingComposer,
          $$HeightRegionsTableAnnotationComposer,
          $$HeightRegionsTableCreateCompanionBuilder,
          $$HeightRegionsTableUpdateCompanionBuilder,
          (HeightRegion, $$HeightRegionsTableReferences),
          HeightRegion,
          PrefetchHooks Function({bool layerId, bool heightPolygonsRefs})
        > {
  $$HeightRegionsTableTableManager(_$AppDatabase db, $HeightRegionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HeightRegionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HeightRegionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HeightRegionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> layerId = const Value.absent(),
                Value<double> centerLat = const Value.absent(),
                Value<double> centerLng = const Value.absent(),
                Value<double> radiusMeters = const Value.absent(),
                Value<double> thresholdMeters = const Value.absent(),
                Value<bool> aboveThreshold = const Value.absent(),
                Value<int> sampleZoom = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<DateTime?> generatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HeightRegionsCompanion(
                id: id,
                layerId: layerId,
                centerLat: centerLat,
                centerLng: centerLng,
                radiusMeters: radiusMeters,
                thresholdMeters: thresholdMeters,
                aboveThreshold: aboveThreshold,
                sampleZoom: sampleZoom,
                label: label,
                generatedAt: generatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String layerId,
                required double centerLat,
                required double centerLng,
                required double radiusMeters,
                Value<double> thresholdMeters = const Value.absent(),
                Value<bool> aboveThreshold = const Value.absent(),
                Value<int> sampleZoom = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<DateTime?> generatedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HeightRegionsCompanion.insert(
                id: id,
                layerId: layerId,
                centerLat: centerLat,
                centerLng: centerLng,
                radiusMeters: radiusMeters,
                thresholdMeters: thresholdMeters,
                aboveThreshold: aboveThreshold,
                sampleZoom: sampleZoom,
                label: label,
                generatedAt: generatedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$HeightRegionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({layerId = false, heightPolygonsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (heightPolygonsRefs) db.heightPolygons,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (layerId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.layerId,
                                    referencedTable:
                                        $$HeightRegionsTableReferences
                                            ._layerIdTable(db),
                                    referencedColumn:
                                        $$HeightRegionsTableReferences
                                            ._layerIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (heightPolygonsRefs)
                        await $_getPrefetchedData<
                          HeightRegion,
                          $HeightRegionsTable,
                          HeightPolygon
                        >(
                          currentTable: table,
                          referencedTable: $$HeightRegionsTableReferences
                              ._heightPolygonsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$HeightRegionsTableReferences(
                                db,
                                table,
                                p0,
                              ).heightPolygonsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.heightRegionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$HeightRegionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HeightRegionsTable,
      HeightRegion,
      $$HeightRegionsTableFilterComposer,
      $$HeightRegionsTableOrderingComposer,
      $$HeightRegionsTableAnnotationComposer,
      $$HeightRegionsTableCreateCompanionBuilder,
      $$HeightRegionsTableUpdateCompanionBuilder,
      (HeightRegion, $$HeightRegionsTableReferences),
      HeightRegion,
      PrefetchHooks Function({bool layerId, bool heightPolygonsRefs})
    >;
typedef $$HeightPolygonsTableCreateCompanionBuilder =
    HeightPolygonsCompanion Function({
      required String id,
      required String heightRegionId,
      required int sortOrder,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$HeightPolygonsTableUpdateCompanionBuilder =
    HeightPolygonsCompanion Function({
      Value<String> id,
      Value<String> heightRegionId,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$HeightPolygonsTableReferences
    extends BaseReferences<_$AppDatabase, $HeightPolygonsTable, HeightPolygon> {
  $$HeightPolygonsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $HeightRegionsTable _heightRegionIdTable(_$AppDatabase db) =>
      db.heightRegions.createAlias(
        $_aliasNameGenerator(
          db.heightPolygons.heightRegionId,
          db.heightRegions.id,
        ),
      );

  $$HeightRegionsTableProcessedTableManager get heightRegionId {
    final $_column = $_itemColumn<String>('height_region_id')!;

    final manager = $$HeightRegionsTableTableManager(
      $_db,
      $_db.heightRegions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_heightRegionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $HeightPolygonPointsTable,
    List<HeightPolygonPoint>
  >
  _heightPolygonPointsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.heightPolygonPoints,
        aliasName: $_aliasNameGenerator(
          db.heightPolygons.id,
          db.heightPolygonPoints.polygonId,
        ),
      );

  $$HeightPolygonPointsTableProcessedTableManager get heightPolygonPointsRefs {
    final manager = $$HeightPolygonPointsTableTableManager(
      $_db,
      $_db.heightPolygonPoints,
    ).filter((f) => f.polygonId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _heightPolygonPointsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$HeightPolygonsTableFilterComposer
    extends Composer<_$AppDatabase, $HeightPolygonsTable> {
  $$HeightPolygonsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$HeightRegionsTableFilterComposer get heightRegionId {
    final $$HeightRegionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.heightRegionId,
      referencedTable: $db.heightRegions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HeightRegionsTableFilterComposer(
            $db: $db,
            $table: $db.heightRegions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> heightPolygonPointsRefs(
    Expression<bool> Function($$HeightPolygonPointsTableFilterComposer f) f,
  ) {
    final $$HeightPolygonPointsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.heightPolygonPoints,
      getReferencedColumn: (t) => t.polygonId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HeightPolygonPointsTableFilterComposer(
            $db: $db,
            $table: $db.heightPolygonPoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$HeightPolygonsTableOrderingComposer
    extends Composer<_$AppDatabase, $HeightPolygonsTable> {
  $$HeightPolygonsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$HeightRegionsTableOrderingComposer get heightRegionId {
    final $$HeightRegionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.heightRegionId,
      referencedTable: $db.heightRegions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HeightRegionsTableOrderingComposer(
            $db: $db,
            $table: $db.heightRegions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HeightPolygonsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HeightPolygonsTable> {
  $$HeightPolygonsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$HeightRegionsTableAnnotationComposer get heightRegionId {
    final $$HeightRegionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.heightRegionId,
      referencedTable: $db.heightRegions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HeightRegionsTableAnnotationComposer(
            $db: $db,
            $table: $db.heightRegions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> heightPolygonPointsRefs<T extends Object>(
    Expression<T> Function($$HeightPolygonPointsTableAnnotationComposer a) f,
  ) {
    final $$HeightPolygonPointsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.heightPolygonPoints,
          getReferencedColumn: (t) => t.polygonId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$HeightPolygonPointsTableAnnotationComposer(
                $db: $db,
                $table: $db.heightPolygonPoints,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$HeightPolygonsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HeightPolygonsTable,
          HeightPolygon,
          $$HeightPolygonsTableFilterComposer,
          $$HeightPolygonsTableOrderingComposer,
          $$HeightPolygonsTableAnnotationComposer,
          $$HeightPolygonsTableCreateCompanionBuilder,
          $$HeightPolygonsTableUpdateCompanionBuilder,
          (HeightPolygon, $$HeightPolygonsTableReferences),
          HeightPolygon,
          PrefetchHooks Function({
            bool heightRegionId,
            bool heightPolygonPointsRefs,
          })
        > {
  $$HeightPolygonsTableTableManager(
    _$AppDatabase db,
    $HeightPolygonsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HeightPolygonsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HeightPolygonsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HeightPolygonsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> heightRegionId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HeightPolygonsCompanion(
                id: id,
                heightRegionId: heightRegionId,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String heightRegionId,
                required int sortOrder,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HeightPolygonsCompanion.insert(
                id: id,
                heightRegionId: heightRegionId,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$HeightPolygonsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({heightRegionId = false, heightPolygonPointsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (heightPolygonPointsRefs) db.heightPolygonPoints,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (heightRegionId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.heightRegionId,
                                    referencedTable:
                                        $$HeightPolygonsTableReferences
                                            ._heightRegionIdTable(db),
                                    referencedColumn:
                                        $$HeightPolygonsTableReferences
                                            ._heightRegionIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (heightPolygonPointsRefs)
                        await $_getPrefetchedData<
                          HeightPolygon,
                          $HeightPolygonsTable,
                          HeightPolygonPoint
                        >(
                          currentTable: table,
                          referencedTable: $$HeightPolygonsTableReferences
                              ._heightPolygonPointsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$HeightPolygonsTableReferences(
                                db,
                                table,
                                p0,
                              ).heightPolygonPointsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.polygonId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$HeightPolygonsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HeightPolygonsTable,
      HeightPolygon,
      $$HeightPolygonsTableFilterComposer,
      $$HeightPolygonsTableOrderingComposer,
      $$HeightPolygonsTableAnnotationComposer,
      $$HeightPolygonsTableCreateCompanionBuilder,
      $$HeightPolygonsTableUpdateCompanionBuilder,
      (HeightPolygon, $$HeightPolygonsTableReferences),
      HeightPolygon,
      PrefetchHooks Function({
        bool heightRegionId,
        bool heightPolygonPointsRefs,
      })
    >;
typedef $$HeightPolygonPointsTableCreateCompanionBuilder =
    HeightPolygonPointsCompanion Function({
      required String id,
      required String polygonId,
      required double lat,
      required double lng,
      required int sortOrder,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$HeightPolygonPointsTableUpdateCompanionBuilder =
    HeightPolygonPointsCompanion Function({
      Value<String> id,
      Value<String> polygonId,
      Value<double> lat,
      Value<double> lng,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$HeightPolygonPointsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $HeightPolygonPointsTable,
          HeightPolygonPoint
        > {
  $$HeightPolygonPointsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $HeightPolygonsTable _polygonIdTable(_$AppDatabase db) =>
      db.heightPolygons.createAlias(
        $_aliasNameGenerator(
          db.heightPolygonPoints.polygonId,
          db.heightPolygons.id,
        ),
      );

  $$HeightPolygonsTableProcessedTableManager get polygonId {
    final $_column = $_itemColumn<String>('polygon_id')!;

    final manager = $$HeightPolygonsTableTableManager(
      $_db,
      $_db.heightPolygons,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_polygonIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$HeightPolygonPointsTableFilterComposer
    extends Composer<_$AppDatabase, $HeightPolygonPointsTable> {
  $$HeightPolygonPointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$HeightPolygonsTableFilterComposer get polygonId {
    final $$HeightPolygonsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.polygonId,
      referencedTable: $db.heightPolygons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HeightPolygonsTableFilterComposer(
            $db: $db,
            $table: $db.heightPolygons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HeightPolygonPointsTableOrderingComposer
    extends Composer<_$AppDatabase, $HeightPolygonPointsTable> {
  $$HeightPolygonPointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$HeightPolygonsTableOrderingComposer get polygonId {
    final $$HeightPolygonsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.polygonId,
      referencedTable: $db.heightPolygons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HeightPolygonsTableOrderingComposer(
            $db: $db,
            $table: $db.heightPolygons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HeightPolygonPointsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HeightPolygonPointsTable> {
  $$HeightPolygonPointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$HeightPolygonsTableAnnotationComposer get polygonId {
    final $$HeightPolygonsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.polygonId,
      referencedTable: $db.heightPolygons,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HeightPolygonsTableAnnotationComposer(
            $db: $db,
            $table: $db.heightPolygons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HeightPolygonPointsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HeightPolygonPointsTable,
          HeightPolygonPoint,
          $$HeightPolygonPointsTableFilterComposer,
          $$HeightPolygonPointsTableOrderingComposer,
          $$HeightPolygonPointsTableAnnotationComposer,
          $$HeightPolygonPointsTableCreateCompanionBuilder,
          $$HeightPolygonPointsTableUpdateCompanionBuilder,
          (HeightPolygonPoint, $$HeightPolygonPointsTableReferences),
          HeightPolygonPoint,
          PrefetchHooks Function({bool polygonId})
        > {
  $$HeightPolygonPointsTableTableManager(
    _$AppDatabase db,
    $HeightPolygonPointsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HeightPolygonPointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HeightPolygonPointsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$HeightPolygonPointsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> polygonId = const Value.absent(),
                Value<double> lat = const Value.absent(),
                Value<double> lng = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HeightPolygonPointsCompanion(
                id: id,
                polygonId: polygonId,
                lat: lat,
                lng: lng,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String polygonId,
                required double lat,
                required double lng,
                required int sortOrder,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HeightPolygonPointsCompanion.insert(
                id: id,
                polygonId: polygonId,
                lat: lat,
                lng: lng,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$HeightPolygonPointsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({polygonId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (polygonId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.polygonId,
                                referencedTable:
                                    $$HeightPolygonPointsTableReferences
                                        ._polygonIdTable(db),
                                referencedColumn:
                                    $$HeightPolygonPointsTableReferences
                                        ._polygonIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$HeightPolygonPointsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HeightPolygonPointsTable,
      HeightPolygonPoint,
      $$HeightPolygonPointsTableFilterComposer,
      $$HeightPolygonPointsTableOrderingComposer,
      $$HeightPolygonPointsTableAnnotationComposer,
      $$HeightPolygonPointsTableCreateCompanionBuilder,
      $$HeightPolygonPointsTableUpdateCompanionBuilder,
      (HeightPolygonPoint, $$HeightPolygonPointsTableReferences),
      HeightPolygonPoint,
      PrefetchHooks Function({bool polygonId})
    >;
typedef $$PoiSetsTableCreateCompanionBuilder =
    PoiSetsCompanion Function({
      required String id,
      required String layerId,
      required String categoryKey,
      required double centerLat,
      required double centerLng,
      required double radiusMeters,
      Value<String?> label,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$PoiSetsTableUpdateCompanionBuilder =
    PoiSetsCompanion Function({
      Value<String> id,
      Value<String> layerId,
      Value<String> categoryKey,
      Value<double> centerLat,
      Value<double> centerLng,
      Value<double> radiusMeters,
      Value<String?> label,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$PoiSetsTableReferences
    extends BaseReferences<_$AppDatabase, $PoiSetsTable, PoiSet> {
  $$PoiSetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LayersTable _layerIdTable(_$AppDatabase db) => db.layers.createAlias(
    $_aliasNameGenerator(db.poiSets.layerId, db.layers.id),
  );

  $$LayersTableProcessedTableManager get layerId {
    final $_column = $_itemColumn<String>('layer_id')!;

    final manager = $$LayersTableTableManager(
      $_db,
      $_db.layers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_layerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PoiPointsTable, List<PoiPoint>>
  _poiPointsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.poiPoints,
    aliasName: $_aliasNameGenerator(db.poiSets.id, db.poiPoints.poiSetId),
  );

  $$PoiPointsTableProcessedTableManager get poiPointsRefs {
    final manager = $$PoiPointsTableTableManager(
      $_db,
      $_db.poiPoints,
    ).filter((f) => f.poiSetId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_poiPointsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PoiSetsTableFilterComposer
    extends Composer<_$AppDatabase, $PoiSetsTable> {
  $$PoiSetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryKey => $composableBuilder(
    column: $table.categoryKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get centerLat => $composableBuilder(
    column: $table.centerLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get centerLng => $composableBuilder(
    column: $table.centerLng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get radiusMeters => $composableBuilder(
    column: $table.radiusMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LayersTableFilterComposer get layerId {
    final $$LayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.layerId,
      referencedTable: $db.layers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayersTableFilterComposer(
            $db: $db,
            $table: $db.layers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> poiPointsRefs(
    Expression<bool> Function($$PoiPointsTableFilterComposer f) f,
  ) {
    final $$PoiPointsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.poiPoints,
      getReferencedColumn: (t) => t.poiSetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoiPointsTableFilterComposer(
            $db: $db,
            $table: $db.poiPoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PoiSetsTableOrderingComposer
    extends Composer<_$AppDatabase, $PoiSetsTable> {
  $$PoiSetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryKey => $composableBuilder(
    column: $table.categoryKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get centerLat => $composableBuilder(
    column: $table.centerLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get centerLng => $composableBuilder(
    column: $table.centerLng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get radiusMeters => $composableBuilder(
    column: $table.radiusMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LayersTableOrderingComposer get layerId {
    final $$LayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.layerId,
      referencedTable: $db.layers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayersTableOrderingComposer(
            $db: $db,
            $table: $db.layers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PoiSetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PoiSetsTable> {
  $$PoiSetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get categoryKey => $composableBuilder(
    column: $table.categoryKey,
    builder: (column) => column,
  );

  GeneratedColumn<double> get centerLat =>
      $composableBuilder(column: $table.centerLat, builder: (column) => column);

  GeneratedColumn<double> get centerLng =>
      $composableBuilder(column: $table.centerLng, builder: (column) => column);

  GeneratedColumn<double> get radiusMeters => $composableBuilder(
    column: $table.radiusMeters,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$LayersTableAnnotationComposer get layerId {
    final $$LayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.layerId,
      referencedTable: $db.layers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayersTableAnnotationComposer(
            $db: $db,
            $table: $db.layers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> poiPointsRefs<T extends Object>(
    Expression<T> Function($$PoiPointsTableAnnotationComposer a) f,
  ) {
    final $$PoiPointsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.poiPoints,
      getReferencedColumn: (t) => t.poiSetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoiPointsTableAnnotationComposer(
            $db: $db,
            $table: $db.poiPoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PoiSetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PoiSetsTable,
          PoiSet,
          $$PoiSetsTableFilterComposer,
          $$PoiSetsTableOrderingComposer,
          $$PoiSetsTableAnnotationComposer,
          $$PoiSetsTableCreateCompanionBuilder,
          $$PoiSetsTableUpdateCompanionBuilder,
          (PoiSet, $$PoiSetsTableReferences),
          PoiSet,
          PrefetchHooks Function({bool layerId, bool poiPointsRefs})
        > {
  $$PoiSetsTableTableManager(_$AppDatabase db, $PoiSetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PoiSetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PoiSetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PoiSetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> layerId = const Value.absent(),
                Value<String> categoryKey = const Value.absent(),
                Value<double> centerLat = const Value.absent(),
                Value<double> centerLng = const Value.absent(),
                Value<double> radiusMeters = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PoiSetsCompanion(
                id: id,
                layerId: layerId,
                categoryKey: categoryKey,
                centerLat: centerLat,
                centerLng: centerLng,
                radiusMeters: radiusMeters,
                label: label,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String layerId,
                required String categoryKey,
                required double centerLat,
                required double centerLng,
                required double radiusMeters,
                Value<String?> label = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PoiSetsCompanion.insert(
                id: id,
                layerId: layerId,
                categoryKey: categoryKey,
                centerLat: centerLat,
                centerLng: centerLng,
                radiusMeters: radiusMeters,
                label: label,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PoiSetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({layerId = false, poiPointsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (poiPointsRefs) db.poiPoints],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (layerId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.layerId,
                                referencedTable: $$PoiSetsTableReferences
                                    ._layerIdTable(db),
                                referencedColumn: $$PoiSetsTableReferences
                                    ._layerIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (poiPointsRefs)
                    await $_getPrefetchedData<PoiSet, $PoiSetsTable, PoiPoint>(
                      currentTable: table,
                      referencedTable: $$PoiSetsTableReferences
                          ._poiPointsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PoiSetsTableReferences(db, table, p0).poiPointsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.poiSetId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PoiSetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PoiSetsTable,
      PoiSet,
      $$PoiSetsTableFilterComposer,
      $$PoiSetsTableOrderingComposer,
      $$PoiSetsTableAnnotationComposer,
      $$PoiSetsTableCreateCompanionBuilder,
      $$PoiSetsTableUpdateCompanionBuilder,
      (PoiSet, $$PoiSetsTableReferences),
      PoiSet,
      PrefetchHooks Function({bool layerId, bool poiPointsRefs})
    >;
typedef $$PoiPointsTableCreateCompanionBuilder =
    PoiPointsCompanion Function({
      required String id,
      required String poiSetId,
      required double lat,
      required double lng,
      Value<String?> name,
      required int sortOrder,
      Value<DateTime> createdAt,
      Value<String?> osmType,
      Value<int?> osmId,
      Value<int> rowid,
    });
typedef $$PoiPointsTableUpdateCompanionBuilder =
    PoiPointsCompanion Function({
      Value<String> id,
      Value<String> poiSetId,
      Value<double> lat,
      Value<double> lng,
      Value<String?> name,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<String?> osmType,
      Value<int?> osmId,
      Value<int> rowid,
    });

final class $$PoiPointsTableReferences
    extends BaseReferences<_$AppDatabase, $PoiPointsTable, PoiPoint> {
  $$PoiPointsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PoiSetsTable _poiSetIdTable(_$AppDatabase db) => db.poiSets
      .createAlias($_aliasNameGenerator(db.poiPoints.poiSetId, db.poiSets.id));

  $$PoiSetsTableProcessedTableManager get poiSetId {
    final $_column = $_itemColumn<String>('poi_set_id')!;

    final manager = $$PoiSetsTableTableManager(
      $_db,
      $_db.poiSets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_poiSetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PoiPointsTableFilterComposer
    extends Composer<_$AppDatabase, $PoiPointsTable> {
  $$PoiPointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get osmType => $composableBuilder(
    column: $table.osmType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get osmId => $composableBuilder(
    column: $table.osmId,
    builder: (column) => ColumnFilters(column),
  );

  $$PoiSetsTableFilterComposer get poiSetId {
    final $$PoiSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.poiSetId,
      referencedTable: $db.poiSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoiSetsTableFilterComposer(
            $db: $db,
            $table: $db.poiSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PoiPointsTableOrderingComposer
    extends Composer<_$AppDatabase, $PoiPointsTable> {
  $$PoiPointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get osmType => $composableBuilder(
    column: $table.osmType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get osmId => $composableBuilder(
    column: $table.osmId,
    builder: (column) => ColumnOrderings(column),
  );

  $$PoiSetsTableOrderingComposer get poiSetId {
    final $$PoiSetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.poiSetId,
      referencedTable: $db.poiSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoiSetsTableOrderingComposer(
            $db: $db,
            $table: $db.poiSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PoiPointsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PoiPointsTable> {
  $$PoiPointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get osmType =>
      $composableBuilder(column: $table.osmType, builder: (column) => column);

  GeneratedColumn<int> get osmId =>
      $composableBuilder(column: $table.osmId, builder: (column) => column);

  $$PoiSetsTableAnnotationComposer get poiSetId {
    final $$PoiSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.poiSetId,
      referencedTable: $db.poiSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PoiSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.poiSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PoiPointsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PoiPointsTable,
          PoiPoint,
          $$PoiPointsTableFilterComposer,
          $$PoiPointsTableOrderingComposer,
          $$PoiPointsTableAnnotationComposer,
          $$PoiPointsTableCreateCompanionBuilder,
          $$PoiPointsTableUpdateCompanionBuilder,
          (PoiPoint, $$PoiPointsTableReferences),
          PoiPoint,
          PrefetchHooks Function({bool poiSetId})
        > {
  $$PoiPointsTableTableManager(_$AppDatabase db, $PoiPointsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PoiPointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PoiPointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PoiPointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> poiSetId = const Value.absent(),
                Value<double> lat = const Value.absent(),
                Value<double> lng = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> osmType = const Value.absent(),
                Value<int?> osmId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PoiPointsCompanion(
                id: id,
                poiSetId: poiSetId,
                lat: lat,
                lng: lng,
                name: name,
                sortOrder: sortOrder,
                createdAt: createdAt,
                osmType: osmType,
                osmId: osmId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String poiSetId,
                required double lat,
                required double lng,
                Value<String?> name = const Value.absent(),
                required int sortOrder,
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> osmType = const Value.absent(),
                Value<int?> osmId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PoiPointsCompanion.insert(
                id: id,
                poiSetId: poiSetId,
                lat: lat,
                lng: lng,
                name: name,
                sortOrder: sortOrder,
                createdAt: createdAt,
                osmType: osmType,
                osmId: osmId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PoiPointsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({poiSetId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (poiSetId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.poiSetId,
                                referencedTable: $$PoiPointsTableReferences
                                    ._poiSetIdTable(db),
                                referencedColumn: $$PoiPointsTableReferences
                                    ._poiSetIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PoiPointsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PoiPointsTable,
      PoiPoint,
      $$PoiPointsTableFilterComposer,
      $$PoiPointsTableOrderingComposer,
      $$PoiPointsTableAnnotationComposer,
      $$PoiPointsTableCreateCompanionBuilder,
      $$PoiPointsTableUpdateCompanionBuilder,
      (PoiPoint, $$PoiPointsTableReferences),
      PoiPoint,
      PrefetchHooks Function({bool poiSetId})
    >;
typedef $$TransitSetsTableCreateCompanionBuilder =
    TransitSetsCompanion Function({
      required String id,
      required String layerId,
      required double south,
      required double west,
      required double north,
      required double east,
      required int modeMask,
      Value<int> visibleModeMask,
      Value<String?> label,
      Value<DateTime?> fetchedAt,
      Value<String?> lastError,
      Value<int> stationCount,
      Value<int> nodeCount,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$TransitSetsTableUpdateCompanionBuilder =
    TransitSetsCompanion Function({
      Value<String> id,
      Value<String> layerId,
      Value<double> south,
      Value<double> west,
      Value<double> north,
      Value<double> east,
      Value<int> modeMask,
      Value<int> visibleModeMask,
      Value<String?> label,
      Value<DateTime?> fetchedAt,
      Value<String?> lastError,
      Value<int> stationCount,
      Value<int> nodeCount,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$TransitSetsTableReferences
    extends BaseReferences<_$AppDatabase, $TransitSetsTable, TransitSet> {
  $$TransitSetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LayersTable _layerIdTable(_$AppDatabase db) => db.layers.createAlias(
    $_aliasNameGenerator(db.transitSets.layerId, db.layers.id),
  );

  $$LayersTableProcessedTableManager get layerId {
    final $_column = $_itemColumn<String>('layer_id')!;

    final manager = $$LayersTableTableManager(
      $_db,
      $_db.layers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_layerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TransitStopsTable, List<TransitStop>>
  _transitStopsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transitStops,
    aliasName: $_aliasNameGenerator(db.transitSets.id, db.transitStops.setId),
  );

  $$TransitStopsTableProcessedTableManager get transitStopsRefs {
    final manager = $$TransitStopsTableTableManager(
      $_db,
      $_db.transitStops,
    ).filter((f) => f.setId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_transitStopsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TransitSetsTableFilterComposer
    extends Composer<_$AppDatabase, $TransitSetsTable> {
  $$TransitSetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get south => $composableBuilder(
    column: $table.south,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get west => $composableBuilder(
    column: $table.west,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get north => $composableBuilder(
    column: $table.north,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get east => $composableBuilder(
    column: $table.east,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get modeMask => $composableBuilder(
    column: $table.modeMask,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get visibleModeMask => $composableBuilder(
    column: $table.visibleModeMask,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stationCount => $composableBuilder(
    column: $table.stationCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nodeCount => $composableBuilder(
    column: $table.nodeCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LayersTableFilterComposer get layerId {
    final $$LayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.layerId,
      referencedTable: $db.layers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayersTableFilterComposer(
            $db: $db,
            $table: $db.layers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> transitStopsRefs(
    Expression<bool> Function($$TransitStopsTableFilterComposer f) f,
  ) {
    final $$TransitStopsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transitStops,
      getReferencedColumn: (t) => t.setId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransitStopsTableFilterComposer(
            $db: $db,
            $table: $db.transitStops,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TransitSetsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransitSetsTable> {
  $$TransitSetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get south => $composableBuilder(
    column: $table.south,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get west => $composableBuilder(
    column: $table.west,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get north => $composableBuilder(
    column: $table.north,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get east => $composableBuilder(
    column: $table.east,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get modeMask => $composableBuilder(
    column: $table.modeMask,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get visibleModeMask => $composableBuilder(
    column: $table.visibleModeMask,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stationCount => $composableBuilder(
    column: $table.stationCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nodeCount => $composableBuilder(
    column: $table.nodeCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LayersTableOrderingComposer get layerId {
    final $$LayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.layerId,
      referencedTable: $db.layers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayersTableOrderingComposer(
            $db: $db,
            $table: $db.layers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransitSetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransitSetsTable> {
  $$TransitSetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get south =>
      $composableBuilder(column: $table.south, builder: (column) => column);

  GeneratedColumn<double> get west =>
      $composableBuilder(column: $table.west, builder: (column) => column);

  GeneratedColumn<double> get north =>
      $composableBuilder(column: $table.north, builder: (column) => column);

  GeneratedColumn<double> get east =>
      $composableBuilder(column: $table.east, builder: (column) => column);

  GeneratedColumn<int> get modeMask =>
      $composableBuilder(column: $table.modeMask, builder: (column) => column);

  GeneratedColumn<int> get visibleModeMask => $composableBuilder(
    column: $table.visibleModeMask,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<int> get stationCount => $composableBuilder(
    column: $table.stationCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nodeCount =>
      $composableBuilder(column: $table.nodeCount, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$LayersTableAnnotationComposer get layerId {
    final $$LayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.layerId,
      referencedTable: $db.layers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayersTableAnnotationComposer(
            $db: $db,
            $table: $db.layers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> transitStopsRefs<T extends Object>(
    Expression<T> Function($$TransitStopsTableAnnotationComposer a) f,
  ) {
    final $$TransitStopsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transitStops,
      getReferencedColumn: (t) => t.setId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransitStopsTableAnnotationComposer(
            $db: $db,
            $table: $db.transitStops,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TransitSetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransitSetsTable,
          TransitSet,
          $$TransitSetsTableFilterComposer,
          $$TransitSetsTableOrderingComposer,
          $$TransitSetsTableAnnotationComposer,
          $$TransitSetsTableCreateCompanionBuilder,
          $$TransitSetsTableUpdateCompanionBuilder,
          (TransitSet, $$TransitSetsTableReferences),
          TransitSet,
          PrefetchHooks Function({bool layerId, bool transitStopsRefs})
        > {
  $$TransitSetsTableTableManager(_$AppDatabase db, $TransitSetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransitSetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransitSetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransitSetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> layerId = const Value.absent(),
                Value<double> south = const Value.absent(),
                Value<double> west = const Value.absent(),
                Value<double> north = const Value.absent(),
                Value<double> east = const Value.absent(),
                Value<int> modeMask = const Value.absent(),
                Value<int> visibleModeMask = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<DateTime?> fetchedAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> stationCount = const Value.absent(),
                Value<int> nodeCount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransitSetsCompanion(
                id: id,
                layerId: layerId,
                south: south,
                west: west,
                north: north,
                east: east,
                modeMask: modeMask,
                visibleModeMask: visibleModeMask,
                label: label,
                fetchedAt: fetchedAt,
                lastError: lastError,
                stationCount: stationCount,
                nodeCount: nodeCount,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String layerId,
                required double south,
                required double west,
                required double north,
                required double east,
                required int modeMask,
                Value<int> visibleModeMask = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<DateTime?> fetchedAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> stationCount = const Value.absent(),
                Value<int> nodeCount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransitSetsCompanion.insert(
                id: id,
                layerId: layerId,
                south: south,
                west: west,
                north: north,
                east: east,
                modeMask: modeMask,
                visibleModeMask: visibleModeMask,
                label: label,
                fetchedAt: fetchedAt,
                lastError: lastError,
                stationCount: stationCount,
                nodeCount: nodeCount,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TransitSetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({layerId = false, transitStopsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (transitStopsRefs) db.transitStops],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (layerId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.layerId,
                                referencedTable: $$TransitSetsTableReferences
                                    ._layerIdTable(db),
                                referencedColumn: $$TransitSetsTableReferences
                                    ._layerIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (transitStopsRefs)
                    await $_getPrefetchedData<
                      TransitSet,
                      $TransitSetsTable,
                      TransitStop
                    >(
                      currentTable: table,
                      referencedTable: $$TransitSetsTableReferences
                          ._transitStopsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TransitSetsTableReferences(
                            db,
                            table,
                            p0,
                          ).transitStopsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.setId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TransitSetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransitSetsTable,
      TransitSet,
      $$TransitSetsTableFilterComposer,
      $$TransitSetsTableOrderingComposer,
      $$TransitSetsTableAnnotationComposer,
      $$TransitSetsTableCreateCompanionBuilder,
      $$TransitSetsTableUpdateCompanionBuilder,
      (TransitSet, $$TransitSetsTableReferences),
      TransitSet,
      PrefetchHooks Function({bool layerId, bool transitStopsRefs})
    >;
typedef $$TransitStopsTableCreateCompanionBuilder =
    TransitStopsCompanion Function({
      required String id,
      required String setId,
      required int osmId,
      required double lat,
      required double lng,
      Value<String?> name,
      Value<int> modeMask,
      Value<int> nodeCount,
      Value<String?> routeRef,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$TransitStopsTableUpdateCompanionBuilder =
    TransitStopsCompanion Function({
      Value<String> id,
      Value<String> setId,
      Value<int> osmId,
      Value<double> lat,
      Value<double> lng,
      Value<String?> name,
      Value<int> modeMask,
      Value<int> nodeCount,
      Value<String?> routeRef,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$TransitStopsTableReferences
    extends BaseReferences<_$AppDatabase, $TransitStopsTable, TransitStop> {
  $$TransitStopsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TransitSetsTable _setIdTable(_$AppDatabase db) =>
      db.transitSets.createAlias(
        $_aliasNameGenerator(db.transitStops.setId, db.transitSets.id),
      );

  $$TransitSetsTableProcessedTableManager get setId {
    final $_column = $_itemColumn<String>('set_id')!;

    final manager = $$TransitSetsTableTableManager(
      $_db,
      $_db.transitSets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_setIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TransitStopsTableFilterComposer
    extends Composer<_$AppDatabase, $TransitStopsTable> {
  $$TransitStopsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get osmId => $composableBuilder(
    column: $table.osmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get modeMask => $composableBuilder(
    column: $table.modeMask,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nodeCount => $composableBuilder(
    column: $table.nodeCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get routeRef => $composableBuilder(
    column: $table.routeRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TransitSetsTableFilterComposer get setId {
    final $$TransitSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.transitSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransitSetsTableFilterComposer(
            $db: $db,
            $table: $db.transitSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransitStopsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransitStopsTable> {
  $$TransitStopsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get osmId => $composableBuilder(
    column: $table.osmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get modeMask => $composableBuilder(
    column: $table.modeMask,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nodeCount => $composableBuilder(
    column: $table.nodeCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get routeRef => $composableBuilder(
    column: $table.routeRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TransitSetsTableOrderingComposer get setId {
    final $$TransitSetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.transitSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransitSetsTableOrderingComposer(
            $db: $db,
            $table: $db.transitSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransitStopsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransitStopsTable> {
  $$TransitStopsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get osmId =>
      $composableBuilder(column: $table.osmId, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get modeMask =>
      $composableBuilder(column: $table.modeMask, builder: (column) => column);

  GeneratedColumn<int> get nodeCount =>
      $composableBuilder(column: $table.nodeCount, builder: (column) => column);

  GeneratedColumn<String> get routeRef =>
      $composableBuilder(column: $table.routeRef, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$TransitSetsTableAnnotationComposer get setId {
    final $$TransitSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.transitSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransitSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.transitSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransitStopsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransitStopsTable,
          TransitStop,
          $$TransitStopsTableFilterComposer,
          $$TransitStopsTableOrderingComposer,
          $$TransitStopsTableAnnotationComposer,
          $$TransitStopsTableCreateCompanionBuilder,
          $$TransitStopsTableUpdateCompanionBuilder,
          (TransitStop, $$TransitStopsTableReferences),
          TransitStop,
          PrefetchHooks Function({bool setId})
        > {
  $$TransitStopsTableTableManager(_$AppDatabase db, $TransitStopsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransitStopsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransitStopsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransitStopsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> setId = const Value.absent(),
                Value<int> osmId = const Value.absent(),
                Value<double> lat = const Value.absent(),
                Value<double> lng = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<int> modeMask = const Value.absent(),
                Value<int> nodeCount = const Value.absent(),
                Value<String?> routeRef = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransitStopsCompanion(
                id: id,
                setId: setId,
                osmId: osmId,
                lat: lat,
                lng: lng,
                name: name,
                modeMask: modeMask,
                nodeCount: nodeCount,
                routeRef: routeRef,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String setId,
                required int osmId,
                required double lat,
                required double lng,
                Value<String?> name = const Value.absent(),
                Value<int> modeMask = const Value.absent(),
                Value<int> nodeCount = const Value.absent(),
                Value<String?> routeRef = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransitStopsCompanion.insert(
                id: id,
                setId: setId,
                osmId: osmId,
                lat: lat,
                lng: lng,
                name: name,
                modeMask: modeMask,
                nodeCount: nodeCount,
                routeRef: routeRef,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TransitStopsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({setId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (setId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.setId,
                                referencedTable: $$TransitStopsTableReferences
                                    ._setIdTable(db),
                                referencedColumn: $$TransitStopsTableReferences
                                    ._setIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TransitStopsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransitStopsTable,
      TransitStop,
      $$TransitStopsTableFilterComposer,
      $$TransitStopsTableOrderingComposer,
      $$TransitStopsTableAnnotationComposer,
      $$TransitStopsTableCreateCompanionBuilder,
      $$TransitStopsTableUpdateCompanionBuilder,
      (TransitStop, $$TransitStopsTableReferences),
      TransitStop,
      PrefetchHooks Function({bool setId})
    >;
typedef $$BorderSetsTableCreateCompanionBuilder =
    BorderSetsCompanion Function({
      required String id,
      required String layerId,
      required double south,
      required double west,
      required double north,
      required double east,
      required String adminLevel,
      Value<String?> label,
      required DateTime fetchedAt,
      Value<int> areaCount,
      Value<int> pointCount,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$BorderSetsTableUpdateCompanionBuilder =
    BorderSetsCompanion Function({
      Value<String> id,
      Value<String> layerId,
      Value<double> south,
      Value<double> west,
      Value<double> north,
      Value<double> east,
      Value<String> adminLevel,
      Value<String?> label,
      Value<DateTime> fetchedAt,
      Value<int> areaCount,
      Value<int> pointCount,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$BorderSetsTableReferences
    extends BaseReferences<_$AppDatabase, $BorderSetsTable, BorderSet> {
  $$BorderSetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LayersTable _layerIdTable(_$AppDatabase db) => db.layers.createAlias(
    $_aliasNameGenerator(db.borderSets.layerId, db.layers.id),
  );

  $$LayersTableProcessedTableManager get layerId {
    final $_column = $_itemColumn<String>('layer_id')!;

    final manager = $$LayersTableTableManager(
      $_db,
      $_db.layers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_layerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$BorderAreasTable, List<BorderArea>>
  _borderAreasRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.borderAreas,
    aliasName: $_aliasNameGenerator(db.borderSets.id, db.borderAreas.setId),
  );

  $$BorderAreasTableProcessedTableManager get borderAreasRefs {
    final manager = $$BorderAreasTableTableManager(
      $_db,
      $_db.borderAreas,
    ).filter((f) => f.setId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_borderAreasRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BorderSetsTableFilterComposer
    extends Composer<_$AppDatabase, $BorderSetsTable> {
  $$BorderSetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get south => $composableBuilder(
    column: $table.south,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get west => $composableBuilder(
    column: $table.west,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get north => $composableBuilder(
    column: $table.north,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get east => $composableBuilder(
    column: $table.east,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get adminLevel => $composableBuilder(
    column: $table.adminLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get areaCount => $composableBuilder(
    column: $table.areaCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pointCount => $composableBuilder(
    column: $table.pointCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LayersTableFilterComposer get layerId {
    final $$LayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.layerId,
      referencedTable: $db.layers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayersTableFilterComposer(
            $db: $db,
            $table: $db.layers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> borderAreasRefs(
    Expression<bool> Function($$BorderAreasTableFilterComposer f) f,
  ) {
    final $$BorderAreasTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.borderAreas,
      getReferencedColumn: (t) => t.setId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BorderAreasTableFilterComposer(
            $db: $db,
            $table: $db.borderAreas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BorderSetsTableOrderingComposer
    extends Composer<_$AppDatabase, $BorderSetsTable> {
  $$BorderSetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get south => $composableBuilder(
    column: $table.south,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get west => $composableBuilder(
    column: $table.west,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get north => $composableBuilder(
    column: $table.north,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get east => $composableBuilder(
    column: $table.east,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get adminLevel => $composableBuilder(
    column: $table.adminLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get areaCount => $composableBuilder(
    column: $table.areaCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pointCount => $composableBuilder(
    column: $table.pointCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LayersTableOrderingComposer get layerId {
    final $$LayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.layerId,
      referencedTable: $db.layers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayersTableOrderingComposer(
            $db: $db,
            $table: $db.layers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BorderSetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BorderSetsTable> {
  $$BorderSetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get south =>
      $composableBuilder(column: $table.south, builder: (column) => column);

  GeneratedColumn<double> get west =>
      $composableBuilder(column: $table.west, builder: (column) => column);

  GeneratedColumn<double> get north =>
      $composableBuilder(column: $table.north, builder: (column) => column);

  GeneratedColumn<double> get east =>
      $composableBuilder(column: $table.east, builder: (column) => column);

  GeneratedColumn<String> get adminLevel => $composableBuilder(
    column: $table.adminLevel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  GeneratedColumn<int> get areaCount =>
      $composableBuilder(column: $table.areaCount, builder: (column) => column);

  GeneratedColumn<int> get pointCount => $composableBuilder(
    column: $table.pointCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$LayersTableAnnotationComposer get layerId {
    final $$LayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.layerId,
      referencedTable: $db.layers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LayersTableAnnotationComposer(
            $db: $db,
            $table: $db.layers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> borderAreasRefs<T extends Object>(
    Expression<T> Function($$BorderAreasTableAnnotationComposer a) f,
  ) {
    final $$BorderAreasTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.borderAreas,
      getReferencedColumn: (t) => t.setId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BorderAreasTableAnnotationComposer(
            $db: $db,
            $table: $db.borderAreas,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BorderSetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BorderSetsTable,
          BorderSet,
          $$BorderSetsTableFilterComposer,
          $$BorderSetsTableOrderingComposer,
          $$BorderSetsTableAnnotationComposer,
          $$BorderSetsTableCreateCompanionBuilder,
          $$BorderSetsTableUpdateCompanionBuilder,
          (BorderSet, $$BorderSetsTableReferences),
          BorderSet,
          PrefetchHooks Function({bool layerId, bool borderAreasRefs})
        > {
  $$BorderSetsTableTableManager(_$AppDatabase db, $BorderSetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BorderSetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BorderSetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BorderSetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> layerId = const Value.absent(),
                Value<double> south = const Value.absent(),
                Value<double> west = const Value.absent(),
                Value<double> north = const Value.absent(),
                Value<double> east = const Value.absent(),
                Value<String> adminLevel = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> areaCount = const Value.absent(),
                Value<int> pointCount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BorderSetsCompanion(
                id: id,
                layerId: layerId,
                south: south,
                west: west,
                north: north,
                east: east,
                adminLevel: adminLevel,
                label: label,
                fetchedAt: fetchedAt,
                areaCount: areaCount,
                pointCount: pointCount,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String layerId,
                required double south,
                required double west,
                required double north,
                required double east,
                required String adminLevel,
                Value<String?> label = const Value.absent(),
                required DateTime fetchedAt,
                Value<int> areaCount = const Value.absent(),
                Value<int> pointCount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BorderSetsCompanion.insert(
                id: id,
                layerId: layerId,
                south: south,
                west: west,
                north: north,
                east: east,
                adminLevel: adminLevel,
                label: label,
                fetchedAt: fetchedAt,
                areaCount: areaCount,
                pointCount: pointCount,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BorderSetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({layerId = false, borderAreasRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (borderAreasRefs) db.borderAreas],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (layerId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.layerId,
                                referencedTable: $$BorderSetsTableReferences
                                    ._layerIdTable(db),
                                referencedColumn: $$BorderSetsTableReferences
                                    ._layerIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (borderAreasRefs)
                    await $_getPrefetchedData<
                      BorderSet,
                      $BorderSetsTable,
                      BorderArea
                    >(
                      currentTable: table,
                      referencedTable: $$BorderSetsTableReferences
                          ._borderAreasRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$BorderSetsTableReferences(
                            db,
                            table,
                            p0,
                          ).borderAreasRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.setId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$BorderSetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BorderSetsTable,
      BorderSet,
      $$BorderSetsTableFilterComposer,
      $$BorderSetsTableOrderingComposer,
      $$BorderSetsTableAnnotationComposer,
      $$BorderSetsTableCreateCompanionBuilder,
      $$BorderSetsTableUpdateCompanionBuilder,
      (BorderSet, $$BorderSetsTableReferences),
      BorderSet,
      PrefetchHooks Function({bool layerId, bool borderAreasRefs})
    >;
typedef $$BorderAreasTableCreateCompanionBuilder =
    BorderAreasCompanion Function({
      required String id,
      required String setId,
      required int osmId,
      Value<String?> name,
      Value<int> colorIndex,
      required double south,
      required double west,
      required double north,
      required double east,
      required double labelLat,
      required double labelLng,
      required int pointCount,
      required String rings,
      required String wayIds,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$BorderAreasTableUpdateCompanionBuilder =
    BorderAreasCompanion Function({
      Value<String> id,
      Value<String> setId,
      Value<int> osmId,
      Value<String?> name,
      Value<int> colorIndex,
      Value<double> south,
      Value<double> west,
      Value<double> north,
      Value<double> east,
      Value<double> labelLat,
      Value<double> labelLng,
      Value<int> pointCount,
      Value<String> rings,
      Value<String> wayIds,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$BorderAreasTableReferences
    extends BaseReferences<_$AppDatabase, $BorderAreasTable, BorderArea> {
  $$BorderAreasTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BorderSetsTable _setIdTable(_$AppDatabase db) =>
      db.borderSets.createAlias(
        $_aliasNameGenerator(db.borderAreas.setId, db.borderSets.id),
      );

  $$BorderSetsTableProcessedTableManager get setId {
    final $_column = $_itemColumn<String>('set_id')!;

    final manager = $$BorderSetsTableTableManager(
      $_db,
      $_db.borderSets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_setIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BorderAreasTableFilterComposer
    extends Composer<_$AppDatabase, $BorderAreasTable> {
  $$BorderAreasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get osmId => $composableBuilder(
    column: $table.osmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get south => $composableBuilder(
    column: $table.south,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get west => $composableBuilder(
    column: $table.west,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get north => $composableBuilder(
    column: $table.north,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get east => $composableBuilder(
    column: $table.east,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get labelLat => $composableBuilder(
    column: $table.labelLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get labelLng => $composableBuilder(
    column: $table.labelLng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pointCount => $composableBuilder(
    column: $table.pointCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rings => $composableBuilder(
    column: $table.rings,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wayIds => $composableBuilder(
    column: $table.wayIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$BorderSetsTableFilterComposer get setId {
    final $$BorderSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.borderSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BorderSetsTableFilterComposer(
            $db: $db,
            $table: $db.borderSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BorderAreasTableOrderingComposer
    extends Composer<_$AppDatabase, $BorderAreasTable> {
  $$BorderAreasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get osmId => $composableBuilder(
    column: $table.osmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get south => $composableBuilder(
    column: $table.south,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get west => $composableBuilder(
    column: $table.west,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get north => $composableBuilder(
    column: $table.north,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get east => $composableBuilder(
    column: $table.east,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get labelLat => $composableBuilder(
    column: $table.labelLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get labelLng => $composableBuilder(
    column: $table.labelLng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pointCount => $composableBuilder(
    column: $table.pointCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rings => $composableBuilder(
    column: $table.rings,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wayIds => $composableBuilder(
    column: $table.wayIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$BorderSetsTableOrderingComposer get setId {
    final $$BorderSetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.borderSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BorderSetsTableOrderingComposer(
            $db: $db,
            $table: $db.borderSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BorderAreasTableAnnotationComposer
    extends Composer<_$AppDatabase, $BorderAreasTable> {
  $$BorderAreasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get osmId =>
      $composableBuilder(column: $table.osmId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => column,
  );

  GeneratedColumn<double> get south =>
      $composableBuilder(column: $table.south, builder: (column) => column);

  GeneratedColumn<double> get west =>
      $composableBuilder(column: $table.west, builder: (column) => column);

  GeneratedColumn<double> get north =>
      $composableBuilder(column: $table.north, builder: (column) => column);

  GeneratedColumn<double> get east =>
      $composableBuilder(column: $table.east, builder: (column) => column);

  GeneratedColumn<double> get labelLat =>
      $composableBuilder(column: $table.labelLat, builder: (column) => column);

  GeneratedColumn<double> get labelLng =>
      $composableBuilder(column: $table.labelLng, builder: (column) => column);

  GeneratedColumn<int> get pointCount => $composableBuilder(
    column: $table.pointCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rings =>
      $composableBuilder(column: $table.rings, builder: (column) => column);

  GeneratedColumn<String> get wayIds =>
      $composableBuilder(column: $table.wayIds, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$BorderSetsTableAnnotationComposer get setId {
    final $$BorderSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setId,
      referencedTable: $db.borderSets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BorderSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.borderSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BorderAreasTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BorderAreasTable,
          BorderArea,
          $$BorderAreasTableFilterComposer,
          $$BorderAreasTableOrderingComposer,
          $$BorderAreasTableAnnotationComposer,
          $$BorderAreasTableCreateCompanionBuilder,
          $$BorderAreasTableUpdateCompanionBuilder,
          (BorderArea, $$BorderAreasTableReferences),
          BorderArea,
          PrefetchHooks Function({bool setId})
        > {
  $$BorderAreasTableTableManager(_$AppDatabase db, $BorderAreasTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BorderAreasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BorderAreasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BorderAreasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> setId = const Value.absent(),
                Value<int> osmId = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<int> colorIndex = const Value.absent(),
                Value<double> south = const Value.absent(),
                Value<double> west = const Value.absent(),
                Value<double> north = const Value.absent(),
                Value<double> east = const Value.absent(),
                Value<double> labelLat = const Value.absent(),
                Value<double> labelLng = const Value.absent(),
                Value<int> pointCount = const Value.absent(),
                Value<String> rings = const Value.absent(),
                Value<String> wayIds = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BorderAreasCompanion(
                id: id,
                setId: setId,
                osmId: osmId,
                name: name,
                colorIndex: colorIndex,
                south: south,
                west: west,
                north: north,
                east: east,
                labelLat: labelLat,
                labelLng: labelLng,
                pointCount: pointCount,
                rings: rings,
                wayIds: wayIds,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String setId,
                required int osmId,
                Value<String?> name = const Value.absent(),
                Value<int> colorIndex = const Value.absent(),
                required double south,
                required double west,
                required double north,
                required double east,
                required double labelLat,
                required double labelLng,
                required int pointCount,
                required String rings,
                required String wayIds,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BorderAreasCompanion.insert(
                id: id,
                setId: setId,
                osmId: osmId,
                name: name,
                colorIndex: colorIndex,
                south: south,
                west: west,
                north: north,
                east: east,
                labelLat: labelLat,
                labelLng: labelLng,
                pointCount: pointCount,
                rings: rings,
                wayIds: wayIds,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BorderAreasTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({setId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (setId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.setId,
                                referencedTable: $$BorderAreasTableReferences
                                    ._setIdTable(db),
                                referencedColumn: $$BorderAreasTableReferences
                                    ._setIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BorderAreasTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BorderAreasTable,
      BorderArea,
      $$BorderAreasTableFilterComposer,
      $$BorderAreasTableOrderingComposer,
      $$BorderAreasTableAnnotationComposer,
      $$BorderAreasTableCreateCompanionBuilder,
      $$BorderAreasTableUpdateCompanionBuilder,
      (BorderArea, $$BorderAreasTableReferences),
      BorderArea,
      PrefetchHooks Function({bool setId})
    >;
typedef $$TileCacheTableCreateCompanionBuilder =
    TileCacheCompanion Function({
      required String url,
      required Uint8List bytes,
      Value<String?> etag,
      required int sizeBytes,
      required int fetchedAt,
      required int lastUsedAt,
      Value<int> rowid,
    });
typedef $$TileCacheTableUpdateCompanionBuilder =
    TileCacheCompanion Function({
      Value<String> url,
      Value<Uint8List> bytes,
      Value<String?> etag,
      Value<int> sizeBytes,
      Value<int> fetchedAt,
      Value<int> lastUsedAt,
      Value<int> rowid,
    });

class $$TileCacheTableFilterComposer
    extends Composer<_$AppDatabase, $TileCacheTable> {
  $$TileCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TileCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $TileCacheTable> {
  $$TileCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TileCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $TileCacheTable> {
  $$TileCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<Uint8List> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<int> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  GeneratedColumn<int> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => column,
  );
}

class $$TileCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TileCacheTable,
          TileCacheData,
          $$TileCacheTableFilterComposer,
          $$TileCacheTableOrderingComposer,
          $$TileCacheTableAnnotationComposer,
          $$TileCacheTableCreateCompanionBuilder,
          $$TileCacheTableUpdateCompanionBuilder,
          (
            TileCacheData,
            BaseReferences<_$AppDatabase, $TileCacheTable, TileCacheData>,
          ),
          TileCacheData,
          PrefetchHooks Function()
        > {
  $$TileCacheTableTableManager(_$AppDatabase db, $TileCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TileCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TileCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TileCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> url = const Value.absent(),
                Value<Uint8List> bytes = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<int> fetchedAt = const Value.absent(),
                Value<int> lastUsedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TileCacheCompanion(
                url: url,
                bytes: bytes,
                etag: etag,
                sizeBytes: sizeBytes,
                fetchedAt: fetchedAt,
                lastUsedAt: lastUsedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String url,
                required Uint8List bytes,
                Value<String?> etag = const Value.absent(),
                required int sizeBytes,
                required int fetchedAt,
                required int lastUsedAt,
                Value<int> rowid = const Value.absent(),
              }) => TileCacheCompanion.insert(
                url: url,
                bytes: bytes,
                etag: etag,
                sizeBytes: sizeBytes,
                fetchedAt: fetchedAt,
                lastUsedAt: lastUsedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TileCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TileCacheTable,
      TileCacheData,
      $$TileCacheTableFilterComposer,
      $$TileCacheTableOrderingComposer,
      $$TileCacheTableAnnotationComposer,
      $$TileCacheTableCreateCompanionBuilder,
      $$TileCacheTableUpdateCompanionBuilder,
      (
        TileCacheData,
        BaseReferences<_$AppDatabase, $TileCacheTable, TileCacheData>,
      ),
      TileCacheData,
      PrefetchHooks Function()
    >;
typedef $$OverpassCacheTableCreateCompanionBuilder =
    OverpassCacheCompanion Function({
      required String kind,
      required String payload,
      required double south,
      required double west,
      required double north,
      required double east,
      required int maskBits,
      required int fetchedAt,
      Value<int> rowid,
    });
typedef $$OverpassCacheTableUpdateCompanionBuilder =
    OverpassCacheCompanion Function({
      Value<String> kind,
      Value<String> payload,
      Value<double> south,
      Value<double> west,
      Value<double> north,
      Value<double> east,
      Value<int> maskBits,
      Value<int> fetchedAt,
      Value<int> rowid,
    });

class $$OverpassCacheTableFilterComposer
    extends Composer<_$AppDatabase, $OverpassCacheTable> {
  $$OverpassCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get south => $composableBuilder(
    column: $table.south,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get west => $composableBuilder(
    column: $table.west,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get north => $composableBuilder(
    column: $table.north,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get east => $composableBuilder(
    column: $table.east,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maskBits => $composableBuilder(
    column: $table.maskBits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OverpassCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $OverpassCacheTable> {
  $$OverpassCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get south => $composableBuilder(
    column: $table.south,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get west => $composableBuilder(
    column: $table.west,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get north => $composableBuilder(
    column: $table.north,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get east => $composableBuilder(
    column: $table.east,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maskBits => $composableBuilder(
    column: $table.maskBits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OverpassCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $OverpassCacheTable> {
  $$OverpassCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<double> get south =>
      $composableBuilder(column: $table.south, builder: (column) => column);

  GeneratedColumn<double> get west =>
      $composableBuilder(column: $table.west, builder: (column) => column);

  GeneratedColumn<double> get north =>
      $composableBuilder(column: $table.north, builder: (column) => column);

  GeneratedColumn<double> get east =>
      $composableBuilder(column: $table.east, builder: (column) => column);

  GeneratedColumn<int> get maskBits =>
      $composableBuilder(column: $table.maskBits, builder: (column) => column);

  GeneratedColumn<int> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$OverpassCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OverpassCacheTable,
          OverpassCacheData,
          $$OverpassCacheTableFilterComposer,
          $$OverpassCacheTableOrderingComposer,
          $$OverpassCacheTableAnnotationComposer,
          $$OverpassCacheTableCreateCompanionBuilder,
          $$OverpassCacheTableUpdateCompanionBuilder,
          (
            OverpassCacheData,
            BaseReferences<
              _$AppDatabase,
              $OverpassCacheTable,
              OverpassCacheData
            >,
          ),
          OverpassCacheData,
          PrefetchHooks Function()
        > {
  $$OverpassCacheTableTableManager(_$AppDatabase db, $OverpassCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OverpassCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OverpassCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OverpassCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> kind = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<double> south = const Value.absent(),
                Value<double> west = const Value.absent(),
                Value<double> north = const Value.absent(),
                Value<double> east = const Value.absent(),
                Value<int> maskBits = const Value.absent(),
                Value<int> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OverpassCacheCompanion(
                kind: kind,
                payload: payload,
                south: south,
                west: west,
                north: north,
                east: east,
                maskBits: maskBits,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String kind,
                required String payload,
                required double south,
                required double west,
                required double north,
                required double east,
                required int maskBits,
                required int fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => OverpassCacheCompanion.insert(
                kind: kind,
                payload: payload,
                south: south,
                west: west,
                north: north,
                east: east,
                maskBits: maskBits,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OverpassCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OverpassCacheTable,
      OverpassCacheData,
      $$OverpassCacheTableFilterComposer,
      $$OverpassCacheTableOrderingComposer,
      $$OverpassCacheTableAnnotationComposer,
      $$OverpassCacheTableCreateCompanionBuilder,
      $$OverpassCacheTableUpdateCompanionBuilder,
      (
        OverpassCacheData,
        BaseReferences<_$AppDatabase, $OverpassCacheTable, OverpassCacheData>,
      ),
      OverpassCacheData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LayersTableTableManager get layers =>
      $$LayersTableTableManager(_db, _db.layers);
  $$CirclesTableTableManager get circles =>
      $$CirclesTableTableManager(_db, _db.circles);
  $$PlanesTableTableManager get planes =>
      $$PlanesTableTableManager(_db, _db.planes);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$SubspacesTableTableManager get subspaces =>
      $$SubspacesTableTableManager(_db, _db.subspaces);
  $$SubspacePointsTableTableManager get subspacePoints =>
      $$SubspacePointsTableTableManager(_db, _db.subspacePoints);
  $$FreeLinesTableTableManager get freeLines =>
      $$FreeLinesTableTableManager(_db, _db.freeLines);
  $$FreeLinePointsTableTableManager get freeLinePoints =>
      $$FreeLinePointsTableTableManager(_db, _db.freeLinePoints);
  $$FreeAreasTableTableManager get freeAreas =>
      $$FreeAreasTableTableManager(_db, _db.freeAreas);
  $$FreeAreaPointsTableTableManager get freeAreaPoints =>
      $$FreeAreaPointsTableTableManager(_db, _db.freeAreaPoints);
  $$HeightRegionsTableTableManager get heightRegions =>
      $$HeightRegionsTableTableManager(_db, _db.heightRegions);
  $$HeightPolygonsTableTableManager get heightPolygons =>
      $$HeightPolygonsTableTableManager(_db, _db.heightPolygons);
  $$HeightPolygonPointsTableTableManager get heightPolygonPoints =>
      $$HeightPolygonPointsTableTableManager(_db, _db.heightPolygonPoints);
  $$PoiSetsTableTableManager get poiSets =>
      $$PoiSetsTableTableManager(_db, _db.poiSets);
  $$PoiPointsTableTableManager get poiPoints =>
      $$PoiPointsTableTableManager(_db, _db.poiPoints);
  $$TransitSetsTableTableManager get transitSets =>
      $$TransitSetsTableTableManager(_db, _db.transitSets);
  $$TransitStopsTableTableManager get transitStops =>
      $$TransitStopsTableTableManager(_db, _db.transitStops);
  $$BorderSetsTableTableManager get borderSets =>
      $$BorderSetsTableTableManager(_db, _db.borderSets);
  $$BorderAreasTableTableManager get borderAreas =>
      $$BorderAreasTableTableManager(_db, _db.borderAreas);
  $$TileCacheTableTableManager get tileCache =>
      $$TileCacheTableTableManager(_db, _db.tileCache);
  $$OverpassCacheTableTableManager get overpassCache =>
      $$OverpassCacheTableTableManager(_db, _db.overpassCache);
}
