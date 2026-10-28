// The research note editor (PLAN's S15d), as the app's sheet: New Research Note or Edit Note, and
// in it the note's text with the Formatting switch, its tags with a field that makes one at once,
// its projects, and the document's summaries to insert into it; Delete for a note being edited, with
// no question, as the app's editor asks none; Discard, which Escape is; and Save. A save is the
// edit's, as the app's: the text and its formatting go only when the text was changed here, as runs
// when it was changed with formatting on and as plain text, which drops the formatting, when it was
// typed with it off; otherwise the store keeps both as they are. Ids a list does not show, a tag or
// project gone since or one the Mac's data names, are kept as the note has them, and the tags and
// projects are boxes to tick, in name order, the web's own, where the app's picker waits for S17b.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Component, lazy, type ReactNode, Suspense, useEffect, useId, useRef, useState } from 'react';
import { ApiError, errorMessage } from '../api/client';
import type { NoteRun, NoteSummary, Summary, UserTag } from '../api/types';
import {
  createNote,
  createTag,
  deleteNote,
  documentNotesQuery,
  documentSummariesQuery,
  type NoteChanges,
  noteGone,
  noteQuery,
  notesQuery,
  projectsQuery,
  tagsQuery,
  updateNote,
} from '../api/userData';
import { copy } from '../copy';
import type { RichTextEditorHandle } from '../editor/RichTextEditor';
import { runsText, withSummary } from '../editor/runs';
import { useNoteEditorRichText } from '../settings/preferences';
import { useListOrder } from '../settings/syncedPreferences';
import { applyOrder } from './listOrder';
import { closeAtOnce, Modal } from '../shell/Modal';

const RichTextEditor = lazy(() => import('../editor/RichTextEditor'));

/** The formatting editor, or, when its code could not be loaded, nothing, so the note opens plain. */
class EditorBoundary extends Component<{ onFailure: () => void; children: ReactNode }, { failed: boolean }> {
  override state = { failed: false };

  static getDerivedStateFromError() {
    return { failed: true };
  }

  override componentDidCatch() {
    this.props.onFailure();
  }

  override render() {
    return this.state.failed ? null : this.props.children;
  }
}

/** The note's text as it stands, its formatting or null for none, and whether it was changed here. */
interface Body {
  text: string;
  runs: NoteRun[] | null;
  edited: boolean;
}

interface Draft {
  body: Body;
  userTagIds: string[];
  projectIds: string[];
  selectedSummaryIds: string[];
}

const upper = (id: string) => id.toUpperCase();

/** Whether runs carry any formatting, which an edit typed with formatting off drops. */
function carriesFormatting(runs: readonly NoteRun[] | null | undefined): boolean {
  return !!runs?.some((run) => run.bold || run.italic || run.underline || run.colorHex !== undefined || run.linkURL !== undefined);
}

/** The ids to save: those ticked that a list shows or the note already holds, in the order ticked. */
function kept(ids: readonly string[], listed: readonly { id: string }[], held: readonly string[] = []): string[] {
  const keep = new Set([...listed.map((item) => upper(item.id)), ...held.map(upper)]);
  return ids.filter((id) => keep.has(upper(id)));
}

function toggled(ids: readonly string[], id: string, on: boolean): string[] {
  const rest = ids.filter((other) => upper(other) !== upper(id));
  return on ? [...rest, id] : rest;
}

export type NoteEditorOutcome = 'saved' | 'deleted' | 'discarded';

