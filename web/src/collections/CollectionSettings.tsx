// Collection settings (PLAN's S18d), the iPad editor's ⚙ sheet: the name and note, the title page and
// introduction, the presets, Briefing packet only where a summary is stored, and the composition's
// three groups, in the app's order and words. Each field saves as it is typed and each switch as it is
// turned, as the app's commits each field from its binding.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Component, lazy, type ReactNode, Suspense, useEffect, useId, useRef, useState } from 'react';
import { applyPreset, type CollectionChanges, type CollectionDetail, linkSavedSearch, tocStyles, updateCollection } from '../api/collections';
import { errorMessage } from '../api/client';
import { type SavedSearch, savedSearchesQuery } from '../api/searchSets';
import type { NoteRun } from '../api/types';
import { projectsQuery } from '../api/userData';
import { copy } from '../copy';
import { runsText } from '../editor/runs';
import { Modal } from '../shell/Modal';
import { useActiveProjectId } from '../shell/ProjectPicker';
import { ChosenCheckbox, ChosenSelect } from './chosen';
import { bodyDepthChoices } from './collectionRules';
import { useSaver } from './useSaver';

const RichTextEditor = lazy(() => import('../editor/RichTextEditor'));

class EditorBoundary extends Component<{ children: ReactNode }, { failed: boolean }> {
  override state = { failed: false };

  static getDerivedStateFromError() {
    return { failed: true };
  }

  override render() {
    return this.state.failed ? <p className="error">{copy.collectionEditor.proseFailed}</p> : this.props.children;
  }
}

/**
 * A text field that saves as it is typed: what the server holds while it is not being typed in, and
 * each edit sent a moment after the typing stops, or when it is left.
 */
export function SavedText({
  label,
  value,
  placeholder,
  multiline = false,
  hideLabel = false,
  focusOnShow = false,
  onSave,
}: {
  label: string;
  value: string;
  placeholder?: string;
  multiline?: boolean;
  /** Whether the label is read rather than shown, as a field the app names by its prompt alone. */
  hideLabel?: boolean;
  /** Whether the field takes focus when it is first drawn, as one a button has just shown does. */
  focusOnShow?: boolean;
  onSave: (value: string) => Promise<unknown>;
}) {
  const id = useId();
  const field = useRef<HTMLInputElement & HTMLTextAreaElement>(null);
  useEffect(() => {
    if (focusOnShow) field.current?.focus();
  }, [focusOnShow]);
  const [text, setText] = useState(value);
  const [focused, setFocused] = useState(false);
  const saver = useSaver(onSave);
  if (!focused && !saver.pending && value !== text) setText(value);
  const shared = {
    ref: field,
    id,
    value: text,
    placeholder,
    onFocus: () => setFocused(true),
    onBlur: () => {
      setFocused(false);
      saver.flush();
    },
  };
  return (
    <div className="field">
      <label htmlFor={id} className={hideLabel ? 'visually-hidden' : undefined}>
        {label}
      </label>
      {multiline ? (
        <textarea
          {...shared}
          rows={3}
          onChange={(event) => {
            setText(event.target.value);
            saver.change(event.target.value);
          }}
        />
      ) : (
        <input
          {...shared}
          type="text"
          onChange={(event) => {
            setText(event.target.value);
            saver.change(event.target.value);
          }}
        />
      )}
      {saver.failure && (
        <p className="error" role="alert">
          {saver.failure}
        </p>
      )}
    </div>
  );
}

/** A switch, as the note editor's Formatting is drawn. */
export function Switch({
  label,
  detail,
  checked,
  disabled,
  onChange,
}: {
  label: string;
  detail?: string;
  checked: boolean;
  disabled?: boolean;
  onChange: (on: boolean) => void;
}) {
  const detailId = useId();
  return (
    <div className="switch-row">
      <label className="switch">
        <ChosenCheckbox
          role="switch"
          checked={checked}
          disabled={disabled}
          aria-describedby={detail ? detailId : undefined}
          onChoose={onChange}
        />{' '}
        {label}
      </label>
      {detail && (
        <p id={detailId} className="note">
          {detail}
        </p>
      )}
    </div>
  );
}

