// /reader/host.js: what the reader's page needs from its host, written for a browser.

/// The script the reader's page loads from its head. It stands in for what FRUS Explorer's WebKit
/// host gives the same page: the three message handlers the app's reader scripts post to
/// (`selectionChanged`, `selectionScrolled`, `highlightTapped`), and the handling of the reader's
/// `frusexplorer://` links (`person/`, `gloss/`, `doc/`, `brokenref/`). Each becomes a message to
/// the parent page, which acts on it; the page itself navigates nowhere. The reader's own scripts
/// arrive with the phase-1 features' upstream pull request.
enum ReaderHostScript {
    static let source = """
        // FRUS Explorer Light: the reader page's host script.
        (function () {
          'use strict';
          function post(kind, detail) {
            if (window.parent === window) { return; }
            window.parent.postMessage({ source: 'frus-reader', kind: kind, detail: detail }, window.location.origin);
          }
          if (!window.webkit) {
            var handlers = {};
            ['selectionChanged', 'selectionScrolled', 'highlightTapped'].forEach(function (name) {
              handlers[name] = { postMessage: function (body) { post(name, body); } };
            });
            window.webkit = { messageHandlers: handlers };
          }
          document.addEventListener('click', function (event) {
            var target = event.target;
            var link = target && target.closest ? target.closest('a[href^="frusexplorer:"]') : null;
            if (!link) { return; }
            event.preventDefault();
            post('link', { href: link.getAttribute('href') });
          });
        })();

        """
}
