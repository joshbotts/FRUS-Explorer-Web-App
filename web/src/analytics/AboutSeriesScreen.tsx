// About the Series (PLAN's S24h), at /about: the four dashboards the app's Research Guide shows under About the Series,
// Production & Timeliness, Geographic Emphasis, Archival Sourcing and Administration Profiles, each a page of the guide
// there and a page of this one here, chosen by the address. Each dashboard's scope bar (`SeriesScopeBar`) and years
// (`AnalyticsYearRangeBar`), Archival Sourcing's categories and top collections, and Administration Profiles' editorial
// notes and detail are the app's; every series, word and table is the kit's or the dashboard's, from the server. Each
// chart is drawn by Vega-Lite with its table beside it, its CSV from the server with the kit's method block, and its
// figure, PNG or SVG, drawn here with the kit's caption band. The web's own: the pages in the address, and the header's
// Analytics menu reaching them, since the web has no Research Guide.
import { useQuery } from '@tanstack/react-query';
import { getRouteApi, Link } from '@tanstack/react-router';
import { lazy, Suspense, useEffect, useId, useMemo, useRef, useState } from 'react';
import {
  type AdministrationsAnswer,
  type SeriesAnswer,
  type SeriesAsk,
  type SeriesChart,
  type SeriesContext,
  type SeriesDashboard,
  seriesContextQuery,
  seriesCSV,
  seriesDashboards,
  seriesPlate,
  seriesQuery,
  type SeriesScope,
  type SourcingAnswer,
} from '../api/aboutSeries';
import type { AnalyticsContext } from '../api/analytics';
import { ApiError, errorMessage } from '../api/client';
import { volumeScopesQuery } from '../api/searchSets';
import { meQuery } from '../api/userData';
import { copy } from '../copy';
import { useScheme } from '../shell/AppShell';
import { useHeadingReady } from '../shell/headingFocus';
import { saveFile } from '../shell/saveFile';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import { figureSpec } from './analyticsRules';
import { type SeriesSearch, seriesLegend, seriesSpec } from './archivalRules';
import { Empty, YearRange } from './CorpusAnalyticsScreen';
import { DataTable, ExportMenu } from './PersonAnalyticsScreen';

const route = getRouteApi('/about');
const words = copy.aboutSeries;
const corpus = copy.corpusAnalytics;

const VegaChart = lazy(() => import('./VegaChart').then((module) => ({ default: module.VegaChart })));

/** The page the address names, Production & Timeliness when it names none. */
function dashboardOf(search: SeriesSearch): SeriesDashboard {
  return seriesDashboards.includes(search.page as SeriesDashboard) ? (search.page as SeriesDashboard) : 'production';
}

/** The scope the address names. */
function seriesScope(search: SeriesSearch): SeriesScope | undefined {
  if (search.subseries) return { kind: 'subseries', subseries: search.subseries };
  if (search.topic && search.subtopic) return { kind: 'topic', category: search.topic, subcategory: search.subtopic };
  if (search.volumes) return { kind: 'volumes', volumeIds: search.volumes.split(',').filter(Boolean), label: search.scopeLabel };
  return undefined;
}

const clearedScope = { subseries: undefined, topic: undefined, subtopic: undefined, volumes: undefined, scopeLabel: undefined };

export function AboutSeriesScreen() {
  const search = route.useSearch();
  const navigate = route.useNavigate();
  const context = useQuery(seriesContextQuery);
  const dashboard = dashboardOf(search);
  const page = context.data?.pages.find((each) => each.id === `series-${dashboard}`);
  useDocumentTitle(page ? `${page.title} – ${words.title}` : words.title);
  useHeadingReady(!context.isPending);

  function change(fields: Partial<SeriesSearch>, replace = false) {
    void navigate({ search: (previous) => ({ ...previous, ...fields }), replace });
  }

  return (
    <div className="analytics-page about-series">
      <h1 tabIndex={-1} data-loading={context.isPending ? 'true' : undefined}>
        {words.title}
      </h1>
      {context.error ? (
        <Empty title={corpus.errorTitle} detail={errorMessage(context.error)} />
      ) : !context.data || !page ? (
        <p className="analytics-loading" role="status">
          {corpus.loading}
        </p>
      ) : (
        <>
          <nav aria-label={words.pages} className="about-pages">
            <ul>
              {context.data.pages.map((each) => {
                const id = each.id.replace('series-', '');
                return (
                  <li key={each.id}>
                    <Link to="/about" search={{ page: id }} aria-current={id === dashboard ? 'page' : undefined}>
                      {each.title}
                    </Link>
                  </li>
                );
              })}
            </ul>
          </nav>
          <h2>{page.title}</h2>
          <p className="analytics-caption">{page.subtitle}</p>
          {/* Each page is a dashboard of its own, its years and scope its own, as each guide page's are. */}
          <Dashboard key={dashboard} dashboard={dashboard} search={search} context={context.data} defaultEnd={page.defaultEnd} onChange={change} />
        </>
      )}
    </div>
  );
}