export function CollectionSettings({ detail, onClose }: { detail: CollectionDetail; onClose: () => void }) {
  const client = useQueryClient();
  const headingId = useId();
  const depthId = useId();
  const promptId = useId();
  const tocId = useId();
  const introductionId = useId();
  const done = useRef<HTMLButtonElement>(null);
  const projects = useQuery(projectsQuery);
  const active = useActiveProjectId(projects.data);
  const project = projects.data?.items.find((item) => item.id === active);
  // The note's field, once shown, stays while the sheet is open, though its text is cleared.
  const [noteShown, setNoteShown] = useState<'held' | 'added' | null>((detail.note ?? '') !== '' ? 'held' : null);
  // An introduction the formatting editor cannot show as its text reads is edited plain.
  const [plainIntroduction, setPlainIntroduction] = useState<string | null>(null);
  const [failure, setFailure] = useState<string | null>(null);
  const introduction = useSaver((body: { text: string; runs: NoteRun[] | null }) =>
    updateCollection(client, detail.id, { introductionText: body.text, introductionRuns: body.runs }),
  );
  const words = copy.collectionSettings;
  // Summary only, which the server offers only where a document has a summary stored, and the collection does not hold.
  const summaryOnlyRefused = !detail.bodyDepths.includes('summaryOnly') && detail.defaultBodyDepth !== 'summaryOnly';

  async function change(changes: CollectionChanges) {
    setFailure(null);
    try {
      await updateCollection(client, detail.id, changes);
    } catch (error) {
      setFailure(errorMessage(error));
    }
  }

  async function preset(id: Parameters<typeof applyPreset>[2]) {
    setFailure(null);
    try {
      await applyPreset(client, detail.id, id);
    } catch (error) {
      setFailure(errorMessage(error));
    }
  }

  function close() {
    introduction.flush();
    onClose();
  }

  return (
    <Modal className="collection-settings" labelledBy={headingId} initial={done} onCancel={close} onClose={() => {}}>
      <div className="dialog-header">
        <h2 id={headingId} tabIndex={-1}>
          {words.title}
        </h2>
        <button ref={done} type="button" className="primary" onClick={close}>
          {words.done}
        </button>
      </div>
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      <section aria-labelledby={`${headingId}-name`}>
        <h3 id={`${headingId}-name`}>{words.nameHeader}</h3>
        <SavedText
          label={words.nameLabel}
          hideLabel
          value={detail.name}
          placeholder={words.namePlaceholder}
          onSave={(name) => updateCollection(client, detail.id, { name })}
        />
      </section>
      <section aria-labelledby={`${headingId}-note`}>
        <h3 id={`${headingId}-note`}>{words.noteHeader}</h3>
        {noteShown || (detail.note ?? '') !== '' ? (
          <SavedText
            label={words.noteLabel}
            hideLabel
            multiline
            focusOnShow={noteShown === 'added'}
            value={detail.note ?? ''}
            placeholder={words.notePlaceholder}
            onSave={(note) => updateCollection(client, detail.id, { note })}
          />
        ) : (
          // Named by the words it shows; the app's longer name is its hint.
          <button type="button" title={words.addNoteLabel} onClick={() => setNoteShown('added')}>
            {words.addNote}
          </button>
        )}
      </section>
      <section aria-labelledby={`${headingId}-front`}>
        <h3 id={`${headingId}-front`}>{words.frontMatterHeader}</h3>
        <SavedText
          label={words.subtitleLabel}
          hideLabel
          value={detail.subtitle ?? ''}
          placeholder={words.subtitlePlaceholder}
          onSave={(subtitle) => updateCollection(client, detail.id, { subtitle })}
        />
        {/* The project's name as a suggestion only, never saved unless typed. */}
        <SavedText
          label={words.authorLabel}
          hideLabel
          value={detail.authorLine ?? ''}
          placeholder={project && project.name !== '' ? project.name : words.authorPlaceholder}
          onSave={(authorLine) => updateCollection(client, detail.id, { authorLine })}
        />
        <div className="field">
          <p id={introductionId} className="field-label">
            {words.introduction}
          </p>
          {plainIntroduction !== null ? (
            <>
              <p className="note">{words.introductionUnreadable}</p>
              <textarea
                id={`${introductionId}-text`}
                className="note-body plain"
                aria-label={words.introduction}
                value={plainIntroduction}
                rows={5}
                // Typed plain, the formatting goes, as the note editor's plain field drops it.
                onChange={(event) => {
                  const value = event.target.value.replace(/\0/g, ' ');
                  setPlainIntroduction(value);
                  introduction.change({ text: value, runs: null });
                }}
              />
            </>
          ) : (
            <>
              {detail.introductionFormattingKept && <p className="note">{words.introductionKept}</p>}
              <EditorBoundary>
                <Suspense fallback={<p role="status">{words.introductionLoading}</p>}>
                  <RichTextEditor
                    id={`${introductionId}-text`}
                    label={words.introduction}
                    runs={detail.introductionRuns ?? null}
                    text={detail.introductionText ?? ''}
                    autoFocus={false}
                    onChange={(runs) => introduction.change({ text: runsText(runs), runs })}
                    onDiscard={close}
                    onUnreadable={() => setPlainIntroduction(detail.introductionText ?? '')}
                  />
                </Suspense>
              </EditorBoundary>
            </>
          )}
          {introduction.failure && (
            <p className="error" role="alert">
              {introduction.failure}
            </p>
          )}
        </div>
        <Switch label={words.colophon} checked={detail.includeColophon} onChange={(on) => void change({ includeColophon: on })} />
        <Switch
          label={words.projectProvenance}
          checked={detail.includeProjectProvenance}
          onChange={(on) => void change({ includeProjectProvenance: on })}
        />
        <Switch
          label={words.methodAppendix}
          detail={words.methodAppendixDetail}
          checked={detail.includeMethodAppendix}
          onChange={(on) => void change({ includeMethodAppendix: on })}
        />
        <p className="note">{words.frontMatterFooter}</p>
      </section>
      <section aria-labelledby={`${headingId}-presets`}>
        <h3 id={`${headingId}-presets`}>{words.presetsHeader}</h3>
        <p id={`${headingId}-preset-hint`} className="visually-hidden">
          {words.presetHint}
        </p>
        <div className="preset-grid">
          {detail.presets.map((offered) => (
            <button
              key={offered.id}
              type="button"
              className={`preset-card${offered.active ? ' active' : ''}`}
              aria-pressed={offered.active}
              aria-describedby={`${headingId}-preset-hint`}
              onClick={() => void preset(offered.id)}
            >
              <span className="preset-name">{words.presets[offered.id].name}</span>
              <span className="preset-subtitle">{words.presets[offered.id].subtitle}</span>
            </button>
          ))}
        </div>
      </section>
      <section aria-labelledby={`${headingId}-content`}>
        <h3 id={`${headingId}-content`}>{words.documentContent}</h3>
        <p className="note">{words.documentContentHelp}</p>
        <div className="field">
          <label htmlFor={depthId}>{words.bodyDepth}</label>
          <ChosenSelect
            id={depthId}
            value={detail.defaultBodyDepth}
            aria-describedby={summaryOnlyRefused ? `${depthId}-reason` : undefined}
            onChoose={(defaultBodyDepth) => void change({ defaultBodyDepth })}
          >
            {bodyDepthChoices(detail.bodyDepths, detail.defaultBodyDepth).map(({ depth, disabled }) => (
              <option key={depth} value={depth} disabled={disabled}>
                {words.bodyDepths[depth] ?? depth}
              </option>
            ))}
          </ChosenSelect>
          {summaryOnlyRefused && (
            <p id={`${depthId}-reason`} className="note">
              {words.summaryOnlyUnavailable} {words.summaryOnlyReason}
            </p>
          )}
        </div>
        {detail.defaultBodyDepth === 'summaryOnly' && (
          <div className="field">
            <label htmlFor={promptId}>{words.summaryPrompt}</label>
            <ChosenSelect
              id={promptId}
              value={detail.summaryPromptId ?? ''}
              aria-describedby={`${promptId}-hint`}
              onChoose={(value) => void change({ summaryPromptId: value === '' ? null : value })}
            >
              <option value="">{words.summaryPromptNone}</option>
              {detail.prompts.map((prompt) => (
                <option key={prompt.id} value={prompt.id}>
                  {prompt.name}
                </option>
              ))}
            </ChosenSelect>
            <p id={`${promptId}-hint`} className="note">
              {words.summaryPromptHint}
            </p>
          </div>
        )}
        <Switch label={words.footnotes} checked={detail.includeFootnotes} onChange={(on) => void change({ includeFootnotes: on })} />
        <Switch label={words.sourceNote} checked={detail.includeSourceNote} onChange={(on) => void change({ includeSourceNote: on })} />
      </section>
      <section aria-labelledby={`${headingId}-annotations`}>
        <h3 id={`${headingId}-annotations`}>{words.annotations}</h3>
        <p className="note">{words.annotationsHelp}</p>
        <Switch label={words.notes} checked={detail.includeNotes} onChange={(on) => void change({ includeNotes: on })} />
        <Switch
          label={words.highlights}
          checked={detail.applyHighlights}
          disabled={detail.defaultBodyDepth !== 'full'}
          onChange={(on) => void change({ applyHighlights: on })}
        />
        <Switch label={words.headnotes} checked={detail.defaultIncludeHeadnote} onChange={(on) => void change({ defaultIncludeHeadnote: on })} />
      </section>
      <section aria-labelledby={`${headingId}-analysis`}>
        <h3 id={`${headingId}-analysis`}>{words.analysis}</h3>
        <p className="note">{words.analysisHelp}</p>
        <Switch label={words.wordCloud} checked={detail.includeWordCloud} onChange={(on) => void change({ includeWordCloud: on })} />
        <div className="field">
          <label htmlFor={tocId}>{words.tocStyle}</label>
          <ChosenSelect id={tocId} value={detail.tocStyle} onChoose={(tocStyle) => void change({ tocStyle })}>
            {tocStyles.map((style) => (
              <option key={style} value={style}>
                {words.tocStyles[style]}
              </option>
            ))}
          </ChosenSelect>
        </div>
      </section>
      <SmartCollectionRows detail={detail} />
    </Modal>
  );
}

