// A person's sheet (PLAN's S21g), the app's `PersonIndexDetailSheet`: the name, the volumes' description, the
// register's life years and role, the reconciled mark, Mentions and Active, Find all mentions, the VIAF and Wikidata
// links, and for a curator the app's corrections: Merge with another person…, its picker (`PersonMergePickerSheet`)
// and its question; Possibly the Same Person, each with Merge; and the identity's records, each with Separate. A
// correction ends the sheet, as the app's dismisses it, once the server has answered, and the screen says what it did.
// The register's career and the volumes' subjects wait for kit members an upstream pull request makes public.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Link } from '@tanstack/react-router';
import { useId, useRef, useState } from 'react';
import { ApiError, errorMessage } from '../api/client';
import {
  type CorrectionOutcome,
  mergePeople,
  type PeopleList,
  personQuery,
  type PersonRow,
  type PersonSheet as Sheet,
  separatePerson,
} from '../api/people';
import { copy } from '../copy';
import { closeAtOnce, Modal } from '../shell/Modal';
import { mergeQuestion, pickerRows } from './peopleRules';

/** What a correction did, as the screen's line says it. */
export function outcomeLine(done: string, outcome: CorrectionOutcome): string {
  if (outcome.state === 'nextExport') return `${done}. ${copy.people.keptForExport}`;
  if (outcome.state === 'waiting') return `${done}. ${copy.people.keptForJob}`;
  return done;
}

export function PersonSheet({
  row,
  list,
  curator,
  onClose,
}: {
  row: PersonRow;
  list: PeopleList;
  curator: boolean;
  /** Called once it has closed, with what a correction did, or nothing. */
  onClose: (said?: string) => void;
}) {
  const client = useQueryClient();
  const sheet = useQuery(personQuery(row.rollupId));
  const headingId = useId();
  const body = useRef<HTMLDivElement>(null);
  const mergeButton = useRef<HTMLButtonElement>(null);
  const [picking, setPicking] = useState(false);
  const [confirming, setConfirming] = useState<PersonRow | null>(null);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const said = useRef<string | undefined>(undefined);
  const data = sheet.data;

  function close() {
    body.current?.closest('dialog')?.close();
  }

  /** A correction's tail, the app's `applyCorrection`: say it is under way, send it, and close with what it did. */
  async function correct(done: string, send: (version: string) => Promise<CorrectionOutcome>) {
    if (busy || !data) return;
    setBusy(true);
    setFailure(null);
    try {
      const outcome = await send(data.version);
      said.current = outcomeLine(done, outcome);
      closeAtOnce(close);
    } catch (error) {
      setBusy(false);
      if (error instanceof ApiError && error.code === 'PEOPLE_CHANGED') {
        await client.invalidateQueries({ queryKey: ['people'] });
        said.current = copy.people.peopleChanged;
        closeAtOnce(close);
        return;
      }
      setFailure(errorMessage(error));
    }
  }

  const merge = (other: { rollupId: number; name: string }) =>
    correct(copy.people.mergeDone(other.name, row.name), (version) => mergePeople(client, row.rollupId, other.rollupId, version));

  return (
    <Modal className="person-sheet" labelledBy={headingId} onCancel={() => !busy && close()} onClose={() => onClose(said.current)}>
      <div ref={body}>
        <h2 id={headingId} tabIndex={-1}>
          {row.name}
        </h2>
        {sheet.isError ? (
          <p className="error" role="alert">
            {errorMessage(sheet.error)}
          </p>
        ) : !data ? (
          <p role="status">{copy.people.loading}</p>
        ) : (
          <SheetBody
            data={data}
            curator={curator}
            busy={busy}
            mergeButton={mergeButton}
            onPick={() => setPicking(true)}
            onMerge={(candidate) => void merge(candidate)}
            onSeparate={(record) =>
              void correct(copy.people.separateDone(record.name), (version) => separatePerson(client, row.rollupId, record, version))
            }
          />
        )}
        {busy && <p role="status">{copy.people.inProgress}</p>}
        {failure && (
          <p className="error" role="alert">
            {failure}
          </p>
        )}
        <div className="actions">
          <button type="button" aria-disabled={busy} onClick={() => !busy && close()}>
            {copy.people.done}
          </button>
        </div>
      </div>
      {picking && (
        <MergePicker
          list={list}
          excluding={row.rollupId}
          onClose={(picked) => {
            setPicking(false);
            if (picked) setConfirming(picked);
            else requestAnimationFrame(() => mergeButton.current?.focus());
          }}
        />
      )}
      {confirming && data && (
        <MergeQuestion
          target={confirming}
          current={{ name: data.name, authorityId: data.authorityId }}
          onClose={(confirmed) => {
            const target = confirming;
            setConfirming(null);
            if (confirmed) void merge(target);
            else requestAnimationFrame(() => mergeButton.current?.focus());
          }}
        />
      )}
    </Modal>
  );
}

