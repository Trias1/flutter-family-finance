import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:family_finance_manager/core/services/receipt_parser.dart';
import 'package:family_finance_manager/core/services/statement_parser.dart';

/// One scan: read as a single receipt, and as a list of transactions. Two or
/// more list rows mean a statement screenshot (mutasi) to import in bulk.
class ScanResult {
  final ReceiptDraft draft;
  final List<StatementItem> items;

  const ScanResult({required this.draft, required this.items});

  bool get isStatement => items.length >= 2;
}

/// Reads a receipt or payment screenshot on the phone (Google ML Kit, no
/// upload, no cost) and turns it into a draft expense.
class ReceiptScanner {
  /// Returns null when the user cancels picking an image.
  static Future<ScanResult?> pickAndRead({
    required bool fromCamera,
    void Function()? onReading,
  }) async {
    final picked = await ImagePicker().pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      // Large enough for small receipt print, small enough to read quickly.
      maxWidth: 2000,
      maxHeight: 2000,
    );
    if (picked == null) return null;
    onReading?.call();
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(picked.path),
      );
      final text = rowsText(result.blocks.expand((b) => b.lines));
      return ScanResult(
        draft: ReceiptParser.parse(text),
        items: StatementParser.parse(text),
      );
    } finally {
      await recognizer.close();
    }
  }

  /// Rebuilds the screen's rows: OCR may return "IDR" (left) and "35,000"
  /// (right) as separate blocks, so lines are ordered top to bottom and the
  /// ones sharing a row are joined left to right.
  static String rowsText(Iterable<TextLine> lines) {
    final sorted = lines.toList()
      ..sort(
        (a, b) => a.boundingBox.center.dy.compareTo(b.boundingBox.center.dy),
      );
    final rows = <List<TextLine>>[];
    for (final line in sorted) {
      final row = rows.isEmpty ? null : rows.last;
      final ref = row?.first.boundingBox;
      if (row != null &&
          ref != null &&
          (line.boundingBox.center.dy - ref.center.dy).abs() <
              ref.height * 0.6) {
        row.add(line);
      } else {
        rows.add([line]);
      }
    }
    return rows
        .map((row) {
          row.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
          return row.map((l) => l.text).join(' ');
        })
        .join('\n');
  }
}
