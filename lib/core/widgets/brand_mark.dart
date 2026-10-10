import 'package:flutter/material.dart';

/// The ledger-card mark used for the launcher icon and on the web: a cream
/// card with two navy lines and a brass tab. Drawn with widgets so it stays
/// sharp at any size.
class BrandMark extends StatelessWidget {
  final double size;

  const BrandMark({super.key, this.size = 64});

  static const _cream = Color(0xFFF4EFE6);
  static const _navy = Color(0xFF2B4C6F);
  static const _brass = Color(0xFFB98A47);

  @override
  Widget build(BuildContext context) {
    final unit = size / 42;
    Widget bar(double width, Color color) => Container(
      width: width * unit,
      height: 4.5 * unit,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2.25 * unit),
      ),
    );
    return Container(
      width: size,
      height: size * 38 / 42,
      padding: EdgeInsets.symmetric(horizontal: 8 * unit),
      decoration: BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.circular(7 * unit),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(26, _navy),
          SizedBox(height: 5.5 * unit),
          Row(
            children: [
              bar(16, _navy),
              SizedBox(width: 3 * unit),
              bar(7, _brass),
            ],
          ),
        ],
      ),
    );
  }
}
