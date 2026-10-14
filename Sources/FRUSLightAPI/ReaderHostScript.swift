// /reader/host.js: what the reader's page needs from its host, written for a browser.

import FRUSCoreKit

/// The script the reader's page loads from its head. It stands in for what FRUS Explorer's WebKit
/// host gives the same page: the three message handlers the app's reader scripts post to
/// (`selectionChanged`, `selectionScrolled`, `highlightTapped`), the handling of the reader's
/// `frusexplorer://` links (`person/`, `gloss/`, `doc/`, `brokenref/`), and the footnote landing.
/// Each link becomes a message to the parent page, which acts on it; the page itself navigates
/// nowhere. The reader's own scripts are still the app's alone.
///
/// The footnote landing is the kit's `FootnoteLanding` script, which the app's reader runs once a
/// page has loaded, here as the body of `landOnFootnote(key)`: it scrolls a note's entry in the list
/// of footnotes into view and washes it, as the app's reader does.
///
/// What a browser adds to a WebKit view's host: a middle click on a reader link is ignored, since
/// the sandbox would refuse the window it opens; Space activates an unresolved reference, which the
/// kit marks as a button; and, since the parent cannot reach into the frame, it asks: the link last
/// activated takes focus again when a card for it closes (`{source: 'frus-app', kind:
/// 'restoreFocus'}`), and a note is landed on when a link names it (`{source: 'frus-app', kind:
/// 'reveal', id}`, the id of the note's entry), after which the entry takes focus, so the next Tab
/// continues from it.
enum ReaderHostScript {
    /// The kit's footnote landing, its key the parameter `key` of the function around it.
    static let footnoteLanding = FootnoteLanding.script(keyExpression: "key")

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
          // FRUS Explorer's footnote landing (FRUSCoreKit's FootnoteLanding), for the note whose key is
          // `key`: true when the page holds the note's entry.
          function landOnFootnote(key) {
            return \(footnoteLanding);
          }
          var lastLink = null;
          function readerLink(event) {
            var target = event.target;
            return target && target.closest ? target.closest('a[href^="frusexplorer:"]') : null;
          }
          document.addEventListener('click', function (event) {
            var link = readerLink(event);
            if (!link) { return; }
            event.preventDefault();
            lastLink = link;
            post('link', { href: link.getAttribute('href') });
          });
          document.addEventListener('auxclick', function (event) {
            if (readerLink(event)) { event.preventDefault(); }
          });
          document.addEventListener('keydown', function (event) {
            var link = readerLink(event);
            if (link && event.key === ' ' && link.getAttribute('role') === 'button') {
              event.preventDefault();
              link.click();
            }
          });
          window.addEventListener('message', function (event) {
            var data = event.data;
            if (event.source !== window.parent || !data || data.source !== 'frus-app') { return; }
            if (data.kind === 'restoreFocus' && lastLink && document.contains(lastLink)) {
              lastLink.focus({ preventScroll: true });
            }
            var prefix = '\(ReaderLinkRoutes.footnoteEntryPrefix)';
            var target = data.kind === 'reveal' && typeof data.id === 'string' && data.id.indexOf(prefix) === 0
              ? document.getElementById(data.id) : null;
            if (target && landOnFootnote(data.id.slice(prefix.length))) {
              if (!target.hasAttribute('tabindex')) { target.setAttribute('tabindex', '-1'); }
              target.focus({ preventScroll: true });
            }
          });
        })();

        """
}
