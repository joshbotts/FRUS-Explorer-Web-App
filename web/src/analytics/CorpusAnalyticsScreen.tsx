// Corpus Analytics (PLAN's S24f), at /analytics/corpus: the app's `AnalyticsView` as a page, for one committed term.
// Its field and Search; its filter row's chips, the scope (`AnalyticsScopeBar`, By Detected Topic among them), the
// year range with its Reset, Group by with its two sections, and the administration presets; its toolbar's
// Measure, Values, fit line, colours and Export; the hand-off link with Search's count and the dispersion line;
// the occurrence notice; and the chart, drawn by Vega-Lite from the server's series, with its legend, caption and
// footnote, and beside it the chart's table, the kit's. Every series, share, word and table is the kit's or the
// view's, from the server. The web's own: the chart and its table at once, where the app switches between them;
// the state in the address, so Back returns to a chart as it was; the measure, values and colours kept in this
// browser under the app's own keys, as the app keeps them on each device; the years typed and kept when the
// field is left; and a breakdown's bar opened from its row of the table by the keyboard.
import { useQuery } from '@tanstack/react-query';
import { getRouteApi, Link, useNavigate } from '@tanstack/react-router';
import { type FormEvent, lazy, type ReactNode, Suspense, useId, useMemo, useState } from 'react';
import {
  analyticsContextQuery,
  type AnalyticsAxis,
  type AnalyticsContext,
  type AnalyticsMeasure,
  type AnalyticsScope,
  type AnalyticsValues,
  corpusChartQuery,
  corpusCSV,
  corpusDocumentsQuery,
  corpusPlate,
  type CorpusAnswer,
  type CorpusAsk,
} from '../api/analytics';
import { ApiError, errorMessage } from '../api/client';
import { volumeScopesQuery } from '../api/searchSets';
import { meQuery } from '../api/userData';
import { copy } from '../copy';
import { useScheme } from '../shell/AppShell';
import { useHeadingReady } from '../shell/headingFocus';
import { MenuButton } from '../shell/MenuButton';
import { saveFile } from '../shell/saveFile';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import {
  addressScope,
  axisSections,
  clampEnd,
  clampStart,
  type CorpusSearch,
  corpusSpec,
  figureSpec,
  isDateBased,
  type ScopeGroup,
  scopeFields,
  scopeGroups,
  scopeValue,
  seriesColor,
  store,
  storageKeys,
  stored,
} from './analyticsRules';

const route = getRouteApi('/analytics/corpus');
const words = copy.corpusAnalytics;

/** Vega-Lite, which only the analytics pages draw with, loaded with them rather than with the app. */
const VegaChart = lazy(() => import('./VegaChart').then((module) => ({ default: module.VegaChart })));

/** The chart the address asks for, with the preferences this browser keeps where the address names none. */
function askOf(search: CorpusSearch, context: AnalyticsContext | undefined): CorpusAsk | undefined {
  if (!search.term) return undefined;
  const measure = search.measure ?? (stored(storageKeys.measure) === 'occurrences' ? 'occurrences' : 'documents');
  const values = search.values ?? (stored(storageKeys.values) === 'percentOfDocuments' ? 'percentOfDocuments' : 'raw');
  const kept = Number(stored(storageKeys.colors));
  const colors = search.colors ?? (Number.isInteger(kept) && kept >= 6 && kept <= 12 ? kept : (context?.defaultColors ?? 8));
  return {
    term: search.term,
    axis: search.axis ?? 'byYear',
    measure,
    values,
    from: search.from,
    to: search.to,
    colors,
    scope: addressScope(search),
  };
}

