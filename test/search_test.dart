import 'package:flutter_test/flutter_test.dart';
import 'package:launcher/apps.dart';

AppEntry app(String label) =>
    AppEntry(label: label, package: 'p.$label', activity: 'A');

void main() {
  final apps = [
    app('Calculator'),
    app('Calendar'),
    app('Google Maps'),
    app('Messages'),
    app('Play Store'),
  ];
  String label(AppEntry a) => a.label;

  test('empty query returns everything', () {
    expect(searchApps(apps, '  ', label), apps);
  });

  test('prefix matches rank before word and substring matches', () {
    final names = searchApps(apps, 'ma', label).map((a) => a.label);
    expect(names, ['Google Maps']);
    expect(searchApps(apps, 's', label).map((a) => a.label), [
      'Play Store',
      'Google Maps',
      'Messages',
    ]);
  });

  test('search is case-insensitive and uses the given label', () {
    expect(searchApps(apps, 'CALC', label).single.label, 'Calculator');
    expect(
      searchApps(
        apps,
        'money',
        (a) => a.label == 'Calculator' ? 'Money' : a.label,
      ).single.label,
      'Calculator',
    );
  });

  test('keys include the user profile', () {
    const a = AppEntry(label: 'X', package: 'x', activity: 'X', user: 10);
    expect(a.key, 'x/X@10');
  });
}
