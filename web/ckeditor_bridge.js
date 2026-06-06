// CKEditor 5 bridge for Flutter web (Content Library CMS).
(function () {
  const instances = {};
  let loadPromise = null;
  let editorMode = 'classic'; // 'classic' | 'super'

  const CKEDITOR_VERSION = '41.4.2';
  const CLASSIC_JS_URLS = [
    'https://cdn.ckeditor.com/ckeditor5/' +
      CKEDITOR_VERSION +
      '/classic/ckeditor.js',
    'https://cdn.jsdelivr.net/npm/@ckeditor/ckeditor5-build-classic@' +
      CKEDITOR_VERSION +
      '/build/ckeditor.js',
  ];
  const SUPERBUILD_URL =
    'https://cdn.ckeditor.com/ckeditor5/' +
    CKEDITOR_VERSION +
    '/super-build/ckeditor.js';

  function getEditorClass() {
    if (window.CKEDITOR && window.CKEDITOR.ClassicEditor) {
      return window.CKEDITOR.ClassicEditor;
    }
    if (window.ClassicEditor) {
      return window.ClassicEditor;
    }
    return null;
  }

  function loadScript(url) {
    return new Promise(function (resolve, reject) {
      const script = document.createElement('script');
      script.src = url;
      script.onload = function () {
        if (getEditorClass()) {
          resolve();
        } else {
          reject(new Error('ClassicEditor not defined after loading ' + url));
        }
      };
      script.onerror = function () {
        reject(new Error('Failed to load script: ' + url));
      };
      document.head.appendChild(script);
    });
  }

  function loadCkEditor() {
    if (getEditorClass()) return Promise.resolve();
    if (loadPromise) return loadPromise;
    loadPromise = (async function () {
      let lastError = null;
      for (let i = 0; i < CLASSIC_JS_URLS.length; i++) {
        try {
          await loadScript(CLASSIC_JS_URLS[i]);
          editorMode = 'classic';
          return;
        } catch (e) {
          lastError = e;
        }
      }
      try {
        await loadScript(SUPERBUILD_URL);
        editorMode = 'super';
        return;
      } catch (superError) {
        throw lastError || superError || new Error('Failed to load CKEditor 5');
      }
    })();
    return loadPromise;
  }

  const REMOVE_PLUGINS_SUPER = [
    'AIAssistant',
    'CKBox',
    'CKFinder',
    'EasyImage',
    'RealTimeCollaborativeComments',
    'RealTimeCollaborativeTrackChanges',
    'RealTimeCollaborativeRevisionHistory',
    'PresenceList',
    'Comments',
    'TrackChanges',
    'TrackChangesData',
    'RevisionHistory',
    'Pagination',
    'WProofreader',
    'MathType',
    'SlashCommand',
    'Template',
    'DocumentOutline',
    'FormatPainter',
    'TableOfContents',
    'PasteFromOfficeEnhanced',
    'CaseChange',
    'ExportPdf',
    'ExportWord',
    'RestrictedEditing',
  ];

  function editorConfig(initialHtml) {
    const headingOptions = [
      {
        model: 'paragraph',
        title: 'Paragraph',
        class: 'ck-heading_paragraph',
      },
      {
        model: 'heading2',
        view: 'h2',
        title: 'Heading 2',
        class: 'ck-heading_heading2',
      },
      {
        model: 'heading3',
        view: 'h3',
        title: 'Heading 3',
        class: 'ck-heading_heading3',
      },
      {
        model: 'heading4',
        view: 'h4',
        title: 'Heading 4',
        class: 'ck-heading_heading4',
      },
    ];

    const shared = {
      initialData: initialHtml || '',
      placeholder: 'Write or paste curriculum content…',
      heading: { options: headingOptions },
      link: {
        addTargetToExternalLinks: true,
        defaultProtocol: 'https://',
      },
      table: {
        contentToolbar: [
          'tableColumn',
          'tableRow',
          'mergeTableCells',
        ],
      },
    };

    if (editorMode === 'super') {
      return Object.assign({}, shared, {
        removePlugins: REMOVE_PLUGINS_SUPER,
        toolbar: {
          shouldNotGroupWhenFull: true,
          items: [
            'heading',
            '|',
            'bold',
            'italic',
            'underline',
            'strikethrough',
            '|',
            'fontSize',
            'fontFamily',
            'fontColor',
            'fontBackgroundColor',
            '|',
            'alignment',
            '|',
            'bulletedList',
            'numberedList',
            '|',
            'outdent',
            'indent',
            '|',
            'link',
            'uploadImage',
            'insertTable',
            'blockQuote',
            'mediaEmbed',
            'horizontalLine',
            '|',
            'undo',
            'redo',
            '|',
            'sourceEditing',
          ],
        },
        fontFamily: {
          options: [
            'default',
            'Arial, Helvetica, sans-serif',
            'Georgia, serif',
            'Times New Roman, Times, serif',
            'Verdana, Geneva, sans-serif',
          ],
          supportAllValues: true,
        },
        fontSize: {
          options: [10, 12, 14, 'default', 18, 20, 24],
          supportAllValues: true,
        },
        htmlSupport: {
          allow: [
            {
              name: /.*/,
              attributes: true,
              classes: true,
              styles: true,
            },
          ],
        },
      });
    }

    // Classic build — stable, editable; toolbar matches bundled plugins.
    return Object.assign({}, shared, {
      toolbar: [
        'heading',
        '|',
        'bold',
        'italic',
        'link',
        'bulletedList',
        'numberedList',
        '|',
        'outdent',
        'indent',
        '|',
        'blockQuote',
        'insertTable',
        'uploadImage',
        'mediaEmbed',
        '|',
        'undo',
        'redo',
      ],
    });
  }

  function formatError(err) {
    if (!err) return 'Unknown CKEditor error';
    if (typeof err === 'string') return err;
    if (err.message) return err.message;
    return String(err);
  }

  /** Flutter platform views mount the host div asynchronously; wait before ClassicEditor.create. */
  function waitForElement(elementId, timeoutMs) {
    const limit = timeoutMs || 15000;
    return new Promise(function (resolve, reject) {
      const start = Date.now();
      function tick() {
        const el = document.getElementById(elementId);
        if (el) {
          resolve(el);
          return;
        }
        if (Date.now() - start > limit) {
          reject(new Error('CKEditor container not found: ' + elementId));
          return;
        }
        requestAnimationFrame(tick);
      }
      tick();
    });
  }

  window.tpkCkEditor = {
    create: function (elementId, initialHtml) {
      return loadCkEditor()
        .then(function () {
          const EditorClass = getEditorClass();
          if (!EditorClass) {
            throw new Error('CKEditor ClassicEditor is not available');
          }
          if (instances[elementId]) {
            return instances[elementId].destroy().then(function () {
              delete instances[elementId];
              return window.tpkCkEditor.create(elementId, initialHtml);
            });
          }
          return waitForElement(elementId, 15000).then(function (el) {
            return EditorClass.create(el, editorConfig(initialHtml));
          });
        })
        .then(function (editor) {
          instances[elementId] = editor;
          editor.model.document.on('change:data', function () {
            const html = editor.getData();
            if (typeof window.tpkCkEditorDartOnChange === 'function') {
              window.tpkCkEditorDartOnChange(elementId, html);
            }
          });
          return true;
        })
        .catch(function (err) {
          throw new Error(formatError(err));
        });
    },

    focus: function (elementId) {
      const editor = instances[elementId];
      if (!editor) return Promise.resolve(false);
      editor.editing.view.focus();
      return Promise.resolve(true);
    },

    setData: function (elementId, html) {
      const editor = instances[elementId];
      if (!editor) return Promise.resolve(false);
      const next = html || '';
      if (editor.getData() === next) return Promise.resolve(true);
      return Promise.resolve(editor.setData(next)).then(function () {
        return true;
      });
    },

    getData: function (elementId) {
      const editor = instances[elementId];
      return editor ? editor.getData() : '';
    },

    destroy: function (elementId) {
      const editor = instances[elementId];
      if (!editor) return Promise.resolve();
      delete instances[elementId];
      return editor.destroy();
    },

    getMode: function () {
      return editorMode;
    },
  };
})();
