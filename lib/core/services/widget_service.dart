import 'package:home_widget/home_widget.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';

class WidgetService {
  static const _widgetName = 'BalanceWidgetProvider';

  static Future<void> initialize() async {
    // no-op: background callback registered via @pragma annotation
  }

  @pragma('vm:entry-point')
  static Future<void> backgroundCallback(Uri? uri) async {
    if (uri != null) {
      // Handle tap actions from widget
    }
  }

  static Future<void> updateBalance(double balance) async {
    await HomeWidget.saveWidgetData<String>('balance', CurrencyFormatter.format(balance));
    await HomeWidget.updateWidget(name: _widgetName, iOSName: _widgetName);
  }
}
