import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web/web.dart' as web;

extension type _VisualMsg._(JSObject _) implements JSObject {
  external String? get type;
  external String? get id;
  external String? get html;
}

class _VisualHost {
  _VisualHost(this.frameId, this.iframe);

  final String frameId;
  final web.HTMLIFrameElement iframe;

  void Function(String html)? onChange;
  VoidCallback? onReady;
  String pendingHtml = '';

  bool sameWindow(JSAny? source) {
    final win = iframe.contentWindow;
    if (win == null || source == null) return false;
    return win == source;
  }

  void init(String html) {
    pendingHtml = html;
    _post({
      'type': 'tpk-visual-init',
      'id': frameId,
      'html': html,
    });
  }

  void setHtml(String html) {
    pendingHtml = html;
    _post({
      'type': 'tpk-visual-set-html',
      'id': frameId,
      'html': html,
    });
  }

  void requestFocus() {
    _post({'type': 'tpk-visual-focus', 'id': frameId});
  }

  void _post(Map<String, String> payload) {
    final win = iframe.contentWindow;
    if (win == null) return;
    final encoded = payload.jsify();
    if (encoded == null || !encoded.isA<JSObject>()) return;
    win.postMessage(encoded as JSObject, '*'.toJS);
  }
}

String _visualEditorPageUrl() {
  return Uri.base.resolve('content_library_visual_editor.html').toString();
}

/// Web visual editor — contenteditable iframe with formatting toolbar.
class ContentLibraryVisualEditor extends StatefulWidget {
  const ContentLibraryVisualEditor({
    super.key,
    required this.html,
    required this.onHtmlChanged,
    this.active = true,
  });

  final String html;
  final void Function(String html) onHtmlChanged;
  final bool active;

  @override
  State<ContentLibraryVisualEditor> createState() =>
      _ContentLibraryVisualEditorState();
}

class _ContentLibraryVisualEditorState extends State<ContentLibraryVisualEditor> {
  static int _nextId = 0;
  static bool _listenerReady = false;
  static final Map<String, _VisualHost> _hosts = {};

  late final String _frameId;
  late final String _viewType;
  late final _VisualHost _host;
  bool _ready = false;
  bool _creating = true;
  String? _loadError;
  String? _lastEmittedHtml;
  Timer? _loadTimeout;

  @override
  void initState() {
    super.initState();
    _frameId = 'tpk-visual-${_nextId++}';
    _viewType = 'tpk-visual-view-$_frameId';
    _ensureListener();

    final iframe = web.HTMLIFrameElement()
      ..src = _visualEditorPageUrl()
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.display = 'block'
      ..setAttribute(
        'sandbox',
        'allow-scripts allow-same-origin allow-forms allow-popups',
      )
      ..setAttribute('title', 'Visual content editor');

    _host = _VisualHost(_frameId, iframe)
      ..pendingHtml = widget.html
      ..onChange = _handleVisualChange
      ..onReady = _handleReady;

    _hosts[_frameId] = _host;

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int _) => iframe,
    );

    _loadTimeout = Timer(const Duration(seconds: 20), () {
      if (!mounted || _ready) return;
      setState(() {
        _creating = false;
        _loadError =
            'Visual editor did not load. Switch to the Edit HTML tab, or hard-refresh '
            '(Ctrl+Shift+R) after the latest admin deploy.';
      });
    });
  }

  static void _ensureListener() {
    if (_listenerReady) return;
    _listenerReady = true;

    void onMessage(web.Event event) {
      final ev = event as web.MessageEvent;
      final data = ev.data;
      if (data == null) return;
      if (!data.isA<JSObject>()) return;
      final msg = data as _VisualMsg;
      final type = msg.type;
      if (type == null || type.isEmpty) return;

      _VisualHost? host;
      final id = msg.id;
      if (id != null && id.isNotEmpty) {
        host = _hosts[id];
      }
      if (host == null) {
        for (final candidate in _hosts.values) {
          if (candidate.sameWindow(ev.source)) {
            host = candidate;
            break;
          }
        }
      }
      if (host == null) return;

      switch (type) {
        case 'tpk-visual-frame-loaded':
          host.init(host.pendingHtml);
        case 'tpk-visual-ready':
          host.onReady?.call();
        case 'tpk-visual-change':
          final html = msg.html;
          if (html != null) host.onChange?.call(html);
      }
    }

    web.window.addEventListener('message', onMessage.toJS);
  }

  void _handleVisualChange(String html) {
    _lastEmittedHtml = html;
    widget.onHtmlChanged(html);
  }

  void _handleReady() {
    if (!mounted) return;
    _loadTimeout?.cancel();
    setState(() {
      _ready = true;
      _creating = false;
      _loadError = null;
    });
  }

  @override
  void didUpdateWidget(ContentLibraryVisualEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _host.pendingHtml = widget.html;

    if (!_ready) return;

    final becameActive = widget.active && !oldWidget.active;
    final externalHtmlChange = oldWidget.html != widget.html &&
        widget.html != _lastEmittedHtml;

    if (becameActive || (externalHtmlChange && widget.active)) {
      _host.setHtml(widget.html);
    }
    if (becameActive) {
      _host.requestFocus();
    }
  }

  @override
  void dispose() {
    _loadTimeout?.cancel();
    _hosts.remove(_frameId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _host.pendingHtml = widget.html;

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _loadError!,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFFC62828),
              height: 1.45,
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        HtmlElementView(viewType: _viewType),
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
    );
  }
}
