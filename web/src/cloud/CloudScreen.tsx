// The Word Cloud (PLAN's S24i, S29e), at /cloud: the app's `WordCloudView` in Frequency mode. Its scope bar is the app's
// (`WordCloudScopeBar`): Entire Corpus, each subseries, each volume under its subseries, the reader's collections, tags,
// saved searches and volume scopes, By Subject and Date Range, with a document's own scope from the reader's rail; its
// lens bar the app's nine lenses, the entity lenses saying, in the server's words, why its tagger draws none of them.
// Since S29e the server counts every scope live from the served index's text, under the reader's own settings, and
// reads the corpus, a subseries and a volume from the language family's clouds (S29d) while the settings are the
// family's; a count that outlasts a request runs as a job, which the page follows until it ends, its bar and line saying
// how far it has come. The page draws the cloud as the app does, in a spiral of words sized by count (`WordCloudLayout`),
// with the ranked list that is the cloud's accessible reading beside it, and a word's menu: Corpus Analytics over the
// series or over the cloud's own volumes, Search, and the three hides, this cloud alone, this lens, or every cloud. The
// header's chip says when a thin volume's era stands in for it. Distinctive is refused with its reason until S29f.
// The web's own: the cloud and its list drawn together, where the app switches between them, the words saying what the
// reader's settings took out of a family's list, and what a count says of itself.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { getRouteApi, Link, useNavigate } from '@tanstack/react-router';
import { useEffect, useId, useMemo, useRef, useState, useSyncExternalStore } from 'react';
import {
  type CloudAnswer,
  cloudContextQuery,
  type CloudContext,
  type CloudJob,
  cloudJobQuery,
  cloudQuery,
  type CloudTerm,
  hideWord,
  pendingCriteriaChanges,
  settingsToken,
  subscribePendingCriteria,
  updateWordCloud,
} from '../api/cloud';
import { errorMessage } from '../api/client';
import { collectionsQuery } from '../api/collections';
import { preferencesQuery } from '../api/research';
import { savedSearchesQuery, volumeScopesQuery } from '../api/searchSets';
import { meQuery, tagsQuery } from '../api/userData';
import { copy } from '../copy';
import { Empty, Segmented } from '../analytics/CorpusAnalyticsScreen';
import { useSyncedPreferences } from '../settings/syncedPreferences';
import { useHeadingReady } from '../shell/headingFocus';
import { MenuButton, type MenuEntry } from '../shell/MenuButton';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import {
  dateRangeOf,
  dateRangeScope,
  documentScope,
  keepMeasure,
  type Measure,
  place,
  type PlacedWord,
  spacingScales,
  storedDensity,
  storedFontDesign,
  storedMeasure,
  subjectScope,
  widthFactors,
  wordColor,
} from './cloudRules';

const route = getRouteApi('/cloud');
const words = copy.wordCloud;

