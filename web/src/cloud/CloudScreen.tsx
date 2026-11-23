// The Word Cloud (PLAN's S24i), at /cloud: the app's `WordCloudView` in Frequency mode, over the clouds bundled with the
// app, for the corpus, each subseries and each volume (`WordCloudScopeBar`'s three), under the four lenses they carry.
// The server reads each list with the kit and filters it by the reader's own Word Cloud settings; this page draws it, as
// the app does, in a spiral of words sized by count (`WordCloudLayout`), with the ranked list that is the cloud's
// accessible reading beside it, and a word's menu: Corpus Analytics over the series or over the cloud's own volumes,
// Search, and the three hides, this cloud alone, this lens, or every cloud. The header's chip says when a thin volume's
// era stands in for it. Distinctive is refused with its reason, as is a document's own cloud from the reader's rail,
// whose volume's cloud is shown instead: each is counted live, which waits for the server's language analysis (phase 4).
// The web's own: the cloud and its list drawn together, where the app switches between them, and the words saying what
// the reader's settings took out.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { getRouteApi, Link, useNavigate } from '@tanstack/react-router';
import { useEffect, useId, useMemo, useRef, useState } from 'react';
import { type CloudAnswer, cloudContextQuery, type CloudContext, cloudQuery, type CloudTerm, hideWord, settingsToken, updateWordCloud } from '../api/cloud';
import { errorMessage } from '../api/client';
import { meQuery } from '../api/userData';
import { copy } from '../copy';
import { Empty, Segmented } from '../analytics/CorpusAnalyticsScreen';
import { useSyncedPreferences } from '../settings/syncedPreferences';
import { useHeadingReady } from '../shell/headingFocus';
import { MenuButton, type MenuEntry } from '../shell/MenuButton';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import {
  documentScope,
  keepMeasure,
  type Measure,
  place,
  type PlacedWord,
  spacingScales,
  storedDensity,
  storedFontDesign,
  storedMeasure,
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
  // The cloud is asked once the reader's settings are known, theirs or the app's own, so it is not drawn twice.
  const settingsKnown = (me.isSuccess || me.isError) && (!keepsUserData || preferences !== undefined);
  const fromDocument = documentScope(search.scope);
  const scope = fromDocument ? `vol:${fromDocument.volumeId}` : (search.scope ?? 'corpus');
  const lenses = context.data?.lenses ?? [];
  const lens = lenses.some((each) => each.id === search.lens) ? search.lens! : (lenses[0]?.id ?? 'topics');
  const cloud = useQuery({ ...cloudQuery(scope, lens, settingsToken(keepsUserData ? preferences : undefined)), enabled: context.isSuccess && settingsKnown });
  const [measure, setMeasure] = useState<Measure>(storedMeasure);
  // The words hidden from this open cloud alone (#233), which go when its scope changes, as the app's view is made again.
  const [session, setSession] = useState<{ scope: string; words: string[] }>({ scope, words: [] });
  const sessionWords = session.scope === scope ? session.words : [];
  // A word hidden in a list of the reader's leaves the cloud at once, before the cloud is asked again.
  const [leaving, setLeaving] = useState<{ answer: CloudAnswer | undefined; words: string[] }>({ answer: undefined, words: [] });
  const leavingWords = leaving.answer === cloud.data ? leaving.words : [];
  const [announcement, setAnnouncement] = useState('');
  const [failure, setFailure] = useState<string | undefined>(undefined);
  useDocumentTitle(words.title);
  useHeadingReady(!context.isPending);

  const answer = cloud.data;
  const shown = useMemo(() => {
    const hidden = new Set([...(session.scope === scope ? session.words : []), ...(leaving.answer === answer ? leaving.words : [])]);
    return (answer?.terms ?? []).filter((term) => !hidden.has(term.term.toLowerCase()));
  }, [answer, session, leaving, scope]);
  // While another scope's or lens's cloud comes, the controls show what was asked (S24h), not the cloud still drawn.
  const asked = cloud.isPlaceholderData;

  function change(fields: { scope?: string; lens?: string }) {
    setFailure(undefined);
    void navigate({ search: (previous) => ({ ...previous, ...fields }) });
  }

  function hideInThisCloud(term: string) {
    setSession({ scope, words: [...sessionWords, term.toLowerCase()] });
    setAnnouncement(words.hiddenAnnouncement(term));
  }

  async function hideInList(term: string, inLens: boolean) {
    setFailure(undefined);
    setLeaving({ answer, words: [...leavingWords, term.toLowerCase()] });
    try {
      await hideWord(client, term, inLens ? lens : undefined);
      setAnnouncement(inLens ? words.hiddenInLens(term) : words.hiddenEverywhere(term));
    } catch (error) {
      setLeaving({ answer, words: leavingWords });
      setFailure(errorMessage(error));
    }
  }

  return (
    <div className="analytics-page word-cloud">
      <h1 tabIndex={-1} data-loading={context.isPending ? 'true' : undefined}>
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
            <p className="analytics-notice cloud-document-notice" role="note">
              {words.documentNotice}{' '}
              <Link to="/doc/$volumeId/$documentId" params={fromDocument} search={{}}>
                {words.backToDocument}
              </Link>
            </p>
          )}
          <ScopeBar context={context.data} scope={scope} onChange={(next) => change({ scope: next })} />
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
                  checked={preferences.wordCloud.excludeBoilerplate}
                  onChange={(event) => {
                    setFailure(undefined);
                    void updateWordCloud(client, { excludeBoilerplate: event.target.checked }).catch((error: unknown) => setFailure(errorMessage(error)));
                  }}
                />{' '}
                {words.boilerplate}
              </label>
              {sessionWords.length > 0 && (
                <button type="button" onClick={() => setSession({ scope, words: [] })}>
                  {words.showHidden(sessionWords.length)}
                </button>
              )}
              <Link to="/settings/word-cloud">{words.settingsLink}</Link>
            </div>
          )}
          {!keepsUserData && sessionWords.length > 0 && (
            <div className="cloud-options">
              <button type="button" onClick={() => setSession({ scope, words: [] })}>
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
              {measure === 'keyness' ? (
                <Empty title={words.keynessTitle} detail={words.keynessReason} />
              ) : answer.state !== 'terms' ? (
                <Empty title={answer.message?.title ?? words.errorTitle} detail={answer.message?.detail ?? ''} />
              ) : (
                <>
                  <Canvas answer={answer} terms={shown} />
                  <TermList
                    answer={answer}
                    terms={shown}
                    keepsUserData={keepsUserData}
                    onHideHere={hideInThisCloud}
                    onHideInLens={(term) => void hideInList(term, true)}
                    onHideEverywhere={(term) => void hideInList(term, false)}
                  />
                </>
              )}
              {context.data.made && <p className="analytics-caption cloud-made">{context.data.made.line}</p>}
            </section>
          )}
        </>
      )}
    </div>
  );
}