export function CorpusAnalyticsScreen() {
  const search = route.useSearch();
  const navigate = route.useNavigate();
  const context = useQuery(analyticsContextQuery);
  const me = useQuery(meQuery);
  const scopes = useQuery({ ...volumeScopesQuery, enabled: me.data?.userData === true });
  const ask = askOf(search, context.data);
  const chart = useQuery({ ...corpusChartQuery(ask ?? { term: '', axis: 'byYear', measure: 'documents', values: 'raw' }), enabled: ask !== undefined });
  const answer = ask && chart.data?.term === ask.term ? chart.data : undefined;
  const counted = answer?.state === 'chart' && ask !== undefined;
  const documents = useQuery({ ...corpusDocumentsQuery(ask ?? { term: '', axis: 'byYear', measure: 'documents', values: 'raw' }), enabled: counted });
  const scheme = useScheme();
  useDocumentTitle(words.title);
  useHeadingReady(!context.isPending);

  const [termInput, setTermInput] = useState(search.term ?? '');
  // A term the address commits elsewhere, as Back to an earlier chart does, is the field's.
  const [shownTerm, setShownTerm] = useState(search.term);
  if (shownTerm !== search.term) {
    setShownTerm(search.term);
    setTermInput(search.term ?? '');
  }
  const [exportError, setExportError] = useState<string | undefined>(undefined);
  const fitLine = search.fit !== 'off';
  const termId = useId();

  /** A change of the chart's state, as a new entry of the address. */
  function change(fields: Partial<CorpusSearch>) {
    void navigate({ search: (previous) => ({ ...previous, ...fields }) });
  }

  function commit(event: FormEvent) {
    event.preventDefault();
    // `addTerm()` trims the field's spaces, and an empty field commits nothing.
    const term = termInput.trim();
    if (term === '') return;
    change({ term });
  }

  async function exportCSV() {
    if (!ask) return;
    setExportError(undefined);
    try {
      const file = await corpusCSV(ask);
      saveFile(file.blob, file.name);
    } catch (error) {
      setExportError(errorMessage(error));
    }
  }

  async function exportFigure(format: 'png' | 'svg') {
    if (!ask || !answer) return;
    setExportError(undefined);
    try {
      const [{ renderFigure }, plate] = await Promise.all([import('./VegaChart'), corpusPlate(ask)]);
      const legend = answer.series.map((series, index) => ({
        title: series.title,
        label: `${series.title}  ${series.totalLabel}`,
        color: seriesColor(series.key, index),
      }));
      const spec = figureSpec(corpusSpec(answer, { fitLine, dark: false }), plate, legend);
      saveFile(await renderFigure(spec, format), `${plate.fileName}.${format}`);
    } catch (error) {
      setExportError(error instanceof ApiError ? errorMessage(error) : words.renderError);
    }
  }

  const unavailable = context.error instanceof ApiError && context.error.code === 'INDEX_NOT_READY';
  return (
    <div className="analytics-page">
      <h1 tabIndex={-1} data-loading={context.isPending ? 'true' : undefined}>
        {words.title}
      </h1>
      <form className="analytics-term" role="search" aria-label={words.title} onSubmit={commit}>
        <label htmlFor={termId} className="visually-hidden">
          {words.term}
        </label>
        <input
          id={termId}
          type="search"
          value={termInput}
          placeholder={words.termPlaceholder}
          onChange={(event) => setTermInput(event.target.value)}
        />
        <button type="submit" className="primary" disabled={termInput.trim() === ''}>
          {words.search}
        </button>
      </form>
      {unavailable ? (
        <Empty title={words.unavailableTitle} detail={words.unavailableDetail} />
      ) : context.error ? (
        <Empty title={words.errorTitle} detail={errorMessage(context.error)} />
      ) : !ask ? (
        <Empty title={words.promptTitle} detail={words.promptDetail} />
      ) : (
        <>
          {context.data && (
            <Filters ask={ask} answer={answer} context={context.data} scopes={scopes.data?.items} onChange={change} />
          )}
          <Options
            ask={ask}
            answer={answer}
            busy={chart.isPlaceholderData}
            colorCounts={context.data?.colorCounts ?? [6, 7, 8, 9, 10, 11, 12]}
            fitLine={fitLine}
            onChange={change}
            onExport={(format) => (format === 'csv' ? void exportCSV() : void exportFigure(format))}
          />
          {exportError && (
            <div className="analytics-alert" role="alert">
              <strong>{words.exportFailed}</strong> {exportError}
            </div>
          )}
          {/* Search's count once taken, and until then the chart's own (`handoffHasDocuments`). */}
          {answer && (documents.data ? documents.data.count > 0 : answer.matchedDocumentCount > 0) && (
            <p className="analytics-handoff">
              {documents.data ? (
                <Link to="/search" search={{ ...documents.data.search, includeNotes: false, includeSummaries: false }} title={words.handoffHelp}>
                  {documents.data.linkTitle} <span aria-hidden="true">↗</span>
                </Link>
              ) : (
                <span>{words.viewDocuments}</span>
              )}
              {documents.data?.dispersion && <span className="analytics-dispersion">{documents.data.dispersion}</span>}
            </p>
          )}
          {chart.error ? (
            <Empty title={words.errorTitle} detail={errorMessage(chart.error)} />
          ) : !answer ? (
            <p className="analytics-loading" role="status">
              {words.loading}
            </p>
          ) : answer.state !== 'chart' ? (
            <Empty title={answer.stateTitle ?? ''} detail={answer.stateDetail ?? ''} />
          ) : (
            <Chart answer={answer} ask={ask} fitLine={fitLine} dark={scheme === 'dark'} busy={chart.isPlaceholderData} />
          )}
        </>
      )}
    </div>
  );
}