export function CloudScreen() {
  const search = route.useSearch();
  const navigate = route.useNavigate();
  const client = useQueryClient();
  const context = useQuery(cloudContextQuery);
  const me = useQuery(meQuery);
  const { keepsUserData, preferences } = useSyncedPreferences();
  const pending = useSyncExternalStore(subscribePendingCriteria, pendingCriteriaChanges);
  const held = useQuery({ ...preferencesQuery, enabled: keepsUserData });
  // The cloud is asked once the reader's settings are known, theirs or the app's own, so it is not drawn twice; a
  // server that cannot give them has the cloud asked all the same, read at whatever settings it holds.
  const settingsKnown = (me.isSuccess || me.isError) && (!keepsUserData || preferences !== undefined || held.isError);
  const fromDocument = documentScope(search.scope);
  const scope = search.scope ?? 'corpus';
  const lenses = context.data?.lenses ?? [];
  const lens = lenses.some((each) => each.id === search.lens) ? search.lens! : (lenses[0]?.id ?? 'allTerms');
  const token = settingsToken(keepsUserData ? preferences : undefined);
  const cloud = useQuery({ ...cloudQuery(scope, lens, token), enabled: context.isSuccess && settingsKnown });
  const answer = cloud.data;
  // The job a count runs as (S29e), followed until it ends: its end asks the cloud again, which the server has kept.
  const jobId = answer?.state === 'counting' && !cloud.isPlaceholderData ? answer.job?.id : undefined;
  const job = useQuery({ ...cloudJobQuery(jobId ?? ''), enabled: jobId !== undefined });
  const jobState = job.data?.state;
  useEffect(() => {
    if (jobId && jobState === 'succeeded') void client.invalidateQueries({ queryKey: ['cloud', scope, lens, token] });
  }, [client, jobId, jobState, scope, lens, token]);
  // The reader's own records the scope bar offers, the app's `@Query`s.
  const collections = useQuery({ ...collectionsQuery, enabled: keepsUserData });
  const tags = useQuery({ ...tagsQuery, enabled: keepsUserData });
  const savedSearches = useQuery({ ...savedSearchesQuery, enabled: keepsUserData });
  const volumeScopes = useQuery({ ...volumeScopesQuery, enabled: keepsUserData });
  const records: ReaderRecords = {
    collections: (collections.data?.items ?? []).map((each) => ({ id: each.id, name: each.listName })),
    tags: (tags.data?.items ?? []).map((each) => ({ id: each.id, name: each.name })),
    savedSearches: (savedSearches.data?.items ?? []).map((each) => ({ id: each.id, name: each.name })),
    volumeScopes: (volumeScopes.data?.items ?? []).map((each) => ({ id: each.id, name: each.name })),
  };
  // While another scope's or lens's cloud comes, the controls show what was asked (S24h), and the cloud still drawn is
  // the one asked before: a word hidden from it is hidden from that cloud, under that lens.
  const asked = cloud.isPlaceholderData;
  const drawnScope = answer?.scope.signature ?? scope;
  const drawnLens = answer?.lens.id ?? lens;
  const [measure, setMeasure] = useState<Measure>(storedMeasure);
  // The words hidden from this open cloud alone (#233), which go when another scope's cloud is drawn, as the app's view
  // is made again.
  const [session, setSession] = useState<{ scope: string; words: string[] }>({ scope, words: [] });
  if (session.scope !== drawnScope) setSession({ scope: drawnScope, words: [] });
  const sessionWords = session.words;
  // A word hidden in a list of the reader's leaves the cloud at once, before the cloud is asked again.
  const [leaving, setLeaving] = useState<{ answer: CloudAnswer | undefined; words: string[] }>({ answer: undefined, words: [] });
  const leavingWords = leaving.answer === answer ? leaving.words : [];
  const [announcement, setAnnouncement] = useState('');
  const [failure, setFailure] = useState<string | undefined>(undefined);
  const title = useRef<HTMLHeadingElement>(null);
  const listHeading = useId();
  useDocumentTitle(words.title);
  useHeadingReady(!context.isPending);

  const shown = useMemo(() => {
    const hidden = new Set([...session.words, ...(leaving.answer === answer ? leaving.words : [])]);
    return (answer?.terms ?? []).filter((term) => !hidden.has(term.term.toLowerCase()));
  }, [answer, session, leaving]);

  function change(fields: { scope?: string; lens?: string }) {
    setFailure(undefined);
    void navigate({ search: (previous) => ({ ...previous, ...fields }) });
  }

  function hideInThisCloud(term: string) {
    setSession({ scope: drawnScope, words: [...sessionWords, term.toLowerCase()] });
    setAnnouncement(words.hiddenAnnouncement(term));
  }

  /** Shows this cloud's hidden words again, the keyboard going to the list's heading, since the button goes. */
  function showSessionWords() {
    setSession({ scope: drawnScope, words: [] });
    (document.getElementById(listHeading) ?? title.current)?.focus();
  }

  async function hideInList(term: string, inLens: boolean) {
    setFailure(undefined);
    setLeaving({ answer, words: [...leavingWords, term.toLowerCase()] });
    try {
      await hideWord(client, term, inLens ? drawnLens : undefined);
      setAnnouncement(inLens ? words.hiddenInLens(term) : words.hiddenEverywhere(term));
    } catch (error) {
      setLeaving({ answer, words: leavingWords });
      setFailure(errorMessage(error));
    }
  }

  return (
    <div className="analytics-page word-cloud">
      <h1 ref={title} tabIndex={-1} data-loading={context.isPending ? 'true' : undefined}>
        {words.title}
      </h1>
      {context.error ? (
        <Empty title={words.errorTitle} detail={errorMessage(context.error)} />
      ) : !context.data ? (
        <p className="analytics-loading" role="status">
          {words.loading}
        </p>
      ) : (
        <>
          {fromDocument && (
            <p className="cloud-document-link">
              <Link to="/doc/$volumeId/$documentId" params={fromDocument} search={{}}>
                {words.backToDocument}
              </Link>
            </p>
          )}
          <ScopeBar context={context.data} scope={scope} records={records} onChange={(next) => change({ scope: next })} />
          <Segmented
            legend={words.show}
            help={words.lensHelp}
            name="cloud-lens"
            value={lens}
            disabled={false}
            choices={lenses.map((each) => ({ value: each.id, label: each.label }))}
            onChange={(next) => change({ lens: next })}
          />
          <Segmented
            legend={words.sizeBy}
            help={words.measureHelp}
            name="cloud-measure"
            value={measure}
            disabled={false}
            choices={context.data.measures.map((each) => ({ value: each.id, label: each.label }))}
            onChange={(next) => {
              setMeasure(next as Measure);
              keepMeasure(next as Measure);
            }}
          />
          {keepsUserData && preferences && (
            <div className="cloud-options">
              <label>
                <input
                  type="checkbox"
                  checked={pending.excludeBoilerplate ?? preferences.wordCloud.excludeBoilerplate}
                  onChange={(event) => {
                    setFailure(undefined);
                    void updateWordCloud(client, { excludeBoilerplate: event.target.checked }).catch((error: unknown) => setFailure(errorMessage(error)));
                  }}
                />{' '}
                {words.boilerplate}
              </label>
              {sessionWords.length > 0 && (
                <button type="button" onClick={showSessionWords}>
                  {words.showHidden(sessionWords.length)}
                </button>
              )}
              <Link to="/settings/word-cloud">{words.settingsLink}</Link>
            </div>
          )}
          {!keepsUserData && sessionWords.length > 0 && (
            <div className="cloud-options">
              <button type="button" onClick={showSessionWords}>
                {words.showHidden(sessionWords.length)}
              </button>
            </div>
          )}
          <p className="visually-hidden" role="status">
            {announcement}
          </p>
          {failure && (
            <p className="error" role="alert">
              {failure}
            </p>
          )}
          {cloud.error ? (
            <Empty title={words.errorTitle} detail={errorMessage(cloud.error)} />
          ) : !answer ? (
            <p className="analytics-loading" role="status">
              {words.loading}
            </p>
          ) : (
            <section className="analytics-result" aria-labelledby="cloud-scope-title" aria-busy={asked || undefined}>
              <Header answer={answer} shownCount={shown.length} />
              {answer.lens.colorsBySentiment && (
                <p className="cloud-legend">
                  <span data-color="positive">{words.positive}</span> <span data-color="negative">{words.negative}</span>
                </p>
              )}
              {answer.state === 'counting' ? (
                <Counting
                  answer={answer}
                  job={job.data}
                  jobError={job.error}
                  onAgain={() => {
                    title.current?.focus();
                    void cloud.refetch();
                  }}
                />
              ) : answer.state !== 'terms' ? (
                <Empty title={answer.message?.title ?? words.errorTitle} detail={answer.message?.detail ?? ''} />
              ) : measure === 'keyness' ? (
                <Empty title={words.keynessTitle} detail={words.keynessReason} />
              ) : (
                <>
                  <Canvas answer={answer} terms={shown} />
                  <TermList
                    answer={answer}
                    terms={shown}
                    headingId={listHeading}
                    keepsUserData={keepsUserData}
                    onHideHere={hideInThisCloud}
                    onHideInLens={(term) => void hideInList(term, true)}
                    onHideEverywhere={(term) => void hideInList(term, false)}
                  />
                </>
              )}
              {answer.source === 'live'
                ? answer.account && <p className="analytics-caption cloud-made">{answer.account}</p>
                : context.data.made && <p className="analytics-caption cloud-made">{context.data.made.line}</p>}
            </section>
          )}
        </>
      )}
    </div>
  );
}

