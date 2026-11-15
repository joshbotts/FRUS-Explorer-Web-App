// Cross-Reference Analytics (PLAN's S24g), at /analytics/cross-references: the app's `CrossReferenceAnalyticsView` as a
// page. The scope, the year range with the administration presets, the caption with the broken references excluded,
// and its four sections: Most-Referenced Documents, whose bars and rows open their documents; Citation Degree
// Distribution with its out-degree overlay; the Volume Citation Heat Matrix, its volumes opening their pages; and the
// PageRank landmarks. Every series, word and table is the kit's or the view's, from the server; each chart is drawn by
// Vega-Lite with its table beside it, its CSV from the server and its figure, PNG or SVG, drawn here with the kit's
// caption band. The web's own: the charts and their tables at once; the state in the address; and a row of a volume
// this server does not serve, which opens nothing, where the app's would download it.
import { useQuery } from '@tanstack/react-query';
import { getRouteApi, Link, useNavigate } from '@tanstack/react-router';
import { lazy, type ReactNode, Suspense, useId, useMemo, useState } from 'react';
import { analyticsContextQuery, type AnalyticsContext, type AnalyticsScope } from '../api/analytics';
import { ApiError, errorMessage } from '../api/client';
import {
  type CrossReferenceAnswer,
  type CrossReferenceAsk,
  type CrossReferenceChart,
  crossReferenceAnalyticsQuery,
  crossReferenceCSV,
  crossReferencePlate,
  type ReferencedDocument,
} from '../api/crossReferenceAnalytics';
import { volumeScopesQuery } from '../api/searchSets';
import { meQuery } from '../api/userData';
import { copy } from '../copy';
import { useScheme } from '../shell/AppShell';
import { useHeadingReady } from '../shell/headingFocus';
import { MenuButton } from '../shell/MenuButton';
import { saveFile } from '../shell/saveFile';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import { addressScope, type ChartSpec, figureSpec, scopeFields, scopeGroups, scopeValue } from './analyticsRules';
import { Empty, ScopeOptions, YearRange } from './CorpusAnalyticsScreen';
import { DataTable, ExportMenu } from './PersonAnalyticsScreen';
import {
  type CrossReferenceSearch,
  distributionSpec,
  heatLegendSteps,
  matrixSpec,
  referenceRankingSpec,
} from './personReferenceRules';

const route = getRouteApi('/analytics/cross-references');
const words = copy.crossReferenceAnalytics;
const corpus = copy.corpusAnalytics;

const VegaChart = lazy(() => import('./VegaChart').then((module) => ({ default: module.VegaChart })));