function Dashboard({
  dashboard,
  search,
  context,
  defaultEnd,
  onChange,
}: {
  dashboard: SeriesDashboard;
  search: SeriesSearch;
  context: SeriesContext;
  defaultEnd: number;
  onChange: (fields: Partial<SeriesSearch>, replace?: boolean) => void;
}) {
  const scheme = useScheme();
  const scope = seriesScope(search);
  const ask: SeriesAsk = {
    from: search.from,
    to: search.to !== undefined ? Math.min(search.to, defaultEnd) : undefined,
    scope,
    hidden: dashboard === 'sourcing' && search.hidden ? search.hidden.split(',').filter(Boolean) : undefined,
    editorialNotes: dashboard === 'administrations' && search.notes === 'on',
    administration: dashboard === 'administrations' ? search.administration : undefined,
  };
  const series = useQuery(seriesQuery<SeriesAnswer>(dashboard, ask));
  const answer = series.data;
  const [failure, setFailure] = useState<string | undefined>(undefined);
  // The page opens on the most documented administration and keeps it as the years change (`onAppear`).
  const opened = useRef(false);
  useEffect(() => {
    if (opened.current || dashboard !== 'administrations' || search.administration) return;
    const focus = (answer as AdministrationsAnswer | undefined)?.detail?.focus;
    if (focus === undefined) return;
    opened.current = true;
    onChange({ administration: focus }, true);
  }, [answer, dashboard, search.administration, onChange]);

  async function csv(chart: SeriesChart) {
    setFailure(undefined);
    try {
      const file = await seriesCSV(dashboard, chart.id, ask);
      saveFile(file.blob, file.name);
    } catch (error) {
      setFailure(errorMessage(error));
    }
  }

  async function figure(chart: SeriesChart, format: 'png' | 'svg') {
    setFailure(undefined);
    try {
      const [{ renderFigure }, plate] = await Promise.all([import('./VegaChart'), seriesPlate(dashboard, chart.id, ask)]);
      const spec = seriesSpec(dashboard, chart, false);
      saveFile(await renderFigure(figureSpec(spec, plate, seriesLegend(dashboard, chart)), format), `${plate.fileName}.${format}`);
    } catch (error) {
      setFailure(error instanceof ApiError ? errorMessage(error) : corpus.renderError);
    }
  }

  if (series.error) return <Empty title={corpus.errorTitle} detail={errorMessage(series.error)} />;
  if (!answer) {
    return (
      <p className="analytics-loading" role="status">
        {corpus.loading}
      </p>
    );
  }
  if (answer.empty) return <Empty title={answer.empty.title} detail={answer.empty.lines.join(' ')} />;
  const sourcing = dashboard === 'sourcing' ? (answer as SourcingAnswer) : undefined;
  const administrations = dashboard === 'administrations' ? (answer as AdministrationsAnswer) : undefined;
  // The years' bar resets the scope too, but on Archival Sourcing (`yearRangeBar`'s `onReset`).
  const resetYears = () => onChange({ from: undefined, to: undefined, ...(dashboard === 'sourcing' ? {} : clearedScope) });
  return (
    <div className="about-dashboard" aria-busy={series.isPlaceholderData || undefined}>
      <p className="analytics-caption about-intro">{answer.intro}</p>
      <div className="analytics-filters">
        {(!sourcing || sourcing.supportsScope) && (
          <ScopeBar context={context} scope={scope} label={answer.frame.scopeLabel} isNarrowed={answer.frame.isNarrowed}
                    onScope={(fields) => onChange({ ...clearedScope, ...fields })}
                    onReset={() => onChange({ ...clearedScope, from: undefined, to: undefined })} />
        )}
        <YearRange
          start={answer.frame.start}
          end={answer.frame.end}
          context={{ earliestYear: context.earliestYear, floorYear: context.floorYear, corpusMaxYear: defaultEnd } as AnalyticsContext}
          disabled={false}
          isCustom={answer.frame.isCustomRange}
          onChange={(from, to) => onChange({ from, to })}
          onReset={resetYears}
        />
        {sourcing && <CategoryFilter answer={sourcing} hidden={ask.hidden ?? []} onHidden={(hidden) => onChange({ hidden: hidden.join(',') || undefined })} />}
      </div>
      {failure && (
        <div className="analytics-alert" role="alert">
          <strong>{corpus.exportFailed}</strong> {failure}
        </div>
      )}
      {administrations?.narrowedEmpty ? (
        <Empty title={administrations.narrowedEmpty.title} detail={administrations.narrowedEmpty.lines.join(' ')} />
      ) : (
        <>
          {administrations && (
            <div className="about-toggle">
              <label>
                <input type="checkbox" checked={administrations.toggle.isOn} onChange={(event) => onChange({ notes: event.target.checked ? 'on' : undefined })} />{' '}
                {administrations.toggle.title}
              </label>
              <p className="analytics-caption">{administrations.toggle.subtitle}</p>
            </div>
          )}
          {answer.charts.map((chart) => (
            <ChartCard key={chart.id} dashboard={dashboard} chart={chart} dark={scheme === 'dark'} busy={series.isPlaceholderData}
                       onCSV={() => void csv(chart)} onFigure={(format) => void figure(chart, format)} />
          ))}
          {sourcing && <TopCollections answer={sourcing} />}
          {sourcing && (
            <div className="about-link">
              <Link to="/analytics/archives">{sourcing.archivalLink}</Link>
              <p className="analytics-caption">{sourcing.archivalLinkDetail}</p>
            </div>
          )}
          {administrations?.detail && <AdministrationDetail detail={administrations.detail} onPick={(id) => onChange({ administration: id })} />}
          <div className="archival-caveats">
            <h3>{answer.caveats.title}</h3>
            {answer.caveats.lines.map((line) => (
              <p key={line} className="analytics-note">
                {line}
              </p>
            ))}
          </div>
        </>
      )}
    </div>
  );
}