/** The reader's own records the scope bar lists, each by its id and the name a list gives it. */
interface ReaderRecords {
  collections: { id: string; name: string }[];
  tags: { id: string; name: string }[];
  savedSearches: { id: string; name: string }[];
  volumeScopes: { id: string; name: string }[];
}

/**
 * The scope bar (`WordCloudScopeBar`): Entire Corpus, each subseries, each volume under its subseries, the reader's
 * collections, tags, saved searches and volume scopes, By Subject's sub-categories under their categories, and Date Range,
 * whose two days follow it, as the app's two date pickers do.
 */
function ScopeBar({ context, scope, records, onChange }: { context: CloudContext; scope: string; records: ReaderRecords; onChange: (scope: string) => void }) {
  const id = useId();
  const range = dateRangeOf(scope);
  const listed =
    scope === 'corpus' ||
    range !== undefined ||
    context.subseries.some((each) => `sub:${each.id}` === scope || each.volumes.some((volume) => `vol:${volume.id}` === scope)) ||
    records.collections.some((each) => `col:${each.id}` === scope) ||
    records.tags.some((each) => `tag:${each.id}` === scope) ||
    records.savedSearches.some((each) => `search:${each.id}` === scope) ||
    records.volumeScopes.some((each) => `scope:${each.id}` === scope) ||
    context.subjects.some((each) => each.subcategories.some((sub) => subjectScope(each.label, sub) === scope));
  const fromDocument = documentScope(scope);
  const named = (name: string) => name.trim() || words.untitled;
  return (
    <div className="analytics-filters">
      <label className="analytics-field" htmlFor={id}>
        {words.scope}
      </label>
      <select id={id} value={range ? 'daterange' : scope} onChange={(event) => onChange(event.target.value === 'daterange' ? dateRangeScope(context.dateRange.from, context.dateRange.to) : event.target.value)}>
        {!listed && <option value={scope}>{fromDocument ? words.document(fromDocument.documentId) : scope}</option>}
        <option value="corpus">{context.corpus}</option>
        <optgroup label={words.subseries}>
          {context.subseries.map((each) => (
            <option key={each.id} value={`sub:${each.id}`}>
              {each.id}
            </option>
          ))}
        </optgroup>
        {context.subseries.map((each) => (
          <optgroup key={each.id} label={words.volumesOf(each.id)}>
            {each.volumes.map((volume) => (
              <option key={volume.id} value={`vol:${volume.id}`}>
                {volume.title.replace(/\s+/g, ' ')}
              </option>
            ))}
          </optgroup>
        ))}
        {records.collections.length > 0 && (
          <optgroup label={words.collection}>
            {records.collections.map((each) => (
              <option key={each.id} value={`col:${each.id}`}>
                {named(each.name)}
              </option>
            ))}
          </optgroup>
        )}
        {records.tags.length > 0 && (
          <optgroup label={words.tag}>
            {records.tags.map((each) => (
              <option key={each.id} value={`tag:${each.id}`}>
                {each.name}
              </option>
            ))}
          </optgroup>
        )}
        {records.savedSearches.length > 0 && (
          <optgroup label={words.savedSearch}>
            {records.savedSearches.map((each) => (
              <option key={each.id} value={`search:${each.id}`}>
                {named(each.name)}
              </option>
            ))}
          </optgroup>
        )}
        {records.volumeScopes.length > 0 && (
          <optgroup label={words.customScopes}>
            {records.volumeScopes.map((each) => (
              <option key={each.id} value={`scope:${each.id}`}>
                {named(each.name)}
              </option>
            ))}
          </optgroup>
        )}
        {context.subjects.map((each) => (
          <optgroup key={each.label} label={`${words.bySubject}: ${each.label}`}>
            {each.subcategories.map((sub) => (
              <option key={sub} value={subjectScope(each.label, sub)}>
                {sub}
              </option>
            ))}
          </optgroup>
        ))}
        <optgroup label={words.dateRange}>
          <option value="daterange">{words.dateRange}</option>
        </optgroup>
      </select>
      {range && <DateRangeFields range={range} onApply={onChange} />}
    </div>
  );
}

