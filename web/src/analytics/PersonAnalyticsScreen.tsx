// Person Analytics (PLAN's S24g), at /analytics/people: the app's `PersonAnalyticsView` as a page. Its Mode, Trends or
// Network; the scope and the year range; Most-Mentioned People, whose bars and rows add a person to the comparison or
// take them out; Mention Trajectories with its add field, chips, By decade, Values and Export, and Relationship Dynamics
// for two people; and the co-mention network around one person, drawn by Cytoscape with its Focus bar, dock and legend.
// Every series, word and table is the kit's or the view's, from the server; each chart is drawn by Vega-Lite with its
// table beside it, its CSV from the server and its figure, PNG or SVG, drawn here with the kit's caption band. The web's
// own: the charts and their tables at once, where the app switches between them; the state in the address, so Back
// returns to a comparison or a focus as it was; Values kept in this browser under the app's own key; and the network's
// canvas one keyboard stop, a list box over it, as the cross-reference graph's is.
import { useQuery } from '@tanstack/react-query';
import { getRouteApi, Link } from '@tanstack/react-router';
import { type KeyboardEvent, lazy, type ReactNode, Suspense, useId, useMemo, useState } from 'react';
import { analyticsContextQuery, type AnalyticsContext, type AnalyticsScope } from '../api/analytics';
import { ApiError, errorMessage } from '../api/client';
import {
  networkQuery,
  type NetworkAnswer,
  type NetworkNode,
  type PersonAnswer,
  type PersonAsk,
  type PersonChart,
  personAnalyticsQuery,
  personCSV,
  personMatchesQuery,
  personPlate,
} from '../api/personAnalytics';
import { volumeScopesQuery } from '../api/searchSets';
import { meQuery } from '../api/userData';
import { copy } from '../copy';
import { useScheme } from '../shell/AppShell';
import { useHeadingReady } from '../shell/headingFocus';
import { MenuButton } from '../shell/MenuButton';
import { saveFile } from '../shell/saveFile';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import { addressScope, figureSpec, scopeFields, scopeGroups, scopeValue, store, stored } from './analyticsRules';
import { Empty, ScopeOptions, Segmented, YearRange } from './CorpusAnalyticsScreen';
import {
  maxComparisonPeople,
  type PeopleSearch,
  personColor,
  personRankingSpec,
  relationshipSpec,
  shownMatches,
  trajectorySpec,
} from './personReferenceRules';

const route = getRouteApi('/analytics/people');
const words = copy.personAnalytics;
const corpus = copy.corpusAnalytics;

/** The app's key for Values, which its devices keep (`PersonTrajectoryNormalization.storageKey`). */
const valuesKey = 'frus.personAnalytics.normalizationMode';

/** Vega-Lite and Cytoscape, which only the analytics pages draw with, loaded with them rather than with the app. */
const VegaChart = lazy(() => import('./VegaChart').then((module) => ({ default: module.VegaChart })));
const NetworkCanvas = lazy(() => import('./NetworkCanvas').then((module) => ({ default: module.NetworkCanvas })));

