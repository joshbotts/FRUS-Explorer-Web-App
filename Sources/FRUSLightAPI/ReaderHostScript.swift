// /reader/host.js: what the reader's page needs from its host, written for a browser.

import FRUSCoreKit

/// The script the reader's page loads from its head, after the app's three reader scripts from the
/// kit. It stands in for what FRUS Explorer's WebKit host gives the same page: the three message
/// handlers those scripts post to (`selectionChanged`, `selectionScrolled`, `highlightTapped`), the
/// call that draws the document's highlights (`FRUSHighlights.render`), the handling of the reader's
/// `frusexplorer://` links (`person/`, `gloss/`, `doc/`, `brokenref/`), and the footnote landing.
/// Each link becomes a message to the parent page, which acts on it; the page itself navigates
/// nowhere.
///
/// Highlights (PLAN's S15c): the parent sends the document's highlights (`{source: 'frus-app',
/// kind: 'highlights', highlights}`, each the kit's `ReaderHighlight`), and the host draws them with
/// the kit's renderer, as the app's reader evaluates `FRUSHighlights.render` after each load. It
/// first tries each with the kit's own `buildRanges`, and passes the renderer only those that build:
/// the kit's renderer stops at one that ends on a line break, whose range cannot end after a `<br>`,
/// and would draw none of the others. It answers `highlightsRendered`, with how many it drew and
/// the indexes of those it could not. `{kind: 'collapseSelection'}` collapses the selection to its
/// end once a colour is chosen, as the app's iPhone and iPad reader clears it, so the new colour is
/// not hidden under the selection's. With a selection in the text, which the kit's own bridge
/// places (`rangeEndpointToOffset`, `selectionGeometry`), ⇧⌘H, or Ctrl+Shift+H, the app's shortcut
/// for Highlight Selection ▸ Yellow, is posted as `highlightShortcut`, and Alt+F10, the web's own key
/// for a toolbar, as `selectionBarShortcut`, each with the selection's offsets and rectangle; Escape
/// with any selection is posted as `selectionEscape`, which hides the bar. The parent page acts on
/// them, since the frame's keys never reach it; for Alt+F10 pressed in the parent page it asks
/// (`{kind: 'selectionBarRequest'}`), and the host answers as for the key in the frame.
/// A tap the kit reports is passed on unless it came from the keyboard, whose click has no point
/// for the kit's hit test to read, or from a reader link, which is followed instead: a link inside
/// a highlight would otherwise open its card and the question to remove the highlight at once.
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
          // Whether the click being dispatched may report a tap on a highlight: set before the kit's
          // listener reads it, in the capture phase.
          var tapAllowed = true;
          if (!window.webkit) {
            var handlers = {};
            ['selectionChanged', 'selectionScrolled', 'highlightTapped'].forEach(function (name) {
              handlers[name] = { postMessage: function (body) {
                if (name === 'highlightTapped' && !tapAllowed) { return; }
                post(name, body);
              } };
            });
            window.webkit = { messageHandlers: handlers };
          }
          // The selection in the text, by the kit's selection bridge: its offsets, in the app's rule
          // for one in the document (`hasOffsets`), and its rectangle; null for none, for a
          // footnote's, and for one the bridge cannot place.
          function selectionInText() {
            var selection = window.getSelection();
            if (!selection || selection.isCollapsed || !selection.rangeCount || typeof rangeEndpointToOffset !== 'function') { return null; }
            var range = selection.getRangeAt(0);
            var start = rangeEndpointToOffset(range.startContainer, range.startOffset);
            var end = rangeEndpointToOffset(range.endContainer, range.endOffset);
            if (!(start >= 0 && end > start)) { return null; }
            return { start: start, end: end, rect: selectionGeometry(range).rect };
          }
          // FRUS Explorer's highlights, drawn by the kit's renderer: those whose ranges the kit can
          // build, so that one it cannot does not keep the others from the page.
          function drawHighlights(highlights) {
            if (!window.FRUSHighlights || !window.FRUSOffsets || typeof buildRanges !== 'function') { return; }
            var drawable = [];
            var skipped = [];
            highlights.forEach(function (highlight, index) {
              try {
                if (buildRanges(highlight.startOffset, highlight.endOffset).length) { drawable.push(highlight); return; }
              } catch (_) {}
              skipped.push(index);
            });
            window.FRUSHighlights.render(drawable);
            post('highlightsRendered', { drawn: drawable.length, skipped: skipped });
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
          window.addEventListener('click', function (event) {
            tapAllowed = event.detail !== 0 && !readerLink(event);
          }, true);
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
            var highlight = event.shiftKey && (event.metaKey || event.ctrlKey) && !event.altKey && (event.key === 'h' || event.key === 'H');
            var bar = event.altKey && !event.metaKey && !event.ctrlKey && event.key === 'F10';
            if (highlight || bar) {
              var inText = selectionInText();
              if (inText) {
                event.preventDefault();
                post(highlight ? 'highlightShortcut' : 'selectionBarShortcut', inText);
                return;
              }
            }
            if (event.key === 'Escape') {
              var live = window.getSelection();
              if (live && !live.isCollapsed) { post('selectionEscape', {}); }
            }
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
            if (data.kind === 'highlights' && Array.isArray(data.highlights)) {
              drawHighlights(data.highlights);
            }
            // Alt+F10 pressed in the app around the frame: the bar, where the selection is now.
            if (data.kind === 'selectionBarRequest') {
              var inText = selectionInText();
              if (inText) { post('selectionBarShortcut', inText); }
            }
            if (data.kind === 'collapseSelection') {
              var selection = window.getSelection();
              if (selection && selection.rangeCount && !selection.isCollapsed) { selection.collapseToEnd(); }
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
