import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Opens a file picker and returns UTF-8 text for `.csv` (admin web only).
Future<String?> pickCsvFileText() {
  final completer = Completer<String?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.csv,text/csv,text/plain'
    ..style.display = 'none';

  void finish(String? value) {
    input.remove();
    if (!completer.isCompleted) completer.complete(value);
  }

  input.addEventListener(
    'change',
    (web.Event _) {
      final file = input.files?.item(0);
      if (file == null) {
        finish(null);
        return;
      }
      final reader = web.FileReader();
      reader.addEventListener(
        'loadend',
        (web.Event _) {
          final result = reader.result;
          if (result != null && result.isA<JSString>()) {
            finish((result as JSString).toDart);
          } else {
            finish(result?.toString());
          }
        }.toJS,
      );
      reader.readAsText(file);
    }.toJS,
  );

  web.document.body?.append(input);
  input.click();
  return completer.future;
}
