// The update review (PLAN's S21f): the strip above a document whose text changed since the user annotated it,
// in the app's words (`DocumentChangeBanner`), with Review…; and the review sheet, the web's own over the kit's
// rules, which the server runs: What Changed, with Mark Reviewed; each highlight with its standing and, where the
// kit's search found its passage again close to where it was, Move Here, with the words and what surrounds them,
// and Confirm and Remove…; each quotation with the kit's check of it; and the other annotations, counted, the
// notes opened from it and the tags edited. It moves nothing and removes nothing of its own accord, as the app's
// does not. Its rows keep the order they opened in, so that a move does not shift a row under the keyboard.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useId, useState } from 'react';
import { ApiError, errorMessage } from '../api/client';
import {
  confirmHighlight,
  type DocumentReview,
  documentChangeQuery,
  documentReviewQuery,
  highlightRemoved,
  markReviewed,
  moveHighlight,
  type ReviewHighlight,
} from '../api/reviews';
import type { Highlight, HighlightColor } from '../api/types';
import { documentTagsQuery } from '../api/userData';
import { copy } from '../copy';
import { NoteEditor } from '../research/NoteEditor';
import { TagPicker } from '../research/TagPicker';
import { closeAtOnce, Modal } from '../shell/Modal';
import { RemoveHighlight } from './RemoveHighlight';

const words = copy.review;

/** The banner above a document, for a user who keeps data: the app's sentence, and Review…, or nothing. */
export function DocumentChangeBanner({
  volumeId,
  documentId,
  enabled,
  onReview,
}: {
  volumeId: string;
  documentId: string;
  enabled: boolean;
  onReview: () => void;
}) {
  const change = useQuery(documentChangeQuery(volumeId, documentId, enabled));
  const line = change.data?.line;
  if (!enabled || !line) return null;
  return (
    <div className="change-banner" role="region" aria-label={words.bannerLabel}>
      <p>
        <span aria-hidden="true">⚠︎ </span>
        {line}
      </p>
      <button type="button" onClick={onReview}>
        {words.review}
      </button>
    </div>
  );
}

/** The review sheet of a document, as a dialog; `onClose` once it is done. */
export function ReviewSheet({
  volumeId,
  documentId,
  title,
  documentNumber,
  onClose,
}: {
  volumeId: string;
  documentId: string;
  title: string;
  documentNumber?: string;
  onClose: () => void;
}) {
  const review = useQuery(documentReviewQuery(volumeId, documentId));
  const headingId = useId();
  // The rows' order as the sheet opened, which a move does not change.
  const [order, setOrder] = useState<string[] | null>(null);
  if (review.data && order === null) setOrder(review.data.highlights.map((row) => row.id));
  const [opening, setOpening] = useState<{ kind: 'note'; id: string } | { kind: 'tags' } | null>(null);
  const tags = useQuery({ ...documentTagsQuery(volumeId, documentId), enabled: opening?.kind === 'tags' });

  return (
    <>
      <Modal
        className="review-sheet"
        labelledBy={headingId}
        onCancel={() => {
          if (!opening) onClose();
        }}
        onClose={onClose}
      >
        <div className="review-sheet-header">
          <h2 id={headingId} tabIndex={-1}>
            {title}
          </h2>
          <button type="button" onClick={() => closeAtOnce(onClose)}>
            {words.done}
          </button>
        </div>
        {review.isError ? (
          <p className="error" role="alert">
            {errorMessage(review.error)}
          </p>
        ) : !review.data ? (
          <p role="status">{words.loading}</p>
        ) : (
          <Sections
            review={review.data}
            order={order ?? []}
            volumeId={volumeId}
            documentId={documentId}
            onOpenNote={(id) => setOpening({ kind: 'note', id })}
            onEditTags={() => setOpening({ kind: 'tags' })}
          />
        )}
      </Modal>
      {opening?.kind === 'note' && (
        <NoteEditor
          volumeId={volumeId}
          documentId={documentId}
          note={{ id: opening.id, volumeId, documentId }}
          onClose={() => {
            const id = opening.id;
            closeAtOnce(() => setOpening(null));
            requestAnimationFrame(() => document.querySelector<HTMLElement>(`button[data-note="${CSS.escape(id)}"]`)?.focus());
          }}
        />
      )}
      {opening?.kind === 'tags' && tags.data && (
        <TagPicker
          volumeId={volumeId}
          documentId={documentId}
          documentNumber={documentNumber}
          applied={tags.data.items}
          onClose={() => {
            closeAtOnce(() => setOpening(null));
            requestAnimationFrame(() => document.querySelector<HTMLElement>('button[data-edit-tags]')?.focus());
          }}
        />
      )}
    </>
  );
}

