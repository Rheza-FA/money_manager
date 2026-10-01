// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monthly_balance.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMonthlyBalanceCollection on Isar {
  IsarCollection<MonthlyBalance> get monthlyBalances => this.collection();
}

const MonthlyBalanceSchema = CollectionSchema(
  name: r'MonthlyBalance',
  id: 2857008909591354516,
  properties: {
    r'balance': PropertySchema(
      id: 0,
      name: r'balance',
      type: IsarType.double,
    ),
    r'monthYear': PropertySchema(
      id: 1,
      name: r'monthYear',
      type: IsarType.string,
    )
  },
  estimateSize: _monthlyBalanceEstimateSize,
  serialize: _monthlyBalanceSerialize,
  deserialize: _monthlyBalanceDeserialize,
  deserializeProp: _monthlyBalanceDeserializeProp,
  idName: r'id',
  indexes: {
    r'monthYear': IndexSchema(
      id: -8729709491572084802,
      name: r'monthYear',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'monthYear',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _monthlyBalanceGetId,
  getLinks: _monthlyBalanceGetLinks,
  attach: _monthlyBalanceAttach,
  version: '3.1.0+1',
);

int _monthlyBalanceEstimateSize(
  MonthlyBalance object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.monthYear.length * 3;
  return bytesCount;
}

void _monthlyBalanceSerialize(
  MonthlyBalance object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDouble(offsets[0], object.balance);
  writer.writeString(offsets[1], object.monthYear);
}

MonthlyBalance _monthlyBalanceDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = MonthlyBalance();
  object.balance = reader.readDouble(offsets[0]);
  object.id = id;
  object.monthYear = reader.readString(offsets[1]);
  return object;
}

P _monthlyBalanceDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDouble(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _monthlyBalanceGetId(MonthlyBalance object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _monthlyBalanceGetLinks(MonthlyBalance object) {
  return [];
}

void _monthlyBalanceAttach(
    IsarCollection<dynamic> col, Id id, MonthlyBalance object) {
  object.id = id;
}

extension MonthlyBalanceByIndex on IsarCollection<MonthlyBalance> {
  Future<MonthlyBalance?> getByMonthYear(String monthYear) {
    return getByIndex(r'monthYear', [monthYear]);
  }

  MonthlyBalance? getByMonthYearSync(String monthYear) {
    return getByIndexSync(r'monthYear', [monthYear]);
  }

  Future<bool> deleteByMonthYear(String monthYear) {
    return deleteByIndex(r'monthYear', [monthYear]);
  }

  bool deleteByMonthYearSync(String monthYear) {
    return deleteByIndexSync(r'monthYear', [monthYear]);
  }

  Future<List<MonthlyBalance?>> getAllByMonthYear(
      List<String> monthYearValues) {
    final values = monthYearValues.map((e) => [e]).toList();
    return getAllByIndex(r'monthYear', values);
  }

  List<MonthlyBalance?> getAllByMonthYearSync(List<String> monthYearValues) {
    final values = monthYearValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'monthYear', values);
  }

  Future<int> deleteAllByMonthYear(List<String> monthYearValues) {
    final values = monthYearValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'monthYear', values);
  }

  int deleteAllByMonthYearSync(List<String> monthYearValues) {
    final values = monthYearValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'monthYear', values);
  }

  Future<Id> putByMonthYear(MonthlyBalance object) {
    return putByIndex(r'monthYear', object);
  }

  Id putByMonthYearSync(MonthlyBalance object, {bool saveLinks = true}) {
    return putByIndexSync(r'monthYear', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByMonthYear(List<MonthlyBalance> objects) {
    return putAllByIndex(r'monthYear', objects);
  }

  List<Id> putAllByMonthYearSync(List<MonthlyBalance> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'monthYear', objects, saveLinks: saveLinks);
  }
}

extension MonthlyBalanceQueryWhereSort
    on QueryBuilder<MonthlyBalance, MonthlyBalance, QWhere> {
  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension MonthlyBalanceQueryWhere
    on QueryBuilder<MonthlyBalance, MonthlyBalance, QWhereClause> {
  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterWhereClause>
      monthYearEqualTo(String monthYear) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'monthYear',
        value: [monthYear],
      ));
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterWhereClause>
      monthYearNotEqualTo(String monthYear) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'monthYear',
              lower: [],
              upper: [monthYear],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'monthYear',
              lower: [monthYear],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'monthYear',
              lower: [monthYear],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'monthYear',
              lower: [],
              upper: [monthYear],
              includeUpper: false,
            ));
      }
    });
  }
}

extension MonthlyBalanceQueryFilter
    on QueryBuilder<MonthlyBalance, MonthlyBalance, QFilterCondition> {
  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterFilterCondition>
      balanceEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'balance',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterFilterCondition>
      balanceGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'balance',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterFilterCondition>
      balanceLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'balance',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterFilterCondition>
      balanceBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'balance',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterFilterCondition>
      monthYearEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'monthYear',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterFilterCondition>
      monthYearGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'monthYear',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterFilterCondition>
      monthYearLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'monthYear',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterFilterCondition>
      monthYearBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'monthYear',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterFilterCondition>
      monthYearStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'monthYear',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterFilterCondition>
      monthYearEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'monthYear',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterFilterCondition>
      monthYearContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'monthYear',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterFilterCondition>
      monthYearMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'monthYear',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterFilterCondition>
      monthYearIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'monthYear',
        value: '',
      ));
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterFilterCondition>
      monthYearIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'monthYear',
        value: '',
      ));
    });
  }
}

extension MonthlyBalanceQueryObject
    on QueryBuilder<MonthlyBalance, MonthlyBalance, QFilterCondition> {}

extension MonthlyBalanceQueryLinks
    on QueryBuilder<MonthlyBalance, MonthlyBalance, QFilterCondition> {}

extension MonthlyBalanceQuerySortBy
    on QueryBuilder<MonthlyBalance, MonthlyBalance, QSortBy> {
  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterSortBy> sortByBalance() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'balance', Sort.asc);
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterSortBy>
      sortByBalanceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'balance', Sort.desc);
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterSortBy> sortByMonthYear() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'monthYear', Sort.asc);
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterSortBy>
      sortByMonthYearDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'monthYear', Sort.desc);
    });
  }
}

extension MonthlyBalanceQuerySortThenBy
    on QueryBuilder<MonthlyBalance, MonthlyBalance, QSortThenBy> {
  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterSortBy> thenByBalance() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'balance', Sort.asc);
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterSortBy>
      thenByBalanceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'balance', Sort.desc);
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterSortBy> thenByMonthYear() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'monthYear', Sort.asc);
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QAfterSortBy>
      thenByMonthYearDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'monthYear', Sort.desc);
    });
  }
}

extension MonthlyBalanceQueryWhereDistinct
    on QueryBuilder<MonthlyBalance, MonthlyBalance, QDistinct> {
  QueryBuilder<MonthlyBalance, MonthlyBalance, QDistinct> distinctByBalance() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'balance');
    });
  }

  QueryBuilder<MonthlyBalance, MonthlyBalance, QDistinct> distinctByMonthYear(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'monthYear', caseSensitive: caseSensitive);
    });
  }
}

extension MonthlyBalanceQueryProperty
    on QueryBuilder<MonthlyBalance, MonthlyBalance, QQueryProperty> {
  QueryBuilder<MonthlyBalance, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<MonthlyBalance, double, QQueryOperations> balanceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'balance');
    });
  }

  QueryBuilder<MonthlyBalance, String, QQueryOperations> monthYearProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'monthYear');
    });
  }
}