/** A chart's card (`SeriesChartCard`): its title, Export, caption, and the chart with its table beside it. */
function ChartCard({
  dashboard,
  chart,
  dark,
  busy,
  onCSV,
  onFigure,
}: {
  dashboard: SeriesDashboard;
  chart: SeriesChart;
  dark: boolean;
  busy: boolean;
  onCSV: () => void;
  onFigure: (format: 'png' | 'svg') => void;
}) {
  const spec = useMemo(() => seriesSpec(dashboard, chart, dark), [dashboard, chart, dark]);
  const hasRows = (chart.table?.rows.length ?? 0) > 0;
  return (
    <section className="analytics-result" aria-label={chart.title}>
      <div className="analytics-section-head">
        <h3>{chart.title}</h3>
        <ExportMenu canExport={hasRows} canDraw={hasRows && !busy} onCSV={onCSV} onFigure={onFigure} />
      </div>
      {chart.caption.split('\n\n').map((paragraph) => (
        <p key={paragraph} className="analytics-caption">
          {paragraph}
        </p>
      ))}
      <div className="analytics-pane">
        <div className="analytics-figure">
          <Suspense fallback={<div className="analytics-chart" aria-hidden="true" />}>
            <VegaChart spec={spec} label={words.chartDescription(chart.title)} />
          </Suspense>
        </div>
        {chart.table && <DataTable table={chart.table} />}
      </div>
    </section>
  );
}

/** The scope bar (`SeriesScopeBar`): Whole series; By Subseries, grouped by the decade a subseries begins in; My Volume
 *  Scopes, each resolved against the series; By Subject; and the button back to the whole series once narrowed. */
