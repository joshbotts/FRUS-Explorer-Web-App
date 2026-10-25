// Citation Lookup (SPEC, Citation; PLAN's S19a), at /lookup, as the app's window lays it out: the
// input mode, Paste Citation's text or Batch's footnotes, the Parsed Fields that Paste Citation fills
// and Structured Entry is, Look Up, and the results, each with the kit's label, or Batch's triage
// table with its summary. What a citation says, which fields it fills, whether Look Up has anything
// to go on, and every match, label and count are the kit's, from the server; this screen draws them.
import { useQuery, useQueryClient, type UseQueryResult } from '@tanstack/react-query';
import { Link } from '@tanstack/react-router';
import { type KeyboardEvent, useEffect, useId, useState } from 'react';
import { errorMessage } from '../api/client';
import { citationBatchQuery, citationFormQuery, citationLookupQuery } from '../api/endpoints';
import type { CitationBatch, CitationBatchRow, CitationFields, CitationLookupMatch, CitationLookupMode } from '../api/types';
import { copy } from '../copy';
import { plainTitle, useDocumentTitle } from '../shell/useDocumentTitle';
import { batchOutcome, batchRowTarget, matchAction, sortedBatchRows, strategyBadges } from './lookupRules';
import {
  fieldNames,
  formRequest,
  lookupState,
  setBatch,
  setDerived,
  setField,
  setLookup,
  setMode,
  setNeedsWorkFirst,
  setText,
  shownFields,
  useLookupState,
} from './lookupState';
import { SymbolIcon } from './SymbolIcon';

/** The modes in the app's order, `CitationLookupMode.allCases`. */
const modes: CitationLookupMode[] = ['paste', 'structured', 'batch'];

/** The Parsed Fields' labels and prompts, in the app's order; Document no. and Page take numbers. */
const fieldLabels: Record<keyof CitationFields, { label: string; placeholder: string; numeric?: true }> = {
  subseries: { label: copy.lookup.subseries, placeholder: copy.lookup.subseriesPlaceholder },
  volumeNumber: { label: copy.lookup.volume, placeholder: copy.lookup.volumePlaceholder },
  partNumber: { label: copy.lookup.part, placeholder: copy.lookup.partPlaceholder },
  documentNumber: { label: copy.lookup.document, placeholder: copy.lookup.documentPlaceholder, numeric: true },
  pageNumber: { label: copy.lookup.page, placeholder: copy.lookup.pagePlaceholder, numeric: true },
};

/** How long the form waits after a keystroke before it asks the kit about what was typed. */
const settle = 150;

/**
 * `value` once it has stood unchanged for `delay` milliseconds, compared by its JSON, from which it
 * is read back: so a render that gives the same value as a new object does not start the wait again.
 */
function useSettled<T>(value: T, delay: number): T {
  const key = JSON.stringify(value);
  const [settled, setSettled] = useState({ key, value });
  useEffect(() => {
    if (key === settled.key) return;
    const timer = setTimeout(() => setSettled({ key, value: JSON.parse(key) as T }), delay);
    return () => clearTimeout(timer);
  }, [key, delay, settled.key]);
  return settled.value;
}

