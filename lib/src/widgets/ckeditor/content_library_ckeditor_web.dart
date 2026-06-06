import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

extension type _TpkCkEditorJs(JSObject _) implements JSObject {
  external JSPromise<JSAny?> create(JSString elementId, JSString initialHtml);
  external JSPromise<JSAny?> setData(JSString elementId, JSString html);
  external JSString getData(JSString elementId);
  external JSPromise<JSAny?> destroy(JSString elementId);
  external JSPromise<JSAny?> focus(JSString elementId);
}

@JS('tpkCkEditor')
external _TpkCkEditorJs get _tpkCkEditor;

@JS('tpkCkEditorDartOnChange')
external set _tpkCkEditorDartOnChange(JSFunction? callback);

final class ContentLibraryCkEditorPlatform {
  static bool _factoryRegistered = false;
  static final Map<String, void Function(String)> _changeHandlers = {};

  static void registerChangeHandler(
    String elementId,
    void Function(String html) handler,
  ) {
    _changeHandlers[elementId] = handler;
  }

  static void unregisterChangeHandler(String elementId) {
    _changeHandlers.remove(elementId);
  }

  static void _ensureFactory() {
    if (_factoryRegistered) return;
    _factoryRegistered = true;

    _tpkCkEditorDartOnChange = (JSString elementId, JSString html) {
      final id = elementId.toDart;
      _changeHandlers[id]?.call(html.toDart);
    }.toJS;

    ui_web.platformViewRegistry.registerViewFactory(
      'tpk-ckeditor',
      (int viewId) {
        final elementId = 'tpk-ck-$viewId';
        return web.HTMLDivElement()
          ..id = elementId
          ..className = 'tpk-ckeditor-host'
          ..style.pointerEvents = 'auto'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.minHeight = '280px'
          ..style.boxSizing = 'border-box'
          ..style.position = 'relative'
          ..style.zIndex = '2';
      },
    );
  }

  static Future<void> create(String elementId, String initialHtml) async {
    _ensureFactory();
    await _tpkCkEditor.create(elementId.toJS, initialHtml.toJS).toDart;
  }

  static Future<void> setData(String elementId, String html) async {
    await _tpkCkEditor.setData(elementId.toJS, html.toJS).toDart;
  }

  static Future<void> destroy(String elementId) async {
    unregisterChangeHandler(elementId);
    await _tpkCkEditor.destroy(elementId.toJS).toDart;
  }

  static Future<void> focus(String elementId) async {
    await _tpkCkEditor.focus(elementId.toJS).toDart;
  }
}

/// CKEditor 5 WYSIWYG (edit in place, rich toolbar).
class ContentLibraryCkEditorView extends StatefulWidget {
  const ContentLibraryCkEditorView({
    super.key,
    required this.controller,
    this.minHeight = 320,
  });

  final TextEditingController controller;
  final double minHeight;

  @override
  State<ContentLibraryCkEditorView> createState() =>
      _ContentLibraryCkEditorViewState();
}

class _ContentLibraryCkEditorViewState extends State<ContentLibraryCkEditorView> {
  String? _elementId;
  bool _creating = false;
  String? _createError;
  int _viewId = -1;

  @override
  void dispose() {
    final id = _elementId;
    if (id != null) {
      ContentLibraryCkEditorPlatform.destroy(id);
    }
    super.dispose();
  }

  Future<void> _initEditor(int viewId) async {
    final id = 'tpk-ck-$viewId';
    _viewId = viewId;
    if (_creating) return;
    setState(() {
      _creating = true;
      _createError = null;
      _elementId = id;
    });
    ContentLibraryCkEditorPlatform.registerChangeHandler(id, _onEditorChanged);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted || _viewId != viewId) return;
      await ContentLibraryCkEditorPlatform.create(id, widget.controller.text);
      if (!mounted || _viewId != viewId) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await ContentLibraryCkEditorPlatform.focus(id);
      if (!mounted) return;
      setState(() {
        _creating = false;
        _createError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _createError = '$e';
      });
    }
  }

  void _onEditorChanged(String html) {
    if (widget.controller.text == html) return;
    widget.controller.text = html;
  }

  @override
  Widget build(BuildContext context) {
    ContentLibraryCkEditorPlatform._ensureFactory();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Text(
            'CKEditor — headings, fonts, alignment, tables, images, and Source (HTML). '
            'Publish to update the mobile app.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF616161),
                ),
          ),
        ),
        if (_createError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _createError!,
              style: const TextStyle(color: Color(0xFFC62828), fontSize: 12),
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: HtmlElementView(
                      viewType: 'tpk-ckeditor',
                      onPlatformViewCreated: _initEditor,
                    ),
                  ),
                  if (_creating)
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
