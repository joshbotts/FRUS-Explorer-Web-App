// Archival Analytics (PLAN's S24h), at /analytics/archives: the app's `ArchivalAnalyticsView` as a page, in its four
// modes. Collections ranks the archival units each era's volumes drew on, from the bundled authority, with nothing
// indexed; Network draws one collection's co-citation neighbourhood in custodian wedges; Flows maps the editors'
// hand-offs between collections, and their pointers to material they did not print; Your Library profiles the served
// index's volumes. Every series, word and table is the kit's or the view's, from the server; the ranking is drawn by
// Vega-Lite with its table beside it, its CSV from the server and its figure, PNG or SVG, drawn here with the kit's
// caption band; the other exports are CSVs, as the app's are. The web's own: the mode, the controls and the network's
// focus and trail in the address; the uncapped list shown below the ranking rather than in a sheet; and a collection or
// a class opening the server's own record and neighbours pages.
import { useQuery } from '@tanstack/react-query';
import { getRouteApi, Link } from '@tanstack/react-router';
import { type KeyboardEvent, lazy, type ReactNode, type RefObject, Suspense, useEffect, useId, useMemo, useRef, useState } from 'react';
import { ApiError, errorMessage } from '../api/client';
import {
  type ArchivalChart,
  type ArchivalContext,
  archivalContextQuery,
  archivalCSV,
  archivalPlate,
  type ArchivalScope,
  type CollectionsAnswer,
  type CollectionsAsk,
  collectionsQuery,
  type FlowEndpoint,
  type FlowsAnswer,
  type FlowsAsk,
  flowsCandidatesQuery,
  flowsQuery,
  libraryQuery,
  type NetworkAnswer,
  type NetworkAsk,
  networkCandidatesQuery,
  networkQuery,
  unitsQuery,
} from '../api/archivalAnalytics';
import type { AnalyticsContext, AnalyticsScope } from '../api/analytics';
import { volumeScopesQuery } from '../api/searchSets';
import { meQuery } from '../api/userData';
import { copy } from '../copy';
import { useScheme } from '../shell/AppShell';
import { useHeadingReady } from '../shell/headingFocus';
import { saveFile } from '../shell/saveFile';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import { addressScope, type ChartSpec, figureSpec, scopeFields, scopeGroups, scopeValue, stored, store } from './analyticsRules';
import {
  type ArchivalSearch,
  blockFrames,
  bandsSpec,
  compositionSpec,
  custodianColors,
  diagramHeight,
  focusFrame,
  markdownRuns,
  rankingSpec,
  ribbonOpacity,
  ribbonPath,
} from './archivalRules';
import { Empty, ScopeOptions, Segmented } from './CorpusAnalyticsScreen';
import { DataTable, ExportMenu } from './PersonAnalyticsScreen';

const route = getRouteApi('/analytics/archives');
const words = copy.archivalAnalytics;
const corpus = copy.corpusAnalytics;

const VegaChart = lazy(() => import('./VegaChart').then((module) => ({ default: module.VegaChart })));
const ArchivalNetworkCanvas = lazy(() => import('./ArchivalNetworkCanvas').then((module) => ({ default: module.ArchivalNetworkCanvas })));

/** The keys the app keeps a reader's way of working under, on each device (`@AppStorage`). */
export const archivalKeys = {
  lens: 'frus.archivalAnalytics.unitLens',
  weight: 'frus.archivalAnalytics.weight',
  measure: 'frus.archivalAnalytics.edgeMeasure',
};

/** The scope the address names: the scope menu's, or a presidency's. */
function archivalScope(search: ArchivalSearch): ArchivalScope | undefined {
  if (search.administration) return { kind: 'administration', id: search.administration };
  return addressScope({
    subseries: search.subseries, volume: search.volume, topic: search.topic, subtopic: search.subtopic,
    volumes: search.volumes, scopeLabel: search.scopeLabel,
  });
}

/** A body of Markdown as the app sets it: strong and emphasis. */
function Markdown({ body }: { body: string }) {
  return (
    <>
      {markdownRuns(body).map((run, index) =>
        run.strong ? <strong key={index}>{run.text}</strong> : run.emphasis ? <em key={index}>{run.text}</em> : <span key={index}>{run.text}</span>,
      )}
    </>
  );
}

export function ArchivalAnalyticsScreen() {
  const search = route.useSearch();
  const navigate = route.useNavigate();
  const context = useQuery(archivalContextQuery);
  useDocumentTitle(words.title);
  useHeadingReady(!context.isPending);
  const [failure, setFailure] = useState<string | undefined>(undefined);
  const mode = search.mode ?? 'collections';

  function change(fields: Partial<ArchivalSearch>, replace = false) {
    void navigate({ search: (previous) => ({ ...previous, ...fields }), replace });
  }

  async function exportCSV(chart: ArchivalChart, asks: Parameters<typeof archivalCSV>[1]) {
    setFailure(undefined);
    try {
      const file = await archivalCSV(chart, asks);
      saveFile(file.blob, file.name);
    } catch (error) {
      setFailure(errorMessage(error));
    }
  }

  return (
    <div className="analytics-page archival-analytics">
      <div className="archival-title">
        <h1 tabIndex={-1} data-loading={context.isPending ? 'true' : undefined}>
          {words.title}
        </h1>
        {context.data && (
          <Link to="/about" search={{ page: 'sourcing' }} className="archival-guide">
            {context.data.researchGuide}
          </Link>
        )}
      </div>
      {context.error ? (
        <Empty title={corpus.errorTitle} detail={errorMessage(context.error)} />
      ) : !context.data ? (
        <p className="analytics-loading" role="status">
          {words.loadingCollections}
        </p>
      ) : (
        <>
          <Segmented
            legend={words.mode}
            help={words.modeHelp}
            name="archival-mode"
            value={mode}
            disabled={false}
            choices={context.data.modes.map((option) => ({ value: option.value, label: option.title }))}
            onChange={(value) => change({ mode: value })}
          />
          {failure && (
            <div className="analytics-alert" role="alert">
              <strong>{corpus.exportFailed}</strong> {failure}
            </div>
          )}
          {mode === 'network' ? (
            <NetworkMode search={search} context={context.data} onChange={change} onCSV={(asks) => void exportCSV('network', asks)} />
          ) : mode === 'flows' ? (
            <FlowsMode search={search} context={context.data} onChange={change} onCSV={(asks) => void exportCSV('flows', asks)} />
          ) : mode === 'yourLibrary' ? (
            <LibraryMode onCSV={(chart) => void exportCSV(chart, emptyAsks)} />
          ) : (
            <CollectionsMode search={search} context={context.data} onChange={change} onFailure={setFailure}
                             onCSV={(chart, asks) => void exportCSV(chart, asks)} />
          )}
          <p className="analytics-footnote archival-pointer">{context.data.methodPointer}</p>
        </>
      )}
    </div>
  );
}

