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
  final DateTime createdAt;
  const Layer({
    required this.id,
    required this.name,
    required this.colorArgb,
    required this.isVisible,
    required this.sortOrder,
    required this.type,
    required this.isInverted,
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
    DateTime? createdAt,
  }) => Layer(
    id: id ?? this.id,
    name: name ?? this.name,
    colorArgb: colorArgb ?? this.colorArgb,
    isVisible: isVisible ?? this.isVisible,
    sortOrder: sortOrder ?? this.sortOrder,
    type: type ?? this.type,
    isInverted: isInverted ?? this.isInverted,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uncertaintyMeters,
    lastLat,
    lastLng,
    lastZoom,
    transportOverlay,
    poiCategories,
    borderLevels,
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
      poiCategories: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}poi_categories'],
      )!,
      borderLevels: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}border_levels'],
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

  /// Packed bitmask of enabled map-POI categories (see `poiCategories` in
  /// `overpass.dart`). 0 = none shown.
  final int poiCategories;

  /// Packed bitmask of enabled administrative-border levels (see `borderLevels`
  /// in `borders.dart`). 0 = none shown.
  final int borderLevels;
  const AppSetting({
    required this.id,
    required this.uncertaintyMeters,
    this.lastLat,
    this.lastLng,
    this.lastZoom,
    required this.transportOverlay,
    required this.poiCategories,
    required this.borderLevels,
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
    map['poi_categories'] = Variable<int>(poiCategories);
    map['border_levels'] = Variable<int>(borderLevels);
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
      poiCategories: Value(poiCategories),
      borderLevels: Value(borderLevels),
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
      poiCategories: serializer.fromJson<int>(json['poiCategories']),
      borderLevels: serializer.fromJson<int>(json['borderLevels']),
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
      'poiCategories': serializer.toJson<int>(poiCategories),
      'borderLevels': serializer.toJson<int>(borderLevels),
    };
  }

  AppSetting copyWith({
    int? id,
    double? uncertaintyMeters,
    Value<double?> lastLat = const Value.absent(),
    Value<double?> lastLng = const Value.absent(),
    Value<double?> lastZoom = const Value.absent(),
    bool? transportOverlay,
    int? poiCategories,
    int? borderLevels,
  }) => AppSetting(
    id: id ?? this.id,
    uncertaintyMeters: uncertaintyMeters ?? this.uncertaintyMeters,
    lastLat: lastLat.present ? lastLat.value : this.lastLat,
    lastLng: lastLng.present ? lastLng.value : this.lastLng,
    lastZoom: lastZoom.present ? lastZoom.value : this.lastZoom,
    transportOverlay: transportOverlay ?? this.transportOverlay,
    poiCategories: poiCategories ?? this.poiCategories,
    borderLevels: borderLevels ?? this.borderLevels,
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
      poiCategories: data.poiCategories.present
          ? data.poiCategories.value
          : this.poiCategories,
      borderLevels: data.borderLevels.present
          ? data.borderLevels.value
          : this.borderLevels,
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
          ..write('poiCategories: $poiCategories, ')
          ..write('borderLevels: $borderLevels')
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
    poiCategories,
    borderLevels,
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
          other.poiCategories == this.poiCategories &&
          other.borderLevels == this.borderLevels);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<int> id;
  final Value<double> uncertaintyMeters;
  final Value<double?> lastLat;
  final Value<double?> lastLng;
  final Value<double?> lastZoom;
  final Value<bool> transportOverlay;
  final Value<int> poiCategories;
  final Value<int> borderLevels;
  const AppSettingsCompanion({
    this.id = const Value.absent(),
    this.uncertaintyMeters = const Value.absent(),
    this.lastLat = const Value.absent(),
    this.lastLng = const Value.absent(),
    this.lastZoom = const Value.absent(),
    this.transportOverlay = const Value.absent(),
    this.poiCategories = const Value.absent(),
    this.borderLevels = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.uncertaintyMeters = const Value.absent(),
    this.lastLat = const Value.absent(),
    this.lastLng = const Value.absent(),
    this.lastZoom = const Value.absent(),
    this.transportOverlay = const Value.absent(),
    this.poiCategories = const Value.absent(),
    this.borderLevels = const Value.absent(),
  });
  static Insertable<AppSetting> custom({
    Expression<int>? id,
    Expression<double>? uncertaintyMeters,
    Expression<double>? lastLat,
    Expression<double>? lastLng,
    Expression<double>? lastZoom,
    Expression<bool>? transportOverlay,
    Expression<int>? poiCategories,
    Expression<int>? borderLevels,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uncertaintyMeters != null) 'uncertainty_meters': uncertaintyMeters,
      if (lastLat != null) 'last_lat': lastLat,
      if (lastLng != null) 'last_lng': lastLng,
      if (lastZoom != null) 'last_zoom': lastZoom,
      if (transportOverlay != null) 'transport_overlay': transportOverlay,
      if (poiCategories != null) 'poi_categories': poiCategories,
      if (borderLevels != null) 'border_levels': borderLevels,
    });
  }

  AppSettingsCompanion copyWith({
    Value<int>? id,
    Value<double>? uncertaintyMeters,
    Value<double?>? lastLat,
    Value<double?>? lastLng,
    Value<double?>? lastZoom,
    Value<bool>? transportOverlay,
    Value<int>? poiCategories,
    Value<int>? borderLevels,
  }) {
    return AppSettingsCompanion(
      id: id ?? this.id,
      uncertaintyMeters: uncertaintyMeters ?? this.uncertaintyMeters,
      lastLat: lastLat ?? this.lastLat,
      lastLng: lastLng ?? this.lastLng,
      lastZoom: lastZoom ?? this.lastZoom,
      transportOverlay: transportOverlay ?? this.transportOverlay,
      poiCategories: poiCategories ?? this.poiCategories,
      borderLevels: borderLevels ?? this.borderLevels,
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
    if (poiCategories.present) {
      map['poi_categories'] = Variable<int>(poiCategories.value);
    }
    if (borderLevels.present) {
      map['border_levels'] = Variable<int>(borderLevels.value);
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
          ..write('poiCategories: $poiCategories, ')
          ..write('borderLevels: $borderLevels')
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
  final DateTime createdAt;
  const SubspacePoint({
    required this.id,
    required this.subspaceId,
    required this.lat,
    required this.lng,
    required this.sortOrder,
    required this.isMain,
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
    DateTime? createdAt,
  }) => SubspacePoint(
    id: id ?? this.id,
    subspaceId: subspaceId ?? this.subspaceId,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    sortOrder: sortOrder ?? this.sortOrder,
    isMain: isMain ?? this.isMain,
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
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, subspaceId, lat, lng, sortOrder, isMain, createdAt);
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
          other.createdAt == this.createdAt);
}

class SubspacePointsCompanion extends UpdateCompanion<SubspacePoint> {
  final Value<String> id;
  final Value<String> subspaceId;
  final Value<double> lat;
  final Value<double> lng;
  final Value<int> sortOrder;
  final Value<bool> isMain;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SubspacePointsCompanion({
    this.id = const Value.absent(),
    this.subspaceId = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isMain = const Value.absent(),
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
  final DateTime createdAt;
  const FreeLine({
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

  FreeLinesCompanion toCompanion(bool nullToAbsent) {
    return FreeLinesCompanion(
      id: Value(id),
      layerId: Value(layerId),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      offsetMeters: Value(offsetMeters),
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

  FreeLine copyWith({
    String? id,
    String? layerId,
    Value<String?> label = const Value.absent(),
    double? offsetMeters,
    DateTime? createdAt,
  }) => FreeLine(
    id: id ?? this.id,
    layerId: layerId ?? this.layerId,
    label: label.present ? label.value : this.label,
    offsetMeters: offsetMeters ?? this.offsetMeters,
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
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, layerId, label, offsetMeters, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FreeLine &&
          other.id == this.id &&
          other.layerId == this.layerId &&
          other.label == this.label &&
          other.offsetMeters == this.offsetMeters &&
          other.createdAt == this.createdAt);
}

class FreeLinesCompanion extends UpdateCompanion<FreeLine> {
  final Value<String> id;
  final Value<String> layerId;
  final Value<String?> label;
  final Value<double> offsetMeters;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const FreeLinesCompanion({
    this.id = const Value.absent(),
    this.layerId = const Value.absent(),
    this.label = const Value.absent(),
    this.offsetMeters = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FreeLinesCompanion.insert({
    required String id,
    required String layerId,
    this.label = const Value.absent(),
    this.offsetMeters = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       layerId = Value(layerId);
  static Insertable<FreeLine> custom({
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

  FreeLinesCompanion copyWith({
    Value<String>? id,
    Value<String>? layerId,
    Value<String?>? label,
    Value<double>? offsetMeters,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return FreeLinesCompanion(
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
    return (StringBuffer('FreeLinesCompanion(')
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
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (circlesRefs) db.circles,
                    if (planesRefs) db.planes,
                    if (subspacesRefs) db.subspaces,
                    if (freeLinesRefs) db.freeLines,
                    if (freeAreasRefs) db.freeAreas,
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
      Value<int> poiCategories,
      Value<int> borderLevels,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<double> uncertaintyMeters,
      Value<double?> lastLat,
      Value<double?> lastLng,
      Value<double?> lastZoom,
      Value<bool> transportOverlay,
      Value<int> poiCategories,
      Value<int> borderLevels,
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

  ColumnFilters<int> get poiCategories => $composableBuilder(
    column: $table.poiCategories,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get borderLevels => $composableBuilder(
    column: $table.borderLevels,
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

  ColumnOrderings<int> get poiCategories => $composableBuilder(
    column: $table.poiCategories,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get borderLevels => $composableBuilder(
    column: $table.borderLevels,
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

  GeneratedColumn<int> get poiCategories => $composableBuilder(
    column: $table.poiCategories,
    builder: (column) => column,
  );

  GeneratedColumn<int> get borderLevels => $composableBuilder(
    column: $table.borderLevels,
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
                Value<int> poiCategories = const Value.absent(),
                Value<int> borderLevels = const Value.absent(),
              }) => AppSettingsCompanion(
                id: id,
                uncertaintyMeters: uncertaintyMeters,
                lastLat: lastLat,
                lastLng: lastLng,
                lastZoom: lastZoom,
                transportOverlay: transportOverlay,
                poiCategories: poiCategories,
                borderLevels: borderLevels,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<double> uncertaintyMeters = const Value.absent(),
                Value<double?> lastLat = const Value.absent(),
                Value<double?> lastLng = const Value.absent(),
                Value<double?> lastZoom = const Value.absent(),
                Value<bool> transportOverlay = const Value.absent(),
                Value<int> poiCategories = const Value.absent(),
                Value<int> borderLevels = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                id: id,
                uncertaintyMeters: uncertaintyMeters,
                lastLat: lastLat,
                lastLng: lastLng,
                lastZoom: lastZoom,
                transportOverlay: transportOverlay,
                poiCategories: poiCategories,
                borderLevels: borderLevels,
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
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubspacePointsCompanion(
                id: id,
                subspaceId: subspaceId,
                lat: lat,
                lng: lng,
                sortOrder: sortOrder,
                isMain: isMain,
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
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubspacePointsCompanion.insert(
                id: id,
                subspaceId: subspaceId,
                lat: lat,
                lng: lng,
                sortOrder: sortOrder,
                isMain: isMain,
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
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$FreeLinesTableUpdateCompanionBuilder =
    FreeLinesCompanion Function({
      Value<String> id,
      Value<String> layerId,
      Value<String?> label,
      Value<double> offsetMeters,
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
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FreeLinesCompanion(
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
              }) => FreeLinesCompanion.insert(
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
}
