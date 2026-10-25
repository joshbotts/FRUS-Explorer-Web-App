// The reader's Research rail (SPEC, Reader and Research rail), the app's RESEARCH panel beside the
// text: from S14c its Tags section, which the app's rail keeps closed until it is opened, and
// remembers. The section shows the document's tags, each with the × that takes it off, and Add Tag,
// which opens the tag picker. From S15c a Highlights section above it, the web's own: the
// document's highlights, as the app's review sheet lists them, each with its colour to change,
// which the app has no way to do, and Remove…, which asks as a tap on the highlight does and is the
// keyboard's way to remove one: the app's review sheet removes a stale one, but the app has no
// keyboard way to remove one that is not. From S15d, above them, the app's Summary and Notes
// sections, open until they are closed, as the app's are.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useId, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import { type Highlight, type HighlightColor, highlightColors, type UserTag } from '../api/types';
import {
  documentHighlightsQuery,
  documentNotesQuery,
  documentSummariesQuery,
  documentTagsQuery,
  recolorHighlight,
  removeDocumentTag,
} from '../api/userData';
import { copy } from '../copy';
import { reviewOrder, staleLine } from '../reader/highlightRules';
import { RemoveHighlight } from '../reader/RemoveHighlight';
import { useHighlightsSectionOpen, useNotesSectionOpen, useSummarySectionOpen, useTagsSectionOpen } from '../settings/preferences';
import { NotesSection } from './NotesSection';
import { noteCount, summaryPreview } from './notesRules';
import { shownSummaries, SummarySection } from './SummarySection';
import { TagPicker } from './TagPicker';