const emptyAsks = {
  collections: { umbrella: false },
  network: { width: 720, height: 420, only: false },
  flows: {},
};

// ─── Collections ────────────────────────────────────────────────────────────

/** The scope's choices over the series: the analytics scope menu's, with the administration menu's presidencies. */
function useArchivalScopes(context: ArchivalContext) {
  const me = useQuery(meQuery);
  const scopes = useQuery({ ...volumeScopesQuery, enabled: me.data?.userData === true });
  return useMemo(() => {
    // A reader's volume scope is resolved against the series here, as the bar resolves it against its population.
    const series = new Set(context.seriesVolumeIds);
    const resolved = scopes.data?.items.map((scope) => ({
      ...scope,
      indexedVolumeIds: scope.volumeIds.filter((id) => series.has(id)),
    }));
    const asContext = { subseries: context.subseries, topics: context.topics } as AnalyticsContext;
    const groups = scopeGroups(asContext, resolved);
    if (context.administrations.length > 0) {
      groups.push({
        label: words.administration,
        options: context.administrations.map((profile) => ({
          value: `administration:${profile.id}`,
          label: profile.president,
          scope: { kind: 'administration', id: profile.id } as unknown as AnalyticsScope,
        })),
      });
    }
    return groups;
  }, [context, scopes.data]);
}

function scopeKey(scope: ArchivalScope | undefined): string {
  return scope?.kind === 'administration' ? `administration:${scope.id}` : scopeValue(scope);
}

