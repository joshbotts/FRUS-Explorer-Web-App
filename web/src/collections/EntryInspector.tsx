// The entry inspector (PLAN's S18d), the app's `CollectionEntryInspector` as the iPad's Configure sheet
// shows it: for a document, its identity and title override, the reader's annotations with what the
// entry includes, New Note… and Insert as Excerpt, its export overrides, each showing what Default
// resolves to, its headnote's switch and card, its excerpts here and its provenance; for a section
// heading, its section defaults. Each control writes as it is changed. From S18f the headnote card, the
// app's: the summary the headnote shows, with who wrote it, which Edit writes over as the researcher's
// own, AI · edited over the model's, with no Generate, since the server writes no summary; New Note…,
// the app's inline sheet, which a partial selection of notes takes; and Summary only offered for a
// document only where it has a summary stored, the line under the picker the web's own.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useId, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import {
  addExcerpts,
  type CollectionDetail,
  collectionQuery,
  type EntryChanges,
  entryInspectorQuery,
  type EntryInspector as Inspected,
  saveHeadnote,
  updateEntry,
} from '../api/collections';
import { createNote, projectsQuery } from '../api/userData';
import { copy } from '../copy';
import { closeAtOnce, Modal } from '../shell/Modal';
import { useActiveProjectId } from '../shell/ProjectPicker';
import { ChosenCheckbox, ChosenSelect } from './chosen';
import { bodyDepthChoices } from './collectionRules';
import { SavedText } from './CollectionSettings';

type Tri = boolean | null;

/** A Default / On / Off picker (`overridePicker`), with what Default resolves to while it is chosen. */
function OverridePicker({
  label,
  value,
  resolved,
  onChange,
}: {
  label: string;
  value: boolean | undefined;
  /** What Default resolves to, for a document; none for a section. */
  resolved?: boolean;
  onChange: (value: Tri) => void;
}) {
  const id = useId();
  const words = copy.collectionInspector;
  return (
    <div className="field override">
      <label htmlFor={id}>{label}</label>
      <ChosenSelect
        id={id}
        value={value === undefined ? '' : value ? 'on' : 'off'}
        aria-describedby={value === undefined && resolved !== undefined ? `${id}-resolves` : undefined}
        onChoose={(chosen) => onChange(chosen === '' ? null : chosen === 'on')}
      >
        <option value="">{words.default}</option>
        <option value="on">{words.on}</option>
        <option value="off">{words.off}</option>
      </ChosenSelect>
      {value === undefined && resolved !== undefined && (
        <p id={`${id}-resolves`} className="note">
          {resolved ? words.resolvesOn : words.resolvesOff}
        </p>
      )}
    </div>
  );
}