/** The scope bar (`WordCloudScopeBar`): Entire Corpus, each subseries, and each volume under its subseries. */
function ScopeBar({ context, scope, onChange }: { context: CloudContext; scope: string; onChange: (scope: string) => void }) {
  const id = useId();
  const listed = scope === 'corpus' || context.subseries.some((each) => `sub:${each.id}` === scope || each.volumes.some((volume) => `vol:${volume.id}` === scope));
  return (
    <div className="analytics-filters">
      <label className="analytics-field" htmlFor={id}>
        {words.scope}
      </label>
      <select id={id} value={scope} onChange={(event) => onChange(event.target.value)}>
        {!listed && <option value={scope}>{scope}</option>}
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
      </select>
    </div>
  );
}

/** The scope header: the cloud's title, its count line, the chip, and what the reader's settings took out or cannot show. */
function Header({ answer, shownCount }: { answer: CloudAnswer; shownCount: number }) {
  return (
    <div className="cloud-header">
      <h2 id="cloud-scope-title">{answer.scope.title.replace(/\s+/g, ' ')}</h2>
      {answer.state === 'terms' && <p className="analytics-caption">{shownCount === answer.terms.length ? answer.countLine : words.countLine(shownCount)}</p>}
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
  keepsUserData,
  onHideHere,
  onHideInLens,
  onHideEverywhere,
}: {
  answer: CloudAnswer;
  terms: CloudTerm[];
  keepsUserData: boolean;
  onHideHere: (term: string) => void;
  onHideInLens: (term: string) => void;
  onHideEverywhere: (term: string) => void;
}) {
  const navigate = useNavigate();
  const headingId = useId();
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