function CollectionsMode({
  search,
  context,
  onChange,
  onFailure,
  onCSV,
}: {
  search: ArchivalSearch;
  context: ArchivalContext;
  onChange: (fields: Partial<ArchivalSearch>, replace?: boolean) => void;
  onFailure: (message: string | undefined) => void;
  onCSV: (chart: ArchivalChart, asks: Parameters<typeof archivalCSV>[1]) => void;
}) {
  const scheme = useScheme();
  const scope = archivalScope(search);
  const lens = search.lens ?? stored(archivalKeys.lens) ?? 'namedCollections';
  const weight = search.weight ?? stored(archivalKeys.weight) ?? 'documents';
  const ask: CollectionsAsk = { band: search.band ?? context.defaultBand, lens, weight, umbrella: search.umbrella === 'shown', scope };
  const collections = useQuery(collectionsQuery(ask));
  const [allUnits, setAllUnits] = useState(false);
  const groups = useArchivalScopes(context);
  const chosen = scopeKey(scope);
  const options = groups.flatMap((group) => group.options);
  const ids = { scope: useId(), band: useId(), lens: useId(), weight: useId() };
  const answer = collections.data;
  const spec = useMemo(
    () => (answer && answer.ranking.rows.length > 0 ? rankingSpec(answer, scheme === 'dark', customNames(answer)) : undefined),
    [answer, scheme],
  );

  function chooseScope(value: string) {
    const option = options.find((each) => each.value === value);
    if (!option || option.disabled) return;
    const picked = option.scope as unknown as ArchivalScope | undefined;
    const cleared = { subseries: undefined, volume: undefined, topic: undefined, subtopic: undefined, volumes: undefined, scopeLabel: undefined, administration: undefined };
    if (picked?.kind === 'administration') onChange({ ...cleared, administration: picked.id });
    else onChange({ ...cleared, ...scopeFields(picked) });
  }

  async function figure(format: 'png' | 'svg') {
    if (!spec || !answer) return;
    onFailure(undefined);
    try {
      const [{ renderFigure }, plate] = await Promise.all([import('./VegaChart'), archivalPlate(ask)]);
      saveFile(await renderFigure(figureSpec(spec as ChartSpec, plate, []), format), `${plate.fileName}.${format}`);
    } catch (error) {
      onFailure(error instanceof ApiError ? errorMessage(error) : corpus.renderError);
    }
  }

  return (
    <section aria-label={words.collections} className="archival-mode">
      <div className="analytics-filters">
        <div className="analytics-field">
          <label htmlFor={ids.scope}>{corpus.scope}</label>
          <select id={ids.scope} value={chosen} onChange={(event) => chooseScope(event.target.value)}>
            {!options.some((option) => option.value === chosen) && <option value={chosen}>{answer?.scope.label ?? ''}</option>}
            {groups.map((group, index) => (
              <ScopeOptions key={`${group.label}-${index}`} group={group} />
            ))}
          </select>
        </div>
        <div className="analytics-field">
          <label htmlFor={ids.band}>{words.era}</label>
          <select id={ids.band} value={ask.band} onChange={(event) => onChange({ band: event.target.value })}>
            {context.bands.map((band) => (
              <option key={band.value} value={band.value}>
                {band.title}
              </option>
            ))}
          </select>
        </div>
        <div className="analytics-field">
          <label htmlFor={ids.lens}>{words.show}</label>
          <select
            id={ids.lens}
            value={lens}
            onChange={(event) => {
              store(archivalKeys.lens, event.target.value);
              onChange({ lens: event.target.value });
            }}
          >
            {context.lenses.map((option) => (
              <option key={option.value} value={option.value}>
                {option.title}
              </option>
            ))}
          </select>
        </div>
        <div className="analytics-field">
          <label htmlFor={ids.weight}>{words.countBy}</label>
          <select
            id={ids.weight}
            value={answer?.weight ?? weight}
            onChange={(event) => {
              store(archivalKeys.weight, event.target.value);
              onChange({ weight: event.target.value });
            }}
          >
            {(answer?.weights ?? context.weights.map((option) => ({ ...option, enabled: true }))).map((option) => (
              <option key={option.value} value={option.value} disabled={!option.enabled}>
                {option.title}
              </option>
            ))}
          </select>
        </div>
        {answer?.umbrella && (
          <button
            type="button"
            aria-pressed={!answer.hidesUmbrella}
            aria-label={answer.umbrella.accessibilityLabel}
            title={`${answer.umbrella.caption}: ${answer.umbrella.value}`}
            onClick={() => onChange({ umbrella: answer.hidesUmbrella ? 'shown' : undefined })}
          >
            {answer.umbrella.caption}: {answer.umbrella.value}
          </button>
        )}
      </div>
      {collections.error ? (
        <Empty title={corpus.errorTitle} detail={errorMessage(collections.error)} />
      ) : !answer ? (
        <p className="analytics-loading" role="status">
          {words.loadingCollections}
        </p>
      ) : (
        <div className="analytics-result" aria-busy={collections.isPlaceholderData || undefined}>
          {answer.denominator && (
            <div className="archival-denominator">
              <p>{answer.denominator.sentence}</p>
              {answer.denominator.pointer && <p>{answer.denominator.pointer}</p>}
            </div>
          )}
          <div className="analytics-section-head">
            <h2>{answer.ranking.title}</h2>
            <ExportMenu
              canExport={answer.ranking.rows.length > 0}
              canDraw={!!spec && !collections.isPlaceholderData}
              onCSV={() => onCSV('ranking', { ...emptyAsks, collections: ask })}
              onFigure={(format) => void figure(format)}
            />
          </div>
          <p className="analytics-caption">{answer.ranking.caption}</p>
          {answer.ranking.empty ? (
            <p className="analytics-note">{answer.ranking.empty}</p>
          ) : (
            <div className="analytics-pane">
              <div className="analytics-figure">
                <Suspense fallback={<div className="analytics-chart" aria-hidden="true" />}>
                  {spec && <VegaChart spec={spec} label={words.chartDescription(answer.ranking.title)} />}
                </Suspense>
                <RankingRows answer={answer} />
              </div>
              {answer.ranking.table && <DataTable table={answer.ranking.table} />}
            </div>
          )}
          {answer.drillInHint && <p className="analytics-caption">{answer.drillInHint}</p>}
          {answer.showAllUnits && (
            <button type="button" aria-expanded={allUnits} onClick={() => setAllUnits((open) => !open)}>
              {answer.showAllUnits}
            </button>
          )}
          {allUnits && answer.showAllUnits && (
            <EveryUnit ask={ask} lens={lens} onClose={() => setAllUnits(false)} onCSV={() => onCSV('units', { ...emptyAsks, collections: ask })} />
          )}
          {answer.families && (
            <div className="archival-families">
              <h3>{answer.families.title}</h3>
              <p className="analytics-caption">{answer.families.caption}</p>
              {answer.families.items.map((family) => (
                <details key={family.name}>
                  <summary>
                    {family.name} <span className="count">{family.count}</span>
                  </summary>
                  <ul>
                    {family.leaves.map((leaf) => (
                      <li key={leaf.key}>
                        <code>{leaf.key}</code> {leaf.gloss && <span className="gloss">{leaf.gloss}</span>} <span className="tag">{leaf.tag}</span>{' '}
                        <span className="count">{leaf.value.toLocaleString('en-US')}</span>
                      </li>
                    ))}
                  </ul>
                </details>
              ))}
            </div>
          )}
          {answer.caveats.map((caveat) => (
            <p key={caveat} className="analytics-note">
              {caveat}
            </p>
          ))}
          <p className="analytics-footnote">{answer.timingPointer}</p>
        </div>
      )}
    </section>
  );
}

/** The custodians' names as the answer gives them, for the chart's colour key. */
function customNames(answer: CollectionsAnswer): Record<string, string> {
  const names: Record<string, string> = { ...copy.archivalAnalytics.custodians };
  for (const row of answer.ranking.rows) names[row.category] = row.categoryName;
  return names;
}

/** Each bar's row, which opens what the bar stands for: a collection's record, or a class's documents (`open(_:data:)`). */
function RankingRows({ answer }: { answer: CollectionsAnswer }) {
  return (
    <ol className="archival-rows">
      {answer.ranking.rows.map((row) => (
        <li key={row.id}>
          <RowLink lens={answer.lens} id={row.id} opens={row.opens} label={row.accessibilityLabel}>
            <span className="swatch" data-custodian={row.category} aria-hidden="true" /> {row.label}
          </RowLink>{' '}
          <span className="count">{row.accessibilityValue}</span>
        </li>
      ))}
    </ol>
  );
}

function RowLink({ lens, id, opens, label, children }: { lens: string; id: string; opens: boolean; label: string; children: ReactNode }) {
  if (!opens) return <span>{children}</span>;
  return lens === 'centralFileClasses' ? (
    <Link to="/archival-neighbors" search={{ decimalClass: id }} aria-label={label}>
      {children}
    </Link>
  ) : (
    <Link to="/archival-collection" search={{ id }} aria-label={label}>
      {children}
    </Link>
  );
}

