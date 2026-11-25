// Search by meaning (S27d): the Mac's Search by picker, Keywords or Meaning, offered where the server searches by meaning;
// the Meaning mode's strip, in place of the Query Inspector's, which says what a search by meaning is and every count its
// run owes the reader, in the kit's sentences; its empty state; and the hits in volumes this server does not serve,
// listed apart under the rows as the app lists those it has not downloaded, each opening its volume's page in Browse,
// with no download to offer, since the model and the vectors are in the image.
import { Link } from '@tanstack/react-router';
import { useId } from 'react';
import type { MeaningBeyondHit, MeaningRunSummary } from '../api/meaning';
import { copy } from '../copy';
import { plainTitle } from '../shell/useDocumentTitle';

/** The engines a search runs through, in the order of the Mac's picker (`SearchMode`). */
export const searchModes = ['keywords', 'meaning'] as const;
export type SearchMode = (typeof searchModes)[number];

/**
 * Search by, as the Mac's window offers it beside its field: Keywords or Meaning, a group of two radio buttons, the
 * engine the next search runs through, which a change runs the standing search through at once, as the Mac's does.
 */
export function SearchBy({ mode, onChange }: { mode: SearchMode; onChange: (mode: SearchMode) => void }) {
  const name = useId();
  return (
    <fieldset className="segmented search-by">
      <legend>{copy.meaningSearch.searchBy}</legend>
      {searchModes.map((choice) => (
        <label key={choice}>
          <input type="radio" name={name} value={choice} checked={mode === choice} onChange={() => onChange(choice)} />
          {copy.meaningSearch.modes[choice]}
        </label>
      ))}
    </fieldset>
  );
}

/**
 * The Meaning mode's strip, which replaces the Query Inspector's, as the Mac's does: no expression ran, and the strip
 * says what a search by meaning is, where it ranked, and every count its run owes the reader, the kit's sentences joined.
 */
export function MeaningStrip({ meaning }: { meaning: MeaningRunSummary }) {
  return (
    <section className="meaning-strip" aria-label={copy.meaningSearch.strip}>
      <span className="meaning-glyph" aria-hidden="true">
        ✦
      </span>
      <p>{meaning.strip.join(' ')}</p>
    </section>
  );
}

/**
 * What a search by meaning that listed no row shows, as the app's empty state does: the kit's sentence under "No semantic
 * matches yet", unless it found matches beyond the library, which are no zero, and which the section under it lists.
 */
export function MeaningEmpty({ meaning }: { meaning: MeaningRunSummary }) {
  if (meaning.beyondLibrary.length > 0) return null;
  return (
    <div className="empty meaning-empty">
      <h3>{copy.meaningSearch.emptyTitle}</h3>
      <p>{meaning.emptyStatement}</p>
    </div>
  );
}

/**
 * The hits in volumes this server does not serve, under the rows, never among them, as the app's section follows its list:
 * each the document's id in its volume, titled from the catalogue, opening the volume's page in Browse, the line that says
 * its volume is not on this server, and its chip.
 */
export function MeaningBeyond({ meaning }: { meaning: MeaningRunSummary }) {
  const headingId = useId();
  if (meaning.beyondLibrary.length === 0) return null;
  return (
    <section className="meaning-beyond" aria-labelledby={headingId}>
      <h3 id={headingId}>{meaning.beyondHeader}</h3>
      <ul>
        {meaning.beyondLibrary.map((hit) => (
          <BeyondHit key={`${hit.volumeId}/${hit.documentId}`} hit={hit} />
        ))}
      </ul>
    </section>
  );
}

function BeyondHit({ hit }: { hit: MeaningBeyondHit }) {
  return (
    <li>
      <Link to="/browse/$volumeId" params={{ volumeId: hit.volumeId }}>
        {copy.meaningSearch.beyondDocument(hit.documentId, plainTitle(hit.volumeTitle))}
      </Link>
      <p className="note">{copy.meaningSearch.beyondNotServed}</p>
      <p className="semantic-chip">{hit.chip}</p>
    </li>
  );
}
