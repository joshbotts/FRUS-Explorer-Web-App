// Look Up in NARA Catalog (PLAN's S22e), the selection bar's fourth verb, as the app's sheet
// (`NARACatalogLookupView`) runs it. Its sections in the iOS sheet's order: Search Text, the selection,
// trimmed, to edit; Detected in This Passage, the kit's readings of the selection and the passage around it,
// best first, each filling the search with its query and its strategy, and showing the record the bundled
// indexes give it with no key; Query Strategy, the kit's six, opened on the first reading's or Keywords in
// RG 59, with the strategy's hint and, without a key, the app's warning; then, for Central files identifier,
// NARA's finding aids for each filing period, and for the others, once Search has run, NARA Catalog
// Results. Nothing is searched until Search, which needs text and a key, the user's or the instance's: a
// tap fills, Search looks up, as the app's sheet does, through the server's NARA proxy. A reading, a change
// of strategy and a new search each clear the last results, and an answer that comes after them is dropped;
// as the app's `isSearching` outlasts them, Search waits for the search out to answer. The web's own: the
// line while the passage is read, what the results' line says of a search that found records, Search held
// until the passage is read, and the warning on a server that is offline or keeps no user data.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useId, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import {
  canSearch,
  type LookUpCandidate,
  type LookUpSelection,
  lookUpQuery,
  type NARACatalogRecord,
  naraStatusQuery,
  searchNARA,
} from '../api/nara';
import { meQuery } from '../api/userData';
import { copy } from '../copy';
import { Modal } from '../shell/Modal';

const words = copy.lookUp;

type Search = { state: 'searching' } | { state: 'found'; results: NARACatalogRecord[] } | { state: 'failed'; message: string };