export function LookupScreen() {
  const form = useLookupState();
  const queryClient = useQueryClient();
  useDocumentTitle(copy.lookup.title);

  // What the paste yields, asked of the kit whenever the text the fields are derived from changes.
  const derivedFrom = useSettled(form.derivedFrom, settle);
  const derivation = useQuery(citationFormQuery({ mode: 'paste', text: derivedFrom }));
  useEffect(() => {
    const fields = derivation.data;
    if (!fields || derivation.isPlaceholderData) return;
    setDerived(derivedFrom, Object.fromEntries(fieldNames.map((name) => [name, fields[name]])) as unknown as CitationFields);
  }, [derivation.data, derivation.isPlaceholderData, derivedFrom]);

  // Look Up's gate for what the form holds in its mode, as the kit's form gives it.
  const settledRequest = useSettled(formRequest(form), settle);
  const gate = useQuery(citationFormQuery(settledRequest));
  const lookup = useQuery(citationLookupQuery(form.lookup));
  const batch = useQuery(citationBatchQuery(form.batch));
  const busy = form.mode === 'batch' ? batch.isFetching : lookup.isFetching;
  const actionable = gate.data?.actionable === true;

  /**
   * Look Up, from the button or Return in a field: once the kit says the form, as it is now, has
   * something to go on, the lookup in its mode; the same lookup again is asked again, as the app's
   * Look Up runs whatever it last ran.
   */
  async function lookUp() {
    const current = formRequest(lookupState());
    if (busy) return;
    // The gate is asked again for what the form holds now, which a keystroke may have changed since.
    const answer = await queryClient.fetchQuery(citationFormQuery(current)).catch(() => null);
    if (answer && !answer.actionable) return;
    const state = lookupState();
    if (current.mode === 'batch') {
      const text = current.text ?? '';
      if (state.batch === text) void queryClient.refetchQueries({ queryKey: citationBatchQuery(text).queryKey, exact: true });
      else setBatch(text);
    } else if (JSON.stringify(state.lookup) === JSON.stringify(current)) {
      void queryClient.refetchQueries({ queryKey: citationLookupQuery(current).queryKey, exact: true });
    } else {
      setLookup(current);
    }
  }

  return (
    <section className="screen lookup">
      <h1 tabIndex={-1}>{copy.lookup.title}</h1>
      <form
        className="lookup-form"
        onSubmit={(event) => {
          event.preventDefault();
          void lookUp();
        }}
      >
        <fieldset className="lookup-modes">
          <legend className="visually-hidden">{copy.lookup.mode}</legend>
          {modes.map((mode) => (
            <label key={mode}>
              <input type="radio" name="lookup-mode" value={mode} checked={form.mode === mode} onChange={() => setMode(mode)} />
              <span>{copy.lookup.modes[mode]}</span>
            </label>
          ))}
        </fieldset>
        {form.mode === 'paste' && <PasteField text={form.text} />}
        {form.mode === 'batch' && <BatchField text={form.text} />}
        {/* Batch never reads the Parsed Fields, so it does not show them, as the app's does not. */}
        {form.mode !== 'batch' && <ParsedFields fields={shownFields(form)} />}
        <div className="lookup-actions">
          {/* Never disabled outright, so focus stays on it while it looks up, and it can say why it waits. */}
          <button type="submit" className="lookup-button" aria-disabled={!actionable || busy} title={copy.lookup.lookUpHelp}>
            {busy ? (
              <>
                <span className="spinner" aria-hidden="true" /> {copy.lookup.searching}
              </>
            ) : (
              copy.lookup.lookUp
            )}
          </button>
        </div>
      </form>
      {form.mode === 'batch'
        ? form.batch !== undefined && <BatchResults query={batch} needsWorkFirst={form.needsWorkFirst} />
        : form.lookup !== undefined && <LookupResults query={lookup} />}
    </section>
  );
}

/** Paste Citation's text, where Return runs the lookup: a citation is pasted, not typed in lines. */
function PasteField({ text }: { text: string }) {
  const id = useId();
  return (
    <div className="lookup-field">
      <label htmlFor={id}>{copy.lookup.pasteHeader}</label>
      <textarea
        id={id}
        rows={3}
        value={text}
        placeholder={copy.lookup.pastePlaceholder}
        spellCheck={false}
        autoCapitalize="off"
        autoComplete="off"
        onChange={(event) => setText(event.target.value)}
        onKeyDown={submitOnReturn}
      />
    </div>
  );
}

