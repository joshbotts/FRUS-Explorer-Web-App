// The cross-reference graph (PLAN's S23e), at /graph/{volumeId}/{documentId}, which the reader's Graph
// opens: the app's `CrossReferenceGraphView` as a page. Its toolbar's layout, Timeline or Network, and
// depth, one to three hops, with the app's note when a sparse graph was widened; the app's banner when
// volumes the server does not serve cite the document; the canvas, Cytoscape.js drawing the server's
// nodes and edges at the timeline's places from the kit or the network's from the app's layout; its
// legend; and beside it the app's reference list panel, the details of the node or edge selected over
// the reference list's three sections, every document the graph draws, which is the canvas's text. The
// graph, its clusters, dates, timeline and order are the kit's, on the server. The web's own: the
// degree, the layout and the clusters expanded are in the address, so Back returns to the graph as it was
// and Recenter is a link, Back the way to the graph before; the canvas is one stop for the keyboard,
// whose arrow keys walk its nodes, each said by the kit's words; and a volume's download, which a reader
// cannot start here, is left out.
import { useQuery } from '@tanstack/react-query';
import { getRouteApi, Link } from '@tanstack/react-router';
import { type KeyboardEvent, lazy, type RefObject, Suspense, useCallback, useEffect, useId, useMemo, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import { documentQuery } from '../api/endpoints';
import { type DocumentGraph, type GraphEdge, type GraphLayout, type GraphNode, graphQuery } from '../api/graph';
import { copy } from '../copy';
import { useHeadingReady } from '../shell/headingFocus';
import { plainTitle, useDocumentTitle } from '../shell/useDocumentTitle';
import {
  contextForNode,
  detailTitle,
  directionLabel,
  edgeDirectionLabel,
  focusKeys,
  isCluster,
  keyboardOrder,
  labelledNodes,
  networkLayout,
  primaryEdge,
  terminatesWalk,
  undownloadedBanner,
} from './graphRules';

const route = getRouteApi('/graph/$volumeId/$documentId');

/** Cytoscape.js, which only this page draws with, loaded with the page's canvas rather than with the app. */
const GraphCanvas = lazy(() => import('./GraphCanvas').then((module) => ({ default: module.GraphCanvas })));

/** The graph's address: the degree and layout the reader chose, the clusters expanded and the window brushed. */
export interface GraphSearch {
  degree?: 1 | 2 | 3;
  layout?: GraphLayout;
  /** The volume clusters expanded. */
  expand?: string[];
  /** The date clusters expanded. */
  dates?: string[];
  from?: number;
  to?: number;
}

/** The canvas a page that cannot measure its own is laid out on. */
const fallbackSize = { width: 960, height: 560 };

/** The canvas's size, measured, and measured again once a resize has rested. */
function useCanvasSize(frame: RefObject<HTMLDivElement | null>) {
  const [size, setSize] = useState<{ width: number; height: number } | undefined>(undefined);
  useEffect(() => {
    const element = frame.current;
    if (!element) return;
    const measure = () => {
      const width = Math.round(element.clientWidth);
      const height = Math.round(element.clientHeight);
      const next = width > 0 && height > 0 ? { width, height } : fallbackSize;
      // The same size, kept, so that nothing is laid out or asked for again.
      setSize((previous) => (previous && previous.width === next.width && previous.height === next.height ? previous : next));
    };
    measure();
    if (typeof ResizeObserver === 'undefined') return;
    let timer: ReturnType<typeof setTimeout> | undefined;
    const observer = new ResizeObserver(() => {
      clearTimeout(timer);
      timer = setTimeout(measure, 250);
    });
    observer.observe(element);
    return () => {
      clearTimeout(timer);
      observer.disconnect();
    };
  }, [frame]);
  return size;
}

/** Whether the reader's system asks for less motion. */
function prefersReducedMotion(): boolean {
  return (
    typeof window !== 'undefined' &&
    typeof window.matchMedia === 'function' &&
    window.matchMedia('(prefers-reduced-motion: reduce)').matches
  );
}

type Selection = { node: string } | { edge: string } | undefined;

export function GraphScreen() {
  const { volumeId, documentId } = route.useParams();
  const search = route.useSearch();
  const navigate = route.useNavigate();
  const key = `${volumeId}/${documentId}`;
  const frame = useRef<HTMLDivElement>(null);
  const size = useCanvasSize(frame);
  const anchor = useQuery(documentQuery(volumeId, documentId));
  const graph = useQuery({
    ...graphQuery(volumeId, documentId, {
      degree: search.degree,
      layout: search.layout,
      expand: search.expand,
      expandDates: search.dates,
      from: search.from,
      to: search.to,
      // A chosen network is laid out here, so the server's answer does not depend on the canvas.
      width: search.layout === 'network' ? fallbackSize.width : (size?.width ?? fallbackSize.width),
      height: size?.height ?? fallbackSize.height,
    }),
    enabled: size !== undefined,
    // The graph on show stays while the next of the same document is built, so the toolbar keeps its place.
    placeholderData: (previous: DocumentGraph | undefined) => (previous?.centralKey === key ? previous : undefined),
  });
  // The last graph the server gave for this document, which stays on show while a later one cannot be had.
  const [lastGood, setLastGood] = useState<DocumentGraph | undefined>(undefined);
  if (graph.data && graph.data !== lastGood && !graph.isPlaceholderData) setLastGood(graph.data);
  const data = graph.data ?? (lastGood?.centralKey === key ? lastGood : undefined);
  const title = anchor.data ? plainTitle(anchor.data.document.displayTitle ?? documentId) : documentId;
  useDocumentTitle(copy.graph.title);
  useHeadingReady(!graph.isPending);

  const [selection, setSelection] = useState<Selection>(undefined);
  const [active, setActive] = useState<string | undefined>(undefined);
  const [resetToken, setResetToken] = useState(0);
  // A new document starts with nothing selected and the keyboard on its own node.
  const [shownKey, setShownKey] = useState(key);
  if (shownKey !== key) {
    setShownKey(key);
    setSelection(undefined);
    setActive(undefined);
  }

  const drawn = useMemo(() => (data ? drawnGraph(data, size ?? fallbackSize) : undefined), [data, size]);
  const byId = useMemo(() => {
    const nodes = new Map<string, GraphNode>();
    for (const node of [...(data?.nodes ?? []), ...(data?.timeline?.dateClusters ?? [])]) nodes.set(node.id, node);
    return nodes;
  }, [data]);
  const order = useMemo(() => (data && drawn ? keyboardOrder(drawn.nodes, data.centralKey, data.referenceList) : []), [data, drawn]);
  const selectedNode = selection && 'node' in selection ? selection.node : undefined;
  const selectedEdge = selection && 'edge' in selection ? selection.edge : undefined;
  const labelled = useMemo(() => {
    if (!drawn) return new Set<string>();
    const labels = labelledNodes(drawn.nodes, drawn.edges, selectedNode);
    if (active) labels.add(active);
    return labels;
  }, [drawn, selectedNode, active]);
  const focus = useMemo(() => {
    if (!drawn) return undefined;
    // A selection the graph no longer draws, after a change of degree, layout or window, dims nothing.
    const shown = selectedNode
      ? drawn.nodes.some((node) => node.id === selectedNode)
      : drawn.edges.some((edge) => edge.id === selectedEdge);
    return shown ? focusKeys(drawn.edges, selectedNode, selectedEdge) : undefined;
  }, [drawn, selectedNode, selectedEdge]);
  // After an expansion, the keyboard goes to the first document it reveals, once the graph that draws it has come.
  const [pending, setPending] = useState<((node: GraphNode) => boolean) | undefined>(undefined);
  const revealed = pending ? order.find(pending) : undefined;
  if (pending && revealed) {
    setPending(undefined);
    setActive(revealed.id);
  }
  const activeNode = active && order.some((node) => node.id === active) ? active : order[0]?.id;
  // A cluster expanded from its row hands the focus to the first row it reveals, since its own row is gone.
  const rowFocus = useRef(false);
  useEffect(() => {
    if (!rowFocus.current || pending || !active) return;
    const row = document.querySelector<HTMLElement>(`.graph-row[data-node="${CSS.escape(active)}"]`);
    if (row) {
      row.focus();
      rowFocus.current = false;
    }
  }, [pending, active, data]);

  function retune(change: (previous: GraphSearch) => GraphSearch) {
    void navigate({ search: change, replace: true });
  }

  /** What a click or Enter on a node does: a cluster expands, any other node shows its details, or hides them. */
  const activate = useCallback(
    (node: GraphNode) => {
      if (node.kind === 'dateCluster') {
        void navigate({
          search: (previous: GraphSearch) => ({
            ...previous,
            dates: [...new Set([...(previous.dates ?? []), node.id])],
          }),
          replace: true,
        });
        const members = new Set(node.members ?? []);
        setPending(() => (each: GraphNode) => members.has(each.id));
        return;
      }
      if (isCluster(node)) {
        void navigate({
          search: (previous: GraphSearch) => ({
            ...previous,
            expand: [...new Set([...(previous.expand ?? []), node.id])],
          }),
          replace: true,
        });
        const direction = node.kind === 'clusterInbound' ? 'inbound' : 'outbound';
        setPending(() => (each: GraphNode) => each.kind === direction && each.volumeId === node.volumeId);
        return;
      }
      setSelection((current) => (current && 'node' in current && current.node === node.id ? undefined : { node: node.id }));
    },
    [navigate],
  );

  const onCanvasNode = useCallback(
    (id: string) => {
      const node = byId.get(id);
      if (!node) return;
      setActive(id);
      activate(node);
    },
    [byId, activate],
  );
  const onCanvasEdge = useCallback(
    (id: string) => {
      // As in the app, only an edge that carries a note's text is selected.
      const edge = drawn?.edges.find((each) => each.id === id);
      if (!edge || edge.contexts.length === 0) return;
      setSelection((current) => (current && 'edge' in current && current.edge === id ? undefined : { edge: id }));
    },
    [drawn],
  );

  /** A row's selection, which expands the date cluster that holds its document so the canvas shows it. */
  function selectFromList(node: GraphNode) {
    const selected = selectedNode === node.id;
    setSelection(selected ? undefined : { node: node.id });
    if (selected || !data?.timeline || data.timeline.visible.includes(node.id)) return;
    const holder = data.timeline.dateClusters.find((cluster) => cluster.members?.includes(node.id));
    if (holder)
      retune((previous) => ({
        ...previous,
        dates: [...(previous.dates ?? []), holder.id],
      }));
    setActive(node.id);
  }

  let body;
  if (graph.isError && !data) {
    body = (
      <div className="graph-empty" role="alert">
        <h2>{copy.graph.error}</h2>
        <p>{errorMessage(graph.error)}</p>
      </div>
    );
  }

  const shown = data !== undefined && drawn !== undefined;
  return (
    <div className="graph-page">
      <p className="back">
        <Link to="/doc/$volumeId/$documentId" params={{ volumeId, documentId }}>
          <span aria-hidden="true">← </span>
          {copy.graph.back(title)}
        </Link>
      </p>
      <h1 tabIndex={-1} data-loading={graph.isPending ? 'true' : undefined}>
        {copy.graph.title}
      </h1>
      {data?.hasUndownloadedSources && (
        <p className="graph-banner">{undownloadedBanner(data.undownloadedCitingCount, data.undownloadedCitingVolumeIds.length)}</p>
      )}
      {data && (
        <Toolbar
          graph={data}
          chosen={search.layout}
          degree={search.degree ?? 1}
          onLayout={(layout) =>
            retune((previous) => ({
              ...previous,
              layout,
              dates: undefined,
              from: undefined,
              to: undefined,
            }))
          }
          onDegree={(degree) =>
            retune((previous) => ({
              ...previous,
              degree,
              expand: undefined,
              dates: undefined,
              from: undefined,
              to: undefined,
            }))
          }
          onReset={() => setResetToken((token) => token + 1)}
        />
      )}
      {graph.isError && data && (
        <p className="error" role="alert">
          {errorMessage(graph.error)}
        </p>
      )}
      <p className="note graph-status" role="status">
        {graph.isFetching ? copy.graph.building : ''}
      </p>
      {body}
      <div className={shown ? 'graph-body' : 'graph-body graph-body-waiting'}>
        <div className="graph-main">
          <div className="graph-canvas-frame" ref={frame}>
            {data && drawn && (
              <>
                <Suspense fallback={null}>
                  <GraphCanvas
                    nodes={drawn.nodes}
                    edges={drawn.edges}
                    positions={drawn.positions}
                    timeline={data.timeline}
                    labelled={labelled}
                    selectedNode={selectedNode}
                    selectedEdge={selectedEdge}
                    activeNode={activeNode}
                    focus={focus}
                    resetToken={resetToken}
                    reducedMotion={prefersReducedMotion()}
                    onNode={onCanvasNode}
                    onEdge={onCanvasEdge}
                  />
                </Suspense>
                <NodeList
                  order={order}
                  graph={data}
                  active={activeNode}
                  selected={selectedNode}
                  onActive={setActive}
                  onActivate={activate}
                  onClear={() => setSelection(undefined)}
                />
              </>
            )}
          </div>
          {drawn && <Legend nodes={drawn.nodes} />}
        </div>
        {data && drawn && (
          <aside className="graph-panel" aria-label={copy.graph.title}>
            <Details
              graph={data}
              selection={selection}
              node={selectedNode ? byId.get(selectedNode) : undefined}
              drawnEdges={drawn.edges}
              search={search}
              onClose={() => {
                // The focus goes back to the selected row, or to the canvas's nodes, not to the page.
                const row = document.querySelector<HTMLElement>('.graph-row[aria-pressed="true"]');
                setSelection(undefined);
                (row ?? document.querySelector<HTMLElement>('.graph-keys'))?.focus();
              }}
              onActivate={activate}
            />
            <ReferenceList
              graph={data}
              byId={byId}
              selected={selectedNode}
              onSelect={selectFromList}
              onExpand={(node) => {
                rowFocus.current = true;
                activate(node);
              }}
            />
          </aside>
        )}
      </div>
      <About />
    </div>
  );
}

/** What the canvas draws: the timeline's nodes, edges and places from the server, or the network's here. */
function drawnGraph(graph: DocumentGraph, size: { width: number; height: number }) {
  const timeline = graph.timeline;
  if (timeline) {
    const byId = new Map<string, GraphNode>();
    for (const node of [...graph.nodes, ...timeline.dateClusters]) byId.set(node.id, node);
    const nodes = timeline.visible.flatMap((id) => {
      const node = byId.get(id);
      return node && timeline.positions[id] ? [node] : [];
    });
    return { nodes, edges: timeline.edges ?? graph.edges, positions: timeline.positions };
  }
  // The three columns place the central document and its direct references alone, as the app's do: what a layout
  // leaves unplaced is not drawn, so the keyboard does not reach it.
  const positions = networkLayout(graph.nodes, graph.edges, graph.centralKey, size.width, size.height);
  return { nodes: graph.nodes.filter((node) => positions[node.id] !== undefined), edges: graph.edges, positions };
}

function Toolbar({
  graph,
  degree,
  onLayout,
  onDegree,
  onReset,
  chosen,
}: {
  graph: DocumentGraph;
  /** The degree the reader chose, one while they have chosen none, as the app's picker shows it. */
  degree: number;
  onLayout: (layout: GraphLayout) => void;
  onDegree: (degree: 1 | 2 | 3) => void;
  onReset: () => void;
  /** The layout the address asks for, shown at once while its graph is built. */
  chosen?: GraphLayout;
}) {
  const layoutName = useId();
  const degreeName = useId();
  const depthLabel = useId();
  const layout = chosen ?? graph.chosenLayout ?? graph.layout;
  return (
    <div className="graph-toolbar">
      <fieldset className="pane-picker" disabled={!graph.timelineEligible} title={copy.graph.layoutHelp}>
        <legend className="visually-hidden">{copy.graph.layout}</legend>
        {(['timeline', 'network'] as const).map((each) => (
          <label key={each}>
            <input type="radio" name={layoutName} checked={layout === each} onChange={() => onLayout(each)} />
            <span>{copy.graph.layouts[each]}</span>
          </label>
        ))}
      </fieldset>
      <span id={depthLabel} className="graph-depth-label" aria-hidden="true">
        {copy.graph.depthLabel}
      </span>
      <fieldset className="pane-picker">
        <legend className="visually-hidden">{copy.graph.depth}</legend>
        {([1, 2, 3] as const).map((each) => (
          <label key={each} title={copy.graph.degreeHelp[each]}>
            <input type="radio" name={degreeName} checked={degree === each} onChange={() => onDegree(each)} />
            <span>{copy.graph.degrees[each]}</span>
          </label>
        ))}
      </fieldset>
      {graph.widened && <p className="note graph-widened">{copy.graph.widened}</p>}
      <button type="button" className="graph-reset" title={copy.graph.resetViewHelp} onClick={onReset}>
        {copy.graph.resetView}
      </button>
    </div>
  );
}

/**
 * The canvas's nodes for the keyboard: a list box over the canvas, one stop, whose arrow keys move from
 * node to node in `order` and whose Enter or Space acts on the node, each said by the kit's words for it.
 * The node it is on is ringed on the canvas.
 */
function NodeList({
  order,
  graph,
  active,
  selected,
  onActive,
  onActivate,
  onClear,
}: {
  order: GraphNode[];
  graph: DocumentGraph;
  active?: string;
  selected?: string;
  onActive: (id: string) => void;
  onActivate: (node: GraphNode) => void;
  onClear: () => void;
}) {
  const help = useId();
  const prefix = useId();
  const index = Math.max(
    0,
    order.findIndex((node) => node.id === active),
  );
  const groups = useMemo(() => nodeGroups(order, graph), [order, graph]);
  const position = new Map(order.map((node, at) => [node.id, at]));

  function onKeyDown(event: KeyboardEvent<HTMLDivElement>) {
    let next: number | undefined;
    switch (event.key) {
      case 'ArrowDown':
      case 'ArrowRight':
        next = Math.min(index + 1, order.length - 1);
        break;
      case 'ArrowUp':
      case 'ArrowLeft':
        next = Math.max(index - 1, 0);
        break;
      case 'Home':
        next = 0;
        break;
      case 'End':
        next = order.length - 1;
        break;
      case 'Enter':
      case ' ': {
        event.preventDefault();
        const node = order[index];
        if (node) onActivate(node);
        return;
      }
      case 'Escape':
        if (selected) {
          event.preventDefault();
          onClear();
        }
        return;
      default:
        return;
    }
    event.preventDefault();
    const reached = order[next];
    if (reached) onActive(reached.id);
  }

  const option = (node: GraphNode) => (
    <div
      key={node.id}
      role="option"
      id={`${prefix}-${position.get(node.id)}`}
      aria-selected={selected === node.id}
      className="graph-option"
      onClick={() => {
        onActive(node.id);
        onActivate(node);
      }}
    >
      {node.label}
    </div>
  );
  return (
    <>
      <div
        role="listbox"
        tabIndex={0}
        className="graph-keys"
        aria-label={copy.graph.canvas}
        aria-describedby={help}
        aria-activedescendant={order.length > 0 ? `${prefix}-${index}` : undefined}
        onKeyDown={onKeyDown}
      >
        {groups.map((group) =>
          group.label ? (
            <div key={group.label} role="group" aria-label={group.label}>
              {group.nodes.map(option)}
            </div>
          ) : (
            group.nodes.map(option)
          ),
        )}
      </div>
      <p id={help} className="visually-hidden">
        {copy.graph.canvasHelp}
      </p>
    </>
  );
}

/** The keyboard's nodes in their groups: the central document alone, then the app's three sections, then the web's two. */
function nodeGroups(order: GraphNode[], graph: DocumentGraph): { label?: string; nodes: GraphNode[] }[] {
  const inbound = new Set(graph.referenceList.inbound);
  const outbound = new Set(graph.referenceList.outbound);
  const extended = new Set(graph.referenceList.extended);
  const groups: { label?: string; nodes: GraphNode[] }[] = [
    { nodes: order.filter((node) => node.kind === 'central') },
    {
      label: copy.graph.sections.inbound,
      nodes: order.filter((node) => inbound.has(node.id)),
    },
    {
      label: copy.graph.sections.outbound,
      nodes: order.filter((node) => outbound.has(node.id)),
    },
    {
      label: copy.graph.sections.extended,
      nodes: order.filter((node) => extended.has(node.id)),
    },
    {
      label: copy.graph.dateGroups,
      nodes: order.filter((node) => node.kind === 'dateCluster'),
    },
    {
      label: copy.graph.archival,
      nodes: order.filter((node) => terminatesWalk(node)),
    },
  ];
  return groups.filter((group) => group.nodes.length > 0);
}

/** The legend under the canvas, the app's: the colours, the arrow, the size, and the archival nodes when any is drawn. */
function Legend({ nodes }: { nodes: GraphNode[] }) {
  const archival = nodes.some((node) => terminatesWalk(node));
  return (
    <ul className="graph-legend" aria-label={copy.graph.legend}>
      <li>
        <span className="swatch inbound" aria-hidden="true" />
        {copy.graph.legendInbound}
      </li>
      <li>
        <span className="swatch outbound" aria-hidden="true" />
        {copy.graph.legendOutbound}
      </li>
      <li>
        <span className="swatch extended" aria-hidden="true" />
        {copy.graph.legendExtended}
      </li>
      <li>
        <span aria-hidden="true">→ </span>
        {copy.graph.legendArrow}
      </li>
      <li>{copy.graph.legendSize}</li>
      {archival && (
        <li>
          <span className="swatch archival" aria-hidden="true" />
          {copy.graph.legendUnit}
        </li>
      )}
    </ul>
  );
}

/** A note's text that carried a reference, to three lines until Show more (`EdgeContextView`). */
function EdgeContext({ context, direction }: { context: string; direction: string }) {
  const [expanded, setExpanded] = useState(false);
  return (
    <div className="graph-context">
      <p className="graph-direction">{direction}</p>
      <p className={expanded ? 'graph-context-text' : 'graph-context-text clamped'}>{context}</p>
      <button type="button" className="link-button" aria-expanded={expanded} onClick={() => setExpanded(!expanded)}>
        {expanded ? copy.graph.showLess : copy.graph.showMore}
      </button>
    </div>
  );
}

/**
 * The details at the top of the panel (`GraphNodeDetailView`, `GraphEdgeDetailView`): the selected node's
 * head, dateline and volume, the note's text that carried its reference, and what can be done with it, or
 * the selected edge's two documents, its count and its notes; else the app's line asking for a selection.
 */
function Details({
  graph,
  selection,
  node,
  drawnEdges,
  search,
  onClose,
  onActivate,
}: {
  graph: DocumentGraph;
  selection: Selection;
  node?: GraphNode;
  drawnEdges: GraphEdge[];
  search: GraphSearch;
  onClose: () => void;
  onActivate: (node: GraphNode) => void;
}) {
  const heading = useId();
  const close = (
    <button type="button" className="graph-close" aria-label={copy.graph.close} title={copy.graph.closeHelp} onClick={onClose}>
      <span aria-hidden="true">×</span>
    </button>
  );
  const edge = selection && 'edge' in selection ? drawnEdges.find((each) => each.id === selection.edge) : undefined;
  if (edge && edge.contexts.length > 0) {
    const name = (id: string) => graph.nodes.find((each) => each.id === id)?.header ?? id;
    return (
      <section className="graph-details" aria-labelledby={heading}>
        <div className="graph-detail-head">
          <h2 id={heading} className="graph-edge-title">
            {name(edge.source)}
            <span aria-hidden="true"> → </span>
            <span className="visually-hidden"> to </span>
            {name(edge.target)}
          </h2>
          {close}
        </div>
        {edge.referenceCount > 1 && <p className="note">{copy.graph.separateReferences(edge.referenceCount)}</p>}
        <EdgeContext context={edge.contexts.join('\n\n')} direction={edgeDirectionLabel(edge, graph.centralKey)} />
      </section>
    );
  }
  if (!node) {
    return <p className="note graph-placeholder">{copy.graph.detailPlaceholder}</p>;
  }
  const context = contextForNode(node, drawnEdges, graph.centralKey);
  return (
    <section className="graph-details" aria-labelledby={heading}>
      <div className="graph-detail-head">
        <h2 id={heading}>{terminatesWalk(node) ? (node.name ?? node.label) : detailTitle(node)}</h2>
        {close}
      </div>
      {node.dateline && <p className="graph-dateline">{node.dateline}</p>}
      {node.header !== undefined && node.volumeId && <p className="graph-volume">{node.volumeId}</p>}
      {terminatesWalk(node) && <p className="graph-dateline">{node.kind === 'unit' ? copy.graph.unprinted : copy.graph.centralFile}</p>}
      {context && <EdgeContext context={context} direction={directionLabel(node.kind)} />}
      {!node.isDownloaded && node.kind !== 'central' && node.kind !== 'dateCluster' && (
        <p className="graph-not-served">{copy.graph.notServed}</p>
      )}
      {node.kind === 'dateCluster' ? (
        <button type="button" onClick={() => onActivate(node)}>
          {copy.graph.expandDateGroup}
        </button>
      ) : isCluster(node) ? (
        <button type="button" onClick={() => onActivate(node)}>
          {copy.graph.expandCluster}
        </button>
      ) : node.kind !== 'central' && !terminatesWalk(node) && node.volumeId && node.documentId ? (
        <div className="graph-actions">
          <Link
            to="/graph/$volumeId/$documentId"
            params={{ volumeId: node.volumeId, documentId: node.documentId }}
            search={{ degree: search.degree, layout: search.layout }}
            className="button-link"
          >
            {copy.graph.recenter}
          </Link>
          {node.opens ? (
            <Link
              to="/doc/$volumeId/$documentId"
              params={{ volumeId: node.volumeId, documentId: node.documentId }}
              className="button-link primary"
            >
              {copy.graph.viewDocument}
            </Link>
          ) : (
            <button type="button" disabled>
              {copy.graph.viewDocument}
            </button>
          )}
        </div>
      ) : null}
    </section>
  );
}

/**
 * The reference list (`ReferenceListPanel`): the documents and clusters citing the document, those it
 * cites, and those further out, each section in the kit's order, each row the document's number and head,
 * its date, its volume, its references' count and the opening of its note, with Open beside it; a
 * cluster's row expands it.
 */
function ReferenceList({
  graph,
  byId,
  selected,
  onSelect,
  onExpand,
}: {
  graph: DocumentGraph;
  byId: Map<string, GraphNode>;
  selected?: string;
  onSelect: (node: GraphNode) => void;
  onExpand: (node: GraphNode) => void;
}) {
  const rowHint = useId();
  const clusterHint = useId();
  const sections = [
    { title: copy.graph.list.inbound, ids: graph.referenceList.inbound },
    { title: copy.graph.list.outbound, ids: graph.referenceList.outbound },
    { title: copy.graph.list.extended, ids: graph.referenceList.extended },
  ].filter((section) => section.ids.length > 0);
  return (
    <div className="graph-list">
      <p id={rowHint} hidden>
        {copy.graph.listRowHint}
      </p>
      <p id={clusterHint} hidden>
        {copy.graph.listClusterHint}
      </p>
      {sections.map((section) => (
        <section key={section.title}>
          <h2>{section.title}</h2>
          <ul>
            {section.ids.flatMap((id) => {
              const node = byId.get(id);
              if (!node) return [];
              if (isCluster(node)) {
                return [
                  <li key={id}>
                    <button
                      type="button"
                      className={`graph-row cluster ${node.kind}`}
                      data-node={id}
                      aria-describedby={clusterHint}
                      onClick={() => onExpand(node)}
                    >
                      {node.label}
                    </button>
                  </li>,
                ];
              }
              const edge = primaryEdge(id, graph.edges, graph.centralKey);
              return [
                <li key={id} className={selected === id ? 'selected' : undefined}>
                  <button
                    type="button"
                    className="graph-row"
                    data-node={id}
                    aria-label={node.label}
                    aria-describedby={rowHint}
                    aria-pressed={selected === id}
                    onClick={() => onSelect(node)}
                  >
                    <span className="graph-row-title">
                      <span className={`kind-dot ${node.kind}`} aria-hidden="true" />
                      {node.rowNumber && <span className="graph-row-number">{node.rowNumber}.</span>}
                      <span>{node.rowTitle}</span>
                    </span>
                    <span className="graph-row-meta">
                      {node.dateLabel && <span>{node.dateLabel}</span>}
                      {node.volumeId && <span>{node.volumeId}</span>}
                      {edge && edge.referenceCount > 1 && <span>{copy.graph.referenceCount(edge.referenceCount)}</span>}
                      {!node.isDownloaded && <span>{copy.graph.notServed}</span>}
                    </span>
                    {edge?.contexts[0] && <span className="graph-row-snippet">{edge.contexts[0]}</span>}
                  </button>
                  {node.opens && node.volumeId && node.documentId ? (
                    <Link
                      to="/doc/$volumeId/$documentId"
                      params={{
                        volumeId: node.volumeId,
                        documentId: node.documentId,
                      }}
                      className="graph-open"
                      aria-label={copy.graph.open}
                      title={copy.graph.open}
                    >
                      <span aria-hidden="true">↗</span>
                    </Link>
                  ) : (
                    <button type="button" className="graph-open" aria-label={copy.graph.open} disabled>
                      <span aria-hidden="true">↗</span>
                    </button>
                  )}
                </li>,
              ];
            })}
          </ul>
        </section>
      ))}
    </div>
  );
}

/** The app's About this graph, as a disclosure under the graph. */
function About() {
  return (
    <details className="graph-about">
      <summary>{copy.graph.about}</summary>
      <h2>{copy.graph.aboutHeading}</h2>
      {copy.graph.aboutRows.map(([title, body]) => (
        <section key={title}>
          <h3>{title}</h3>
          {body.split('\n\n').map((paragraph) => (
            <p key={paragraph.slice(0, 40)}>{paragraph}</p>
          ))}
        </section>
      ))}
    </details>
  );
}