export function CrossReferenceAnalyticsScreen() {
  const search = route.useSearch();
  const navigate = route.useNavigate();
  const context = useQuery(analyticsContextQuery);
  const me = useQuery(meQuery);
  const scopes = useQuery({ ...volumeScopesQuery, enabled: me.data?.userData === true });
  const scope = addressScope({
    subseries: search.subseries, volume: search.volume, topic: search.topic, subtopic: search.subtopic,
    volumes: search.volumes, scopeLabel: search.scopeLabel,
  });
  const ask: CrossReferenceAsk = { from: search.from, to: search.to, scope, outDegree: search.outDegree === 'on' };
  const references = useQuery(crossReferenceAnalyticsQuery(ask));
  useDocumentTitle(words.title);
  useHeadingReady(!context.isPending);
  const [failure, setFailure] = useState<string | undefined>(undefined);

  function change(fields: Partial<CrossReferenceSearch>) {
    void navigate({ search: (previous) => ({ ...previous, ...fields }) });
  }

  async function csv(chart: CrossReferenceChart) {
    setFailure(undefined);
    try {
      const file = await crossReferenceCSV(ask, chart);
      saveFile(file.blob, file.name);
    } catch (error) {
      setFailure(errorMessage(error));
    }
  }

  async function figure(chart: CrossReferenceChart, spec: ChartSpec, format: 'png' | 'svg') {
    setFailure(undefined);
    try {
      const [{ renderFigure }, plate] = await Promise.all([import('./VegaChart'), crossReferencePlate(ask, chart)]);
      saveFile(await renderFigure(figureSpec(spec, plate, []), format), `${plate.fileName}.${format}`);
    } catch (error) {
      setFailure(error instanceof ApiError ? errorMessage(error) : corpus.renderError);
    }
  }

  const unavailable = context.error instanceof ApiError && context.error.code === 'INDEX_NOT_READY';
  const answer = references.data;
  return (
    <div className="analytics-page cross-reference-analytics">
      <h1 tabIndex={-1} data-loading={context.isPending ? 'true' : undefined}>
        {words.title}
      </h1>
      {unavailable ? (
        <Empty title={words.unavailableTitle} detail={words.unavailableDetail} />
      ) : context.error ? (
        <Empty title={corpus.errorTitle} detail={errorMessage(context.error)} />
      ) : (
        <>
          {context.data && <Filters search={search} scope={scope} answer={answer} context={context.data} scopes={scopes.data?.items} onChange={change} />}
          {failure && (
            <div className="analytics-alert" role="alert">
              <strong>{corpus.exportFailed}</strong> {failure}
            </div>
          )}
          {references.error ? (
            <Empty title={corpus.errorTitle} detail={errorMessage(references.error)} />
          ) : !answer ? (
            <p className="analytics-loading" role="status">
              {corpus.loading}
            </p>
          ) : (
            <Sections answer={answer} busy={references.isPlaceholderData} onChange={change} onCSV={(chart) => void csv(chart)}
                      onFigure={(chart, spec, format) => void figure(chart, spec, format)} />
          )}
        </>
      )}
    </div>
  );
}

/** The scope, the year range and the administration presets (#189-B, #236). */
function Filters({
  search,
  scope,
  answer,
  context,
  scopes,
  onChange,
}: {
  search: CrossReferenceSearch;
  scope: AnalyticsScope | undefined;
  answer: CrossReferenceAnswer | undefined;
  context: AnalyticsContext;
  scopes: Parameters<typeof scopeGroups>[1];
  onChange: (fields: Partial<CrossReferenceSearch>) => void;
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
      <YearRange
        start={start}
        end={end}
        context={context}
        disabled={false}
        isCustom={start !== context.floorYear || end !== context.corpusMaxYear}
        onChange={(from, to) => onChange({ from, to })}
      />
      {context.presets.length > 0 && (
        <MenuButton
          label={corpus.administration}
          entries={context.presets.map((preset) => ({
            kind: 'item' as const,
            label: preset.label,
            onSelect: () => onChange({ from: preset.start, to: preset.end }),
          }))}
        />
      )}
    </div>
  );
}

/** A document's row, which opens it where the server serves its volume. */
function DocumentLink({ document, children }: { document: ReferencedDocument; children: ReactNode }) {
  return document.isIndexed ? (
    <Link to="/doc/$volumeId/$documentId" params={{ volumeId: document.volumeId, documentId: document.documentId }}>
      {children}
    </Link>
  ) : (
    <>
      {children} <span className="analytics-note">({words.notServed})</span>
    </>
  );
}

/** Each chart's words, which the page and its figure share. */
function rankingLabels(answer: CrossReferenceAnswer) {
  return { document: words.document, inDegree: words.inboundCitations, description: words.chartDescription(answer.ranking.heading) };
}

function distributionLabels(answer: CrossReferenceAnswer) {
  return {
    degree: words.degree, documents: words.documents, direction: words.direction, inDegree: words.inDegreeSeries,
    outDegree: words.outDegreeSeries, description: words.chartDescription(answer.distribution.heading),
  };
}

function matrixLabels(answer: CrossReferenceAnswer) {
  return { citing: words.citing, cited: words.cited, references: words.references, description: words.chartDescription(answer.matrix.heading) };
}

