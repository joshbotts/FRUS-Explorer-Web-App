// A collection's editor (PLAN's S18d), as the app's iPad editor lays it out: its name over the toolbar's
// Add menu, Sort by Date, Collection settings and Export…; Contents, the outline the kit derives, three
// deep, each row the app's, a collapsed heading hiding its section, with Add Documents… under it; and,
// since S18e, the live preview beside it, the collection as its HTML export renders it. Narrower than
// 900 px the two are the iPhone's Outline | Preview. A smart collection says what it is first and takes
// nothing by hand but its apparatus.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { getRouteApi } from '@tanstack/react-router';
import { useEffect, useId, useRef, useState, useSyncExternalStore } from 'react';
import { errorMessage } from '../api/client';
import {
  addBlock,
  collectionGone,
  collectionQuery,
  deleteEntry,
  deleteSection,
  generatedBlockTypes,
  indentSection,
  moveEntryBy,
  sortByDate,
  updateEntry,
  type CollectionDetail,
  type CollectionEntry,
} from '../api/collections';
import { copy } from '../copy';
import { useHeadingReady } from '../shell/headingFocus';
import { closeAtOnce, Modal } from '../shell/Modal';
import { MenuButton } from '../shell/MenuButton';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import { AddDocuments } from './AddDocuments';
import { AddHighlights } from './AddHighlights';
import { CollectionExportSheet } from './CollectionExportSheet';
import { CollectionPreview } from './CollectionPreview';
import { CollectionSettings } from './CollectionSettings';
import { canMoveDown, contentsRows, moveDown, moveRequest, moveUp, outlineSteps, type ContentsRow } from './collectionRules';
import { EntryInspector } from './EntryInspector';
import { DocumentRow, ExcerptRow, GeneratedRow, HeadingRow, ProseRow, type RowActions, UnrecognizedRow } from './EntryRows';

const route = getRouteApi('/collections/$collectionId');

/** Below the width the iPad's two columns need, the iPhone's one pane at a time, as the reader's rail goes. */
const narrowQuery = '(max-width: 899.98px)';

function subscribeToWidth(onChange: () => void): () => void {
  const list = window.matchMedia?.(narrowQuery);
  list?.addEventListener('change', onChange);
  return () => list?.removeEventListener('change', onChange);
}

export function CollectionEditorScreen() {
  const { collectionId } = route.useParams();
  const query = useQuery(collectionQuery(collectionId));
  const gone = collectionGone(query.error);
  const detail = query.data;
  const title = gone ? copy.collectionEditor.unavailableTitle : (detail?.listName ?? copy.collections.title);
  useDocumentTitle(title);
  useHeadingReady(!query.isPending);
  return (
    <section className="screen collection-editor">
      {/* Focused once it names the collection, not while it says Collections. */}
      <h1 tabIndex={-1} data-loading={query.isPending ? 'true' : undefined}>
        {title}
      </h1>
      {gone ? (
        <p>{copy.collectionEditor.unavailableDetail}</p>
      ) : query.isError ? (
        <p className="error" role="alert">
          {errorMessage(query.error)}
        </p>
      ) : !detail ? (
        <p role="status">{copy.collectionEditor.loading}</p>
      ) : (
        // Made again for another collection, so no state of one names another's entries.
        <Editor key={detail.id} detail={detail} />
      )}
    </section>
  );
}