/**
 * A count that runs as a job (S29e): the server's words for it, the job's bar and line as it goes, and, if it ends
 * otherwise than with its cloud, why, with Count Again, which asks the cloud once more and so queues another. The live
 * region says only where the job stands, waiting or counting, so a screen reader is not told each chunk; the bar and the
 * line beside it say how far it has come.
 */
function Counting({ answer, job, jobError, onAgain }: { answer: CloudAnswer; job: CloudJob | undefined; jobError: unknown; onAgain: () => void }) {
  const current = job ?? answer.job;
  const again = (
    <button type="button" onClick={onAgain}>
      {words.countAgain}
    </button>
  );
  if (jobError || current?.state === 'failed') {
    return (
      <div className="analytics-empty">
        <h2>{words.errorTitle}</h2>
        <p>{jobError ? errorMessage(jobError) : (current?.error ?? '')}</p>
        {again}
      </div>
    );
  }
  if (current?.state === 'cancelled') {
    return (
      <div className="analytics-empty">
        <h2>{answer.message?.title ?? words.loading}</h2>
        <p>{words.jobCancelled}</p>
        {again}
      </div>
    );
  }
  return (
    <div className="analytics-empty cloud-counting">
      <h2>{answer.message?.title ?? words.loading}</h2>
      <p>{answer.message?.detail}</p>
      <progress max={1} value={current?.fraction ?? undefined} aria-label={words.jobProgressLabel} />
      <p role="status">{current?.state === 'running' ? words.jobProgressLabel : words.jobWaiting}</p>
      {current?.state === 'running' && current.progress && (
        <p className="analytics-caption">
          {current.progress}
          {current.fraction !== undefined ? ` (${words.jobProgress(current.fraction)})` : ''}
        </p>
      )}
    </div>
  );
}