export function PersonAnalyticsScreen() {
  const search = route.useSearch();
  const navigate = route.useNavigate();
  const context = useQuery(analyticsContextQuery);
  const me = useQuery(meQuery);
  const scopes = useQuery({ ...volumeScopesQuery, enabled: me.data?.userData === true });
  const scope = addressScope({
    subseries: search.subseries, volume: search.volume, topic: search.topic, subtopic: search.subtopic,
    volumes: search.volumes, scopeLabel: search.scopeLabel,
  });
  const values = search.values ?? (stored(valuesKey) === 'percentOfDocuments' ? 'percentOfDocuments' : 'raw');
  const ask: PersonAsk = { from: search.from, to: search.to, scope, people: search.people ?? [], decade: search.decade === 'on', values };
  const people = useQuery(personAnalyticsQuery(ask));
  const network = search.mode === 'network';
  useDocumentTitle(words.title);
  useHeadingReady(!context.isPending);

  /** A change of the page's state, as a new entry of the address. */
  function change(fields: Partial<PeopleSearch>) {
    void navigate({ search: (previous) => ({ ...previous, ...fields }) });
  }

  const unavailable = context.error instanceof ApiError && context.error.code === 'INDEX_NOT_READY';
  const modeId = useId();
  return (
    <div className="analytics-page person-analytics">
      <h1 tabIndex={-1} data-loading={context.isPending ? 'true' : undefined}>
        {words.title}
      </h1>
      {unavailable ? (
        <Empty title={words.unavailableTitle} detail={words.unavailableDetail} />
      ) : context.error ? (
        <Empty title={corpus.errorTitle} detail={errorMessage(context.error)} />
      ) : (
        <>
          <div className="analytics-options" id={modeId}>
            <Segmented
              legend={words.mode}
              help={words.modeHelp}
              name="mode"
              value={network ? 'network' : 'trends'}
              disabled={false}
              choices={[
                { value: 'trends', label: words.trends },
                { value: 'network', label: words.network },
              ]}
              onChange={(value) => change({ mode: value === 'network' ? 'network' : undefined })}
            />
          </div>
          {context.data && (
            <Filters search={search} scope={scope} answer={people.data} context={context.data} scopes={scopes.data?.items}
                     showYears={!network} onChange={change} />
          )}
          {people.error ? (
            <Empty title={corpus.errorTitle} detail={errorMessage(people.error)} />
          ) : !people.data ? (
            <p className="analytics-loading" role="status">
              {corpus.loading}
            </p>
          ) : network ? (
            <NetworkMode search={search} scope={scope} answer={people.data} onChange={change} />
          ) : (
            <Trends ask={ask} answer={people.data} busy={people.isPlaceholderData} onChange={change} />
          )}
        </>
      )}
    </div>
  );
}

/** The scope and, in Trends, the year range, applied to every query (#189-B). */
function Filters({
  search,
  scope,
  answer,
  context,
  scopes,
  showYears,
  onChange,
}: {
  search: PeopleSearch;
  scope: AnalyticsScope | undefined;
  answer: PersonAnswer | undefined;
  context: AnalyticsContext;
  scopes: Parameters<typeof scopeGroups>[1];
  showYears: boolean;
  onChange: (fields: Partial<PeopleSearch>) => void;
}) {
  const groups = useMemo(() => scopeGroups(context, scopes), [context, scopes]);
  const chosen = scopeValue(scope);
  const options = groups.flatMap((group) => group.options);
  const missing = !options.some((option) => option.value === chosen);
  const start = search.from ?? context.floorYear;
  const end = search.to ?? context.corpusMaxYear;
  const scopeId = useId();
  return (
    <div className="analytics-filters">
      <div className="analytics-field">
        <label htmlFor={scopeId}>{corpus.scope}</label>
        <select
          id={scopeId}
          value={chosen}
          title={corpus.scopeHelp}
          onChange={(event) => {
            const option = options.find((each) => each.value === event.target.value);
            if (option && !option.disabled) onChange(scopeFields(option.scope as AnalyticsScope | undefined));
          }}
        >
          {missing && <option value={chosen}>{answer?.scope.label ?? corpus.wholeCorpus}</option>}
          {groups.map((group, index) => (
            <ScopeOptions key={`${group.label}-${index}`} group={group} />
          ))}
        </select>
      </div>
      {showYears && (
        <YearRange
          start={start}
          end={end}
          context={context}
          disabled={false}
          isCustom={start !== context.floorYear || end !== context.corpusMaxYear}
          onChange={(from, to) => onChange({ from, to })}
        />
      )}
    </div>
  );
}