export function LookUpDialog({
  volumeId,
  documentId,
  selection,
  onClose,
}: {
  volumeId: string;
  documentId: string;
  selection: LookUpSelection;
  onClose: () => void;
}) {
  const client = useQueryClient();
  const id = useId();
  const sheet = useQuery(lookUpQuery(client, volumeId, documentId, selection));
  const status = useQuery(naraStatusQuery);
  const me = useQuery(meQuery);
  // The app's `hasAPIKey`: a key the server would search with, the user's or the instance's, on a server not offline.
  const keyed = canSearch(status.data);
  const [text, setText] = useState(selection.text.trim());
  const [chosen, setChosen] = useState<string | null>(null);
  const [search, setSearch] = useState<Search | null>(null);
  // The search out, which Search waits for, and the count of changes since it was asked, whose answer is
  // dropped once the sheet has changed under it.
  const [asking, setAsking] = useState(false);
  const generation = useRef(0);
  // The sheet opens on the first reading's strategy, else Keywords in RG 59, as the server says the app's does.
  const strategy = chosen ?? sheet.data?.strategy ?? 'keywordRG59';
  const strategies = sheet.data?.strategies ?? [];
  const current = strategies.find((each) => each.id === strategy);
  const showsPeriodLinks = strategy === 'centralURL';
  const query = text.trim();
  // The strategies come with the passage's reading, so Search waits for it, and has none when it failed.
  const searchable = !asking && sheet.isSuccess && query !== '' && keyed;
  const warning = status.data?.offline ? words.offline : me.data?.userData === false ? words.noServerKey : words.noKey;
  const warns = !!current?.searches && !!status.data && !keyed;

  /** A change under the last results: they are cleared, and an answer still out is dropped. */
  function cleared() {
    generation.current += 1;
    setSearch(null);
  }

  /** `apply(_:)`: the reading's query and strategy, and the last results cleared. */
  function apply(candidate: LookUpCandidate) {
    setText(candidate.query);
    setChosen(candidate.strategy);
    cleared();
  }

  /** `runSearch()`, through the server: the strategy over the text, trimmed. */
  async function run() {
    if (!searchable || showsPeriodLinks) return;
    const asked = ++generation.current;
    setChosen(strategy);
    setAsking(true);
    setSearch({ state: 'searching' });
    try {
      const answer = await searchNARA(client, { strategy, query });
      if (generation.current === asked) setSearch({ state: 'found', results: answer.results });
    } catch (error) {
      if (generation.current === asked) setSearch({ state: 'failed', message: errorMessage(error) });
    } finally {
      setAsking(false);
    }
  }

  const candidates = sheet.data?.candidates ?? [];
  return (
    <Modal className="lookup-sheet" labelledBy={`${id}-title`} onCancel={onClose} onClose={onClose}>
      <h2 id={`${id}-title`} tabIndex={-1}>
        {words.title}
      </h2>
      <form
        onSubmit={(event) => {
          event.preventDefault();
          void run();
        }}
      >
        <section aria-labelledby={`${id}-query`}>
          <h3 id={`${id}-query`}>{words.queryHeader}</h3>
          <input
            type="text"
            aria-labelledby={`${id}-query`}
            aria-describedby={`${id}-query-hint`}
            placeholder={words.queryPlaceholder}
            autoComplete="off"
            autoCapitalize="off"
            spellCheck={false}
            value={text}
            onChange={(event) => setText(event.target.value)}
          />
          <p id={`${id}-query-hint`} className="hint">
            {words.queryHint}
          </p>
        </section>
        {sheet.isPending && (
          <p className="note" role="status">
            {words.reading}
          </p>
        )}
        {sheet.isError && (
          <p className="error" role="alert">
            {errorMessage(sheet.error)}
          </p>
        )}
        {status.isError && (
          <p className="error" role="alert">
            {errorMessage(status.error)}
          </p>
        )}
        {candidates.length > 0 && (
          <section aria-labelledby={`${id}-detected`}>
            <h3 id={`${id}-detected`}>{words.detectedHeader}</h3>
            <p className="hint">{words.detectedHint}</p>
            <ul className="lookup-candidates">
              {candidates.map((candidate) => (
                <li key={candidate.id}>
                  <button type="button" aria-describedby={`${id}-fills`} onClick={() => apply(candidate)}>
                    <span>{candidate.label}</span>
                    {candidate.resolution && (
                      <>
                        <span className="resolved">{candidate.resolution.title}</span>
                        <span className="resolved">{words.resolved(candidate.resolution.naId)}</span>
                      </>
                    )}
                  </button>
                </li>
              ))}
            </ul>
            <p id={`${id}-fills`} hidden>
              {words.detectedTapHint}
            </p>
          </section>
        )}
        {strategies.length > 0 && (
          <fieldset aria-describedby={`${id}-strategy-hint`}>
            <legend>{words.strategyHeader}</legend>
            {strategies.map((each) => (
              <label key={each.id}>
                <input
                  type="radio"
                  name={`${id}-strategy`}
                  value={each.id}
                  checked={each.id === strategy}
                  onChange={() => {
                    setChosen(each.id);
                    cleared();
                  }}
                />{' '}
                {each.name}
              </label>
            ))}
            <p id={`${id}-strategy-hint`} className="hint">
              {current?.hint}
            </p>
            {warns && (
              <p id={`${id}-warning`} className="hint warning">
                {warning}
              </p>
            )}
          </fieldset>
        )}
        {showsPeriodLinks ? (
          <section aria-labelledby={`${id}-periods`}>
            <h3 id={`${id}-periods`}>{words.periodHeader}</h3>
            <p className="hint">{words.periodIntro}</p>
            <ul className="lookup-results">
              {(sheet.data?.periods ?? []).map((period) => (
                <li key={period.id}>
                  <a href={period.url} target="_blank" rel="noopener noreferrer">
                    {period.label}
                  </a>
                  {period.manuals.map((manual) => (
                    <p key={manual.url} className="hint">
                      <a href={manual.url} target="_blank" rel="noopener noreferrer">
                        {manual.label ?? manual.url}
                      </a>
                    </p>
                  ))}
                </li>
              ))}
            </ul>
          </section>
        ) : (
          search && (
            <section aria-labelledby={`${id}-results`}>
              <h3 id={`${id}-results`}>{words.resultsHeader}</h3>
              <p className="note" role="status">
                {search.state === 'searching'
                  ? words.searching
                  : search.state === 'found'
                    ? search.results.length === 0
                      ? words.noResults
                      : words.found(search.results.length)
                    : ''}
              </p>
              {search.state === 'failed' && (
                <p className="error" role="alert">
                  {search.message}
                </p>
              )}
              {search.state === 'found' && search.results.length > 0 && (
                <ul className="lookup-results">
                  {search.results.map((result) => (
                    <li key={result.naId}>
                      <p>
                        <strong>{result.title}</strong>
                      </p>
                      {result.scopeNote && <p className="se-scope">{result.scopeNote}</p>}
                      {result.dateRange && <p className="hint">{result.dateRange}</p>}
                      <a href={result.catalogURL} target="_blank" rel="noopener noreferrer">
                        {words.viewRecord}
                      </a>
                    </li>
                  ))}
                </ul>
              )}
            </section>
          )
        )}
        <div className="dialog-actions">
          <button type="button" onClick={onClose}>
            {words.close}
          </button>
          {/* aria-disabled, not disabled, so Search pressed by keyboard keeps its focus while it runs. */}
          {!showsPeriodLinks && (
            <button type="submit" className="primary" aria-disabled={!searchable} aria-describedby={warns ? `${id}-warning` : undefined}>
              {words.search}
            </button>
          )}
        </div>
      </form>
    </Modal>
  );
}
