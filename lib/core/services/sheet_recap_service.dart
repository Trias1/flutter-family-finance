import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:family_finance_manager/core/services/sheet_recap_builder.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

/// Where this user's recap lives. Kept on the phone only: the spreadsheet
/// is in the user's own Google Drive and the app reaches it with the user's
/// own Google sign-in, so no server (and nobody else) ever sees the data.
class SheetRecapConfig {
  final String spreadsheetId;
  final String email;
  final bool isId;
  final String? lastSync; // yyyy-mm-dd
  final String? lastMonth; // yyyy-mm

  const SheetRecapConfig({
    required this.spreadsheetId,
    required this.email,
    required this.isId,
    this.lastSync,
    this.lastMonth,
  });

  String get url => 'https://docs.google.com/spreadsheets/d/$spreadsheetId';

  SheetRecapConfig synced(String day, String month) => SheetRecapConfig(
    spreadsheetId: spreadsheetId,
    email: email,
    isId: isId,
    lastSync: day,
    lastMonth: month,
  );

  Map<String, dynamic> toJson() => {
    'id': spreadsheetId,
    'email': email,
    'isId': isId,
    'lastSync': lastSync,
    'lastMonth': lastMonth,
  };

  static SheetRecapConfig? fromJson(String? raw) {
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return SheetRecapConfig(
        spreadsheetId: m['id'] as String,
        email: m['email'] as String,
        isId: m['isId'] as bool? ?? true,
        lastSync: m['lastSync'] as String?,
        lastMonth: m['lastMonth'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

class SheetRecapException implements Exception {
  /// cancelled, reconnect, network, google
  final String code;
  const SheetRecapException(this.code);
}

final sheetRecapServiceProvider = Provider<SheetRecapService>(
  (ref) => SheetRecapService(ref),
);

final sheetRecapConfigProvider = FutureProvider<SheetRecapConfig?>((ref) {
  final uid = ref.watch(authNotifierProvider).valueOrNull?.id;
  if (uid == null) return null;
  return SheetRecapService.load(uid);
});

class SheetRecapService {
  SheetRecapService(this._ref);
  final Ref _ref;

  // drive.file only lets the app open files it created itself, so it can
  // never read anything else in the user's Drive.
  static const _scope = 'https://www.googleapis.com/auth/drive.file';
  static const _api = 'https://sheets.googleapis.com/v4/spreadsheets';
  static const _overviewId = 1;
  static const _overviewChartId = 11;
  // Room on the right of the tables for the charts.
  static const _columns = 14;

  final GoogleSignIn _google = GoogleSignIn(scopes: [_scope]);
  bool _running = false;

  static String _key(String uid) => 'sheet_recap_$uid';

  static Future<SheetRecapConfig?> load(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return SheetRecapConfig.fromJson(prefs.getString(_key(uid)));
  }

  static Future<void> _save(String uid, SheetRecapConfig? config) async {
    final prefs = await SharedPreferences.getInstance();
    if (config == null) {
      await prefs.remove(_key(uid));
    } else {
      await prefs.setString(_key(uid), jsonEncode(config.toJson()));
    }
  }

  String? get _uid => _ref.read(authNotifierProvider).valueOrNull?.id;

  /// Asks the user to pick a Google account, creates the spreadsheet in
  /// that account's Drive and fills last month and this month.
  Future<SheetRecapConfig> connect({required bool isId}) async {
    final uid = _uid;
    if (uid == null) throw const SheetRecapException('reconnect');
    // Always show the account picker, even if a Google account is already
    // signed in on this phone: the user decides whose Drive gets the file.
    try {
      await _google.signOut();
    } catch (_) {}
    final GoogleSignInAccount? account;
    try {
      account = await _google.signIn();
    } catch (_) {
      throw const SheetRecapException('google');
    }
    if (account == null) throw const SheetRecapException('cancelled');
    final headers = await _headers(account);

    final res = await _send(
      () => http.post(
        Uri.parse(_api),
        headers: headers,
        body: jsonEncode({
          'properties': {
            'title': isId
                ? 'Rekap Keuangan - Family Finance'
                : 'Finance Recap - Family Finance',
            'locale': isId ? 'id_ID' : 'en_US',
            'timeZone': 'Asia/Jakarta',
          },
          'sheets': [
            {
              'properties': {
                'sheetId': _overviewId,
                'title': isId ? 'Ringkasan' : 'Overview',
              },
            },
          ],
        }),
      ),
    );
    final config = SheetRecapConfig(
      spreadsheetId: jsonDecode(res.body)['spreadsheetId'] as String,
      email: account.email,
      isId: isId,
    );
    await _save(uid, config);
    final now = DateTime.now();
    await _sync(config, [DateTime(now.year, now.month - 1), _monthOf(now)],
        headers);
    _ref.invalidate(sheetRecapConfigProvider);
    return config;
  }

  /// Forgets the spreadsheet on this phone. The file stays in the user's
  /// Drive; nothing is deleted.
  Future<void> disconnect() async {
    final uid = _uid;
    if (uid == null) return;
    await _save(uid, null);
    try {
      await _google.signOut();
    } catch (_) {}
    _ref.invalidate(sheetRecapConfigProvider);
  }

  /// Rewrites this month (and last month) now.
  Future<void> syncNow() async {
    final uid = _uid;
    final config = uid == null ? null : await load(uid);
    if (config == null) throw const SheetRecapException('reconnect');
    final now = DateTime.now();
    await _sync(config, [
      DateTime(now.year, now.month - 1),
      _monthOf(now),
    ], await _silentHeaders(config));
    _ref.invalidate(sheetRecapConfigProvider);
  }

  /// Called when the app opens or comes back. At most once a day it
  /// refreshes this month; on the first run of a new month it also closes
  /// last month, so the recap and the new month's tab appear by themselves.
  Future<void> autoSync() async {
    if (_running) return;
    final uid = _uid;
    final config = uid == null ? null : await load(uid);
    if (config == null) return;
    final now = DateTime.now();
    if (config.lastSync == _day(now)) return;
    final months = <DateTime>[
      if (config.lastMonth != _monthKey(now) || now.day <= 3)
        DateTime(now.year, now.month - 1),
      _monthOf(now),
    ];
    try {
      await _sync(config, months, await _silentHeaders(config));
      _ref.invalidate(sheetRecapConfigProvider);
    } catch (_) {
      // Offline or the Google sign-in is gone; the next open tries again
      // and the Settings tile offers to reconnect.
    }
  }

  static DateTime _monthOf(DateTime d) => DateTime(d.year, d.month);
  static String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';
  static String _day(DateTime d) =>
      '${_monthKey(d)}-${d.day.toString().padLeft(2, '0')}';

  Future<Map<String, String>> _headers(GoogleSignInAccount account) async {
    final auth = await account.authHeaders;
    return {...auth, 'Content-Type': 'application/json'};
  }

  Future<Map<String, String>> _silentHeaders(SheetRecapConfig config) async {
    GoogleSignInAccount? account;
    try {
      account = await _google.signInSilently();
    } catch (_) {
      account = null;
    }
    // A different Google account on the phone must never receive the data.
    if (account == null ||
        account.email.toLowerCase() != config.email.toLowerCase()) {
      throw const SheetRecapException('reconnect');
    }
    return _headers(account);
  }

  Future<http.Response> _send(Future<http.Response> Function() call) async {
    final http.Response res;
    try {
      res = await call().timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const SheetRecapException('network');
    }
    if (res.statusCode == 401 || res.statusCode == 403 || res.statusCode == 404) {
      throw const SheetRecapException('reconnect');
    }
    if (res.statusCode >= 300) throw const SheetRecapException('google');
    return res;
  }

  Future<void> _sync(
    SheetRecapConfig config,
    List<DateTime> months,
    Map<String, String> headers,
  ) async {
    final uid = _uid;
    final scope = _ref.read(financeScopeIdProvider);
    if (uid == null || scope.isEmpty) return;
    _running = true;
    try {
      final data = _ref.read(firestoreDataSourceProvider);
      final incomes = [
        for (final i in await data.getIncomes(scope))
          RecapEntry(
            date: i.date,
            amount: i.amount,
            category: i.category,
            note: i.note,
          ),
      ];
      final expenses = [
        for (final e in await data.getExpenses(scope))
          RecapEntry(
            date: e.date,
            amount: e.amount,
            category: e.category,
            note: e.note,
          ),
      ];

      final sheet = jsonDecode(
        (await _send(
          () => http.get(
            Uri.parse(
              '$_api/${config.spreadsheetId}?fields=sheets(properties(sheetId,title),charts(chartId))',
            ),
            headers: headers,
          ),
        )).body,
      );
      final tabs = <String, int>{
        for (final s in (sheet['sheets'] as List? ?? const []))
          s['properties']['title'] as String: s['properties']['sheetId'] as int,
      };
      final charts = <int>{
        for (final s in (sheet['sheets'] as List? ?? const []))
          for (final c in (s['charts'] as List? ?? const []))
            c['chartId'] as int,
      };

      final requests = <Map<String, dynamic>>[];
      final now = DateTime.now();
      for (final month in months) {
        bool inMonth(DateTime d) =>
            d.year == month.year && d.month == month.month;
        final title = SheetRecapBuilder.monthTitle(month, config.isId);
        final rows = SheetRecapBuilder.month(
          month: month,
          expenses: expenses.where((e) => inMonth(e.date)).toList(),
          incomes: incomes.where((e) => inMonth(e.date)).toList(),
          isId: config.isId,
          updatedAt: now,
        );
        final existing = tabs[title];
        final sheetId = existing ?? month.year * 100 + month.month;
        if (existing == null) {
          requests.add({
            'addSheet': {
              'properties': {
                'sheetId': sheetId,
                'title': title,
                'index': 1,
                'gridProperties': {
                  'rowCount': rows.length + 20,
                  'columnCount': _columns,
                },
              },
            },
          });
          tabs[title] = sheetId;
        } else {
          requests.addAll(_clear(sheetId, rows.length + 20));
        }
        requests.add(_write(sheetId, rows));
        requests.addAll(_widths(sheetId, const [110, 320, 150, 280]));
        requests.addAll(
          _replaceChart(charts, _pieChart(sheetId, rows, config.isId)),
        );
      }
      requests.addAll(_overview(tabs, charts, config.isId));

      await _send(
        () => http.post(
          Uri.parse('$_api/${config.spreadsheetId}:batchUpdate'),
          headers: headers,
          body: jsonEncode({'requests': requests}),
        ),
      );
      await _save(uid, config.synced(_day(now), _monthKey(now)));
    } finally {
      _running = false;
    }
  }

  List<Map<String, dynamic>> _clear(int sheetId, int rowCount) => [
    {
      'updateSheetProperties': {
        'properties': {
          'sheetId': sheetId,
          'gridProperties': {'rowCount': rowCount, 'columnCount': _columns},
        },
        'fields': 'gridProperties.rowCount,gridProperties.columnCount',
      },
    },
    {
      'updateCells': {
        'range': {'sheetId': sheetId},
        'fields': 'userEnteredValue,userEnteredFormat',
      },
    },
  ];

  List<Map<String, dynamic>> _widths(int sheetId, List<int> widths) => [
    for (var i = 0; i < widths.length; i++)
      {
        'updateDimensionProperties': {
          'range': {
            'sheetId': sheetId,
            'dimension': 'COLUMNS',
            'startIndex': i,
            'endIndex': i + 1,
          },
          'properties': {'pixelSize': widths[i]},
          'fields': 'pixelSize',
        },
      },
  ];

  /// Deletes the chart with the same id first: charts are not cleared with
  /// the cells, and re-adding keeps exactly one per tab.
  List<Map<String, dynamic>> _replaceChart(
    Set<int> existing,
    Map<String, dynamic> chart,
  ) {
    final id = chart['addChart']['chart']['chartId'] as int;
    return [
      if (existing.contains(id))
        {
          'deleteEmbeddedObject': {'objectId': id},
        },
      chart,
    ];
  }

  static Map<String, dynamic> _range(
    int sheetId,
    int startRow,
    int endRow,
    int column,
  ) => {
    'sourceRange': {
      'sources': [
        {
          'sheetId': sheetId,
          'startRowIndex': startRow,
          'endRowIndex': endRow,
          'startColumnIndex': column,
          'endColumnIndex': column + 1,
        },
      ],
    },
  };

  static Map<String, dynamic> _position(int sheetId) => {
    'overlayPosition': {
      'anchorCell': {'sheetId': sheetId, 'rowIndex': 1, 'columnIndex': 5},
      'widthPixels': 560,
      'heightPixels': 360,
    },
  };

  /// Donut of the month's spending per group, read from the recap table.
  Map<String, dynamic> _pieChart(
    int sheetId,
    List<SheetRow> rows,
    bool isId,
  ) {
    final head = rows.indexWhere((r) => r.anchor == 'recap_head');
    final total = rows.indexWhere((r) => r.anchor == 'spend_total');
    return {
      'addChart': {
        'chart': {
          'chartId': sheetId * 10 + 1,
          'spec': {
            'title': isId ? 'Pengeluaran per kategori' : 'Spending by category',
            'pieChart': {
              'legendPosition': 'RIGHT_LEGEND',
              'pieHole': 0.45,
              'domain': _range(sheetId, head + 1, total, 1),
              'series': _range(sheetId, head + 1, total, 2),
            },
          },
          'position': _position(sheetId),
        },
      },
    };
  }

  Map<String, dynamic> _write(int sheetId, List<SheetRow> rows) => {
    'updateCells': {
      'start': {'sheetId': sheetId, 'rowIndex': 0, 'columnIndex': 0},
      'rows': [
        for (final row in rows)
          {
            'values': [for (final c in row.cells) _cell(c, rows)],
          },
      ],
      'fields': 'userEnteredValue,userEnteredFormat',
    },
  };

  static const _moneyFormat = {'type': 'NUMBER', 'pattern': '"Rp" #,##0'};

  Map<String, dynamic> _cell(SheetCell c, List<SheetRow> rows) {
    final value = c.formula != null
        ? {'formulaValue': SheetRecapBuilder.resolve(c.formula!, rows)}
        : c.number != null
        ? {'numberValue': c.number}
        : c.text != null && c.text!.isNotEmpty
        ? {'stringValue': c.text}
        : null;
    final format = <String, dynamic>{
      if (c.money) 'numberFormat': _moneyFormat,
      ..._style(c.style),
    };
    return {
      'userEnteredValue': ?value,
      if (format.isNotEmpty) 'userEnteredFormat': format,
    };
  }

  static Map<String, dynamic> _rgb(int hex) => {
    'red': ((hex >> 16) & 0xff) / 255,
    'green': ((hex >> 8) & 0xff) / 255,
    'blue': (hex & 0xff) / 255,
  };

  static Map<String, dynamic> _style(CellStyle style) => switch (style) {
    CellStyle.normal => const {},
    CellStyle.title => {
      'textFormat': {'bold': true, 'fontSize': 14},
    },
    CellStyle.subtitle => {
      'textFormat': {
        'italic': true,
        'fontSize': 9,
        'foregroundColor': _rgb(0x777777),
      },
    },
    CellStyle.blockTitle => {
      'textFormat': {'bold': true},
      'backgroundColor': _rgb(0xD9EAD3),
    },
    CellStyle.header => {
      'textFormat': {'bold': true},
      'backgroundColor': _rgb(0xF3F3F3),
    },
    CellStyle.total => {
      'textFormat': {'bold': true},
    },
    CellStyle.label => {
      'textFormat': {'bold': true},
    },
  };

  /// The overview tab: one row per month tab, pointing at the totals each
  /// month keeps in C3:C5.
  List<Map<String, dynamic>> _overview(
    Map<String, int> tabs,
    Set<int> charts,
    bool isId,
  ) {
    final overviewTitle = isId ? 'Ringkasan' : 'Overview';
    final overviewId = tabs[overviewTitle] ?? _overviewId;
    final months = <(DateTime, String)>[
      for (final t in tabs.keys)
        if (SheetRecapBuilder.parseMonthTitle(t) case final m?) (m, t),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    String q(String title) => "'${title.replaceAll("'", "''")}'";
    final rows = <SheetRow>[
      SheetRow([
        SheetCell.text(
          isId ? 'Ringkasan Bulanan' : 'Monthly Overview',
          style: CellStyle.title,
        ),
      ]),
      SheetRow.blank,
      SheetRow([
        SheetCell.text(isId ? 'Bulan' : 'Month', style: CellStyle.header),
        SheetCell.text(isId ? 'Pendapatan' : 'Income', style: CellStyle.header),
        SheetCell.text(
          isId ? 'Pengeluaran' : 'Spending',
          style: CellStyle.header,
        ),
        SheetCell.text(
          isId ? 'Sisa saldo' : 'Left over',
          style: CellStyle.header,
        ),
      ]),
      for (final (_, title) in months)
        SheetRow([
          SheetCell.text(title),
          SheetCell.formula('=${q(title)}!C3'),
          SheetCell.formula('=${q(title)}!C4'),
          SheetCell.formula('=${q(title)}!C5'),
        ]),
    ];
    return [
      if (!tabs.containsKey(overviewTitle))
        {
          'addSheet': {
            'properties': {
              'sheetId': overviewId,
              'title': overviewTitle,
              'index': 0,
            },
          },
        },
      if (tabs.containsKey(overviewTitle)) ..._clear(overviewId, rows.length + 20),
      _write(overviewId, rows),
      ..._widths(overviewId, const [160, 160, 160, 160]),
      if (months.isNotEmpty)
        ..._replaceChart(charts, {
          'addChart': {
            'chart': {
              'chartId': _overviewChartId,
              'spec': {
                'title': isId
                    ? 'Pendapatan vs pengeluaran'
                    : 'Income vs spending',
                'basicChart': {
                  'chartType': 'COLUMN',
                  'legendPosition': 'BOTTOM_LEGEND',
                  'headerCount': 1,
                  'domains': [
                    {'domain': _range(overviewId, 2, 3 + months.length, 0)},
                  ],
                  'series': [
                    {
                      'series': _range(overviewId, 2, 3 + months.length, 1),
                      'targetAxis': 'LEFT_AXIS',
                      'colorStyle': {'rgbColor': _rgb(0x2E7D32)},
                    },
                    {
                      'series': _range(overviewId, 2, 3 + months.length, 2),
                      'targetAxis': 'LEFT_AXIS',
                      'colorStyle': {'rgbColor': _rgb(0xC62828)},
                    },
                  ],
                },
              },
              'position': _position(overviewId),
            },
          },
        }),
    ];
  }
}