function Editor({ detail }: { detail: CollectionDetail }) {
  const client = useQueryClient();
  const [collapsed, setCollapsed] = useState<ReadonlySet<string>>(new Set());
  const [dialog, setDialog] = useState<null | 'settings' | 'documents' | 'highlights' | 'export'>(null);
  // Render All, kept while the editor is open, as the app's editor keeps it across its panes.
  const [renderAll, setRenderAll] = useState(false);
  const narrow = useSyncExternalStore(subscribeToWidth, () => window.matchMedia?.(narrowQuery).matches ?? false, () => false);
  const [pane, setPane] = useState<'outline' | 'preview'>('outline');
  const [inspecting, setInspecting] = useState<string | null>(null);
  const [deletingSection, setDeletingSection] = useState<CollectionEntry | null>(null);
  const [focusEntry, setFocusEntry] = useState<string | null>(null);
  const [failure, setFailure] = useState<string | null>(null);
  const [said, setSaid] = useState<string | null>(null);
  const list = useRef<HTMLOListElement>(null);
  const addMenu = useRef<HTMLDivElement>(null);
  // What opened the dialog showing, which focus goes back to when it closes: Modal leaves that to us.
  const opener = useRef<HTMLElement | null>(null);
  const contentsId = useId();
  const entries = detail.entries;
  const rows = contentsRows(detail, collapsed);
  const hand = detail.takesHandAddedEntries;
  const documents = entries.filter((entry) => entry.kind === 'document');

  /** A change the editor makes, its refusal said above the outline. */
  async function run<T>(work: () => Promise<T>): Promise<T | undefined> {
    setFailure(null);
    try {
      return await work();
    } catch (error) {
      setFailure(errorMessage(error));
      return undefined;
    }
  }

  async function added(made: Promise<{ entryIds: string[] }>) {
    const answer = await run(() => made);
    if (answer?.entryIds[0]) setFocusEntry(answer.entryIds[0]);
  }

  function openDialog(which: 'settings' | 'documents' | 'highlights' | 'export') {
    opener.current = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    setDialog(which);
  }

  function closeDialog() {
    setDialog(null);
    requestAnimationFrame(() => opener.current?.focus());
  }

  /** Says `text` in the live region, again when it is what it last said. */
  function say(text: string) {
    setSaid(null);
    requestAnimationFrame(() => setSaid(text));
  }

  /** The row's menu button, focused. */
  function focusRowMenu(entryId: string) {
    list.current?.querySelector<HTMLElement>(`li[data-id="${CSS.escape(entryId)}"] .row-menu > button`)?.focus();
  }

  /**
   * Move Up or Move Down, worked out as it is sent, from the collection the moves before it left;
   * React places a moved row anew, which can take focus from its menu's button, so a focus the move
   * dropped goes back to it once the rows are drawn.
   */
  function move(entryId: string, direction: 'up' | 'down') {
    const held = collapsed;
    void run(async () => {
      const answer = await moveEntryBy(client, detail.id, (latest) => {
        const latestRows = contentsRows(latest, held);
        const at = latestRows.findIndex((row) => row.entry.id === entryId);
        if (at < 0) return null;
        const outline = direction === 'up' ? moveUp(latestRows, at, latest.entries.length) : moveDown(latestRows, latest.entries, at);
        return outline ? moveRequest(latest.entries, outline) : null;
      });
      requestAnimationFrame(() =>
        requestAnimationFrame(() => {
          if (document.activeElement === document.body) focusRowMenu(entryId);
        }),
      );
      return answer;
    });
  }

  /** After a row goes, focus goes to the next row's menu, else the one before, else the Add menu; never the removed row's. */
  function focusAfter(removedIds: readonly string[], pos: number) {
    requestAnimationFrame(() => {
      const menus = [...(list.current?.querySelectorAll<HTMLElement>('li[data-id] .row-menu > button') ?? [])].filter(
        (button) => !removedIds.includes(button.closest('li')?.dataset.id ?? ''),
      );
      (menus[pos] ?? menus[pos - 1] ?? addMenu.current?.querySelector('button'))?.focus();
    });
  }

  async function remove(entry: CollectionEntry, pos: number) {
    const answer = await run(() => deleteEntry(client, detail.id, entry.id));
    if (answer) focusAfter([entry.id], pos);
  }

  function actions(row: ContentsRow, pos: number): RowActions {
    const unrecognized = row.entry.kind === 'unrecognized';
    const id = row.entry.id;
    return {
      onMoveUp: unrecognized || !moveUp(rows, pos, entries.length) ? undefined : () => move(id, 'up'),
      onMoveDown: unrecognized || !canMoveDown(rows, entries, pos) ? undefined : () => move(id, 'down'),
      onRemove: unrecognized ? undefined : () => void remove(row.entry, pos),
      onChange: (changes) => updateEntry(client, detail.id, row.entry.id, changes),
    };
  }

  // A new entry a collapsed section hides asks nothing, so its row does not take focus when the
  // section is opened later.
  if (focusEntry && entries.some((entry) => entry.id === focusEntry) && !rows.some((row) => row.entry.id === focusEntry)) {
    setFocusEntry(null);
  }

  // Nor does one the narrow window's Preview hides with the whole outline: nothing there takes it.
  if (focusEntry && narrow && pane !== 'outline') setFocusEntry(null);

  // A new entry takes focus once it is drawn: a heading's title, a note block's editor.
  useEffect(() => {
    if (!focusEntry) return;
    const row = list.current?.querySelector<HTMLElement>(`li[data-id="${CSS.escape(focusEntry)}"]`);
    if (!row) return;
    // A heading's row and a note block's take it themselves; any other row's menu takes it.
    const kind = entries.find((entry) => entry.id === focusEntry)?.kind;
    if (kind !== 'heading' && kind !== 'prose') row.querySelector<HTMLElement>('.row-menu > button')?.focus();
    setFocusEntry(null);
  }, [focusEntry, entries]);

  const addEntries = [
    { kind: 'item' as const, label: copy.collectionEditor.addDocuments, onSelect: () => openDialog('documents'), disabled: !hand },
    { kind: 'separator' as const },
    {
      kind: 'item' as const,
      label: copy.collectionEditor.addHeading,
      onSelect: () => void added(addBlock(client, detail.id, { kind: 'heading' })),
      disabled: !hand,
    },
    {
      kind: 'item' as const,
      label: copy.collectionEditor.addProse,
      onSelect: () => void added(addBlock(client, detail.id, { kind: 'prose' })),
      disabled: !hand,
    },
    {
      kind: 'item' as const,
      label: copy.collectionEditor.addHighlights,
      onSelect: () => openDialog('highlights'),
      disabled: documents.length === 0 || !hand,
    },
    { kind: 'separator' as const },
    {
      kind: 'group' as const,
      label: copy.collectionEditor.apparatus,
      items: generatedBlockTypes.map((type) => ({
        label: copy.collectionEditor.blocks[type]!,
        onSelect: () => void added(addBlock(client, detail.id, { generatedBlockType: type })),
      })),
    },
  ];

  return (
    <>
      <div className="editor-toolbar">
        <div ref={addMenu}>
          <MenuButton label={copy.collectionEditor.add} accessibleLabel={copy.collectionEditor.addLabel} entries={addEntries}>
            <span aria-hidden="true">+</span> {copy.collectionEditor.add}
          </MenuButton>
        </div>
        <MenuButton
          label={copy.collectionEditor.sortByDate}
          entries={[
            {
              kind: 'item',
              label: copy.collectionEditor.sortWhole,
              hint: copy.collectionEditor.sortWholeHelp,
              disabled: entries.length === 0,
              onSelect: () => void run(() => sortByDate(client, detail.id, 'wholeCollection')),
            },
            {
              kind: 'item',
              label: copy.collectionEditor.sortSections,
              hint: copy.collectionEditor.sortSectionsHelp,
              disabled: entries.length === 0,
              onSelect: () => void run(() => sortByDate(client, detail.id, 'withinSections')),
            },
          ]}
        />
        <button type="button" onClick={() => openDialog('settings')}>
          {copy.collectionEditor.settings}
        </button>
        <button type="button" onClick={() => openDialog('export')}>
          {copy.collectionEditor.export}
        </button>
      </div>
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      <p className="visually-hidden" role="status">
        {said}
      </p>
      {narrow && (
        <fieldset className="pane-picker">
          <legend className="visually-hidden">{copy.collectionEditor.pane}</legend>
          {(['outline', 'preview'] as const).map((each) => (
            <label key={each}>
              <input type="radio" name={`${contentsId}-pane`} checked={each === pane} onChange={() => setPane(each)} />
              <span>{copy.collectionEditor[each]}</span>
            </label>
          ))}
        </fieldset>
      )}
      <div className="editor-panes">
        {(!narrow || pane === 'outline') && (
          <div className="editor-outline">
            <section className="contents" aria-labelledby={`${contentsId}-heading`}>
              <h2 id={`${contentsId}-heading`}>{copy.collectionEditor.contents}</h2>
              {!hand && <p className="smart-sentence">{copy.collections.smartSentence}</p>}
              {entries.length === 0 && hand && <p className="note">{copy.collectionEditor.empty}</p>}
              {rows.length > 0 && (
                <ol ref={list} id={contentsId} className="contents-list" aria-labelledby={`${contentsId}-heading`}>
                  {rows.map((row, pos) => {
                    const entry = row.entry;
                    const rowActions = actions(row, pos);
                    const hiddenCount = entry.kind === 'heading' ? Math.max(0, (entry.sectionEnd ?? row.index + 1) - row.index - 1) : 0;
                    return (
                      <li key={entry.id} data-id={entry.id} className={`contents-row indent-${outlineSteps(row)} kind-${entry.kind}`}>
                        {entry.kind === 'document' ? (
                          <DocumentRow entry={entry} collection={detail} actions={rowActions} onConfigure={() => setInspecting(entry.id)} />
                        ) : entry.kind === 'heading' ? (
                          <HeadingRow
                            entry={entry}
                            collection={detail}
                            actions={rowActions}
                            collapsed={collapsed.has(entry.id)}
                            hiddenCount={hiddenCount}
                            onToggle={() =>
                              setCollapsed((held) => {
                                const next = new Set(held);
                                if (next.has(entry.id)) next.delete(entry.id);
                                else next.add(entry.id);
                                return next;
                              })
                            }
                            onIndent={() => void run(() => indentSection(client, detail.id, entry.id, true))}
                            onOutdent={() => void run(() => indentSection(client, detail.id, entry.id, false))}
                            onDefaults={() => setInspecting(entry.id)}
                            onDeleteSection={() => setDeletingSection(entry)}
                            autoFocus={focusEntry === entry.id}
                          />
                        ) : entry.kind === 'prose' ? (
                          <ProseRow entry={entry} actions={rowActions} autoFocus={focusEntry === entry.id} />
                        ) : entry.kind === 'excerpt' ? (
                          <ExcerptRow entry={entry} actions={rowActions} />
                        ) : entry.kind === 'generated' ? (
                          <GeneratedRow entry={entry} collection={detail} actions={rowActions} />
                        ) : (
                          <UnrecognizedRow />
                        )}
                      </li>
                    );
                  })}
                </ol>
              )}
            </section>
            {hand && (
              <div className="add-documents">
                <button type="button" onClick={() => openDialog('documents')}>
                  {copy.collectionEditor.addDocuments}
                </button>
                <p className="note">{copy.collectionEditor.addDocumentsFooter}</p>
              </div>
            )}
          </div>
        )}
        {(!narrow || pane === 'preview') && (
          <CollectionPreview detail={detail} renderAll={renderAll} onRenderAll={() => setRenderAll(true)} />
        )}
      </div>
      {dialog === 'settings' && <CollectionSettings detail={detail} onClose={closeDialog} />}
      {dialog === 'export' && <CollectionExportSheet detail={detail} onClose={closeDialog} />}
      {dialog === 'documents' && (
        <AddDocuments
          detail={detail}
          onClose={(count) => {
            closeDialog();
            if (count) say(count === 1 ? copy.collectionEditor.addedOne : copy.collectionEditor.addedMany(count));
          }}
        />
      )}
      {dialog === 'highlights' && <AddHighlights detail={detail} onClose={closeDialog} />}
      {inspecting && (
        <EntryInspector
          detail={detail}
          entryId={inspecting}
          onClose={() => {
            const id = inspecting;
            setInspecting(null);
            requestAnimationFrame(() =>
              list.current?.querySelector<HTMLElement>(`li[data-id="${CSS.escape(id)}"] button.configure`)?.focus(),
            );
          }}
        />
      )}
      {deletingSection && (
        <DeleteSection
          count={Math.max(0, (deletingSection.sectionEnd ?? 0) - entries.findIndex((entry) => entry.id === deletingSection.id) - 1)}
          onClose={async (confirmed) => {
            const heading = deletingSection;
            setDeletingSection(null);
            if (!confirmed) {
              requestAnimationFrame(() => focusRowMenu(heading.id));
              return;
            }
            const at = rows.findIndex((row) => row.entry.id === heading.id);
            const start = entries.findIndex((entry) => entry.id === heading.id);
            const removed = entries.slice(start, heading.sectionEnd ?? start + 1).map((entry) => entry.id);
            const answer = await run(() => deleteSection(client, detail.id, heading.id));
            // Refused, the heading stays, and its menu takes focus back.
            if (answer) focusAfter(removed, at);
            else requestAnimationFrame(() => focusRowMenu(heading.id));
          }}
        />
      )}
    </>
  );
}

/** The heading's Delete Section question, the app's. */
function DeleteSection({ count, onClose }: { count: number; onClose: (confirmed: boolean) => void }) {
  const headingId = useId();
  const messageId = useId();
  const cancel = useRef<HTMLButtonElement>(null);
  return (
    <Modal
      className="confirm"
      role="alertdialog"
      labelledBy={headingId}
      describedBy={messageId}
      initial={cancel}
      onCancel={() => onClose(false)}
      onClose={() => {}}
    >
      <h2 id={headingId} tabIndex={-1}>
        {copy.collectionEditor.deleteSectionTitle}
      </h2>
      <p id={messageId}>{copy.collectionEditor.deleteSectionMessage(count)}</p>
      <div className="dialog-actions">
        <button ref={cancel} type="button" onClick={() => onClose(false)}>
          {copy.collectionEditor.deleteSectionCancel}
        </button>
        <button type="button" className="destructive" onClick={() => closeAtOnce(() => onClose(true))}>
          {copy.collectionEditor.deleteSectionAction}
        </button>
      </div>
    </Modal>
  );
}