function Sections({
  review,
  order,
  volumeId,
  documentId,
  onOpenNote,
  onEditTags,
}: {
  review: DocumentReview;
  order: string[];
  volumeId: string;
  documentId: string;
  onOpenNote: (id: string) => void;
  onEditTags: () => void;
}) {
  const client = useQueryClient();
  const [said, setSaid] = useState('');
  const [failure, setFailure] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [removing, setRemoving] = useState<ReviewHighlight | null>(null);
  const changeId = useId();
  const highlightsId = useId();
  const excerptsId = useId();
  const othersId = useId();
  const rank = new Map(order.map((id, index) => [id, index]));
  const highlights = [...review.highlights].sort(
    (a, b) => (rank.get(a.id) ?? Number.MAX_SAFE_INTEGER) - (rank.get(b.id) ?? Number.MAX_SAFE_INTEGER),
  );
  const version = review.currentVersion;

  async function act(key: string, work: () => Promise<unknown>, done: string) {
    if (busy) return;
    setBusy(key);
    setFailure(null);
    setSaid('');
    try {
      await work();
      setSaid(done);
    } catch (error) {
      setFailure(error instanceof ApiError ? error.message : errorMessage(error));
    } finally {
      setBusy(null);
    }
  }

  const others = review.others;
  const parts = [
    others.notes.length > 0 ? words.notesCount(others.notes.length) : null,
    others.tagCount > 0 ? words.tagsCount(others.tagCount) : null,
    others.collectionCount > 0 ? words.collectionsCount(others.collectionCount) : null,
    others.summaryCount > 0 ? words.summariesCount(others.summaryCount) : null,
    others.inVisitPlan ? words.inVisitPlan : null,
  ].filter((part): part is string => part !== null);

  return (
    <>
      <p role="status" className="review-said">
        {said}
      </p>
      <p className="error" role="alert">
        {failure}
      </p>
      <section aria-labelledby={changeId} className="review-section">
        <h3 id={changeId}>{words.changeHeader}</h3>
        <p className={review.change.vanished ? 'error' : review.change.changeKind || review.change.highlightsStale ? 'review-change' : 'note'}>
          {review.changeLine}
        </p>
        {review.change.foundInTEI && <p className="note">{words.foundInTEI}</p>}
        {review.change.canMarkReviewed && (
          <>
            <button
              type="button"
              aria-disabled={busy !== null}
              onClick={() => void act('review', () => markReviewed(client, volumeId, documentId), words.markedReviewed)}
            >
              {words.markReviewed}
            </button>
            <p className="note">{words.changeFooter}</p>
          </>
        )}
      </section>
      {highlights.length > 0 && (
        <section aria-labelledby={highlightsId} className="review-section">
          <h3 id={highlightsId}>{words.highlightsHeader}</h3>
          <ul className="review-rows">
            {highlights.map((row) => (
              <li key={row.id} className={`review-highlight hl-${row.colorTag as HighlightColor}`}>
                {row.context ? (
                  // The found words in their surroundings, in place of the bare passage.
                  <p className="review-context">
                    <span className="note">…{row.context.before}</span>
                    <strong>{row.context.found}</strong>
                    <span className="note">{row.context.after}…</span>
                  </p>
                ) : row.selectedText ? (
                  <p className="review-passage">{row.selectedText}</p>
                ) : (
                  <p className="review-passage note">
                    <em>{words.noPassage}</em>
                  </p>
                )}
                <p className={row.status === 'aligned' ? 'note' : 'review-change'}>{row.statusLine}</p>
                {row.searchLine && <p className="review-change">{row.searchLine}</p>}
                <p className="actions">
                  {row.canMove && version && (
                    <button
                      type="button"
                      aria-disabled={busy !== null}
                      aria-label={words.moveA11y(passageOf(row))}
                      onClick={() =>
                        void act(row.id, () => moveHighlight(client, volumeId, documentId, row.id, version), words.moved)
                      }
                    >
                      {words.move}
                    </button>
                  )}{' '}
                  {row.canConfirm && version && (
                    <button
                      type="button"
                      aria-disabled={busy !== null}
                      aria-label={words.confirmA11y(passageOf(row))}
                      onClick={() =>
                        void act(row.id, () => confirmHighlight(client, volumeId, documentId, row.id, version), words.confirmed)
                      }
                    >
                      {words.confirm}
                    </button>
                  )}{' '}
                  <button
                    type="button"
                    className="destructive"
                    data-remove={row.id}
                    aria-label={words.removeA11y(passageOf(row))}
                    onClick={() => setRemoving(row)}
                  >
                    {words.remove}
                  </button>
                </p>
              </li>
            ))}
          </ul>
          <p className="note">{words.highlightsFooter}</p>
        </section>
      )}
      {review.excerpts.length > 0 && (
        <section aria-labelledby={excerptsId} className="review-section">
          <h3 id={excerptsId}>{words.excerptsHeader}</h3>
          <ul className="review-rows">
            {review.excerpts.map((excerpt) => (
              <li key={excerpt.id}>
                <p className="review-passage">{excerpt.text}</p>
                <p className="note">{excerpt.collectionName}</p>
                <p className={excerpt.warning ? 'review-change' : 'note'}>{excerpt.finding}</p>
                {excerpt.capture && <p className="note">{excerpt.capture}</p>}
              </li>
            ))}
          </ul>
          <p className="note">{words.excerptsFooter}</p>
        </section>
      )}
      <section aria-labelledby={othersId} className="review-section">
        <h3 id={othersId}>{words.othersHeader}</h3>
        <p>{parts.length > 0 ? parts.join(' · ') : <span className="note">{words.othersNone}</span>}</p>
        <ul className="review-links">
          {others.notes.map((note) => (
            <li key={note.id}>
              <button type="button" data-note={note.id} onClick={() => onOpenNote(note.id)}>
                {note.title ?? words.openNote}
              </button>
            </li>
          ))}
          <li>
            <button type="button" data-edit-tags onClick={onEditTags}>
              {words.editTags}
            </button>
          </li>
        </ul>
        <p className="note">{words.othersFooter}</p>
      </section>
      {removing && (
        <RemoveHighlight
          highlight={asHighlight(removing, volumeId, documentId, review.currentVersion)}
          onClose={(removed) => {
            const id = removing.id;
            closeAtOnce(() => setRemoving(null));
            if (removed) {
              void highlightRemoved(client, volumeId, documentId);
              setSaid(words.removed);
            }
            // Back to the row's Remove…, or, once the row has gone, to the section's heading.
            requestAnimationFrame(() => {
              const button = document.querySelector<HTMLElement>(`button[data-remove="${CSS.escape(id)}"]`);
              (button ?? document.getElementById(highlightsId) ?? document.getElementById(changeId))?.focus();
            });
          }}
        />
      )}
    </>
  );
}

/** A row's words, for its buttons' names: the passage, cut short, or the app's word for one with none. */
function passageOf(row: ReviewHighlight): string {
  const text = row.selectedText.trim();
  if (!text) return words.noPassage;
  return text.length > 60 ? `${text.slice(0, 60)}…` : text;
}

/** The row as the reader's Remove Highlight takes a highlight. */
function asHighlight(row: ReviewHighlight, volumeId: string, documentId: string, version?: string): Highlight {
  return {
    id: row.id,
    volumeId,
    documentId,
    startOffset: row.startOffset,
    endOffset: row.endOffset,
    colorTag: row.colorTag as HighlightColor,
    selectedText: row.selectedText,
    renderingVersion: version ?? '',
  } as Highlight;
}
