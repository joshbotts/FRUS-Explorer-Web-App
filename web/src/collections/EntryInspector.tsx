// The entry inspector (PLAN's S18d), the app's `CollectionEntryInspector` as the iPad's Configure sheet
// shows it: for a document, its identity and title override, the reader's annotations with what the
// entry includes and Insert as Excerpt, its export overrides, each showing what Default resolves to,
// its headnote's switch, its excerpts here and its provenance; for a section heading, its section
// defaults. Each control writes as it is changed. The headnote's card, which writes one, is S18f's.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useId, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import {
  addExcerpts,
  type CollectionDetail,
  type EntryChanges,
  entryInspectorQuery,
  type EntryInspector as Inspected,
  updateEntry,
} from '../api/collections';
import { copy } from '../copy';
import { Modal } from '../shell/Modal';
import { bodyDepthOptions } from './collectionRules';
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
      <select
        id={id}
        value={value === undefined ? '' : value ? 'on' : 'off'}
        aria-describedby={value === undefined && resolved !== undefined ? `${id}-resolves` : undefined}
        onChange={(event) => onChange(event.target.value === '' ? null : event.target.value === 'on')}
      >
        <option value="">{words.default}</option>
        <option value="on">{words.on}</option>
        <option value="off">{words.off}</option>
      </select>
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

  async function insert(highlightId: string) {
    setFailure(null);
    try {
      await addExcerpts(client, detail.id, { highlightIds: [highlightId] });
      setInserted((held) => new Set(held).add(highlightId));
    } catch (error) {
      setFailure(errorMessage(error));
    }
  }

  const data: Inspected | undefined = inspected.data;
  const promptName = (id: string | undefined) => detail.prompts.find((prompt) => prompt.id === id)?.name ?? words.promptNone;

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
          <select
            id={`${headingId}-prompt`}
            value={entry.summaryPromptIdOverride ?? ''}
            aria-describedby={!entry.summaryPromptIdOverride && resolved ? `${headingId}-prompt-resolves` : undefined}
            onChange={(event) => void change({ summaryPromptIdOverride: event.target.value === '' ? null : event.target.value })}
          >
            <option value="">{words.default}</option>
            {detail.prompts.map((prompt) => (
              <option key={prompt.id} value={prompt.id}>
                {prompt.name}
              </option>
            ))}
          </select>
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
                        <input
                          type="checkbox"
                          checked={note.included}
                          aria-label={`${words.noteInclude}: ${note.preview}`}
                          onChange={(event) => void change({ note: { id: note.id, included: event.target.checked } })}
                        />{' '}
                        {note.preview}
                      </label>
                    </li>
                  ))}
                </ul>
                <p className="note">{words.noteCaption}</p>
              </>
            )}
            <p>{words.highlightCount(data.highlights.length)}</p>
            {data.highlights.length > 0 && (
              <>
                <ul className="inclusions">
                  {data.highlights.map((highlight) => (
                    <li key={highlight.id} className={`hl-row hl-${highlight.colorTag}`}>
                      <label>
                        <input
                          type="checkbox"
                          checked={highlight.included}
                          aria-label={`${words.highlightInclude}: ${highlight.text ?? copy.highlights.noPassage}`}
                          onChange={(event) => void change({ highlight: { id: highlight.id, included: event.target.checked } })}
                        />{' '}
                        <span className={`color-dot hl-${highlight.colorTag}`} aria-hidden="true" />
                        {highlight.text ?? <em>{words.noText}</em>}
                      </label>
                      {highlight.text &&
                        detail.takesHandAddedEntries &&
                        (inserted.has(highlight.id) ? (
                          <span className="inserted">{words.inserted}</span>
                        ) : (
                          <button type="button" onClick={() => void insert(highlight.id)}>
                            {words.insertExcerpt}
                          </button>
                        ))}
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
              <select
                id={`${headingId}-depth`}
                value={entry.bodyDepthOverride ?? ''}
                aria-describedby={!entry.bodyDepthOverride && data.resolved ? `${headingId}-depth-resolves` : undefined}
                onChange={(event) => void change({ bodyDepthOverride: event.target.value === '' ? null : event.target.value })}
              >
                <option value="">{words.bodyDepthDefault}</option>
                {bodyDepthOptions(detail.bodyDepths, entry.bodyDepthOverride).map((depth) => (
                  <option key={depth} value={depth}>
                    {copy.collectionSettings.bodyDepths[depth] ?? depth}
                  </option>
                ))}
              </select>
              {!entry.bodyDepthOverride && data.resolved && (
                <p id={`${headingId}-depth-resolves`} className="note">
                  {words.resolvesTo(copy.collectionSettings.bodyDepths[data.resolved.bodyDepth] ?? data.resolved.bodyDepth)}
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
    </Modal>
  );
}