export function ResearchRail({
  volumeId,
  documentId,
  documentNumber,
  undrawnHighlights = new Set(),
  pendingHighlightId,
  onPendingUsed,
  autoFocus,
  onClose,
}: {
  volumeId: string;
  documentId: string;
  /** The printed number, which the tag picker's title names, as the app's does. */
  documentNumber?: string;
  /** The ids of the highlights the reader's page could not draw. */
  undrawnHighlights?: ReadonlySet<string>;
  /** The highlight made last on this document, which Add Note to Highlight makes a note for. */
  pendingHighlightId?: string | null;
  onPendingUsed?: () => void;
  /** Whether opening it takes focus to it: when the reader opens it, not when a page loads with it open. */
  autoFocus: boolean;
  onClose: () => void;
}) {
  const heading = useRef<HTMLHeadingElement>(null);
  const summaryToggle = useRef<HTMLButtonElement>(null);
  const notesToggle = useRef<HTMLButtonElement>(null);
  const highlightsToggle = useRef<HTMLButtonElement>(null);
  const [summaryOpen, setSummaryOpen] = useSummarySectionOpen();
  const [notesOpen, setNotesOpen] = useNotesSectionOpen();
  const [tagsOpen, setTagsOpen] = useTagsSectionOpen();
  const [highlightsOpen, setHighlightsOpen] = useHighlightsSectionOpen();
  const summaries = useQuery(documentSummariesQuery(volumeId, documentId));
  const notes = useQuery(documentNotesQuery(volumeId, documentId));
  const tags = useQuery(documentTagsQuery(volumeId, documentId));
  const highlights = useQuery(documentHighlightsQuery(volumeId, documentId));
  const count = tags.data?.items.length ?? 0;
  const highlightCount = highlights.data?.items.length ?? 0;
  const notesCount = notes.data?.items.length ?? 0;
  // The summary shown, the newest at first, and again on another document.
  const documentKey = `${volumeId}/${documentId}`;
  const [summaryAt, setSummaryAt] = useState({ documentKey, index: 0 });
  const summaryItems = summaries.data?.items.slice(0, shownSummaries);
  const summaryIndex = summaryAt.documentKey === documentKey ? Math.min(summaryAt.index, Math.max((summaryItems?.length ?? 1) - 1, 0)) : 0;
  const shownSummary = summaryItems?.[summaryIndex];
  const summaryPreviewed = summaryOpen !== 'open' && shownSummary ? summaryPreview(shownSummary.responseText) : null;
  const [focusOnOpen] = useState(autoFocus);
  useEffect(() => {
    if (focusOnOpen) heading.current?.focus({ preventScroll: true });
  }, [focusOnOpen]);

  return (
    <aside
      id="research-panel"
      className="rail"
      aria-labelledby="research-heading"
      // Escape closes the rail, as Close does; a dialog open over it takes Escape first.
      onKeyDown={(event) => {
        if (event.key === 'Escape' && !event.defaultPrevented) {
          event.stopPropagation();
          onClose();
        }
      }}
    >
      <div className="rail-header">
        <h2 id="research-heading" ref={heading} tabIndex={-1}>
          {copy.research.title}
        </h2>
        <button type="button" onClick={onClose}>
          {copy.research.close}
        </button>
      </div>
      <section className="rail-section">
        <h3>
          <button
            ref={summaryToggle}
            type="button"
            className="disclosure"
            aria-expanded={summaryOpen === 'open'}
            aria-controls="research-summary"
            // Named outright, as the badges are, when it shows its preview.
            aria-label={summaryPreviewed ? `${copy.summary.title}, ${summaryPreviewed}` : undefined}
            onClick={() => setSummaryOpen(summaryOpen === 'open' ? 'closed' : 'open')}
          >
            <span className="disclosure-mark" aria-hidden="true">
              {summaryOpen === 'open' ? '▾' : '▸'}
            </span>
            {copy.summary.title}
            {/* Closed, the header previews the summary shown, as the app's does. */}
            {summaryPreviewed && (
              <span className="disclosure-preview" aria-hidden="true">
                {summaryPreviewed}
              </span>
            )}
          </button>
        </h3>
        {summaryOpen === 'open' && (
          <div id="research-summary">
            {/* Made again for another document, as Notes is, so a dialog left open by Back or Forward writes to no other. */}
            <SummarySection
              key={documentKey}
              volumeId={volumeId}
              documentId={documentId}
              summaries={summaryItems}
              error={summaries.error}
              index={summaryIndex}
              onIndex={(index) => setSummaryAt({ documentKey, index })}
              toggle={summaryToggle}
            />
          </div>
        )}
      </section>
      <section className="rail-section">
        <h3>
          <button
            ref={notesToggle}
            type="button"
            className="disclosure"
            aria-expanded={notesOpen === 'open'}
            aria-controls="research-notes"
            aria-label={notesCount > 0 ? `${copy.notes.title}, ${noteCount(notesCount)}` : undefined}
            onClick={() => setNotesOpen(notesOpen === 'open' ? 'closed' : 'open')}
          >
            <span className="disclosure-mark" aria-hidden="true">
              {notesOpen === 'open' ? '▾' : '▸'}
            </span>
            {copy.notes.title}
            {notesCount > 0 && (
              <span className="badge" aria-hidden="true">
                {notesCount.toLocaleString('en-US')}
              </span>
            )}
          </button>
        </h3>
        {notesOpen === 'open' && (
          <div id="research-notes">
            {/* Made again for another document, as the bar's editor is closed, so one left open by Back or Forward saves to no other. */}
            <NotesSection
              key={documentKey}
              volumeId={volumeId}
              documentId={documentId}
              notes={notes.data?.items}
              error={notes.error}
              pendingHighlightId={pendingHighlightId}
              onPendingUsed={onPendingUsed}
              toggle={notesToggle}
            />
          </div>
        )}
      </section>
      <section className="rail-section">
        <h3>
          <button
            ref={highlightsToggle}
            type="button"
            className="disclosure"
            aria-expanded={highlightsOpen === 'open'}
            aria-controls="research-highlights"
            aria-label={highlightCount > 0 ? `${copy.highlights.section}, ${copy.highlights.count(highlightCount)}` : undefined}
            onClick={() => setHighlightsOpen(highlightsOpen === 'open' ? 'closed' : 'open')}
          >
            <span className="disclosure-mark" aria-hidden="true">
              {highlightsOpen === 'open' ? '▾' : '▸'}
            </span>
            {copy.highlights.section}
            {highlightCount > 0 && (
              <span className="badge" aria-hidden="true">
                {highlightCount.toLocaleString('en-US')}
              </span>
            )}
          </button>
        </h3>
        {highlightsOpen === 'open' && (
          <div id="research-highlights">
            <HighlightsSection
              highlights={highlights.data?.items}
              error={highlights.error}
              undrawn={undrawnHighlights}
              toggle={highlightsToggle}
            />
          </div>
        )}
      </section>
      <section className="rail-section">
        <h3>
          <button
            type="button"
            className="disclosure"
            aria-expanded={tagsOpen === 'open'}
            aria-controls="research-tags"
            // Named outright: a browser reads the badge's parts with spaces of its own between them.
            aria-label={count > 0 ? `${copy.research.tags}, ${copy.research.tagCount(count)}` : undefined}
            onClick={() => setTagsOpen(tagsOpen === 'open' ? 'closed' : 'open')}
          >
            {/* The mark is drawn, not read: aria-expanded says it. */}
            <span className="disclosure-mark" aria-hidden="true">
              {tagsOpen === 'open' ? '▾' : '▸'}
            </span>
            {copy.research.tags}
            {count > 0 && (
              <span className="badge" aria-hidden="true">
                {count.toLocaleString('en-US')}
              </span>
            )}
          </button>
        </h3>
        {tagsOpen === 'open' && (
          <div id="research-tags">
            <TagsSection volumeId={volumeId} documentId={documentId} documentNumber={documentNumber} tags={tags.data?.items} error={tags.error} />
          </div>
        )}
      </section>
    </aside>
  );
}