/** The uncapped list (`ArchivalAllUnitsSheet`), below the chart it was opened from. */
function EveryUnit({ ask, lens, onClose, onCSV }: { ask: CollectionsAsk; lens: string; onClose: () => void; onCSV: () => void }) {
  const units = useQuery(unitsQuery(ask, true));
  const heading = useRef<HTMLHeadingElement>(null);
  useEffect(() => heading.current?.focus(), []);
  const answer = units.data;
  return (
    <section className="archival-units" aria-label={answer?.title ?? words.everyUnit}>
      <div className="analytics-section-head">
        <h3 ref={heading} tabIndex={-1}>
          {answer?.title ?? words.everyUnit}
        </h3>
        <ExportMenu canExport={!!answer && answer.rows.length > 0} canDraw={false} onCSV={onCSV} />
        <button type="button" onClick={onClose}>
          {words.done}
        </button>
      </div>
      {units.error ? (
        <p className="analytics-note">{errorMessage(units.error)}</p>
      ) : !answer ? (
        <p className="analytics-loading" role="status">
          {words.loadingCollections}
        </p>
      ) : (
        <>
          <p className="analytics-caption">{answer.header}</p>
          <div className="archival-units-list" tabIndex={0} role="region" aria-label={words.everyUnitList(answer.header)}>
            <ol>
              {answer.rows.map((row) => (
                <li key={row.id}>
                  <span className="rank">{row.rank}</span>{' '}
                  <RowLink lens={lens} id={row.id} opens={row.opens} label={row.label}>
                    {row.label}
                  </RowLink>
                  {row.gloss && <span className="gloss"> {row.gloss}</span>} <span className="count">{row.value.toLocaleString('en-US')}</span>
                </li>
              ))}
            </ol>
          </div>
          <p className="analytics-footnote">{answer.footer}</p>
        </>
      )}
    </section>
  );
}

// ─── Network ────────────────────────────────────────────────────────────────

/** The canvas's size, measured, settled a moment after it last changed, in whole points. */
function useCanvasSize(frame: RefObject<HTMLDivElement | null>) {
  const [size, setSize] = useState<{ width: number; height: number } | undefined>(undefined);
  useEffect(() => {
    const element = frame.current;
    if (!element) return;
    let timer: ReturnType<typeof setTimeout> | undefined;
    const observer = new ResizeObserver(([entry]) => {
      if (!entry) return;
      const width = Math.max(200, Math.round(entry.contentRect.width));
      const height = Math.max(150, Math.round(entry.contentRect.height));
      clearTimeout(timer);
      timer = setTimeout(() => setSize((last) => (last && last.width === width && last.height === height ? last : { width, height })), 120);
    });
    observer.observe(element);
    return () => {
      clearTimeout(timer);
      observer.disconnect();
    };
  }, [frame]);
  return size;
}

