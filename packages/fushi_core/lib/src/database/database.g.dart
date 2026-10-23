// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $MediaOpenHistoryTable extends MediaOpenHistory
    with TableInfo<$MediaOpenHistoryTable, MediaOpenHistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaOpenHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mediaTypeMeta = const VerificationMeta(
    'mediaType',
  );
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
    'media_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaSourceMeta = const VerificationMeta(
    'mediaSource',
  );
  @override
  late final GeneratedColumn<String> mediaSource = GeneratedColumn<String>(
    'media_source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaIdMeta = const VerificationMeta(
    'mediaId',
  );
  @override
  late final GeneratedColumn<String> mediaId = GeneratedColumn<String>(
    'media_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _openedAtMeta = const VerificationMeta(
    'openedAt',
  );
  @override
  late final GeneratedColumn<int> openedAt = GeneratedColumn<int>(
    'opened_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durationMeta = const VerificationMeta(
    'duration',
  );
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
    'duration',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _snapshotJsonMeta = const VerificationMeta(
    'snapshotJson',
  );
  @override
  late final GeneratedColumn<String> snapshotJson = GeneratedColumn<String>(
    'snapshot_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    mediaType,
    mediaSource,
    mediaId,
    openedAt,
    position,
    duration,
    snapshotJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_open_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<MediaOpenHistoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('media_type')) {
      context.handle(
        _mediaTypeMeta,
        mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaTypeMeta);
    }
    if (data.containsKey('media_source')) {
      context.handle(
        _mediaSourceMeta,
        mediaSource.isAcceptableOrUnknown(
          data['media_source']!,
          _mediaSourceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_mediaSourceMeta);
    }
    if (data.containsKey('media_id')) {
      context.handle(
        _mediaIdMeta,
        mediaId.isAcceptableOrUnknown(data['media_id']!, _mediaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaIdMeta);
    }
    if (data.containsKey('opened_at')) {
      context.handle(
        _openedAtMeta,
        openedAt.isAcceptableOrUnknown(data['opened_at']!, _openedAtMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('duration')) {
      context.handle(
        _durationMeta,
        duration.isAcceptableOrUnknown(data['duration']!, _durationMeta),
      );
    }
    if (data.containsKey('snapshot_json')) {
      context.handle(
        _snapshotJsonMeta,
        snapshotJson.isAcceptableOrUnknown(
          data['snapshot_json']!,
          _snapshotJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mediaSource, mediaId};
  @override
  MediaOpenHistoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaOpenHistoryRow(
      mediaType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_type'],
      )!,
      mediaSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_source'],
      )!,
      mediaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_id'],
      )!,
      openedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}opened_at'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      duration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration'],
      )!,
      snapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_json'],
      )!,
    );
  }

  @override
  $MediaOpenHistoryTable createAlias(String alias) {
    return $MediaOpenHistoryTable(attachedDatabase, alias);
  }
}