function ScopeBar({
  context,
  scope,
  label,
  isNarrowed,
  onScope,
  onReset,
}: {
  context: SeriesContext;
  scope: SeriesScope | undefined;
  label: string;
  isNarrowed: boolean;
  onScope: (fields: Partial<SeriesSearch>) => void;
  onReset: () => void;
}) {
  const me = useQuery(meQuery);
  const scopes = useQuery({ ...volumeScopesQuery, enabled: me.data?.userData === true });
  const fieldId = useId();
  const series = useMemo(() => new Set(context.seriesVolumeIds), [context.seriesVolumeIds]);
  const custom = useMemo(
    () =>
      [...(scopes.data?.items ?? [])]
        .sort((a, b) => a.name.localeCompare(b.name, 'en', { numeric: true }))
        .map((each) => ({ name: each.name, id: each.id, ids: each.volumeIds.filter((id) => series.has(id)).sort() })),
    [scopes.data, series],
  );
  const value =
    scope?.kind === 'subseries' ? `subseries:${scope.subseries}`
      : scope?.kind === 'topic' ? `topic:${scope.category}\u001f${scope.subcategory}`
        : scope?.kind === 'volumes' ? `volumes:${scope.volumeIds.join(',')}` : 'whole';

  function choose(chosen: string) {
    if (chosen === 'whole') onScope({});
    else if (chosen.startsWith('subseries:')) onScope({ subseries: chosen.slice(10) });
    else if (chosen.startsWith('topic:')) {
      const [category, subcategory] = chosen.slice(6).split('\u001f');
      onScope({ topic: category, subtopic: subcategory });
    } else if (chosen.startsWith('volumes:')) {
      const picked = custom.find((each) => `volumes:${each.ids.join(',')}` === chosen);
      if (picked) onScope({ volumes: picked.ids.join(','), scopeLabel: picked.name });
    }
  }

  return (
    <div className="analytics-field about-scope">
      <label htmlFor={fieldId}>{label}</label>
      <select id={fieldId} aria-label={words.scopeA11y} value={value} onChange={(event) => choose(event.target.value)}>
        <option value="whole">{words.wholeSeries}</option>
        {context.decades.map((decade) => (
          <optgroup key={decade.label} label={words.bySubseriesIn(decade.label)}>
            {decade.subseries.map((name) => (
              <option key={name} value={`subseries:${name}`}>
                {name}
              </option>
            ))}
          </optgroup>
        ))}
        {custom.length > 0 && (
          <optgroup label={words.customScopes}>
            {custom.map((each) =>
              each.ids.length > 0 ? (
                <option key={each.id} value={`volumes:${each.ids.join(',')}`}>
                  {words.customScope(each.name, each.ids.length)}
                </option>
              ) : (
                <option key={each.id} value={`none:${each.id}`} disabled>
                  {words.customScopeNone(each.name)}
                </option>
              ),
            )}
          </optgroup>
        )}
        {context.topics.map((topic) => (
          <optgroup key={topic.label} label={words.subjectGroup(topic.label)}>
            {topic.items.map((item) => (
              <option key={item} value={`topic:${topic.label}\u001f${item}`}>
                {item}
              </option>
            ))}
          </optgroup>
        ))}
      </select>
      {isNarrowed && (
        <button type="button" className="link" aria-label={words.resetA11y} onClick={onReset}>
          {words.wholeSeries}
        </button>
      )}
    </div>
  );
}

/** Archival Sourcing's categories (`categoryFilterBar`): each shown or hidden, the last shown kept, Other first. */
function CategoryFilter({ answer, hidden, onHidden }: { answer: SourcingAnswer; hidden: string[]; onHidden: (hidden: string[]) => void }) {
  const filter = answer.filter;
  const other = filter.categories.find((category) => category.value === 'unrecognized');
  function toggle(value: string) {
    if (hidden.includes(value)) onHidden(hidden.filter((each) => each !== value));
    else if (hidden.length < filter.categories.length - 1) onHidden([...hidden, value]);
  }
  return (
    <details className="about-categories">
      <summary aria-label={`${filter.accessibilityLabel}: ${filter.accessibilityValue}`}>{filter.label}</summary>
      <div className="about-categories-menu">
        {other && (
          <button type="button" disabled={!other.enabled} onClick={() => toggle(other.value)}>
            {other.shown ? words.hideOther : words.showOther}
          </button>
        )}
        <fieldset>
          <legend className="visually-hidden">{filter.accessibilityLabel}</legend>
          {filter.categories.map((category) => (
            <label key={category.value}>
              <input type="checkbox" checked={category.shown} disabled={!category.enabled} onChange={() => toggle(category.value)} /> {category.name}
            </label>
          ))}
        </fieldset>
        {filter.showAll && (
          <button type="button" onClick={() => onHidden([])}>
            {filter.showAll}
          </button>
        )}
      </div>
    </details>
  );
}