/** An empty state's title and words, as the app's `ContentUnavailableView`. */
function Empty({ title, detail }: { title: string; detail: string }) {
  return (
    <div className="analytics-empty">
      <h2>{title}</h2>
      <p>{detail}</p>
    </div>
  );
}

/** The filter row (`filterRow`): the scope, the years with their Reset, Group by, and the presets. */
function Filters({
  ask,
  answer,
  context,
  scopes,
  onChange,
}: {
  ask: CorpusAsk;
  answer: CorpusAnswer | undefined;
  context: AnalyticsContext;
  scopes: Parameters<typeof scopeGroups>[1];
  onChange: (fields: Partial<CorpusSearch>) => void;
}) {
  const groups = useMemo(() => scopeGroups(context, scopes), [context, scopes]);
  const chosen = scopeValue(ask.scope);
  const options = groups.flatMap((group) => group.options);
  const missing = !options.some((option) => option.value === chosen);
  const categorical = !isDateBased(ask.axis);
  // The years asked for, the server's defaults where the address names none: never a chart still on show.
  const start = ask.from ?? context.floorYear;
  const end = ask.to ?? context.corpusMaxYear;
  const isCustom = start !== context.floorYear || end !== context.corpusMaxYear;
  const scopeId = useId();
  const axisId = useId();

  function chooseScope(value: string) {
    const option = options.find((each) => each.value === value);
    if (!option || option.disabled) return;
    onChange(scopeFields(option.scope as AnalyticsScope | undefined));
  }

  return (
    <div className="analytics-filters">
      <div className="analytics-field">
        <label htmlFor={scopeId}>{words.scope}</label>
        <select id={scopeId} value={chosen} title={words.scopeHelp} onChange={(event) => chooseScope(event.target.value)}>
          {missing && <option value={chosen}>{answer?.scope.label ?? words.wholeCorpus}</option>}
          {groups.map((group, index) => (
            <ScopeOptions key={`${group.label}-${index}`} group={group} />
          ))}
        </select>
      </div>
      <YearRange
        start={start}
        end={end}
        context={context}
        disabled={categorical}
        isCustom={isCustom}
        onChange={(from, to) => onChange({ from, to })}
      />
      <div className="analytics-field">
        <label htmlFor={axisId}>{words.groupBy}</label>
        <select id={axisId} value={ask.axis} title={words.groupByHelp} onChange={(event) => onChange({ axis: event.target.value as AnalyticsAxis })}>
          {axisSections().map((section) => (
            <optgroup key={section.label} label={section.label}>
              {section.axes.map((axis) => (
                <option key={axis} value={axis}>
                  {words.axes[axis]}
                </option>
              ))}
            </optgroup>
          ))}
        </select>
      </div>
      {context.presets.length > 0 &&
        (categorical ? (
          <button type="button" disabled title={words.administrationHelp}>
            {words.administration}
          </button>
        ) : (
          <MenuButton
            label={words.administration}
            entries={context.presets.map((preset) => ({
              kind: 'item' as const,
              label: preset.label,
              onSelect: () => onChange({ from: preset.start, to: preset.end }),
            }))}
          />
        ))}
      {categorical && <p className="analytics-note">{words.categoricalNote}</p>}
    </div>
  );
}