function NetworkMode({
  search,
  context,
  onChange,
  onCSV,
}: {
  search: ArchivalSearch;
  context: ArchivalContext;
  onChange: (fields: Partial<ArchivalSearch>, replace?: boolean) => void;
  onCSV: (asks: Parameters<typeof archivalCSV>[1]) => void;
}) {
  const frame = useRef<HTMLDivElement>(null);
  const size = useCanvasSize(frame);
  const [shown, setShown] = useState<string | undefined>(undefined);
  const [active, setActive] = useState<string | undefined>(undefined);
  const [resetToken, setResetToken] = useState(0);
  const [picking, setPicking] = useState(false);
  const takeFocus = useRef(false);
  const measure = search.measure ?? stored(archivalKeys.measure) ?? undefined;
  const threshold = search.threshold !== undefined ? Number(search.threshold) : context.defaultThreshold;
  const ask: NetworkAsk = {
    focus: search.focus,
    measure,
    expansion: search.expansion,
    threshold: Number.isFinite(threshold) ? threshold : context.defaultThreshold,
    width: size?.width ?? 720,
    height: size?.height ?? 420,
    selected: shown,
    group: search.group,
    only: search.only === 'on',
  };
  const network = useQuery(networkQuery(ask, size !== undefined && !context.networkUnavailable));
  const answer = network.data;
  const trail = search.trail ? search.trail.split('\u001f') : [];
  const ids = { measure: useId(), expansion: useId(), threshold: useId() };
  // A new focus is a new graph, whose selection starts empty (`recentre(on:)`).
  const [lastFocus, setLastFocus] = useState(answer?.focus?.id);
  if (answer?.focus?.id !== undefined && lastFocus !== answer.focus.id) {
    setLastFocus(answer.focus.id);
    setShown(undefined);
    setActive(undefined);
  }
  // A partner the rebuilt graph no longer holds is let go (`rebuild()`).
  if (answer && shown !== undefined && !answer.nodes.some((node) => node.id === shown) && !network.isPlaceholderData) {
    setShown(undefined);
  }

  if (context.networkUnavailable) return <Empty title={words.unavailableTitle} detail={context.networkUnavailable} />;

  /** Explores a collection: the focus moves to it, the last one onto the trail (`recentre(on:)`). */
  function recentre(id: string) {
    const current = answer?.focus?.id;
    takeFocus.current = true;
    setResetToken((token) => token + 1);
    onChange({ focus: id, trail: current && current !== id ? [...trail, current].join('\u001f') : search.trail });
  }

  function back() {
    const previous = trail[trail.length - 1];
    if (previous === undefined) return;
    takeFocus.current = true;
    onChange({ focus: previous, trail: trail.slice(0, -1).join('\u001f') || undefined });
  }

  /** A wedge selects its custodian's group, or clears it when it is the one selected (`sectorZones`). */
  function chooseSector(category: string) {
    setShown(undefined);
    onChange(search.group === category ? { group: undefined, only: undefined } : { group: category, only: undefined });
  }

  const node = answer?.dock.node;
  const group = answer?.dock.group;
  return (
    <section aria-label={words.network} className="archival-mode">
      <div className="analytics-filters">
        <button type="button" onClick={() => setPicking(true)} aria-haspopup="dialog">
          {words.focus}: {answer?.focus?.name ?? words.focusNone}
        </button>
        <div className="analytics-field">
          <label htmlFor={ids.measure}>{words.measure}</label>
          <select
            id={ids.measure}
            value={answer?.measure ?? measure ?? 'sharedVolumes'}
            disabled={answer ? !answer.usageAvailable : false}
            onChange={(event) => {
              store(archivalKeys.measure, event.target.value);
              onChange({ measure: event.target.value });
            }}
          >
            {context.measures.map((option) => (
              <option key={option.value} value={option.value}>
                {option.title}
              </option>
            ))}
          </select>
        </div>
        <div className="analytics-field">
          <label htmlFor={ids.expansion}>{words.umbrella}</label>
          <select
            id={ids.expansion}
            value={answer?.expansion ?? search.expansion ?? 'collapsed'}
            disabled={answer ? !answer.usageAvailable : false}
            onChange={(event) => onChange({ expansion: event.target.value === 'collapsed' ? undefined : event.target.value })}
          >
            {context.expansions.map((option) => (
              <option key={option.value} value={option.value}>
                {option.title}
              </option>
            ))}
          </select>
        </div>
        {group && (
          <button type="button" aria-label={group.clearLabel} onClick={() => onChange({ group: undefined, only: undefined })}>
            {words.group}: {group.name} ✕
          </button>
        )}
        {answer && answer.nodes.length > 0 && (
          <ExportMenu canExport={true} canDraw={false} onCSV={() => onCSV({ ...emptyAsks, network: ask })} />
        )}
        {trail.length > 0 && (
          <button type="button" onClick={back}>
            {words.back}
          </button>
        )}
      </div>
      <div className="archival-threshold">
        <label htmlFor={ids.threshold}>{words.threshold}</label>
        <input
          id={ids.threshold}
          type="range"
          min={context.thresholds[0]}
          max={context.thresholds[context.thresholds.length - 1]}
          step={0.05}
          value={ask.threshold}
          aria-label={words.thresholdA11y}
          aria-valuetext={answer?.thresholdText}
          onChange={(event) => onChange({ threshold: Number(event.target.value).toFixed(2) }, true)}
        />
        <span className="count">{answer?.thresholdText}</span>
      </div>
      {picking && (
        <FocusPicker
          query={(text) => networkCandidatesQuery(text, true)}
          onPick={(id) => {
            setPicking(false);
            recentre(id);
          }}
          onCancel={() => setPicking(false)}
        />
      )}
      {network.error ? (
        <Empty title={corpus.errorTitle} detail={errorMessage(network.error)} />
      ) : (
        <>
          <div className="person-network-tools">
            <button type="button" onClick={() => setResetToken((token) => token + 1)}>
              {words.resetView}
            </button>
          </div>
          <div className="analytics-pane">
            <div ref={frame} className="archival-network-frame">
              {answer?.empty ? (
                <Empty title={answer.empty.title} detail={answer.empty.detail} />
              ) : answer ? (
                <>
                  <Suspense fallback={<div className="network-cy" aria-hidden="true" />}>
                    <ArchivalNetworkCanvas
                      answer={answer}
                      shown={shown}
                      active={active}
                      group={search.group}
                      resetToken={resetToken}
                      onNode={(id) => setShown((current) => (current === id ? undefined : id))}
                      onSector={chooseSector}
                    />
                  </Suspense>
                  <NodeList
                    answer={answer}
                    takeFocusRef={takeFocus}
                    active={active}
                    shown={shown}
                    onActive={setActive}
                    onActivate={(id) => setShown((current) => (current === id ? undefined : id))}
                    onClear={() => setShown(undefined)}
                  />
                </>
              ) : (
                <p className="analytics-loading" role="status">
                  {corpus.loading}
                </p>
              )}
            </div>
            {answer && !answer.empty && (
              <div className="person-dock archival-dock" aria-live="polite">
                {node ? (
                  <>
                    <h3>{node.name}</h3>
                    <p className="analytics-caption">{node.caption}</p>
                    <p className="analytics-caption">{node.detail}</p>
                    {node.isCollection ? (
                      <>
                        <button type="button" onClick={() => recentre(node.id)}>
                          {words.recentre}
                        </button>
                        <Link className="button" to="/archival-neighbors" search={{ collection: node.id }}>
                          {words.neighbors}
                        </Link>
                        <Link className="button" to="/archival-collection" search={{ id: node.id }}>
                          {words.openCollection}
                        </Link>
                      </>
                    ) : (
                      <Link className="button" to="/archival-neighbors" search={{ decimalClass: answer.nodes.find((each) => each.id === node.id)?.name ?? node.name }}>
                        {words.classNeighbors}
                      </Link>
                    )}
                  </>
                ) : group ? (
                  <>
                    <h3>{group.name}</h3>
                    <p className="analytics-caption">{group.caption}</p>
                    <p className="analytics-caption">{group.detail}</p>
                    {group.rescaled && <p className="analytics-note">{group.rescaled}</p>}
                    {group.toggle && (
                      <button type="button" aria-pressed={group.onlyThisGroup} onClick={() => onChange({ only: group.onlyThisGroup ? undefined : 'on' })}>
                        {group.toggle}
                      </button>
                    )}
                  </>
                ) : (
                  <>
                    <h3>{answer.dock.title}</h3>
                    <p className="analytics-caption">{answer.dock.summary}</p>
                    <ul className="graph-legend">
                      <li>
                        <span className="swatch" data-custodian="stateDepartment" aria-hidden="true" /> {answer.dock.legend[0]}
                      </li>
                      <li>
                        <span className="swatch square" data-custodian="stateDepartment" aria-hidden="true" /> {answer.dock.legend[1]}
                      </li>
                    </ul>
                  </>
                )}
                <div className="archival-sectors">
                  {answer.sectors.map((sector) => (
                    <button key={sector.category} type="button" aria-pressed={search.group === sector.category} title={words.sectorHint}
                            onClick={() => chooseSector(sector.category)}>
                      <span className="swatch" data-custodian={sector.category} aria-hidden="true" /> {sector.name}
                    </button>
                  ))}
                </div>
              </div>
            )}
          </div>
          {answer?.table && <DataTable table={answer.table} />}
        </>
      )}
    </section>
  );
}