function SheetBody({
  data,
  curator,
  busy,
  mergeButton,
  onPick,
  onMerge,
  onSeparate,
}: {
  data: Sheet;
  curator: boolean;
  busy: boolean;
  mergeButton: { current: HTMLButtonElement | null };
  onPick: () => void;
  onMerge: (candidate: { rollupId: number; name: string }) => void;
  onSeparate: (record: { volumeId: string; ref: string; name: string }) => void;
}) {
  const mergeFooterId = useId();
  const candidatesId = useId();
  const recordsId = useId();
  return (
    <>
      <div className="person-head">
        {data.description && <p className="person-description">{data.description}</p>}
        {(data.lifespan || data.registerRole) && (
          <p className="meta">
            {[data.lifespan, data.registerRole].filter(Boolean).join(' · ')}
          </p>
        )}
        {data.reconciled && (
          <p className="meta" title={copy.people.reconciledHelp}>
            {copy.people.reconciled}
          </p>
        )}
      </div>
      <dl className="person-facts">
        <dt>{copy.people.mentions}</dt>
        <dd>{data.mentions}</dd>
        {data.active && (
          <>
            <dt>{copy.people.active}</dt>
            <dd>{data.active}</dd>
          </>
        )}
      </dl>
      <ul className="person-links">
        <li>
          {data.mentionCount > 0 ? (
            <Link
              to="/search"
              search={{ keywords: '', personRollupId: String(data.rollupId), personLabel: data.name }}
              title={copy.people.findMentionsHelp}
            >
              {copy.people.findMentions}
            </Link>
          ) : (
            <>
              <span aria-disabled="true">{copy.people.findMentions}</span>
              <p className="note">{copy.people.noMentions}</p>
            </>
          )}
        </li>
        {data.viafURL && (
          <li>
            <a href={data.viafURL} target="_blank" rel="noopener noreferrer" title={copy.people.viafHelp}>
              {copy.people.viaf}
            </a>
          </li>
        )}
        {data.wikidataURL && (
          <li>
            <a href={data.wikidataURL} target="_blank" rel="noopener noreferrer" title={copy.people.wikidataHelp}>
              {copy.people.wikidata}
            </a>
          </li>
        )}
      </ul>
      {curator && (
        <div className="person-merge">
          <button ref={mergeButton} type="button" aria-disabled={busy} aria-describedby={mergeFooterId} title={copy.people.mergeManualHelp}
            onClick={() => !busy && onPick()}>
            {copy.people.mergeManual}
          </button>
          <p id={mergeFooterId} className="note">
            {copy.people.mergeManualFooter}
          </p>
        </div>
      )}
      {data.candidates.length > 0 && (
        <section aria-labelledby={candidatesId}>
          <h3 id={candidatesId}>{copy.people.possiblySameHeader}</h3>
          <ul className="person-candidates">
            {data.candidates.map((candidate) => (
              <li key={candidate.rollupId}>
                <span>{candidate.name}</span>
                {candidate.reason && <span className="meta">{candidate.reason}</span>}
                {curator && (
                  <button type="button" aria-disabled={busy} aria-label={copy.people.mergeSpoken(candidate.name)}
                    onClick={() => !busy && onMerge(candidate)}>
                    {copy.people.merge}
                  </button>
                )}
              </li>
            ))}
          </ul>
          {curator && <p className="note">{copy.people.possiblySameFooter}</p>}
        </section>
      )}
      {data.records.length > 1 && (
        <section aria-labelledby={recordsId}>
          <h3 id={recordsId}>{copy.people.recordsHeader(data.records.length)}</h3>
          <ul className="person-records">
            {data.records.map((record) => (
              <li key={`${record.volumeId}|${record.ref}`}>
                <span>{record.name}</span>
                <span className="meta">{record.volumeId}</span>
                {curator && (
                  <button type="button" className="destructive" aria-disabled={busy} aria-label={copy.people.separateSpoken(record.name)}
                    onClick={() => !busy && onSeparate(record)}>
                    {copy.people.separate}
                  </button>
                )}
              </li>
            ))}
          </ul>
          {curator && <p className="note">{copy.people.recordsFooter}</p>}
        </section>
      )}
    </>
  );
}