function ScopeOptions({ group }: { group: ScopeGroup }): ReactNode {
  const options = group.options.map((option) => (
    <option key={option.value} value={option.value} disabled={option.disabled}>
      {option.label}
    </option>
  ));
  return group.label === '' ? options : <optgroup label={group.label}>{options}</optgroup>;
}

/** The year range (`AnalyticsYearRangeBar`): two fields, each clamped as the app's are, kept when left. */
function YearRange({
  start,
  end,
  context,
  disabled,
  isCustom,
  onChange,
}: {
  start: number;
  end: number;
  context: AnalyticsContext;
  disabled: boolean;
  isCustom: boolean;
  onChange: (from: number, to: number) => void;
}) {
  const [draftStart, setDraftStart] = useState(String(start));
  const [draftEnd, setDraftEnd] = useState(String(end));
  // The field being edited keeps what is typed in it when the years change, as a preset or Back changes them.
  const [editing, setEditing] = useState<'start' | 'end' | undefined>(undefined);
  const [shown, setShown] = useState(`${start}-${end}`);
  if (shown !== `${start}-${end}`) {
    setShown(`${start}-${end}`);
    if (editing !== 'start') setDraftStart(String(start));
    if (editing !== 'end') setDraftEnd(String(end));
  }
  const startId = useId();
  const endId = useId();

  function keep() {
    const typedStart = Number.parseInt(draftStart, 10);
    const typedEnd = Number.parseInt(draftEnd, 10);
    const nextStart = Number.isFinite(typedStart) ? clampStart(typedStart, end, context.earliestYear) : start;
    const nextEnd = Number.isFinite(typedEnd) ? clampEnd(typedEnd, nextStart, context.corpusMaxYear) : end;
    setDraftStart(String(nextStart));
    setDraftEnd(String(nextEnd));
    if (nextStart !== start || nextEnd !== end) onChange(nextStart, nextEnd);
  }

  return (
    <fieldset className="analytics-years" disabled={disabled}>
      <legend>{words.yearRange}</legend>
      <label htmlFor={startId} className="visually-hidden">
        {words.startYear}
      </label>
      <input
        id={startId}
        type="number"
        inputMode="numeric"
        min={context.earliestYear}
        max={end}
        value={draftStart}
        onChange={(event) => setDraftStart(event.target.value)}
        onFocus={() => setEditing('start')}
        onBlur={() => {
          setEditing(undefined);
          keep();
        }}
        onKeyDown={(event) => {
          if (event.key === 'Enter') keep();
        }}
      />
      <span aria-hidden="true">–</span>
      <label htmlFor={endId} className="visually-hidden">
        {words.endYear}
      </label>
      <input
        id={endId}
        type="number"
        inputMode="numeric"
        min={start}
        max={context.corpusMaxYear}
        value={draftEnd}
        onChange={(event) => setDraftEnd(event.target.value)}
        onFocus={() => setEditing('end')}
        onBlur={() => {
          setEditing(undefined);
          keep();
        }}
        onKeyDown={(event) => {
          if (event.key === 'Enter') keep();
        }}
      />
      {isCustom && (
        <button type="button" className="link" title={words.resetHelp} onClick={() => onChange(context.floorYear, context.corpusMaxYear)}>
          {words.reset}
        </button>
      )}
    </fieldset>
  );
}