/**
 * Date Range's two days (`WordCloudScopeBar`'s pickers), each typed into a field and applied by Show, as Chronology applies
 * its range, where the app's pickers apply each change: a count follows each applied range, not each digit typed.
 */
function DateRangeFields({ range, onApply }: { range: { from: string; to: string }; onApply: (scope: string) => void }) {
  const fromId = useId();
  const toId = useId();
  const address = `${range.from}|${range.to}`;
  const [shown, setShown] = useState(address);
  const [from, setFrom] = useState(range.from);
  const [to, setTo] = useState(range.to);
  if (shown !== address) {
    setShown(address);
    setFrom(range.from);
    setTo(range.to);
  }
  return (
    <form
      className="cloud-date-range"
      onSubmit={(event) => {
        event.preventDefault();
        if (from && to) onApply(dateRangeScope(from, to));
      }}
    >
      <label className="visually-hidden" htmlFor={fromId}>
        {words.rangeStart}
      </label>
      <input id={fromId} type="date" value={from} max={to || undefined} required onChange={(event) => setFrom(event.target.value)} />
      <span aria-hidden="true">–</span>
      <label className="visually-hidden" htmlFor={toId}>
        {words.rangeEnd}
      </label>
      <input id={toId} type="date" value={to} min={from || undefined} required onChange={(event) => setTo(event.target.value)} />
      <button type="submit">{words.applyRange}</button>{' '}
      <Link to="/chronology" search={{ from: range.from, to: range.to }}>
        {words.viewInChronology}
      </Link>
    </form>
  );
}