function submitOnReturn(event: KeyboardEvent<HTMLTextAreaElement>) {
  if (event.key !== 'Enter' || event.shiftKey || event.nativeEvent.isComposing) return;
  event.preventDefault();
  event.currentTarget.form?.requestSubmit();
}

/** Batch's footnotes, a block of lines, where Return begins a line as in any editor. */
function BatchField({ text }: { text: string }) {
  const id = useId();
  const footer = useId();
  return (
    <div className="lookup-field">
      <label htmlFor={id}>{copy.lookup.batchHeader}</label>
      <textarea
        id={id}
        className="footnotes"
        rows={8}
        value={text}
        spellCheck={false}
        autoCapitalize="off"
        autoComplete="off"
        aria-describedby={footer}
        onChange={(event) => setText(event.target.value)}
      />
      <p id={footer} className="note">
        {copy.lookup.batchFooter}
      </p>
    </div>
  );
}

/** The Parsed Fields: what the paste yielded, or what the reader typed in Structured Entry. */
function ParsedFields({ fields }: { fields: CitationFields }) {
  const footer = useId();
  return (
    <fieldset className="parsed-fields" aria-describedby={footer}>
      <legend>{copy.lookup.fieldsHeader}</legend>
      <div className="parsed-grid">
        {fieldNames.map((name) => (
          <label key={name}>
            <span>{fieldLabels[name].label}</span>
            <input
              type="text"
              value={fields[name]}
              placeholder={fieldLabels[name].placeholder}
              inputMode={fieldLabels[name].numeric ? 'numeric' : undefined}
              spellCheck={false}
              autoCapitalize="off"
              autoComplete="off"
              onChange={(event) => setField(name, event.target.value)}
            />
          </label>
        ))}
      </div>
      <p id={footer} className="note">
        {copy.lookup.fieldsFooter}
      </p>
    </fieldset>
  );
}

/** Paste Citation's and Structured Entry's results, as the app's results section shows them. */
function LookupResults({ query }: { query: UseQueryResult<CitationLookupMatch[], unknown> }) {
  const matches = query.data;
  const outcome = query.isError
    ? errorMessage(query.error)
    : matches === undefined || query.isFetching
      ? undefined
      : matches.length === 0
        ? copy.lookup.noMatchTitle
        : copy.lookup.matchesFound(matches.length);
  return (
    <section className="lookup-results" aria-busy={query.isFetching}>
      {/* Empty while it looks up, so every outcome is announced, as the app announces each one. */}
      <p role="status" className="visually-hidden">
        {outcome ?? ''}
      </p>
      {query.isError ? (
        <div className="lookup-outcome" role="alert">
          <h2>{copy.lookup.errorTitle}</h2>
          <p>{errorMessage(query.error)}</p>
        </div>
      ) : matches === undefined ? (
        <p className="note">{copy.lookup.searching}</p>
      ) : matches.length === 0 ? (
        <div className="lookup-outcome">
          <h2>{copy.lookup.noMatchTitle}</h2>
          <p>{copy.lookup.noMatchDetail}</p>
        </div>
      ) : (
        <>
          <h2 id="lookup-results-heading">{copy.lookup.results(matches.length)}</h2>
          <ol className="match-list" aria-labelledby="lookup-results-heading">
            {matches.map((match) => (
              <MatchRow key={`${match.volumeId}/${match.documentId}/${match.rank}`} match={match} />
            ))}
          </ol>
        </>
      )}
    </section>
  );
}

/**
 * A result, as the app's result row draws it: the kit's label beside the symbol and in the colour of
 * its strategy; the volume's title for a row naming a volume, else the document's id; the volume's
 * id; the kit's note, when it applied a correction; and what the row offers.
 */