export function NoteEditor({
  volumeId,
  documentId,
  note,
  linkedHighlightId,
  onClose,
}: {
  volumeId: string;
  documentId: string;
  /** The note to edit; none for a new one. */
  note?: Pick<NoteSummary, 'id' | 'volumeId' | 'documentId'>;
  /** The highlight a new note is the note of, the rail's Add Note to Highlight. */
  linkedHighlightId?: string;
  onClose: (outcome: NoteEditorOutcome) => void;
}) {
  const client = useQueryClient();
  const headingId = useId();
  const bodyHeadingId = useId();
  const bodyId = useId();
  const textarea = useRef<HTMLTextAreaElement>(null);
  const editorHandle = useRef<RichTextEditorHandle>(null);
  const editing = note !== undefined;
  const stored = useQuery({ ...noteQuery(note?.id ?? ''), enabled: editing });
  const tags = useQuery(tagsQuery);
  const projects = useQuery(projectsQuery);
  const summaries = useQuery(documentSummariesQuery(volumeId, documentId));
  const [richText, setRichText] = useNoteEditorRichText();
  // For this note only: its formatting could not be shown, or the editor could not be loaded.
  const [fallback, setFallback] = useState<'unreadable' | 'failed' | null>(null);
  const formatted = richText === 'true' && fallback === null;
  const [draft, setDraft] = useState<Draft | null>(() =>
    editing ? null : { body: { text: '', runs: null, edited: false }, userTagIds: [], projectIds: [], selectedSummaryIds: [] },
  );
  // From this opening's own read, never from a copy an earlier one left in the cache, which a change
  // in another tab or browser, or a tag deleted since, may have made old; and not from one whose
  // read again failed, as for a note deleted elsewhere, whose refusal is shown.
  if (draft === null && stored.data && stored.isFetchedAfterMount && !stored.isError) {
    const { bodyText, runs, userTagIds, projectIds, selectedSummaryIds } = stored.data;
    setDraft({ body: { text: bodyText, runs, edited: false }, userTagIds, projectIds, selectedSummaryIds });
  }
  /** The tags made here, which the list may not hold yet. */
  const [made, setMade] = useState<UserTag[]>([]);
  const [newTag, setNewTag] = useState('');
  const [making, setMaking] = useState(false);
  const [announcement, setAnnouncement] = useState('');
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);

  // A note deleted elsewhere leaves the lists it was in.
  useEffect(() => {
    if (!note || !noteGone(stored.error)) return;
    void client.invalidateQueries({ queryKey: notesQuery.queryKey });
    void client.invalidateQueries({ queryKey: documentNotesQuery(note.volumeId, note.documentId).queryKey });
  }, [client, note, stored.error]);

  // A new note's text takes focus, once its heading has had it, as the dialog opens; in the plain
  // field at once, in the formatting editor once it has loaded.
  useEffect(() => {
    if (!editing) textarea.current?.focus();
  }, [editing]);

  // Both lists in the reader's own order (S17f), as the app's note editor lists them.
  const { tagOrder, projectOrder } = useListOrder();
  const tagItems = [
    ...applyOrder(tags.data?.items ?? [], tagOrder, (tag) => tag.id),
    ...made.filter((tag) => !tags.data?.items.some((listed) => listed.id === tag.id)),
  ];
  const projectItems = applyOrder(projects.data?.items ?? [], projectOrder, (project) => project.id);
  const summaryItems = summaries.data?.items ?? [];

  function setBody(body: Body) {
    setDraft((earlier) => earlier && { ...earlier, body });
  }

  function discard() {
    if (!busy) onClose('discarded');
  }

  async function addTag() {
    const name = newTag.trim();
    if (!name || making) return;
    setMaking(true);
    setFailure(null);
    try {
      // Made at once, as the app's is, so Discard keeps it.
      const tag = await createTag(client, name);
      setMade((earlier) => [...earlier, tag]);
      setDraft((earlier) => earlier && { ...earlier, userTagIds: toggled(earlier.userTagIds, tag.id, true) });
      setNewTag('');
      setAnnouncement(copy.tagPicker.created(tag.name));
    } catch (error) {
      setFailure(errorMessage(error));
    } finally {
      setMaking(false);
    }
  }

  /** Insert into note, as the app's: the summary's text after a blank line, or alone in an empty note. */
  function insert(summary: Summary) {
    if (!draft || draft.selectedSummaryIds.some((id) => upper(id) === upper(summary.id))) return;
    setDraft({ ...draft, selectedSummaryIds: [...draft.selectedSummaryIds, summary.id] });
    const { text } = draft.body;
    if (formatted && editorHandle.current) {
      // The web's own: added to the formatted text, whose formatting stays, where the app's drops it.
      editorHandle.current.insertSummary(summary.responseText);
    } else if (formatted) {
      // The same while the formatting editor is still loading: added to the runs it will open with.
      const runs = withSummary(draft.body.runs, text, summary.responseText);
      setBody({ text: runsText(runs), runs, edited: true });
    } else {
      setBody({ text: text === '' ? summary.responseText : `${text}\n\n${summary.responseText}`, runs: null, edited: true });
    }
  }

  async function save() {
    if (!draft || busy) return;
    const lists = {
      userTagIds: kept(draft.userTagIds, tagItems, stored.data?.userTagIds),
      projectIds: kept(draft.projectIds, projectItems, stored.data?.projectIds),
      selectedSummaryIds: kept(draft.selectedSummaryIds, summaryItems, stored.data?.selectedSummaryIds),
    };
    setBusy(true);
    setFailure(null);
    try {
      if (note) {
        const changes: NoteChanges = { ...lists };
        if (draft.body.edited) {
          changes.bodyText = draft.body.text;
          changes.runs = draft.body.runs;
        }
        await updateNote(client, note, changes);
      } else {
        await createNote(client, volumeId, documentId, {
          bodyText: draft.body.text,
          runs: draft.body.edited ? draft.body.runs : null,
          ...lists,
          ...(linkedHighlightId ? { linkedHighlightId } : {}),
        });
      }
      closeAtOnce(() => onClose('saved'));
    } catch (error) {
      setFailure(errorMessage(error));
      setBusy(false);
      // A tag, project or summary the server no longer has: the lists and the note are read again,
      // so what is gone is not sent again.
      if (error instanceof ApiError && (error.code === 'TAG_NOT_FOUND' || error.code === 'INVALID_FIELD')) {
        for (const key of [tagsQuery.queryKey, projectsQuery.queryKey, documentSummariesQuery(volumeId, documentId).queryKey]) {
          void client.invalidateQueries({ queryKey: key });
        }
        if (note) void client.invalidateQueries({ queryKey: noteQuery(note.id).queryKey });
      }
    }
  }

  async function remove() {
    if (!note || busy) return;
    setBusy(true);
    setFailure(null);
    try {
      await deleteNote(client, note);
      closeAtOnce(() => onClose('deleted'));
    } catch (error) {
      setFailure(errorMessage(error));
      setBusy(false);
    }
  }

  // A plain note has no formatting to keep: what the formatting editor cannot show is its line breaks.
  const unreadable = stored.data?.runs || stored.data?.formattingKept ? copy.noteEditor.unreadable : copy.noteEditor.unreadablePlain;
  // A note with formatting, the server's or made here before the editor failed, loses it once its
  // text is typed in the plain field, so the sentence says so, as the one for a note it cannot show.
  const hasFormatting = stored.data?.formattingKept === true || carriesFormatting(stored.data?.runs) || carriesFormatting(draft?.body.runs);
  const notice =
    fallback === 'failed'
      ? hasFormatting
        ? copy.noteEditor.editorFailedFormatted
        : copy.noteEditor.editorFailed
      : fallback === 'unreadable'
        ? unreadable
        : stored.data?.formattingKept && !draft?.body.edited
          ? copy.noteEditor.formattingKept
          : null;

  return (
    <Modal className="note-editor" labelledBy={headingId} onCancel={discard} onClose={() => {}}>
      <div className="note-editor-header">
        <h2 id={headingId} tabIndex={-1}>
          {editing ? copy.noteEditor.titleEdit : copy.noteEditor.titleNew}
        </h2>
        {editing && draft && (
          // aria-disabled, not disabled, so a press by keyboard keeps its focus.
          <button type="button" className="destructive" aria-disabled={busy} onClick={() => void remove()}>
            {copy.noteEditor.delete}
          </button>
        )}
      </div>
      {!draft ? (
        stored.isError ? (
          <p className="error" role="alert">
            {errorMessage(stored.error)}
          </p>
        ) : (
          <p role="status">{copy.noteEditor.loading}</p>
        )
      ) : (
        <>
          <section className="note-text" aria-labelledby={bodyHeadingId}>
            <div className="note-text-header">
              <h3 id={bodyHeadingId}>{copy.noteEditor.body}</h3>
              {/* Named by the word it shows: the app's hidden "Formatted text" would not match it. */}
              <label className="switch">
                <input
                  type="checkbox"
                  role="switch"
                  checked={formatted}
                  disabled={fallback !== null}
                  onChange={(event) => setRichText(event.target.checked ? 'true' : 'false')}
                />{' '}
                {copy.noteEditor.formatting}
              </label>
            </div>
            {notice && <p className="note">{notice}</p>}
            {formatted ? (
              <EditorBoundary onFailure={() => setFallback('failed')}>
                <Suspense fallback={<p role="status">{copy.noteEditor.editorLoading}</p>}>
                  <RichTextEditor
                    ref={editorHandle}
                    id={bodyId}
                    label={copy.noteEditor.bodyLabel}
                    runs={draft.body.runs}
                    text={draft.body.text}
                    autoFocus={!editing}
                    onChange={(runs) => setBody({ text: runsText(runs), runs, edited: true })}
                    onDiscard={discard}
                    onUnreadable={() => setFallback('unreadable')}
                  />
                </Suspense>
              </EditorBoundary>
            ) : (
              <textarea
                ref={textarea}
                id={bodyId}
                className="note-body plain"
                aria-label={copy.noteEditor.bodyLabel}
                value={draft.body.text}
                rows={8}
                // Typed with formatting off: the formatting goes, as the app's setPlainBody drops it.
                onChange={(event) => setBody({ text: event.target.value.replace(/\0/g, ' '), runs: null, edited: true })}
              />
            )}
          </section>
          <fieldset className="note-assignments">
            <legend>{copy.noteEditor.tags}</legend>
            {!tags.data && !tags.isError ? (
              <p role="status">{copy.research.loading}</p>
            ) : tagItems.length === 0 ? (
              <p className="note">{copy.noteEditor.tagsEmpty}</p>
            ) : (
              <ul className="assignment-options">
                {tagItems.map((tag) => (
                  <li key={tag.id}>
                    <label>
                      <input
                        type="checkbox"
                        checked={draft.userTagIds.some((id) => upper(id) === upper(tag.id))}
                        onChange={(event) => setDraft({ ...draft, userTagIds: toggled(draft.userTagIds, tag.id, event.target.checked) })}
                      />{' '}
                      {tag.name}
                    </label>
                  </li>
                ))}
              </ul>
            )}
            <form
              className="new-tag"
              onSubmit={(event) => {
                event.preventDefault();
                void addTag();
              }}
            >
              <input
                type="text"
                value={newTag}
                placeholder={copy.noteEditor.newTag}
                aria-label={copy.noteEditor.newTag}
                onChange={(event) => setNewTag(event.target.value)}
              />
              {/* aria-disabled, not disabled, so Add pressed by keyboard keeps its focus while the tag is made. */}
              <button type="submit" aria-disabled={newTag.trim() === '' || making}>
                {copy.noteEditor.addTag}
              </button>
            </form>
            <p className="visually-hidden" role="status">
              {announcement}
            </p>
          </fieldset>
          <fieldset className="note-assignments">
            <legend>{copy.noteEditor.projects}</legend>
            {projects.data && projectItems.length === 0 ? (
              <p className="note">{copy.noteEditor.projectsEmpty}</p>
            ) : (
              <ul className="assignment-options">
                {projectItems.map((project) => (
                  <li key={project.id}>
                    <label>
                      <input
                        type="checkbox"
                        checked={draft.projectIds.some((id) => upper(id) === upper(project.id))}
                        onChange={(event) => setDraft({ ...draft, projectIds: toggled(draft.projectIds, project.id, event.target.checked) })}
                      />{' '}
                      {project.name}
                    </label>
                  </li>
                ))}
              </ul>
            )}
          </fieldset>
          {summaryItems.length > 0 && (
            <section className="note-summaries" aria-labelledby={`${headingId}-summaries`}>
              <h3 id={`${headingId}-summaries`}>{copy.noteEditor.summaries}</h3>
              <ul>
                {summaryItems.map((summary) => (
                  <SummaryRow
                    key={summary.id}
                    summary={summary}
                    inserted={draft.selectedSummaryIds.some((id) => upper(id) === upper(summary.id))}
                    onInsert={() => insert(summary)}
                    onRemove={() =>
                      setDraft({ ...draft, selectedSummaryIds: draft.selectedSummaryIds.filter((id) => upper(id) !== upper(summary.id)) })
                    }
                  />
                ))}
              </ul>
            </section>
          )}
        </>
      )}
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      <div className="actions">
        <button type="button" aria-disabled={busy} onClick={discard}>
          {copy.noteEditor.discard}
        </button>
        {draft && (
          <button type="button" aria-disabled={busy} onClick={() => void save()}>
            {copy.noteEditor.save}
          </button>
        )}
      </div>
    </Modal>
  );
}

/**
 * A summary in the editor's Generated Summaries, its text to three lines, with Insert into note, or
 * Remove from note once it is in, which only unticks it, as the app's leaves the text.
 */
function SummaryRow({ summary, inserted, onInsert, onRemove }: { summary: Summary; inserted: boolean; onInsert: () => void; onRemove: () => void }) {
  const textId = useId();
  return (
    <li className="note-summary">
      <p id={textId} className="note-summary-text">
        {summary.responseText}
      </p>
      {inserted ? (
        <button type="button" className="destructive" aria-describedby={textId} onClick={onRemove}>
          {copy.noteEditor.remove}
        </button>
      ) : (
        <button type="button" aria-describedby={textId} onClick={onInsert}>
          {copy.noteEditor.insert}
        </button>
      )}
    </li>
  );
}