/**
 * The Smart Collection rows, last in the iPad's sheet: a linked collection's search, or Saved search not
 * found, with Unlink and what the link does (`SmartCollectionLinkRows`); else Link to Saved Search…, dimmed
 * with the app's line when no search is saved (`SmartCollectionLinkButton`), which opens the picker. Focus
 * goes to the row that takes the pressed one's place once the change is answered.
 */
function SmartCollectionRows({ detail }: { detail: CollectionDetail }) {
  const client = useQueryClient();
  const headingId = useId();
  const searches = useQuery(savedSearchesQuery);
  const [picking, setPicking] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const linkButton = useRef<HTMLButtonElement>(null);
  const unlinkButton = useRef<HTMLButtonElement>(null);
  const words = copy.collectionSettings;
  const held = searches.data?.items ?? [];

  async function link(savedSearchId: string | null) {
    setPicking(false);
    setFailure(null);
    try {
      await linkSavedSearch(client, detail.id, savedSearchId);
      requestAnimationFrame(() => (savedSearchId ? unlinkButton : linkButton).current?.focus());
    } catch (error) {
      setFailure(errorMessage(error));
    }
  }

  return (
    <section aria-labelledby={`${headingId}-smart`}>
      <h3 id={`${headingId}-smart`}>{words.smartHeader}</h3>
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      {detail.savedSearchId ? (
        <>
          <div className="smart-link">
            <p className={detail.savedSearchName === undefined ? 'note' : undefined}>{detail.savedSearchName ?? words.smartMissing}</p>
            <button ref={unlinkButton} type="button" className="destructive" onClick={() => void link(null)}>
              {words.smartUnlink}
            </button>
          </div>
          <p className="note">{detail.savedSearchName === undefined ? words.smartMissingExplanation : words.smartExplanation}</p>
        </>
      ) : (
        <>
          {/* aria-disabled, not disabled, so that the line under it is reached with it. */}
          <button
            ref={linkButton}
            type="button"
            aria-disabled={held.length === 0}
            aria-describedby={searches.data && held.length === 0 ? `${headingId}-none` : undefined}
            onClick={() => held.length > 0 && setPicking(true)}
          >
            {words.smartLink}
          </button>
          {searches.data && held.length === 0 && (
            <p id={`${headingId}-none`} className="note">
              {words.smartNoSearches}
            </p>
          )}
        </>
      )}
      {picking && (
        <LinkSavedSearchPicker
          searches={held}
          onLink={(id) => void link(id)}
          onCancel={() => {
            setPicking(false);
            requestAnimationFrame(() => linkButton.current?.focus());
          }}
        />
      )}
    </section>
  );
}

/** `LinkSavedSearchPicker`: the saved searches, newest first, each its name over its words, and Cancel. */
function LinkSavedSearchPicker({
  searches,
  onLink,
  onCancel,
}: {
  searches: readonly SavedSearch[];
  onLink: (id: string) => void;
  onCancel: () => void;
}) {
  const headingId = useId();
  const words = copy.collectionSettings;
  return (
    <Modal className="link-saved-search" labelledBy={headingId} onCancel={onCancel} onClose={() => {}}>
      <h2 id={headingId} tabIndex={-1}>
        {words.smartPickerTitle}
      </h2>
      <ul className="saved-search-picker">
        {searches.map((search) => (
          <li key={search.id}>
            <button type="button" onClick={() => onLink(search.id)}>
              <span className="search-name">{search.name}</span>
              {search.queryText !== '' && <span className="meta">{search.queryText}</span>}
            </button>
          </li>
        ))}
      </ul>
      <div className="dialog-actions">
        <button type="button" onClick={onCancel}>
          {words.smartPickerCancel}
        </button>
      </div>
    </Modal>
  );
}