/** The canvas's partners for the keyboard: a list box over the canvas, one stop, whose arrow keys walk the partners in
 *  the graph's order, each said by its name and its link, and whose Enter or Space shows the one reached in the dock. */
function NodeList({
  answer,
  takeFocusRef,
  active,
  shown,
  onActive,
  onActivate,
  onClear,
}: {
  answer: NetworkAnswer;
  takeFocusRef: RefObject<boolean>;
  active?: string;
  shown?: string;
  onActive: (id: string) => void;
  onActivate: (id: string) => void;
  onClear: () => void;
}) {
  const help = useId();
  const prefix = useId();
  const list = useRef<HTMLDivElement>(null);
  const nodes = answer.nodes;
  const index = Math.max(0, nodes.findIndex((node) => node.id === active));
  useEffect(() => {
    if (!takeFocusRef.current) return;
    takeFocusRef.current = false;
    list.current?.focus();
  }, [answer.focus?.id, takeFocusRef]);

  function onKeyDown(event: KeyboardEvent<HTMLDivElement>) {
    let next: number | undefined;
    switch (event.key) {
      case 'ArrowDown':
      case 'ArrowRight':
        next = Math.min(index + 1, nodes.length - 1);
        break;
      case 'ArrowUp':
      case 'ArrowLeft':
        next = Math.max(index - 1, 0);
        break;
      case 'Home':
        next = 0;
        break;
      case 'End':
        next = nodes.length - 1;
        break;
      case 'Enter':
      case ' ': {
        event.preventDefault();
        const node = nodes[index];
        if (node) {
          onActive(node.id);
          onActivate(node.id);
        }
        return;
      }
      case 'Escape':
        if (shown !== undefined) {
          event.preventDefault();
          onClear();
        }
        return;
      default:
        return;
    }
    event.preventDefault();
    const reached = nodes[next];
    if (reached) onActive(reached.id);
  }

  return (
    <>
      <div
        ref={list}
        role="listbox"
        tabIndex={0}
        className="graph-keys"
        aria-label={words.canvas(answer.focus?.name ?? '')}
        aria-describedby={help}
        aria-activedescendant={nodes.length > 0 ? `${prefix}-${index}` : undefined}
        onKeyDown={onKeyDown}
        onFocus={() => {
          if (active === undefined && nodes[0]) onActive(nodes[0].id);
        }}
      >
        {nodes.map((node, at) => (
          <div
            key={node.id}
            role="option"
            id={`${prefix}-${at}`}
            aria-selected={shown === node.id}
            className="graph-option"
            onClick={() => {
              onActive(node.id);
              onActivate(node.id);
            }}
          >
            {node.label}, {node.accessibilityValue}
          </div>
        ))}
      </div>
      <p id={help} className="visually-hidden">
        {words.canvasHelp}
      </p>
    </>
  );
}

/** The focus picker (`focusPicker`): a search field over the candidates, most cited first, the first two hundred. */
function FocusPicker({
  query,
  onPick,
  onCancel,
}: {
  query: (text: string) => ReturnType<typeof networkCandidatesQuery>;
  onPick: (id: string) => void;
  onCancel: () => void;
}) {
  const [text, setText] = useState('');
  const candidates = useQuery(query(text));
  const field = useRef<HTMLInputElement>(null);
  const fieldId = useId();
  const heading = useId();
  useEffect(() => field.current?.focus(), []);
  const answer = candidates.data;
  return (
    <section className="archival-picker" role="dialog" aria-labelledby={heading}
             onKeyDown={(event) => {
               if (event.key === 'Escape') {
                 event.preventDefault();
                 onCancel();
               }
             }}>
      <h3 id={heading}>{answer?.title ?? words.pickerTitle}</h3>
      <label htmlFor={fieldId} className="visually-hidden">
        {answer?.prompt ?? words.pickerPrompt}
      </label>
      <input ref={field} id={fieldId} type="search" value={text} placeholder={answer?.prompt ?? words.pickerPrompt}
             onChange={(event) => setText(event.target.value)} />
      <p className="visually-hidden" role="status">
        {answer ? words.candidateCount(answer.candidates.length) : ''}
      </p>
      <ul className="archival-candidates">
        {(answer?.candidates ?? []).map((candidate) => (
          <li key={candidate.id}>
            <button type="button" onClick={() => onPick(candidate.id)}>
              <span>{candidate.name}</span>
              <span className="analytics-caption">{candidate.caption}</span>
            </button>
          </li>
        ))}
      </ul>
      <button type="button" onClick={onCancel}>
        {words.cancel}
      </button>
    </section>
  );
}

// ─── Flows ──────────────────────────────────────────────────────────────────