function TagsSection({
  volumeId,
  documentId,
  documentNumber,
  tags,
  error,
}: {
  volumeId: string;
  documentId: string;
  documentNumber?: string;
  tags?: UserTag[];
  error: unknown;
}) {
  const client = useQueryClient();
  const addButton = useRef<HTMLButtonElement>(null);
  const [picking, setPicking] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);

  async function remove(tag: UserTag) {
    setFailure(null);
    try {
      await removeDocumentTag(client, volumeId, documentId, tag.id);
      // The chip is gone; focus goes to Add Tag, which stays.
      addButton.current?.focus();
    } catch (problem) {
      setFailure(errorMessage(problem));
    }
  }

  if (error) {
    return (
      <p className="error" role="alert">
        {errorMessage(error)}
      </p>
    );
  }
  if (!tags) return <p role="status">{copy.research.loading}</p>;
  return (
    <>
      <div className="chips tag-chips" role="group" aria-label={copy.research.tags}>
        {tags.map((tag) => (
          <button key={tag.id} type="button" className="chip tag-chip" aria-label={copy.research.removeTag(tag.name)} onClick={() => void remove(tag)}>
            {tag.name} <span aria-hidden="true">×</span>
          </button>
        ))}
        {/* With tags shown, the app's button is a plus alone; its name stays Add Tag. */}
        <button ref={addButton} type="button" className="chip add-tag" onClick={() => setPicking(true)}>
          <span aria-hidden="true">+</span>{' '}
          <span className={tags.length > 0 ? 'visually-hidden' : undefined}>{copy.research.addTag}</span>
        </button>
      </div>
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      {picking && (
        <TagPicker
          volumeId={volumeId}
          documentId={documentId}
          documentNumber={documentNumber}
          applied={tags}
          onClose={() => {
            setPicking(false);
            addButton.current?.focus();
          }}
        />
      )}
    </>
  );
}