/** The scope header: the cloud's title, its count line, the chip, and what the reader's settings took out or cannot show. */
function Header({ answer, shownCount }: { answer: CloudAnswer; shownCount: number }) {
  return (
    <div className="cloud-header">
      <h2 id="cloud-scope-title">{answer.scope.title.replace(/\s+/g, ' ')}</h2>
      {answer.state === 'terms' && (
        <p className="analytics-caption">
          {shownCount === answer.terms.length
            ? answer.countLine
            : answer.documentCount !== undefined
              ? words.countFrom(shownCount, answer.documentCount)
              : words.countLine(shownCount)}
        </p>
      )}
      <p className="cloud-chip" data-era={answer.fallbackSubseries ? 'true' : undefined}>
        {answer.chip}
      </p>
      {answer.removed > 0 && <p className="analytics-note">{words.removed(answer.removed, answer.listed)}</p>}
      {answer.settingsNotShown && <p className="analytics-note">{answer.settingsNotShown}</p>}
    </div>
  );
}

/**
 * The spiral of words (`cloudCanvas`), laid out here by the app's packing at the frame's size, in the reader's typeface
 * and density for this device. A word's click charts it in Corpus Analytics, as the app's tap does; the list below is
 * its reading for a keyboard and a screen reader, as the app's list is its accessibility representation.
 */
function Canvas({ answer, terms }: { answer: CloudAnswer; terms: CloudTerm[] }) {
  const navigate = useNavigate();
  const frame = useRef<HTMLDivElement>(null);
  const [width, setWidth] = useState(0);
  const [design] = useState(storedFontDesign);
  const [density] = useState(storedDensity);
  useEffect(() => {
    const element = frame.current;
    if (!element) return;
    setWidth(element.clientWidth);
    if (typeof ResizeObserver === 'undefined') return;
    const observer = new ResizeObserver(() => setWidth(element.clientWidth));
    observer.observe(element);
    return () => observer.disconnect();
  }, []);
  const height = Math.round(Math.min(560, Math.max(320, width * 0.6)));
  const placed: PlacedWord[] = useMemo(
    () => place(terms, width, height, { spacingScale: spacingScales[density], widthFactor: widthFactors[design] }),
    [terms, width, height, density, design],
  );
  const polarity = useMemo(() => new Map(terms.map((term) => [term.term, term.polarity])), [terms]);

  return (
    <div ref={frame} className={`cloud-canvas cloud-font-${design}`}>
      {width > 0 && (
        <svg viewBox={`0 0 ${width} ${height}`} width={width} height={height} role="img" aria-label={words.canvasLabel(placed.length, terms.length)}>
          {placed.map((word) => (
            <text
              key={word.term}
              x={word.x}
              y={word.y}
              fontSize={word.fontSize}
              textAnchor="middle"
              dominantBaseline="central"
              transform={word.rotation ? `rotate(${word.rotation} ${word.x} ${word.y})` : undefined}
              data-color={wordColor(word.colorIndex, polarity.get(word.term), answer.lens.colorsBySentiment)}
              aria-hidden="true"
              onClick={() => void navigate({ to: '/analytics/corpus', search: { term: word.term } })}
            >
              <title>{words.wordTitle(word.term, word.count)}</title>
              {word.term}
            </text>
          ))}
        </svg>
      )}
    </div>
  );
}

/**
 * The ranked list (`rankedList`): each word, its bar against the first and its count, the word charting itself in Corpus
 * Analytics, and its menu, the app's word menu.
 */
