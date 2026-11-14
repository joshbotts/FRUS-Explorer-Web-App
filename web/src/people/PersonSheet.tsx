// A person's sheet (PLAN's S21g), the app's `PersonIndexDetailSheet`, in its order: the name; the volumes' description
// under its source's chip; the lifespan line, the kit's (`PersonLifespan`), and the register's role, under the
// register's chip; the reconciled mark; Mentions and Active; Subjects, the kit's ranking of the subjects of the volumes
// the person is mentioned in, each a chip that opens its pivot, the volumes covering it (SubjectVolumesSheet.tsx); Find
// all mentions, the VIAF and Wikidata links; Career, the register's posts, each its title, dates and note, over the
// register's sentence and chip (S21g's follow-up); and for a curator the app's corrections: Merge with another
// person…, its picker (`PersonMergePickerSheet`) and its question; Possibly the Same Person, each with Merge; and the
// identity's records, each with Separate. A correction ends the sheet, as the app's dismisses it, once the server has
// answered, and the screen says what it did.
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
  type PersonSubject,
  separatePerson,
} from '../api/people';
import { copy } from '../copy';
import { closeAtOnce, Modal } from '../shell/Modal';
import { ProvenanceChip } from '../sources/Chips';
import { mergeQuestion, pickerRows, roleEraLine, subjectChipValue } from './peopleRules';
import { SubjectVolumesSheet } from './SubjectVolumesSheet';

/** What a correction made, or one undone, did, as the screen's line says it. */
export function outcomeLine(done: string, outcome: CorrectionOutcome, undone = false): string {
  if (outcome.state === 'nextExport') return `${done}. ${undone ? copy.people.undoneForExport : copy.people.keptForExport}`;
  if (outcome.state === 'waiting') return `${done}. ${undone ? copy.people.undoneForJob : copy.people.keptForJob}`;
  return done;
}