/** The toolbar's chart controls: Measure and Values on the axes they apply to, the fit line, the colours, Export. */
function Options({
  ask,
  answer,
  busy,
  colorCounts,
  fitLine,
  onChange,
  onExport,
}: {
  ask: CorpusAsk;
  answer: CorpusAnswer | undefined;
  /** Whether the chart on show is the last one, while the one asked for is computed. */
  busy: boolean;
  colorCounts: number[];
  fitLine: boolean;
  onChange: (fields: Partial<CorpusSearch>) => void;
  onExport: (format: 'csv' | 'png' | 'svg') => void;
}) {
  // By Year and By Decade only, the axes with a per-period series (`measureApplies`, `normalizationApplies`).
  const periodic = ask.axis === 'byYear' || ask.axis === 'byDecade';
  const dated = isDateBased(ask.axis);
  const canExport = answer?.state === 'chart';
  // A figure draws the chart on show, so it waits for the one asked for; the CSV is the server's, of the request.
  const canDraw = canExport && !busy;
  const colorsId = useId();

  function measure(value: AnalyticsMeasure) {
    store(storageKeys.measure, value);
    onChange({ measure: value });
  }

  function values(value: AnalyticsValues) {
    store(storageKeys.values, value);
    onChange({ values: value });
  }

  return (
    <div className="analytics-options">
      {periodic && (
        <Segmented
          legend={words.measure}
          help={words.measureHelp}
          name="measure"
          value={ask.measure}
          disabled={answer !== undefined && !answer.measure.available}
          choices={[
            { value: 'documents', label: words.documents },
            { value: 'occurrences', label: words.occurrences },
          ]}
          onChange={(value) => measure(value as AnalyticsMeasure)}
        />
      )}
      {periodic && (
        <Segmented
          legend={words.values}
          help={words.valuesHelp}
          name="values"
          value={ask.values}
          disabled={answer !== undefined && !answer.values.enabled}
          choices={[
            { value: 'raw', label: words.raw },
            { value: 'percentOfDocuments', label: words.percent },
          ]}
          onChange={(value) => values(value as AnalyticsValues)}
        />
      )}
      <label className="analytics-check" title={words.fitLineHelp}>
        <input type="checkbox" checked={fitLine} disabled={!dated} onChange={(event) => onChange({ fit: event.target.checked ? undefined : 'off' })} />
        {words.fitLine}
      </label>
      <div className="analytics-field">
        <label htmlFor={colorsId}>{words.colors}</label>
        <select
          id={colorsId}
          value={ask.colors}
          disabled={!dated}
          title={words.colorsHelp}
          onChange={(event) => {
            store(storageKeys.colors, event.target.value);
            onChange({ colors: Number(event.target.value) });
          }}
        >
          {colorCounts.map((count) => (
            <option key={count} value={count}>
              {count}
            </option>
          ))}
        </select>
      </div>
      <MenuButton
        label={words.export}
        accessibleLabel={words.export}
        entries={[
          { kind: 'item', label: words.exportCSV, onSelect: () => onExport('csv'), disabled: !canExport },
          // The app exports a figure of the date axes alone (`canExportFigure`).
          { kind: 'item', label: words.exportPNG, onSelect: () => onExport('png'), disabled: !canDraw || !dated },
          { kind: 'item', label: words.exportSVG, onSelect: () => onExport('svg'), disabled: !canDraw || !dated },
        ]}
      />
    </div>
  );
}