function HighlightsSection({
  highlights,
  error,
  undrawn,
  toggle,
}: {
  highlights?: Highlight[];
  error: unknown;
  undrawn: ReadonlySet<string>;
  /** The section's disclosure, which takes focus when the last highlight is removed. */
  toggle: { current: HTMLButtonElement | null };
}) {
  const client = useQueryClient();
  const list = useRef<HTMLUListElement>(null);
  const [removing, setRemoving] = useState<{ highlight: Highlight; index: number } | null>(null);
  // The rows whose colour is being changed: each waits for its own change alone.
  const [recolouring, setRecolouring] = useState<ReadonlySet<string>>(new Set());
  const [failure, setFailure] = useState<string | null>(null);
  const rows = highlights ? reviewOrder(highlights) : undefined;

  async function recolour(highlight: Highlight, color: HighlightColor) {
    if (recolouring.has(highlight.id) || highlight.colorTag === color) return;
    setRecolouring((rows) => new Set(rows).add(highlight.id));
    setFailure(null);
    try {
      await recolorHighlight(client, highlight, color);
    } catch (problem) {
      setFailure(errorMessage(problem));
    } finally {
      setRecolouring((rows) => {
        const left = new Set(rows);
        left.delete(highlight.id);
        return left;
      });
    }
  }

  /** After a removal, focus goes to the next row's Remove…, else the one before it, else the section. */
  function focusAfterRemoving(index: number) {
    requestAnimationFrame(() => {
      const buttons = list.current?.querySelectorAll<HTMLButtonElement>('button.remove-highlight') ?? [];
      (buttons[index] ?? buttons[index - 1] ?? toggle.current)?.focus();
    });
  }

  if (error) {
    return (
      <p className="error" role="alert">
        {errorMessage(error)}
      </p>
    );
  }
  if (!rows) return <p role="status">{copy.highlights.loading}</p>;
  return (
    <>
      {rows.length > 0 && (
        <ul ref={list} className="highlight-list">
          {rows.map((highlight, index) => (
            <HighlightRow
              key={highlight.id}
              highlight={highlight}
              undrawn={undrawn.has(highlight.id)}
              busy={recolouring.has(highlight.id)}
              onRecolour={(color) => void recolour(highlight, color)}
              onRemove={() => setRemoving({ highlight, index })}
            />
          ))}
        </ul>
      )}
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      {removing && (
        <RemoveHighlight
          highlight={removing.highlight}
          onClose={(removed) => {
            const { highlight, index } = removing;
            setRemoving(null);
            // Once the question has gone: while a modal dialog is open, all else is inert.
            if (removed) focusAfterRemoving(index);
            else
              requestAnimationFrame(() =>
                list.current?.querySelector<HTMLButtonElement>(`button.remove-highlight[data-id="${CSS.escape(highlight.id)}"]`)?.focus(),
              );
          }}
        />
      )}
    </>
  );
}

/**
 * One highlight, as the app's review sheet shows it: its words, or Highlighted passage when it stored
 * none; the sheet's line when it was made against an earlier version of the text; its colour, which
 * the web can change; and Remove….
 */
function HighlightRow({
  highlight,
  undrawn,
  busy,
  onRecolour,
  onRemove,
}: {
  highlight: Highlight;
  undrawn: boolean;
  busy: boolean;
  onRecolour: (color: HighlightColor) => void;
  onRemove: () => void;
}) {
  const textId = useId();
  const stale = staleLine(highlight);
  return (
    <li className={`highlight-row hl-${highlight.colorTag}`}>
      <p id={textId} className="highlight-text">
        {highlight.selectedText === '' ? <em>{copy.highlights.noPassage}</em> : highlight.selectedText}
      </p>
      {stale && <p className="highlight-status">{copy.highlights[stale]}</p>}
      {undrawn && <p className="highlight-status">{copy.highlights.notDrawn}</p>}
      <div className="highlight-actions">
        <div className="highlight-colors" role="group" aria-label={copy.highlights.color} aria-describedby={textId}>
          {highlightColors.map((color) => (
            <button
              key={color}
              type="button"
              className={`highlight-color hl-${color}`}
              aria-pressed={highlight.colorTag === color}
              aria-describedby={textId}
              // aria-disabled, not disabled, so the button pressed by keyboard keeps its focus.
              aria-disabled={busy}
              onClick={() => onRecolour(color)}
            >
              {copy.highlights.colors[color]}
            </button>
          ))}
        </div>
        <button type="button" className="remove-highlight" data-id={highlight.id} aria-describedby={textId} onClick={onRemove}>
          {copy.highlights.remove}
        </button>
      </div>
    </li>
  );
}
