# Changelog

## Not released

- Fix eager loading of scoped associations. (https://github.com/Beyond-Finance/active_force/pull/67)
- Adding `.blank?`, `.present?`, and `.any?` delegators to `ActiveQuery`. (https://github.com/Beyond-Finance/active_force/pull/68)
- Adding `update` and `update!` class methods on `SObject`. (https://github.com/Beyond-Finance/active_force/pull/66)

## 0.17.0

- Fix bug with has_many queries due to query method chaining mutating in-place (https://github.com/Beyond-Finance/active_force/pull/10)

## 0.16.0

- Fix `default` in models when default value is overridden by the same value, it is still sent to salesforce (https://github.com/Beyond-Finance/active_force/pull/61)
- Support to fetch multi-level associations during eager load (https://github.com/Beyond-Finance/active_force/pull/62)

## 0.15.1

- Revert new `pluck` implementation due to compatibility issues (https://github.com/Beyond-Finance/active_force/pull/60)

## 0.15.0

- Fix model defaults so data is persisted in Salesforce (https://github.com/Beyond-Finance/active_force/pull/55)
- Add `pluck` query method (https://github.com/Beyond-Finance/active_force/pull/51)
- Add `#order` method to active query that accepts arguments in several formats ( symbol, string that has raw soql) (https://github.com/Beyond-Finance/active_force/pull/58)

## 0.14.0

- Add `scoped_as` option to `has_one` association (https://github.com/Beyond-Finance/active_force/pull/50)
- Add `default` to model fields (https://github.com/Beyond-Finance/active_force/pull/49)
- Allow `nil` datetimes as `:datetime` fields (https://github.com/Beyond-Finance/active_force/pull/52)

## 0.13.2
- Add `#loaded?` method for ActiveQueries to allow the detection of records loaded in memory or pending to be loaded. (https://github.com/Beyond-Finance/active_force/pull/45)
- Use attributes' values_for_database (serialize) value instead of using the type casted value to allow more flexibility when creating your own ActiveModel type

## 0.13.1

- Fix constructor of `ActiveForce::RecordNotFound` (https://github.com/Beyond-Finance/active_force/pull/44)
- Add `.to_json` and `.as_json` to `SObject` to allow JSON serialization (https://github.com/Beyond-Finance/active_force/pull/37)
- Memoize the `ActiveForce::Mapping#mappings` Hash since it is based on the fields and those are generally only set when the class is loaded. Also use `Hash#key` which returns the key for a value rather than `Hash#invert` which creates a new Hash with key/value inverted. (https://github.com/Beyond-Finance/active_force/pull/41)

## 0.13.0

- Add `.find!` to `SObject` (https://github.com/Beyond-Finance/active_force/pull/39)

## 0.12.0

- Add `.describe` to `SObject` to allow convenient metadata fetching (https://github.com/Beyond-Finance/active_force/pull/36)

## 0.11.4

- Properly escape single quote (https://github.com/Beyond-Finance/active_force/pull/29)
- Fix `Time` value formatting in `.where` (https://github.com/Beyond-Finance/active_force/pull/28)

## 0.11.3

- Fix has_one assignment when receiver does not have id (https://github.com/Beyond-Finance/active_force/pull/23)

## 0.11.2

- Fix: prevent association methods from running queries when keys do not exist (https://github.com/Beyond-Finance/active_force/pull/20)

## 0.11.1

- Fix `datetime` fields of SObjects to use iso(8601) format when sending to SF (https://github.com/Beyond-Finance/active_force/pull/18)

## 0.11.0

- Added support for 'or' and 'not' clauses (https://github.com/Beyond-Finance/active_force/pull/13)
- Added support for the SUM aggregate function (https://github.com/Beyond-Finance/active_force/pull/14)
- Allow `model` to be passed as a string or a constant (https://github.com/Beyond-Finance/active_force/pull/16)

## 0.10.0

- Fix `#where` chaining on `ActiveQuery` (https://github.com/Beyond-Finance/active_force/pull/7)
- Add `#find_by!` which raises `ActiveForce::RecordNotFound` if nothing is found. (https://github.com/Beyond-Finance/active_force/pull/8)
- Fix `#includes` to find, build, and set the association. (https://github.com/Beyond-Finance/active_force/pull/12)

## 0.9.1

- Fix invalid error class (https://github.com/Beyond-Finance/active_force/pull/6)

## 0.9.0

- Add support for Rails 7 and update Restforce dependency to newer version. (https://github.com/Beyond-Finance/active_force/pull/3)
- Add `has_one` association. (https://github.com/Beyond-Finance/active_force/pull/3)
- Model generator enhancements (https://github.com/Beyond-Finance/active_force/pull/3):
  - automatically add types to fields
  - sort fields alphabetically
  - add `table_name` to class
  - add optional namespace parameter so generated models can be namespaced
- Add get/set via `[]` and `[]=` for `SObject` attributes. (https://github.com/Beyond-Finance/active_force/pull/3)

## 0.7.1

- Allow sfdc_client to be set. ([#92][])

## 0.7.0

- Rails4-style conditional has_many associations ([Dan Olson][])
- Add `#includes` query method to eager load has_many association. ([Dan Olson][])
- Add `#includes` query method to eager load belongs_to association. ([#65][])
- SObject#destroy method.

## 0.6.1

- Fix missing require of 'restforce'. Now clients don't need to add an initializer.

## 0.6.0

- Add select statement functionality. ([Pablo Oldani][], [#33][])
- Add callback functionality ([Pablo Oldani][], [#20][])
- Support bind parameters. ([Dan Olson][], [#29][])
- Fix when passing nil value in a :where condition. ([Armando Andini][])
- Model generator complete ([Armando Andini][], [#19][])

## 0.5.0

- Provide a default id field for all SObject subclassees ([Dan Olson][], [#30][])
- Fix Ruby 2.0 compatibility issue ([Dan Olson][], [Pablo Oldani][], [#28][])
- Normalize rspec syntax to remove deprecation warnings ([Dan Olson][], [#26][])
- Remove namespace when inferring default SObject.table_name ([Dan Olson][], [#24][])
- Add create! and save! methods. ([Pablo Oldani][], [#21][])
- Refactor update and create methods. ([Pablo Oldani][], [#21][])
- Add a generator. ([José Piccioni][], [#19][])
- ActiveQuery now provides :each, :map and :inspect. ([Armando Andini][])
- Add SObject.create class mehtod. ([Pablo Oldani][], [#10][])
- SObject.field default mapping value follows SFDC API naming convention.
  ([Dan Olson][], [#14][] [#15][])

## 0.4.2

- Use ActiveQuery instead of Query. ([Armando Andini][])
- Add instructions to use validations ([José Piccioni][])
- Lots of refactoring.

## 0.3.2

- Fixed gemspec.

## 0.3.1

- Create different classes for associations. ([#4][])
- Big refactor on has_many association. ([Armando Andini][])
- Add a lot of specs and refactors. ([Armando Andini][])
- Add a Finders module. ([Armando Andini][])
- Add fist and last method to SObject.

## 0.2.0

- Add belogns_to and has_many associations.
- Changed when the SOQL query is sent to the client.
- Add join method to query to use associtations.

## 0.1.0

- Add query builder object to chain conditions.
- Update update and create methods.
- Add Campaing standard table name.

## 0.0.6.alfa

- ActiveForce::SObject#table_name is auto populated using the class
  name. It adds "\_\_c" to all non standard types.

<!--- The following link definition list is generated by PimpMyChangelog --->

[#4]: https://github.com/ionia-corporation/active_force/issues/4
[#9]: https://github.com/ionia-corporation/active_force/issues/9
[#10]: https://github.com/ionia-corporation/active_force/issues/10
[#14]: https://github.com/ionia-corporation/active_force/issues/14
[#15]: https://github.com/ionia-corporation/active_force/issues/15
[#19]: https://github.com/ionia-corporation/active_force/issues/19
[#20]: https://github.com/ionia-corporation/active_force/issues/20
[#21]: https://github.com/ionia-corporation/active_force/issues/21
[#24]: https://github.com/ionia-corporation/active_force/issues/24
[#26]: https://github.com/ionia-corporation/active_force/issues/26
[#28]: https://github.com/ionia-corporation/active_force/issues/28
[#29]: https://github.com/ionia-corporation/active_force/issues/29
[#30]: https://github.com/ionia-corporation/active_force/issues/30
[#33]: https://github.com/ionia-corporation/active_force/issues/33
[#65]: https://github.com/ionia-corporation/active_force/issues/65
[#92]: https://github.com/ionia-corporation/active_force/issues/92
[pablo oldani]: https://github.com/olvap
[armando andini]: https://github.com/antico5
[josé piccioni]: https://github.com/lmhsjackson
[dan olson]: https://github.com/DanOlson
