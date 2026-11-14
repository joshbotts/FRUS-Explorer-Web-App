// A volume's Sources outline (PLAN's S22d), on Browse's page for a Sources section, as the app's Browse opens
// `VolumeSourcesView` for one. About These Sources, the section's narrative paragraphs; Archival Collections,
// the outline the index's rows nest into by their depths, every branch open at first, as the app opens them,
// with Expand All or Collapse All where a branch has rows beneath it; each row's text, in bold for a major named
// collection, its link to the catalogue record the kit resolves it to, the editors' note and the file series and
// HMS/MLR entry numbers; and Published Sources, plain rows. The rows' Archival Neighbors button and count, their
// collection and cross-volume links and their line for a lot NARA divides read kit members still internal at
// this pin, and follow when those are public.
import { useQuery } from '@tanstack/react-query';
import { type ReactNode, useId, useMemo, useState } from 'react';
import { errorMessage } from '../api/client';
import { type OutlineRow, volumeSourcesQuery } from '../api/sources';
import { copy } from '../copy';

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
  return <Outline rows={outline.data.rows} />;
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

export function Outline({ rows }: { rows: OutlineRow[] }) {
  const prose = rows.filter((row) => row.kind === 'prose');
  const bibliography = rows.filter((row) => row.kind === 'bibliography');
  const tree = useMemo(() => buildTree(rows.filter((row) => row.kind === 'item')), [rows]);
  const expandable = useMemo(() => expandableIDs(tree), [tree]);
  // Every branch open at first, as the published Sources page reads.
  const [expanded, setExpanded] = useState<Set<number>>(() => new Set(expandable));
  const allExpanded = expandable.size > 0 && [...expandable].every((id) => expanded.has(id));
  const toggle = (id: number) =>
    setExpanded((open) => {
      const next = new Set(open);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });

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
          <Nodes nodes={tree} expanded={expanded} toggle={toggle} />
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
    </div>
  );
}

function Nodes({
  nodes,
  expanded,
  toggle,
  id,
  hidden,
}: {
  nodes: SourceNode[];
  expanded: Set<number>;
  toggle: (id: number) => void;
  id?: string;
  hidden?: boolean;
}) {
  return (
    <ul className="vs-tree" id={id} hidden={hidden}>
      {nodes.map((node) => (
        <Node key={node.id} node={node} expanded={expanded} toggle={toggle} />
      ))}
    </ul>
  );
}

function Node({ node, expanded, toggle }: { node: SourceNode; expanded: Set<number>; toggle: (id: number) => void }) {
  const textId = useId();
  const listId = useId();
  const { row, children } = node;
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
            {row.catalogURL && (
              <a className="se-link vs-catalog" href={row.catalogURL} target="_blank" rel="noopener noreferrer" title={words.catalogHelp}>
                {words.catalog}
              </a>
            )}
          </p>
          {row.note && <p className="se-caption vs-note">{row.note}</p>}
          {row.seriesTitle && <p className="se-caption">{words.fileSeries(row.seriesTitle)}</p>}
          {numbers && <p className="se-caption">{numbers}</p>}
        </div>
      </div>
      {children && <Nodes nodes={children} expanded={expanded} toggle={toggle} id={listId} hidden={!open} />}
    </li>
  );
}