function FlowsMode({
  search,
  context,
  onChange,
  onCSV,
}: {
  search: ArchivalSearch;
  context: ArchivalContext;
  onChange: (fields: Partial<ArchivalSearch>, replace?: boolean) => void;
  onCSV: (asks: Parameters<typeof archivalCSV>[1]) => void;
}) {
  const [selected, setSelected] = useState<string | undefined>(undefined);
  const [expanded, setExpanded] = useState(false);
  const [picking, setPicking] = useState(false);
  const ask: FlowsAsk = { layer: search.layer, focus: search.flowFocus, direction: search.direction, selected };
  const flows = useQuery(flowsQuery(ask));
  const answer = flows.data;
  const [shownFor, setShownFor] = useState(`${ask.layer}|${ask.focus}|${ask.direction}`);
  // A new layer, focus or direction starts with nothing selected and the remainder folded, as the view's do.
  if (shownFor !== `${ask.layer}|${ask.focus}|${ask.direction}`) {
    setShownFor(`${ask.layer}|${ask.focus}|${ask.direction}`);
    setSelected(undefined);
    setExpanded(false);
  }
  if (context.flowsUnavailable) return <Empty title={words.unavailableTitle} detail={context.flowsUnavailable} />;
  return (
    <section aria-label={words.flows} className="archival-mode">
      {answer && (
        <p className="analytics-caption archival-intro">{answer.intro}</p>
      )}
      <div className="analytics-filters">
        {context.layers.length > 0 && (
          <Segmented
            legend={words.layer}
            help={words.layer}
            name="archival-layer"
            value={answer?.layer ?? search.layer ?? 'betweenPrinted'}
            disabled={false}
            choices={context.layers.map((option) => ({ value: option.value, label: option.title }))}
            // A new layer clears the focus (`onChange(of: layer)`).
            onChange={(value) => onChange({ layer: value === 'betweenPrinted' ? undefined : value, flowFocus: undefined })}
          />
        )}
        <button type="button" onClick={() => setPicking(true)} aria-haspopup="dialog">
          {answer?.focusCaption ?? words.focus}: {answer?.focusValue}
        </button>
        {answer?.focus && (
          <>
            <button type="button" aria-label={answer.clearFocus} title={answer.clearFocus} onClick={() => onChange({ flowFocus: undefined })}>
              ✕
            </button>
            <Segmented
              legend={words.direction}
              help={words.direction}
              name="archival-direction"
              value={answer.direction}
              disabled={false}
              choices={context.directions.map((option) => ({ value: option.value, label: option.title }))}
              onChange={(value) => onChange({ direction: value === 'outgoing' ? undefined : value })}
            />
          </>
        )}
        <ExportMenu canExport={!!answer?.table} canDraw={false} onCSV={() => onCSV({ ...emptyAsks, flows: ask })} />
      </div>
      {picking && (
        <FocusPicker
          query={(text) => flowsCandidatesQuery(search.layer, text, true)}
          onPick={(id) => {
            setPicking(false);
            onChange({ flowFocus: id });
          }}
          onCancel={() => setPicking(false)}
        />
      )}
      {flows.error ? (
        <Empty title={corpus.errorTitle} detail={errorMessage(flows.error)} />
      ) : !answer ? (
        <p className="analytics-loading" role="status">
          {corpus.loading}
        </p>
      ) : (
        <div className="analytics-result" aria-busy={flows.isPlaceholderData || undefined}>
          {answer.corpusWide && (
            <div className="archival-pairs">
              <h2>{answer.corpusWide.title}</h2>
              <p className="analytics-caption">{answer.corpusWide.caption}</p>
              <ol>
                {answer.corpusWide.pairs.map((pair, index) => (
                  <li key={index} aria-label={pair.accessibilityLabel}>
                    <span className="swatch" data-custodian={pair.source.category} aria-hidden="true" /> {pair.source.label}{' '}
                    <span aria-hidden="true">→</span> <span className="swatch" data-custodian={pair.target.category} aria-hidden="true" />{' '}
                    {pair.target.label} <span className="count">{pair.count.toLocaleString('en-US')}</span>
                  </li>
                ))}
              </ol>
            </div>
          )}
          {answer.none && <Empty title={answer.none.title} detail={answer.none.detail} />}
          {answer.diagram && (
            <FlowsDiagram
              diagram={answer.diagram}
              selected={selected}
              expanded={expanded}
              onSelect={(endpoint) => {
                if (endpoint.isRemainder) setExpanded((open) => !open);
                else setSelected((current) => (current === endpoint.id ? undefined : endpoint.id));
              }}
            />
          )}
          {answer.card && (
            <div className="person-dock archival-card" aria-live="polite">
              <h3>{answer.card.title}</h3>
              <p className="analytics-caption">{answer.card.detail}</p>
              {answer.card.collectionId && (
                <>
                  <Link className="button" to="/archival-neighbors" search={{ collection: answer.card.collectionId }}>
                    {answer.card.neighbors}
                  </Link>
                  <Link className="button" to="/archival-collection" search={{ id: answer.card.collectionId }}>
                    {answer.card.openCollection}
                  </Link>
                </>
              )}
            </div>
          )}
          <div className="archival-caveats">
            <h3>{answer.caveats.title}</h3>
            {answer.caveats.lines.map((line) => (
              <p key={line} className="analytics-note">
                {line}
              </p>
            ))}
          </div>
          {answer.table && <DataTable table={answer.table} />}
        </div>
      )}
    </section>
  );
}

/** The ribbon diagram (`diagramCard`): the focus's block on the left, each destination's on the right, a ribbon to each as
 *  thick as its share of the largest, the blocks buttons that select a hand-off or unfold the remainder. */
