// The collection editor's rows (PLAN's S18d), as the app's `CollectionEntryRows` draws them: a section
// heading, its title edited in place, its chevron, Section defaults, its Section body and the section's
// menu; a document, a report of its identity and chips with Configure; a note block, its rich text
// edited in place; a frozen excerpt; an apparatus block; and an entry a newer build wrote, inert. Each
// row's menu, the web's way to the app's context menu, holds what the app's does, Move Up and Move
// Down among them, and the remove the app gives by a swipe or a trash button.
import { useNavigate } from '@tanstack/react-router';
import { Component, lazy, type ReactNode, Suspense, useEffect, useId, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import type { CollectionDetail, CollectionEntry, EntryChanges } from '../api/collections';
import type { NoteRun } from '../api/types';
import { copy } from '../copy';
import { runsText } from '../editor/runs';
import { MenuButton, type MenuEntry } from '../shell/MenuButton';
import { ChosenSelect } from './chosen';
import { bodyDepthChoices, entryChips, type EntryChip } from './collectionRules';
import { useSaver } from './useSaver';

const RichTextEditor = lazy(() => import('../editor/RichTextEditor'));

/** What a row can do, each absent where the app's row offers nothing. */
export interface RowActions {
  onMoveUp?: () => void;
  onMoveDown?: () => void;
  onRemove?: () => void;
  onChange: (changes: EntryChanges) => Promise<unknown>;
}

/**
 * The row's menu: what the row offers, then Move Up and Move Down, then its removes, Remove entry for
 * any row but a heading, whose two deletes the app's section menu gives.
 */
function RowMenu({ label, actions, before = [], removes }: { label: string; actions: RowActions; before?: MenuEntry[]; removes?: MenuEntry[] }) {
  const entries: MenuEntry[] = [...before];
  if (actions.onMoveUp || actions.onMoveDown) {
    if (entries.length > 0) entries.push({ kind: 'separator' });
    if (actions.onMoveUp) entries.push({ kind: 'item', label: copy.collectionEditor.moveUp, onSelect: actions.onMoveUp });
    if (actions.onMoveDown) entries.push({ kind: 'item', label: copy.collectionEditor.moveDown, onSelect: actions.onMoveDown });
  }
  const last = removes ?? (actions.onRemove ? [{ kind: 'item' as const, label: copy.collectionEditor.remove, onSelect: actions.onRemove, destructive: true }] : []);
  if (last.length > 0) {
    if (entries.length > 0) entries.push({ kind: 'separator' });
    entries.push(...last);
  }
  if (entries.length === 0) return null;
  return (
    <MenuButton className="row-menu" label={copy.collectionEditor.actions} accessibleLabel={`${copy.collectionEditor.actions}: ${label}`} entries={entries}>
      <span aria-hidden="true">⋯</span>
    </MenuButton>
  );
}

function chipText(chip: EntryChip): string {
  const words = copy.collectionEditor.chips;
  switch (chip.kind) {
    case 'bodyDepth':
      return words.bodyDepth[chip.depth] ?? chip.depth;
    case 'notesOff':
      return words.notesOff;
    case 'notes':
      return words.notes(chip.count);
    case 'highlightsOff':
      return words.highlightsOff;
    case 'headnote':
      return words.headnote;
    case 'seeAlso':
      return words.seeAlso;
  }
}

/** A document's row, a report (`EntryRow`): its header or id, its volume line, the duplicate badge and the chips, with Configure. */
export function DocumentRow({
  entry,
  collection,
  actions,
  onConfigure,
}: {
  entry: CollectionEntry;
  collection: CollectionDetail;
  actions: RowActions;
  onConfigure: () => void;
}) {
  const navigate = useNavigate();
  const title = entry.header ?? entry.documentId;
  const line = [entry.header ? entry.documentId : undefined, entry.volumeTitle ?? entry.volumeId, entry.dateISO].filter(Boolean).join(' · ');
  const chips = entryChips(entry, collection);
  return (
    <div className="entry document-entry" role="group" aria-label={copy.collectionEditor.documentLabel(title)}>
      <div className="entry-body">
        <p className="entry-title">{title}</p>
        <p className="meta">{line}</p>
        {entry.isDuplicate && <p className="badge-line">{copy.collectionEditor.duplicate}</p>}
        {chips.length > 0 && (
          <ul className="chips entry-chips">
            {chips.map((chip) => (
              <li key={chip.kind} className="chip">
                {chipText(chip)}
              </li>
            ))}
          </ul>
        )}
      </div>
      <div className="entry-actions">
        <button type="button" className="configure" aria-label={`${copy.collectionEditor.configure}: ${title}`} title={copy.collectionEditor.configureHint} onClick={onConfigure}>
          {copy.collectionEditor.configure}
        </button>
        <RowMenu
          label={title}
          actions={actions}
          before={[
            {
              kind: 'item',
              label: copy.collectionEditor.openDocument,
              onSelect: () =>
                void navigate({ to: '/doc/$volumeId/$documentId', params: { volumeId: entry.volumeId, documentId: entry.documentId } }),
            },
          ]}
        />
      </div>
    </div>
  );
}

/** A section heading's row (`CollectionHeadingRow`). */
export function HeadingRow({
  entry,
  collection,
  actions,
  collapsed,
  hiddenCount,
  onToggle,
  onIndent,
  onOutdent,
  onDefaults,
  onDeleteSection,
  autoFocus,
}: {
  entry: CollectionEntry;
  collection: CollectionDetail;
  actions: RowActions;
  collapsed: boolean;
  hiddenCount: number;
  onToggle: () => void;
  onIndent: () => void;
  onOutdent: () => void;
  onDefaults: () => void;
  onDeleteSection: () => void;
  autoFocus: boolean;
}) {
  const field = useRef<HTMLInputElement>(null);
  const bodyId = useId();
  // Summary only, which the server offers only where a document of the collection has a summary stored.
  const summaryOnlyRefused = !collection.bodyDepths.includes('summaryOnly') && entry.bodyDepthOverride !== 'summaryOnly';
  const [text, setText] = useState(entry.text ?? '');
  const [focused, setFocused] = useState(false);
  const [bodyFailure, setBodyFailure] = useState<string | null>(null);
  const saver = useSaver((value: string) => actions.onChange({ text: value }));
  // The title the server holds, while the field is not being typed in.
  if (!focused && !saver.pending && (entry.text ?? '') !== text) setText(entry.text ?? '');
  useEffect(() => {
    if (autoFocus) field.current?.focus();
  }, [autoFocus]);
  const title = text.trim() === '' ? copy.collectionEditor.headingPlaceholder : text;
  const level = Math.min(Math.max(entry.depth, 1), 3);
  // Rename, the menu's, puts focus in the title once the menu has gone.
  function rename() {
    requestAnimationFrame(() => field.current?.focus());
  }
  return (
    <div className={`entry heading-entry level-${level}`}>
      <div className="heading-line">
        <button
          type="button"
          className="chevron"
          aria-expanded={!collapsed}
          aria-label={collapsed ? copy.collectionEditor.expandSection : copy.collectionEditor.collapseSection}
          onClick={onToggle}
        >
          <span aria-hidden="true">{collapsed ? '▸' : '▾'}</span>
        </button>
        <span className="heading-mark" aria-hidden="true">
          #
        </span>
        <input
          ref={field}
          type="text"
          className="heading-title"
          value={text}
          placeholder={copy.collectionEditor.headingPlaceholder}
          aria-label={copy.collectionEditor.headingPlaceholder}
          onFocus={() => setFocused(true)}
          onBlur={() => {
            setFocused(false);
            saver.flush();
          }}
          onChange={(event) => {
            setText(event.target.value);
            saver.change(event.target.value);
          }}
        />
        {collapsed && hiddenCount > 0 && <span className="hidden-count">{copy.collectionEditor.hidden(hiddenCount)}</span>}
        <button type="button" className="configure" title={copy.collectionEditor.sectionDefaultsHelp} onClick={onDefaults}>
          {copy.collectionEditor.sectionDefaults}
        </button>
        <RowMenu
          label={title}
          actions={actions}
          before={[
            { kind: 'item', label: copy.collectionEditor.rename, onSelect: rename },
            { kind: 'item', label: copy.collectionEditor.sectionDefaultsMenu, onSelect: onDefaults },
            { kind: 'item', label: copy.collectionEditor.indent, onSelect: onIndent, disabled: !entry.canIndent },
            { kind: 'item', label: copy.collectionEditor.outdent, onSelect: onOutdent, disabled: !entry.canOutdent },
          ]}
          removes={[
            { kind: 'item', label: copy.collectionEditor.deleteHeadingOnly, onSelect: () => actions.onRemove?.(), destructive: true },
            { kind: 'item', label: copy.collectionEditor.deleteSection, onSelect: onDeleteSection, destructive: true },
          ]}
        />
      </div>
      <div className="section-body">
        <label htmlFor={bodyId}>{copy.collectionEditor.sectionBody}</label>
        <ChosenSelect
          id={bodyId}
          value={entry.bodyDepthOverride ?? ''}
          aria-describedby={summaryOnlyRefused ? `${bodyId}-reason` : undefined}
          onChoose={(chosen) => {
            setBodyFailure(null);
            actions
              .onChange({ bodyDepthOverride: chosen === '' ? null : chosen })
              .catch((error: unknown) => setBodyFailure(errorMessage(error)));
          }}
        >
          <option value="">{copy.collectionEditor.sectionBodyDefault}</option>
          {bodyDepthChoices(collection.bodyDepths, entry.bodyDepthOverride).map(({ depth, disabled }) => (
            <option key={depth} value={depth} disabled={disabled}>
              {copy.collectionSettings.bodyDepths[depth] ?? depth}
            </option>
          ))}
        </ChosenSelect>
        {/* Summary only, listed but not offered (S18f): the row is short, so its reason is the picker's description. */}
        {summaryOnlyRefused && (
          <span id={`${bodyId}-reason`} className="visually-hidden">
            {copy.collectionSettings.summaryOnlyUnavailable} {copy.collectionSettings.summaryOnlyReason}
          </span>
        )}
      </div>
      {(saver.failure ?? bodyFailure) && (
        <p className="error" role="alert">
          {saver.failure ?? bodyFailure}
        </p>
      )}
    </div>
  );
}

/** The editor's code, or, when it could not be loaded, nothing but its line. */
class EditorBoundary extends Component<{ children: ReactNode }, { failed: boolean }> {
  override state = { failed: false };

  static getDerivedStateFromError() {
    return { failed: true };
  }

  override render() {
    return this.state.failed ? <p className="error">{copy.collectionEditor.proseFailed}</p> : this.props.children;
  }
}

/** A note block's row (`CollectionProseRow`): its text at rest, at most six lines, and its editor in place. */
export function ProseRow({ entry, actions, autoFocus }: { entry: CollectionEntry; actions: RowActions; autoFocus: boolean }) {
  // A block the formatting editor cannot show as its text reads is edited plain, as a note is.
  const [plain, setPlain] = useState<string | null>(null);
  const plainField = useRef<HTMLTextAreaElement>(null);
  const [editing, setEditing] = useState(autoFocus);
  // A note block just added opens its editor, as the app's opens in place.
  const [asked, setAsked] = useState(autoFocus);
  if (autoFocus !== asked) {
    setAsked(autoFocus);
    if (autoFocus) setEditing(true);
  }
  const editorId = useId();
  const editButton = useRef<HTMLButtonElement>(null);
  const saver = useSaver((body: { text: string; runs: NoteRun[] | null }) => actions.onChange(body));
  const text = entry.text ?? '';
  const isPlain = plain !== null;
  useEffect(() => {
    if (isPlain) plainField.current?.focus();
  }, [isPlain]);
  const label = text.trim() === '' ? copy.collectionEditor.proseEmpty : text;
  return (
    <div className="entry prose-entry">
      {editing ? (
        <div className="prose-editor">
          {plain !== null ? (
            <>
              <p className="note">{copy.collectionEditor.proseUnreadable}</p>
              <textarea
                ref={plainField}
                id={editorId}
                className="note-body plain"
                aria-label={copy.collectionEditor.proseLabel}
                value={plain}
                rows={6}
                // Typed plain, the formatting goes, as the note editor's plain field drops it.
                onChange={(event) => {
                  const value = event.target.value.replace(/\0/g, ' ');
                  setPlain(value);
                  saver.change({ text: value, runs: null });
                }}
              />
            </>
          ) : (
            <>
              {entry.formattingKept && <p className="note">{copy.collectionEditor.proseKept}</p>}
              <EditorBoundary>
                <Suspense fallback={<p role="status">{copy.collectionEditor.proseLoading}</p>}>
                  <RichTextEditor
                    id={editorId}
                    label={copy.collectionEditor.proseLabel}
                    runs={entry.runs ?? null}
                    text={text}
                    autoFocus
                    onChange={(runs) => saver.change({ text: runsText(runs), runs })}
                    onDiscard={() => {
                      saver.flush();
                      setEditing(false);
                      requestAnimationFrame(() => editButton.current?.focus());
                    }}
                    onUnreadable={() => setPlain(text)}
                  />
                </Suspense>
              </EditorBoundary>
            </>
          )}
          <button
            type="button"
            onClick={() => {
              saver.flush();
              setEditing(false);
              setPlain(null);
              requestAnimationFrame(() => editButton.current?.focus());
            }}
          >
            {copy.collectionEditor.proseDone}
          </button>
        </div>
      ) : (
        <div className="entry-body">
          <p className={`prose-text${text.trim() === '' ? ' empty' : ''}`}>{label}</p>
        </div>
      )}
      <div className="entry-actions">
        {!editing && (
          <button ref={editButton} type="button" aria-label={`${copy.collectionEditor.proseEdit}: ${copy.collectionEditor.proseLabel}`} onClick={() => setEditing(true)}>
            {copy.collectionEditor.proseEdit}
          </button>
        )}
        <RowMenu label={copy.collectionEditor.proseLabel} actions={actions} />
      </div>
      {saver.failure && (
        <p className="error" role="alert">
          {saver.failure}
        </p>
      )}
    </div>
  );
}

/** A frozen excerpt's row (`CollectionExcerptRow`): its passage, its colour and its provenance. */
export function ExcerptRow({ entry, actions }: { entry: CollectionEntry; actions: RowActions }) {
  const text = entry.text ?? '';
  const provenance = [entry.documentId || undefined, entry.volumeTitle ?? (entry.volumeId || undefined)].filter(Boolean).join(' · ');
  const color = entry.excerptColorTag && ['yellow', 'green', 'blue', 'pink'].includes(entry.excerptColorTag) ? entry.excerptColorTag : null;
  return (
    <div className="entry excerpt-entry" aria-label={copy.collectionEditor.excerptLabel(entry.documentId, text)} role="group">
      <div className="entry-body">
        <blockquote className="excerpt-text">{text}</blockquote>
        <p className="meta">
          {color && <span className={`color-dot hl-${color}`} role="img" aria-label={copy.highlights.colors[color as 'yellow']} />}
          {provenance}
        </p>
      </div>
      <div className="entry-actions">
        <RowMenu label={copy.collectionEditor.excerptLabel(entry.documentId, text.slice(0, 40))} actions={actions} />
      </div>
    </div>
  );
}

/** An apparatus block's row (`CollectionGeneratedEntryRow`), with the documents a bibliography or chronology lists. */
export function GeneratedRow({ entry, collection, actions }: { entry: CollectionEntry; collection: CollectionDetail; actions: RowActions }) {
  const known = entry.generatedBlockType ? copy.collectionEditor.blocks[entry.generatedBlockType] : undefined;
  const title = known ?? copy.collectionEditor.generatedUnsupported;
  const counted =
    collection.takesHandAddedEntries && (entry.generatedBlockType === 'bibliography' || entry.generatedBlockType === 'chronology')
      ? `${copy.collectionEditor.generatedCount(collection.documentCount)} `
      : '';
  const caption = known ? `${counted}${copy.collectionEditor.generatedCaption}` : copy.collectionEditor.generatedUnsupportedDetail;
  return (
    <div className="entry generated-entry" role="group" aria-label={copy.collectionEditor.generatedLabel(title)}>
      <div className="entry-body">
        <p className="entry-title">{title}</p>
        <p className="meta">{caption}</p>
      </div>
      <div className="entry-actions">
        <RowMenu label={title} actions={actions} />
      </div>
    </div>
  );
}

/** An entry a newer build wrote (`UnrecognizedEntryRow`), which offers nothing. */
export function UnrecognizedRow() {
  return (
    <div className="entry unrecognized-entry">
      <div className="entry-body">
        <p className="entry-title">{copy.collectionEditor.unrecognizedTitle}</p>
        <p className="meta">{copy.collectionEditor.unrecognizedDetail}</p>
      </div>
    </div>
  );
}