function MatchRow({ match }: { match: CitationLookupMatch }) {
  const badge = strategyBadges[match.matchStrategy];
  const action = matchAction(match);
  const entry = match.volumeManifestEntry;
  const title = entry ? plainTitle(entry.title) : match.documentId;
  const volumeId = entry?.volumeId ?? match.volumeId;
  return (
    <li className="match">
      <p className={`confidence tone-${badge.tone}`} data-strategy={match.matchStrategy}>
        <SymbolIcon name={badge.symbol} />
        <span>{match.confidenceLabel}</span>
      </p>
      <h3>{title}</h3>
      <p className="meta">{volumeId}</p>
      {match.correctionNote && <p className="match-note">{match.correctionNote}</p>}
      {action === 'document' && (
        <Link
          to="/doc/$volumeId/$documentId"
          params={{ volumeId: match.volumeId, documentId: match.documentId }}
          className="button primary"
          title={copy.lookup.viewDocumentHelp}
        >
          {copy.lookup.viewDocument}
          <span className="visually-hidden">
            , {match.documentId}, {match.volumeId}
          </span>
        </Link>
      )}
      {action === 'volume' && (
        <Link to="/browse/$volumeId" params={{ volumeId: match.volumeId }} className="button" title={copy.lookup.viewVolumeHelp}>
          {copy.lookup.viewVolume}
          <span className="visually-hidden">, {match.volumeId}</span>
        </Link>
      )}
    </li>
  );
}

/** Batch's triage table, as the app's shows it: the summary, Needs work first, and a row per note. */
function BatchResults({ query, needsWorkFirst }: { query: UseQueryResult<CitationBatch, unknown>; needsWorkFirst: boolean }) {
  const batch = query.data;
  const outcome = query.isError ? errorMessage(query.error) : batch === undefined || query.isFetching ? undefined : batch.summary;
  return (
    <section className="lookup-results" aria-busy={query.isFetching}>
      {/* Empty while it looks up, so every outcome is announced, as the app announces each one. */}
      <p role="status" className="visually-hidden">
        {outcome ?? ''}
      </p>
      {query.isError ? (
        <div className="lookup-outcome" role="alert">
          <h2>{copy.lookup.errorTitle}</h2>
          <p>{errorMessage(query.error)}</p>
        </div>
      ) : batch === undefined ? (
        <p className="note">{copy.lookup.searching}</p>
      ) : batch.items.length === 0 ? (
        <div className="lookup-outcome">
          <h2>{copy.lookup.batchEmptyTitle}</h2>
          <p>{copy.lookup.batchEmptyDetail}</p>
        </div>
      ) : (
        <>
          <div className="batch-header">
            <h2 id="batch-summary">{batch.summary}</h2>
            <button type="button" className="toggle" aria-pressed={needsWorkFirst} onClick={() => setNeedsWorkFirst(!needsWorkFirst)}>
              {copy.lookup.needsWorkFirst}
            </button>
          </div>
          <ul className="batch-rows" aria-labelledby="batch-summary">
            {sortedBatchRows(batch.items, needsWorkFirst).map((row) => (
              <BatchRow key={row.index} row={row} />
            ))}
          </ul>
        </>
      )}
    </section>
  );
}

/**
 * A note of the table: its number as printed, or its place in the paste; its text, which opens the
 * document its one answer names; and its outcome, in the kit's words where the kit has them.
 */
function BatchRow({ row }: { row: CitationBatchRow }) {
  const target = batchRowTarget(row);
  const outcome = batchOutcome(row);
  return (
    <li className="batch-row" data-outcome={row.outcome}>
      <span className="batch-marker">{row.marker ?? row.index}</span>
      <div>
        {target ? (
          <Link to="/doc/$volumeId/$documentId" params={{ volumeId: target.volumeId, documentId: target.documentId }} className="batch-text">
            {row.text}
          </Link>
        ) : (
          <p className="batch-text">{row.text}</p>
        )}
        <p className={`batch-outcome tone-${outcome.tone}`}>
          <SymbolIcon name={outcome.symbol} />
          <span>{outcome.label}</span>
        </p>
      </div>
    </li>
  );
}