export function EntryInspector({ detail, entryId, onClose }: { detail: CollectionDetail; entryId: string; onClose: () => void }) {
  const client = useQueryClient();
  const headingId = useId();
  const done = useRef<HTMLButtonElement>(null);
  const inspected = useQuery(entryInspectorQuery(detail.id, entryId));
  const entry = detail.entries.find((candidate) => candidate.id === entryId);
  const [failure, setFailure] = useState<string | null>(null);
  const [inserted, setInserted] = useState<ReadonlySet<string>>(new Set());
  const [creatingNote, setCreatingNote] = useState(false);
  const newNoteButton = useRef<HTMLButtonElement>(null);
  const words = copy.collectionInspector;
  const heading = entry?.kind === 'heading';
  // The collection's name, the generic role while it has none (`collectionDisplayTitle`).
  const title = detail.name !== '' ? detail.name : heading ? words.sectionTitle : words.documentTitle;

  async function change(changes: EntryChanges) {
    setFailure(null);
    try {
      await updateEntry(client, detail.id, entryId, changes);
    } catch (error) {
      setFailure(errorMessage(error));
    }
  }

  // The highlights being inserted, set at the press, so a second press before the answer adds none.
  const inserting = useRef(new Set<string>());

  async function insert(highlightId: string) {
    if (inserting.current.has(highlightId)) return;
    inserting.current.add(highlightId);
    setFailure(null);
    try {
      await addExcerpts(client, detail.id, { highlightIds: [highlightId] });
      setInserted((held) => new Set(held).add(highlightId));
    } catch (error) {
      inserting.current.delete(highlightId);
      setFailure(errorMessage(error));
    }
  }

  const data: Inspected | undefined = inspected.data;
  const promptName = (id: string | undefined) => detail.prompts.find((prompt) => prompt.id === id)?.name ?? words.promptNone;
  // A document's Summary only, offered only where its document has a summary stored.
  const documentDepths = data?.summaryOnlyOffered === false ? detail.bodyDepths.filter((depth) => depth !== 'summaryOnly') : detail.bodyDepths;
  const summaryOnlyRefused = !documentDepths.includes('summaryOnly') && entry?.bodyDepthOverride !== 'summaryOnly';

  /** The six override controls (`overrideControls`), a document's own or a section's defaults. */
  function overrides(resolved: Inspected['resolved']) {
    if (!entry) return null;
    return (
      <>
        <OverridePicker
          label={words.highlights}
          value={entry.applyHighlightsOverride}
          resolved={resolved?.highlights}
          onChange={(value) => void change({ applyHighlightsOverride: value })}
        />
        <OverridePicker
          label={words.notes}
          value={entry.includeNotesOverride}
          resolved={resolved?.notes}
          onChange={(value) => void change({ includeNotesOverride: value })}
        />
        <OverridePicker
          label={words.sourceNote}
          value={entry.includeSourceNoteOverride}
          resolved={resolved?.sourceNote}
          onChange={(value) => void change({ includeSourceNoteOverride: value })}
        />
        <OverridePicker
          label={words.footnotes}
          value={entry.includeFootnotesOverride}
          resolved={resolved?.footnotes}
          onChange={(value) => void change({ includeFootnotesOverride: value })}
        />
        <div className="field override">
          <label htmlFor={`${headingId}-prompt`}>{words.prompt}</label>
          <ChosenSelect
            id={`${headingId}-prompt`}
            value={entry.summaryPromptIdOverride ?? ''}
            aria-describedby={!entry.summaryPromptIdOverride && resolved ? `${headingId}-prompt-resolves` : undefined}
            onChoose={(chosen) => void change({ summaryPromptIdOverride: chosen === '' ? null : chosen })}
          >
            <option value="">{words.default}</option>
            {detail.prompts.map((prompt) => (
              <option key={prompt.id} value={prompt.id}>
                {prompt.name}
              </option>
            ))}
          </ChosenSelect>
          {!entry.summaryPromptIdOverride && resolved && (
            <p id={`${headingId}-prompt-resolves`} className="note">
              {words.resolvesTo(promptName(resolved.summaryPromptId))}
            </p>
          )}
        </div>
        <OverridePicker
          label={words.related}
          value={entry.includeRelatedDocuments}
          resolved={resolved?.related}
          onChange={(value) => void change({ includeRelatedDocuments: value })}
        />
        <p className="note">{words.relatedCaption}</p>
      </>
    );
  }

  return (
    <Modal className="entry-inspector" labelledBy={headingId} initial={done} onCancel={onClose} onClose={() => {}}>
      <div className="dialog-header">
        <h2 id={headingId} tabIndex={-1}>
          {title}
        </h2>
        <button ref={done} type="button" className="primary" onClick={onClose}>
          {words.done}
        </button>
      </div>
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      {!entry ? null : inspected.isError ? (
        <p className="error" role="alert">
          {errorMessage(inspected.error)}
        </p>
      ) : !data ? (
        <p role="status">{words.loading}</p>
      ) : heading ? (
        <>
          <section aria-label={words.section}>
            <dl className="facts">
              <dt>{words.section}</dt>
              <dd>{data.sectionTitle}</dd>
            </dl>
          </section>
          <section aria-labelledby={`${headingId}-defaults`}>
            <h3 id={`${headingId}-defaults`}>{words.sectionDefaults}</h3>
            {overrides(undefined)}
            <p className="note">{words.sectionDefaultsCaption}</p>
          </section>
        </>
      ) : (
        <>
          <section aria-label={words.document}>
            {data.header && <p className="inspector-header">{data.header}</p>}
            <dl className="facts">
              <dt>{words.document}</dt>
              <dd>{data.documentId}</dd>
              <dt>{words.volume}</dt>
              <dd>{data.volumeTitle ?? data.volumeId}</dd>
            </dl>
            <SavedText
              label={words.titleOverride}
              value={entry.titleOverride ?? ''}
              placeholder={data.derivedTitle}
              onSave={(titleOverride) => updateEntry(client, detail.id, entryId, { titleOverride })}
            />
            <p className="note">{words.titleOverrideCaption}</p>
          </section>
          <section aria-labelledby={`${headingId}-annotations`}>
            <h3 id={`${headingId}-annotations`}>{words.yourAnnotations}</h3>
            {data.notes.length === 0 ? (
              <p className="note">{words.noNotes}</p>
            ) : (
              <>
                <ul className="inclusions">
                  {data.notes.map((note) => (
                    <li key={note.id}>
                      <label>
                        <ChosenCheckbox
                          checked={note.included}
                          aria-label={`${words.noteInclude}: ${note.preview}`}
                          onChoose={(included) => void change({ note: { id: note.id, included } })}
                        />{' '}
                        {note.preview}
                      </label>
                    </li>
                  ))}
                </ul>
                <p className="note">{words.noteCaption}</p>
              </>
            )}
            <button ref={newNoteButton} type="button" onClick={() => setCreatingNote(true)}>
              {words.newNote}
            </button>
            <p>{words.highlightCount(data.highlights.length)}</p>
            {data.highlights.length > 0 && (
              <>
                <ul className="inclusions">
                  {data.highlights.map((highlight) => (
                    <li key={highlight.id} className={`hl-row hl-${highlight.colorTag}`}>
                      <label>
                        <ChosenCheckbox
                          checked={highlight.included}
                          aria-label={`${words.highlightInclude}: ${highlight.text ?? copy.highlights.noPassage}`}
                          onChoose={(included) => void change({ highlight: { id: highlight.id, included } })}
                        />{' '}
                        <span className={`color-dot hl-${highlight.colorTag}`} aria-hidden="true" />
                        {highlight.text ?? <em>{words.noText}</em>}
                      </label>
                      {highlight.text && detail.takesHandAddedEntries && (
                        // One button, which says Inserted once pressed, so the focus it holds stays.
                        <button
                          type="button"
                          className={inserted.has(highlight.id) ? 'inserted' : undefined}
                          aria-disabled={inserted.has(highlight.id) || undefined}
                          onClick={() => !inserted.has(highlight.id) && void insert(highlight.id)}
                        >
                          {inserted.has(highlight.id) ? words.inserted : words.insertExcerpt}
                        </button>
                      )}
                    </li>
                  ))}
                </ul>
                <p className="note">{words.highlightCaption}</p>
              </>
            )}
            {data.tags.length > 0 && (
              <p>
                <span className="visually-hidden">{words.tags}: </span>
                {data.tags.join(', ')}
              </p>
            )}
            {data.summary && (
              <div className="inspector-summary">
                <p className="note">{data.summary.promptName ? words.summaryFromPrompt(data.summary.promptName) : words.summary}</p>
                <p className="summary-preview">{data.summary.text}</p>
              </div>
            )}
          </section>
          <section aria-labelledby={`${headingId}-overrides`}>
            <h3 id={`${headingId}-overrides`}>{words.overrides}</h3>
            <div className="field override">
              <label htmlFor={`${headingId}-depth`}>{words.bodyDepth}</label>
              <ChosenSelect
                id={`${headingId}-depth`}
                value={entry.bodyDepthOverride ?? ''}
                aria-describedby={
                  [
                    !entry.bodyDepthOverride && data.resolved ? `${headingId}-depth-resolves` : '',
                    summaryOnlyRefused ? `${headingId}-depth-reason` : '',
                  ]
                    .filter(Boolean)
                    .join(' ') || undefined
                }
                onChoose={(chosen) => void change({ bodyDepthOverride: chosen === '' ? null : chosen })}
              >
                <option value="">{words.bodyDepthDefault}</option>
                {bodyDepthChoices(documentDepths, entry.bodyDepthOverride).map(({ depth, disabled }) => (
                  <option key={depth} value={depth} disabled={disabled}>
                    {copy.collectionSettings.bodyDepths[depth] ?? depth}
                  </option>
                ))}
              </ChosenSelect>
              {!entry.bodyDepthOverride && data.resolved && (
                <p id={`${headingId}-depth-resolves`} className="note">
                  {words.resolvesTo(copy.collectionSettings.bodyDepths[data.resolved.bodyDepth] ?? data.resolved.bodyDepth)}
                </p>
              )}
              {summaryOnlyRefused && (
                <p id={`${headingId}-depth-reason`} className="note">
                  {words.summaryOnlyUnavailable} {copy.collectionSettings.summaryOnlyReason}
                </p>
              )}
            </div>
            {overrides(data.resolved)}
            <p className="note">{words.overridesCaption}</p>
          </section>
          <section aria-labelledby={`${headingId}-headnote`}>
            <h3 id={`${headingId}-headnote`}>{words.headnote}</h3>
            <OverridePicker
              label={words.headnoteToggle}
              value={entry.includeHeadnote}
              resolved={data.resolved?.headnote}
              onChange={(value) => void change({ includeHeadnote: value })}
            />
            {(entry.includeHeadnote ?? data.resolved?.headnote ?? false) && (
              <HeadnoteCard collectionId={detail.id} entryId={entryId} headnote={data.headnote} />
            )}
          </section>
          {data.excerpts.length > 0 && (
            <section aria-labelledby={`${headingId}-excerpts`}>
              <h3 id={`${headingId}-excerpts`}>{words.excerpts}</h3>
              <ul className="inspector-excerpts">
                {data.excerpts.map((excerpt) => (
                  <li key={excerpt.id}>
                    <blockquote>{excerpt.text}</blockquote>
                  </li>
                ))}
              </ul>
              <p className="note">{words.excerptsCaption}</p>
            </section>
          )}
          <section aria-labelledby={`${headingId}-provenance`}>
            <h3 id={`${headingId}-provenance`}>{words.provenance}</h3>
            <p>{data.sourceNote && data.sourceNote !== '' ? data.sourceNote : words.noSource}</p>
          </section>
        </>
      )}
      {creatingNote && entry && (
        <NewNoteSheet
          volumeId={entry.volumeId}
          documentId={entry.documentId}
          onCreated={async (noteId) => {
            // The note is on this document, so an entry with every note (none chosen) already takes it; a
            // partial selection is given it, as the app's sheet appends it.
            if (entry.selectedNoteIds.length > 0) await change({ note: { id: noteId, included: true } });
            else {
              // Every note is the entry's already: the inspector, and the collection, whose row counts the
              // document's notes and whose preview shows them, are read again.
              void client.invalidateQueries({ queryKey: entryInspectorQuery(detail.id, entryId).queryKey });
              void client.invalidateQueries({ queryKey: collectionQuery(detail.id).queryKey });
            }
          }}
          onClose={() => {
            setCreatingNote(false);
            requestAnimationFrame(() => newNoteButton.current?.focus());
          }}
        />
      )}
    </Modal>
  );
}