class MediaOpenHistoryRow extends DataClass
    implements Insertable<MediaOpenHistoryRow> {
  /// 媒体类型 key（冻结值域 = 旧 mediaTypeIdentifier：'reader' / 'player' / …）。
  final String mediaType;

  /// 媒体源 key（旧 mediaSourceIdentifier）。
  final String mediaSource;

  /// 源内身份（旧 mediaIdentifier：库内 = bookKey 派生 URI，外部 = URL）。
  final String mediaId;

  /// 最后打开毫秒戳（排序与 trim 的键；旧 imported_at 平移）。
  final int openedAt;

  /// 进度两数（互联 host 的百分比换算要在 SQL 面上可用，故留列不进 JSON）。
  final int position;
  final int duration;

  /// 其余展示/重开载荷（MediaItem.toJson 去掉列化字段后的 JSON）。
  final String snapshotJson;
  const MediaOpenHistoryRow({
    required this.mediaType,
    required this.mediaSource,
    required this.mediaId,
    required this.openedAt,
    required this.position,
    required this.duration,
    required this.snapshotJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['media_type'] = Variable<String>(mediaType);
    map['media_source'] = Variable<String>(mediaSource);
    map['media_id'] = Variable<String>(mediaId);
    map['opened_at'] = Variable<int>(openedAt);
    map['position'] = Variable<int>(position);
    map['duration'] = Variable<int>(duration);
    map['snapshot_json'] = Variable<String>(snapshotJson);
    return map;
  }

  MediaOpenHistoryCompanion toCompanion(bool nullToAbsent) {
    return MediaOpenHistoryCompanion(
      mediaType: Value(mediaType),
      mediaSource: Value(mediaSource),
      mediaId: Value(mediaId),
      openedAt: Value(openedAt),
      position: Value(position),
      duration: Value(duration),
      snapshotJson: Value(snapshotJson),
    );
  }

  factory MediaOpenHistoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaOpenHistoryRow(
      mediaType: serializer.fromJson<String>(json['mediaType']),
      mediaSource: serializer.fromJson<String>(json['mediaSource']),
      mediaId: serializer.fromJson<String>(json['mediaId']),
      openedAt: serializer.fromJson<int>(json['openedAt']),
      position: serializer.fromJson<int>(json['position']),
      duration: serializer.fromJson<int>(json['duration']),
      snapshotJson: serializer.fromJson<String>(json['snapshotJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mediaType': serializer.toJson<String>(mediaType),
      'mediaSource': serializer.toJson<String>(mediaSource),
      'mediaId': serializer.toJson<String>(mediaId),
      'openedAt': serializer.toJson<int>(openedAt),
      'position': serializer.toJson<int>(position),
      'duration': serializer.toJson<int>(duration),
      'snapshotJson': serializer.toJson<String>(snapshotJson),
    };
  }

  MediaOpenHistoryRow copyWith({
    String? mediaType,
    String? mediaSource,
    String? mediaId,
    int? openedAt,
    int? position,
    int? duration,
    String? snapshotJson,
  }) => MediaOpenHistoryRow(
    mediaType: mediaType ?? this.mediaType,
    mediaSource: mediaSource ?? this.mediaSource,
    mediaId: mediaId ?? this.mediaId,
    openedAt: openedAt ?? this.openedAt,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    snapshotJson: snapshotJson ?? this.snapshotJson,
  );
  MediaOpenHistoryRow copyWithCompanion(MediaOpenHistoryCompanion data) {
    return MediaOpenHistoryRow(
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      mediaSource: data.mediaSource.present
          ? data.mediaSource.value
          : this.mediaSource,
      mediaId: data.mediaId.present ? data.mediaId.value : this.mediaId,
      openedAt: data.openedAt.present ? data.openedAt.value : this.openedAt,
      position: data.position.present ? data.position.value : this.position,
      duration: data.duration.present ? data.duration.value : this.duration,
      snapshotJson: data.snapshotJson.present
          ? data.snapshotJson.value
          : this.snapshotJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaOpenHistoryRow(')
          ..write('mediaType: $mediaType, ')
          ..write('mediaSource: $mediaSource, ')
          ..write('mediaId: $mediaId, ')
          ..write('openedAt: $openedAt, ')
          ..write('position: $position, ')
          ..write('duration: $duration, ')
          ..write('snapshotJson: $snapshotJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    mediaType,
    mediaSource,
    mediaId,
    openedAt,
    position,
    duration,
    snapshotJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaOpenHistoryRow &&
          other.mediaType == this.mediaType &&
          other.mediaSource == this.mediaSource &&
          other.mediaId == this.mediaId &&
          other.openedAt == this.openedAt &&
          other.position == this.position &&
          other.duration == this.duration &&
          other.snapshotJson == this.snapshotJson);
}

class MediaOpenHistoryCompanion extends UpdateCompanion<MediaOpenHistoryRow> {
  final Value<String> mediaType;
  final Value<String> mediaSource;
  final Value<String> mediaId;
  final Value<int> openedAt;
  final Value<int> position;
  final Value<int> duration;
  final Value<String> snapshotJson;
  final Value<int> rowid;
  const MediaOpenHistoryCompanion({
    this.mediaType = const Value.absent(),
    this.mediaSource = const Value.absent(),
    this.mediaId = const Value.absent(),
    this.openedAt = const Value.absent(),
    this.position = const Value.absent(),
    this.duration = const Value.absent(),
    this.snapshotJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaOpenHistoryCompanion.insert({
    required String mediaType,
    required String mediaSource,
    required String mediaId,
    this.openedAt = const Value.absent(),
    this.position = const Value.absent(),
    this.duration = const Value.absent(),
    this.snapshotJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : mediaType = Value(mediaType),
       mediaSource = Value(mediaSource),
       mediaId = Value(mediaId);
  static Insertable<MediaOpenHistoryRow> custom({
    Expression<String>? mediaType,
    Expression<String>? mediaSource,
    Expression<String>? mediaId,
    Expression<int>? openedAt,
    Expression<int>? position,
    Expression<int>? duration,
    Expression<String>? snapshotJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mediaType != null) 'media_type': mediaType,
      if (mediaSource != null) 'media_source': mediaSource,
      if (mediaId != null) 'media_id': mediaId,
      if (openedAt != null) 'opened_at': openedAt,
      if (position != null) 'position': position,
      if (duration != null) 'duration': duration,
      if (snapshotJson != null) 'snapshot_json': snapshotJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaOpenHistoryCompanion copyWith({
    Value<String>? mediaType,
    Value<String>? mediaSource,
    Value<String>? mediaId,
    Value<int>? openedAt,
    Value<int>? position,
    Value<int>? duration,
    Value<String>? snapshotJson,
    Value<int>? rowid,
  }) {
    return MediaOpenHistoryCompanion(
      mediaType: mediaType ?? this.mediaType,
      mediaSource: mediaSource ?? this.mediaSource,
      mediaId: mediaId ?? this.mediaId,
      openedAt: openedAt ?? this.openedAt,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      snapshotJson: snapshotJson ?? this.snapshotJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (mediaSource.present) {
      map['media_source'] = Variable<String>(mediaSource.value);
    }
    if (mediaId.present) {
      map['media_id'] = Variable<String>(mediaId.value);
    }
    if (openedAt.present) {
      map['opened_at'] = Variable<int>(openedAt.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    if (snapshotJson.present) {
      map['snapshot_json'] = Variable<String>(snapshotJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaOpenHistoryCompanion(')
          ..write('mediaType: $mediaType, ')
          ..write('mediaSource: $mediaSource, ')
          ..write('mediaId: $mediaId, ')
          ..write('openedAt: $openedAt, ')
          ..write('position: $position, ')
          ..write('duration: $duration, ')
          ..write('snapshotJson: $snapshotJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReaderPositionsTable extends ReaderPositions
    with TableInfo<$ReaderPositionsTable, ReaderPositionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReaderPositionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _bookUidMeta = const VerificationMeta(
    'bookUid',
  );
  @override
  late final GeneratedColumn<String> bookUid = GeneratedColumn<String>(
    'book_uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _sectionIndexMeta = const VerificationMeta(
    'sectionIndex',
  );
  @override
  late final GeneratedColumn<int> sectionIndex = GeneratedColumn<int>(
    'section_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normCharOffsetMeta = const VerificationMeta(
    'normCharOffset',
  );
  @override
  late final GeneratedColumn<int> normCharOffset = GeneratedColumn<int>(
    'norm_char_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _charOffsetMeta = const VerificationMeta(
    'charOffset',
  );
  @override
  late final GeneratedColumn<int> charOffset = GeneratedColumn<int>(
    'char_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(-1),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookUid,
    sectionIndex,
    normCharOffset,
    charOffset,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reader_positions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReaderPositionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_uid')) {
      context.handle(
        _bookUidMeta,
        bookUid.isAcceptableOrUnknown(data['book_uid']!, _bookUidMeta),
      );
    } else if (isInserting) {
      context.missing(_bookUidMeta);
    }
    if (data.containsKey('section_index')) {
      context.handle(
        _sectionIndexMeta,
        sectionIndex.isAcceptableOrUnknown(
          data['section_index']!,
          _sectionIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sectionIndexMeta);
    }
    if (data.containsKey('norm_char_offset')) {
      context.handle(
        _normCharOffsetMeta,
        normCharOffset.isAcceptableOrUnknown(
          data['norm_char_offset']!,
          _normCharOffsetMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normCharOffsetMeta);
    }
    if (data.containsKey('char_offset')) {
      context.handle(
        _charOffsetMeta,
        charOffset.isAcceptableOrUnknown(data['char_offset']!, _charOffsetMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReaderPositionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReaderPositionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bookUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_uid'],
      )!,
      sectionIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}section_index'],
      )!,
      normCharOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}norm_char_offset'],
      )!,
      charOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}char_offset'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ReaderPositionsTable createAlias(String alias) {
    return $ReaderPositionsTable(attachedDatabase, alias);
  }
}

class ReaderPositionRow extends DataClass
    implements Insertable<ReaderPositionRow> {
  final int id;

  /// v82 起的书稳定身份:epub 书 = EpubBooks.uid(本机稳定,标题改名不丢位置);
  /// 非 epub 域(SRT 书等)沿用其既有稳定键。刻意无 FK——本表跨书族,孤儿防线
  /// 在应用层(host service 写入闸门 + deleteEpubBook 显式清理)。
  final String bookUid;
  final int sectionIndex;
  final int normCharOffset;
  final int charOffset;
  final int updatedAt;
  const ReaderPositionRow({
    required this.id,
    required this.bookUid,
    required this.sectionIndex,
    required this.normCharOffset,
    required this.charOffset,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_uid'] = Variable<String>(bookUid);
    map['section_index'] = Variable<int>(sectionIndex);
    map['norm_char_offset'] = Variable<int>(normCharOffset);
    map['char_offset'] = Variable<int>(charOffset);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ReaderPositionsCompanion toCompanion(bool nullToAbsent) {
    return ReaderPositionsCompanion(
      id: Value(id),
      bookUid: Value(bookUid),
      sectionIndex: Value(sectionIndex),
      normCharOffset: Value(normCharOffset),
      charOffset: Value(charOffset),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReaderPositionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReaderPositionRow(
      id: serializer.fromJson<int>(json['id']),
      bookUid: serializer.fromJson<String>(json['bookUid']),
      sectionIndex: serializer.fromJson<int>(json['sectionIndex']),
      normCharOffset: serializer.fromJson<int>(json['normCharOffset']),
      charOffset: serializer.fromJson<int>(json['charOffset']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookUid': serializer.toJson<String>(bookUid),
      'sectionIndex': serializer.toJson<int>(sectionIndex),
      'normCharOffset': serializer.toJson<int>(normCharOffset),
      'charOffset': serializer.toJson<int>(charOffset),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ReaderPositionRow copyWith({
    int? id,
    String? bookUid,
    int? sectionIndex,
    int? normCharOffset,
    int? charOffset,
    int? updatedAt,
  }) => ReaderPositionRow(
    id: id ?? this.id,
    bookUid: bookUid ?? this.bookUid,
    sectionIndex: sectionIndex ?? this.sectionIndex,
    normCharOffset: normCharOffset ?? this.normCharOffset,
    charOffset: charOffset ?? this.charOffset,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ReaderPositionRow copyWithCompanion(ReaderPositionsCompanion data) {
    return ReaderPositionRow(
      id: data.id.present ? data.id.value : this.id,
      bookUid: data.bookUid.present ? data.bookUid.value : this.bookUid,
      sectionIndex: data.sectionIndex.present
          ? data.sectionIndex.value
          : this.sectionIndex,
      normCharOffset: data.normCharOffset.present
          ? data.normCharOffset.value
          : this.normCharOffset,
      charOffset: data.charOffset.present
          ? data.charOffset.value
          : this.charOffset,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReaderPositionRow(')
          ..write('id: $id, ')
          ..write('bookUid: $bookUid, ')
          ..write('sectionIndex: $sectionIndex, ')
          ..write('normCharOffset: $normCharOffset, ')
          ..write('charOffset: $charOffset, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookUid,
    sectionIndex,
    normCharOffset,
    charOffset,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReaderPositionRow &&
          other.id == this.id &&
          other.bookUid == this.bookUid &&
          other.sectionIndex == this.sectionIndex &&
          other.normCharOffset == this.normCharOffset &&
          other.charOffset == this.charOffset &&
          other.updatedAt == this.updatedAt);
}

class ReaderPositionsCompanion extends UpdateCompanion<ReaderPositionRow> {
  final Value<int> id;
  final Value<String> bookUid;
  final Value<int> sectionIndex;
  final Value<int> normCharOffset;
  final Value<int> charOffset;
  final Value<int> updatedAt;
  const ReaderPositionsCompanion({
    this.id = const Value.absent(),
    this.bookUid = const Value.absent(),
    this.sectionIndex = const Value.absent(),
    this.normCharOffset = const Value.absent(),
    this.charOffset = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ReaderPositionsCompanion.insert({
    this.id = const Value.absent(),
    required String bookUid,
    required int sectionIndex,
    required int normCharOffset,
    this.charOffset = const Value.absent(),
    required int updatedAt,
  }) : bookUid = Value(bookUid),
       sectionIndex = Value(sectionIndex),
       normCharOffset = Value(normCharOffset),
       updatedAt = Value(updatedAt);
  static Insertable<ReaderPositionRow> custom({
    Expression<int>? id,
    Expression<String>? bookUid,
    Expression<int>? sectionIndex,
    Expression<int>? normCharOffset,
    Expression<int>? charOffset,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookUid != null) 'book_uid': bookUid,
      if (sectionIndex != null) 'section_index': sectionIndex,
      if (normCharOffset != null) 'norm_char_offset': normCharOffset,
      if (charOffset != null) 'char_offset': charOffset,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ReaderPositionsCompanion copyWith({
    Value<int>? id,
    Value<String>? bookUid,
    Value<int>? sectionIndex,
    Value<int>? normCharOffset,
    Value<int>? charOffset,
    Value<int>? updatedAt,
  }) {
    return ReaderPositionsCompanion(
      id: id ?? this.id,
      bookUid: bookUid ?? this.bookUid,
      sectionIndex: sectionIndex ?? this.sectionIndex,
      normCharOffset: normCharOffset ?? this.normCharOffset,
      charOffset: charOffset ?? this.charOffset,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookUid.present) {
      map['book_uid'] = Variable<String>(bookUid.value);
    }
    if (sectionIndex.present) {
      map['section_index'] = Variable<int>(sectionIndex.value);
    }
    if (normCharOffset.present) {
      map['norm_char_offset'] = Variable<int>(normCharOffset.value);
    }
    if (charOffset.present) {
      map['char_offset'] = Variable<int>(charOffset.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReaderPositionsCompanion(')
          ..write('id: $id, ')
          ..write('bookUid: $bookUid, ')
          ..write('sectionIndex: $sectionIndex, ')
          ..write('normCharOffset: $normCharOffset, ')
          ..write('charOffset: $charOffset, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $BookmarksTable extends Bookmarks
    with TableInfo<$BookmarksTable, BookmarkRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _bookUidMeta = const VerificationMeta(
    'bookUid',
  );
  @override
  late final GeneratedColumn<String> bookUid = GeneratedColumn<String>(
    'book_uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sectionIndexMeta = const VerificationMeta(
    'sectionIndex',
  );
  @override
  late final GeneratedColumn<int> sectionIndex = GeneratedColumn<int>(
    'section_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normCharOffsetMeta = const VerificationMeta(
    'normCharOffset',
  );
  @override
  late final GeneratedColumn<int> normCharOffset = GeneratedColumn<int>(
    'norm_char_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookTitleMeta = const VerificationMeta(
    'bookTitle',
  );
  @override
  late final GeneratedColumn<String> bookTitle = GeneratedColumn<String>(
    'book_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pageInChapterMeta = const VerificationMeta(
    'pageInChapter',
  );
  @override
  late final GeneratedColumn<int> pageInChapter = GeneratedColumn<int>(
    'page_in_chapter',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalPagesInChapterMeta =
      const VerificationMeta('totalPagesInChapter');
  @override
  late final GeneratedColumn<int> totalPagesInChapter = GeneratedColumn<int>(
    'total_pages_in_chapter',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookUid,
    sectionIndex,
    normCharOffset,
    label,
    createdAt,
    bookTitle,
    pageInChapter,
    totalPagesInChapter,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookmarkRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_uid')) {
      context.handle(
        _bookUidMeta,
        bookUid.isAcceptableOrUnknown(data['book_uid']!, _bookUidMeta),
      );
    } else if (isInserting) {
      context.missing(_bookUidMeta);
    }
    if (data.containsKey('section_index')) {
      context.handle(
        _sectionIndexMeta,
        sectionIndex.isAcceptableOrUnknown(
          data['section_index']!,
          _sectionIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sectionIndexMeta);
    }
    if (data.containsKey('norm_char_offset')) {
      context.handle(
        _normCharOffsetMeta,
        normCharOffset.isAcceptableOrUnknown(
          data['norm_char_offset']!,
          _normCharOffsetMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normCharOffsetMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('book_title')) {
      context.handle(
        _bookTitleMeta,
        bookTitle.isAcceptableOrUnknown(data['book_title']!, _bookTitleMeta),
      );
    }
    if (data.containsKey('page_in_chapter')) {
      context.handle(
        _pageInChapterMeta,
        pageInChapter.isAcceptableOrUnknown(
          data['page_in_chapter']!,
          _pageInChapterMeta,
        ),
      );
    }
    if (data.containsKey('total_pages_in_chapter')) {
      context.handle(
        _totalPagesInChapterMeta,
        totalPagesInChapter.isAcceptableOrUnknown(
          data['total_pages_in_chapter']!,
          _totalPagesInChapterMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookmarkRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookmarkRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bookUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_uid'],
      )!,
      sectionIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}section_index'],
      )!,
      normCharOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}norm_char_offset'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      bookTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_title'],
      ),
      pageInChapter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_in_chapter'],
      ),
      totalPagesInChapter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_pages_in_chapter'],
      ),
    );
  }

  @override
  $BookmarksTable createAlias(String alias) {
    return $BookmarksTable(attachedDatabase, alias);
  }
}

class BookmarkRow extends DataClass implements Insertable<BookmarkRow> {
  final int id;

  /// v82:= EpubBooks.uid。无 SQL FK(uid 唯一性是 partial 索引,FK 会
  /// mismatch);删书清理走 deleteEpubBook 显式级联,守卫测试兜底。
  final String bookUid;
  final int sectionIndex;
  final int normCharOffset;
  final String label;
  final int createdAt;
  final String? bookTitle;
  final int? pageInChapter;
  final int? totalPagesInChapter;
  const BookmarkRow({
    required this.id,
    required this.bookUid,
    required this.sectionIndex,
    required this.normCharOffset,
    required this.label,
    required this.createdAt,
    this.bookTitle,
    this.pageInChapter,
    this.totalPagesInChapter,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_uid'] = Variable<String>(bookUid);
    map['section_index'] = Variable<int>(sectionIndex);
    map['norm_char_offset'] = Variable<int>(normCharOffset);
    map['label'] = Variable<String>(label);
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || bookTitle != null) {
      map['book_title'] = Variable<String>(bookTitle);
    }
    if (!nullToAbsent || pageInChapter != null) {
      map['page_in_chapter'] = Variable<int>(pageInChapter);
    }
    if (!nullToAbsent || totalPagesInChapter != null) {
      map['total_pages_in_chapter'] = Variable<int>(totalPagesInChapter);
    }
    return map;
  }

  BookmarksCompanion toCompanion(bool nullToAbsent) {
    return BookmarksCompanion(
      id: Value(id),
      bookUid: Value(bookUid),
      sectionIndex: Value(sectionIndex),
      normCharOffset: Value(normCharOffset),
      label: Value(label),
      createdAt: Value(createdAt),
      bookTitle: bookTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(bookTitle),
      pageInChapter: pageInChapter == null && nullToAbsent
          ? const Value.absent()
          : Value(pageInChapter),
      totalPagesInChapter: totalPagesInChapter == null && nullToAbsent
          ? const Value.absent()
          : Value(totalPagesInChapter),
    );
  }

  factory BookmarkRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookmarkRow(
      id: serializer.fromJson<int>(json['id']),
      bookUid: serializer.fromJson<String>(json['bookUid']),
      sectionIndex: serializer.fromJson<int>(json['sectionIndex']),
      normCharOffset: serializer.fromJson<int>(json['normCharOffset']),
      label: serializer.fromJson<String>(json['label']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      bookTitle: serializer.fromJson<String?>(json['bookTitle']),
      pageInChapter: serializer.fromJson<int?>(json['pageInChapter']),
      totalPagesInChapter: serializer.fromJson<int?>(
        json['totalPagesInChapter'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookUid': serializer.toJson<String>(bookUid),
      'sectionIndex': serializer.toJson<int>(sectionIndex),
      'normCharOffset': serializer.toJson<int>(normCharOffset),
      'label': serializer.toJson<String>(label),
      'createdAt': serializer.toJson<int>(createdAt),
      'bookTitle': serializer.toJson<String?>(bookTitle),
      'pageInChapter': serializer.toJson<int?>(pageInChapter),
      'totalPagesInChapter': serializer.toJson<int?>(totalPagesInChapter),
    };
  }

  BookmarkRow copyWith({
    int? id,
    String? bookUid,
    int? sectionIndex,
    int? normCharOffset,
    String? label,
    int? createdAt,
    Value<String?> bookTitle = const Value.absent(),
    Value<int?> pageInChapter = const Value.absent(),
    Value<int?> totalPagesInChapter = const Value.absent(),
  }) => BookmarkRow(
    id: id ?? this.id,
    bookUid: bookUid ?? this.bookUid,
    sectionIndex: sectionIndex ?? this.sectionIndex,
    normCharOffset: normCharOffset ?? this.normCharOffset,
    label: label ?? this.label,
    createdAt: createdAt ?? this.createdAt,
    bookTitle: bookTitle.present ? bookTitle.value : this.bookTitle,
    pageInChapter: pageInChapter.present
        ? pageInChapter.value
        : this.pageInChapter,
    totalPagesInChapter: totalPagesInChapter.present
        ? totalPagesInChapter.value
        : this.totalPagesInChapter,
  );
  BookmarkRow copyWithCompanion(BookmarksCompanion data) {
    return BookmarkRow(
      id: data.id.present ? data.id.value : this.id,
      bookUid: data.bookUid.present ? data.bookUid.value : this.bookUid,
      sectionIndex: data.sectionIndex.present
          ? data.sectionIndex.value
          : this.sectionIndex,
      normCharOffset: data.normCharOffset.present
          ? data.normCharOffset.value
          : this.normCharOffset,
      label: data.label.present ? data.label.value : this.label,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      bookTitle: data.bookTitle.present ? data.bookTitle.value : this.bookTitle,
      pageInChapter: data.pageInChapter.present
          ? data.pageInChapter.value
          : this.pageInChapter,
      totalPagesInChapter: data.totalPagesInChapter.present
          ? data.totalPagesInChapter.value
          : this.totalPagesInChapter,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookmarkRow(')
          ..write('id: $id, ')
          ..write('bookUid: $bookUid, ')
          ..write('sectionIndex: $sectionIndex, ')
          ..write('normCharOffset: $normCharOffset, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt, ')
          ..write('bookTitle: $bookTitle, ')
          ..write('pageInChapter: $pageInChapter, ')
          ..write('totalPagesInChapter: $totalPagesInChapter')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookUid,
    sectionIndex,
    normCharOffset,
    label,
    createdAt,
    bookTitle,
    pageInChapter,
    totalPagesInChapter,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookmarkRow &&
          other.id == this.id &&
          other.bookUid == this.bookUid &&
          other.sectionIndex == this.sectionIndex &&
          other.normCharOffset == this.normCharOffset &&
          other.label == this.label &&
          other.createdAt == this.createdAt &&
          other.bookTitle == this.bookTitle &&
          other.pageInChapter == this.pageInChapter &&
          other.totalPagesInChapter == this.totalPagesInChapter);
}

class BookmarksCompanion extends UpdateCompanion<BookmarkRow> {
  final Value<int> id;
  final Value<String> bookUid;
  final Value<int> sectionIndex;
  final Value<int> normCharOffset;
  final Value<String> label;
  final Value<int> createdAt;
  final Value<String?> bookTitle;
  final Value<int?> pageInChapter;
  final Value<int?> totalPagesInChapter;
  const BookmarksCompanion({
    this.id = const Value.absent(),
    this.bookUid = const Value.absent(),
    this.sectionIndex = const Value.absent(),
    this.normCharOffset = const Value.absent(),
    this.label = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.bookTitle = const Value.absent(),
    this.pageInChapter = const Value.absent(),
    this.totalPagesInChapter = const Value.absent(),
  });
  BookmarksCompanion.insert({
    this.id = const Value.absent(),
    required String bookUid,
    required int sectionIndex,
    required int normCharOffset,
    required String label,
    required int createdAt,
    this.bookTitle = const Value.absent(),
    this.pageInChapter = const Value.absent(),
    this.totalPagesInChapter = const Value.absent(),
  }) : bookUid = Value(bookUid),
       sectionIndex = Value(sectionIndex),
       normCharOffset = Value(normCharOffset),
       label = Value(label),
       createdAt = Value(createdAt);
  static Insertable<BookmarkRow> custom({
    Expression<int>? id,
    Expression<String>? bookUid,
    Expression<int>? sectionIndex,
    Expression<int>? normCharOffset,
    Expression<String>? label,
    Expression<int>? createdAt,
    Expression<String>? bookTitle,
    Expression<int>? pageInChapter,
    Expression<int>? totalPagesInChapter,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookUid != null) 'book_uid': bookUid,
      if (sectionIndex != null) 'section_index': sectionIndex,
      if (normCharOffset != null) 'norm_char_offset': normCharOffset,
      if (label != null) 'label': label,
      if (createdAt != null) 'created_at': createdAt,
      if (bookTitle != null) 'book_title': bookTitle,
      if (pageInChapter != null) 'page_in_chapter': pageInChapter,
      if (totalPagesInChapter != null)
        'total_pages_in_chapter': totalPagesInChapter,
    });
  }

  BookmarksCompanion copyWith({
    Value<int>? id,
    Value<String>? bookUid,
    Value<int>? sectionIndex,
    Value<int>? normCharOffset,
    Value<String>? label,
    Value<int>? createdAt,
    Value<String?>? bookTitle,
    Value<int?>? pageInChapter,
    Value<int?>? totalPagesInChapter,
  }) {
    return BookmarksCompanion(
      id: id ?? this.id,
      bookUid: bookUid ?? this.bookUid,
      sectionIndex: sectionIndex ?? this.sectionIndex,
      normCharOffset: normCharOffset ?? this.normCharOffset,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
      bookTitle: bookTitle ?? this.bookTitle,
      pageInChapter: pageInChapter ?? this.pageInChapter,
      totalPagesInChapter: totalPagesInChapter ?? this.totalPagesInChapter,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookUid.present) {
      map['book_uid'] = Variable<String>(bookUid.value);
    }
    if (sectionIndex.present) {
      map['section_index'] = Variable<int>(sectionIndex.value);
    }
    if (normCharOffset.present) {
      map['norm_char_offset'] = Variable<int>(normCharOffset.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (bookTitle.present) {
      map['book_title'] = Variable<String>(bookTitle.value);
    }
    if (pageInChapter.present) {
      map['page_in_chapter'] = Variable<int>(pageInChapter.value);
    }
    if (totalPagesInChapter.present) {
      map['total_pages_in_chapter'] = Variable<int>(totalPagesInChapter.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookmarksCompanion(')
          ..write('id: $id, ')
          ..write('bookUid: $bookUid, ')
          ..write('sectionIndex: $sectionIndex, ')
          ..write('normCharOffset: $normCharOffset, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt, ')
          ..write('bookTitle: $bookTitle, ')
          ..write('pageInChapter: $pageInChapter, ')
          ..write('totalPagesInChapter: $totalPagesInChapter')
          ..write(')'))
        .toString();
  }
}

class $ReadingStatisticsTable extends ReadingStatistics
    with TableInfo<$ReadingStatisticsTable, ReadingStatisticRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingStatisticsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateKeyMeta = const VerificationMeta(
    'dateKey',
  );
  @override
  late final GeneratedColumn<String> dateKey = GeneratedColumn<String>(
    'date_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _charactersReadMeta = const VerificationMeta(
    'charactersRead',
  );
  @override
  late final GeneratedColumn<int> charactersRead = GeneratedColumn<int>(
    'characters_read',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readingTimeMsMeta = const VerificationMeta(
    'readingTimeMs',
  );
  @override
  late final GeneratedColumn<int> readingTimeMs = GeneratedColumn<int>(
    'reading_time_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pagesReadMeta = const VerificationMeta(
    'pagesRead',
  );
  @override
  late final GeneratedColumn<int> pagesRead = GeneratedColumn<int>(
    'pages_read',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastStatisticModifiedMeta =
      const VerificationMeta('lastStatisticModified');
  @override
  late final GeneratedColumn<int> lastStatisticModified = GeneratedColumn<int>(
    'last_statistic_modified',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    dateKey,
    charactersRead,
    readingTimeMs,
    pagesRead,
    lastStatisticModified,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_statistics';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingStatisticRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('date_key')) {
      context.handle(
        _dateKeyMeta,
        dateKey.isAcceptableOrUnknown(data['date_key']!, _dateKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dateKeyMeta);
    }
    if (data.containsKey('characters_read')) {
      context.handle(
        _charactersReadMeta,
        charactersRead.isAcceptableOrUnknown(
          data['characters_read']!,
          _charactersReadMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_charactersReadMeta);
    }
    if (data.containsKey('reading_time_ms')) {
      context.handle(
        _readingTimeMsMeta,
        readingTimeMs.isAcceptableOrUnknown(
          data['reading_time_ms']!,
          _readingTimeMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_readingTimeMsMeta);
    }
    if (data.containsKey('pages_read')) {
      context.handle(
        _pagesReadMeta,
        pagesRead.isAcceptableOrUnknown(data['pages_read']!, _pagesReadMeta),
      );
    }
    if (data.containsKey('last_statistic_modified')) {
      context.handle(
        _lastStatisticModifiedMeta,
        lastStatisticModified.isAcceptableOrUnknown(
          data['last_statistic_modified']!,
          _lastStatisticModifiedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastStatisticModifiedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {title, dateKey},
  ];
  @override
  ReadingStatisticRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingStatisticRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      dateKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_key'],
      )!,
      charactersRead: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}characters_read'],
      )!,
      readingTimeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reading_time_ms'],
      )!,
      pagesRead: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pages_read'],
      )!,
      lastStatisticModified: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_statistic_modified'],
      )!,
    );
  }

  @override
  $ReadingStatisticsTable createAlias(String alias) {
    return $ReadingStatisticsTable(attachedDatabase, alias);
  }
}

class ReadingStatisticRow extends DataClass
    implements Insertable<ReadingStatisticRow> {
  final int id;
  final String title;
  final String dateKey;
  final int charactersRead;
  final int readingTimeMs;

  /// v60：当日读过的**页数**（漫画 / PDF 这类以页为单位的书；EPUB 恒 0）。
  ///
  /// 页数与字数是两个独立量纲，绝不互相顶替：漫画既落 OCR 字符数（与 EPUB 同口径）
  /// 又落页数，统计页两个维度分别展示。旧库迁移补 0，跨设备聚合同步的 wire 契约
  /// 不带此列（[StatBucket] 要求两端字段集一致，加字段会让新旧端互相抛错），页数
  /// 随整库备份/恢复走。
  final int pagesRead;
  final int lastStatisticModified;
  const ReadingStatisticRow({
    required this.id,
    required this.title,
    required this.dateKey,
    required this.charactersRead,
    required this.readingTimeMs,
    required this.pagesRead,
    required this.lastStatisticModified,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['date_key'] = Variable<String>(dateKey);
    map['characters_read'] = Variable<int>(charactersRead);
    map['reading_time_ms'] = Variable<int>(readingTimeMs);
    map['pages_read'] = Variable<int>(pagesRead);
    map['last_statistic_modified'] = Variable<int>(lastStatisticModified);
    return map;
  }

  ReadingStatisticsCompanion toCompanion(bool nullToAbsent) {
    return ReadingStatisticsCompanion(
      id: Value(id),
      title: Value(title),
      dateKey: Value(dateKey),
      charactersRead: Value(charactersRead),
      readingTimeMs: Value(readingTimeMs),
      pagesRead: Value(pagesRead),
      lastStatisticModified: Value(lastStatisticModified),
    );
  }

  factory ReadingStatisticRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingStatisticRow(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      dateKey: serializer.fromJson<String>(json['dateKey']),
      charactersRead: serializer.fromJson<int>(json['charactersRead']),
      readingTimeMs: serializer.fromJson<int>(json['readingTimeMs']),
      pagesRead: serializer.fromJson<int>(json['pagesRead']),
      lastStatisticModified: serializer.fromJson<int>(
        json['lastStatisticModified'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'dateKey': serializer.toJson<String>(dateKey),
      'charactersRead': serializer.toJson<int>(charactersRead),
      'readingTimeMs': serializer.toJson<int>(readingTimeMs),
      'pagesRead': serializer.toJson<int>(pagesRead),
      'lastStatisticModified': serializer.toJson<int>(lastStatisticModified),
    };
  }

  ReadingStatisticRow copyWith({
    int? id,
    String? title,
    String? dateKey,
    int? charactersRead,
    int? readingTimeMs,
    int? pagesRead,
    int? lastStatisticModified,
  }) => ReadingStatisticRow(
    id: id ?? this.id,
    title: title ?? this.title,
    dateKey: dateKey ?? this.dateKey,
    charactersRead: charactersRead ?? this.charactersRead,
    readingTimeMs: readingTimeMs ?? this.readingTimeMs,
    pagesRead: pagesRead ?? this.pagesRead,
    lastStatisticModified: lastStatisticModified ?? this.lastStatisticModified,
  );
  ReadingStatisticRow copyWithCompanion(ReadingStatisticsCompanion data) {
    return ReadingStatisticRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      dateKey: data.dateKey.present ? data.dateKey.value : this.dateKey,
      charactersRead: data.charactersRead.present
          ? data.charactersRead.value
          : this.charactersRead,
      readingTimeMs: data.readingTimeMs.present
          ? data.readingTimeMs.value
          : this.readingTimeMs,
      pagesRead: data.pagesRead.present ? data.pagesRead.value : this.pagesRead,
      lastStatisticModified: data.lastStatisticModified.present
          ? data.lastStatisticModified.value
          : this.lastStatisticModified,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingStatisticRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('dateKey: $dateKey, ')
          ..write('charactersRead: $charactersRead, ')
          ..write('readingTimeMs: $readingTimeMs, ')
          ..write('pagesRead: $pagesRead, ')
          ..write('lastStatisticModified: $lastStatisticModified')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    dateKey,
    charactersRead,
    readingTimeMs,
    pagesRead,
    lastStatisticModified,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingStatisticRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.dateKey == this.dateKey &&
          other.charactersRead == this.charactersRead &&
          other.readingTimeMs == this.readingTimeMs &&
          other.pagesRead == this.pagesRead &&
          other.lastStatisticModified == this.lastStatisticModified);
}

class ReadingStatisticsCompanion extends UpdateCompanion<ReadingStatisticRow> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> dateKey;
  final Value<int> charactersRead;
  final Value<int> readingTimeMs;
  final Value<int> pagesRead;
  final Value<int> lastStatisticModified;
  const ReadingStatisticsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.dateKey = const Value.absent(),
    this.charactersRead = const Value.absent(),
    this.readingTimeMs = const Value.absent(),
    this.pagesRead = const Value.absent(),
    this.lastStatisticModified = const Value.absent(),
  });
  ReadingStatisticsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required String dateKey,
    required int charactersRead,
    required int readingTimeMs,
    this.pagesRead = const Value.absent(),
    required int lastStatisticModified,
  }) : title = Value(title),
       dateKey = Value(dateKey),
       charactersRead = Value(charactersRead),
       readingTimeMs = Value(readingTimeMs),
       lastStatisticModified = Value(lastStatisticModified);
  static Insertable<ReadingStatisticRow> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? dateKey,
    Expression<int>? charactersRead,
    Expression<int>? readingTimeMs,
    Expression<int>? pagesRead,
    Expression<int>? lastStatisticModified,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (dateKey != null) 'date_key': dateKey,
      if (charactersRead != null) 'characters_read': charactersRead,
      if (readingTimeMs != null) 'reading_time_ms': readingTimeMs,
      if (pagesRead != null) 'pages_read': pagesRead,
      if (lastStatisticModified != null)
        'last_statistic_modified': lastStatisticModified,
    });
  }

  ReadingStatisticsCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? dateKey,
    Value<int>? charactersRead,
    Value<int>? readingTimeMs,
    Value<int>? pagesRead,
    Value<int>? lastStatisticModified,
  }) {
    return ReadingStatisticsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      dateKey: dateKey ?? this.dateKey,
      charactersRead: charactersRead ?? this.charactersRead,
      readingTimeMs: readingTimeMs ?? this.readingTimeMs,
      pagesRead: pagesRead ?? this.pagesRead,
      lastStatisticModified:
          lastStatisticModified ?? this.lastStatisticModified,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (dateKey.present) {
      map['date_key'] = Variable<String>(dateKey.value);
    }
    if (charactersRead.present) {
      map['characters_read'] = Variable<int>(charactersRead.value);
    }
    if (readingTimeMs.present) {
      map['reading_time_ms'] = Variable<int>(readingTimeMs.value);
    }
    if (pagesRead.present) {
      map['pages_read'] = Variable<int>(pagesRead.value);
    }
    if (lastStatisticModified.present) {
      map['last_statistic_modified'] = Variable<int>(
        lastStatisticModified.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingStatisticsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('dateKey: $dateKey, ')
          ..write('charactersRead: $charactersRead, ')
          ..write('readingTimeMs: $readingTimeMs, ')
          ..write('pagesRead: $pagesRead, ')
          ..write('lastStatisticModified: $lastStatisticModified')
          ..write(')'))
        .toString();
  }
}

class $ReadingHourlyLogsTable extends ReadingHourlyLogs
    with TableInfo<$ReadingHourlyLogsTable, ReadingHourlyLogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingHourlyLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dateKeyMeta = const VerificationMeta(
    'dateKey',
  );
  @override
  late final GeneratedColumn<String> dateKey = GeneratedColumn<String>(
    'date_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hourMeta = const VerificationMeta('hour');
  @override
  late final GeneratedColumn<int> hour = GeneratedColumn<int>(
    'hour',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readingTimeMsMeta = const VerificationMeta(
    'readingTimeMs',
  );
  @override
  late final GeneratedColumn<int> readingTimeMs = GeneratedColumn<int>(
    'reading_time_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    dateKey,
    hour,
    readingTimeMs,
    format,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_hourly_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingHourlyLogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date_key')) {
      context.handle(
        _dateKeyMeta,
        dateKey.isAcceptableOrUnknown(data['date_key']!, _dateKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dateKeyMeta);
    }
    if (data.containsKey('hour')) {
      context.handle(
        _hourMeta,
        hour.isAcceptableOrUnknown(data['hour']!, _hourMeta),
      );
    } else if (isInserting) {
      context.missing(_hourMeta);
    }
    if (data.containsKey('reading_time_ms')) {
      context.handle(
        _readingTimeMsMeta,
        readingTimeMs.isAcceptableOrUnknown(
          data['reading_time_ms']!,
          _readingTimeMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_readingTimeMsMeta);
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {dateKey, hour, format},
  ];
  @override
  ReadingHourlyLogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingHourlyLogRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      dateKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_key'],
      )!,
      hour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hour'],
      )!,
      readingTimeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reading_time_ms'],
      )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
    );
  }

  @override
  $ReadingHourlyLogsTable createAlias(String alias) {
    return $ReadingHourlyLogsTable(attachedDatabase, alias);
  }
}

class ReadingHourlyLogRow extends DataClass
    implements Insertable<ReadingHourlyLogRow> {
  final int id;
  final String dateKey;
  final int hour;
  final int readingTimeMs;

  /// v67：写入面身份（`BookFormat.dbValue`：'epub' / 'pdf' / 'manga'）。此前没有
  /// 任何身份列，EPUB / PDF / 漫画同一小时的时长在写入时就被加成一行，永久分不开；
  /// 日级 `reading_statistics` 靠 title→format 反查能拆，时段表拆不开只因缺这列。
  /// `''` = v67 前的历史行（写入时信息已丢，如实标未区分）以及云同步里旧端贡献的
  /// 无法归因差额（见 aggregate_sync_service 的 deficit-lift）。
  final String format;
  const ReadingHourlyLogRow({
    required this.id,
    required this.dateKey,
    required this.hour,
    required this.readingTimeMs,
    required this.format,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date_key'] = Variable<String>(dateKey);
    map['hour'] = Variable<int>(hour);
    map['reading_time_ms'] = Variable<int>(readingTimeMs);
    map['format'] = Variable<String>(format);
    return map;
  }

  ReadingHourlyLogsCompanion toCompanion(bool nullToAbsent) {
    return ReadingHourlyLogsCompanion(
      id: Value(id),
      dateKey: Value(dateKey),
      hour: Value(hour),
      readingTimeMs: Value(readingTimeMs),
      format: Value(format),
    );
  }

  factory ReadingHourlyLogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingHourlyLogRow(
      id: serializer.fromJson<int>(json['id']),
      dateKey: serializer.fromJson<String>(json['dateKey']),
      hour: serializer.fromJson<int>(json['hour']),
      readingTimeMs: serializer.fromJson<int>(json['readingTimeMs']),
      format: serializer.fromJson<String>(json['format']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'dateKey': serializer.toJson<String>(dateKey),
      'hour': serializer.toJson<int>(hour),
      'readingTimeMs': serializer.toJson<int>(readingTimeMs),
      'format': serializer.toJson<String>(format),
    };
  }

  ReadingHourlyLogRow copyWith({
    int? id,
    String? dateKey,
    int? hour,
    int? readingTimeMs,
    String? format,
  }) => ReadingHourlyLogRow(
    id: id ?? this.id,
    dateKey: dateKey ?? this.dateKey,
    hour: hour ?? this.hour,
    readingTimeMs: readingTimeMs ?? this.readingTimeMs,
    format: format ?? this.format,
  );
  ReadingHourlyLogRow copyWithCompanion(ReadingHourlyLogsCompanion data) {
    return ReadingHourlyLogRow(
      id: data.id.present ? data.id.value : this.id,
      dateKey: data.dateKey.present ? data.dateKey.value : this.dateKey,
      hour: data.hour.present ? data.hour.value : this.hour,
      readingTimeMs: data.readingTimeMs.present
          ? data.readingTimeMs.value
          : this.readingTimeMs,
      format: data.format.present ? data.format.value : this.format,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingHourlyLogRow(')
          ..write('id: $id, ')
          ..write('dateKey: $dateKey, ')
          ..write('hour: $hour, ')
          ..write('readingTimeMs: $readingTimeMs, ')
          ..write('format: $format')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, dateKey, hour, readingTimeMs, format);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingHourlyLogRow &&
          other.id == this.id &&
          other.dateKey == this.dateKey &&
          other.hour == this.hour &&
          other.readingTimeMs == this.readingTimeMs &&
          other.format == this.format);
}

class ReadingHourlyLogsCompanion extends UpdateCompanion<ReadingHourlyLogRow> {
  final Value<int> id;
  final Value<String> dateKey;
  final Value<int> hour;
  final Value<int> readingTimeMs;
  final Value<String> format;
  const ReadingHourlyLogsCompanion({
    this.id = const Value.absent(),
    this.dateKey = const Value.absent(),
    this.hour = const Value.absent(),
    this.readingTimeMs = const Value.absent(),
    this.format = const Value.absent(),
  });
  ReadingHourlyLogsCompanion.insert({
    this.id = const Value.absent(),
    required String dateKey,
    required int hour,
    required int readingTimeMs,
    this.format = const Value.absent(),
  }) : dateKey = Value(dateKey),
       hour = Value(hour),
       readingTimeMs = Value(readingTimeMs);
  static Insertable<ReadingHourlyLogRow> custom({
    Expression<int>? id,
    Expression<String>? dateKey,
    Expression<int>? hour,
    Expression<int>? readingTimeMs,
    Expression<String>? format,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dateKey != null) 'date_key': dateKey,
      if (hour != null) 'hour': hour,
      if (readingTimeMs != null) 'reading_time_ms': readingTimeMs,
      if (format != null) 'format': format,
    });
  }

  ReadingHourlyLogsCompanion copyWith({
    Value<int>? id,
    Value<String>? dateKey,
    Value<int>? hour,
    Value<int>? readingTimeMs,
    Value<String>? format,
  }) {
    return ReadingHourlyLogsCompanion(
      id: id ?? this.id,
      dateKey: dateKey ?? this.dateKey,
      hour: hour ?? this.hour,
      readingTimeMs: readingTimeMs ?? this.readingTimeMs,
      format: format ?? this.format,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (dateKey.present) {
      map['date_key'] = Variable<String>(dateKey.value);
    }
    if (hour.present) {
      map['hour'] = Variable<int>(hour.value);
    }
    if (readingTimeMs.present) {
      map['reading_time_ms'] = Variable<int>(readingTimeMs.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingHourlyLogsCompanion(')
          ..write('id: $id, ')
          ..write('dateKey: $dateKey, ')
          ..write('hour: $hour, ')
          ..write('readingTimeMs: $readingTimeMs, ')
          ..write('format: $format')
          ..write(')'))
        .toString();
  }
}

class $PreferencesTable extends Preferences
    with TableInfo<$PreferencesTable, PreferenceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<PreferenceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  PreferenceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PreferenceRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PreferencesTable createAlias(String alias) {
    return $PreferencesTable(attachedDatabase, alias);
  }
}

class PreferenceRow extends DataClass implements Insertable<PreferenceRow> {
  final String key;
  final String value;

  /// 该行最后一次写入的毫秒戳（v84 / BUG-1502）——**跨端 LWW 的比较键**。
  ///
  /// 绝大多数偏好是设备设置、从不跨端合并，这一列对它们只是无害的记账。它存在
  /// 是因为**有些偏好行是内容**：书的改名（`override_title://` 覆盖行，BUG-1488）
  /// 跟着书走、必须跨端合并，而 `preferences` 原先只有 key/value 两列，合并端
  /// 无从判断「谁更新」，只能退化成 insert-if-absent —— 母设备**第二次**改名
  /// 就传不到已有 override 的子设备了。
  ///
  /// **默认 0 = 「时刻未知」，是刻意的取舍**：v84 迁移不给存量行填迁移时刻。
  /// 填迁移时刻会让「谁赢」由两台设备各自的升级时间决定（后升级的一侧无条件
  /// 覆盖先升级的一侧，用户什么都没做却发生覆盖）；取 0 则存量行彼此平局，
  /// 而 LWW 的平局规则是「保留本机」——正好等于升级前的 insert-if-absent 行为，
  /// 零回归；任何一侧**真正改过一次名**之后（时刻 > 0）立刻胜出。同理，旧对端
  /// 发来的无时刻数据一律按 0 收，永远不会覆盖本机改过的名字。
  ///
  /// 写入方：[FushiDatabase.setPref] / `setPrefs` / `compareAndSetPref` 填
  /// `now`；跨端采纳走 [FushiDatabase.setPrefIfNewer]，**填对端的时刻而不是
  /// now**（填 now 会让本机永远最新，母设备的下一次改名再也传不进来）。
  final int updatedAt;
  const PreferenceRow({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  PreferencesCompanion toCompanion(bool nullToAbsent) {
    return PreferencesCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory PreferenceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PreferenceRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  PreferenceRow copyWith({String? key, String? value, int? updatedAt}) =>
      PreferenceRow(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  PreferenceRow copyWithCompanion(PreferencesCompanion data) {
    return PreferenceRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PreferenceRow(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PreferenceRow &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class PreferencesCompanion extends UpdateCompanion<PreferenceRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const PreferencesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PreferencesCompanion.insert({
    required String key,
    required String value,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<PreferenceRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PreferencesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return PreferencesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PreferencesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EpubBooksTable extends EpubBooks
    with TableInfo<$EpubBooksTable, EpubBookRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpubBooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookKeyMeta = const VerificationMeta(
    'bookKey',
  );
  @override
  late final GeneratedColumn<String> bookKey = GeneratedColumn<String>(
    'book_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
    'uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta(
    'coverPath',
  );
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _epubPathMeta = const VerificationMeta(
    'epubPath',
  );
  @override
  late final GeneratedColumn<String> epubPath = GeneratedColumn<String>(
    'epub_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _extractDirMeta = const VerificationMeta(
    'extractDir',
  );
  @override
  late final GeneratedColumn<String> extractDir = GeneratedColumn<String>(
    'extract_dir',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterCountMeta = const VerificationMeta(
    'chapterCount',
  );
  @override
  late final GeneratedColumn<int> chapterCount = GeneratedColumn<int>(
    'chapter_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chaptersJsonMeta = const VerificationMeta(
    'chaptersJson',
  );
  @override
  late final GeneratedColumn<String> chaptersJson = GeneratedColumn<String>(
    'chapters_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tocJsonMeta = const VerificationMeta(
    'tocJson',
  );
  @override
  late final GeneratedColumn<String> tocJson = GeneratedColumn<String>(
    'toc_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMetadataMeta = const VerificationMeta(
    'sourceMetadata',
  );
  @override
  late final GeneratedColumn<String> sourceMetadata = GeneratedColumn<String>(
    'source_metadata',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<int> importedAt = GeneratedColumn<int>(
    'imported_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('epub'),
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isbnMeta = const VerificationMeta('isbn');
  @override
  late final GeneratedColumn<String> isbn = GeneratedColumn<String>(
    'isbn',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    bookKey,
    uid,
    title,
    author,
    coverPath,
    epubPath,
    extractDir,
    chapterCount,
    chaptersJson,
    tocJson,
    sourceMetadata,
    importedAt,
    language,
    format,
    completedAt,
    isbn,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'epub_books';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpubBookRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_key')) {
      context.handle(
        _bookKeyMeta,
        bookKey.isAcceptableOrUnknown(data['book_key']!, _bookKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_bookKeyMeta);
    }
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('epub_path')) {
      context.handle(
        _epubPathMeta,
        epubPath.isAcceptableOrUnknown(data['epub_path']!, _epubPathMeta),
      );
    } else if (isInserting) {
      context.missing(_epubPathMeta);
    }
    if (data.containsKey('extract_dir')) {
      context.handle(
        _extractDirMeta,
        extractDir.isAcceptableOrUnknown(data['extract_dir']!, _extractDirMeta),
      );
    } else if (isInserting) {
      context.missing(_extractDirMeta);
    }
    if (data.containsKey('chapter_count')) {
      context.handle(
        _chapterCountMeta,
        chapterCount.isAcceptableOrUnknown(
          data['chapter_count']!,
          _chapterCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chapterCountMeta);
    }
    if (data.containsKey('chapters_json')) {
      context.handle(
        _chaptersJsonMeta,
        chaptersJson.isAcceptableOrUnknown(
          data['chapters_json']!,
          _chaptersJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chaptersJsonMeta);
    }
    if (data.containsKey('toc_json')) {
      context.handle(
        _tocJsonMeta,
        tocJson.isAcceptableOrUnknown(data['toc_json']!, _tocJsonMeta),
      );
    }
    if (data.containsKey('source_metadata')) {
      context.handle(
        _sourceMetadataMeta,
        sourceMetadata.isAcceptableOrUnknown(
          data['source_metadata']!,
          _sourceMetadataMeta,
        ),
      );
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_importedAtMeta);
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('isbn')) {
      context.handle(
        _isbnMeta,
        isbn.isAcceptableOrUnknown(data['isbn']!, _isbnMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookKey};
  @override
  EpubBookRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpubBookRow(
      bookKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_key'],
      )!,
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uid'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      epubPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}epub_path'],
      )!,
      extractDir: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extract_dir'],
      )!,
      chapterCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_count'],
      )!,
      chaptersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapters_json'],
      )!,
      tocJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}toc_json'],
      ),
      sourceMetadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_metadata'],
      ),
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}imported_at'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      ),
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      isbn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}isbn'],
      ),
    );
  }

  @override
  $EpubBooksTable createAlias(String alias) {
    return $EpubBooksTable(attachedDatabase, alias);
  }
}

class EpubBookRow extends DataClass implements Insertable<EpubBookRow> {
  final String bookKey;

  /// v81（P3 Stage 1，数据层重构 2026-08）：书的**本机稳定身份**。bookKey 由
  /// 用户可见可改的标题派生（改名 = 身份变 = 十来张子表连坐改键，这正是它当
  /// 头号根因的原因）；本列是导入时生成一次、此后永不变的机器局域 uid
  /// （`book_<rowid/时刻>` 形，[generateEpubBookUid]），为后续把
  /// ReaderPositions/Bookmarks/RevealedImages/BookCustomCss 等子表键切过来
  /// （Stage 1b）与最终支持改名铺地基——v39 给视频先落 bookUid 列、v76 展示层
  /// 才收尾的同款两步走。**wire/sync/备份仍走 bookKey**（title 派生键契约冻
  /// 结），本列不进 wire；跨库合并经 bookKey 对齐后各自保留本机 uid。
  /// 唯一性由独立唯一索引保证（迁移路径 ADD COLUMN 不能带 UNIQUE）；插入时
  /// 未携带则由 [insertEpubBook] 单点自动生成，调用方零改动。
  final String uid;
  final String title;
  final String? author;
  final String? coverPath;
  final String epubPath;
  final String extractDir;
  final int chapterCount;
  final String chaptersJson;
  final String? tocJson;
  final String? sourceMetadata;
  final int importedAt;

  /// v87：书的内容语言（BCP-47，如 `ja` / `zh-Hant`），决定正文用哪条字体链。
  ///
  /// 导入时从 EPUB OPF 的 `dc:language` 回填（`EpubParser` 早就解析出来了，此前
  /// 无人消费）；用户可在书籍设置里手动改，手动值压过自动值。null = 既没解析到
  /// 也没指定 → 阅读器不写 `font-family`，保持浏览器默认（不猜，见
  /// `content_font_chain.dart`）。
  final String? language;

  /// 书身份格式判别（PDF 阅读器 Phase 1）：`'epub'`（默认，含 EPUB / TextToEpub /
  /// 有声书配对壳）、`'pdf'`（pdfrx 渲染的真 PDF）或 `'manga'`（漫画 OCR，第三种书）。
  /// 默认 `'epub'` 让既有全部行零破坏（Never break userspace，v51 迁移 addColumn 自动
  /// 回填），书架/进度/删除按此列区分而非另建平行表。PDF 行：`format='pdf'`、
  /// `epubPath`=PDF 绝对路径、`extractDir`=占位、`chapterCount`=页数、`chaptersJson`=`'[]'`。
  final String format;

  /// 书「读完」的时间戳（用户手动标记，或读到全书末尾自动写入）；null = 未完成。
  /// 镜像 [VideoBooks.completedAt]，书架概览「Completed」统计用。跳过后记/附录的
  /// 读者靠手动标记即可计入完成，不再受「必须读到最后一字」限制。
  final DateTime? completedAt;

  /// v115（排行榜作品匹配）：OPF `dc:identifier` 里解析出的 ISBN，**统一存 ISBN-13**
  /// （ISBN-10 转换后存），校验位不对的一律不存。null = 包里没有合法 ISBN、或是
  /// v115 前导入且尚未回填（`backfillEpubIsbns` 只读 OPF 回填，不重新导入）。
  /// 规范化唯一口径见 `fushi_engine/epub/isbn.dart` 的 `normalizeIsbn13`。
  final String? isbn;
  const EpubBookRow({
    required this.bookKey,
    required this.uid,
    required this.title,
    this.author,
    this.coverPath,
    required this.epubPath,
    required this.extractDir,
    required this.chapterCount,
    required this.chaptersJson,
    this.tocJson,
    this.sourceMetadata,
    required this.importedAt,
    this.language,
    required this.format,
    this.completedAt,
    this.isbn,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_key'] = Variable<String>(bookKey);
    map['uid'] = Variable<String>(uid);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    map['epub_path'] = Variable<String>(epubPath);
    map['extract_dir'] = Variable<String>(extractDir);
    map['chapter_count'] = Variable<int>(chapterCount);
    map['chapters_json'] = Variable<String>(chaptersJson);
    if (!nullToAbsent || tocJson != null) {
      map['toc_json'] = Variable<String>(tocJson);
    }
    if (!nullToAbsent || sourceMetadata != null) {
      map['source_metadata'] = Variable<String>(sourceMetadata);
    }
    map['imported_at'] = Variable<int>(importedAt);
    if (!nullToAbsent || language != null) {
      map['language'] = Variable<String>(language);
    }
    map['format'] = Variable<String>(format);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || isbn != null) {
      map['isbn'] = Variable<String>(isbn);
    }
    return map;
  }

  EpubBooksCompanion toCompanion(bool nullToAbsent) {
    return EpubBooksCompanion(
      bookKey: Value(bookKey),
      uid: Value(uid),
      title: Value(title),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      coverPath: coverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPath),
      epubPath: Value(epubPath),
      extractDir: Value(extractDir),
      chapterCount: Value(chapterCount),
      chaptersJson: Value(chaptersJson),
      tocJson: tocJson == null && nullToAbsent
          ? const Value.absent()
          : Value(tocJson),
      sourceMetadata: sourceMetadata == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceMetadata),
      importedAt: Value(importedAt),
      language: language == null && nullToAbsent
          ? const Value.absent()
          : Value(language),
      format: Value(format),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      isbn: isbn == null && nullToAbsent ? const Value.absent() : Value(isbn),
    );
  }

  factory EpubBookRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpubBookRow(
      bookKey: serializer.fromJson<String>(json['bookKey']),
      uid: serializer.fromJson<String>(json['uid']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String?>(json['author']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      epubPath: serializer.fromJson<String>(json['epubPath']),
      extractDir: serializer.fromJson<String>(json['extractDir']),
      chapterCount: serializer.fromJson<int>(json['chapterCount']),
      chaptersJson: serializer.fromJson<String>(json['chaptersJson']),
      tocJson: serializer.fromJson<String?>(json['tocJson']),
      sourceMetadata: serializer.fromJson<String?>(json['sourceMetadata']),
      importedAt: serializer.fromJson<int>(json['importedAt']),
      language: serializer.fromJson<String?>(json['language']),
      format: serializer.fromJson<String>(json['format']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      isbn: serializer.fromJson<String?>(json['isbn']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookKey': serializer.toJson<String>(bookKey),
      'uid': serializer.toJson<String>(uid),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String?>(author),
      'coverPath': serializer.toJson<String?>(coverPath),
      'epubPath': serializer.toJson<String>(epubPath),
      'extractDir': serializer.toJson<String>(extractDir),
      'chapterCount': serializer.toJson<int>(chapterCount),
      'chaptersJson': serializer.toJson<String>(chaptersJson),
      'tocJson': serializer.toJson<String?>(tocJson),
      'sourceMetadata': serializer.toJson<String?>(sourceMetadata),
      'importedAt': serializer.toJson<int>(importedAt),
      'language': serializer.toJson<String?>(language),
      'format': serializer.toJson<String>(format),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'isbn': serializer.toJson<String?>(isbn),
    };
  }

  EpubBookRow copyWith({
    String? bookKey,
    String? uid,
    String? title,
    Value<String?> author = const Value.absent(),
    Value<String?> coverPath = const Value.absent(),
    String? epubPath,
    String? extractDir,
    int? chapterCount,
    String? chaptersJson,
    Value<String?> tocJson = const Value.absent(),
    Value<String?> sourceMetadata = const Value.absent(),
    int? importedAt,
    Value<String?> language = const Value.absent(),
    String? format,
    Value<DateTime?> completedAt = const Value.absent(),
    Value<String?> isbn = const Value.absent(),
  }) => EpubBookRow(
    bookKey: bookKey ?? this.bookKey,
    uid: uid ?? this.uid,
    title: title ?? this.title,
    author: author.present ? author.value : this.author,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    epubPath: epubPath ?? this.epubPath,
    extractDir: extractDir ?? this.extractDir,
    chapterCount: chapterCount ?? this.chapterCount,
    chaptersJson: chaptersJson ?? this.chaptersJson,
    tocJson: tocJson.present ? tocJson.value : this.tocJson,
    sourceMetadata: sourceMetadata.present
        ? sourceMetadata.value
        : this.sourceMetadata,
    importedAt: importedAt ?? this.importedAt,
    language: language.present ? language.value : this.language,
    format: format ?? this.format,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    isbn: isbn.present ? isbn.value : this.isbn,
  );
  EpubBookRow copyWithCompanion(EpubBooksCompanion data) {
    return EpubBookRow(
      bookKey: data.bookKey.present ? data.bookKey.value : this.bookKey,
      uid: data.uid.present ? data.uid.value : this.uid,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      epubPath: data.epubPath.present ? data.epubPath.value : this.epubPath,
      extractDir: data.extractDir.present
          ? data.extractDir.value
          : this.extractDir,
      chapterCount: data.chapterCount.present
          ? data.chapterCount.value
          : this.chapterCount,
      chaptersJson: data.chaptersJson.present
          ? data.chaptersJson.value
          : this.chaptersJson,
      tocJson: data.tocJson.present ? data.tocJson.value : this.tocJson,
      sourceMetadata: data.sourceMetadata.present
          ? data.sourceMetadata.value
          : this.sourceMetadata,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
      language: data.language.present ? data.language.value : this.language,
      format: data.format.present ? data.format.value : this.format,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      isbn: data.isbn.present ? data.isbn.value : this.isbn,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpubBookRow(')
          ..write('bookKey: $bookKey, ')
          ..write('uid: $uid, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('coverPath: $coverPath, ')
          ..write('epubPath: $epubPath, ')
          ..write('extractDir: $extractDir, ')
          ..write('chapterCount: $chapterCount, ')
          ..write('chaptersJson: $chaptersJson, ')
          ..write('tocJson: $tocJson, ')
          ..write('sourceMetadata: $sourceMetadata, ')
          ..write('importedAt: $importedAt, ')
          ..write('language: $language, ')
          ..write('format: $format, ')
          ..write('completedAt: $completedAt, ')
          ..write('isbn: $isbn')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    bookKey,
    uid,
    title,
    author,
    coverPath,
    epubPath,
    extractDir,
    chapterCount,
    chaptersJson,
    tocJson,
    sourceMetadata,
    importedAt,
    language,
    format,
    completedAt,
    isbn,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpubBookRow &&
          other.bookKey == this.bookKey &&
          other.uid == this.uid &&
          other.title == this.title &&
          other.author == this.author &&
          other.coverPath == this.coverPath &&
          other.epubPath == this.epubPath &&
          other.extractDir == this.extractDir &&
          other.chapterCount == this.chapterCount &&
          other.chaptersJson == this.chaptersJson &&
          other.tocJson == this.tocJson &&
          other.sourceMetadata == this.sourceMetadata &&
          other.importedAt == this.importedAt &&
          other.language == this.language &&
          other.format == this.format &&
          other.completedAt == this.completedAt &&
          other.isbn == this.isbn);
}

class EpubBooksCompanion extends UpdateCompanion<EpubBookRow> {
  final Value<String> bookKey;
  final Value<String> uid;
  final Value<String> title;
  final Value<String?> author;
  final Value<String?> coverPath;
  final Value<String> epubPath;
  final Value<String> extractDir;
  final Value<int> chapterCount;
  final Value<String> chaptersJson;
  final Value<String?> tocJson;
  final Value<String?> sourceMetadata;
  final Value<int> importedAt;
  final Value<String?> language;
  final Value<String> format;
  final Value<DateTime?> completedAt;
  final Value<String?> isbn;
  final Value<int> rowid;
  const EpubBooksCompanion({
    this.bookKey = const Value.absent(),
    this.uid = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.epubPath = const Value.absent(),
    this.extractDir = const Value.absent(),
    this.chapterCount = const Value.absent(),
    this.chaptersJson = const Value.absent(),
    this.tocJson = const Value.absent(),
    this.sourceMetadata = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.language = const Value.absent(),
    this.format = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.isbn = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EpubBooksCompanion.insert({
    required String bookKey,
    this.uid = const Value.absent(),
    required String title,
    this.author = const Value.absent(),
    this.coverPath = const Value.absent(),
    required String epubPath,
    required String extractDir,
    required int chapterCount,
    required String chaptersJson,
    this.tocJson = const Value.absent(),
    this.sourceMetadata = const Value.absent(),
    required int importedAt,
    this.language = const Value.absent(),
    this.format = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.isbn = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : bookKey = Value(bookKey),
       title = Value(title),
       epubPath = Value(epubPath),
       extractDir = Value(extractDir),
       chapterCount = Value(chapterCount),
       chaptersJson = Value(chaptersJson),
       importedAt = Value(importedAt);
  static Insertable<EpubBookRow> custom({
    Expression<String>? bookKey,
    Expression<String>? uid,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? coverPath,
    Expression<String>? epubPath,
    Expression<String>? extractDir,
    Expression<int>? chapterCount,
    Expression<String>? chaptersJson,
    Expression<String>? tocJson,
    Expression<String>? sourceMetadata,
    Expression<int>? importedAt,
    Expression<String>? language,
    Expression<String>? format,
    Expression<DateTime>? completedAt,
    Expression<String>? isbn,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookKey != null) 'book_key': bookKey,
      if (uid != null) 'uid': uid,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (coverPath != null) 'cover_path': coverPath,
      if (epubPath != null) 'epub_path': epubPath,
      if (extractDir != null) 'extract_dir': extractDir,
      if (chapterCount != null) 'chapter_count': chapterCount,
      if (chaptersJson != null) 'chapters_json': chaptersJson,
      if (tocJson != null) 'toc_json': tocJson,
      if (sourceMetadata != null) 'source_metadata': sourceMetadata,
      if (importedAt != null) 'imported_at': importedAt,
      if (language != null) 'language': language,
      if (format != null) 'format': format,
      if (completedAt != null) 'completed_at': completedAt,
      if (isbn != null) 'isbn': isbn,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EpubBooksCompanion copyWith({
    Value<String>? bookKey,
    Value<String>? uid,
    Value<String>? title,
    Value<String?>? author,
    Value<String?>? coverPath,
    Value<String>? epubPath,
    Value<String>? extractDir,
    Value<int>? chapterCount,
    Value<String>? chaptersJson,
    Value<String?>? tocJson,
    Value<String?>? sourceMetadata,
    Value<int>? importedAt,
    Value<String?>? language,
    Value<String>? format,
    Value<DateTime?>? completedAt,
    Value<String?>? isbn,
    Value<int>? rowid,
  }) {
    return EpubBooksCompanion(
      bookKey: bookKey ?? this.bookKey,
      uid: uid ?? this.uid,
      title: title ?? this.title,
      author: author ?? this.author,
      coverPath: coverPath ?? this.coverPath,
      epubPath: epubPath ?? this.epubPath,
      extractDir: extractDir ?? this.extractDir,
      chapterCount: chapterCount ?? this.chapterCount,
      chaptersJson: chaptersJson ?? this.chaptersJson,
      tocJson: tocJson ?? this.tocJson,
      sourceMetadata: sourceMetadata ?? this.sourceMetadata,
      importedAt: importedAt ?? this.importedAt,
      language: language ?? this.language,
      format: format ?? this.format,
      completedAt: completedAt ?? this.completedAt,
      isbn: isbn ?? this.isbn,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookKey.present) {
      map['book_key'] = Variable<String>(bookKey.value);
    }
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (epubPath.present) {
      map['epub_path'] = Variable<String>(epubPath.value);
    }
    if (extractDir.present) {
      map['extract_dir'] = Variable<String>(extractDir.value);
    }
    if (chapterCount.present) {
      map['chapter_count'] = Variable<int>(chapterCount.value);
    }
    if (chaptersJson.present) {
      map['chapters_json'] = Variable<String>(chaptersJson.value);
    }
    if (tocJson.present) {
      map['toc_json'] = Variable<String>(tocJson.value);
    }
    if (sourceMetadata.present) {
      map['source_metadata'] = Variable<String>(sourceMetadata.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<int>(importedAt.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (isbn.present) {
      map['isbn'] = Variable<String>(isbn.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpubBooksCompanion(')
          ..write('bookKey: $bookKey, ')
          ..write('uid: $uid, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('coverPath: $coverPath, ')
          ..write('epubPath: $epubPath, ')
          ..write('extractDir: $extractDir, ')
          ..write('chapterCount: $chapterCount, ')
          ..write('chaptersJson: $chaptersJson, ')
          ..write('tocJson: $tocJson, ')
          ..write('sourceMetadata: $sourceMetadata, ')
          ..write('importedAt: $importedAt, ')
          ..write('language: $language, ')
          ..write('format: $format, ')
          ..write('completedAt: $completedAt, ')
          ..write('isbn: $isbn, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookTagsTable extends BookTags
    with TableInfo<$BookTagsTable, BookTagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xFF9E9E9E),
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
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    colorValue,
    sortOrder,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookTagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookTagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookTagRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BookTagsTable createAlias(String alias) {
    return $BookTagsTable(attachedDatabase, alias);
  }
}

class BookTagRow extends DataClass implements Insertable<BookTagRow> {
  final int id;
  final String name;
  final int colorValue;
  final int sortOrder;
  final int createdAt;
  const BookTagRow({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['color_value'] = Variable<int>(colorValue);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  BookTagsCompanion toCompanion(bool nullToAbsent) {
    return BookTagsCompanion(
      id: Value(id),
      name: Value(name),
      colorValue: Value(colorValue),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory BookTagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookTagRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'colorValue': serializer.toJson<int>(colorValue),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  BookTagRow copyWith({
    int? id,
    String? name,
    int? colorValue,
    int? sortOrder,
    int? createdAt,
  }) => BookTagRow(
    id: id ?? this.id,
    name: name ?? this.name,
    colorValue: colorValue ?? this.colorValue,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  BookTagRow copyWithCompanion(BookTagsCompanion data) {
    return BookTagRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookTagRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, colorValue, sortOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookTagRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorValue == this.colorValue &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class BookTagsCompanion extends UpdateCompanion<BookTagRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> colorValue;
  final Value<int> sortOrder;
  final Value<int> createdAt;
  const BookTagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  BookTagsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.colorValue = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required int createdAt,
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<BookTagRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? colorValue,
    Expression<int>? sortOrder,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorValue != null) 'color_value': colorValue,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  BookTagsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? colorValue,
    Value<int>? sortOrder,
    Value<int>? createdAt,
  }) {
    return BookTagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookTagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $TagAssignmentsTable extends TagAssignments
    with TableInfo<$TagAssignmentsTable, TagAssignmentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagAssignmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mediaKindMeta = const VerificationMeta(
    'mediaKind',
  );
  @override
  late final GeneratedColumn<String> mediaKind = GeneratedColumn<String>(
    'media_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entryKeyMeta = const VerificationMeta(
    'entryKey',
  );
  @override
  late final GeneratedColumn<String> entryKey = GeneratedColumn<String>(
    'entry_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<int> tagId = GeneratedColumn<int>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES book_tags (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [mediaKind, entryKey, tagId, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tag_assignments';
  @override
  VerificationContext validateIntegrity(
    Insertable<TagAssignmentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('media_kind')) {
      context.handle(
        _mediaKindMeta,
        mediaKind.isAcceptableOrUnknown(data['media_kind']!, _mediaKindMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaKindMeta);
    }
    if (data.containsKey('entry_key')) {
      context.handle(
        _entryKeyMeta,
        entryKey.isAcceptableOrUnknown(data['entry_key']!, _entryKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_entryKeyMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mediaKind, entryKey, tagId};
  @override
  TagAssignmentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagAssignmentRow(
      mediaKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_kind'],
      )!,
      entryKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_key'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tag_id'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $TagAssignmentsTable createAlias(String alias) {
    return $TagAssignmentsTable(attachedDatabase, alias);
  }
}

class TagAssignmentRow extends DataClass
    implements Insertable<TagAssignmentRow> {
  /// 宿主种类：'epub' | 'srt' | 'video' | 'collection' | 'game'。
  final String mediaKind;

  /// 宿主稳定身份（值域见类 doc）。
  final String entryKey;
  final int tagId;

  /// 该映射被加入的毫秒戳（epub/video 域是 LWW-element-set 的 add 时钟——与
  /// [BookTagMembershipTombstones].deletedAt 比较决定 add-wins/remove-wins）。
  final int addedAt;
  const TagAssignmentRow({
    required this.mediaKind,
    required this.entryKey,
    required this.tagId,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['media_kind'] = Variable<String>(mediaKind);
    map['entry_key'] = Variable<String>(entryKey);
    map['tag_id'] = Variable<int>(tagId);
    map['added_at'] = Variable<int>(addedAt);
    return map;
  }

  TagAssignmentsCompanion toCompanion(bool nullToAbsent) {
    return TagAssignmentsCompanion(
      mediaKind: Value(mediaKind),
      entryKey: Value(entryKey),
      tagId: Value(tagId),
      addedAt: Value(addedAt),
    );
  }

  factory TagAssignmentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagAssignmentRow(
      mediaKind: serializer.fromJson<String>(json['mediaKind']),
      entryKey: serializer.fromJson<String>(json['entryKey']),
      tagId: serializer.fromJson<int>(json['tagId']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mediaKind': serializer.toJson<String>(mediaKind),
      'entryKey': serializer.toJson<String>(entryKey),
      'tagId': serializer.toJson<int>(tagId),
      'addedAt': serializer.toJson<int>(addedAt),
    };
  }

  TagAssignmentRow copyWith({
    String? mediaKind,
    String? entryKey,
    int? tagId,
    int? addedAt,
  }) => TagAssignmentRow(
    mediaKind: mediaKind ?? this.mediaKind,
    entryKey: entryKey ?? this.entryKey,
    tagId: tagId ?? this.tagId,
    addedAt: addedAt ?? this.addedAt,
  );
  TagAssignmentRow copyWithCompanion(TagAssignmentsCompanion data) {
    return TagAssignmentRow(
      mediaKind: data.mediaKind.present ? data.mediaKind.value : this.mediaKind,
      entryKey: data.entryKey.present ? data.entryKey.value : this.entryKey,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TagAssignmentRow(')
          ..write('mediaKind: $mediaKind, ')
          ..write('entryKey: $entryKey, ')
          ..write('tagId: $tagId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(mediaKind, entryKey, tagId, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagAssignmentRow &&
          other.mediaKind == this.mediaKind &&
          other.entryKey == this.entryKey &&
          other.tagId == this.tagId &&
          other.addedAt == this.addedAt);
}

class TagAssignmentsCompanion extends UpdateCompanion<TagAssignmentRow> {
  final Value<String> mediaKind;
  final Value<String> entryKey;
  final Value<int> tagId;
  final Value<int> addedAt;
  final Value<int> rowid;
  const TagAssignmentsCompanion({
    this.mediaKind = const Value.absent(),
    this.entryKey = const Value.absent(),
    this.tagId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagAssignmentsCompanion.insert({
    required String mediaKind,
    required String entryKey,
    required int tagId,
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : mediaKind = Value(mediaKind),
       entryKey = Value(entryKey),
       tagId = Value(tagId);
  static Insertable<TagAssignmentRow> custom({
    Expression<String>? mediaKind,
    Expression<String>? entryKey,
    Expression<int>? tagId,
    Expression<int>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mediaKind != null) 'media_kind': mediaKind,
      if (entryKey != null) 'entry_key': entryKey,
      if (tagId != null) 'tag_id': tagId,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagAssignmentsCompanion copyWith({
    Value<String>? mediaKind,
    Value<String>? entryKey,
    Value<int>? tagId,
    Value<int>? addedAt,
    Value<int>? rowid,
  }) {
    return TagAssignmentsCompanion(
      mediaKind: mediaKind ?? this.mediaKind,
      entryKey: entryKey ?? this.entryKey,
      tagId: tagId ?? this.tagId,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mediaKind.present) {
      map['media_kind'] = Variable<String>(mediaKind.value);
    }
    if (entryKey.present) {
      map['entry_key'] = Variable<String>(entryKey.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<int>(tagId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagAssignmentsCompanion(')
          ..write('mediaKind: $mediaKind, ')
          ..write('entryKey: $entryKey, ')
          ..write('tagId: $tagId, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProfilesTable extends Profiles
    with TableInfo<$ProfilesTable, ProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }
}

class ProfileRow extends DataClass implements Insertable<ProfileRow> {
  final int id;
  final String name;
  final int createdAt;
  final int updatedAt;
  const ProfileRow({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProfileRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ProfileRow copyWith({
    int? id,
    String? name,
    int? createdAt,
    int? updatedAt,
  }) => ProfileRow(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ProfileRow copyWithCompanion(ProfilesCompanion data) {
    return ProfileRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProfileRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ProfilesCompanion extends UpdateCompanion<ProfileRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ProfilesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int createdAt,
    required int updatedAt,
  }) : name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ProfileRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ProfilesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? createdAt,
    Value<int>? updatedAt,
  }) {
    return ProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ProfileSettingsTable extends ProfileSettings
    with TableInfo<$ProfileSettingsTable, ProfileSettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfileSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES profiles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, profileId, category, key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profile_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProfileSettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {profileId, category, key},
  ];
  @override
  ProfileSettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProfileSettingRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $ProfileSettingsTable createAlias(String alias) {
    return $ProfileSettingsTable(attachedDatabase, alias);
  }
}

class ProfileSettingRow extends DataClass
    implements Insertable<ProfileSettingRow> {
  final int id;
  final int profileId;
  final String category;
  final String key;
  final String value;
  const ProfileSettingRow({
    required this.id,
    required this.profileId,
    required this.category,
    required this.key,
    required this.value,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<int>(profileId);
    map['category'] = Variable<String>(category);
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  ProfileSettingsCompanion toCompanion(bool nullToAbsent) {
    return ProfileSettingsCompanion(
      id: Value(id),
      profileId: Value(profileId),
      category: Value(category),
      key: Value(key),
      value: Value(value),
    );
  }

  factory ProfileSettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProfileSettingRow(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<int>(json['profileId']),
      category: serializer.fromJson<String>(json['category']),
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<int>(profileId),
      'category': serializer.toJson<String>(category),
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  ProfileSettingRow copyWith({
    int? id,
    int? profileId,
    String? category,
    String? key,
    String? value,
  }) => ProfileSettingRow(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    category: category ?? this.category,
    key: key ?? this.key,
    value: value ?? this.value,
  );
  ProfileSettingRow copyWithCompanion(ProfileSettingsCompanion data) {
    return ProfileSettingRow(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      category: data.category.present ? data.category.value : this.category,
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProfileSettingRow(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('category: $category, ')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, profileId, category, key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileSettingRow &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.category == this.category &&
          other.key == this.key &&
          other.value == this.value);
}

class ProfileSettingsCompanion extends UpdateCompanion<ProfileSettingRow> {
  final Value<int> id;
  final Value<int> profileId;
  final Value<String> category;
  final Value<String> key;
  final Value<String> value;
  const ProfileSettingsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.category = const Value.absent(),
    this.key = const Value.absent(),
    this.value = const Value.absent(),
  });
  ProfileSettingsCompanion.insert({
    this.id = const Value.absent(),
    required int profileId,
    required String category,
    required String key,
    required String value,
  }) : profileId = Value(profileId),
       category = Value(category),
       key = Value(key),
       value = Value(value);
  static Insertable<ProfileSettingRow> custom({
    Expression<int>? id,
    Expression<int>? profileId,
    Expression<String>? category,
    Expression<String>? key,
    Expression<String>? value,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (category != null) 'category': category,
      if (key != null) 'key': key,
      if (value != null) 'value': value,
    });
  }

  ProfileSettingsCompanion copyWith({
    Value<int>? id,
    Value<int>? profileId,
    Value<String>? category,
    Value<String>? key,
    Value<String>? value,
  }) {
    return ProfileSettingsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      category: category ?? this.category,
      key: key ?? this.key,
      value: value ?? this.value,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfileSettingsCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('category: $category, ')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }
}

class $MediaTypeProfilesTable extends MediaTypeProfiles
    with TableInfo<$MediaTypeProfilesTable, MediaTypeProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaTypeProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mediaTypeMeta = const VerificationMeta(
    'mediaType',
  );
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
    'media_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES profiles (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [mediaType, profileId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_type_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<MediaTypeProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('media_type')) {
      context.handle(
        _mediaTypeMeta,
        mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaTypeMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mediaType};
  @override
  MediaTypeProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaTypeProfileRow(
      mediaType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_type'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
    );
  }

  @override
  $MediaTypeProfilesTable createAlias(String alias) {
    return $MediaTypeProfilesTable(attachedDatabase, alias);
  }
}

class MediaTypeProfileRow extends DataClass
    implements Insertable<MediaTypeProfileRow> {
  final String mediaType;
  final int profileId;
  const MediaTypeProfileRow({required this.mediaType, required this.profileId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['media_type'] = Variable<String>(mediaType);
    map['profile_id'] = Variable<int>(profileId);
    return map;
  }

  MediaTypeProfilesCompanion toCompanion(bool nullToAbsent) {
    return MediaTypeProfilesCompanion(
      mediaType: Value(mediaType),
      profileId: Value(profileId),
    );
  }

  factory MediaTypeProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaTypeProfileRow(
      mediaType: serializer.fromJson<String>(json['mediaType']),
      profileId: serializer.fromJson<int>(json['profileId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mediaType': serializer.toJson<String>(mediaType),
      'profileId': serializer.toJson<int>(profileId),
    };
  }

  MediaTypeProfileRow copyWith({String? mediaType, int? profileId}) =>
      MediaTypeProfileRow(
        mediaType: mediaType ?? this.mediaType,
        profileId: profileId ?? this.profileId,
      );
  MediaTypeProfileRow copyWithCompanion(MediaTypeProfilesCompanion data) {
    return MediaTypeProfileRow(
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaTypeProfileRow(')
          ..write('mediaType: $mediaType, ')
          ..write('profileId: $profileId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(mediaType, profileId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaTypeProfileRow &&
          other.mediaType == this.mediaType &&
          other.profileId == this.profileId);
}

class MediaTypeProfilesCompanion extends UpdateCompanion<MediaTypeProfileRow> {
  final Value<String> mediaType;
  final Value<int> profileId;
  final Value<int> rowid;
  const MediaTypeProfilesCompanion({
    this.mediaType = const Value.absent(),
    this.profileId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaTypeProfilesCompanion.insert({
    required String mediaType,
    required int profileId,
    this.rowid = const Value.absent(),
  }) : mediaType = Value(mediaType),
       profileId = Value(profileId);
  static Insertable<MediaTypeProfileRow> custom({
    Expression<String>? mediaType,
    Expression<int>? profileId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mediaType != null) 'media_type': mediaType,
      if (profileId != null) 'profile_id': profileId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaTypeProfilesCompanion copyWith({
    Value<String>? mediaType,
    Value<int>? profileId,
    Value<int>? rowid,
  }) {
    return MediaTypeProfilesCompanion(
      mediaType: mediaType ?? this.mediaType,
      profileId: profileId ?? this.profileId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaTypeProfilesCompanion(')
          ..write('mediaType: $mediaType, ')
          ..write('profileId: $profileId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookProfilesTable extends BookProfiles
    with TableInfo<$BookProfilesTable, BookProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookKeyMeta = const VerificationMeta(
    'bookKey',
  );
  @override
  late final GeneratedColumn<String> bookKey = GeneratedColumn<String>(
    'book_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES profiles (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [bookKey, profileId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_key')) {
      context.handle(
        _bookKeyMeta,
        bookKey.isAcceptableOrUnknown(data['book_key']!, _bookKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_bookKeyMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookKey};
  @override
  BookProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookProfileRow(
      bookKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_key'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
    );
  }

  @override
  $BookProfilesTable createAlias(String alias) {
    return $BookProfilesTable(attachedDatabase, alias);
  }
}

class BookProfileRow extends DataClass implements Insertable<BookProfileRow> {
  final String bookKey;
  final int profileId;
  const BookProfileRow({required this.bookKey, required this.profileId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_key'] = Variable<String>(bookKey);
    map['profile_id'] = Variable<int>(profileId);
    return map;
  }

  BookProfilesCompanion toCompanion(bool nullToAbsent) {
    return BookProfilesCompanion(
      bookKey: Value(bookKey),
      profileId: Value(profileId),
    );
  }

  factory BookProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookProfileRow(
      bookKey: serializer.fromJson<String>(json['bookKey']),
      profileId: serializer.fromJson<int>(json['profileId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookKey': serializer.toJson<String>(bookKey),
      'profileId': serializer.toJson<int>(profileId),
    };
  }

  BookProfileRow copyWith({String? bookKey, int? profileId}) => BookProfileRow(
    bookKey: bookKey ?? this.bookKey,
    profileId: profileId ?? this.profileId,
  );
  BookProfileRow copyWithCompanion(BookProfilesCompanion data) {
    return BookProfileRow(
      bookKey: data.bookKey.present ? data.bookKey.value : this.bookKey,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookProfileRow(')
          ..write('bookKey: $bookKey, ')
          ..write('profileId: $profileId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookKey, profileId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookProfileRow &&
          other.bookKey == this.bookKey &&
          other.profileId == this.profileId);
}

class BookProfilesCompanion extends UpdateCompanion<BookProfileRow> {
  final Value<String> bookKey;
  final Value<int> profileId;
  final Value<int> rowid;
  const BookProfilesCompanion({
    this.bookKey = const Value.absent(),
    this.profileId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookProfilesCompanion.insert({
    required String bookKey,
    required int profileId,
    this.rowid = const Value.absent(),
  }) : bookKey = Value(bookKey),
       profileId = Value(profileId);
  static Insertable<BookProfileRow> custom({
    Expression<String>? bookKey,
    Expression<int>? profileId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookKey != null) 'book_key': bookKey,
      if (profileId != null) 'profile_id': profileId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookProfilesCompanion copyWith({
    Value<String>? bookKey,
    Value<int>? profileId,
    Value<int>? rowid,
  }) {
    return BookProfilesCompanion(
      bookKey: bookKey ?? this.bookKey,
      profileId: profileId ?? this.profileId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookKey.present) {
      map['book_key'] = Variable<String>(bookKey.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookProfilesCompanion(')
          ..write('bookKey: $bookKey, ')
          ..write('profileId: $profileId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LanguageProfilesTable extends LanguageProfiles
    with TableInfo<$LanguageProfilesTable, LanguageProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LanguageProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _languageTagMeta = const VerificationMeta(
    'languageTag',
  );
  @override
  late final GeneratedColumn<String> languageTag = GeneratedColumn<String>(
    'language_tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES profiles (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [languageTag, profileId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'language_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<LanguageProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('language_tag')) {
      context.handle(
        _languageTagMeta,
        languageTag.isAcceptableOrUnknown(
          data['language_tag']!,
          _languageTagMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_languageTagMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {languageTag};
  @override
  LanguageProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LanguageProfileRow(
      languageTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language_tag'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
    );
  }

  @override
  $LanguageProfilesTable createAlias(String alias) {
    return $LanguageProfilesTable(attachedDatabase, alias);
  }
}

class LanguageProfileRow extends DataClass
    implements Insertable<LanguageProfileRow> {
  final String languageTag;
  final int profileId;
  const LanguageProfileRow({
    required this.languageTag,
    required this.profileId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['language_tag'] = Variable<String>(languageTag);
    map['profile_id'] = Variable<int>(profileId);
    return map;
  }

  LanguageProfilesCompanion toCompanion(bool nullToAbsent) {
    return LanguageProfilesCompanion(
      languageTag: Value(languageTag),
      profileId: Value(profileId),
    );
  }

  factory LanguageProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LanguageProfileRow(
      languageTag: serializer.fromJson<String>(json['languageTag']),
      profileId: serializer.fromJson<int>(json['profileId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'languageTag': serializer.toJson<String>(languageTag),
      'profileId': serializer.toJson<int>(profileId),
    };
  }

  LanguageProfileRow copyWith({String? languageTag, int? profileId}) =>
      LanguageProfileRow(
        languageTag: languageTag ?? this.languageTag,
        profileId: profileId ?? this.profileId,
      );
  LanguageProfileRow copyWithCompanion(LanguageProfilesCompanion data) {
    return LanguageProfileRow(
      languageTag: data.languageTag.present
          ? data.languageTag.value
          : this.languageTag,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LanguageProfileRow(')
          ..write('languageTag: $languageTag, ')
          ..write('profileId: $profileId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(languageTag, profileId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LanguageProfileRow &&
          other.languageTag == this.languageTag &&
          other.profileId == this.profileId);
}

class LanguageProfilesCompanion extends UpdateCompanion<LanguageProfileRow> {
  final Value<String> languageTag;
  final Value<int> profileId;
  final Value<int> rowid;
  const LanguageProfilesCompanion({
    this.languageTag = const Value.absent(),
    this.profileId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LanguageProfilesCompanion.insert({
    required String languageTag,
    required int profileId,
    this.rowid = const Value.absent(),
  }) : languageTag = Value(languageTag),
       profileId = Value(profileId);
  static Insertable<LanguageProfileRow> custom({
    Expression<String>? languageTag,
    Expression<int>? profileId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (languageTag != null) 'language_tag': languageTag,
      if (profileId != null) 'profile_id': profileId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LanguageProfilesCompanion copyWith({
    Value<String>? languageTag,
    Value<int>? profileId,
    Value<int>? rowid,
  }) {
    return LanguageProfilesCompanion(
      languageTag: languageTag ?? this.languageTag,
      profileId: profileId ?? this.profileId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (languageTag.present) {
      map['language_tag'] = Variable<String>(languageTag.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LanguageProfilesCompanion(')
          ..write('languageTag: $languageTag, ')
          ..write('profileId: $profileId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SeriesTable extends Series with TableInfo<$SeriesTable, SeriesRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
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
  static const VerificationMeta _coverSourceMeta = const VerificationMeta(
    'coverSource',
  );
  @override
  late final GeneratedColumn<String> coverSource = GeneratedColumn<String>(
    'cover_source',
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
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    coverSource,
    sortOrder,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'series';
  @override
  VerificationContext validateIntegrity(
    Insertable<SeriesRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('cover_source')) {
      context.handle(
        _coverSourceMeta,
        coverSource.isAcceptableOrUnknown(
          data['cover_source']!,
          _coverSourceMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SeriesRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeriesRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      coverSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_source'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SeriesTable createAlias(String alias) {
    return $SeriesTable(attachedDatabase, alias);
  }
}

class SeriesRow extends DataClass implements Insertable<SeriesRow> {
  final int id;

  /// 系列名（必填）。
  final String name;

  /// 系列封面来源：NULL = 自动取系列内 sortOrder 最小成员封面（拍板「首卷自动」）；
  /// 非空 = 手动指定（预留，本期恒 NULL）。不存首卷 entryKey 快照——首卷随增删 / 重排
  /// 变化，渲染时纯函数推导。
  final String? coverSource;

  /// 系列卡片之间的排序权重（同 [MediaSources].sortOrder 范式）。
  final int sortOrder;

  /// 创建时间（毫秒戳，同 [EpubBooks].importedAt int 范式）。
  final int createdAt;
  const SeriesRow({
    required this.id,
    required this.name,
    this.coverSource,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || coverSource != null) {
      map['cover_source'] = Variable<String>(coverSource);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  SeriesCompanion toCompanion(bool nullToAbsent) {
    return SeriesCompanion(
      id: Value(id),
      name: Value(name),
      coverSource: coverSource == null && nullToAbsent
          ? const Value.absent()
          : Value(coverSource),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory SeriesRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeriesRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      coverSource: serializer.fromJson<String?>(json['coverSource']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'coverSource': serializer.toJson<String?>(coverSource),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  SeriesRow copyWith({
    int? id,
    String? name,
    Value<String?> coverSource = const Value.absent(),
    int? sortOrder,
    int? createdAt,
  }) => SeriesRow(
    id: id ?? this.id,
    name: name ?? this.name,
    coverSource: coverSource.present ? coverSource.value : this.coverSource,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  SeriesRow copyWithCompanion(SeriesCompanion data) {
    return SeriesRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      coverSource: data.coverSource.present
          ? data.coverSource.value
          : this.coverSource,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SeriesRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('coverSource: $coverSource, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, coverSource, sortOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeriesRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.coverSource == this.coverSource &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class SeriesCompanion extends UpdateCompanion<SeriesRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> coverSource;
  final Value<int> sortOrder;
  final Value<int> createdAt;
  const SeriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.coverSource = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SeriesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.coverSource = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required int createdAt,
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<SeriesRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? coverSource,
    Expression<int>? sortOrder,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (coverSource != null) 'cover_source': coverSource,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SeriesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? coverSource,
    Value<int>? sortOrder,
    Value<int>? createdAt,
  }) {
    return SeriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      coverSource: coverSource ?? this.coverSource,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (coverSource.present) {
      map['cover_source'] = Variable<String>(coverSource.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('coverSource: $coverSource, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ShelfEntriesTable extends ShelfEntries
    with TableInfo<$ShelfEntriesTable, ShelfEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShelfEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mediaTypeMeta = const VerificationMeta(
    'mediaType',
  );
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
    'media_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entryKeyMeta = const VerificationMeta(
    'entryKey',
  );
  @override
  late final GeneratedColumn<String> entryKey = GeneratedColumn<String>(
    'entry_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _seriesIdMeta = const VerificationMeta(
    'seriesId',
  );
  @override
  late final GeneratedColumn<int> seriesId = GeneratedColumn<int>(
    'series_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES series (id) ON DELETE SET NULL',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    mediaType,
    entryKey,
    sortOrder,
    seriesId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shelf_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShelfEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('media_type')) {
      context.handle(
        _mediaTypeMeta,
        mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaTypeMeta);
    }
    if (data.containsKey('entry_key')) {
      context.handle(
        _entryKeyMeta,
        entryKey.isAcceptableOrUnknown(data['entry_key']!, _entryKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_entryKeyMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('series_id')) {
      context.handle(
        _seriesIdMeta,
        seriesId.isAcceptableOrUnknown(data['series_id']!, _seriesIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mediaType, entryKey};
  @override
  ShelfEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShelfEntryRow(
      mediaType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_type'],
      )!,
      entryKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_key'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      seriesId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}series_id'],
      ),
    );
  }

  @override
  $ShelfEntriesTable createAlias(String alias) {
    return $ShelfEntriesTable(attachedDatabase, alias);
  }
}

class ShelfEntryRow extends DataClass implements Insertable<ShelfEntryRow> {
  /// 媒体种类：'epub' | 'srt' | 'video'（'game' 不写本表——游戏库排序走
  /// `galgame_library_query.dart` 的视图偏好，合集归属见 [MediaCollectionItems]）。
  final String mediaType;

  /// 条目稳定身份（v83 起 epub 域 = epub_books.uid,导入时刻定死、改标题不再
  /// 漂移,旧的下载后改键迁移已删）：本地 = epubUid / srtUid / videoBookUid；
  /// 远端 = 对端 bookKey（照抄透传,本地无行）/ video.id。**逻辑外键**（不对
  /// 本地三表加 FK：远端 entryKey 无本地表行，写 FK 会在插远端归属时违反
  /// 约束）。孤儿由删除路径主动清理 + 读取期过滤兜底。
  final String entryKey;

  /// 自定义排序权重（拖拽回写）。无行的旧条目退化为 importedAt 倒序（向后兼容）。
  final int sortOrder;

  /// 归属系列（NULL = 散书）。onDelete:setNull：移除系列时
  /// 成员归 NULL（散回书架），不连坐删条目。
  final int? seriesId;
  const ShelfEntryRow({
    required this.mediaType,
    required this.entryKey,
    required this.sortOrder,
    this.seriesId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['media_type'] = Variable<String>(mediaType);
    map['entry_key'] = Variable<String>(entryKey);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || seriesId != null) {
      map['series_id'] = Variable<int>(seriesId);
    }
    return map;
  }

  ShelfEntriesCompanion toCompanion(bool nullToAbsent) {
    return ShelfEntriesCompanion(
      mediaType: Value(mediaType),
      entryKey: Value(entryKey),
      sortOrder: Value(sortOrder),
      seriesId: seriesId == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesId),
    );
  }

  factory ShelfEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShelfEntryRow(
      mediaType: serializer.fromJson<String>(json['mediaType']),
      entryKey: serializer.fromJson<String>(json['entryKey']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      seriesId: serializer.fromJson<int?>(json['seriesId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mediaType': serializer.toJson<String>(mediaType),
      'entryKey': serializer.toJson<String>(entryKey),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'seriesId': serializer.toJson<int?>(seriesId),
    };
  }

  ShelfEntryRow copyWith({
    String? mediaType,
    String? entryKey,
    int? sortOrder,
    Value<int?> seriesId = const Value.absent(),
  }) => ShelfEntryRow(
    mediaType: mediaType ?? this.mediaType,
    entryKey: entryKey ?? this.entryKey,
    sortOrder: sortOrder ?? this.sortOrder,
    seriesId: seriesId.present ? seriesId.value : this.seriesId,
  );
  ShelfEntryRow copyWithCompanion(ShelfEntriesCompanion data) {
    return ShelfEntryRow(
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      entryKey: data.entryKey.present ? data.entryKey.value : this.entryKey,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      seriesId: data.seriesId.present ? data.seriesId.value : this.seriesId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShelfEntryRow(')
          ..write('mediaType: $mediaType, ')
          ..write('entryKey: $entryKey, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('seriesId: $seriesId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(mediaType, entryKey, sortOrder, seriesId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShelfEntryRow &&
          other.mediaType == this.mediaType &&
          other.entryKey == this.entryKey &&
          other.sortOrder == this.sortOrder &&
          other.seriesId == this.seriesId);
}

class ShelfEntriesCompanion extends UpdateCompanion<ShelfEntryRow> {
  final Value<String> mediaType;
  final Value<String> entryKey;
  final Value<int> sortOrder;
  final Value<int?> seriesId;
  final Value<int> rowid;
  const ShelfEntriesCompanion({
    this.mediaType = const Value.absent(),
    this.entryKey = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShelfEntriesCompanion.insert({
    required String mediaType,
    required String entryKey,
    this.sortOrder = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : mediaType = Value(mediaType),
       entryKey = Value(entryKey);
  static Insertable<ShelfEntryRow> custom({
    Expression<String>? mediaType,
    Expression<String>? entryKey,
    Expression<int>? sortOrder,
    Expression<int>? seriesId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mediaType != null) 'media_type': mediaType,
      if (entryKey != null) 'entry_key': entryKey,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (seriesId != null) 'series_id': seriesId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ShelfEntriesCompanion copyWith({
    Value<String>? mediaType,
    Value<String>? entryKey,
    Value<int>? sortOrder,
    Value<int?>? seriesId,
    Value<int>? rowid,
  }) {
    return ShelfEntriesCompanion(
      mediaType: mediaType ?? this.mediaType,
      entryKey: entryKey ?? this.entryKey,
      sortOrder: sortOrder ?? this.sortOrder,
      seriesId: seriesId ?? this.seriesId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (entryKey.present) {
      map['entry_key'] = Variable<String>(entryKey.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (seriesId.present) {
      map['series_id'] = Variable<int>(seriesId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShelfEntriesCompanion(')
          ..write('mediaType: $mediaType, ')
          ..write('entryKey: $entryKey, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('seriesId: $seriesId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MediaCollectionsTable extends MediaCollections
    with TableInfo<$MediaCollectionsTable, MediaCollectionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaCollectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sourceFolderPathMeta = const VerificationMeta(
    'sourceFolderPath',
  );
  @override
  late final GeneratedColumn<String> sourceFolderPath = GeneratedColumn<String>(
    'source_folder_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _collectionTypeMeta = const VerificationMeta(
    'collectionType',
  );
  @override
  late final GeneratedColumn<String> collectionType = GeneratedColumn<String>(
    'collection_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('collection'),
  );
  static const VerificationMeta _coverSourceMeta = const VerificationMeta(
    'coverSource',
  );
  @override
  late final GeneratedColumn<String> coverSource = GeneratedColumn<String>(
    'cover_source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta(
    'coverPath',
  );
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
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
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderUpdatedAtMeta = const VerificationMeta(
    'orderUpdatedAt',
  );
  @override
  late final GeneratedColumn<int> orderUpdatedAt = GeneratedColumn<int>(
    'order_updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceFolderPath,
    name,
    collectionType,
    coverSource,
    coverPath,
    sortOrder,
    createdAt,
    orderUpdatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_collections';
  @override
  VerificationContext validateIntegrity(
    Insertable<MediaCollectionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source_folder_path')) {
      context.handle(
        _sourceFolderPathMeta,
        sourceFolderPath.isAcceptableOrUnknown(
          data['source_folder_path']!,
          _sourceFolderPathMeta,
        ),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('collection_type')) {
      context.handle(
        _collectionTypeMeta,
        collectionType.isAcceptableOrUnknown(
          data['collection_type']!,
          _collectionTypeMeta,
        ),
      );
    }
    if (data.containsKey('cover_source')) {
      context.handle(
        _coverSourceMeta,
        coverSource.isAcceptableOrUnknown(
          data['cover_source']!,
          _coverSourceMeta,
        ),
      );
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('order_updated_at')) {
      context.handle(
        _orderUpdatedAtMeta,
        orderUpdatedAt.isAcceptableOrUnknown(
          data['order_updated_at']!,
          _orderUpdatedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MediaCollectionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaCollectionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sourceFolderPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_folder_path'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      collectionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_type'],
      )!,
      coverSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_source'],
      ),
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      orderUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_updated_at'],
      )!,
    );
  }

  @override
  $MediaCollectionsTable createAlias(String alias) {
    return $MediaCollectionsTable(attachedDatabase, alias);
  }
}

class MediaCollectionRow extends DataClass
    implements Insertable<MediaCollectionRow> {
  final int id;

  /// 目录自动合集的本机目录身份（schema v98）；NULL 表示非目录自动合集。
  /// 与来源根一样属于用户外部路径，不跨端同步，不据合集名称推断归属。
  final String? sourceFolderPath;

  /// 合集名（必填）。
  final String name;

  /// 'collection' | 'playlist'。
  final String collectionType;

  /// 自定义封面成员 `'<mediaType>|<entryKey>'`；NULL = 自动（playlist 取前 4 成员封面
  /// 2×2 拼贴；collection 取首成员封面堆叠）。不存快照——成员增删/重排后渲染时纯函数推导。
  final String? coverSource;

  /// **合集自己的**封面图绝对路径（schema v61，BUG-1211）。与 [coverSource] 正交：
  /// 后者是「借哪个成员的封面」，本列是「合集自有一张图」，落在
  /// `<documents>/video_covers/collections/<id>.jpg`（[AppPaths.videoCoversDirectory]
  /// 的子目录 —— 与成员封面同池不同目录，文件名不可能与 `videoCoverFileName(bookUid)`
  /// 撞车）。
  ///
  /// 存在的理由：合集卡封面原先只能「遍历成员借第一张」，于是「给合集换封面」被迫
  /// 退化成「把同一张封面写进每一集」；用户明确否决该语义（BUG-1211：「匹配的是合集
  /// 的封面，谁说应用到本机里面的视频了」）。有了自有列，换合集封面就是改这一列，
  /// 一个成员都不动。
  ///
  /// 无损迁移：nullable 无 default → 旧库既有行全 NULL；渲染端 NULL 时**继续**走原来
  /// 的成员借用链（首个有本地封面的成员 → 远端成员 → 占位），老合集封面逐像素不变
  /// （Never break userspace）。
  ///
  /// 机器本地绝对路径：随数据根迁移改写（`data_root_migrator.dart`，与
  /// [VideoBooks].coverPath / [Galgames].coverPath 同型），且**不跨端同步**。
  final String? coverPath;

  /// 合集卡自身在库网格中的排序权重（与散条目同层混排，语义同旧 [Series.sortOrder]）。
  final int sortOrder;

  /// 创建时间（毫秒戳，同 [EpubBooks].importedAt int 范式）。
  final int createdAt;

  /// 合集内手动序（成员 sortIndex）最后一次人为改动的毫秒戳（schema v40，多端库
  /// 联合视图 §2.3）。仅 [FushiDatabase.reorderCollectionItems]（用户拖拽落盘）
  /// bump 为 now；同步应用对端顺序时**镜像对端时间戳而非 now**（否则同步会伪装成
  /// 更新的人为改序，两端时间戳互相追赶）。跨端手动序整合集 LWW 的比较键：新者
  /// 整表覆盖成员 sortIndex。默认 0 = 从未手动排序，任何真实改序都能盖过它。
  final int orderUpdatedAt;
  const MediaCollectionRow({
    required this.id,
    this.sourceFolderPath,
    required this.name,
    required this.collectionType,
    this.coverSource,
    this.coverPath,
    required this.sortOrder,
    required this.createdAt,
    required this.orderUpdatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || sourceFolderPath != null) {
      map['source_folder_path'] = Variable<String>(sourceFolderPath);
    }
    map['name'] = Variable<String>(name);
    map['collection_type'] = Variable<String>(collectionType);
    if (!nullToAbsent || coverSource != null) {
      map['cover_source'] = Variable<String>(coverSource);
    }
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<int>(createdAt);
    map['order_updated_at'] = Variable<int>(orderUpdatedAt);
    return map;
  }

  MediaCollectionsCompanion toCompanion(bool nullToAbsent) {
    return MediaCollectionsCompanion(
      id: Value(id),
      sourceFolderPath: sourceFolderPath == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceFolderPath),
      name: Value(name),
      collectionType: Value(collectionType),
      coverSource: coverSource == null && nullToAbsent
          ? const Value.absent()
          : Value(coverSource),
      coverPath: coverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPath),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      orderUpdatedAt: Value(orderUpdatedAt),
    );
  }

  factory MediaCollectionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaCollectionRow(
      id: serializer.fromJson<int>(json['id']),
      sourceFolderPath: serializer.fromJson<String?>(json['sourceFolderPath']),
      name: serializer.fromJson<String>(json['name']),
      collectionType: serializer.fromJson<String>(json['collectionType']),
      coverSource: serializer.fromJson<String?>(json['coverSource']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      orderUpdatedAt: serializer.fromJson<int>(json['orderUpdatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sourceFolderPath': serializer.toJson<String?>(sourceFolderPath),
      'name': serializer.toJson<String>(name),
      'collectionType': serializer.toJson<String>(collectionType),
      'coverSource': serializer.toJson<String?>(coverSource),
      'coverPath': serializer.toJson<String?>(coverPath),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<int>(createdAt),
      'orderUpdatedAt': serializer.toJson<int>(orderUpdatedAt),
    };
  }

  MediaCollectionRow copyWith({
    int? id,
    Value<String?> sourceFolderPath = const Value.absent(),
    String? name,
    String? collectionType,
    Value<String?> coverSource = const Value.absent(),
    Value<String?> coverPath = const Value.absent(),
    int? sortOrder,
    int? createdAt,
    int? orderUpdatedAt,
  }) => MediaCollectionRow(
    id: id ?? this.id,
    sourceFolderPath: sourceFolderPath.present
        ? sourceFolderPath.value
        : this.sourceFolderPath,
    name: name ?? this.name,
    collectionType: collectionType ?? this.collectionType,
    coverSource: coverSource.present ? coverSource.value : this.coverSource,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    orderUpdatedAt: orderUpdatedAt ?? this.orderUpdatedAt,
  );
  MediaCollectionRow copyWithCompanion(MediaCollectionsCompanion data) {
    return MediaCollectionRow(
      id: data.id.present ? data.id.value : this.id,
      sourceFolderPath: data.sourceFolderPath.present
          ? data.sourceFolderPath.value
          : this.sourceFolderPath,
      name: data.name.present ? data.name.value : this.name,
      collectionType: data.collectionType.present
          ? data.collectionType.value
          : this.collectionType,
      coverSource: data.coverSource.present
          ? data.coverSource.value
          : this.coverSource,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      orderUpdatedAt: data.orderUpdatedAt.present
          ? data.orderUpdatedAt.value
          : this.orderUpdatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaCollectionRow(')
          ..write('id: $id, ')
          ..write('sourceFolderPath: $sourceFolderPath, ')
          ..write('name: $name, ')
          ..write('collectionType: $collectionType, ')
          ..write('coverSource: $coverSource, ')
          ..write('coverPath: $coverPath, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('orderUpdatedAt: $orderUpdatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceFolderPath,
    name,
    collectionType,
    coverSource,
    coverPath,
    sortOrder,
    createdAt,
    orderUpdatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaCollectionRow &&
          other.id == this.id &&
          other.sourceFolderPath == this.sourceFolderPath &&
          other.name == this.name &&
          other.collectionType == this.collectionType &&
          other.coverSource == this.coverSource &&
          other.coverPath == this.coverPath &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.orderUpdatedAt == this.orderUpdatedAt);
}

class MediaCollectionsCompanion extends UpdateCompanion<MediaCollectionRow> {
  final Value<int> id;
  final Value<String?> sourceFolderPath;
  final Value<String> name;
  final Value<String> collectionType;
  final Value<String?> coverSource;
  final Value<String?> coverPath;
  final Value<int> sortOrder;
  final Value<int> createdAt;
  final Value<int> orderUpdatedAt;
  const MediaCollectionsCompanion({
    this.id = const Value.absent(),
    this.sourceFolderPath = const Value.absent(),
    this.name = const Value.absent(),
    this.collectionType = const Value.absent(),
    this.coverSource = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.orderUpdatedAt = const Value.absent(),
  });
  MediaCollectionsCompanion.insert({
    this.id = const Value.absent(),
    this.sourceFolderPath = const Value.absent(),
    required String name,
    this.collectionType = const Value.absent(),
    this.coverSource = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required int createdAt,
    this.orderUpdatedAt = const Value.absent(),
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<MediaCollectionRow> custom({
    Expression<int>? id,
    Expression<String>? sourceFolderPath,
    Expression<String>? name,
    Expression<String>? collectionType,
    Expression<String>? coverSource,
    Expression<String>? coverPath,
    Expression<int>? sortOrder,
    Expression<int>? createdAt,
    Expression<int>? orderUpdatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceFolderPath != null) 'source_folder_path': sourceFolderPath,
      if (name != null) 'name': name,
      if (collectionType != null) 'collection_type': collectionType,
      if (coverSource != null) 'cover_source': coverSource,
      if (coverPath != null) 'cover_path': coverPath,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (orderUpdatedAt != null) 'order_updated_at': orderUpdatedAt,
    });
  }

  MediaCollectionsCompanion copyWith({
    Value<int>? id,
    Value<String?>? sourceFolderPath,
    Value<String>? name,
    Value<String>? collectionType,
    Value<String?>? coverSource,
    Value<String?>? coverPath,
    Value<int>? sortOrder,
    Value<int>? createdAt,
    Value<int>? orderUpdatedAt,
  }) {
    return MediaCollectionsCompanion(
      id: id ?? this.id,
      sourceFolderPath: sourceFolderPath ?? this.sourceFolderPath,
      name: name ?? this.name,
      collectionType: collectionType ?? this.collectionType,
      coverSource: coverSource ?? this.coverSource,
      coverPath: coverPath ?? this.coverPath,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      orderUpdatedAt: orderUpdatedAt ?? this.orderUpdatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sourceFolderPath.present) {
      map['source_folder_path'] = Variable<String>(sourceFolderPath.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (collectionType.present) {
      map['collection_type'] = Variable<String>(collectionType.value);
    }
    if (coverSource.present) {
      map['cover_source'] = Variable<String>(coverSource.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (orderUpdatedAt.present) {
      map['order_updated_at'] = Variable<int>(orderUpdatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaCollectionsCompanion(')
          ..write('id: $id, ')
          ..write('sourceFolderPath: $sourceFolderPath, ')
          ..write('name: $name, ')
          ..write('collectionType: $collectionType, ')
          ..write('coverSource: $coverSource, ')
          ..write('coverPath: $coverPath, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('orderUpdatedAt: $orderUpdatedAt')
          ..write(')'))
        .toString();
  }
}

class $MediaCollectionItemsTable extends MediaCollectionItems
    with TableInfo<$MediaCollectionItemsTable, MediaCollectionItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaCollectionItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _collectionIdMeta = const VerificationMeta(
    'collectionId',
  );
  @override
  late final GeneratedColumn<int> collectionId = GeneratedColumn<int>(
    'collection_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES media_collections (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _mediaTypeMeta = const VerificationMeta(
    'mediaType',
  );
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
    'media_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entryKeyMeta = const VerificationMeta(
    'entryKey',
  );
  @override
  late final GeneratedColumn<String> entryKey = GeneratedColumn<String>(
    'entry_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    collectionId,
    mediaType,
    entryKey,
    sortIndex,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_collection_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<MediaCollectionItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('collection_id')) {
      context.handle(
        _collectionIdMeta,
        collectionId.isAcceptableOrUnknown(
          data['collection_id']!,
          _collectionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectionIdMeta);
    }
    if (data.containsKey('media_type')) {
      context.handle(
        _mediaTypeMeta,
        mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaTypeMeta);
    }
    if (data.containsKey('entry_key')) {
      context.handle(
        _entryKeyMeta,
        entryKey.isAcceptableOrUnknown(data['entry_key']!, _entryKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_entryKeyMeta);
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collectionId, mediaType, entryKey};
  @override
  MediaCollectionItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaCollectionItemRow(
      collectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}collection_id'],
      )!,
      mediaType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_type'],
      )!,
      entryKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_key'],
      )!,
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      )!,
    );
  }

  @override
  $MediaCollectionItemsTable createAlias(String alias) {
    return $MediaCollectionItemsTable(attachedDatabase, alias);
  }
}

class MediaCollectionItemRow extends DataClass
    implements Insertable<MediaCollectionItemRow> {
  /// 所属合集（[MediaCollections].id）。onDelete:cascade = 删合集连带删本引用行。
  final int collectionId;

  /// 媒体种类：'epub' | 'srt' | 'video' | 'game'（前三者同 [ShelfEntries].mediaType
  /// 值域；'game' 仅存在于本表——游戏库无书架排序行）。自由 TextColumn，无 CHECK。
  final String mediaType;

  /// 条目稳定身份：epub=bookKey / srt=uid / video=bookUid / game=galgames.id
  /// （game 的 id 是添加时刻微秒时间戳字符串，**本机局域身份**：跨端同步时经
  /// `GameIdentityIndex` 换成外部 id / exe 路径 / 标题等跨端身份，对端解析不到
  /// 本机游戏则透传保存、静默不渲染）。
  final String entryKey;

  /// 合集内序：playlist 的播放顺序 / collection 的展示顺序。
  final int sortIndex;
  const MediaCollectionItemRow({
    required this.collectionId,
    required this.mediaType,
    required this.entryKey,
    required this.sortIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['collection_id'] = Variable<int>(collectionId);
    map['media_type'] = Variable<String>(mediaType);
    map['entry_key'] = Variable<String>(entryKey);
    map['sort_index'] = Variable<int>(sortIndex);
    return map;
  }

  MediaCollectionItemsCompanion toCompanion(bool nullToAbsent) {
    return MediaCollectionItemsCompanion(
      collectionId: Value(collectionId),
      mediaType: Value(mediaType),
      entryKey: Value(entryKey),
      sortIndex: Value(sortIndex),
    );
  }

  factory MediaCollectionItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaCollectionItemRow(
      collectionId: serializer.fromJson<int>(json['collectionId']),
      mediaType: serializer.fromJson<String>(json['mediaType']),
      entryKey: serializer.fromJson<String>(json['entryKey']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collectionId': serializer.toJson<int>(collectionId),
      'mediaType': serializer.toJson<String>(mediaType),
      'entryKey': serializer.toJson<String>(entryKey),
      'sortIndex': serializer.toJson<int>(sortIndex),
    };
  }

  MediaCollectionItemRow copyWith({
    int? collectionId,
    String? mediaType,
    String? entryKey,
    int? sortIndex,
  }) => MediaCollectionItemRow(
    collectionId: collectionId ?? this.collectionId,
    mediaType: mediaType ?? this.mediaType,
    entryKey: entryKey ?? this.entryKey,
    sortIndex: sortIndex ?? this.sortIndex,
  );
  MediaCollectionItemRow copyWithCompanion(MediaCollectionItemsCompanion data) {
    return MediaCollectionItemRow(
      collectionId: data.collectionId.present
          ? data.collectionId.value
          : this.collectionId,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      entryKey: data.entryKey.present ? data.entryKey.value : this.entryKey,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaCollectionItemRow(')
          ..write('collectionId: $collectionId, ')
          ..write('mediaType: $mediaType, ')
          ..write('entryKey: $entryKey, ')
          ..write('sortIndex: $sortIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(collectionId, mediaType, entryKey, sortIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaCollectionItemRow &&
          other.collectionId == this.collectionId &&
          other.mediaType == this.mediaType &&
          other.entryKey == this.entryKey &&
          other.sortIndex == this.sortIndex);
}

class MediaCollectionItemsCompanion
    extends UpdateCompanion<MediaCollectionItemRow> {
  final Value<int> collectionId;
  final Value<String> mediaType;
  final Value<String> entryKey;
  final Value<int> sortIndex;
  final Value<int> rowid;
  const MediaCollectionItemsCompanion({
    this.collectionId = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.entryKey = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaCollectionItemsCompanion.insert({
    required int collectionId,
    required String mediaType,
    required String entryKey,
    this.sortIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : collectionId = Value(collectionId),
       mediaType = Value(mediaType),
       entryKey = Value(entryKey);
  static Insertable<MediaCollectionItemRow> custom({
    Expression<int>? collectionId,
    Expression<String>? mediaType,
    Expression<String>? entryKey,
    Expression<int>? sortIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collectionId != null) 'collection_id': collectionId,
      if (mediaType != null) 'media_type': mediaType,
      if (entryKey != null) 'entry_key': entryKey,
      if (sortIndex != null) 'sort_index': sortIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaCollectionItemsCompanion copyWith({
    Value<int>? collectionId,
    Value<String>? mediaType,
    Value<String>? entryKey,
    Value<int>? sortIndex,
    Value<int>? rowid,
  }) {
    return MediaCollectionItemsCompanion(
      collectionId: collectionId ?? this.collectionId,
      mediaType: mediaType ?? this.mediaType,
      entryKey: entryKey ?? this.entryKey,
      sortIndex: sortIndex ?? this.sortIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collectionId.present) {
      map['collection_id'] = Variable<int>(collectionId.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (entryKey.present) {
      map['entry_key'] = Variable<String>(entryKey.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaCollectionItemsCompanion(')
          ..write('collectionId: $collectionId, ')
          ..write('mediaType: $mediaType, ')
          ..write('entryKey: $entryKey, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookCustomCssTable extends BookCustomCss
    with TableInfo<$BookCustomCssTable, BookCustomCssRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookCustomCssTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookUidMeta = const VerificationMeta(
    'bookUid',
  );
  @override
  late final GeneratedColumn<String> bookUid = GeneratedColumn<String>(
    'book_uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    bookUid,
    relativePath,
    content,
    deleted,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_custom_css';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookCustomCssRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_uid')) {
      context.handle(
        _bookUidMeta,
        bookUid.isAcceptableOrUnknown(data['book_uid']!, _bookUidMeta),
      );
    } else if (isInserting) {
      context.missing(_bookUidMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookUid, relativePath};
  @override
  BookCustomCssRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookCustomCssRow(
      bookUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_uid'],
      )!,
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $BookCustomCssTable createAlias(String alias) {
    return $BookCustomCssTable(attachedDatabase, alias);
  }
}

class BookCustomCssRow extends DataClass
    implements Insertable<BookCustomCssRow> {
  /// 书稳定身份（v82 起 = EpubBooks.uid，本机稳定；跨设备/备份合并经
  /// epub_books 双侧 JOIN 换键）。删书清理走 deleteEpubBook 显式级联。
  final String bookUid;

  /// 书内 CSS 文件相对路径（extractDir 内，正斜杠归一，同 [CssFileEntry].relativePath）。
  final String relativePath;

  /// 用户自定义的 CSS 全文（[deleted]=true 时无意义，留空）。
  final String content;

  /// true = 已重置回原始（重置墓碑）；false = 有自定义内容。
  final bool deleted;

  /// 最后修改毫秒戳（LWW 比较键；保存/重置都刷新）。
  final int updatedAt;
  const BookCustomCssRow({
    required this.bookUid,
    required this.relativePath,
    required this.content,
    required this.deleted,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_uid'] = Variable<String>(bookUid);
    map['relative_path'] = Variable<String>(relativePath);
    map['content'] = Variable<String>(content);
    map['deleted'] = Variable<bool>(deleted);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  BookCustomCssCompanion toCompanion(bool nullToAbsent) {
    return BookCustomCssCompanion(
      bookUid: Value(bookUid),
      relativePath: Value(relativePath),
      content: Value(content),
      deleted: Value(deleted),
      updatedAt: Value(updatedAt),
    );
  }

  factory BookCustomCssRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookCustomCssRow(
      bookUid: serializer.fromJson<String>(json['bookUid']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      content: serializer.fromJson<String>(json['content']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookUid': serializer.toJson<String>(bookUid),
      'relativePath': serializer.toJson<String>(relativePath),
      'content': serializer.toJson<String>(content),
      'deleted': serializer.toJson<bool>(deleted),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  BookCustomCssRow copyWith({
    String? bookUid,
    String? relativePath,
    String? content,
    bool? deleted,
    int? updatedAt,
  }) => BookCustomCssRow(
    bookUid: bookUid ?? this.bookUid,
    relativePath: relativePath ?? this.relativePath,
    content: content ?? this.content,
    deleted: deleted ?? this.deleted,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  BookCustomCssRow copyWithCompanion(BookCustomCssCompanion data) {
    return BookCustomCssRow(
      bookUid: data.bookUid.present ? data.bookUid.value : this.bookUid,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      content: data.content.present ? data.content.value : this.content,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookCustomCssRow(')
          ..write('bookUid: $bookUid, ')
          ..write('relativePath: $relativePath, ')
          ..write('content: $content, ')
          ..write('deleted: $deleted, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(bookUid, relativePath, content, deleted, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookCustomCssRow &&
          other.bookUid == this.bookUid &&
          other.relativePath == this.relativePath &&
          other.content == this.content &&
          other.deleted == this.deleted &&
          other.updatedAt == this.updatedAt);
}

class BookCustomCssCompanion extends UpdateCompanion<BookCustomCssRow> {
  final Value<String> bookUid;
  final Value<String> relativePath;
  final Value<String> content;
  final Value<bool> deleted;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const BookCustomCssCompanion({
    this.bookUid = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.content = const Value.absent(),
    this.deleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookCustomCssCompanion.insert({
    required String bookUid,
    required String relativePath,
    this.content = const Value.absent(),
    this.deleted = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : bookUid = Value(bookUid),
       relativePath = Value(relativePath),
       updatedAt = Value(updatedAt);
  static Insertable<BookCustomCssRow> custom({
    Expression<String>? bookUid,
    Expression<String>? relativePath,
    Expression<String>? content,
    Expression<bool>? deleted,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookUid != null) 'book_uid': bookUid,
      if (relativePath != null) 'relative_path': relativePath,
      if (content != null) 'content': content,
      if (deleted != null) 'deleted': deleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookCustomCssCompanion copyWith({
    Value<String>? bookUid,
    Value<String>? relativePath,
    Value<String>? content,
    Value<bool>? deleted,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return BookCustomCssCompanion(
      bookUid: bookUid ?? this.bookUid,
      relativePath: relativePath ?? this.relativePath,
      content: content ?? this.content,
      deleted: deleted ?? this.deleted,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookUid.present) {
      map['book_uid'] = Variable<String>(bookUid.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookCustomCssCompanion(')
          ..write('bookUid: $bookUid, ')
          ..write('relativePath: $relativePath, ')
          ..write('content: $content, ')
          ..write('deleted: $deleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RevealedImagesTable extends RevealedImages
    with TableInfo<$RevealedImagesTable, RevealedImageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RevealedImagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookUidMeta = const VerificationMeta(
    'bookUid',
  );
  @override
  late final GeneratedColumn<String> bookUid = GeneratedColumn<String>(
    'book_uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageKeyMeta = const VerificationMeta(
    'imageKey',
  );
  @override
  late final GeneratedColumn<String> imageKey = GeneratedColumn<String>(
    'image_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revealedAtMeta = const VerificationMeta(
    'revealedAt',
  );
  @override
  late final GeneratedColumn<int> revealedAt = GeneratedColumn<int>(
    'revealed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [bookUid, imageKey, revealedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'revealed_images';
  @override
  VerificationContext validateIntegrity(
    Insertable<RevealedImageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_uid')) {
      context.handle(
        _bookUidMeta,
        bookUid.isAcceptableOrUnknown(data['book_uid']!, _bookUidMeta),
      );
    } else if (isInserting) {
      context.missing(_bookUidMeta);
    }
    if (data.containsKey('image_key')) {
      context.handle(
        _imageKeyMeta,
        imageKey.isAcceptableOrUnknown(data['image_key']!, _imageKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_imageKeyMeta);
    }
    if (data.containsKey('revealed_at')) {
      context.handle(
        _revealedAtMeta,
        revealedAt.isAcceptableOrUnknown(data['revealed_at']!, _revealedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_revealedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookUid, imageKey};
  @override
  RevealedImageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RevealedImageRow(
      bookUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_uid'],
      )!,
      imageKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_key'],
      )!,
      revealedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revealed_at'],
      )!,
    );
  }

  @override
  $RevealedImagesTable createAlias(String alias) {
    return $RevealedImagesTable(attachedDatabase, alias);
  }
}

class RevealedImageRow extends DataClass
    implements Insertable<RevealedImageRow> {
  /// 书稳定身份（v82 起 = EpubBooks.uid）。无 SQL FK（uid 唯一性是 partial
  /// 索引），删书清理走 deleteEpubBook 显式级联，守卫测试兜底。
  final String bookUid;

  /// 图片稳定 key（extractDir 相对、解码、正斜杠路径，如 `OEBPS/images/foo.jpg`）。
  final String imageKey;

  /// 揭开毫秒戳（LWW 比较键；备份合并取较新）。
  final int revealedAt;
  const RevealedImageRow({
    required this.bookUid,
    required this.imageKey,
    required this.revealedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_uid'] = Variable<String>(bookUid);
    map['image_key'] = Variable<String>(imageKey);
    map['revealed_at'] = Variable<int>(revealedAt);
    return map;
  }

  RevealedImagesCompanion toCompanion(bool nullToAbsent) {
    return RevealedImagesCompanion(
      bookUid: Value(bookUid),
      imageKey: Value(imageKey),
      revealedAt: Value(revealedAt),
    );
  }

  factory RevealedImageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RevealedImageRow(
      bookUid: serializer.fromJson<String>(json['bookUid']),
      imageKey: serializer.fromJson<String>(json['imageKey']),
      revealedAt: serializer.fromJson<int>(json['revealedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookUid': serializer.toJson<String>(bookUid),
      'imageKey': serializer.toJson<String>(imageKey),
      'revealedAt': serializer.toJson<int>(revealedAt),
    };
  }

  RevealedImageRow copyWith({
    String? bookUid,
    String? imageKey,
    int? revealedAt,
  }) => RevealedImageRow(
    bookUid: bookUid ?? this.bookUid,
    imageKey: imageKey ?? this.imageKey,
    revealedAt: revealedAt ?? this.revealedAt,
  );
  RevealedImageRow copyWithCompanion(RevealedImagesCompanion data) {
    return RevealedImageRow(
      bookUid: data.bookUid.present ? data.bookUid.value : this.bookUid,
      imageKey: data.imageKey.present ? data.imageKey.value : this.imageKey,
      revealedAt: data.revealedAt.present
          ? data.revealedAt.value
          : this.revealedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RevealedImageRow(')
          ..write('bookUid: $bookUid, ')
          ..write('imageKey: $imageKey, ')
          ..write('revealedAt: $revealedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookUid, imageKey, revealedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RevealedImageRow &&
          other.bookUid == this.bookUid &&
          other.imageKey == this.imageKey &&
          other.revealedAt == this.revealedAt);
}

class RevealedImagesCompanion extends UpdateCompanion<RevealedImageRow> {
  final Value<String> bookUid;
  final Value<String> imageKey;
  final Value<int> revealedAt;
  final Value<int> rowid;
  const RevealedImagesCompanion({
    this.bookUid = const Value.absent(),
    this.imageKey = const Value.absent(),
    this.revealedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RevealedImagesCompanion.insert({
    required String bookUid,
    required String imageKey,
    required int revealedAt,
    this.rowid = const Value.absent(),
  }) : bookUid = Value(bookUid),
       imageKey = Value(imageKey),
       revealedAt = Value(revealedAt);
  static Insertable<RevealedImageRow> custom({
    Expression<String>? bookUid,
    Expression<String>? imageKey,
    Expression<int>? revealedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookUid != null) 'book_uid': bookUid,
      if (imageKey != null) 'image_key': imageKey,
      if (revealedAt != null) 'revealed_at': revealedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RevealedImagesCompanion copyWith({
    Value<String>? bookUid,
    Value<String>? imageKey,
    Value<int>? revealedAt,
    Value<int>? rowid,
  }) {
    return RevealedImagesCompanion(
      bookUid: bookUid ?? this.bookUid,
      imageKey: imageKey ?? this.imageKey,
      revealedAt: revealedAt ?? this.revealedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookUid.present) {
      map['book_uid'] = Variable<String>(bookUid.value);
    }
    if (imageKey.present) {
      map['image_key'] = Variable<String>(imageKey.value);
    }
    if (revealedAt.present) {
      map['revealed_at'] = Variable<int>(revealedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RevealedImagesCompanion(')
          ..write('bookUid: $bookUid, ')
          ..write('imageKey: $imageKey, ')
          ..write('revealedAt: $revealedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ActivityEventsTable extends ActivityEvents
    with TableInfo<$ActivityEventsTable, ActivityEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActivityEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaTypeMeta = const VerificationMeta(
    'mediaType',
  );
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
    'media_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaKeyMeta = const VerificationMeta(
    'mediaKey',
  );
  @override
  late final GeneratedColumn<String> mediaKey = GeneratedColumn<String>(
    'media_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateKeyMeta = const VerificationMeta(
    'dateKey',
  );
  @override
  late final GeneratedColumn<String> dateKey = GeneratedColumn<String>(
    'date_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMsMeta = const VerificationMeta(
    'timestampMs',
  );
  @override
  late final GeneratedColumn<int> timestampMs = GeneratedColumn<int>(
    'timestamp_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _charsDeltaMeta = const VerificationMeta(
    'charsDelta',
  );
  @override
  late final GeneratedColumn<int> charsDelta = GeneratedColumn<int>(
    'chars_delta',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    eventType,
    mediaType,
    title,
    mediaKey,
    dateKey,
    timestampMs,
    durationMs,
    charsDelta,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'activity_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActivityEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('media_type')) {
      context.handle(
        _mediaTypeMeta,
        mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaTypeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('media_key')) {
      context.handle(
        _mediaKeyMeta,
        mediaKey.isAcceptableOrUnknown(data['media_key']!, _mediaKeyMeta),
      );
    }
    if (data.containsKey('date_key')) {
      context.handle(
        _dateKeyMeta,
        dateKey.isAcceptableOrUnknown(data['date_key']!, _dateKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dateKeyMeta);
    }
    if (data.containsKey('timestamp_ms')) {
      context.handle(
        _timestampMsMeta,
        timestampMs.isAcceptableOrUnknown(
          data['timestamp_ms']!,
          _timestampMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_timestampMsMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('chars_delta')) {
      context.handle(
        _charsDeltaMeta,
        charsDelta.isAcceptableOrUnknown(data['chars_delta']!, _charsDeltaMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ActivityEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActivityEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_type'],
      )!,
      mediaType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      mediaKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_key'],
      ),
      dateKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_key'],
      )!,
      timestampMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp_ms'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      charsDelta: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chars_delta'],
      ),
    );
  }

  @override
  $ActivityEventsTable createAlias(String alias) {
    return $ActivityEventsTable(attachedDatabase, alias);
  }
}

class ActivityEventRow extends DataClass
    implements Insertable<ActivityEventRow> {
  final int id;

  /// 事件语义：'read'（读完一段）/ 'watch'（看了一段视频）/ 'added'（导入了媒体）
  /// / 'game'（galgame 游玩：时长行由前台窗口计时器写，字符行由 hook 文本累计器写）。
  final String eventType;

  /// 媒体种类：'book' / 'video' / 'game'。与 [eventType] 分开，未来可扩展
  /// （如 'added' 的媒体既可能是 book 也可能是 video）。
  final String mediaType;

  /// 展示标题（书名 / 视频名）。
  final String title;

  /// 点击活动条打开媒体用的稳定身份：书=bookKey，视频=bookUid，导入不一定有。
  final String? mediaKey;

  /// 冗余的按天分组键（'YYYY-MM-DD'，本地时区），避免读取端为分组再从
  /// [timestampMs] 反算。与统计表 dateKey 同源（[statDateKey]）。
  final String dateKey;

  /// 精确发生时刻（epoch 毫秒），Activity 相对时间与排序的真值。
  final int timestampMs;

  /// 本次 session 时长（毫秒），read/watch 有；added 为 null。
  final int? durationMs;

  /// 本次读/看的字符数（阅读=字数，视频=字幕字数），added 为 null。
  final int? charsDelta;
  const ActivityEventRow({
    required this.id,
    required this.eventType,
    required this.mediaType,
    required this.title,
    this.mediaKey,
    required this.dateKey,
    required this.timestampMs,
    this.durationMs,
    this.charsDelta,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['event_type'] = Variable<String>(eventType);
    map['media_type'] = Variable<String>(mediaType);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || mediaKey != null) {
      map['media_key'] = Variable<String>(mediaKey);
    }
    map['date_key'] = Variable<String>(dateKey);
    map['timestamp_ms'] = Variable<int>(timestampMs);
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || charsDelta != null) {
      map['chars_delta'] = Variable<int>(charsDelta);
    }
    return map;
  }

  ActivityEventsCompanion toCompanion(bool nullToAbsent) {
    return ActivityEventsCompanion(
      id: Value(id),
      eventType: Value(eventType),
      mediaType: Value(mediaType),
      title: Value(title),
      mediaKey: mediaKey == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaKey),
      dateKey: Value(dateKey),
      timestampMs: Value(timestampMs),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      charsDelta: charsDelta == null && nullToAbsent
          ? const Value.absent()
          : Value(charsDelta),
    );
  }

  factory ActivityEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActivityEventRow(
      id: serializer.fromJson<int>(json['id']),
      eventType: serializer.fromJson<String>(json['eventType']),
      mediaType: serializer.fromJson<String>(json['mediaType']),
      title: serializer.fromJson<String>(json['title']),
      mediaKey: serializer.fromJson<String?>(json['mediaKey']),
      dateKey: serializer.fromJson<String>(json['dateKey']),
      timestampMs: serializer.fromJson<int>(json['timestampMs']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      charsDelta: serializer.fromJson<int?>(json['charsDelta']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'eventType': serializer.toJson<String>(eventType),
      'mediaType': serializer.toJson<String>(mediaType),
      'title': serializer.toJson<String>(title),
      'mediaKey': serializer.toJson<String?>(mediaKey),
      'dateKey': serializer.toJson<String>(dateKey),
      'timestampMs': serializer.toJson<int>(timestampMs),
      'durationMs': serializer.toJson<int?>(durationMs),
      'charsDelta': serializer.toJson<int?>(charsDelta),
    };
  }

  ActivityEventRow copyWith({
    int? id,
    String? eventType,
    String? mediaType,
    String? title,
    Value<String?> mediaKey = const Value.absent(),
    String? dateKey,
    int? timestampMs,
    Value<int?> durationMs = const Value.absent(),
    Value<int?> charsDelta = const Value.absent(),
  }) => ActivityEventRow(
    id: id ?? this.id,
    eventType: eventType ?? this.eventType,
    mediaType: mediaType ?? this.mediaType,
    title: title ?? this.title,
    mediaKey: mediaKey.present ? mediaKey.value : this.mediaKey,
    dateKey: dateKey ?? this.dateKey,
    timestampMs: timestampMs ?? this.timestampMs,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    charsDelta: charsDelta.present ? charsDelta.value : this.charsDelta,
  );
  ActivityEventRow copyWithCompanion(ActivityEventsCompanion data) {
    return ActivityEventRow(
      id: data.id.present ? data.id.value : this.id,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      title: data.title.present ? data.title.value : this.title,
      mediaKey: data.mediaKey.present ? data.mediaKey.value : this.mediaKey,
      dateKey: data.dateKey.present ? data.dateKey.value : this.dateKey,
      timestampMs: data.timestampMs.present
          ? data.timestampMs.value
          : this.timestampMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      charsDelta: data.charsDelta.present
          ? data.charsDelta.value
          : this.charsDelta,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActivityEventRow(')
          ..write('id: $id, ')
          ..write('eventType: $eventType, ')
          ..write('mediaType: $mediaType, ')
          ..write('title: $title, ')
          ..write('mediaKey: $mediaKey, ')
          ..write('dateKey: $dateKey, ')
          ..write('timestampMs: $timestampMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('charsDelta: $charsDelta')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    eventType,
    mediaType,
    title,
    mediaKey,
    dateKey,
    timestampMs,
    durationMs,
    charsDelta,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActivityEventRow &&
          other.id == this.id &&
          other.eventType == this.eventType &&
          other.mediaType == this.mediaType &&
          other.title == this.title &&
          other.mediaKey == this.mediaKey &&
          other.dateKey == this.dateKey &&
          other.timestampMs == this.timestampMs &&
          other.durationMs == this.durationMs &&
          other.charsDelta == this.charsDelta);
}

class ActivityEventsCompanion extends UpdateCompanion<ActivityEventRow> {
  final Value<int> id;
  final Value<String> eventType;
  final Value<String> mediaType;
  final Value<String> title;
  final Value<String?> mediaKey;
  final Value<String> dateKey;
  final Value<int> timestampMs;
  final Value<int?> durationMs;
  final Value<int?> charsDelta;
  const ActivityEventsCompanion({
    this.id = const Value.absent(),
    this.eventType = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.title = const Value.absent(),
    this.mediaKey = const Value.absent(),
    this.dateKey = const Value.absent(),
    this.timestampMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.charsDelta = const Value.absent(),
  });
  ActivityEventsCompanion.insert({
    this.id = const Value.absent(),
    required String eventType,
    required String mediaType,
    required String title,
    this.mediaKey = const Value.absent(),
    required String dateKey,
    required int timestampMs,
    this.durationMs = const Value.absent(),
    this.charsDelta = const Value.absent(),
  }) : eventType = Value(eventType),
       mediaType = Value(mediaType),
       title = Value(title),
       dateKey = Value(dateKey),
       timestampMs = Value(timestampMs);
  static Insertable<ActivityEventRow> custom({
    Expression<int>? id,
    Expression<String>? eventType,
    Expression<String>? mediaType,
    Expression<String>? title,
    Expression<String>? mediaKey,
    Expression<String>? dateKey,
    Expression<int>? timestampMs,
    Expression<int>? durationMs,
    Expression<int>? charsDelta,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventType != null) 'event_type': eventType,
      if (mediaType != null) 'media_type': mediaType,
      if (title != null) 'title': title,
      if (mediaKey != null) 'media_key': mediaKey,
      if (dateKey != null) 'date_key': dateKey,
      if (timestampMs != null) 'timestamp_ms': timestampMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (charsDelta != null) 'chars_delta': charsDelta,
    });
  }

  ActivityEventsCompanion copyWith({
    Value<int>? id,
    Value<String>? eventType,
    Value<String>? mediaType,
    Value<String>? title,
    Value<String?>? mediaKey,
    Value<String>? dateKey,
    Value<int>? timestampMs,
    Value<int?>? durationMs,
    Value<int?>? charsDelta,
  }) {
    return ActivityEventsCompanion(
      id: id ?? this.id,
      eventType: eventType ?? this.eventType,
      mediaType: mediaType ?? this.mediaType,
      title: title ?? this.title,
      mediaKey: mediaKey ?? this.mediaKey,
      dateKey: dateKey ?? this.dateKey,
      timestampMs: timestampMs ?? this.timestampMs,
      durationMs: durationMs ?? this.durationMs,
      charsDelta: charsDelta ?? this.charsDelta,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (mediaKey.present) {
      map['media_key'] = Variable<String>(mediaKey.value);
    }
    if (dateKey.present) {
      map['date_key'] = Variable<String>(dateKey.value);
    }
    if (timestampMs.present) {
      map['timestamp_ms'] = Variable<int>(timestampMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (charsDelta.present) {
      map['chars_delta'] = Variable<int>(charsDelta.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActivityEventsCompanion(')
          ..write('id: $id, ')
          ..write('eventType: $eventType, ')
          ..write('mediaType: $mediaType, ')
          ..write('title: $title, ')
          ..write('mediaKey: $mediaKey, ')
          ..write('dateKey: $dateKey, ')
          ..write('timestampMs: $timestampMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('charsDelta: $charsDelta')
          ..write(')'))
        .toString();
  }
}

class $StudySegmentTombstonesTable extends StudySegmentTombstones
    with TableInfo<$StudySegmentTombstonesTable, StudySegmentTombstoneRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudySegmentTombstonesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _mediaKindMeta = const VerificationMeta(
    'mediaKind',
  );
  @override
  late final GeneratedColumn<String> mediaKind = GeneratedColumn<String>(
    'media_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaKeyMeta = const VerificationMeta(
    'mediaKey',
  );
  @override
  late final GeneratedColumn<String> mediaKey = GeneratedColumn<String>(
    'media_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    profileId,
    mediaKind,
    mediaKey,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'study_segment_tombstones';
  @override
  VerificationContext validateIntegrity(
    Insertable<StudySegmentTombstoneRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    }
    if (data.containsKey('media_kind')) {
      context.handle(
        _mediaKindMeta,
        mediaKind.isAcceptableOrUnknown(data['media_kind']!, _mediaKindMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaKindMeta);
    }
    if (data.containsKey('media_key')) {
      context.handle(
        _mediaKeyMeta,
        mediaKey.isAcceptableOrUnknown(data['media_key']!, _mediaKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaKeyMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_deletedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId, mediaKind, mediaKey};
  @override
  StudySegmentTombstoneRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StudySegmentTombstoneRow(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
      mediaKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_kind'],
      )!,
      mediaKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_key'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      )!,
    );
  }

  @override
  $StudySegmentTombstonesTable createAlias(String alias) {
    return $StudySegmentTombstonesTable(attachedDatabase, alias);
  }
}

class StudySegmentTombstoneRow extends DataClass
    implements Insertable<StudySegmentTombstoneRow> {
  /// 立碑时的 Profile（`profiles.id`），语义同 [StudySegments.profileId]。
  final int profileId;
  final String mediaKind;
  final String mediaKey;
  final int deletedAt;
  const StudySegmentTombstoneRow({
    required this.profileId,
    required this.mediaKind,
    required this.mediaKey,
    required this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<int>(profileId);
    map['media_kind'] = Variable<String>(mediaKind);
    map['media_key'] = Variable<String>(mediaKey);
    map['deleted_at'] = Variable<int>(deletedAt);
    return map;
  }

  StudySegmentTombstonesCompanion toCompanion(bool nullToAbsent) {
    return StudySegmentTombstonesCompanion(
      profileId: Value(profileId),
      mediaKind: Value(mediaKind),
      mediaKey: Value(mediaKey),
      deletedAt: Value(deletedAt),
    );
  }

  factory StudySegmentTombstoneRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StudySegmentTombstoneRow(
      profileId: serializer.fromJson<int>(json['profileId']),
      mediaKind: serializer.fromJson<String>(json['mediaKind']),
      mediaKey: serializer.fromJson<String>(json['mediaKey']),
      deletedAt: serializer.fromJson<int>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<int>(profileId),
      'mediaKind': serializer.toJson<String>(mediaKind),
      'mediaKey': serializer.toJson<String>(mediaKey),
      'deletedAt': serializer.toJson<int>(deletedAt),
    };
  }

  StudySegmentTombstoneRow copyWith({
    int? profileId,
    String? mediaKind,
    String? mediaKey,
    int? deletedAt,
  }) => StudySegmentTombstoneRow(
    profileId: profileId ?? this.profileId,
    mediaKind: mediaKind ?? this.mediaKind,
    mediaKey: mediaKey ?? this.mediaKey,
    deletedAt: deletedAt ?? this.deletedAt,
  );
  StudySegmentTombstoneRow copyWithCompanion(
    StudySegmentTombstonesCompanion data,
  ) {
    return StudySegmentTombstoneRow(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      mediaKind: data.mediaKind.present ? data.mediaKind.value : this.mediaKind,
      mediaKey: data.mediaKey.present ? data.mediaKey.value : this.mediaKey,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StudySegmentTombstoneRow(')
          ..write('profileId: $profileId, ')
          ..write('mediaKind: $mediaKind, ')
          ..write('mediaKey: $mediaKey, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(profileId, mediaKind, mediaKey, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudySegmentTombstoneRow &&
          other.profileId == this.profileId &&
          other.mediaKind == this.mediaKind &&
          other.mediaKey == this.mediaKey &&
          other.deletedAt == this.deletedAt);
}

class StudySegmentTombstonesCompanion
    extends UpdateCompanion<StudySegmentTombstoneRow> {
  final Value<int> profileId;
  final Value<String> mediaKind;
  final Value<String> mediaKey;
  final Value<int> deletedAt;
  final Value<int> rowid;
  const StudySegmentTombstonesCompanion({
    this.profileId = const Value.absent(),
    this.mediaKind = const Value.absent(),
    this.mediaKey = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StudySegmentTombstonesCompanion.insert({
    this.profileId = const Value.absent(),
    required String mediaKind,
    required String mediaKey,
    required int deletedAt,
    this.rowid = const Value.absent(),
  }) : mediaKind = Value(mediaKind),
       mediaKey = Value(mediaKey),
       deletedAt = Value(deletedAt);
  static Insertable<StudySegmentTombstoneRow> custom({
    Expression<int>? profileId,
    Expression<String>? mediaKind,
    Expression<String>? mediaKey,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (mediaKind != null) 'media_kind': mediaKind,
      if (mediaKey != null) 'media_key': mediaKey,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StudySegmentTombstonesCompanion copyWith({
    Value<int>? profileId,
    Value<String>? mediaKind,
    Value<String>? mediaKey,
    Value<int>? deletedAt,
    Value<int>? rowid,
  }) {
    return StudySegmentTombstonesCompanion(
      profileId: profileId ?? this.profileId,
      mediaKind: mediaKind ?? this.mediaKind,
      mediaKey: mediaKey ?? this.mediaKey,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (mediaKind.present) {
      map['media_kind'] = Variable<String>(mediaKind.value);
    }
    if (mediaKey.present) {
      map['media_key'] = Variable<String>(mediaKey.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudySegmentTombstonesCompanion(')
          ..write('profileId: $profileId, ')
          ..write('mediaKind: $mediaKind, ')
          ..write('mediaKey: $mediaKey, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StudySegmentsTable extends StudySegments
    with TableInfo<$StudySegmentsTable, StudySegmentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudySegmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
    'uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaKindMeta = const VerificationMeta(
    'mediaKind',
  );
  @override
  late final GeneratedColumn<String> mediaKind = GeneratedColumn<String>(
    'media_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaKeyMeta = const VerificationMeta(
    'mediaKey',
  );
  @override
  late final GeneratedColumn<String> mediaKey = GeneratedColumn<String>(
    'media_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startAtMeta = const VerificationMeta(
    'startAt',
  );
  @override
  late final GeneratedColumn<int> startAt = GeneratedColumn<int>(
    'start_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endAtMeta = const VerificationMeta('endAt');
  @override
  late final GeneratedColumn<int> endAt = GeneratedColumn<int>(
    'end_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateKeyMeta = const VerificationMeta(
    'dateKey',
  );
  @override
  late final GeneratedColumn<String> dateKey = GeneratedColumn<String>(
    'date_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hourMeta = const VerificationMeta('hour');
  @override
  late final GeneratedColumn<int> hour = GeneratedColumn<int>(
    'hour',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _charsMeta = const VerificationMeta('chars');
  @override
  late final GeneratedColumn<int> chars = GeneratedColumn<int>(
    'chars',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pagesMeta = const VerificationMeta('pages');
  @override
  late final GeneratedColumn<int> pages = GeneratedColumn<int>(
    'pages',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<int> profileId = GeneratedColumn<int>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    uid,
    deviceId,
    mediaKind,
    mediaKey,
    format,
    title,
    startAt,
    endAt,
    dateKey,
    hour,
    durationMs,
    chars,
    pages,
    updatedAt,
    profileId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'study_segments';
  @override
  VerificationContext validateIntegrity(
    Insertable<StudySegmentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    } else if (isInserting) {
      context.missing(_uidMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('media_kind')) {
      context.handle(
        _mediaKindMeta,
        mediaKind.isAcceptableOrUnknown(data['media_kind']!, _mediaKindMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaKindMeta);
    }
    if (data.containsKey('media_key')) {
      context.handle(
        _mediaKeyMeta,
        mediaKey.isAcceptableOrUnknown(data['media_key']!, _mediaKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaKeyMeta);
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('start_at')) {
      context.handle(
        _startAtMeta,
        startAt.isAcceptableOrUnknown(data['start_at']!, _startAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startAtMeta);
    }
    if (data.containsKey('end_at')) {
      context.handle(
        _endAtMeta,
        endAt.isAcceptableOrUnknown(data['end_at']!, _endAtMeta),
      );
    } else if (isInserting) {
      context.missing(_endAtMeta);
    }
    if (data.containsKey('date_key')) {
      context.handle(
        _dateKeyMeta,
        dateKey.isAcceptableOrUnknown(data['date_key']!, _dateKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dateKeyMeta);
    }
    if (data.containsKey('hour')) {
      context.handle(
        _hourMeta,
        hour.isAcceptableOrUnknown(data['hour']!, _hourMeta),
      );
    } else if (isInserting) {
      context.missing(_hourMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('chars')) {
      context.handle(
        _charsMeta,
        chars.isAcceptableOrUnknown(data['chars']!, _charsMeta),
      );
    }
    if (data.containsKey('pages')) {
      context.handle(
        _pagesMeta,
        pages.isAcceptableOrUnknown(data['pages']!, _pagesMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uid};
  @override
  StudySegmentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StudySegmentRow(
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uid'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      mediaKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_kind'],
      )!,
      mediaKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_key'],
      )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      startAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_at'],
      )!,
      endAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_at'],
      )!,
      dateKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_key'],
      )!,
      hour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hour'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      chars: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chars'],
      )!,
      pages: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pages'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}profile_id'],
      )!,
    );
  }

  @override
  $StudySegmentsTable createAlias(String alias) {
    return $StudySegmentsTable(attachedDatabase, alias);
  }
}

class StudySegmentRow extends DataClass implements Insertable<StudySegmentRow> {
  /// 写入方生成的幂等键（32 位 hex，见 [FushiDatabase.newStudySegmentUid]）。
  final String uid;

  /// 产生本段的设备（`sync_device_id` 偏好，见 [FushiDatabase.getOrCreateStudyDeviceId]）。
  /// 同步 v2 按 (uid) 并集时它是 provenance，不进任何合并判据。
  final String deviceId;

  /// 'book' | 'video' | 'game'（[ActivityMediaKind.dbValue] 同值域）。
  final String mediaKind;

  /// 稳定媒体身份：书=bookKey，视频=bookUid，游戏=galgames.id。**永不用 title**。
  final String mediaKey;

  /// 写入面：'epub' | 'pdf' | 'manga'（[BookFormat.dbValue]），非书面 ''。
  final String format;

  /// 展示快照：库表 join 不到（媒体已删）时回退显示，不参与任何分组。
  final String title;

  /// 段起始 / 结束毫秒戳。[endAt] 随 tick 前进；`endAt - startAt >= durationMs`。
  final int startAt;
  final int endAt;

  /// [startAt] 的本地 `yyyy-MM-dd` 与小时（段不跨小时边界，故两者精确）。
  final String dateKey;
  final int hour;

  /// 活跃时长（毫秒，已过前台 / 播放态 / 空闲 / 断档守卫）。
  final int durationMs;

  /// 字数（书 / 漫画 OCR = 实义字符；视频 = 字幕字符；游戏 = hook 文本）。
  final int chars;

  /// 页数（漫画 / PDF；EPUB 恒 0）。
  final int pages;

  /// 最后写入毫秒戳：同步 v2 同 uid 取大者（LWW），墓碑仲裁用它与 deletedAt 比。
  final int updatedAt;

  /// v105（统计按 Profile 隔离）：开段时激活的 Profile（`profiles.id`）。
  ///
  /// 分区键：读取面（`loadStatFacts` / 最近观看 / 删除 / 清空）一律只看当前激活
  /// Profile 的行，各 Profile 之间互不可见。**只在插入时盖戳、冲突更新不改**——
  /// 段的归属在它开始那一刻就定了，中途切 Profile 不把已开的段挪走（下一段自然
  /// 归新 Profile）。写入方（StudyClock / galgame hook）不用知道 Profile：缺席时
  /// DAO 从 `active_profile_id` 偏好解析（[FushiDatabase.resolveActiveProfileId]）。
  /// 0 = 库里还没有 Profile（只在纯 DB 测试里出现；app 启动即 ensureDefaultProfile）。
  ///
  /// 不做 FK：删 Profile 不 cascade 删历史（同步对端可能还持有这些段，本机静默
  /// 消失又回灌是最坏形态），行留着、对任何 Profile 都不可见即可。同步 wire 不
  /// 传本机自增 id，传 Profile **名字**（`profileName`），对端按名字落到自己的
  /// 同名 Profile。
  final int profileId;
  const StudySegmentRow({
    required this.uid,
    required this.deviceId,
    required this.mediaKind,
    required this.mediaKey,
    required this.format,
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.dateKey,
    required this.hour,
    required this.durationMs,
    required this.chars,
    required this.pages,
    required this.updatedAt,
    required this.profileId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uid'] = Variable<String>(uid);
    map['device_id'] = Variable<String>(deviceId);
    map['media_kind'] = Variable<String>(mediaKind);
    map['media_key'] = Variable<String>(mediaKey);
    map['format'] = Variable<String>(format);
    map['title'] = Variable<String>(title);
    map['start_at'] = Variable<int>(startAt);
    map['end_at'] = Variable<int>(endAt);
    map['date_key'] = Variable<String>(dateKey);
    map['hour'] = Variable<int>(hour);
    map['duration_ms'] = Variable<int>(durationMs);
    map['chars'] = Variable<int>(chars);
    map['pages'] = Variable<int>(pages);
    map['updated_at'] = Variable<int>(updatedAt);
    map['profile_id'] = Variable<int>(profileId);
    return map;
  }

  StudySegmentsCompanion toCompanion(bool nullToAbsent) {
    return StudySegmentsCompanion(
      uid: Value(uid),
      deviceId: Value(deviceId),
      mediaKind: Value(mediaKind),
      mediaKey: Value(mediaKey),
      format: Value(format),
      title: Value(title),
      startAt: Value(startAt),
      endAt: Value(endAt),
      dateKey: Value(dateKey),
      hour: Value(hour),
      durationMs: Value(durationMs),
      chars: Value(chars),
      pages: Value(pages),
      updatedAt: Value(updatedAt),
      profileId: Value(profileId),
    );
  }

  factory StudySegmentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StudySegmentRow(
      uid: serializer.fromJson<String>(json['uid']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      mediaKind: serializer.fromJson<String>(json['mediaKind']),
      mediaKey: serializer.fromJson<String>(json['mediaKey']),
      format: serializer.fromJson<String>(json['format']),
      title: serializer.fromJson<String>(json['title']),
      startAt: serializer.fromJson<int>(json['startAt']),
      endAt: serializer.fromJson<int>(json['endAt']),
      dateKey: serializer.fromJson<String>(json['dateKey']),
      hour: serializer.fromJson<int>(json['hour']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      chars: serializer.fromJson<int>(json['chars']),
      pages: serializer.fromJson<int>(json['pages']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      profileId: serializer.fromJson<int>(json['profileId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uid': serializer.toJson<String>(uid),
      'deviceId': serializer.toJson<String>(deviceId),
      'mediaKind': serializer.toJson<String>(mediaKind),
      'mediaKey': serializer.toJson<String>(mediaKey),
      'format': serializer.toJson<String>(format),
      'title': serializer.toJson<String>(title),
      'startAt': serializer.toJson<int>(startAt),
      'endAt': serializer.toJson<int>(endAt),
      'dateKey': serializer.toJson<String>(dateKey),
      'hour': serializer.toJson<int>(hour),
      'durationMs': serializer.toJson<int>(durationMs),
      'chars': serializer.toJson<int>(chars),
      'pages': serializer.toJson<int>(pages),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'profileId': serializer.toJson<int>(profileId),
    };
  }

  StudySegmentRow copyWith({
    String? uid,
    String? deviceId,
    String? mediaKind,
    String? mediaKey,
    String? format,
    String? title,
    int? startAt,
    int? endAt,
    String? dateKey,
    int? hour,
    int? durationMs,
    int? chars,
    int? pages,
    int? updatedAt,
    int? profileId,
  }) => StudySegmentRow(
    uid: uid ?? this.uid,
    deviceId: deviceId ?? this.deviceId,
    mediaKind: mediaKind ?? this.mediaKind,
    mediaKey: mediaKey ?? this.mediaKey,
    format: format ?? this.format,
    title: title ?? this.title,
    startAt: startAt ?? this.startAt,
    endAt: endAt ?? this.endAt,
    dateKey: dateKey ?? this.dateKey,
    hour: hour ?? this.hour,
    durationMs: durationMs ?? this.durationMs,
    chars: chars ?? this.chars,
    pages: pages ?? this.pages,
    updatedAt: updatedAt ?? this.updatedAt,
    profileId: profileId ?? this.profileId,
  );
  StudySegmentRow copyWithCompanion(StudySegmentsCompanion data) {
    return StudySegmentRow(
      uid: data.uid.present ? data.uid.value : this.uid,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      mediaKind: data.mediaKind.present ? data.mediaKind.value : this.mediaKind,
      mediaKey: data.mediaKey.present ? data.mediaKey.value : this.mediaKey,
      format: data.format.present ? data.format.value : this.format,
      title: data.title.present ? data.title.value : this.title,
      startAt: data.startAt.present ? data.startAt.value : this.startAt,
      endAt: data.endAt.present ? data.endAt.value : this.endAt,
      dateKey: data.dateKey.present ? data.dateKey.value : this.dateKey,
      hour: data.hour.present ? data.hour.value : this.hour,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      chars: data.chars.present ? data.chars.value : this.chars,
      pages: data.pages.present ? data.pages.value : this.pages,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StudySegmentRow(')
          ..write('uid: $uid, ')
          ..write('deviceId: $deviceId, ')
          ..write('mediaKind: $mediaKind, ')
          ..write('mediaKey: $mediaKey, ')
          ..write('format: $format, ')
          ..write('title: $title, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('dateKey: $dateKey, ')
          ..write('hour: $hour, ')
          ..write('durationMs: $durationMs, ')
          ..write('chars: $chars, ')
          ..write('pages: $pages, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('profileId: $profileId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    uid,
    deviceId,
    mediaKind,
    mediaKey,
    format,
    title,
    startAt,
    endAt,
    dateKey,
    hour,
    durationMs,
    chars,
    pages,
    updatedAt,
    profileId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudySegmentRow &&
          other.uid == this.uid &&
          other.deviceId == this.deviceId &&
          other.mediaKind == this.mediaKind &&
          other.mediaKey == this.mediaKey &&
          other.format == this.format &&
          other.title == this.title &&
          other.startAt == this.startAt &&
          other.endAt == this.endAt &&
          other.dateKey == this.dateKey &&
          other.hour == this.hour &&
          other.durationMs == this.durationMs &&
          other.chars == this.chars &&
          other.pages == this.pages &&
          other.updatedAt == this.updatedAt &&
          other.profileId == this.profileId);
}

class StudySegmentsCompanion extends UpdateCompanion<StudySegmentRow> {
  final Value<String> uid;
  final Value<String> deviceId;
  final Value<String> mediaKind;
  final Value<String> mediaKey;
  final Value<String> format;
  final Value<String> title;
  final Value<int> startAt;
  final Value<int> endAt;
  final Value<String> dateKey;
  final Value<int> hour;
  final Value<int> durationMs;
  final Value<int> chars;
  final Value<int> pages;
  final Value<int> updatedAt;
  final Value<int> profileId;
  final Value<int> rowid;
  const StudySegmentsCompanion({
    this.uid = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.mediaKind = const Value.absent(),
    this.mediaKey = const Value.absent(),
    this.format = const Value.absent(),
    this.title = const Value.absent(),
    this.startAt = const Value.absent(),
    this.endAt = const Value.absent(),
    this.dateKey = const Value.absent(),
    this.hour = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.chars = const Value.absent(),
    this.pages = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.profileId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StudySegmentsCompanion.insert({
    required String uid,
    required String deviceId,
    required String mediaKind,
    required String mediaKey,
    this.format = const Value.absent(),
    required String title,
    required int startAt,
    required int endAt,
    required String dateKey,
    required int hour,
    this.durationMs = const Value.absent(),
    this.chars = const Value.absent(),
    this.pages = const Value.absent(),
    required int updatedAt,
    this.profileId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uid = Value(uid),
       deviceId = Value(deviceId),
       mediaKind = Value(mediaKind),
       mediaKey = Value(mediaKey),
       title = Value(title),
       startAt = Value(startAt),
       endAt = Value(endAt),
       dateKey = Value(dateKey),
       hour = Value(hour),
       updatedAt = Value(updatedAt);
  static Insertable<StudySegmentRow> custom({
    Expression<String>? uid,
    Expression<String>? deviceId,
    Expression<String>? mediaKind,
    Expression<String>? mediaKey,
    Expression<String>? format,
    Expression<String>? title,
    Expression<int>? startAt,
    Expression<int>? endAt,
    Expression<String>? dateKey,
    Expression<int>? hour,
    Expression<int>? durationMs,
    Expression<int>? chars,
    Expression<int>? pages,
    Expression<int>? updatedAt,
    Expression<int>? profileId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uid != null) 'uid': uid,
      if (deviceId != null) 'device_id': deviceId,
      if (mediaKind != null) 'media_kind': mediaKind,
      if (mediaKey != null) 'media_key': mediaKey,
      if (format != null) 'format': format,
      if (title != null) 'title': title,
      if (startAt != null) 'start_at': startAt,
      if (endAt != null) 'end_at': endAt,
      if (dateKey != null) 'date_key': dateKey,
      if (hour != null) 'hour': hour,
      if (durationMs != null) 'duration_ms': durationMs,
      if (chars != null) 'chars': chars,
      if (pages != null) 'pages': pages,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (profileId != null) 'profile_id': profileId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StudySegmentsCompanion copyWith({
    Value<String>? uid,
    Value<String>? deviceId,
    Value<String>? mediaKind,
    Value<String>? mediaKey,
    Value<String>? format,
    Value<String>? title,
    Value<int>? startAt,
    Value<int>? endAt,
    Value<String>? dateKey,
    Value<int>? hour,
    Value<int>? durationMs,
    Value<int>? chars,
    Value<int>? pages,
    Value<int>? updatedAt,
    Value<int>? profileId,
    Value<int>? rowid,
  }) {
    return StudySegmentsCompanion(
      uid: uid ?? this.uid,
      deviceId: deviceId ?? this.deviceId,
      mediaKind: mediaKind ?? this.mediaKind,
      mediaKey: mediaKey ?? this.mediaKey,
      format: format ?? this.format,
      title: title ?? this.title,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      dateKey: dateKey ?? this.dateKey,
      hour: hour ?? this.hour,
      durationMs: durationMs ?? this.durationMs,
      chars: chars ?? this.chars,
      pages: pages ?? this.pages,
      updatedAt: updatedAt ?? this.updatedAt,
      profileId: profileId ?? this.profileId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (mediaKind.present) {
      map['media_kind'] = Variable<String>(mediaKind.value);
    }
    if (mediaKey.present) {
      map['media_key'] = Variable<String>(mediaKey.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (startAt.present) {
      map['start_at'] = Variable<int>(startAt.value);
    }
    if (endAt.present) {
      map['end_at'] = Variable<int>(endAt.value);
    }
    if (dateKey.present) {
      map['date_key'] = Variable<String>(dateKey.value);
    }
    if (hour.present) {
      map['hour'] = Variable<int>(hour.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (chars.present) {
      map['chars'] = Variable<int>(chars.value);
    }
    if (pages.present) {
      map['pages'] = Variable<int>(pages.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<int>(profileId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudySegmentsCompanion(')
          ..write('uid: $uid, ')
          ..write('deviceId: $deviceId, ')
          ..write('mediaKind: $mediaKind, ')
          ..write('mediaKey: $mediaKey, ')
          ..write('format: $format, ')
          ..write('title: $title, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('dateKey: $dateKey, ')
          ..write('hour: $hour, ')
          ..write('durationMs: $durationMs, ')
          ..write('chars: $chars, ')
          ..write('pages: $pages, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('profileId: $profileId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$FushiDatabase extends GeneratedDatabase {
  _$FushiDatabase(QueryExecutor e) : super(e);
  $FushiDatabaseManager get managers => $FushiDatabaseManager(this);
  late final $MediaOpenHistoryTable mediaOpenHistory = $MediaOpenHistoryTable(
    this,
  );
  late final $ReaderPositionsTable readerPositions = $ReaderPositionsTable(
    this,
  );
  late final $BookmarksTable bookmarks = $BookmarksTable(this);
  late final $ReadingStatisticsTable readingStatistics =
      $ReadingStatisticsTable(this);
  late final $ReadingHourlyLogsTable readingHourlyLogs =
      $ReadingHourlyLogsTable(this);
  late final $PreferencesTable preferences = $PreferencesTable(this);
  late final $EpubBooksTable epubBooks = $EpubBooksTable(this);
  late final $BookTagsTable bookTags = $BookTagsTable(this);
  late final $TagAssignmentsTable tagAssignments = $TagAssignmentsTable(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $ProfileSettingsTable profileSettings = $ProfileSettingsTable(
    this,
  );
  late final $MediaTypeProfilesTable mediaTypeProfiles =
      $MediaTypeProfilesTable(this);
  late final $BookProfilesTable bookProfiles = $BookProfilesTable(this);
  late final $LanguageProfilesTable languageProfiles = $LanguageProfilesTable(
    this,
  );
  late final $SeriesTable series = $SeriesTable(this);
  late final $ShelfEntriesTable shelfEntries = $ShelfEntriesTable(this);
  late final $MediaCollectionsTable mediaCollections = $MediaCollectionsTable(
    this,
  );
  late final $MediaCollectionItemsTable mediaCollectionItems =
      $MediaCollectionItemsTable(this);
  late final $BookCustomCssTable bookCustomCss = $BookCustomCssTable(this);
  late final $RevealedImagesTable revealedImages = $RevealedImagesTable(this);
  late final $ActivityEventsTable activityEvents = $ActivityEventsTable(this);
  late final $StudySegmentTombstonesTable studySegmentTombstones =
      $StudySegmentTombstonesTable(this);
  late final $StudySegmentsTable studySegments = $StudySegmentsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    mediaOpenHistory,
    readerPositions,
    bookmarks,
    readingStatistics,
    readingHourlyLogs,
    preferences,
    epubBooks,
    bookTags,
    tagAssignments,
    profiles,
    profileSettings,
    mediaTypeProfiles,
    bookProfiles,
    languageProfiles,
    series,
    shelfEntries,
    mediaCollections,
    mediaCollectionItems,
    bookCustomCss,
    revealedImages,
    activityEvents,
    studySegmentTombstones,
    studySegments,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'book_tags',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('tag_assignments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('profile_settings', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('media_type_profiles', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('book_profiles', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('language_profiles', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'series',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('shelf_entries', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'media_collections',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('media_collection_items', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$MediaOpenHistoryTableCreateCompanionBuilder =
    MediaOpenHistoryCompanion Function({
      required String mediaType,
      required String mediaSource,
      required String mediaId,
      Value<int> openedAt,
      Value<int> position,
      Value<int> duration,
      Value<String> snapshotJson,
      Value<int> rowid,
    });
typedef $$MediaOpenHistoryTableUpdateCompanionBuilder =
    MediaOpenHistoryCompanion Function({
      Value<String> mediaType,
      Value<String> mediaSource,
      Value<String> mediaId,
      Value<int> openedAt,
      Value<int> position,
      Value<int> duration,
      Value<String> snapshotJson,
      Value<int> rowid,
    });

class $$MediaOpenHistoryTableFilterComposer
    extends Composer<_$FushiDatabase, $MediaOpenHistoryTable> {
  $$MediaOpenHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaSource => $composableBuilder(
    column: $table.mediaSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaId => $composableBuilder(
    column: $table.mediaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MediaOpenHistoryTableOrderingComposer
    extends Composer<_$FushiDatabase, $MediaOpenHistoryTable> {
  $$MediaOpenHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaSource => $composableBuilder(
    column: $table.mediaSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaId => $composableBuilder(
    column: $table.mediaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MediaOpenHistoryTableAnnotationComposer
    extends Composer<_$FushiDatabase, $MediaOpenHistoryTable> {
  $$MediaOpenHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<String> get mediaSource => $composableBuilder(
    column: $table.mediaSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mediaId =>
      $composableBuilder(column: $table.mediaId, builder: (column) => column);

  GeneratedColumn<int> get openedAt =>
      $composableBuilder(column: $table.openedAt, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<String> get snapshotJson => $composableBuilder(
    column: $table.snapshotJson,
    builder: (column) => column,
  );
}

class $$MediaOpenHistoryTableTableManager
    extends
        RootTableManager<
          _$FushiDatabase,
          $MediaOpenHistoryTable,
          MediaOpenHistoryRow,
          $$MediaOpenHistoryTableFilterComposer,
          $$MediaOpenHistoryTableOrderingComposer,
          $$MediaOpenHistoryTableAnnotationComposer,
          $$MediaOpenHistoryTableCreateCompanionBuilder,
          $$MediaOpenHistoryTableUpdateCompanionBuilder,
          (
            MediaOpenHistoryRow,
            BaseReferences<
              _$FushiDatabase,
              $MediaOpenHistoryTable,
              MediaOpenHistoryRow
            >,
          ),
          MediaOpenHistoryRow,
          PrefetchHooks Function()
        > {
  $$MediaOpenHistoryTableTableManager(
    _$FushiDatabase db,
    $MediaOpenHistoryTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaOpenHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaOpenHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaOpenHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> mediaType = const Value.absent(),
                Value<String> mediaSource = const Value.absent(),
                Value<String> mediaId = const Value.absent(),
                Value<int> openedAt = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> duration = const Value.absent(),
                Value<String> snapshotJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaOpenHistoryCompanion(
                mediaType: mediaType,
                mediaSource: mediaSource,
                mediaId: mediaId,
                openedAt: openedAt,
                position: position,
                duration: duration,
                snapshotJson: snapshotJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String mediaType,
                required String mediaSource,
                required String mediaId,
                Value<int> openedAt = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> duration = const Value.absent(),
                Value<String> snapshotJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaOpenHistoryCompanion.insert(
                mediaType: mediaType,
                mediaSource: mediaSource,
                mediaId: mediaId,
                openedAt: openedAt,
                position: position,
                duration: duration,
                snapshotJson: snapshotJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MediaOpenHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$FushiDatabase,
      $MediaOpenHistoryTable,
      MediaOpenHistoryRow,
      $$MediaOpenHistoryTableFilterComposer,
      $$MediaOpenHistoryTableOrderingComposer,
      $$MediaOpenHistoryTableAnnotationComposer,
      $$MediaOpenHistoryTableCreateCompanionBuilder,
      $$MediaOpenHistoryTableUpdateCompanionBuilder,
      (
        MediaOpenHistoryRow,
        BaseReferences<
          _$FushiDatabase,
          $MediaOpenHistoryTable,
          MediaOpenHistoryRow
        >,
      ),
      MediaOpenHistoryRow,
      PrefetchHooks Function()
    >;
typedef $$ReaderPositionsTableCreateCompanionBuilder =
    ReaderPositionsCompanion Function({
      Value<int> id,
      required String bookUid,
      required int sectionIndex,
      required int normCharOffset,
      Value<int> charOffset,
      required int updatedAt,
    });
typedef $$ReaderPositionsTableUpdateCompanionBuilder =
    ReaderPositionsCompanion Function({
      Value<int> id,
      Value<String> bookUid,
      Value<int> sectionIndex,
      Value<int> normCharOffset,
      Value<int> charOffset,
      Value<int> updatedAt,
    });

class $$ReaderPositionsTableFilterComposer
    extends Composer<_$FushiDatabase, $ReaderPositionsTable> {
  $$ReaderPositionsTableFilterComposer({
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

  ColumnFilters<String> get bookUid => $composableBuilder(
    column: $table.bookUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sectionIndex => $composableBuilder(
    column: $table.sectionIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get normCharOffset => $composableBuilder(
    column: $table.normCharOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get charOffset => $composableBuilder(
    column: $table.charOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReaderPositionsTableOrderingComposer
    extends Composer<_$FushiDatabase, $ReaderPositionsTable> {
  $$ReaderPositionsTableOrderingComposer({
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

  ColumnOrderings<String> get bookUid => $composableBuilder(
    column: $table.bookUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sectionIndex => $composableBuilder(
    column: $table.sectionIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get normCharOffset => $composableBuilder(
    column: $table.normCharOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get charOffset => $composableBuilder(
    column: $table.charOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReaderPositionsTableAnnotationComposer
    extends Composer<_$FushiDatabase, $ReaderPositionsTable> {
  $$ReaderPositionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookUid =>
      $composableBuilder(column: $table.bookUid, builder: (column) => column);

  GeneratedColumn<int> get sectionIndex => $composableBuilder(
    column: $table.sectionIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get normCharOffset => $composableBuilder(
    column: $table.normCharOffset,
    builder: (column) => column,
  );

  GeneratedColumn<int> get charOffset => $composableBuilder(
    column: $table.charOffset,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ReaderPositionsTableTableManager
    extends
        RootTableManager<
          _$FushiDatabase,
          $ReaderPositionsTable,
          ReaderPositionRow,
          $$ReaderPositionsTableFilterComposer,
          $$ReaderPositionsTableOrderingComposer,
          $$ReaderPositionsTableAnnotationComposer,
          $$ReaderPositionsTableCreateCompanionBuilder,
          $$ReaderPositionsTableUpdateCompanionBuilder,
          (
            ReaderPositionRow,
            BaseReferences<
              _$FushiDatabase,
              $ReaderPositionsTable,
              ReaderPositionRow
            >,
          ),
          ReaderPositionRow,
          PrefetchHooks Function()
        > {
  $$ReaderPositionsTableTableManager(
    _$FushiDatabase db,
    $ReaderPositionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReaderPositionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReaderPositionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReaderPositionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> bookUid = const Value.absent(),
                Value<int> sectionIndex = const Value.absent(),
                Value<int> normCharOffset = const Value.absent(),
                Value<int> charOffset = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => ReaderPositionsCompanion(
                id: id,
                bookUid: bookUid,
                sectionIndex: sectionIndex,
                normCharOffset: normCharOffset,
                charOffset: charOffset,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String bookUid,
                required int sectionIndex,
                required int normCharOffset,
                Value<int> charOffset = const Value.absent(),
                required int updatedAt,
              }) => ReaderPositionsCompanion.insert(
                id: id,
                bookUid: bookUid,
                sectionIndex: sectionIndex,
                normCharOffset: normCharOffset,
                charOffset: charOffset,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReaderPositionsTableProcessedTableManager =
    ProcessedTableManager<
      _$FushiDatabase,
      $ReaderPositionsTable,
      ReaderPositionRow,
      $$ReaderPositionsTableFilterComposer,
      $$ReaderPositionsTableOrderingComposer,
      $$ReaderPositionsTableAnnotationComposer,
      $$ReaderPositionsTableCreateCompanionBuilder,
      $$ReaderPositionsTableUpdateCompanionBuilder,
      (
        ReaderPositionRow,
        BaseReferences<
          _$FushiDatabase,
          $ReaderPositionsTable,
          ReaderPositionRow
        >,
      ),
      ReaderPositionRow,
      PrefetchHooks Function()
    >;
typedef $$BookmarksTableCreateCompanionBuilder =
    BookmarksCompanion Function({
      Value<int> id,
      required String bookUid,
      required int sectionIndex,
      required int normCharOffset,
      required String label,
      required int createdAt,
      Value<String?> bookTitle,
      Value<int?> pageInChapter,
      Value<int?> totalPagesInChapter,
    });
typedef $$BookmarksTableUpdateCompanionBuilder =
    BookmarksCompanion Function({
      Value<int> id,
      Value<String> bookUid,
      Value<int> sectionIndex,
      Value<int> normCharOffset,
      Value<String> label,
      Value<int> createdAt,
      Value<String?> bookTitle,
      Value<int?> pageInChapter,
      Value<int?> totalPagesInChapter,
    });

class $$BookmarksTableFilterComposer
    extends Composer<_$FushiDatabase, $BookmarksTable> {
  $$BookmarksTableFilterComposer({
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

  ColumnFilters<String> get bookUid => $composableBuilder(
    column: $table.bookUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sectionIndex => $composableBuilder(
    column: $table.sectionIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get normCharOffset => $composableBuilder(
    column: $table.normCharOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookTitle => $composableBuilder(
    column: $table.bookTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageInChapter => $composableBuilder(
    column: $table.pageInChapter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalPagesInChapter => $composableBuilder(
    column: $table.totalPagesInChapter,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookmarksTableOrderingComposer
    extends Composer<_$FushiDatabase, $BookmarksTable> {
  $$BookmarksTableOrderingComposer({
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

  ColumnOrderings<String> get bookUid => $composableBuilder(
    column: $table.bookUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sectionIndex => $composableBuilder(
    column: $table.sectionIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get normCharOffset => $composableBuilder(
    column: $table.normCharOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookTitle => $composableBuilder(
    column: $table.bookTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageInChapter => $composableBuilder(
    column: $table.pageInChapter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalPagesInChapter => $composableBuilder(
    column: $table.totalPagesInChapter,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookmarksTableAnnotationComposer
    extends Composer<_$FushiDatabase, $BookmarksTable> {
  $$BookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookUid =>
      $composableBuilder(column: $table.bookUid, builder: (column) => column);

  GeneratedColumn<int> get sectionIndex => $composableBuilder(
    column: $table.sectionIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get normCharOffset => $composableBuilder(
    column: $table.normCharOffset,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get bookTitle =>
      $composableBuilder(column: $table.bookTitle, builder: (column) => column);

  GeneratedColumn<int> get pageInChapter => $composableBuilder(
    column: $table.pageInChapter,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalPagesInChapter => $composableBuilder(
    column: $table.totalPagesInChapter,
    builder: (column) => column,
  );
}

class $$BookmarksTableTableManager
    extends
        RootTableManager<
          _$FushiDatabase,
          $BookmarksTable,
          BookmarkRow,
          $$BookmarksTableFilterComposer,
          $$BookmarksTableOrderingComposer,
          $$BookmarksTableAnnotationComposer,
          $$BookmarksTableCreateCompanionBuilder,
          $$BookmarksTableUpdateCompanionBuilder,
          (
            BookmarkRow,
            BaseReferences<_$FushiDatabase, $BookmarksTable, BookmarkRow>,
          ),
          BookmarkRow,
          PrefetchHooks Function()
        > {
  $$BookmarksTableTableManager(_$FushiDatabase db, $BookmarksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> bookUid = const Value.absent(),
                Value<int> sectionIndex = const Value.absent(),
                Value<int> normCharOffset = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String?> bookTitle = const Value.absent(),
                Value<int?> pageInChapter = const Value.absent(),
                Value<int?> totalPagesInChapter = const Value.absent(),
              }) => BookmarksCompanion(
                id: id,
                bookUid: bookUid,
                sectionIndex: sectionIndex,
                normCharOffset: normCharOffset,
                label: label,
                createdAt: createdAt,
                bookTitle: bookTitle,
                pageInChapter: pageInChapter,
                totalPagesInChapter: totalPagesInChapter,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String bookUid,
                required int sectionIndex,
                required int normCharOffset,
                required String label,
                required int createdAt,
                Value<String?> bookTitle = const Value.absent(),
                Value<int?> pageInChapter = const Value.absent(),
                Value<int?> totalPagesInChapter = const Value.absent(),
              }) => BookmarksCompanion.insert(
                id: id,
                bookUid: bookUid,
                sectionIndex: sectionIndex,
                normCharOffset: normCharOffset,
                label: label,
                createdAt: createdAt,
                bookTitle: bookTitle,
                pageInChapter: pageInChapter,
                totalPagesInChapter: totalPagesInChapter,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$FushiDatabase,
      $BookmarksTable,
      BookmarkRow,
      $$BookmarksTableFilterComposer,
      $$BookmarksTableOrderingComposer,
      $$BookmarksTableAnnotationComposer,
      $$BookmarksTableCreateCompanionBuilder,
      $$BookmarksTableUpdateCompanionBuilder,
      (
        BookmarkRow,
        BaseReferences<_$FushiDatabase, $BookmarksTable, BookmarkRow>,
      ),
      BookmarkRow,
      PrefetchHooks Function()
    >;
typedef $$ReadingStatisticsTableCreateCompanionBuilder =
    ReadingStatisticsCompanion Function({
      Value<int> id,
      required String title,
      required String dateKey,
      required int charactersRead,
      required int readingTimeMs,
      Value<int> pagesRead,
      required int lastStatisticModified,
    });
typedef $$ReadingStatisticsTableUpdateCompanionBuilder =
    ReadingStatisticsCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String> dateKey,
      Value<int> charactersRead,
      Value<int> readingTimeMs,
      Value<int> pagesRead,
      Value<int> lastStatisticModified,
    });

class $$ReadingStatisticsTableFilterComposer
    extends Composer<_$FushiDatabase, $ReadingStatisticsTable> {
  $$ReadingStatisticsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get charactersRead => $composableBuilder(
    column: $table.charactersRead,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get readingTimeMs => $composableBuilder(
    column: $table.readingTimeMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pagesRead => $composableBuilder(
    column: $table.pagesRead,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastStatisticModified => $composableBuilder(
    column: $table.lastStatisticModified,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReadingStatisticsTableOrderingComposer
    extends Composer<_$FushiDatabase, $ReadingStatisticsTable> {
  $$ReadingStatisticsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get charactersRead => $composableBuilder(
    column: $table.charactersRead,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get readingTimeMs => $composableBuilder(
    column: $table.readingTimeMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pagesRead => $composableBuilder(
    column: $table.pagesRead,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastStatisticModified => $composableBuilder(
    column: $table.lastStatisticModified,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReadingStatisticsTableAnnotationComposer
    extends Composer<_$FushiDatabase, $ReadingStatisticsTable> {
  $$ReadingStatisticsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get dateKey =>
      $composableBuilder(column: $table.dateKey, builder: (column) => column);

  GeneratedColumn<int> get charactersRead => $composableBuilder(
    column: $table.charactersRead,
    builder: (column) => column,
  );

  GeneratedColumn<int> get readingTimeMs => $composableBuilder(
    column: $table.readingTimeMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pagesRead =>
      $composableBuilder(column: $table.pagesRead, builder: (column) => column);

  GeneratedColumn<int> get lastStatisticModified => $composableBuilder(
    column: $table.lastStatisticModified,
    builder: (column) => column,
  );
}

class $$ReadingStatisticsTableTableManager
    extends
        RootTableManager<
          _$FushiDatabase,
          $ReadingStatisticsTable,
          ReadingStatisticRow,
          $$ReadingStatisticsTableFilterComposer,
          $$ReadingStatisticsTableOrderingComposer,
          $$ReadingStatisticsTableAnnotationComposer,
          $$ReadingStatisticsTableCreateCompanionBuilder,
          $$ReadingStatisticsTableUpdateCompanionBuilder,
          (
            ReadingStatisticRow,
            BaseReferences<
              _$FushiDatabase,
              $ReadingStatisticsTable,
              ReadingStatisticRow
            >,
          ),
          ReadingStatisticRow,
          PrefetchHooks Function()
        > {
  $$ReadingStatisticsTableTableManager(
    _$FushiDatabase db,
    $ReadingStatisticsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingStatisticsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingStatisticsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingStatisticsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> dateKey = const Value.absent(),
                Value<int> charactersRead = const Value.absent(),
                Value<int> readingTimeMs = const Value.absent(),
                Value<int> pagesRead = const Value.absent(),
                Value<int> lastStatisticModified = const Value.absent(),
              }) => ReadingStatisticsCompanion(
                id: id,
                title: title,
                dateKey: dateKey,
                charactersRead: charactersRead,
                readingTimeMs: readingTimeMs,
                pagesRead: pagesRead,
                lastStatisticModified: lastStatisticModified,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required String dateKey,
                required int charactersRead,
                required int readingTimeMs,
                Value<int> pagesRead = const Value.absent(),
                required int lastStatisticModified,
              }) => ReadingStatisticsCompanion.insert(
                id: id,
                title: title,
                dateKey: dateKey,
                charactersRead: charactersRead,
                readingTimeMs: readingTimeMs,
                pagesRead: pagesRead,
                lastStatisticModified: lastStatisticModified,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReadingStatisticsTableProcessedTableManager =
    ProcessedTableManager<
      _$FushiDatabase,
      $ReadingStatisticsTable,
      ReadingStatisticRow,
      $$ReadingStatisticsTableFilterComposer,
      $$ReadingStatisticsTableOrderingComposer,
      $$ReadingStatisticsTableAnnotationComposer,
      $$ReadingStatisticsTableCreateCompanionBuilder,
      $$ReadingStatisticsTableUpdateCompanionBuilder,
      (
        ReadingStatisticRow,
        BaseReferences<
          _$FushiDatabase,
          $ReadingStatisticsTable,
          ReadingStatisticRow
        >,
      ),
      ReadingStatisticRow,
      PrefetchHooks Function()
    >;
typedef $$ReadingHourlyLogsTableCreateCompanionBuilder =
    ReadingHourlyLogsCompanion Function({
      Value<int> id,
      required String dateKey,
      required int hour,
      required int readingTimeMs,
      Value<String> format,
    });
typedef $$ReadingHourlyLogsTableUpdateCompanionBuilder =
    ReadingHourlyLogsCompanion Function({
      Value<int> id,
      Value<String> dateKey,
      Value<int> hour,
      Value<int> readingTimeMs,
      Value<String> format,
    });

class $$ReadingHourlyLogsTableFilterComposer
    extends Composer<_$FushiDatabase, $ReadingHourlyLogsTable> {
  $$ReadingHourlyLogsTableFilterComposer({
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

  ColumnFilters<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hour => $composableBuilder(
    column: $table.hour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get readingTimeMs => $composableBuilder(
    column: $table.readingTimeMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReadingHourlyLogsTableOrderingComposer
    extends Composer<_$FushiDatabase, $ReadingHourlyLogsTable> {
  $$ReadingHourlyLogsTableOrderingComposer({
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

  ColumnOrderings<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hour => $composableBuilder(
    column: $table.hour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get readingTimeMs => $composableBuilder(
    column: $table.readingTimeMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReadingHourlyLogsTableAnnotationComposer
    extends Composer<_$FushiDatabase, $ReadingHourlyLogsTable> {
  $$ReadingHourlyLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dateKey =>
      $composableBuilder(column: $table.dateKey, builder: (column) => column);

  GeneratedColumn<int> get hour =>
      $composableBuilder(column: $table.hour, builder: (column) => column);

  GeneratedColumn<int> get readingTimeMs => $composableBuilder(
    column: $table.readingTimeMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);
}

class $$ReadingHourlyLogsTableTableManager
    extends
        RootTableManager<
          _$FushiDatabase,
          $ReadingHourlyLogsTable,
          ReadingHourlyLogRow,
          $$ReadingHourlyLogsTableFilterComposer,
          $$ReadingHourlyLogsTableOrderingComposer,
          $$ReadingHourlyLogsTableAnnotationComposer,
          $$ReadingHourlyLogsTableCreateCompanionBuilder,
          $$ReadingHourlyLogsTableUpdateCompanionBuilder,
          (
            ReadingHourlyLogRow,
            BaseReferences<
              _$FushiDatabase,
              $ReadingHourlyLogsTable,
              ReadingHourlyLogRow
            >,
          ),
          ReadingHourlyLogRow,
          PrefetchHooks Function()
        > {
  $$ReadingHourlyLogsTableTableManager(
    _$FushiDatabase db,
    $ReadingHourlyLogsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingHourlyLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingHourlyLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingHourlyLogsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> dateKey = const Value.absent(),
                Value<int> hour = const Value.absent(),
                Value<int> readingTimeMs = const Value.absent(),
                Value<String> format = const Value.absent(),
              }) => ReadingHourlyLogsCompanion(
                id: id,
                dateKey: dateKey,
                hour: hour,
                readingTimeMs: readingTimeMs,
                format: format,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String dateKey,
                required int hour,
                required int readingTimeMs,
                Value<String> format = const Value.absent(),
              }) => ReadingHourlyLogsCompanion.insert(
                id: id,
                dateKey: dateKey,
                hour: hour,
                readingTimeMs: readingTimeMs,
                format: format,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReadingHourlyLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$FushiDatabase,
      $ReadingHourlyLogsTable,
      ReadingHourlyLogRow,
      $$ReadingHourlyLogsTableFilterComposer,
      $$ReadingHourlyLogsTableOrderingComposer,
      $$ReadingHourlyLogsTableAnnotationComposer,
      $$ReadingHourlyLogsTableCreateCompanionBuilder,
      $$ReadingHourlyLogsTableUpdateCompanionBuilder,
      (
        ReadingHourlyLogRow,
        BaseReferences<
          _$FushiDatabase,
          $ReadingHourlyLogsTable,
          ReadingHourlyLogRow
        >,
      ),
      ReadingHourlyLogRow,
      PrefetchHooks Function()
    >;
typedef $$PreferencesTableCreateCompanionBuilder =
    PreferencesCompanion Function({
      required String key,
      required String value,
      Value<int> updatedAt,
      Value<int> rowid,
    });
typedef $$PreferencesTableUpdateCompanionBuilder =
    PreferencesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$PreferencesTableFilterComposer
    extends Composer<_$FushiDatabase, $PreferencesTable> {
  $$PreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PreferencesTableOrderingComposer
    extends Composer<_$FushiDatabase, $PreferencesTable> {
  $$PreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PreferencesTableAnnotationComposer
    extends Composer<_$FushiDatabase, $PreferencesTable> {
  $$PreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PreferencesTableTableManager
    extends
        RootTableManager<
          _$FushiDatabase,
          $PreferencesTable,
          PreferenceRow,
          $$PreferencesTableFilterComposer,
          $$PreferencesTableOrderingComposer,
          $$PreferencesTableAnnotationComposer,
          $$PreferencesTableCreateCompanionBuilder,
          $$PreferencesTableUpdateCompanionBuilder,
          (
            PreferenceRow,
            BaseReferences<_$FushiDatabase, $PreferencesTable, PreferenceRow>,
          ),
          PreferenceRow,
          PrefetchHooks Function()
        > {
  $$PreferencesTableTableManager(_$FushiDatabase db, $PreferencesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PreferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PreferencesCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PreferencesCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$FushiDatabase,
      $PreferencesTable,
      PreferenceRow,
      $$PreferencesTableFilterComposer,
      $$PreferencesTableOrderingComposer,
      $$PreferencesTableAnnotationComposer,
      $$PreferencesTableCreateCompanionBuilder,
      $$PreferencesTableUpdateCompanionBuilder,
      (
        PreferenceRow,
        BaseReferences<_$FushiDatabase, $PreferencesTable, PreferenceRow>,
      ),
      PreferenceRow,
      PrefetchHooks Function()
    >;
typedef $$EpubBooksTableCreateCompanionBuilder =
    EpubBooksCompanion Function({
      required String bookKey,
      Value<String> uid,
      required String title,
      Value<String?> author,
      Value<String?> coverPath,
      required String epubPath,
      required String extractDir,
      required int chapterCount,
      required String chaptersJson,
      Value<String?> tocJson,
      Value<String?> sourceMetadata,
      required int importedAt,
      Value<String?> language,
      Value<String> format,
      Value<DateTime?> completedAt,
      Value<String?> isbn,
      Value<int> rowid,
    });
typedef $$EpubBooksTableUpdateCompanionBuilder =
    EpubBooksCompanion Function({
      Value<String> bookKey,
      Value<String> uid,
      Value<String> title,
      Value<String?> author,
      Value<String?> coverPath,
      Value<String> epubPath,
      Value<String> extractDir,
      Value<int> chapterCount,
      Value<String> chaptersJson,
      Value<String?> tocJson,
      Value<String?> sourceMetadata,
      Value<int> importedAt,
      Value<String?> language,
      Value<String> format,
      Value<DateTime?> completedAt,
      Value<String?> isbn,
      Value<int> rowid,
    });

class $$EpubBooksTableFilterComposer
    extends Composer<_$FushiDatabase, $EpubBooksTable> {
  $$EpubBooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookKey => $composableBuilder(
    column: $table.bookKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get epubPath => $composableBuilder(
    column: $table.epubPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extractDir => $composableBuilder(
    column: $table.extractDir,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterCount => $composableBuilder(
    column: $table.chapterCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chaptersJson => $composableBuilder(
    column: $table.chaptersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tocJson => $composableBuilder(
    column: $table.tocJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceMetadata => $composableBuilder(
    column: $table.sourceMetadata,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get isbn => $composableBuilder(
    column: $table.isbn,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EpubBooksTableOrderingComposer
    extends Composer<_$FushiDatabase, $EpubBooksTable> {
  $$EpubBooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookKey => $composableBuilder(
    column: $table.bookKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get epubPath => $composableBuilder(
    column: $table.epubPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extractDir => $composableBuilder(
    column: $table.extractDir,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterCount => $composableBuilder(
    column: $table.chapterCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chaptersJson => $composableBuilder(
    column: $table.chaptersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tocJson => $composableBuilder(
    column: $table.tocJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceMetadata => $composableBuilder(
    column: $table.sourceMetadata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get isbn => $composableBuilder(
    column: $table.isbn,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EpubBooksTableAnnotationComposer
    extends Composer<_$FushiDatabase, $EpubBooksTable> {
  $$EpubBooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookKey =>
      $composableBuilder(column: $table.bookKey, builder: (column) => column);

  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<String> get epubPath =>
      $composableBuilder(column: $table.epubPath, builder: (column) => column);

  GeneratedColumn<String> get extractDir => $composableBuilder(
    column: $table.extractDir,
    builder: (column) => column,
  );

  GeneratedColumn<int> get chapterCount => $composableBuilder(
    column: $table.chapterCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chaptersJson => $composableBuilder(
    column: $table.chaptersJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tocJson =>
      $composableBuilder(column: $table.tocJson, builder: (column) => column);

  GeneratedColumn<String> get sourceMetadata => $composableBuilder(
    column: $table.sourceMetadata,
    builder: (column) => column,
  );

  GeneratedColumn<int> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get isbn =>
      $composableBuilder(column: $table.isbn, builder: (column) => column);
}

class $$EpubBooksTableTableManager
    extends
        RootTableManager<
          _$FushiDatabase,
          $EpubBooksTable,
          EpubBookRow,
          $$EpubBooksTableFilterComposer,
          $$EpubBooksTableOrderingComposer,
          $$EpubBooksTableAnnotationComposer,
          $$EpubBooksTableCreateCompanionBuilder,
          $$EpubBooksTableUpdateCompanionBuilder,
          (
            EpubBookRow,
            BaseReferences<_$FushiDatabase, $EpubBooksTable, EpubBookRow>,
          ),
          EpubBookRow,
          PrefetchHooks Function()
        > {
  $$EpubBooksTableTableManager(_$FushiDatabase db, $EpubBooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpubBooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpubBooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpubBooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> bookKey = const Value.absent(),
                Value<String> uid = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<String> epubPath = const Value.absent(),
                Value<String> extractDir = const Value.absent(),
                Value<int> chapterCount = const Value.absent(),
                Value<String> chaptersJson = const Value.absent(),
                Value<String?> tocJson = const Value.absent(),
                Value<String?> sourceMetadata = const Value.absent(),
                Value<int> importedAt = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String?> isbn = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpubBooksCompanion(
                bookKey: bookKey,
                uid: uid,
                title: title,
                author: author,
                coverPath: coverPath,
                epubPath: epubPath,
                extractDir: extractDir,
                chapterCount: chapterCount,
                chaptersJson: chaptersJson,
                tocJson: tocJson,
                sourceMetadata: sourceMetadata,
                importedAt: importedAt,
                language: language,
                format: format,
                completedAt: completedAt,
                isbn: isbn,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookKey,
                Value<String> uid = const Value.absent(),
                required String title,
                Value<String?> author = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                required String epubPath,
                required String extractDir,
                required int chapterCount,
                required String chaptersJson,
                Value<String?> tocJson = const Value.absent(),
                Value<String?> sourceMetadata = const Value.absent(),
                required int importedAt,
                Value<String?> language = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String?> isbn = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpubBooksCompanion.insert(
                bookKey: bookKey,
                uid: uid,
                title: title,
                author: author,
                coverPath: coverPath,
                epubPath: epubPath,
                extractDir: extractDir,
                chapterCount: chapterCount,
                chaptersJson: chaptersJson,
                tocJson: tocJson,
                sourceMetadata: sourceMetadata,
                importedAt: importedAt,
                language: language,
                format: format,
                completedAt: completedAt,
                isbn: isbn,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EpubBooksTableProcessedTableManager =
    ProcessedTableManager<
      _$FushiDatabase,
      $EpubBooksTable,
      EpubBookRow,
      $$EpubBooksTableFilterComposer,
      $$EpubBooksTableOrderingComposer,
      $$EpubBooksTableAnnotationComposer,
      $$EpubBooksTableCreateCompanionBuilder,
      $$EpubBooksTableUpdateCompanionBuilder,
      (
        EpubBookRow,
        BaseReferences<_$FushiDatabase, $EpubBooksTable, EpubBookRow>,
      ),
      EpubBookRow,
      PrefetchHooks Function()
    >;
typedef $$BookTagsTableCreateCompanionBuilder =
    BookTagsCompanion Function({
      Value<int> id,
      required String name,
      Value<int> colorValue,
      Value<int> sortOrder,
      required int createdAt,
    });
typedef $$BookTagsTableUpdateCompanionBuilder =
    BookTagsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> colorValue,
      Value<int> sortOrder,
      Value<int> createdAt,
    });

final class $$BookTagsTableReferences
    extends BaseReferences<_$FushiDatabase, $BookTagsTable, BookTagRow> {
  $$BookTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TagAssignmentsTable, List<TagAssignmentRow>>
  _tagAssignmentsRefsTable(_$FushiDatabase db) => MultiTypedResultKey.fromTable(
    db.tagAssignments,
    aliasName: 'book_tags__id__tag_assignments__tag_id',
  );

  $$TagAssignmentsTableProcessedTableManager get tagAssignmentsRefs {
    final manager = $$TagAssignmentsTableTableManager(
      $_db,
      $_db.tagAssignments,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_tagAssignmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BookTagsTableFilterComposer
    extends Composer<_$FushiDatabase, $BookTagsTable> {
  $$BookTagsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> tagAssignmentsRefs(
    Expression<bool> Function($$TagAssignmentsTableFilterComposer f) f,
  ) {
    final $$TagAssignmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tagAssignments,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagAssignmentsTableFilterComposer(
            $db: $db,
            $table: $db.tagAssignments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BookTagsTableOrderingComposer
    extends Composer<_$FushiDatabase, $BookTagsTable> {
  $$BookTagsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookTagsTableAnnotationComposer
    extends Composer<_$FushiDatabase, $BookTagsTable> {
  $$BookTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> tagAssignmentsRefs<T extends Object>(
    Expression<T> Function($$TagAssignmentsTableAnnotationComposer a) f,
  ) {
    final $$TagAssignmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tagAssignments,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagAssignmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.tagAssignments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BookTagsTableTableManager
    extends
        RootTableManager<
          _$FushiDatabase,
          $BookTagsTable,
          BookTagRow,
          $$BookTagsTableFilterComposer,
          $$BookTagsTableOrderingComposer,
          $$BookTagsTableAnnotationComposer,
          $$BookTagsTableCreateCompanionBuilder,
          $$BookTagsTableUpdateCompanionBuilder,
          (BookTagRow, $$BookTagsTableReferences),
          BookTagRow,
          PrefetchHooks Function({bool tagAssignmentsRefs})
        > {
  $$BookTagsTableTableManager(_$FushiDatabase db, $BookTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => BookTagsCompanion(
                id: id,
                name: name,
                colorValue: colorValue,
                sortOrder: sortOrder,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int> colorValue = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required int createdAt,
              }) => BookTagsCompanion.insert(
                id: id,
                name: name,
                colorValue: colorValue,
                sortOrder: sortOrder,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BookTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tagAssignmentsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (tagAssignmentsRefs) db.tagAssignments,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (tagAssignmentsRefs)
                    await $_getPrefetchedData<
                      BookTagRow,
                      $BookTagsTable,
                      TagAssignmentRow
                    >(
                      currentTable: table,
                      referencedTable: $$BookTagsTableReferences
                          ._tagAssignmentsRefsTable(db),
                      managerFromTypedResult: (p0) => $$BookTagsTableReferences(
                        db,
                        table,
                        p0,
                      ).tagAssignmentsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tagId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$BookTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$FushiDatabase,
      $BookTagsTable,
      BookTagRow,
      $$BookTagsTableFilterComposer,
      $$BookTagsTableOrderingComposer,
      $$BookTagsTableAnnotationComposer,
      $$BookTagsTableCreateCompanionBuilder,
      $$BookTagsTableUpdateCompanionBuilder,
      (BookTagRow, $$BookTagsTableReferences),
      BookTagRow,
      PrefetchHooks Function({bool tagAssignmentsRefs})
    >;
typedef $$TagAssignmentsTableCreateCompanionBuilder =
    TagAssignmentsCompanion Function({
      required String mediaKind,
      required String entryKey,
      required int tagId,
      Value<int> addedAt,
      Value<int> rowid,
    });
typedef $$TagAssignmentsTableUpdateCompanionBuilder =
    TagAssignmentsCompanion Function({
      Value<String> mediaKind,
      Value<String> entryKey,
      Value<int> tagId,
      Value<int> addedAt,
      Value<int> rowid,
    });

final class $$TagAssignmentsTableReferences
    extends
        BaseReferences<
          _$FushiDatabase,
          $TagAssignmentsTable,
          TagAssignmentRow
        > {
  $$TagAssignmentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $BookTagsTable _tagIdTable(_$FushiDatabase db) =>
      db.bookTags.createAlias('tag_assignments__tag_id__book_tags__id');

  $$BookTagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<int>('tag_id')!;

    final manager = $$BookTagsTableTableManager(
      $_db,
      $_db.bookTags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TagAssignmentsTableFilterComposer
    extends Composer<_$FushiDatabase, $TagAssignmentsTable> {
  $$TagAssignmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get mediaKind => $composableBuilder(
    column: $table.mediaKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entryKey => $composableBuilder(
    column: $table.entryKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$BookTagsTableFilterComposer get tagId {
    final $$BookTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.bookTags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookTagsTableFilterComposer(
            $db: $db,
            $table: $db.bookTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TagAssignmentsTableOrderingComposer
    extends Composer<_$FushiDatabase, $TagAssignmentsTable> {
  $$TagAssignmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get mediaKind => $composableBuilder(
    column: $table.mediaKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryKey => $composableBuilder(
    column: $table.entryKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$BookTagsTableOrderingComposer get tagId {
    final $$BookTagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.bookTags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookTagsTableOrderingComposer(
            $db: $db,
            $table: $db.bookTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TagAssignmentsTableAnnotationComposer
    extends Composer<_$FushiDatabase, $TagAssignmentsTable> {
  $$TagAssignmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get mediaKind =>
      $composableBuilder(column: $table.mediaKind, builder: (column) => column);

  GeneratedColumn<String> get entryKey =>
      $composableBuilder(column: $table.entryKey, builder: (column) => column);

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$BookTagsTableAnnotationComposer get tagId {
    final $$BookTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.bookTags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.bookTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TagAssignmentsTableTableManager
    extends
        RootTableManager<
          _$FushiDatabase,
          $TagAssignmentsTable,
          TagAssignmentRow,
          $$TagAssignmentsTableFilterComposer,
          $$TagAssignmentsTableOrderingComposer,
          $$TagAssignmentsTableAnnotationComposer,
          $$TagAssignmentsTableCreateCompanionBuilder,
          $$TagAssignmentsTableUpdateCompanionBuilder,
          (TagAssignmentRow, $$TagAssignmentsTableReferences),
          TagAssignmentRow,
          PrefetchHooks Function({bool tagId})
        > {
  $$TagAssignmentsTableTableManager(
    _$FushiDatabase db,
    $TagAssignmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagAssignmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagAssignmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagAssignmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> mediaKind = const Value.absent(),
                Value<String> entryKey = const Value.absent(),
                Value<int> tagId = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagAssignmentsCompanion(
                mediaKind: mediaKind,
                entryKey: entryKey,
                tagId: tagId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String mediaKind,
                required String entryKey,
                required int tagId,
                Value<int> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagAssignmentsCompanion.insert(
                mediaKind: mediaKind,
                entryKey: entryKey,
                tagId: tagId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TagAssignmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tagId = false}) {
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
                    if (tagId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tagId,
                                referencedTable: $$TagAssignmentsTableReferences
                                    ._tagIdTable(db),
                                referencedColumn:
                                    $$TagAssignmentsTableReferences
                                        ._tagIdTable(db)
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

typedef $$TagAssignmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$FushiDatabase,
      $TagAssignmentsTable,
      TagAssignmentRow,
      $$TagAssignmentsTableFilterComposer,
      $$TagAssignmentsTableOrderingComposer,
      $$TagAssignmentsTableAnnotationComposer,
      $$TagAssignmentsTableCreateCompanionBuilder,
      $$TagAssignmentsTableUpdateCompanionBuilder,
      (TagAssignmentRow, $$TagAssignmentsTableReferences),
      TagAssignmentRow,
      PrefetchHooks Function({bool tagId})
    >;
typedef $$ProfilesTableCreateCompanionBuilder =
    ProfilesCompanion Function({
      Value<int> id,
      required String name,
      required int createdAt,
      required int updatedAt,
    });
typedef $$ProfilesTableUpdateCompanionBuilder =
    ProfilesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> createdAt,
      Value<int> updatedAt,
    });

final class $$ProfilesTableReferences
    extends BaseReferences<_$FushiDatabase, $ProfilesTable, ProfileRow> {
  $$ProfilesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ProfileSettingsTable, List<ProfileSettingRow>>
  _profileSettingsRefsTable(_$FushiDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.profileSettings,
        aliasName: 'profiles__id__profile_settings__profile_id',
      );

  $$ProfileSettingsTableProcessedTableManager get profileSettingsRefs {
    final manager = $$ProfileSettingsTableTableManager(
      $_db,
      $_db.profileSettings,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _profileSettingsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MediaTypeProfilesTable, List<MediaTypeProfileRow>>
  _mediaTypeProfilesRefsTable(_$FushiDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.mediaTypeProfiles,
        aliasName: 'profiles__id__media_type_profiles__profile_id',
      );

  $$MediaTypeProfilesTableProcessedTableManager get mediaTypeProfilesRefs {
    final manager = $$MediaTypeProfilesTableTableManager(
      $_db,
      $_db.mediaTypeProfiles,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _mediaTypeProfilesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BookProfilesTable, List<BookProfileRow>>
  _bookProfilesRefsTable(_$FushiDatabase db) => MultiTypedResultKey.fromTable(
    db.bookProfiles,
    aliasName: 'profiles__id__book_profiles__profile_id',
  );

  $$BookProfilesTableProcessedTableManager get bookProfilesRefs {
    final manager = $$BookProfilesTableTableManager(
      $_db,
      $_db.bookProfiles,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_bookProfilesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LanguageProfilesTable, List<LanguageProfileRow>>
  _languageProfilesRefsTable(_$FushiDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.languageProfiles,
        aliasName: 'profiles__id__language_profiles__profile_id',
      );

  $$LanguageProfilesTableProcessedTableManager get languageProfilesRefs {
    final manager = $$LanguageProfilesTableTableManager(
      $_db,
      $_db.languageProfiles,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _languageProfilesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProfilesTableFilterComposer
    extends Composer<_$FushiDatabase, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> profileSettingsRefs(
    Expression<bool> Function($$ProfileSettingsTableFilterComposer f) f,
  ) {
    final $$ProfileSettingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.profileSettings,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfileSettingsTableFilterComposer(
            $db: $db,
            $table: $db.profileSettings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> mediaTypeProfilesRefs(
    Expression<bool> Function($$MediaTypeProfilesTableFilterComposer f) f,
  ) {
    final $$MediaTypeProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mediaTypeProfiles,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaTypeProfilesTableFilterComposer(
            $db: $db,
            $table: $db.mediaTypeProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> bookProfilesRefs(
    Expression<bool> Function($$BookProfilesTableFilterComposer f) f,
  ) {
    final $$BookProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookProfiles,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookProfilesTableFilterComposer(
            $db: $db,
            $table: $db.bookProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> languageProfilesRefs(
    Expression<bool> Function($$LanguageProfilesTableFilterComposer f) f,
  ) {
    final $$LanguageProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.languageProfiles,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LanguageProfilesTableFilterComposer(
            $db: $db,
            $table: $db.languageProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProfilesTableOrderingComposer
    extends Composer<_$FushiDatabase, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfilesTableAnnotationComposer
    extends Composer<_$FushiDatabase, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> profileSettingsRefs<T extends Object>(
    Expression<T> Function($$ProfileSettingsTableAnnotationComposer a) f,
  ) {
    final $$ProfileSettingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.profileSettings,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfileSettingsTableAnnotationComposer(
            $db: $db,
            $table: $db.profileSettings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> mediaTypeProfilesRefs<T extends Object>(
    Expression<T> Function($$MediaTypeProfilesTableAnnotationComposer a) f,
  ) {
    final $$MediaTypeProfilesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.mediaTypeProfiles,
          getReferencedColumn: (t) => t.profileId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MediaTypeProfilesTableAnnotationComposer(
                $db: $db,
                $table: $db.mediaTypeProfiles,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> bookProfilesRefs<T extends Object>(
    Expression<T> Function($$BookProfilesTableAnnotationComposer a) f,
  ) {
    final $$BookProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookProfiles,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.bookProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> languageProfilesRefs<T extends Object>(
    Expression<T> Function($$LanguageProfilesTableAnnotationComposer a) f,
  ) {
    final $$LanguageProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.languageProfiles,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LanguageProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.languageProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProfilesTableTableManager
    extends
        RootTableManager<
          _$FushiDatabase,
          $ProfilesTable,
          ProfileRow,
          $$ProfilesTableFilterComposer,
          $$ProfilesTableOrderingComposer,
          $$ProfilesTableAnnotationComposer,
          $$ProfilesTableCreateCompanionBuilder,
          $$ProfilesTableUpdateCompanionBuilder,
          (ProfileRow, $$ProfilesTableReferences),
          ProfileRow,
          PrefetchHooks Function({
            bool profileSettingsRefs,
            bool mediaTypeProfilesRefs,
            bool bookProfilesRefs,
            bool languageProfilesRefs,
          })
        > {
  $$ProfilesTableTableManager(_$FushiDatabase db, $ProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => ProfilesCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required int createdAt,
                required int updatedAt,
              }) => ProfilesCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                profileSettingsRefs = false,
                mediaTypeProfilesRefs = false,
                bookProfilesRefs = false,
                languageProfilesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (profileSettingsRefs) db.profileSettings,
                    if (mediaTypeProfilesRefs) db.mediaTypeProfiles,
                    if (bookProfilesRefs) db.bookProfiles,
                    if (languageProfilesRefs) db.languageProfiles,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (profileSettingsRefs)
                        await $_getPrefetchedData<
                          ProfileRow,
                          $ProfilesTable,
                          ProfileSettingRow
                        >(
                          currentTable: table,
                          referencedTable: $$ProfilesTableReferences
                              ._profileSettingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).profileSettingsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (mediaTypeProfilesRefs)
                        await $_getPrefetchedData<
                          ProfileRow,
                          $ProfilesTable,
                          MediaTypeProfileRow
                        >(
                          currentTable: table,
                          referencedTable: $$ProfilesTableReferences
                              ._mediaTypeProfilesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).mediaTypeProfilesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (bookProfilesRefs)
                        await $_getPrefetchedData<
                          ProfileRow,
                          $ProfilesTable,
                          BookProfileRow
                        >(
                          currentTable: table,
                          referencedTable: $$ProfilesTableReferences
                              ._bookProfilesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).bookProfilesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (languageProfilesRefs)
                        await $_getPrefetchedData<
                          ProfileRow,
                          $ProfilesTable,
                          LanguageProfileRow
                        >(
                          currentTable: table,
                          referencedTable: $$ProfilesTableReferences
                              ._languageProfilesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).languageProfilesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.id,
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

typedef $$ProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$FushiDatabase,
      $ProfilesTable,
      ProfileRow,
      $$ProfilesTableFilterComposer,
      $$ProfilesTableOrderingComposer,
      $$ProfilesTableAnnotationComposer,
      $$ProfilesTableCreateCompanionBuilder,
      $$ProfilesTableUpdateCompanionBuilder,
      (ProfileRow, $$ProfilesTableReferences),
      ProfileRow,
      PrefetchHooks Function({
        bool profileSettingsRefs,
        bool mediaTypeProfilesRefs,
        bool bookProfilesRefs,
        bool languageProfilesRefs,
      })
    >;
typedef $$ProfileSettingsTableCreateCompanionBuilder =
    ProfileSettingsCompanion Function({
      Value<int> id,
      required int profileId,
      required String category,
      required String key,
      required String value,
    });
typedef $$ProfileSettingsTableUpdateCompanionBuilder =
    ProfileSettingsCompanion Function({
      Value<int> id,
      Value<int> profileId,
      Value<String> category,
      Value<String> key,
      Value<String> value,
    });

final class $$ProfileSettingsTableReferences
    extends
        BaseReferences<
          _$FushiDatabase,
          $ProfileSettingsTable,
          ProfileSettingRow
        > {
  $$ProfileSettingsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProfilesTable _profileIdTable(_$FushiDatabase db) =>
      db.profiles.createAlias('profile_settings__profile_id__profiles__id');

  $$ProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<int>('profile_id')!;

    final manager = $$ProfilesTableTableManager(
      $_db,
      $_db.profiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ProfileSettingsTableFilterComposer
    extends Composer<_$FushiDatabase, $ProfileSettingsTable> {
  $$ProfileSettingsTableFilterComposer({
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

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableFilterComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProfileSettingsTableOrderingComposer
    extends Composer<_$FushiDatabase, $ProfileSettingsTable> {
  $$ProfileSettingsTableOrderingComposer({
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

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProfileSettingsTableAnnotationComposer
    extends Composer<_$FushiDatabase, $ProfileSettingsTable> {
  $$ProfileSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProfileSettingsTableTableManager
    extends
        RootTableManager<
          _$FushiDatabase,
          $ProfileSettingsTable,
          ProfileSettingRow,
          $$ProfileSettingsTableFilterComposer,
          $$ProfileSettingsTableOrderingComposer,
          $$ProfileSettingsTableAnnotationComposer,
          $$ProfileSettingsTableCreateCompanionBuilder,
          $$ProfileSettingsTableUpdateCompanionBuilder,
          (ProfileSettingRow, $$ProfileSettingsTableReferences),
          ProfileSettingRow,
          PrefetchHooks Function({bool profileId})
        > {
  $$ProfileSettingsTableTableManager(
    _$FushiDatabase db,
    $ProfileSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfileSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfileSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfileSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
              }) => ProfileSettingsCompanion(
                id: id,
                profileId: profileId,
                category: category,
                key: key,
                value: value,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int profileId,
                required String category,
                required String key,
                required String value,
              }) => ProfileSettingsCompanion.insert(
                id: id,
                profileId: profileId,
                category: category,
                key: key,
                value: value,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProfileSettingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
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
                    if (profileId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.profileId,
                                referencedTable:
                                    $$ProfileSettingsTableReferences
                                        ._profileIdTable(db),
                                referencedColumn:
                                    $$ProfileSettingsTableReferences
                                        ._profileIdTable(db)
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

typedef $$ProfileSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$FushiDatabase,
      $ProfileSettingsTable,
      ProfileSettingRow,
      $$ProfileSettingsTableFilterComposer,
      $$ProfileSettingsTableOrderingComposer,
      $$ProfileSettingsTableAnnotationComposer,
      $$ProfileSettingsTableCreateCompanionBuilder,
      $$ProfileSettingsTableUpdateCompanionBuilder,
      (ProfileSettingRow, $$ProfileSettingsTableReferences),
      ProfileSettingRow,
      PrefetchHooks Function({bool profileId})
    >;
typedef $$MediaTypeProfilesTableCreateCompanionBuilder =
    MediaTypeProfilesCompanion Function({
      required String mediaType,
      required int profileId,
      Value<int> rowid,
    });
typedef $$MediaTypeProfilesTableUpdateCompanionBuilder =
    MediaTypeProfilesCompanion Function({
      Value<String> mediaType,
      Value<int> profileId,
      Value<int> rowid,
    });

final class $$MediaTypeProfilesTableReferences
    extends
        BaseReferences<
          _$FushiDatabase,
          $MediaTypeProfilesTable,
          MediaTypeProfileRow
        > {
  $$MediaTypeProfilesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProfilesTable _profileIdTable(_$FushiDatabase db) =>
      db.profiles.createAlias('media_type_profiles__profile_id__profiles__id');

  $$ProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<int>('profile_id')!;

    final manager = $$ProfilesTableTableManager(
      $_db,
      $_db.profiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MediaTypeProfilesTableFilterComposer
    extends Composer<_$FushiDatabase, $MediaTypeProfilesTable> {
  $$MediaTypeProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnFilters(column),
  );

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableFilterComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MediaTypeProfilesTableOrderingComposer
    extends Composer<_$FushiDatabase, $MediaTypeProfilesTable> {
  $$MediaTypeProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MediaTypeProfilesTableAnnotationComposer
    extends Composer<_$FushiDatabase, $MediaTypeProfilesTable> {
  $$MediaTypeProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MediaTypeProfilesTableTableManager
    extends
        RootTableManager<
          _$FushiDatabase,
          $MediaTypeProfilesTable,
          MediaTypeProfileRow,
          $$MediaTypeProfilesTableFilterComposer,
          $$MediaTypeProfilesTableOrderingComposer,
          $$MediaTypeProfilesTableAnnotationComposer,
          $$MediaTypeProfilesTableCreateCompanionBuilder,
          $$MediaTypeProfilesTableUpdateCompanionBuilder,
          (MediaTypeProfileRow, $$MediaTypeProfilesTableReferences),
          MediaTypeProfileRow,
          PrefetchHooks Function({bool profileId})
        > {
  $$MediaTypeProfilesTableTableManager(
    _$FushiDatabase db,
    $MediaTypeProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaTypeProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaTypeProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaTypeProfilesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> mediaType = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaTypeProfilesCompanion(
                mediaType: mediaType,
                profileId: profileId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String mediaType,
                required int profileId,
                Value<int> rowid = const Value.absent(),
              }) => MediaTypeProfilesCompanion.insert(
                mediaType: mediaType,
                profileId: profileId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MediaTypeProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
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
                    if (profileId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.profileId,
                                referencedTable:
                                    $$MediaTypeProfilesTableReferences
                                        ._profileIdTable(db),
                                referencedColumn:
                                    $$MediaTypeProfilesTableReferences
                                        ._profileIdTable(db)
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

typedef $$MediaTypeProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$FushiDatabase,
      $MediaTypeProfilesTable,
      MediaTypeProfileRow,
      $$MediaTypeProfilesTableFilterComposer,
      $$MediaTypeProfilesTableOrderingComposer,
      $$MediaTypeProfilesTableAnnotationComposer,
      $$MediaTypeProfilesTableCreateCompanionBuilder,
      $$MediaTypeProfilesTableUpdateCompanionBuilder,
      (MediaTypeProfileRow, $$MediaTypeProfilesTableReferences),
      MediaTypeProfileRow,
      PrefetchHooks Function({bool profileId})
    >;
typedef $$BookProfilesTableCreateCompanionBuilder =
    BookProfilesCompanion Function({
      required String bookKey,
      required int profileId,
      Value<int> rowid,
    });
typedef $$BookProfilesTableUpdateCompanionBuilder =
    BookProfilesCompanion Function({
      Value<String> bookKey,
      Value<int> profileId,
      Value<int> rowid,
    });

final class $$BookProfilesTableReferences
    extends
        BaseReferences<_$FushiDatabase, $BookProfilesTable, BookProfileRow> {
  $$BookProfilesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProfilesTable _profileIdTable(_$FushiDatabase db) =>
      db.profiles.createAlias('book_profiles__profile_id__profiles__id');

  $$ProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<int>('profile_id')!;

    final manager = $$ProfilesTableTableManager(
      $_db,
      $_db.profiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BookProfilesTableFilterComposer
    extends Composer<_$FushiDatabase, $BookProfilesTable> {
  $$BookProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookKey => $composableBuilder(
    column: $table.bookKey,
    builder: (column) => ColumnFilters(column),
  );

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableFilterComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookProfilesTableOrderingComposer
    extends Composer<_$FushiDatabase, $BookProfilesTable> {
  $$BookProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookKey => $composableBuilder(
    column: $table.bookKey,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookProfilesTableAnnotationComposer
    extends Composer<_$FushiDatabase, $BookProfilesTable> {
  $$BookProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookKey =>
      $composableBuilder(column: $table.bookKey, builder: (column) => column);

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookProfilesTableTableManager
    extends
        RootTableManager<
          _$FushiDatabase,
          $BookProfilesTable,
          BookProfileRow,
          $$BookProfilesTableFilterComposer,
          $$BookProfilesTableOrderingComposer,
          $$BookProfilesTableAnnotationComposer,
          $$BookProfilesTableCreateCompanionBuilder,
          $$BookProfilesTableUpdateCompanionBuilder,
          (BookProfileRow, $$BookProfilesTableReferences),
          BookProfileRow,
          PrefetchHooks Function({bool profileId})
        > {
  $$BookProfilesTableTableManager(_$FushiDatabase db, $BookProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> bookKey = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookProfilesCompanion(
                bookKey: bookKey,
                profileId: profileId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookKey,
                required int profileId,
                Value<int> rowid = const Value.absent(),
              }) => BookProfilesCompanion.insert(
                bookKey: bookKey,
                profileId: profileId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BookProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
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
                    if (profileId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.profileId,
                                referencedTable: $$BookProfilesTableReferences
                                    ._profileIdTable(db),
                                referencedColumn: $$BookProfilesTableReferences
                                    ._profileIdTable(db)
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

typedef $$BookProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$FushiDatabase,
      $BookProfilesTable,
      BookProfileRow,
      $$BookProfilesTableFilterComposer,
      $$BookProfilesTableOrderingComposer,
      $$BookProfilesTableAnnotationComposer,
      $$BookProfilesTableCreateCompanionBuilder,
      $$BookProfilesTableUpdateCompanionBuilder,
      (BookProfileRow, $$BookProfilesTableReferences),
      BookProfileRow,
      PrefetchHooks Function({bool profileId})
    >;
typedef $$LanguageProfilesTableCreateCompanionBuilder =
    LanguageProfilesCompanion Function({
      required String languageTag,
      required int profileId,
      Value<int> rowid,
    });
typedef $$LanguageProfilesTableUpdateCompanionBuilder =
    LanguageProfilesCompanion Function({
      Value<String> languageTag,
      Value<int> profileId,
      Value<int> rowid,
    });

final class $$LanguageProfilesTableReferences
    extends
        BaseReferences<
          _$FushiDatabase,
          $LanguageProfilesTable,
          LanguageProfileRow
        > {
  $$LanguageProfilesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProfilesTable _profileIdTable(_$FushiDatabase db) =>
      db.profiles.createAlias('language_profiles__profile_id__profiles__id');

  $$ProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<int>('profile_id')!;

    final manager = $$ProfilesTableTableManager(
      $_db,
      $_db.profiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LanguageProfilesTableFilterComposer
    extends Composer<_$FushiDatabase, $LanguageProfilesTable> {
  $$LanguageProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get languageTag => $composableBuilder(
    column: $table.languageTag,
    builder: (column) => ColumnFilters(column),
  );

  $$ProfilesTableFilterComposer get profileId {
    final $$ProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableFilterComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LanguageProfilesTableOrderingComposer
    extends Composer<_$FushiDatabase, $LanguageProfilesTable> {
  $$LanguageProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get languageTag => $composableBuilder(
    column: $table.languageTag,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProfilesTableOrderingComposer get profileId {
    final $$ProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LanguageProfilesTableAnnotationComposer
    extends Composer<_$FushiDatabase, $LanguageProfilesTable> {
  $$LanguageProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get languageTag => $composableBuilder(
    column: $table.languageTag,
    builder: (column) => column,
  );

  $$ProfilesTableAnnotationComposer get profileId {
    final $$ProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.profiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.profiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LanguageProfilesTableTableManager
    extends
        RootTableManager<
          _$FushiDatabase,
          $LanguageProfilesTable,
          LanguageProfileRow,
          $$LanguageProfilesTableFilterComposer,
          $$LanguageProfilesTableOrderingComposer,
          $$LanguageProfilesTableAnnotationComposer,
          $$LanguageProfilesTableCreateCompanionBuilder,
          $$LanguageProfilesTableUpdateCompanionBuilder,
          (LanguageProfileRow, $$LanguageProfilesTableReferences),
          LanguageProfileRow,
          PrefetchHooks Function({bool profileId})
        > {
  $$LanguageProfilesTableTableManager(
    _$FushiDatabase db,
    $LanguageProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LanguageProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LanguageProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LanguageProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> languageTag = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LanguageProfilesCompanion(
                languageTag: languageTag,
                profileId: profileId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String languageTag,
                required int profileId,
                Value<int> rowid = const Value.absent(),
              }) => LanguageProfilesCompanion.insert(
                languageTag: languageTag,
                profileId: profileId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LanguageProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
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
                    if (profileId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.profileId,
                                referencedTable:
                                    $$LanguageProfilesTableReferences
                                        ._profileIdTable(db),
                                referencedColumn:
                                    $$LanguageProfilesTableReferences
                                        ._profileIdTable(db)
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

typedef $$LanguageProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$FushiDatabase,
      $LanguageProfilesTable,
      LanguageProfileRow,
      $$LanguageProfilesTableFilterComposer,
      $$LanguageProfilesTableOrderingComposer,
      $$LanguageProfilesTableAnnotationComposer,
      $$LanguageProfilesTableCreateCompanionBuilder,
      $$LanguageProfilesTableUpdateCompanionBuilder,
      (LanguageProfileRow, $$LanguageProfilesTableReferences),
      LanguageProfileRow,
      PrefetchHooks Function({bool profileId})
    >;
typedef $$SeriesTableCreateCompanionBuilder =
    SeriesCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> coverSource,
      Value<int> sortOrder,
      required int createdAt,
    });
typedef $$SeriesTableUpdateCompanionBuilder =
    SeriesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> coverSource,
      Value<int> sortOrder,
      Value<int> createdAt,
    });

final class $$SeriesTableReferences
    extends BaseReferences<_$FushiDatabase, $SeriesTable, SeriesRow> {
  $$SeriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ShelfEntriesTable, List<ShelfEntryRow>>
  _shelfEntriesRefsTable(_$FushiDatabase db) => MultiTypedResultKey.fromTable(
    db.shelfEntries,
    aliasName: 'series__id__shelf_entries__series_id',
  );

  $$ShelfEntriesTableProcessedTableManager get shelfEntriesRefs {
    final manager = $$ShelfEntriesTableTableManager(
      $_db,
      $_db.shelfEntries,
    ).filter((f) => f.seriesId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_shelfEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SeriesTableFilterComposer
    extends Composer<_$FushiDatabase, $SeriesTable> {
  $$SeriesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverSource => $composableBuilder(
    column: $table.coverSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> shelfEntriesRefs(
    Expression<bool> Function($$ShelfEntriesTableFilterComposer f) f,
  ) {
    final $$ShelfEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shelfEntries,
      getReferencedColumn: (t) => t.seriesId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShelfEntriesTableFilterComposer(
            $db: $db,
            $table: $db.shelfEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SeriesTableOrderingComposer
    extends Composer<_$FushiDatabase, $SeriesTable> {
  $$SeriesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverSource => $composableBuilder(
    column: $table.coverSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SeriesTableAnnotationComposer
    extends Composer<_$FushiDatabase, $SeriesTable> {
  $$SeriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get coverSource => $composableBuilder(
    column: $table.coverSource,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> shelfEntriesRefs<T extends Object>(
    Expression<T> Function($$ShelfEntriesTableAnnotationComposer a) f,
  ) {
    final $$ShelfEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shelfEntries,
      getReferencedColumn: (t) => t.seriesId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShelfEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.shelfEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SeriesTableTableManager
    extends
        RootTableManager<
          _$FushiDatabase,
          $SeriesTable,
          SeriesRow,
          $$SeriesTableFilterComposer,
          $$SeriesTableOrderingComposer,
          $$SeriesTableAnnotationComposer,
          $$SeriesTableCreateCompanionBuilder,
          $$SeriesTableUpdateCompanionBuilder,
          (SeriesRow, $$SeriesTableReferences),
          SeriesRow,
          PrefetchHooks Function({bool shelfEntriesRefs})
        > {
  $$SeriesTableTableManager(_$FushiDatabase db, $SeriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> coverSource = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => SeriesCompanion(
                id: id,
                name: name,
                coverSource: coverSource,
                sortOrder: sortOrder,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> coverSource = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required int createdAt,
              }) => SeriesCompanion.insert(
                id: id,
                name: name,
                coverSource: coverSource,
                sortOrder: sortOrder,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$SeriesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({shelfEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (shelfEntriesRefs) db.shelfEntries],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (shelfEntriesRefs)
                    await $_getPrefetchedData<
                      SeriesRow,
                      $SeriesTable,
                      ShelfEntryRow
                    >(
                      currentTable: table,
                      referencedTable: $$SeriesTableReferences
                          ._shelfEntriesRefsTable(db),
                      managerFromTypedResult: (p0) => $$SeriesTableReferences(
                        db,
                        table,
                        p0,
                      ).shelfEntriesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.seriesId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SeriesTableProcessedTableManager =
    ProcessedTableManager<
      _$FushiDatabase,
      $SeriesTable,
      SeriesRow,
      $$SeriesTableFilterComposer,
      $$SeriesTableOrderingComposer,
      $$SeriesTableAnnotationComposer,
      $$SeriesTableCreateCompanionBuilder,
      $$SeriesTableUpdateCompanionBuilder,
      (SeriesRow, $$SeriesTableReferences),
      SeriesRow,
      PrefetchHooks Function({bool shelfEntriesRefs})
    >;
typedef $$ShelfEntriesTableCreateCompanionBuilder =
    ShelfEntriesCompanion Function({
      required String mediaType,
      required String entryKey,
      Value<int> sortOrder,
      Value<int?> seriesId,
      Value<int> rowid,
    });
typedef $$ShelfEntriesTableUpdateCompanionBuilder =
    ShelfEntriesCompanion Function({
      Value<String> mediaType,
      Value<String> entryKey,
      Value<int> sortOrder,
      Value<int?> seriesId,
      Value<int> rowid,
    });

final class $$ShelfEntriesTableReferences
    extends BaseReferences<_$FushiDatabase, $ShelfEntriesTable, ShelfEntryRow> {
  $$ShelfEntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SeriesTable _seriesIdTable(_$FushiDatabase db) =>
      db.series.createAlias('shelf_entries__series_id__series__id');

  $$SeriesTableProcessedTableManager? get seriesId {
    final $_column = $_itemColumn<int>('series_id');
    if ($_column == null) return null;
    final manager = $$SeriesTableTableManager(
      $_db,
      $_db.series,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_seriesIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ShelfEntriesTableFilterComposer
    extends Composer<_$FushiDatabase, $ShelfEntriesTable> {
  $$ShelfEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entryKey => $composableBuilder(
    column: $table.entryKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$SeriesTableFilterComposer get seriesId {
    final $$SeriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.seriesId,
      referencedTable: $db.series,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableFilterComposer(
            $db: $db,
            $table: $db.series,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShelfEntriesTableOrderingComposer
    extends Composer<_$FushiDatabase, $ShelfEntriesTable> {
  $$ShelfEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryKey => $composableBuilder(
    column: $table.entryKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$SeriesTableOrderingComposer get seriesId {
    final $$SeriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.seriesId,
      referencedTable: $db.series,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableOrderingComposer(
            $db: $db,
            $table: $db.series,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShelfEntriesTableAnnotationComposer
    extends Composer<_$FushiDatabase, $ShelfEntriesTable> {
  $$ShelfEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<String> get entryKey =>
      $composableBuilder(column: $table.entryKey, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$SeriesTableAnnotationComposer get seriesId {
    final $$SeriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.seriesId,
      referencedTable: $db.series,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableAnnotationComposer(
            $db: $db,
            $table: $db.series,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShelfEntriesTableTableManager
    extends
        RootTableManager<
          _$FushiDatabase,
          $ShelfEntriesTable,
          ShelfEntryRow,
          $$ShelfEntriesTableFilterComposer,
          $$ShelfEntriesTableOrderingComposer,
          $$ShelfEntriesTableAnnotationComposer,
          $$ShelfEntriesTableCreateCompanionBuilder,
          $$ShelfEntriesTableUpdateCompanionBuilder,
          (ShelfEntryRow, $$ShelfEntriesTableReferences),
          ShelfEntryRow,
          PrefetchHooks Function({bool seriesId})
        > {
  $$ShelfEntriesTableTableManager(_$FushiDatabase db, $ShelfEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShelfEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShelfEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShelfEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> mediaType = const Value.absent(),
                Value<String> entryKey = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int?> seriesId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShelfEntriesCompanion(
                mediaType: mediaType,
                entryKey: entryKey,
                sortOrder: sortOrder,
                seriesId: seriesId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String mediaType,
                required String entryKey,
                Value<int> sortOrder = const Value.absent(),
                Value<int?> seriesId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShelfEntriesCompanion.insert(
                mediaType: mediaType,
                entryKey: entryKey,
                sortOrder: sortOrder,
                seriesId: seriesId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ShelfEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({seriesId = false}) {
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
                    if (seriesId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.seriesId,
                                referencedTable: $$ShelfEntriesTableReferences
                                    ._seriesIdTable(db),
                                referencedColumn: $$ShelfEntriesTableReferences
                                    ._seriesIdTable(db)
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

typedef $$ShelfEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$FushiDatabase,
      $ShelfEntriesTable,
      ShelfEntryRow,
      $$ShelfEntriesTableFilterComposer,
      $$ShelfEntriesTableOrderingComposer,
      $$ShelfEntriesTableAnnotationComposer,
      $$ShelfEntriesTableCreateCompanionBuilder,
      $$ShelfEntriesTableUpdateCompanionBuilder,
      (ShelfEntryRow, $$ShelfEntriesTableReferences),
      ShelfEntryRow,
      PrefetchHooks Function({bool seriesId})
    >;
typedef $$MediaCollectionsTableCreateCompanionBuilder =
    MediaCollectionsCompanion Function({
      Value<int> id,
      Value<String?> sourceFolderPath,
      required String name,
      Value<String> collectionType,
      Value<String?> coverSource,
      Value<String?> coverPath,
      Value<int> sortOrder,
      required int createdAt,
      Value<int> orderUpdatedAt,
    });
typedef $$MediaCollectionsTableUpdateCompanionBuilder =
    MediaCollectionsCompanion Function({
      Value<int> id,
      Value<String?> sourceFolderPath,
      Value<String> name,
      Value<String> collectionType,
      Value<String?> coverSource,
      Value<String?> coverPath,
      Value<int> sortOrder,
      Value<int> createdAt,
      Value<int> orderUpdatedAt,
    });

final class $$MediaCollectionsTableReferences
    extends
        BaseReferences<
          _$FushiDatabase,
          $MediaCollectionsTable,
          MediaCollectionRow
        > {
  $$MediaCollectionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $MediaCollectionItemsTable,
    List<MediaCollectionItemRow>
  >
  _mediaCollectionItemsRefsTable(_$FushiDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.mediaCollectionItems,
        aliasName:
            'media_collections__id__media_collection_items__collection_id',
      );

  $$MediaCollectionItemsTableProcessedTableManager
  get mediaCollectionItemsRefs {
    final manager = $$MediaCollectionItemsTableTableManager(
      $_db,
      $_db.mediaCollectionItems,
    ).filter((f) => f.collectionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _mediaCollectionItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MediaCollectionsTableFilterComposer
    extends Composer<_$FushiDatabase, $MediaCollectionsTable> {
  $$MediaCollectionsTableFilterComposer({
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

  ColumnFilters<String> get sourceFolderPath => $composableBuilder(
    column: $table.sourceFolderPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get collectionType => $composableBuilder(
    column: $table.collectionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverSource => $composableBuilder(
    column: $table.coverSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderUpdatedAt => $composableBuilder(
    column: $table.orderUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> mediaCollectionItemsRefs(
    Expression<bool> Function($$MediaCollectionItemsTableFilterComposer f) f,
  ) {
    final $$MediaCollectionItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mediaCollectionItems,
      getReferencedColumn: (t) => t.collectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaCollectionItemsTableFilterComposer(
            $db: $db,
            $table: $db.mediaCollectionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MediaCollectionsTableOrderingComposer
    extends Composer<_$FushiDatabase, $MediaCollectionsTable> {
  $$MediaCollectionsTableOrderingComposer({
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

  ColumnOrderings<String> get sourceFolderPath => $composableBuilder(
    column: $table.sourceFolderPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get collectionType => $composableBuilder(
    column: $table.collectionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverSource => $composableBuilder(
    column: $table.coverSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderUpdatedAt => $composableBuilder(
    column: $table.orderUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MediaCollectionsTableAnnotationComposer
    extends Composer<_$FushiDatabase, $MediaCollectionsTable> {
  $$MediaCollectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceFolderPath => $composableBuilder(
    column: $table.sourceFolderPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get collectionType => $composableBuilder(
    column: $table.collectionType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverSource => $composableBuilder(
    column: $table.coverSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get orderUpdatedAt => $composableBuilder(
    column: $table.orderUpdatedAt,
    builder: (column) => column,
  );

  Expression<T> mediaCollectionItemsRefs<T extends Object>(
    Expression<T> Function($$MediaCollectionItemsTableAnnotationComposer a) f,
  ) {
    final $$MediaCollectionItemsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.mediaCollectionItems,
          getReferencedColumn: (t) => t.collectionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MediaCollectionItemsTableAnnotationComposer(
                $db: $db,
                $table: $db.mediaCollectionItems,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$MediaCollectionsTableTableManager
    extends
        RootTableManager<
          _$FushiDatabase,
          $MediaCollectionsTable,
          MediaCollectionRow,
          $$MediaCollectionsTableFilterComposer,
          $$MediaCollectionsTableOrderingComposer,
          $$MediaCollectionsTableAnnotationComposer,
          $$MediaCollectionsTableCreateCompanionBuilder,
          $$MediaCollectionsTableUpdateCompanionBuilder,
          (MediaCollectionRow, $$MediaCollectionsTableReferences),
          MediaCollectionRow,
          PrefetchHooks Function({bool mediaCollectionItemsRefs})
        > {
  $$MediaCollectionsTableTableManager(
    _$FushiDatabase db,
    $MediaCollectionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaCollectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaCollectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaCollectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> sourceFolderPath = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> collectionType = const Value.absent(),
                Value<String?> coverSource = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> orderUpdatedAt = const Value.absent(),
              }) => MediaCollectionsCompanion(
                id: id,
                sourceFolderPath: sourceFolderPath,
                name: name,
                collectionType: collectionType,
                coverSource: coverSource,
                coverPath: coverPath,
                sortOrder: sortOrder,
                createdAt: createdAt,
                orderUpdatedAt: orderUpdatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> sourceFolderPath = const Value.absent(),
                required String name,
                Value<String> collectionType = const Value.absent(),
                Value<String?> coverSource = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required int createdAt,
                Value<int> orderUpdatedAt = const Value.absent(),
              }) => MediaCollectionsCompanion.insert(
                id: id,
                sourceFolderPath: sourceFolderPath,
                name: name,
                collectionType: collectionType,
                coverSource: coverSource,
                coverPath: coverPath,
                sortOrder: sortOrder,
                createdAt: createdAt,
                orderUpdatedAt: orderUpdatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MediaCollectionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mediaCollectionItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (mediaCollectionItemsRefs) db.mediaCollectionItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (mediaCollectionItemsRefs)
                    await $_getPrefetchedData<
                      MediaCollectionRow,
                      $MediaCollectionsTable,
                      MediaCollectionItemRow
                    >(
                      currentTable: table,
                      referencedTable: $$MediaCollectionsTableReferences
                          ._mediaCollectionItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$MediaCollectionsTableReferences(
                            db,
                            table,
                            p0,
                          ).mediaCollectionItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.collectionId == item.id,
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

typedef $$MediaCollectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$FushiDatabase,
      $MediaCollectionsTable,
      MediaCollectionRow,
      $$MediaCollectionsTableFilterComposer,
      $$MediaCollectionsTableOrderingComposer,
      $$MediaCollectionsTableAnnotationComposer,
      $$MediaCollectionsTableCreateCompanionBuilder,
      $$MediaCollectionsTableUpdateCompanionBuilder,
      (MediaCollectionRow, $$MediaCollectionsTableReferences),
      MediaCollectionRow,
      PrefetchHooks Function({bool mediaCollectionItemsRefs})
    >;
typedef $$MediaCollectionItemsTableCreateCompanionBuilder =
    MediaCollectionItemsCompanion Function({
      required int collectionId,
      required String mediaType,
      required String entryKey,
      Value<int> sortIndex,
      Value<int> rowid,
    });
typedef $$MediaCollectionItemsTableUpdateCompanionBuilder =
    MediaCollectionItemsCompanion Function({
      Value<int> collectionId,
      Value<String> mediaType,
      Value<String> entryKey,
      Value<int> sortIndex,
      Value<int> rowid,
    });

final class $$MediaCollectionItemsTableReferences
    extends
        BaseReferences<
          _$FushiDatabase,
          $MediaCollectionItemsTable,
          MediaCollectionItemRow
        > {
  $$MediaCollectionItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MediaCollectionsTable _collectionIdTable(_$FushiDatabase db) =>
      db.mediaCollections.createAlias(
        'media_collection_items__collection_id__media_collections__id',
      );

  $$MediaCollectionsTableProcessedTableManager get collectionId {
    final $_column = $_itemColumn<int>('collection_id')!;

    final manager = $$MediaCollectionsTableTableManager(
      $_db,
      $_db.mediaCollections,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_collectionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MediaCollectionItemsTableFilterComposer
    extends Composer<_$FushiDatabase, $MediaCollectionItemsTable> {
  $$MediaCollectionItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entryKey => $composableBuilder(
    column: $table.entryKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnFilters(column),
  );

  $$MediaCollectionsTableFilterComposer get collectionId {
    final $$MediaCollectionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.mediaCollections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaCollectionsTableFilterComposer(
            $db: $db,
            $table: $db.mediaCollections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MediaCollectionItemsTableOrderingComposer
    extends Composer<_$FushiDatabase, $MediaCollectionItemsTable> {
  $$MediaCollectionItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryKey => $composableBuilder(
    column: $table.entryKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnOrderings(column),
  );

  $$MediaCollectionsTableOrderingComposer get collectionId {
    final $$MediaCollectionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.mediaCollections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaCollectionsTableOrderingComposer(
            $db: $db,
            $table: $db.mediaCollections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MediaCollectionItemsTableAnnotationComposer
    extends Composer<_$FushiDatabase, $MediaCollectionItemsTable> {
  $$MediaCollectionItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<String> get entryKey =>
      $composableBuilder(column: $table.entryKey, builder: (column) => column);

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  $$MediaCollectionsTableAnnotationComposer get collectionId {
    final $$MediaCollectionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.mediaCollections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaCollectionsTableAnnotationComposer(
            $db: $db,
            $table: $db.mediaCollections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MediaCollectionItemsTableTableManager
    extends
        RootTableManager<
          _$FushiDatabase,
          $MediaCollectionItemsTable,
          MediaCollectionItemRow,
          $$MediaCollectionItemsTableFilterComposer,
          $$MediaCollectionItemsTableOrderingComposer,
          $$MediaCollectionItemsTableAnnotationComposer,
          $$MediaCollectionItemsTableCreateCompanionBuilder,
          $$MediaCollectionItemsTableUpdateCompanionBuilder,
          (MediaCollectionItemRow, $$MediaCollectionItemsTableReferences),
          MediaCollectionItemRow,
          PrefetchHooks Function({bool collectionId})
        > {
  $$MediaCollectionItemsTableTableManager(
    _$FushiDatabase db,
    $MediaCollectionItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaCollectionItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaCollectionItemsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MediaCollectionItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> collectionId = const Value.absent(),
                Value<String> mediaType = const Value.absent(),
                Value<String> entryKey = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaCollectionItemsCompanion(
                collectionId: collectionId,
                mediaType: mediaType,
                entryKey: entryKey,
                sortIndex: sortIndex,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int collectionId,
                required String mediaType,
                required String entryKey,
                Value<int> sortIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaCollectionItemsCompanion.insert(
                collectionId: collectionId,
                mediaType: mediaType,
                entryKey: entryKey,
                sortIndex: sortIndex,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MediaCollectionItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({collectionId = false}) {
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
                    if (collectionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.collectionId,
                                referencedTable:
                                    $$MediaCollectionItemsTableReferences
                                        ._collectionIdTable(db),
                                referencedColumn:
                                    $$MediaCollectionItemsTableReferences
                                        ._collectionIdTable(db)
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

typedef $$MediaCollectionItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$FushiDatabase,
      $MediaCollectionItemsTable,
      MediaCollectionItemRow,
      $$MediaCollectionItemsTableFilterComposer,
      $$MediaCollectionItemsTableOrderingComposer,
      $$MediaCollectionItemsTableAnnotationComposer,
      $$MediaCollectionItemsTableCreateCompanionBuilder,
      $$MediaCollectionItemsTableUpdateCompanionBuilder,
      (MediaCollectionItemRow, $$MediaCollectionItemsTableReferences),
      MediaCollectionItemRow,
      PrefetchHooks Function({bool collectionId})
    >;
typedef $$BookCustomCssTableCreateCompanionBuilder =
    BookCustomCssCompanion Function({
      required String bookUid,
      required String relativePath,
      Value<String> content,
      Value<bool> deleted,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$BookCustomCssTableUpdateCompanionBuilder =
    BookCustomCssCompanion Function({
      Value<String> bookUid,
      Value<String> relativePath,
      Value<String> content,
      Value<bool> deleted,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$BookCustomCssTableFilterComposer
    extends Composer<_$FushiDatabase, $BookCustomCssTable> {
  $$BookCustomCssTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookUid => $composableBuilder(
    column: $table.bookUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookCustomCssTableOrderingComposer
    extends Composer<_$FushiDatabase, $BookCustomCssTable> {
  $$BookCustomCssTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookUid => $composableBuilder(
    column: $table.bookUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookCustomCssTableAnnotationComposer
    extends Composer<_$FushiDatabase, $BookCustomCssTable> {
  $$BookCustomCssTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookUid =>
      $composableBuilder(column: $table.bookUid, builder: (column) => column);

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BookCustomCssTableTableManager
    extends
        RootTableManager<
          _$FushiDatabase,
          $BookCustomCssTable,
          BookCustomCssRow,
          $$BookCustomCssTableFilterComposer,
          $$BookCustomCssTableOrderingComposer,
          $$BookCustomCssTableAnnotationComposer,
          $$BookCustomCssTableCreateCompanionBuilder,
          $$BookCustomCssTableUpdateCompanionBuilder,
          (
            BookCustomCssRow,
            BaseReferences<
              _$FushiDatabase,
              $BookCustomCssTable,
              BookCustomCssRow
            >,
          ),
          BookCustomCssRow,
          PrefetchHooks Function()
        > {
  $$BookCustomCssTableTableManager(
    _$FushiDatabase db,
    $BookCustomCssTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookCustomCssTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookCustomCssTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookCustomCssTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> bookUid = const Value.absent(),
                Value<String> relativePath = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookCustomCssCompanion(
                bookUid: bookUid,
                relativePath: relativePath,
                content: content,
                deleted: deleted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookUid,
                required String relativePath,
                Value<String> content = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => BookCustomCssCompanion.insert(
                bookUid: bookUid,
                relativePath: relativePath,
                content: content,
                deleted: deleted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookCustomCssTableProcessedTableManager =
    ProcessedTableManager<
      _$FushiDatabase,
      $BookCustomCssTable,
      BookCustomCssRow,
      $$BookCustomCssTableFilterComposer,
      $$BookCustomCssTableOrderingComposer,
      $$BookCustomCssTableAnnotationComposer,
      $$BookCustomCssTableCreateCompanionBuilder,
      $$BookCustomCssTableUpdateCompanionBuilder,
      (
        BookCustomCssRow,
        BaseReferences<_$FushiDatabase, $BookCustomCssTable, BookCustomCssRow>,
      ),
      BookCustomCssRow,
      PrefetchHooks Function()
    >;
typedef $$RevealedImagesTableCreateCompanionBuilder =
    RevealedImagesCompanion Function({
      required String bookUid,
      required String imageKey,
      required int revealedAt,
      Value<int> rowid,
    });
typedef $$RevealedImagesTableUpdateCompanionBuilder =
    RevealedImagesCompanion Function({
      Value<String> bookUid,
      Value<String> imageKey,
      Value<int> revealedAt,
      Value<int> rowid,
    });

class $$RevealedImagesTableFilterComposer
    extends Composer<_$FushiDatabase, $RevealedImagesTable> {
  $$RevealedImagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookUid => $composableBuilder(
    column: $table.bookUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageKey => $composableBuilder(
    column: $table.imageKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revealedAt => $composableBuilder(
    column: $table.revealedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RevealedImagesTableOrderingComposer
    extends Composer<_$FushiDatabase, $RevealedImagesTable> {
  $$RevealedImagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookUid => $composableBuilder(
    column: $table.bookUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageKey => $composableBuilder(
    column: $table.imageKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revealedAt => $composableBuilder(
    column: $table.revealedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RevealedImagesTableAnnotationComposer
    extends Composer<_$FushiDatabase, $RevealedImagesTable> {
  $$RevealedImagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookUid =>
      $composableBuilder(column: $table.bookUid, builder: (column) => column);

  GeneratedColumn<String> get imageKey =>
      $composableBuilder(column: $table.imageKey, builder: (column) => column);

  GeneratedColumn<int> get revealedAt => $composableBuilder(
    column: $table.revealedAt,
    builder: (column) => column,
  );
}

class $$RevealedImagesTableTableManager
    extends
        RootTableManager<
          _$FushiDatabase,
          $RevealedImagesTable,
          RevealedImageRow,
          $$RevealedImagesTableFilterComposer,
          $$RevealedImagesTableOrderingComposer,
          $$RevealedImagesTableAnnotationComposer,
          $$RevealedImagesTableCreateCompanionBuilder,
          $$RevealedImagesTableUpdateCompanionBuilder,
          (
            RevealedImageRow,
            BaseReferences<
              _$FushiDatabase,
              $RevealedImagesTable,
              RevealedImageRow
            >,
          ),
          RevealedImageRow,
          PrefetchHooks Function()
        > {
  $$RevealedImagesTableTableManager(
    _$FushiDatabase db,
    $RevealedImagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RevealedImagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RevealedImagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RevealedImagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> bookUid = const Value.absent(),
                Value<String> imageKey = const Value.absent(),
                Value<int> revealedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RevealedImagesCompanion(
                bookUid: bookUid,
                imageKey: imageKey,
                revealedAt: revealedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookUid,
                required String imageKey,
                required int revealedAt,
                Value<int> rowid = const Value.absent(),
              }) => RevealedImagesCompanion.insert(
                bookUid: bookUid,
                imageKey: imageKey,
                revealedAt: revealedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RevealedImagesTableProcessedTableManager =
    ProcessedTableManager<
      _$FushiDatabase,
      $RevealedImagesTable,
      RevealedImageRow,
      $$RevealedImagesTableFilterComposer,
      $$RevealedImagesTableOrderingComposer,
      $$RevealedImagesTableAnnotationComposer,
      $$RevealedImagesTableCreateCompanionBuilder,
      $$RevealedImagesTableUpdateCompanionBuilder,
      (
        RevealedImageRow,
        BaseReferences<_$FushiDatabase, $RevealedImagesTable, RevealedImageRow>,
      ),
      RevealedImageRow,
      PrefetchHooks Function()
    >;
typedef $$ActivityEventsTableCreateCompanionBuilder =
    ActivityEventsCompanion Function({
      Value<int> id,
      required String eventType,
      required String mediaType,
      required String title,
      Value<String?> mediaKey,
      required String dateKey,
      required int timestampMs,
      Value<int?> durationMs,
      Value<int?> charsDelta,
    });
typedef $$ActivityEventsTableUpdateCompanionBuilder =
    ActivityEventsCompanion Function({
      Value<int> id,
      Value<String> eventType,
      Value<String> mediaType,
      Value<String> title,
      Value<String?> mediaKey,
      Value<String> dateKey,
      Value<int> timestampMs,
      Value<int?> durationMs,
      Value<int?> charsDelta,
    });

class $$ActivityEventsTableFilterComposer
    extends Composer<_$FushiDatabase, $ActivityEventsTable> {
  $$ActivityEventsTableFilterComposer({
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

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaKey => $composableBuilder(
    column: $table.mediaKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get charsDelta => $composableBuilder(
    column: $table.charsDelta,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ActivityEventsTableOrderingComposer
    extends Composer<_$FushiDatabase, $ActivityEventsTable> {
  $$ActivityEventsTableOrderingComposer({
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

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaKey => $composableBuilder(
    column: $table.mediaKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get charsDelta => $composableBuilder(
    column: $table.charsDelta,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActivityEventsTableAnnotationComposer
    extends Composer<_$FushiDatabase, $ActivityEventsTable> {
  $$ActivityEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get mediaKey =>
      $composableBuilder(column: $table.mediaKey, builder: (column) => column);

  GeneratedColumn<String> get dateKey =>
      $composableBuilder(column: $table.dateKey, builder: (column) => column);

  GeneratedColumn<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get charsDelta => $composableBuilder(
    column: $table.charsDelta,
    builder: (column) => column,
  );
}

class $$ActivityEventsTableTableManager
    extends
        RootTableManager<
          _$FushiDatabase,
          $ActivityEventsTable,
          ActivityEventRow,
          $$ActivityEventsTableFilterComposer,
          $$ActivityEventsTableOrderingComposer,
          $$ActivityEventsTableAnnotationComposer,
          $$ActivityEventsTableCreateCompanionBuilder,
          $$ActivityEventsTableUpdateCompanionBuilder,
          (
            ActivityEventRow,
            BaseReferences<
              _$FushiDatabase,
              $ActivityEventsTable,
              ActivityEventRow
            >,
          ),
          ActivityEventRow,
          PrefetchHooks Function()
        > {
  $$ActivityEventsTableTableManager(
    _$FushiDatabase db,
    $ActivityEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActivityEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActivityEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActivityEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> eventType = const Value.absent(),
                Value<String> mediaType = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> mediaKey = const Value.absent(),
                Value<String> dateKey = const Value.absent(),
                Value<int> timestampMs = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<int?> charsDelta = const Value.absent(),
              }) => ActivityEventsCompanion(
                id: id,
                eventType: eventType,
                mediaType: mediaType,
                title: title,
                mediaKey: mediaKey,
                dateKey: dateKey,
                timestampMs: timestampMs,
                durationMs: durationMs,
                charsDelta: charsDelta,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String eventType,
                required String mediaType,
                required String title,
                Value<String?> mediaKey = const Value.absent(),
                required String dateKey,
                required int timestampMs,
                Value<int?> durationMs = const Value.absent(),
                Value<int?> charsDelta = const Value.absent(),
              }) => ActivityEventsCompanion.insert(
                id: id,
                eventType: eventType,
                mediaType: mediaType,
                title: title,
                mediaKey: mediaKey,
                dateKey: dateKey,
                timestampMs: timestampMs,
                durationMs: durationMs,
                charsDelta: charsDelta,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActivityEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$FushiDatabase,
      $ActivityEventsTable,
      ActivityEventRow,
      $$ActivityEventsTableFilterComposer,
      $$ActivityEventsTableOrderingComposer,
      $$ActivityEventsTableAnnotationComposer,
      $$ActivityEventsTableCreateCompanionBuilder,
      $$ActivityEventsTableUpdateCompanionBuilder,
      (
        ActivityEventRow,
        BaseReferences<_$FushiDatabase, $ActivityEventsTable, ActivityEventRow>,
      ),
      ActivityEventRow,
      PrefetchHooks Function()
    >;
typedef $$StudySegmentTombstonesTableCreateCompanionBuilder =
    StudySegmentTombstonesCompanion Function({
      Value<int> profileId,
      required String mediaKind,
      required String mediaKey,
      required int deletedAt,
      Value<int> rowid,
    });
typedef $$StudySegmentTombstonesTableUpdateCompanionBuilder =
    StudySegmentTombstonesCompanion Function({
      Value<int> profileId,
      Value<String> mediaKind,
      Value<String> mediaKey,
      Value<int> deletedAt,
      Value<int> rowid,
    });

class $$StudySegmentTombstonesTableFilterComposer
    extends Composer<_$FushiDatabase, $StudySegmentTombstonesTable> {
  $$StudySegmentTombstonesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaKind => $composableBuilder(
    column: $table.mediaKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaKey => $composableBuilder(
    column: $table.mediaKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StudySegmentTombstonesTableOrderingComposer
    extends Composer<_$FushiDatabase, $StudySegmentTombstonesTable> {
  $$StudySegmentTombstonesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaKind => $composableBuilder(
    column: $table.mediaKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaKey => $composableBuilder(
    column: $table.mediaKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StudySegmentTombstonesTableAnnotationComposer
    extends Composer<_$FushiDatabase, $StudySegmentTombstonesTable> {
  $$StudySegmentTombstonesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get mediaKind =>
      $composableBuilder(column: $table.mediaKind, builder: (column) => column);

  GeneratedColumn<String> get mediaKey =>
      $composableBuilder(column: $table.mediaKey, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$StudySegmentTombstonesTableTableManager
    extends
        RootTableManager<
          _$FushiDatabase,
          $StudySegmentTombstonesTable,
          StudySegmentTombstoneRow,
          $$StudySegmentTombstonesTableFilterComposer,
          $$StudySegmentTombstonesTableOrderingComposer,
          $$StudySegmentTombstonesTableAnnotationComposer,
          $$StudySegmentTombstonesTableCreateCompanionBuilder,
          $$StudySegmentTombstonesTableUpdateCompanionBuilder,
          (
            StudySegmentTombstoneRow,
            BaseReferences<
              _$FushiDatabase,
              $StudySegmentTombstonesTable,
              StudySegmentTombstoneRow
            >,
          ),
          StudySegmentTombstoneRow,
          PrefetchHooks Function()
        > {
  $$StudySegmentTombstonesTableTableManager(
    _$FushiDatabase db,
    $StudySegmentTombstonesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StudySegmentTombstonesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$StudySegmentTombstonesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$StudySegmentTombstonesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> profileId = const Value.absent(),
                Value<String> mediaKind = const Value.absent(),
                Value<String> mediaKey = const Value.absent(),
                Value<int> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StudySegmentTombstonesCompanion(
                profileId: profileId,
                mediaKind: mediaKind,
                mediaKey: mediaKey,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<int> profileId = const Value.absent(),
                required String mediaKind,
                required String mediaKey,
                required int deletedAt,
                Value<int> rowid = const Value.absent(),
              }) => StudySegmentTombstonesCompanion.insert(
                profileId: profileId,
                mediaKind: mediaKind,
                mediaKey: mediaKey,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StudySegmentTombstonesTableProcessedTableManager =
    ProcessedTableManager<
      _$FushiDatabase,
      $StudySegmentTombstonesTable,
      StudySegmentTombstoneRow,
      $$StudySegmentTombstonesTableFilterComposer,
      $$StudySegmentTombstonesTableOrderingComposer,
      $$StudySegmentTombstonesTableAnnotationComposer,
      $$StudySegmentTombstonesTableCreateCompanionBuilder,
      $$StudySegmentTombstonesTableUpdateCompanionBuilder,
      (
        StudySegmentTombstoneRow,
        BaseReferences<
          _$FushiDatabase,
          $StudySegmentTombstonesTable,
          StudySegmentTombstoneRow
        >,
      ),
      StudySegmentTombstoneRow,
      PrefetchHooks Function()
    >;
typedef $$StudySegmentsTableCreateCompanionBuilder =
    StudySegmentsCompanion Function({
      required String uid,
      required String deviceId,
      required String mediaKind,
      required String mediaKey,
      Value<String> format,
      required String title,
      required int startAt,
      required int endAt,
      required String dateKey,
      required int hour,
      Value<int> durationMs,
      Value<int> chars,
      Value<int> pages,
      required int updatedAt,
      Value<int> profileId,
      Value<int> rowid,
    });
typedef $$StudySegmentsTableUpdateCompanionBuilder =
    StudySegmentsCompanion Function({
      Value<String> uid,
      Value<String> deviceId,
      Value<String> mediaKind,
      Value<String> mediaKey,
      Value<String> format,
      Value<String> title,
      Value<int> startAt,
      Value<int> endAt,
      Value<String> dateKey,
      Value<int> hour,
      Value<int> durationMs,
      Value<int> chars,
      Value<int> pages,
      Value<int> updatedAt,
      Value<int> profileId,
      Value<int> rowid,
    });

class $$StudySegmentsTableFilterComposer
    extends Composer<_$FushiDatabase, $StudySegmentsTable> {
  $$StudySegmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaKind => $composableBuilder(
    column: $table.mediaKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaKey => $composableBuilder(
    column: $table.mediaKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endAt => $composableBuilder(
    column: $table.endAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hour => $composableBuilder(
    column: $table.hour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chars => $composableBuilder(
    column: $table.chars,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pages => $composableBuilder(
    column: $table.pages,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StudySegmentsTableOrderingComposer
    extends Composer<_$FushiDatabase, $StudySegmentsTable> {
  $$StudySegmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaKind => $composableBuilder(
    column: $table.mediaKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaKey => $composableBuilder(
    column: $table.mediaKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endAt => $composableBuilder(
    column: $table.endAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hour => $composableBuilder(
    column: $table.hour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chars => $composableBuilder(
    column: $table.chars,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pages => $composableBuilder(
    column: $table.pages,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StudySegmentsTableAnnotationComposer
    extends Composer<_$FushiDatabase, $StudySegmentsTable> {
  $$StudySegmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get mediaKind =>
      $composableBuilder(column: $table.mediaKind, builder: (column) => column);

  GeneratedColumn<String> get mediaKey =>
      $composableBuilder(column: $table.mediaKey, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get startAt =>
      $composableBuilder(column: $table.startAt, builder: (column) => column);

  GeneratedColumn<int> get endAt =>
      $composableBuilder(column: $table.endAt, builder: (column) => column);

  GeneratedColumn<String> get dateKey =>
      $composableBuilder(column: $table.dateKey, builder: (column) => column);

  GeneratedColumn<int> get hour =>
      $composableBuilder(column: $table.hour, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get chars =>
      $composableBuilder(column: $table.chars, builder: (column) => column);

  GeneratedColumn<int> get pages =>
      $composableBuilder(column: $table.pages, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);
}

class $$StudySegmentsTableTableManager
    extends
        RootTableManager<
          _$FushiDatabase,
          $StudySegmentsTable,
          StudySegmentRow,
          $$StudySegmentsTableFilterComposer,
          $$StudySegmentsTableOrderingComposer,
          $$StudySegmentsTableAnnotationComposer,
          $$StudySegmentsTableCreateCompanionBuilder,
          $$StudySegmentsTableUpdateCompanionBuilder,
          (
            StudySegmentRow,
            BaseReferences<
              _$FushiDatabase,
              $StudySegmentsTable,
              StudySegmentRow
            >,
          ),
          StudySegmentRow,
          PrefetchHooks Function()
        > {
  $$StudySegmentsTableTableManager(
    _$FushiDatabase db,
    $StudySegmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StudySegmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StudySegmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StudySegmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uid = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> mediaKind = const Value.absent(),
                Value<String> mediaKey = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> startAt = const Value.absent(),
                Value<int> endAt = const Value.absent(),
                Value<String> dateKey = const Value.absent(),
                Value<int> hour = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> chars = const Value.absent(),
                Value<int> pages = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> profileId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StudySegmentsCompanion(
                uid: uid,
                deviceId: deviceId,
                mediaKind: mediaKind,
                mediaKey: mediaKey,
                format: format,
                title: title,
                startAt: startAt,
                endAt: endAt,
                dateKey: dateKey,
                hour: hour,
                durationMs: durationMs,
                chars: chars,
                pages: pages,
                updatedAt: updatedAt,
                profileId: profileId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uid,
                required String deviceId,
                required String mediaKind,
                required String mediaKey,
                Value<String> format = const Value.absent(),
                required String title,
                required int startAt,
                required int endAt,
                required String dateKey,
                required int hour,
                Value<int> durationMs = const Value.absent(),
                Value<int> chars = const Value.absent(),
                Value<int> pages = const Value.absent(),
                required int updatedAt,
                Value<int> profileId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StudySegmentsCompanion.insert(
                uid: uid,
                deviceId: deviceId,
                mediaKind: mediaKind,
                mediaKey: mediaKey,
                format: format,
                title: title,
                startAt: startAt,
                endAt: endAt,
                dateKey: dateKey,
                hour: hour,
                durationMs: durationMs,
                chars: chars,
                pages: pages,
                updatedAt: updatedAt,
                profileId: profileId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StudySegmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$FushiDatabase,
      $StudySegmentsTable,
      StudySegmentRow,
      $$StudySegmentsTableFilterComposer,
      $$StudySegmentsTableOrderingComposer,
      $$StudySegmentsTableAnnotationComposer,
      $$StudySegmentsTableCreateCompanionBuilder,
      $$StudySegmentsTableUpdateCompanionBuilder,
      (
        StudySegmentRow,
        BaseReferences<_$FushiDatabase, $StudySegmentsTable, StudySegmentRow>,
      ),
      StudySegmentRow,
      PrefetchHooks Function()
    >;

class $FushiDatabaseManager {
  final _$FushiDatabase _db;
  $FushiDatabaseManager(this._db);
  $$MediaOpenHistoryTableTableManager get mediaOpenHistory =>
      $$MediaOpenHistoryTableTableManager(_db, _db.mediaOpenHistory);
  $$ReaderPositionsTableTableManager get readerPositions =>
      $$ReaderPositionsTableTableManager(_db, _db.readerPositions);
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db, _db.bookmarks);
  $$ReadingStatisticsTableTableManager get readingStatistics =>
      $$ReadingStatisticsTableTableManager(_db, _db.readingStatistics);
  $$ReadingHourlyLogsTableTableManager get readingHourlyLogs =>
      $$ReadingHourlyLogsTableTableManager(_db, _db.readingHourlyLogs);
  $$PreferencesTableTableManager get preferences =>
      $$PreferencesTableTableManager(_db, _db.preferences);
  $$EpubBooksTableTableManager get epubBooks =>
      $$EpubBooksTableTableManager(_db, _db.epubBooks);
  $$BookTagsTableTableManager get bookTags =>
      $$BookTagsTableTableManager(_db, _db.bookTags);
  $$TagAssignmentsTableTableManager get tagAssignments =>
      $$TagAssignmentsTableTableManager(_db, _db.tagAssignments);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$ProfileSettingsTableTableManager get profileSettings =>
      $$ProfileSettingsTableTableManager(_db, _db.profileSettings);
  $$MediaTypeProfilesTableTableManager get mediaTypeProfiles =>
      $$MediaTypeProfilesTableTableManager(_db, _db.mediaTypeProfiles);
  $$BookProfilesTableTableManager get bookProfiles =>
      $$BookProfilesTableTableManager(_db, _db.bookProfiles);
  $$LanguageProfilesTableTableManager get languageProfiles =>
      $$LanguageProfilesTableTableManager(_db, _db.languageProfiles);
  $$SeriesTableTableManager get series =>
      $$SeriesTableTableManager(_db, _db.series);
  $$ShelfEntriesTableTableManager get shelfEntries =>
      $$ShelfEntriesTableTableManager(_db, _db.shelfEntries);
  $$MediaCollectionsTableTableManager get mediaCollections =>
      $$MediaCollectionsTableTableManager(_db, _db.mediaCollections);
  $$MediaCollectionItemsTableTableManager get mediaCollectionItems =>
      $$MediaCollectionItemsTableTableManager(_db, _db.mediaCollectionItems);
  $$BookCustomCssTableTableManager get bookCustomCss =>
      $$BookCustomCssTableTableManager(_db, _db.bookCustomCss);
  $$RevealedImagesTableTableManager get revealedImages =>
      $$RevealedImagesTableTableManager(_db, _db.revealedImages);
  $$ActivityEventsTableTableManager get activityEvents =>
      $$ActivityEventsTableTableManager(_db, _db.activityEvents);
  $$StudySegmentTombstonesTableTableManager get studySegmentTombstones =>
      $$StudySegmentTombstonesTableTableManager(
        _db,
        _db.studySegmentTombstones,
      );
  $$StudySegmentsTableTableManager get studySegments =>
      $$StudySegmentsTableTableManager(_db, _db.studySegments);
}
