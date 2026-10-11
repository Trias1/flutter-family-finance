import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';

/// "Hide amounts" (the eye on the balance card), like a bank app: balances on
/// Home and Goals show as dots so people nearby can't read them. Kept on the
/// phone; screens opened on purpose (details, history) still show numbers.
final hideAmountsProvider = StateNotifierProvider<HideAmountsNotifier, bool>(
  (ref) => HideAmountsNotifier(),
);

class HideAmountsNotifier extends StateNotifier<bool> {
  static const _key = 'hide_amounts';

  HideAmountsNotifier() : super(false) {
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) state = prefs.getBool(_key) ?? false;
    });
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
  }
}

/// The dots that stand in for a hidden number.
const hiddenDigits = '••••••';

/// [amount] as money, or dots when amounts are hidden.
String moneyText(bool hidden, double amount) => hidden
    ? '${CurrencyFormatter.currentCurrency.symbol} $hiddenDigits'
    : CurrencyFormatter.format(amount);

/// [amount] without the symbol, or dots when amounts are hidden.
String numberText(bool hidden, double amount) =>
    hidden ? hiddenDigits : CurrencyFormatter.formatWithoutSymbol(amount);

/// The eye that shows or hides amounts.
class HideAmountsButton extends ConsumerWidget {
  final Color? color;
  final double size;
  const HideAmountsButton({super.key, this.color, this.size = 20});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(hideAmountsProvider);
    final isId = Localizations.localeOf(context).languageCode == 'id';
    return IconButton(
      visualDensity: VisualDensity.compact,
      iconSize: size,
      color: color,
      tooltip: hidden
          ? (isId ? 'Tampilkan nominal' : 'Show amounts')
          : (isId ? 'Sembunyikan nominal' : 'Hide amounts'),
      icon: Icon(
        hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
      ),
      onPressed: () => ref.read(hideAmountsProvider.notifier).toggle(),
    );
  }
}