/** A segmented control, a group of radios, as the app's segmented pickers are to a screen reader. */
function Segmented({
  legend,
  help,
  name,
  value,
  disabled,
  choices,
  onChange,
}: {
  legend: string;
  help: string;
  name: string;
  value: string;
  disabled: boolean;
  choices: { value: string; label: string }[];
  onChange: (value: string) => void;
}) {
  return (
    <fieldset className="segmented" disabled={disabled} title={help}>
      <legend>{legend}</legend>
      {choices.map((choice) => (
        <label key={choice.value}>
          <input type="radio" name={name} value={choice.value} checked={value === choice.value} onChange={() => onChange(choice.value)} />
          {choice.label}
        </label>
      ))}
    </fieldset>
  );
}

/** The chart and its table, beside each other, with the legend, the notes and the footnote. */
function Chart({ answer, ask, fitLine, dark, busy }: { answer: CorpusAnswer; ask: CorpusAsk; fitLine: boolean; dark: boolean; busy: boolean }) {
  const navigate = useNavigate();
  const spec = useMemo(() => corpusSpec(answer, { fitLine, dark }), [answer, fitLine, dark]);
  const categorical = answer.axis === 'bySubseries' || answer.axis === 'byVolume';
  const headingId = useId();

  /** A breakdown's bar opens its documents in Search, with the notes and summaries off (#1306). */
  function searchOf(volumeIds: string[]) {
    return { keywords: ask.term, volumeIds, includeNotes: false as const, includeSummaries: false as const };
  }

  return (
    <section className="analytics-result" aria-labelledby={headingId} aria-busy={busy || undefined}>
      {answer.measure.notice && (
        <p className="analytics-notice" role="note">
          <span aria-hidden="true">ⓘ </span>
          {answer.measure.notice}
        </p>
      )}
      <h2 id={headingId}>{answer.heading}</h2>
      <div className="analytics-pane">
        <div className="analytics-figure">
          {answer.series.length > 0 && (
            <ul className="analytics-legend" aria-label={words.legend}>
              {answer.series.map((series, index) => (
                <li key={series.key}>
                  <span className="swatch" style={{ background: seriesColor(series.key, index) }} aria-hidden="true" />
                  <span className="name">{series.title}</span> <span className="total">{series.totalLabel}</span>
                </li>
              ))}
            </ul>
          )}
          {answer.notice ? (
            <div className="analytics-empty">
              <h3>{answer.notice.title}</h3>
              <p>{answer.notice.detail}</p>
            </div>
          ) : (
            <Suspense fallback={<div className="analytics-chart" aria-hidden="true" />}>
              <VegaChart
                spec={spec}
                label={words.chartDescription(answer.heading)}
                onChoose={
                  categorical
                    ? (datum) => {
                        const bar = answer.bars[Number(datum.index)];
                        if (bar) void navigate({ to: '/search', search: searchOf(bar.volumeIds) });
                      }
                    : undefined
                }
              />
            </Suspense>
          )}
          {answer.normalizationCaption && <p className="analytics-caption">{answer.normalizationCaption}</p>}
          {categorical && <p className="analytics-caption">{words.drillHint}</p>}
          {answer.footnote && (
            <p className="analytics-footnote">
              {answer.footnote}
              {answer.fullCorpusTotal && <span className="analytics-total"> · {answer.fullCorpusTotal}</span>}
            </p>
          )}
        </div>
        {/* A region the keyboard reaches, since a long table scrolls within it. */}
        <div className="analytics-table" tabIndex={0} role="region" aria-label={words.table}>
          <table>
            <caption>{words.table}</caption>
            <thead>
              <tr>
                {answer.table.columns.map((column) => (
                  <th key={column} scope="col">
                    {column}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {answer.table.rows.map((row, index) => (
                <tr key={`${row[1]}-${index}`}>
                  {row.map((cell, column) => (
                    <td key={column}>
                      {column === 1 && categorical && answer.bars[index] ? (
                        <Link to="/search" search={searchOf(answer.bars[index].volumeIds)}>
                          {cell}
                        </Link>
                      ) : (
                        cell
                      )}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </section>
  );
}