function Sections({
  answer,
  busy,
  onChange,
  onCSV,
  onFigure,
}: {
  answer: CrossReferenceAnswer;
  busy: boolean;
  onChange: (fields: Partial<CrossReferenceSearch>) => void;
  onCSV: (chart: CrossReferenceChart) => void;
  onFigure: (chart: CrossReferenceChart, spec: ChartSpec, format: 'png' | 'svg') => void;
}) {
  const navigate = useNavigate();
  const dark = useScheme() === 'dark';
  const ids = { ranking: useId(), distribution: useId(), matrix: useId(), landmarks: useId() };
  const ranking = useMemo(() => referenceRankingSpec(answer, rankingLabels(answer), dark), [answer, dark]);
  const distribution = useMemo(() => distributionSpec(answer, distributionLabels(answer), dark), [answer, dark]);
  const matrix = useMemo(() => matrixSpec(answer, matrixLabels(answer), dark), [answer, dark]);
  return (
    <>
      <div className="analytics-caption cross-reference-caption">
        <p>{answer.resolvedCaption}</p>
        {answer.excludedBrokenCaption && <p>{answer.excludedBrokenCaption}</p>}
      </div>

      <section className="analytics-result" aria-labelledby={ids.ranking} aria-busy={busy || undefined}>
        <div className="analytics-section-head">
          <h2 id={ids.ranking}>{answer.ranking.heading}</h2>
          <ExportMenu
            canExport={answer.ranking.rows.length > 0}
            canDraw={answer.ranking.rows.length > 0 && !busy}
            onCSV={() => onCSV('ranking')}
            onFigure={(format) => onFigure('ranking', referenceRankingSpec(answer, rankingLabels(answer), false), format)}
          />
        </div>
        <p className="analytics-caption">{answer.ranking.subtitle}</p>
        {answer.ranking.empty ? (
          <Empty title={answer.emptyTitle} detail={answer.ranking.empty} />
        ) : (
          <div className="analytics-pane">
            <div className="analytics-figure">
              <Suspense fallback={<div className="analytics-chart" aria-hidden="true" />}>
                <VegaChart
                  spec={ranking}
                  label={words.chartDescription(answer.ranking.heading)}
                  onChoose={(datum) => {
                    const row = answer.ranking.rows[Number(datum.index)];
                    if (row?.document.isIndexed) {
                      void navigate({ to: '/doc/$volumeId/$documentId', params: { volumeId: row.document.volumeId, documentId: row.document.documentId } });
                    }
                  }}
                />
              </Suspense>
            </div>
            <DataTable
              table={answer.ranking.table}
              cell={(row, column, text) => {
                const ranked = answer.ranking.rows[row];
                return column === 1 && ranked ? <DocumentLink document={ranked.document}>{text}</DocumentLink> : text;
              }}
            />
          </div>
        )}
      </section>

      <section className="analytics-result" aria-labelledby={ids.distribution} aria-busy={busy || undefined}>
        <div className="analytics-section-head">
          <h2 id={ids.distribution}>{answer.distribution.heading}</h2>
          <ExportMenu
            canExport={answer.distribution.inDegree.length > 0}
            canDraw={answer.distribution.inDegree.length > 0 && !busy}
            onCSV={() => onCSV('distribution')}
            onFigure={(format) => onFigure('distribution', distributionSpec(answer, distributionLabels(answer), false), format)}
          />
        </div>
        <p className="analytics-caption">{answer.distribution.subtitle}</p>
        <div className="analytics-options">
          <label className="analytics-check" title={words.outDegreeHelp}>
            <input
              type="checkbox"
              checked={answer.distribution.showsOutDegree}
              disabled={answer.distribution.inDegree.length === 0}
              onChange={(event) => onChange({ outDegree: event.target.checked ? 'on' : undefined })}
            />
            {words.outDegree}
          </label>
        </div>
        {answer.distribution.empty ? (
          <Empty title={answer.emptyTitle} detail={answer.distribution.empty} />
        ) : (
          <div className="analytics-pane">
            <div className="analytics-figure">
              <Suspense fallback={<div className="analytics-chart" aria-hidden="true" />}>
                <VegaChart spec={distribution} label={words.chartDescription(answer.distribution.heading)} />
              </Suspense>
            </div>
            <DataTable table={answer.distribution.table} />
          </div>
        )}
      </section>

      <section className="analytics-result" aria-labelledby={ids.matrix} aria-busy={busy || undefined}>
        <div className="analytics-section-head">
          <h2 id={ids.matrix}>{answer.matrix.heading}</h2>
          <ExportMenu
            canExport={answer.matrix.table.rows.length > 0}
            canDraw={answer.matrix.table.rows.length > 0 && !busy}
            onCSV={() => onCSV('matrix')}
            onFigure={(format) => onFigure('matrix', matrixSpec(answer, matrixLabels(answer), false, true), format)}
          />
        </div>
        <p className="analytics-caption">{answer.matrix.subtitle}</p>
        {answer.matrix.empty ? (
          <Empty title={answer.emptyTitle} detail={answer.matrix.empty} />
        ) : (
          <div className="analytics-pane">
            <div className="analytics-figure">
              <div className="cross-reference-matrix">
                <Suspense fallback={<div className="analytics-chart" aria-hidden="true" />}>
                  <VegaChart spec={matrix} label={words.chartDescription(answer.matrix.heading)} />
                </Suspense>
              </div>
              <p className="cross-reference-legend">
                <span>{answer.matrix.legend.low}</span>
                {heatLegendSteps.map((step) => (
                  <span key={step} className={`heat-step heat-${Math.round(step * 100)}`} aria-hidden="true" />
                ))}
                <span>{answer.matrix.legend.high}</span>
                {answer.matrix.legend.max && <span>{answer.matrix.legend.max}</span>}
              </p>
              <ul className="cross-reference-volumes" aria-label={words.citing}>
                {answer.matrix.volumes.map((volume) => (
                  <li key={volume.id}>
                    <Link to="/browse/$volumeId" params={{ volumeId: volume.id }} title={volume.title}>
                      <span className="code">{volume.code}</span> {volume.topic ? `${volume.topic} · ${volume.tag}` : volume.tag}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
            <DataTable
              table={answer.matrix.table}
              // The citing and cited volumes' ids open their volumes, as the matrix's labels do (`openVolume`).
              cell={(_row, column, text) =>
                column === 1 || column === 3 ? (
                  <Link to="/browse/$volumeId" params={{ volumeId: text }}>
                    {text}
                  </Link>
                ) : (
                  text
                )
              }
            />
          </div>
        )}
      </section>

      <section className="analytics-result" aria-labelledby={ids.landmarks} aria-busy={busy || undefined}>
        <div className="analytics-section-head">
          <h2 id={ids.landmarks}>{answer.landmarks.heading}</h2>
          <ExportMenu canExport={answer.landmarks.rows.length > 0} canDraw={false} onCSV={() => onCSV('landmarks')} />
        </div>
        <p className="analytics-caption">{answer.landmarks.subtitle}</p>
        {answer.landmarks.empty ? (
          <Empty title={answer.emptyTitle} detail={answer.landmarks.empty} />
        ) : (
          <div className="analytics-pane">
            <ol className="cross-reference-landmarks">
              {answer.landmarks.rows.map((row, index) => (
                <li key={`${row.document.volumeId}/${row.document.documentId}`} className={index === 0 ? 'first' : undefined}>
                  <span className="rank" aria-hidden="true">
                    {index + 1}
                  </span>
                  <span className="body">
                    <DocumentLink document={row.document}>{row.document.label}</DocumentLink>
                    <span className="ids">
                      {row.document.volumeId} · {row.document.documentId}
                    </span>
                    <meter min={0} max={1} value={row.fraction} aria-label={row.scoreLabel} />
                  </span>
                </li>
              ))}
            </ol>
            <DataTable
              table={answer.landmarks.table}
              cell={(row, column, text) => {
                const landmark = answer.landmarks.rows[row];
                return column === 1 && landmark ? <DocumentLink document={landmark.document}>{text}</DocumentLink> : text;
              }}
            />
          </div>
        )}
      </section>
    </>
  );
}