/** Exports a chart's CSV, or draws its figure with the kit's caption band. */
function useExport(ask: PersonAsk) {
  const [failure, setFailure] = useState<string | undefined>(undefined);
  async function csv(chart: PersonChart) {
    setFailure(undefined);
    try {
      const file = await personCSV(ask, chart);
      saveFile(file.blob, file.name);
    } catch (error) {
      setFailure(errorMessage(error));
    }
  }
  async function figure(chart: PersonChart, spec: Record<string, unknown>, legend: { title: string; label: string; color: string }[], format: 'png' | 'svg') {
    setFailure(undefined);
    try {
      const [{ renderFigure }, plate] = await Promise.all([import('./VegaChart'), personPlate(ask, chart)]);
      saveFile(await renderFigure(figureSpec(spec, plate, legend), format), `${plate.fileName}.${format}`);
    } catch (error) {
      setFailure(error instanceof ApiError ? errorMessage(error) : corpus.renderError);
    }
  }
  return { failure, csv, figure };
}

/** The Trends dashboard: the ranking, the comparison and, for two, the relationship. */
function Trends({ ask, answer, busy, onChange }: { ask: PersonAsk; answer: PersonAnswer; busy: boolean; onChange: (fields: Partial<PeopleSearch>) => void }) {
  const dark = useScheme() === 'dark';
  const exports = useExport(ask);
  const selected = answer.comparison.people;
  const isSelected = (rollupId: number) => ask.people.includes(rollupId);
  const rankingId = useId();
  const comparisonId = useId();

  /** A ranked person toggles in the comparison (`toggleSelection`), which holds at most five. */
  function toggle(rollupId: number) {
    if (isSelected(rollupId)) onChange({ people: ask.people.filter((id) => id !== rollupId) });
    else if (ask.people.length < maxComparisonPeople) onChange({ people: [...ask.people, rollupId] });
  }

  const rankingSpec = useMemo(
    () => personRankingSpec(answer, { person: words.person, mentions: words.mentions, description: words.chartDescription(answer.ranking.heading) }, dark),
    [answer, dark],
  );
  const lines = useMemo(() => trajectorySpec(answer, { person: words.person, description: words.chartDescription(answer.comparison.heading) }, dark), [answer, dark]);
  const together = useMemo(
    () => (answer.relationship ? relationshipSpec(answer, words.chartDescription(answer.relationship.heading), dark) : undefined),
    [answer, dark],
  );
  const legend = selected.map((person) => ({ title: person.name, label: person.name, color: personColor(selected, person.rollupId) }));

  return (
    <>
      {exports.failure && (
        <div className="analytics-alert" role="alert">
          <strong>{corpus.exportFailed}</strong> {exports.failure}
        </div>
      )}
      <section className="analytics-result" aria-labelledby={rankingId} aria-busy={busy || undefined}>
        <div className="analytics-section-head">
          <h2 id={rankingId}>{answer.ranking.heading}</h2>
          <ExportMenu
            canExport={answer.ranking.rows.length > 0}
            canDraw={answer.ranking.rows.length > 0 && !busy}
            onCSV={() => void exports.csv('ranking')}
            onFigure={(format) => void exports.figure('ranking', personRankingSpec(answer, { person: words.person, mentions: words.mentions, description: '' }, false), [], format)}
          />
        </div>
        <p className="analytics-caption">{answer.ranking.subtitle}</p>
        {answer.ranking.empty ? (
          <Empty title={answer.ranking.empty.title} detail={answer.ranking.empty.detail} />
        ) : (
          <div className="analytics-pane">
            <div className="analytics-figure">
              <Suspense fallback={<div className="analytics-chart" aria-hidden="true" />}>
                <VegaChart
                  spec={rankingSpec}
                  label={words.chartDescription(answer.ranking.heading)}
                  onChoose={(datum) => {
                    const row = answer.ranking.rows[Number(datum.index)];
                    if (row) toggle(row.rollupId);
                  }}
                />
              </Suspense>
            </div>
            <DataTable
              table={answer.ranking.table}
              cell={(row, column, text) => {
                const ranked = answer.ranking.rows[row];
                if (column !== 1 || !ranked) return text;
                const on = isSelected(ranked.rollupId);
                return (
                  <button
                    type="button"
                    className="link"
                    aria-pressed={on}
                    disabled={!on && ask.people.length >= maxComparisonPeople}
                    title={words.compare(ranked.name)}
                    onClick={() => toggle(ranked.rollupId)}
                  >
                    {text}
                  </button>
                );
              }}
            />
          </div>
        )}
      </section>
      <section className="analytics-result" aria-labelledby={comparisonId} aria-busy={busy || undefined}>
        <div className="analytics-section-head">
          <h2 id={comparisonId}>{answer.comparison.heading}</h2>
        </div>
        <AddPerson
          placeholder={words.addPlaceholder}
          disabled={answer.comparison.atCap}
          isChosen={isSelected}
          onPick={(rollupId) => toggle(rollupId)}
        />
        {answer.comparison.atCap && <p className="analytics-note">{answer.comparison.capNote}</p>}
        {selected.length > 0 && (
          <ul className="person-chips" aria-label={answer.comparison.heading}>
            {selected.map((person) => (
              <li key={person.rollupId}>
                <span className="swatch" style={{ background: personColor(selected, person.rollupId) }} aria-hidden="true" />
                <Link to="/search" search={{ personRollupId: String(person.rollupId), personLabel: person.name }} title={words.findMentions}>
                  {person.name}
                </Link>
                <button
                  type="button"
                  className="person-chip-remove"
                  aria-label={words.removeFromComparison(person.name)}
                  onClick={() => onChange({ people: ask.people.filter((id) => id !== person.rollupId) })}
                >
                  <span aria-hidden="true">✕</span>
                </button>
              </li>
            ))}
          </ul>
        )}
        <div className="analytics-options">
          <label className="analytics-check" title={words.byDecadeHelp}>
            <input type="checkbox" checked={ask.decade} onChange={(event) => onChange({ decade: event.target.checked ? 'on' : undefined })} />
            {words.byDecade}
          </label>
          <Segmented
            legend={words.values}
            help={words.valuesHelp}
            name="values"
            value={ask.values}
            disabled={selected.length === 0}
            choices={[
              { value: 'raw', label: words.raw },
              { value: 'percentOfDocuments', label: words.percent },
            ]}
            onChange={(value) => {
              store(valuesKey, value);
              onChange({ values: value === 'percentOfDocuments' ? 'percentOfDocuments' : undefined });
            }}
          />
          <ExportMenu
            canExport={selected.length > 0}
            canDraw={selected.length > 0 && !busy}
            onCSV={() => void exports.csv('trajectories')}
            onFigure={(format) => void exports.figure('trajectories', trajectorySpec(answer, { person: words.person, description: '' }, false), legend, format)}
          />
          {answer.relationship && (
            <button type="button" title={words.exportRelationshipHelp} onClick={() => void exports.csv('relationship')}>
              {words.exportRelationship}
            </button>
          )}
        </div>
        {selected.length === 0 ? (
          <p className="analytics-caption">{answer.comparison.prompt}</p>
        ) : answer.comparison.empty ? (
          <Empty title={answer.comparison.empty.title} detail={answer.comparison.empty.detail} />
        ) : (
          <div className="analytics-pane">
            <div className="analytics-figure">
              <Suspense fallback={<div className="analytics-chart" aria-hidden="true" />}>
                <VegaChart spec={lines} label={words.chartDescription(answer.comparison.heading)} />
              </Suspense>
              <p className="analytics-caption">{answer.comparison.caption}</p>
            </div>
            <DataTable table={answer.comparison.table} />
          </div>
        )}
        {answer.relationship && (
          <div className="person-relationship">
            <h3>{answer.relationship.heading}</h3>
            <p className="analytics-caption">{answer.relationship.subtitle}</p>
            {answer.relationship.empty ? (
              <Empty title={answer.relationship.empty.title} detail={answer.relationship.empty.detail} />
            ) : (
              <div className="analytics-pane">
                <div className="analytics-figure">
                  <Suspense fallback={<div className="analytics-chart" aria-hidden="true" />}>
                    {together && <VegaChart spec={together} label={words.chartDescription(answer.relationship.heading)} />}
                  </Suspense>
                  <p className="analytics-caption">{answer.relationship.caption}</p>
                </div>
                <DataTable table={answer.relationship.table} />
              </div>
            )}
          </div>
        )}
      </section>
    </>
  );
}

