// A volume's Sources outline (PLAN's S22d and its follow-up), on Browse's page for a Sources section, as the app's
// Browse opens `VolumeSourcesView` for one. About These Sources, the section's narrative paragraphs; Archival
// Collections, the outline the index's rows nest into by their depths, every branch open at first, as the app opens
// them, with Expand All or Collapse All where a branch has rows beneath it; and Published Sources, plain rows. Each
// outline row, as the view's `sourceNodeRow` draws it: its text, in bold for a major named collection, its link to
// the catalogue record the kit resolves it to, and its Archival Neighbors button with the count of indexed
// documents its keys match, plain while the count is unknown and quiet for none; beneath, the editors' note, the
// line for a lot NARA divides, the file series and HMS/MLR entry numbers; and its link to the collection's record,
// or, for a heading the authority has no record for, its Cited in N volumes, which opens the Cross-Volume Provenance
// list, the app's sheet, as a dialog. What each row carries is the server's, from the kit.
import { useQuery } from '@tanstack/react-query';
import { Link } from '@tanstack/react-router';
import { type ReactNode, useId, useMemo, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import { type OutlineNeighbours, type OutlineRow, volumeSourcesQuery } from '../api/sources';
import { copy } from '../copy';
import { Modal } from '../shell/Modal';
import { neighboursLabel } from './sourcesRules';

const words = copy.volumeSources;

/** A row of the outline with the rows beneath it (`SourceTreeNode`), named by its place among the outline's rows. */
export interface SourceNode {
  id: number;
  row: OutlineRow;
  children?: SourceNode[];
}

/**
 * The outline from its rows in the volume's order (`VolumeSourcesView.buildTree(_:)`): each row takes the rows
 * after it that are deeper as its own, and a row deeper than its place allows is kept at that place rather than
 * dropped.
 */
export function buildTree(rows: OutlineRow[]): SourceNode[] {
  let index = 0;
  const build = (depth: number): SourceNode[] => {
    const nodes: SourceNode[] = [];
    while (index < rows.length) {
      const row = rows[index] as OutlineRow;
      if (row.depth < depth) break;
      const id = index;
      index += 1;
      const children = build(row.depth + 1);
      nodes.push(children.length > 0 ? { id, row, children } : { id, row });
    }
    return nodes;
  };
  return build(0);
}

/** The rows with rows beneath them, at any depth (`VolumeSourcesView.expandableIDs(_:)`). */
export function expandableIDs(nodes: SourceNode[]): Set<number> {
  const ids = new Set<number>();
  const walk = (list: SourceNode[]) => {
    for (const node of list) {
      if (!node.children?.length) continue;
      ids.add(node.id);
      walk(node.children);
    }
  };
  walk(nodes);
  return ids;
}

export function VolumeSourcesOutline({ volumeId }: { volumeId: string }) {
  const outline = useQuery(volumeSourcesQuery(volumeId));
  if (outline.isPending) return <p role="status">{words.loading}</p>;
  if (outline.isError) {
    return (
      <p className="error" role="alert">
        {errorMessage(outline.error)}
      </p>
    );
  }
  if (outline.data.rows.length === 0) {
    return (
      <div className="vs-empty">
        <h2>{words.empty}</h2>
        <p>{words.emptyDetail}</p>
      </div>
    );
  }
  return <Outline volumeId={volumeId} rows={outline.data.rows} />;
}

/** A heading's volumes, as the Cross-Volume Provenance sheet lists them, and the control that opened it. */
interface CrossVolumeList {
  title: string;
  volumes: { volumeId: string; title?: string }[];
  opener: HTMLElement;
}

function Group({ title, action, children }: { title: string; action?: ReactNode; children: ReactNode }) {
  const id = useId();
  return (
    <section className="se-section vs-group" aria-labelledby={id}>
      <div className="se-section-heading">
        <h2 id={id}>{title}</h2>
        {action}
      </div>
      {children}
    </section>
  );
}

export function Outline({ volumeId, rows }: { volumeId: string; rows: OutlineRow[] }) {
  const prose = rows.filter((row) => row.kind === 'prose');
  const bibliography = rows.filter((row) => row.kind === 'bibliography');
  const tree = useMemo(() => buildTree(rows.filter((row) => row.kind === 'item')), [rows]);
  const expandable = useMemo(() => expandableIDs(tree), [tree]);
  // Every branch open at first, as the published Sources page reads.
  const [expanded, setExpanded] = useState<Set<number>>(() => new Set(expandable));
  const [crossVolume, setCrossVolume] = useState<CrossVolumeList | null>(null);
  const allExpanded = expandable.size > 0 && [...expandable].every((id) => expanded.has(id));
  const toggle = (id: number) =>
    setExpanded((open) => {
      const next = new Set(open);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  const row: RowContext = { volumeId, expanded, toggle, openCrossVolume: setCrossVolume };

  return (
    <div className="vs-outline">
      {prose.length > 0 && (
        <Group title={words.about}>
          {prose.map((row, index) => (
            <p key={index} className="vs-prose">
              {row.text}
            </p>
          ))}
        </Group>
      )}
      {tree.length > 0 && (
        <Group
          title={words.collections}
          action={
            // Only where there is something to open: a flat outline offers no control that does nothing.
            expandable.size > 0 && (
              <button
                type="button"
                className="link-button"
                onClick={() => setExpanded(allExpanded ? new Set() : new Set(expandable))}
              >
                {allExpanded ? words.collapseAll : words.expandAll}
              </button>
            )
          }
        >
          <Nodes nodes={tree} context={row} />
        </Group>
      )}
      {bibliography.length > 0 && (
        <Group title={words.bibliography}>
          <ul className="vs-plain">
            {bibliography.map((row, index) => (
              <li key={index}>{row.text}</li>
            ))}
          </ul>
        </Group>
      )}
      {crossVolume && (
        <CrossVolumeDialog
          list={crossVolume}
          onClose={() => {
            const { opener } = crossVolume;
            setCrossVolume(null);
            // Back to the row's Cited in N volumes, once the page is no longer inert.
            requestAnimationFrame(() => opener.focus());
          }}
        />
      )}
    </div>
  );
}

/** What every row of the outline reads: its volume, the open branches, and the dialog a heading's volumes open in. */
interface RowContext {
  volumeId: string;
  expanded: Set<number>;
  toggle: (id: number) => void;
  openCrossVolume: (list: CrossVolumeList) => void;
}

function Nodes({ nodes, context, id, hidden }: { nodes: SourceNode[]; context: RowContext; id?: string; hidden?: boolean }) {
  return (
    <ul className="vs-tree" id={id} hidden={hidden}>
      {nodes.map((node) => (
        <Node key={node.id} node={node} context={context} />
      ))}
    </ul>
  );
}

/**
 * A row's Archival Neighbors button (`VolumeSourcesView`'s three-state affordance): its count of indexed documents
 * once known, quiet for none, as the neighbours' page lists them for the row's keys on This volume, with the record
 * whose names the matcher falls back on.
 */
function NeighboursLink({ volumeId, neighbours }: { volumeId: string; neighbours: OutlineNeighbours }) {
  const { count } = neighbours;
  return (
    <Link
      className={count === 0 ? 'se-link vs-neighbours vs-none' : 'se-link vs-neighbours'}
      to="/archival-neighbors"
      search={{
        lotFile: neighbours.lotFile,
        recordGroup: neighbours.recordGroup,
        series: neighbours.series,
        repository: neighbours.repository,
        decimalClass: neighbours.decimalClass,
        jobNumber: neighbours.jobNumber,
        aliasCollection: neighbours.aliasCollection,
        anchor: volumeId,
      }}
      aria-label={neighboursLabel(count)}
      title={count === 0 ? words.neighboursZeroHelp : words.neighboursHelp}
    >
      {words.neighbours}
      {count !== undefined && <span className="vs-count">{count.toLocaleString('en-US')}</span>}
    </Link>
  );
}

/**
 * The Cross-Volume Provenance sheet (`VolumeSourcesCrossVolumeSheet`): the volumes whose Sources sections cite a
 * heading the authority has no record for, each opening its volume, under the heading's own text, and Done.
 */
function CrossVolumeDialog({ list, onClose }: { list: CrossVolumeList; onClose: () => void }) {
  const headingId = useId();
  const listId = useId();
  return (
    <Modal className="cross-volume" labelledBy={headingId} onCancel={onClose} onClose={onClose}>
      <h2 id={headingId} tabIndex={-1}>
        {words.crossVolumeTitle}
      </h2>
      <section aria-labelledby={listId}>
        <h3 id={listId}>{words.crossVolumeHeader}</h3>
        <ul className="se-volumes">
          {list.volumes.map((volume) => (
            <li key={volume.volumeId}>
              <Link to="/browse/$volumeId" params={{ volumeId: volume.volumeId }} title={words.volumeHint}>
                {volume.title ?? volume.volumeId}
              </Link>
              <p className="se-dates">{volume.volumeId}</p>
            </li>
          ))}
        </ul>
        <p className="se-caption">{list.title}</p>
      </section>
      <div className="actions">
        <button type="button" onClick={onClose}>
          {words.done}
        </button>
      </div>
    </Modal>
  );
}

function Node({ node, context }: { node: SourceNode; context: RowContext }) {
  const textId = useId();
  const listId = useId();
  const crossVolumeButton = useRef<HTMLButtonElement>(null);
  const { row, children } = node;
  const { expanded, toggle, volumeId, openCrossVolume } = context;
  const open = expanded.has(node.id);
  const numbers = row.entryNumbers?.length
    ? words.entryNumbers(row.entryNumbers.join(', '))
    : row.seriesEntryNumbers?.length
      ? words.seriesEntryNumbers(row.seriesEntryNumbers.join(', '))
      : undefined;
  return (
    <li>
      <div className="vs-row">
        {children ? (
          // The disclosure, named by the row it opens.
          <button
            type="button"
            className="vs-toggle"
            aria-expanded={open}
            aria-controls={listId}
            aria-labelledby={textId}
            onClick={() => toggle(node.id)}
          >
            <span aria-hidden="true">{open ? '▾' : '▸'}</span>
          </button>
        ) : (
          <span className="vs-leaf" aria-hidden="true" />
        )}
        <div className="vs-entry">
          <p className="vs-line">
            <span id={textId} className={row.isHeading ? 'vs-text vs-heading' : 'vs-text'}>
              {row.text}
            </span>
            {(row.catalogURL || row.neighbours) && (
              <span className="vs-actions">
                {row.catalogURL && (
                  <a className="se-link vs-catalog" href={row.catalogURL} target="_blank" rel="noopener noreferrer" title={words.catalogHelp}>
                    {words.catalog}
                  </a>
                )}
                {row.neighbours && <NeighboursLink volumeId={volumeId} neighbours={row.neighbours} />}
              </span>
            )}
          </p>
          {row.note && <p className="se-caption vs-note">{row.note}</p>}
          {row.dividedSeriesCount !== undefined && <p className="se-caption">{words.divided(row.dividedSeriesCount)}</p>}
          {row.seriesTitle && <p className="se-caption">{words.fileSeries(row.seriesTitle)}</p>}
          {numbers && <p className="se-caption">{numbers}</p>}
          {row.collection ? (
            <p className="se-caption">
              <Link className="vs-collection" to="/archival-collection" search={{ id: row.collection.id }} title={words.collectionHint}>
                {words.collection(row.collection.volumeCount)}
              </Link>
            </p>
          ) : row.crossVolume ? (
            <p className="se-caption">
              <button
                ref={crossVolumeButton}
                type="button"
                className="link-button vs-collection"
                aria-haspopup="dialog"
                title={words.crossVolumeHint}
                onClick={() => {
                  const opener = crossVolumeButton.current;
                  if (row.crossVolume && opener) openCrossVolume({ title: row.text, volumes: row.crossVolume, opener });
                }}
              >
                {words.crossVolume(row.crossVolume.length)}
              </button>
            </p>
          ) : null}
        </div>
      </div>
      {children && <Nodes nodes={children} context={context} id={listId} hidden={!open} />}
    </li>
  );
}