function TermList({
  answer,
  terms,
  headingId,
  keepsUserData,
  onHideHere,
  onHideInLens,
  onHideEverywhere,
}: {
  answer: CloudAnswer;
  terms: CloudTerm[];
  headingId: string;
  keepsUserData: boolean;
  onHideHere: (term: string) => void;
  onHideInLens: (term: string) => void;
  onHideEverywhere: (term: string) => void;
}) {
  const navigate = useNavigate();
  const heading = useRef<HTMLHeadingElement>(null);
  const body = useRef<HTMLTableSectionElement>(null);
  const maxCount = terms[0]?.count ?? 1;

  /**
   * Hides a word, and gives the keyboard to the word that takes its place, or the one before it, or the list's heading:
   * the menu hands it back to its own button, which goes with the word's row.
   */
  function hideAndMove(action: (word: string) => void, term: string, index: number) {
    const rows = body.current?.querySelectorAll<HTMLButtonElement>('button.link-button');
    const next = rows?.[index + 1] ?? rows?.[index - 1] ?? heading.current;
    action(term);
    next?.focus();
  }

  function entries(term: CloudTerm, index: number): MenuEntry[] {
    const within = answer.analyzeWithin;
    return [
      { kind: 'item', label: words.analyze, onSelect: () => void navigate({ to: '/analytics/corpus', search: { term: term.term } }) },
      ...(within
        ? [{ kind: 'item' as const, label: within.label, onSelect: () => void navigate({ to: '/analytics/corpus', search: { term: term.term, volumes: within.volumeIds, scopeLabel: within.scopeLabel } }) }]
        : []),
      { kind: 'item', label: words.searchTerm, onSelect: () => void navigate({ to: '/search', search: { keywords: term.term } }) },
      { kind: 'separator' },
      { kind: 'item', label: words.hideSession, onSelect: () => hideAndMove(onHideHere, term.term, index), destructive: true },
      ...(keepsUserData
        ? [
            { kind: 'item' as const, label: words.hideLens, onSelect: () => hideAndMove(onHideInLens, term.term, index), destructive: true },
            { kind: 'item' as const, label: words.hideGlobal, onSelect: () => hideAndMove(onHideEverywhere, term.term, index), destructive: true },
          ]
        : []),
    ];
  }

  return (
    <div className="cloud-list">
      <h3 id={headingId} ref={heading} tabIndex={-1}>
        {words.listTitle}
      </h3>
      <table aria-labelledby={headingId}>
        <thead>
          <tr>
            <th scope="col">{words.rank}</th>
            <th scope="col">{words.term}</th>
            {answer.lens.colorsBySentiment && <th scope="col">{words.polarity}</th>}
            <th scope="col">{words.count}</th>
            <th scope="col">
              <span className="visually-hidden">{words.actions}</span>
            </th>
          </tr>
        </thead>
        <tbody ref={body}>
          {terms.map((term, index) => (
            <tr key={term.term}>
              <td className="cloud-rank">{index + 1}</td>
              <td>
                <button
                  type="button"
                  className="link-button"
                  title={words.tapHint}
                  data-color={answer.lens.colorsBySentiment ? wordColor(index, term.polarity, true) : undefined}
                  onClick={() => void navigate({ to: '/analytics/corpus', search: { term: term.term } })}
                >
                  {term.term}
                </button>
              </td>
              {answer.lens.colorsBySentiment && <td>{term.polarity === 1 ? words.positive : term.polarity === -1 ? words.negative : words.neither}</td>}
              <td className="cloud-count">
                <span className="cloud-bar" aria-hidden="true" style={{ width: `${Math.round((60 * term.count) / maxCount)}px` }} />
                {term.count.toLocaleString('en-US')}
              </td>
              <td>
                <MenuButton label={words.more} accessibleLabel={words.moreFor(term.term)} entries={entries(term, index)} className="cloud-word-menu">
                  {words.more}
                </MenuButton>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