/** How many of the picker's matches it lists. */
const pickerShown = 200;

/** The app's `PersonMergePickerSheet`: every other identity, searched by name, case and diacritics aside. */
function MergePicker({ list, excluding, onClose }: { list: PeopleList; excluding: number; onClose: (picked?: PersonRow) => void }) {
  const headingId = useId();
  const searchId = useId();
  const hintId = useId();
  const field = useRef<HTMLInputElement>(null);
  const body = useRef<HTMLDivElement>(null);
  const [query, setQuery] = useState('');
  const picked = useRef<PersonRow | undefined>(undefined);
  // The list the screen holds, which the sheet's merge is checked against; the first rows of the matches, the
  // rest found by searching, the web's own, where the app's list draws every row it scrolls to.
  const matches = pickerRows(list, excluding, query.trim());
  const rows = matches.slice(0, pickerShown);

  function close() {
    body.current?.closest('dialog')?.close();
  }

  return (
    <Modal className="merge-picker" labelledBy={headingId} initial={field} onCancel={close} onClose={() => onClose(picked.current)}>
      <div ref={body}>
        <h2 id={headingId} tabIndex={-1}>
          {copy.people.pickerTitle}
        </h2>
        <label htmlFor={searchId} className="visually-hidden">
          {copy.people.searchPrompt}
        </label>
        <input ref={field} id={searchId} type="search" placeholder={copy.people.searchPrompt} value={query} autoComplete="off"
          onChange={(event) => setQuery(event.target.value)} />
        <p id={hintId} className="visually-hidden">
          {copy.people.pickerHint}
        </p>
        {rows.length === 0 ? (
          <div className="empty">
            <p>{copy.people.noResults(query.trim())}</p>
            <p>{copy.people.noResultsDetail}</p>
          </div>
        ) : (
          <ul className="picker-rows" aria-label={copy.people.pickerTitle}>
            {rows.map((row) => (
              <li key={row.rollupId}>
                <button type="button" aria-describedby={hintId}
                  aria-label={[row.name, row.subtitle].filter(Boolean).join(', ')}
                  onClick={() => {
                    picked.current = row;
                    close();
                  }}>
                  <span className="person-name">{row.name}</span>
                  {row.subtitle && <span className="meta">{row.subtitle}</span>}
                </button>
              </li>
            ))}
          </ul>
        )}
        {matches.length > rows.length && <p className="note">{copy.people.pickerMore(matches.length - rows.length)}</p>}
        <div className="actions">
          <button type="button" onClick={close}>
            {copy.people.cancel}
          </button>
        </div>
      </div>
    </Modal>
  );
}

/** The app's "Merge these identities?": its two names, the transitive union, and Merge and Cancel. */
function MergeQuestion({
  target,
  current,
  onClose,
}: {
  target: PersonRow;
  current: { name: string; authorityId?: number | null };
  onClose: (confirmed: boolean) => void;
}) {
  const headingId = useId();
  const messageId = useId();
  const cancel = useRef<HTMLButtonElement>(null);
  const body = useRef<HTMLDivElement>(null);
  const confirmed = useRef(false);

  function close() {
    body.current?.closest('dialog')?.close();
  }

  return (
    <Modal className="confirm" role="alertdialog" labelledBy={headingId} describedBy={messageId} initial={cancel}
      onCancel={close} onClose={() => onClose(confirmed.current)}>
      <div ref={body}>
        <h2 id={headingId} tabIndex={-1}>
          {copy.people.mergeConfirmTitle}
        </h2>
        <p id={messageId} className="pre-line">
          {mergeQuestion(target, current)}
        </p>
        <div className="actions">
          <button ref={cancel} type="button" onClick={close}>
            {copy.people.cancel}
          </button>
          <button type="button" className="destructive" onClick={() => {
            confirmed.current = true;
            close();
          }}>
            {copy.people.mergeConfirmAction}
          </button>
        </div>
      </div>
    </Modal>
  );
}
