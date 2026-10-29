// A collection's editor (PLAN's S18d), as the app's iPad editor lays it out: its name over the toolbar's
// Add menu, Sort by Date and Collection settings; and Contents, the outline the kit derives, three deep,
// each row the app's, a collapsed heading hiding its section, with Add Documents… under it. A smart
// collection says what it is first and takes nothing by hand but its apparatus. The live preview
// beside the outline is S18e's, with the exports.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { getRouteApi } from '@tanstack/react-router';
import { useEffect, useId, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import {
  addBlock,
  collectionGone,
  collectionQuery,
  deleteEntry,
  deleteSection,
  generatedBlockTypes,
  indentSection,
  moveEntry,
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
import { CollectionSettings } from './CollectionSettings';
import { canMoveDown, contentsRows, moveDown, moveRequest, moveUp, outlineSteps, type ContentsRow, type OutlineMove } from './collectionRules';
import { EntryInspector } from './EntryInspector';
import { DocumentRow, ExcerptRow, GeneratedRow, HeadingRow, ProseRow, type RowActions, UnrecognizedRow } from './EntryRows';

const route = getRouteApi('/collections/$collectionId');

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
      <h1 tabIndex={-1}>{title}</h1>
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
  const [dialog, setDialog] = useState<null | 'settings' | 'documents' | 'highlights'>(null);
  const [inspecting, setInspecting] = useState<string | null>(null);
  const [deletingSection, setDeletingSection] = useState<CollectionEntry | null>(null);
  const [focusEntry, setFocusEntry] = useState<string | null>(null);
  const [failure, setFailure] = useState<string | null>(null);
  const [said, setSaid] = useState<string | null>(null);
  const list = useRef<HTMLOListElement>(null);
  const addMenu = useRef<HTMLDivElement>(null);
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

  function move(outline: OutlineMove | null) {
    if (!outline) return;
    const { entryId, before } = moveRequest(entries, outline);
    void run(() => moveEntry(client, detail.id, entryId, before));
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
    return {
      onMoveUp: unrecognized ? undefined : (moveUp(rows, pos, entries.length) ? () => move(moveUp(rows, pos, entries.length)) : undefined),
      onMoveDown: unrecognized || !canMoveDown(rows, entries, pos) ? undefined : () => move(moveDown(rows, entries, pos)),
      onRemove: unrecognized ? undefined : () => void remove(row.entry, pos),
      onChange: (changes) => updateEntry(client, detail.id, row.entry.id, changes),
    };
  }

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
    { kind: 'item' as const, label: copy.collectionEditor.addDocuments, onSelect: () => setDialog('documents'), disabled: !hand },
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
      onSelect: () => setDialog('highlights'),
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
        <button type="button" onClick={() => setDialog('settings')}>
          {copy.collectionEditor.settings}
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
          <button type="button" onClick={() => setDialog('documents')}>
            {copy.collectionEditor.addDocuments}
          </button>
          <p className="note">{copy.collectionEditor.addDocumentsFooter}</p>
        </div>
      )}
      {dialog === 'settings' && <CollectionSettings detail={detail} onClose={() => setDialog(null)} />}
      {dialog === 'documents' && (
        <AddDocuments
          detail={detail}
          onClose={(count) => {
            setDialog(null);
            if (count) setSaid(count === 1 ? copy.collectionEditor.addedOne : copy.collectionEditor.addedMany(count));
          }}
        />
      )}
      {dialog === 'highlights' && <AddHighlights detail={detail} onClose={() => setDialog(null)} />}
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
              requestAnimationFrame(() =>
                list.current?.querySelector<HTMLElement>(`li[data-id="${CSS.escape(heading.id)}"] .row-menu > button`)?.focus(),
              );
              return;
            }
            const at = rows.findIndex((row) => row.entry.id === heading.id);
            const start = entries.findIndex((entry) => entry.id === heading.id);
            const removed = entries.slice(start, heading.sectionEnd ?? start + 1).map((entry) => entry.id);
            const answer = await run(() => deleteSection(client, detail.id, heading.id));
            if (answer) focusAfter(removed, at);
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