/** A chart's Export menu: its CSV, and its figure as PNG or SVG once the chart asked for is on show. */
export function ExportMenu({
  canExport,
  canDraw,
  onCSV,
  onFigure,
}: {
  canExport: boolean;
  canDraw: boolean;
  onCSV: () => void;
  onFigure?: (format: 'png' | 'svg') => void;
}) {
  return (
    <MenuButton
      label={corpus.export}
      accessibleLabel={corpus.export}
      entries={[
        { kind: 'item', label: corpus.exportCSV, onSelect: onCSV, disabled: !canExport },
        ...(onFigure
          ? [
              { kind: 'item' as const, label: corpus.exportPNG, onSelect: () => onFigure('png'), disabled: !canDraw },
              { kind: 'item' as const, label: corpus.exportSVG, onSelect: () => onFigure('svg'), disabled: !canDraw },
            ]
          : []),
      ]}
    />
  );
}

/** A chart's table beside it, the kit's, in a region the keyboard reaches, since a long table scrolls within it. */
export function DataTable({
  table,
  cell,
}: {
  table: { title: string; columns: string[]; rows: string[][] };
  cell?: (row: number, column: number, text: string) => ReactNode;
}) {
  return (
    <div className="analytics-table" tabIndex={0} role="region" aria-label={`${table.title}: ${corpus.table}`}>
      <table>
        <caption>{table.title}</caption>
        <thead>
          <tr>
            {table.columns.map((column) => (
              <th key={column} scope="col">
                {column}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {table.rows.map((row, index) => (
            <tr key={`${row.join('|')}-${index}`}>
              {row.map((text, column) => (
                <td key={column}>{cell ? cell(index, column, text) : text}</td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

/** The add field and the focus search (`searchToAddField`, `networkFocusBar`): the people whose name holds what is typed,
 *  the first six, most mentioned first. */
function AddPerson({
  placeholder,
  disabled,
  isChosen,
  onPick,
}: {
  placeholder: string;
  disabled: boolean;
  isChosen: (rollupId: number) => boolean;
  onPick: (rollupId: number) => void;
}) {
  const [text, setText] = useState('');
  const matches = useQuery(personMatchesQuery(disabled ? '' : text));
  const fieldId = useId();
  const listId = useId();
  const shown = text.trim() === '' ? [] : (matches.data?.people ?? []).slice(0, shownMatches);
  return (
    <div className="person-add">
      <label htmlFor={fieldId} className="visually-hidden">
        {placeholder}
      </label>
      <input
        id={fieldId}
        type="search"
        value={text}
        placeholder={placeholder}
        disabled={disabled}
        aria-controls={listId}
        onChange={(event) => setText(event.target.value)}
      />
      <ul id={listId} className="person-matches" aria-label={words.matches} hidden={shown.length === 0}>
        {shown.map((match) => (
          <li key={match.rollupId}>
            <button
              type="button"
              disabled={isChosen(match.rollupId)}
              onClick={() => {
                onPick(match.rollupId);
                setText('');
              }}
            >
              <span>{match.name}</span> <span className="count">{match.mentions.toLocaleString('en-US')}</span>
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
}

/** Network mode: the Focus bar and the co-mention network around the person picked, else the ranking's first. */
function NetworkMode({
  search,
  scope,
  answer,
  onChange,
}: {
  search: PeopleSearch;
  scope: AnalyticsScope | undefined;
  answer: PersonAnswer;
  onChange: (fields: Partial<PeopleSearch>) => void;
}) {
  const focus = search.focus ?? answer.ranking.rows[0]?.rollupId;
  const network = useQuery(networkQuery(focus, scope));
  // Explore connections' trail, which Back walks (`history`): the people the network was centred on before.
  const [history, setHistory] = useState<number[]>([]);
  const graph = network.data && network.data.focus.rollupId === focus ? network.data : undefined;
  return (
    <section className="analytics-result person-network" aria-label={words.network}>
      <div className="person-focus">
        <p>
          <strong>{words.focusLabel}</strong> {graph?.focus.name ?? (focus === undefined ? words.focusNone : '')}
        </p>
        <AddPerson
          placeholder={words.focusPlaceholder}
          disabled={false}
          isChosen={() => false}
          onPick={(rollupId) => {
            setHistory([]);
            onChange({ focus: rollupId });
          }}
        />
      </div>
      {focus === undefined ? (
        <Empty title={words.noFocusTitle} detail={words.noFocusDetail} />
      ) : network.error ? (
        <Empty title={words.graphError} detail={errorMessage(network.error)} />
      ) : !graph ? (
        <p className="analytics-loading" role="status">
          {words.loadingNetwork}
        </p>
      ) : graph.state === 'empty' && graph.empty ? (
        <Empty title={graph.empty.title} detail={graph.empty.detail} />
      ) : (
        <Network
          answer={graph}
          canGoBack={history.length > 0}
          onBack={() => {
            const previous = history.at(-1);
            setHistory(history.slice(0, -1));
            if (previous !== undefined) onChange({ focus: previous });
          }}
          onExplore={(rollupId) => {
            setHistory([...history, graph.focus.rollupId]);
            onChange({ focus: rollupId });
          }}
        />
      )}
    </section>
  );
}

/** The network's canvas, its keyboard list box, its dock, its legend and its table. */
function Network({
  answer,
  canGoBack,
  onBack,
  onExplore,
}: {
  answer: NetworkAnswer;
  canGoBack: boolean;
  onBack: () => void;
  onExplore: (rollupId: number) => void;
}) {
  const partners = answer.nodes.filter((node) => !node.isFocus);
  const [shown, setShown] = useState<number | undefined>(undefined);
  const [active, setActive] = useState<number | undefined>(undefined);
  const [resetToken, setResetToken] = useState(0);
  const [lastFocus, setLastFocus] = useState(answer.focus.rollupId);
  // A new focus is a new graph, whose selection starts empty (`load`).
  if (lastFocus !== answer.focus.rollupId) {
    setLastFocus(answer.focus.rollupId);
    setShown(undefined);
    setActive(undefined);
  }
  const reducedMotion = typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches === true;
  const partner = partners.find((node) => node.rollupId === shown);
  /** A click or Enter on a partner shows it, or hides it when it is the one shown (`toggleSelection`). */
  const toggle = (rollupId: number) => setShown((current) => (current === rollupId ? undefined : rollupId));
  return (
    <>
      <div className="person-network-tools">
        {canGoBack && (
          <button type="button" onClick={onBack}>
            {words.back}
          </button>
        )}
        <button type="button" onClick={() => setResetToken((token) => token + 1)}>
          {words.resetView}
        </button>
      </div>
      <div className="analytics-pane">
        <div className="person-network-frame">
          <Suspense fallback={<div className="network-cy" aria-hidden="true" />}>
            <NetworkCanvas answer={answer} shown={shown} active={active} resetToken={resetToken} reducedMotion={reducedMotion} onPartner={toggle} />
          </Suspense>
          <PartnerList
            focus={answer.focus}
            partners={partners}
            active={active}
            shown={shown}
            onActive={setActive}
            onActivate={(node) => toggle(node.rollupId)}
            onClear={() => setShown(undefined)}
          />
        </div>
        <div className="person-dock" aria-live="polite">
          {partner ? (
            <>
              <h3>{partner.name}</h3>
              <p className="analytics-caption">{partner.sharedLine}</p>
              <button type="button" onClick={() => onExplore(partner.rollupId)}>
                {words.explore}
              </button>
              <Link className="button" to="/search" search={{ personRollupId: String(partner.rollupId), personLabel: partner.name }}>
                {words.openInSearch}
              </Link>
            </>
          ) : (
            <p className="analytics-caption">{words.dockEmpty}</p>
          )}
        </div>
      </div>
      <ul className="graph-legend">
        <li>
          <span className="swatch focus" aria-hidden="true" /> {words.legendFocus}
        </li>
        <li>
          <span className="swatch partner" aria-hidden="true" /> {words.legendPartner}
        </li>
      </ul>
      <p className="analytics-footnote">{answer.footer}</p>
      <DataTable
        table={{
          title: words.partnersTable,
          columns: [words.person, words.sharedDocuments],
          rows: partners.map((node) => [node.name, node.sharedWithFocus.toLocaleString('en-US')]),
        }}
      />
    </>
  );
}

/** The canvas's partners for the keyboard: a list box over the canvas, one stop, whose arrow keys move from partner to
 *  partner, most shared documents first, and whose Enter or Space shows the one reached in the dock, each said by its
 *  name and its shared documents with the focus, as the app's hit areas are. */
function PartnerList({
  focus,
  partners,
  active,
  shown,
  onActive,
  onActivate,
  onClear,
}: {
  focus: NetworkNode;
  partners: NetworkNode[];
  active?: number;
  shown?: number;
  onActive: (rollupId: number) => void;
  onActivate: (node: NetworkNode) => void;
  onClear: () => void;
}) {
  const help = useId();
  const prefix = useId();
  const index = Math.max(
    0,
    partners.findIndex((node) => node.rollupId === active),
  );

  function onKeyDown(event: KeyboardEvent<HTMLDivElement>) {
    let next: number | undefined;
    switch (event.key) {
      case 'ArrowDown':
      case 'ArrowRight':
        next = Math.min(index + 1, partners.length - 1);
        break;
      case 'ArrowUp':
      case 'ArrowLeft':
        next = Math.max(index - 1, 0);
        break;
      case 'Home':
        next = 0;
        break;
      case 'End':
        next = partners.length - 1;
        break;
      case 'Enter':
      case ' ': {
        event.preventDefault();
        const node = partners[index];
        if (node) {
          onActive(node.rollupId);
          onActivate(node);
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
    const reached = partners[next];
    if (reached) onActive(reached.rollupId);
  }

  return (
    <>
      <div
        role="listbox"
        tabIndex={0}
        className="graph-keys"
        aria-label={words.canvas(focus.name)}
        aria-describedby={help}
        aria-activedescendant={partners.length > 0 ? `${prefix}-${index}` : undefined}
        onKeyDown={onKeyDown}
        onFocus={() => {
          if (active === undefined && partners[0]) onActive(partners[0].rollupId);
        }}
      >
        {partners.map((node, at) => (
          <div
            key={node.rollupId}
            role="option"
            id={`${prefix}-${at}`}
            aria-selected={shown === node.rollupId}
            className="graph-option"
            onClick={() => {
              onActive(node.rollupId);
              onActivate(node);
            }}
          >
            {node.name}, {node.accessibilityValue}
          </div>
        ))}
      </div>
      <p id={help} className="visually-hidden">
        {words.canvasHelp}
      </p>
    </>
  );
}