export function PersonSheet({
  row,
  list,
  curator,
  onClose,
  onSaid,
}: {
  row: PersonRow;
  list: PeopleList;
  curator: boolean;
  /** Called once it has closed, with what a correction did, or nothing. */
  onClose: (said?: string) => void;
  /**
   * Told what a correction did when the sheet had closed before the server answered, as a second Escape closes a
   * dialog in Chrome whatever its page says; otherwise `onClose` is told, once the page behind is no longer inert.
   */
  onSaid?: (said: string) => void;
}) {
  const client = useQueryClient();
  const sheet = useQuery(personQuery(row.rollupId));
  const headingId = useId();
  const body = useRef<HTMLDivElement>(null);
  const mergeButton = useRef<HTMLButtonElement>(null);
  const [picking, setPicking] = useState(false);
  // The chip whose pivot is open, and the chip itself, which focus goes back to when the pivot closes.
  const [pivot, setPivot] = useState<PersonSubject | null>(null);
  const chip = useRef<HTMLButtonElement | null>(null);
  const [confirming, setConfirming] = useState<PersonRow | null>(null);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const said = useRef<string | undefined>(undefined);
  const closed = useRef(false);
  const data = sheet.data;

  function close() {
    body.current?.closest('dialog')?.close();
  }

  /** What a correction did: said as the sheet closes, or at once where it has closed already. */
  function finish(line: string) {
    said.current = line;
    if (closed.current) onSaid?.(line);
    else closeAtOnce(close);
  }

  /** The people rebuilt since the list was read: the sheet closes, saying so, and the list is read again. */
  function changed() {
    finish(copy.people.peopleChanged);
    void client.invalidateQueries({ queryKey: ['people'] });
  }

  /**
   * A correction's tail, the app's `applyCorrection`: say it is under way, send it, and close with what it did. It
   * is checked against the list the row and the picker's ids came from, which the sheet's own must match.
   */
  async function correct(done: string, send: (version: string) => Promise<CorrectionOutcome>) {
    if (busy || !data) return;
    if (data.version !== list.version) {
      changed();
      return;
    }
    setBusy(true);
    setFailure(null);
    try {
      const outcome = await send(list.version);
      finish(outcomeLine(done, outcome));
    } catch (error) {
      if (error instanceof ApiError && error.code === 'PEOPLE_CHANGED') {
        changed();
        return;
      }
      setBusy(false);
      setFailure(errorMessage(error));
    }
  }

  const merge = (other: { rollupId: number; name: string }) =>
    correct(copy.people.mergeDone(other.name, row.name), (version) => mergePeople(client, row.rollupId, other.rollupId, version));

  return (
    <Modal className="person-sheet" labelledBy={headingId} onCancel={() => !busy && close()}
      onClose={() => {
        closed.current = true;
        onClose(said.current);
      }}>
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
            onPivot={(subject, opener) => {
              chip.current = opener;
              setPivot(subject);
            }}
            onPick={() => setPicking(true)}
            onMerge={(candidate) => void merge(candidate)}
            onSeparate={(record) =>
              void correct(copy.people.separateDone(record.name), (version) => separatePerson(client, row.rollupId, record, version))
            }
          />
        )}
        {/* Mounted while the sheet is, so that its words are announced when they change. */}
        <p role="status">{busy ? copy.people.inProgress : ''}</p>
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
      {pivot && (
        <SubjectVolumesSheet
          subject={pivot}
          onClose={() => {
            setPivot(null);
            // Back to the chip, or to the sheet's heading where the sheet was read again meanwhile and the chip is gone.
            requestAnimationFrame(() => {
              const back = chip.current;
              (back?.isConnected ? back : body.current?.querySelector<HTMLElement>('h2'))?.focus();
            });
          }}
        />
      )}
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
  onPivot,
  onPick,
  onMerge,
  onSeparate,
}: {
  data: Sheet;
  curator: boolean;
  busy: boolean;
  mergeButton: { current: HTMLButtonElement | null };
  onPivot: (subject: PersonSubject, opener: HTMLButtonElement) => void;
  onPick: () => void;
  onMerge: (candidate: { rollupId: number; name: string }) => void;
  onSeparate: (record: { volumeId: string; ref: string; name: string }) => void;
}) {
  const mergeFooterId = useId();
  const candidatesId = useId();
  const recordsId = useId();
  const subjectsId = useId();
  const careerId = useId();
  return (
    <>
      <div className="person-head">
        {/* Each claim under its source's chip, the volumes' words apart from the register's, as the app badges them. */}
        {data.description && (
          <div className="person-claim">
            <p className="person-description">{data.description}</p>
            <ProvenanceChip source="frusText" />
          </div>
        )}
        {(data.lifespan || data.registerRole) && (
          <div className="person-claim">
            {data.lifespan && <p className="meta person-lifespan">{data.lifespan}</p>}
            {data.registerRole && <p className="meta">{data.registerRole}</p>}
            <ProvenanceChip source="ohPeopleRegister" />
          </div>
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
      {data.subjects.length > 0 && (
        <section className="person-subjects" aria-labelledby={subjectsId}>
          <h3 id={subjectsId}>{copy.people.subjectsHeader}</h3>
          <ul className="chips">
            {data.subjects.map((subject, index) => (
              <li key={subject.ref}>
                <button type="button" className="chip" title={copy.people.subjectChipHelp}
                  aria-describedby={`${subjectsId}-value-${index} ${subjectsId}-hint`}
                  onClick={(event) => onPivot(subject, event.currentTarget)}>
                  {subject.name}
                </button>
                <span id={`${subjectsId}-value-${index}`} hidden>
                  {subjectChipValue(subject)}
                </span>
              </li>
            ))}
          </ul>
          <span id={`${subjectsId}-hint`} hidden>
            {copy.people.subjectChipHint}
          </span>
          <p className="note">{copy.people.subjectsNote}</p>
        </section>
      )}
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
      {data.career.length > 0 && (
        <section className="person-career" aria-labelledby={careerId}>
          <h3 id={careerId}>{copy.people.careerHeader}</h3>
          <ul>
            {data.career.map((post, index) => (
              // One stop each, its lines read in turn, as the app combines a post's. Known by its place: the register
              // can give one career two posts alike but for when they end.
              <li key={index}>
                <span className="post-title">{post.title}</span>
                {post.dates && (
                  <>
                    {' '}
                    <span className="meta post-dates">{post.dates}</span>
                  </>
                )}
                {post.note && (
                  <>
                    {' '}
                    <span className="note post-note">{post.note}</span>
                  </>
                )}
              </li>
            ))}
          </ul>
          <div className="person-claim note">
            <p>{copy.people.careerSource}</p>
            <ProvenanceChip source="ohPeopleRegister" />
          </div>
        </section>
      )}
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
                  aria-label={[row.name, roleEraLine(row)].filter(Boolean).join(', ')}
                  onClick={() => {
                    picked.current = row;
                    close();
                  }}>
                  <span className="person-name">{row.name}</span>
                  {roleEraLine(row) && <span className="meta">{roleEraLine(row)}</span>}
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