function FlowsDiagram({
  diagram,
  selected,
  expanded,
  onSelect,
}: {
  diagram: NonNullable<FlowsAnswer['diagram']>;
  selected?: string;
  expanded: boolean;
  onSelect: (endpoint: FlowEndpoint) => void;
}) {
  const frame = useRef<HTMLDivElement>(null);
  const [width, setWidth] = useState(640);
  useEffect(() => {
    const element = frame.current;
    if (!element) return;
    const observer = new ResizeObserver(([entry]) => entry && setWidth(Math.max(320, Math.round(entry.contentRect.width))));
    observer.observe(element);
    return () => observer.disconnect();
  }, []);
  const height = diagramHeight(diagram.endpoints.length);
  const frames = blockFrames(diagram.endpoints, width);
  const origin = focusFrame(diagram.endpoints.length, width, height);
  const maxCount = Math.max(1, ...diagram.endpoints.map((endpoint) => endpoint.count));
  return (
    <div className="archival-diagram">
      <div className="analytics-section-head">
        <h2>{diagram.title}</h2>
        <span className="analytics-caption">{diagram.countLabel}</span>
      </div>
      <p className="analytics-caption">
        <Markdown body={diagram.caption} />
      </p>
      <div ref={frame} className="archival-diagram-frame" style={{ height }}>
        <svg width={width} height={height} aria-hidden="true">
          <rect x={origin.x} y={origin.y} width={origin.width} height={origin.height} rx={8}
                fill={custodianColors[diagram.focusCategory] ?? custodianColors.otherInstitution} fillOpacity={0.18} />
          {diagram.endpoints.map((endpoint) => {
            const block = frames.get(endpoint.id);
            if (!block) return null;
            return (
              <path key={endpoint.id} d={ribbonPath(origin, block, endpoint.count, maxCount)}
                    fill={custodianColors[endpoint.category] ?? '#8E8E93'} fillOpacity={ribbonOpacity(selected === endpoint.id)} />
            );
          })}
        </svg>
        <div className="archival-focus-block" style={{ left: origin.x, top: origin.y, width: origin.width, height: origin.height }}>
          <strong>{diagram.focusName}</strong>
          <span className="count">{diagram.focusTotal}</span>
        </div>
        {diagram.endpoints.map((endpoint) => {
          const block = frames.get(endpoint.id);
          if (!block) return null;
          return (
            <button
              key={endpoint.id}
              type="button"
              className={endpoint.isRemainder ? 'archival-block remainder' : 'archival-block'}
              data-custodian={endpoint.category}
              style={{ left: block.x, top: block.y, width: block.width, height: block.height }}
              aria-pressed={endpoint.isRemainder ? undefined : selected === endpoint.id}
              aria-expanded={endpoint.isRemainder ? expanded : undefined}
              aria-label={`${endpoint.label}, ${endpoint.accessibilityValue}`}
              title={endpoint.hint}
              onClick={() => onSelect(endpoint)}
            >
              <span className="label">
                {endpoint.label}
                {endpoint.repository && <span className="repository">{endpoint.repository}</span>}
              </span>
              <span className="count">{endpoint.count.toLocaleString('en-US')}</span>
            </button>
          );
        })}
      </div>
      {expanded && diagram.remainder.length > 0 && (
        <div className="archival-remainder">
          <h3>{diagram.remainderTitle}</h3>
          <ul>
            {diagram.remainder.map((endpoint) => (
              <li key={endpoint.id}>
                <span className="swatch" data-custodian={endpoint.category} aria-hidden="true" /> {endpoint.label}{' '}
                <span className="count">{endpoint.count.toLocaleString('en-US')}</span>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}

// ─── Your Library ───────────────────────────────────────────────────────────

function LibraryMode({ onCSV }: { onCSV: (chart: ArchivalChart) => void }) {
  const scheme = useScheme();
  const library = useQuery(libraryQuery);
  const answer = library.data;
  const composition = useMemo(() => (answer ? compositionSpec(answer.composition, scheme === 'dark') : undefined), [answer, scheme]);
  const bands = useMemo(() => (answer ? bandsSpec(answer.bands, scheme === 'dark') : undefined), [answer, scheme]);
  const unavailable = library.error instanceof ApiError && library.error.code === 'INDEX_NOT_READY';
  if (unavailable) return <Empty title={words.libraryEmptyTitle} detail={words.libraryEmptyDetail} />;
  if (library.error) return <Empty title={corpus.errorTitle} detail={errorMessage(library.error)} />;
  if (!answer) {
    return (
      <p className="analytics-loading" role="status">
        {words.loadingLibrary}
      </p>
    );
  }
  if (answer.empty) return <Empty title={answer.empty.title} detail={answer.empty.detail} />;
  return (
    <section aria-label={words.yourLibrary} className="archival-mode">
      <p className="analytics-caption archival-intro">
        <Markdown body={answer.intro} />
      </p>
      <div className="analytics-result">
        <div className="analytics-section-head">
          <h2>{answer.composition.title}</h2>
          <ExportMenu canExport={answer.composition.table.rows.length > 0} canDraw={false} onCSV={() => onCSV('composition')} />
        </div>
        <p className="analytics-caption">{answer.composition.caption}</p>
        <div className="analytics-pane">
          <Suspense fallback={<div className="analytics-chart" aria-hidden="true" />}>
            {composition && <VegaChart spec={composition} label={words.chartDescription(answer.composition.title)} />}
          </Suspense>
          <DataTable table={answer.composition.table} />
        </div>
      </div>
      <div className="analytics-result">
        <div className="analytics-section-head">
          <h2>{answer.bands.title}</h2>
          <ExportMenu canExport={answer.bands.table.rows.length > 0} canDraw={false} onCSV={() => onCSV('bands')} />
        </div>
        <p className="analytics-caption">{answer.bands.caption}</p>
        <div className="analytics-pane">
          <Suspense fallback={<div className="analytics-chart" aria-hidden="true" />}>
            {bands && <VegaChart spec={bands} label={words.chartDescription(answer.bands.title)} />}
          </Suspense>
          <DataTable table={answer.bands.table} />
        </div>
      </div>
      <div className="analytics-result">
        <div className="analytics-section-head">
          <h2>{answer.collections.title}</h2>
          <ExportMenu canExport={answer.collections.table.rows.length > 0} canDraw={false} onCSV={() => onCSV('collections')} />
        </div>
        <p className="analytics-caption">{answer.collections.caption}</p>
        {answer.collections.empty ? (
          <p className="analytics-note">{answer.collections.empty}</p>
        ) : (
          <ul className="archival-library-collections">
            {answer.collections.rows.map((row) => (
              <li key={row.id}>
                <Link to="/archival-neighbors" search={{ collection: row.id }} title={answer.collections.hint}>
                  <span>{row.name}</span>
                  {row.repository && <span className="analytics-caption"> {row.repository}</span>}
                </Link>{' '}
                <span className="count">{row.count}</span>
              </li>
            ))}
          </ul>
        )}
      </div>
      <div className="archival-caveats">
        <h3>{answer.footer.title}</h3>
        {answer.footer.lines.map((line) => (
          <p key={line} className="analytics-note">
            {line}
          </p>
        ))}
      </div>
    </section>
  );
}