/**
 * The headnote card (`headnoteCard`): Key takeaway · headnote, the chip of who wrote the summary it shows,
 * its text, or the app's line for none, and Edit, which opens the text to change, Cancel and Save, Save
 * dimmed while the text is empty. What it saves is the server's, `commitHeadnote(seed:)`'s rule.
 */
function HeadnoteCard({ collectionId, entryId, headnote }: { collectionId: string; entryId: string; headnote: Inspected['headnote'] }) {
  const client = useQueryClient();
  const fieldId = useId();
  const editButton = useRef<HTMLButtonElement>(null);
  const field = useRef<HTMLTextAreaElement>(null);
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState('');
  const [saving, setSaving] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const words = copy.collectionInspector;
  const empty = draft.trim() === '';

  /** Leaves editing, drawn at once, so that Edit, which takes the pressed button's place, takes its focus. */
  function leave() {
    closeAtOnce(() => setEditing(false));
    editButton.current?.focus();
  }

  async function save() {
    if (empty || saving) return;
    setSaving(true);
    setFailure(null);
    try {
      await saveHeadnote(client, collectionId, entryId, draft);
      // The card shows what was saved, and who wrote it, before it leaves editing, so a second Edit starts from it.
      await client.refetchQueries({ queryKey: entryInspectorQuery(collectionId, entryId).queryKey });
      leave();
    } catch (error) {
      setFailure(errorMessage(error));
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="headnote-card">
      <div className="headnote-header">
        <p className="headnote-title">{words.headnoteKeyTakeaway}</p>
        {headnote && <span className="headnote-chip">{words.headnoteChips[headnote.authorship] ?? words.headnoteChips.aiGenerated}</span>}
      </div>
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      {editing ? (
        <>
          <label htmlFor={fieldId} className="visually-hidden">
            {words.headnoteText}
          </label>
          <textarea ref={field} id={fieldId} rows={4} value={draft} onChange={(event) => setDraft(event.target.value)} />
          <div className="dialog-actions">
            <button type="button" onClick={leave}>
              {words.headnoteCancel}
            </button>
            {/* aria-disabled, not disabled, so Save pressed by keyboard keeps its focus while it is saved. */}
            <button type="button" className="primary" aria-disabled={empty || saving} onClick={() => void save()}>
              {words.headnoteSave}
            </button>
          </div>
        </>
      ) : (
        <>
          {headnote ? <p className="headnote-text">{headnote.text}</p> : <p className="note">{words.headnoteEmpty}</p>}
          <button
            ref={editButton}
            type="button"
            onClick={() => {
              setDraft(headnote?.text ?? '');
              setEditing(true);
              requestAnimationFrame(() => field.current?.focus());
            }}
          >
            {words.headnoteEdit}
          </button>
        </>
      )}
    </div>
  );
}

/**
 * New Note…'s sheet, the app's `InlineNoteCreateSheet`: New Research Note, the note's text, Cancel and Save
 * Note, dimmed until the text holds more than spaces; the note made on the document, its text trimmed, in
 * the project the user works in.
 */
function NewNoteSheet({
  volumeId,
  documentId,
  onCreated,
  onClose,
}: {
  volumeId: string;
  documentId: string;
  onCreated: (noteId: string) => Promise<void>;
  onClose: () => void;
}) {
  const client = useQueryClient();
  const headingId = useId();
  const fieldId = useId();
  const field = useRef<HTMLTextAreaElement>(null);
  const projects = useQuery(projectsQuery);
  const active = useActiveProjectId(projects.data);
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const words = copy.collectionInspector;
  const trimmed = text.trim();

  async function save() {
    if (trimmed === '' || busy) return;
    setBusy(true);
    setFailure(null);
    try {
      const note = await createNote(client, volumeId, documentId, {
        bodyText: trimmed,
        runs: null,
        userTagIds: [],
        projectIds: active ? [active] : [],
        selectedSummaryIds: [],
      });
      await onCreated(note.id);
      closeAtOnce(onClose);
    } catch (error) {
      setFailure(errorMessage(error));
      setBusy(false);
    }
  }

  return (
    <Modal className="new-note" labelledBy={headingId} initial={field} onCancel={onClose} onClose={() => {}}>
      <h2 id={headingId} tabIndex={-1}>
        {words.newNoteTitle}
      </h2>
      <label htmlFor={fieldId} className="visually-hidden">
        {words.newNoteText}
      </label>
      <textarea ref={field} id={fieldId} rows={6} value={text} onChange={(event) => setText(event.target.value)} />
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      <div className="dialog-actions">
        <button type="button" onClick={onClose}>
          {words.newNoteCancel}
        </button>
        <button type="button" className="primary" aria-disabled={trimmed === '' || busy} onClick={() => void save()}>
          {words.newNoteSave}
        </button>
      </div>
    </Modal>
  );
}