/** The top collections (`TopCollectionsCard`): the named collections the scope's volumes drew on, over the eras the years
 *  overlap, each opening its record. */
function TopCollections({ answer }: { answer: SourcingAnswer }) {
  const card = answer.topCollections;
  return (
    <section className="analytics-result about-top-collections" aria-label={card.title}>
      <h3>{card.title}</h3>
      <p className="analytics-caption">{card.caption}</p>
      {card.notice ? (
        <p className="analytics-note">{card.notice}</p>
      ) : (
        <>
          <ol>
            {card.rows.map((row) => (
              <li key={row.id}>
                <div className="about-collection-row">
                  {row.opens ? (
                    <Link to="/archival-collection" search={{ id: row.id }}>
                      {row.label}
                    </Link>
                  ) : (
                    <span>{row.label}</span>
                  )}
                  <span className="count">{row.value.toLocaleString('en-US')}</span>
                </div>
                <span className="about-bar" aria-hidden="true">
                  <span data-custodian={row.category} style={{ width: `${Math.max(row.bar * 100, 0.5)}%` }} />
                </span>
              </li>
            ))}
          </ol>
          <ul className="graph-legend">
            {card.legend.map((entry) => (
              <li key={entry.category}>
                <span className="swatch" data-custodian={entry.category} aria-hidden="true" /> {entry.name}
              </li>
            ))}
          </ul>
          {card.footnotes.map((line) => (
            <p key={line} className="analytics-footnote">
              {line}
            </p>
          ))}
          {card.method && <p className="analytics-footnote about-method">{card.method}</p>}
        </>
      )}
    </section>
  );
}

/** Administration Profiles' detail (`administrationDetail`): the picker, the profile card and its volumes. */
function AdministrationDetail({ detail, onPick }: { detail: NonNullable<AdministrationsAnswer['detail']>; onPick: (id: string) => void }) {
  const pickerId = useId();
  return (
    <section className="analytics-result about-administration" aria-label={detail.title}>
      <h3>{detail.title}</h3>
      <div className="analytics-field">
        <label htmlFor={pickerId}>{detail.pickerLabel}</label>
        <select id={pickerId} value={detail.focus} onChange={(event) => onPick(event.target.value)}>
          {detail.choices.map((choice) => (
            <option key={choice.id} value={choice.id}>
              {choice.label}
            </option>
          ))}
        </select>
      </div>
      <div className="about-profile">
        <h4>
          {detail.president} <span className="about-party" data-party={detail.party}>{detail.partyName}</span>
        </h4>
        <dl>
          {detail.stats.map((stat) => (
            <div key={stat.label}>
              <dt>{stat.label}</dt>
              <dd>{stat.value}</dd>
            </div>
          ))}
        </dl>
      </div>
      <h4>{detail.volumesHeader}</h4>
      <p className="analytics-caption">{detail.volumesCaption}</p>
      {detail.volumesEmpty ? (
        <p className="analytics-note">{detail.volumesEmpty}</p>
      ) : (
        <div className="about-volumes" tabIndex={0} role="region" aria-label={detail.volumesHeader}>
          <ul>
            {detail.volumes.map((volume) => (
              <li key={volume.id}>
                <span>
                  <Link to="/browse/$volumeId" params={{ volumeId: volume.id }}>
                    {volume.title}
                  </Link>
                  <span className="analytics-caption"> {volume.documents}</span>
                </span>
                <span className="count">{volume.proportion}</span>
              </li>
            ))}
          </ul>
        </div>
      )}
    </section>
  );
}
