// Browse's catalogue (SPEC, Browse): every volume of the published catalogue, in its order, narrowed
// by title or volume number, by subseries, and to what this server indexes. The app's arrangements
// (Title, Published, Era, Length) are its own code, and wait for an upstream move into the kit.
import { useQuery } from '@tanstack/react-query';
import { getRouteApi, Link } from '@tanstack/react-router';
import { useId, useState } from 'react';
import { ApiError } from '../api/client';
import { volumesQuery } from '../api/endpoints';
import type { Volume } from '../api/types';
import { copy } from '../copy';
import { Badge } from '../shell/Badge';
import { useDocumentTitle } from '../shell/useDocumentTitle';

const route = getRouteApi('/browse');

export interface CatalogueSearch {
  /** The filter's text, as typed. */
  q?: string;
  subseries?: string;
  /** Only the volumes the index holds. */
  indexed?: true;
}

function single(value: unknown): string | undefined {
  if (typeof value === 'string') return value;
  if (Array.isArray(value) && typeof value[0] === 'string') return value[0];
  return undefined;
}

/** Every field is returned, undefined when dropped, so the router's raw value cannot stand in for it. */
export function validateCatalogueSearch(raw: Record<string, unknown>): CatalogueSearch {
  const q = single(raw.q);
  const subseries = single(raw.subseries);
  return {
    q: q ? q : undefined,
    subseries: subseries ? subseries : undefined,
    indexed: single(raw.indexed) === 'true' || raw.indexed === true ? true : undefined,
  };
}

/** Whether a volume's title or id holds the filter's text, ignoring case, as the app's filter matches. */
export function matchesFilter(volume: Pick<Volume, 'title' | 'volumeId'>, text: string): boolean {
  const needle = text.trim().toLocaleLowerCase('en-US');
  if (!needle) return true;
  return volume.title.toLocaleLowerCase('en-US').includes(needle) || volume.volumeId.toLocaleLowerCase('en-US').includes(needle);
}

export function CatalogueScreen() {
  const search = route.useSearch();
  const navigate = route.useNavigate();
  const volumes = useQuery(volumesQuery);
  useDocumentTitle(copy.browse.title);
  const filterId = useId();

  // The filter's text is kept here as it is typed, and copied into the URL in place of the last
  // copy, so a narrowed catalogue survives going to a volume and back, and can be bookmarked,
  // without a history entry per keystroke. The URL catches up a moment after each keystroke, so the
  // values written and not yet seen are remembered: when the URL shows one of them, it is the
  // screen's own; when it shows anything else, as after the header's Browse link or Back, the box
  // takes it.
  const [text, setText] = useState(search.q ?? '');
  const [seen, setSeen] = useState(search.q);
  const [pending, setPending] = useState<(string | undefined)[]>([]);
  if (search.q !== seen) {
    setSeen(search.q);
    const own = pending.indexOf(search.q);
    if (own >= 0) {
      setPending(pending.slice(own + 1));
    } else {
      setPending([]);
      setText(search.q ?? '');
    }
  }

  function update(changes: Partial<CatalogueSearch>) {
    void navigate({ search: (previous: CatalogueSearch) => ({ ...previous, ...changes }), replace: true });
  }

  const items = volumes.data?.items ?? [];
  const subseries = [...new Set(items.map((volume) => volume.subseries))];
  const shown = items.filter(
    (volume) =>
      matchesFilter(volume, text) &&
      (search.subseries === undefined || volume.subseries === search.subseries) &&
      (!search.indexed || volume.indexed),
  );

  return (
    <section className="screen browse">
      <h1 tabIndex={-1}>{copy.browse.title}</h1>
      <div className="catalogue-filters" role="search">
        <label htmlFor={filterId}>{copy.browse.filter}</label>
        <input
          id={filterId}
          type="search"
          value={text}
          onChange={(event) => {
            const q = event.target.value || undefined;
            setText(event.target.value);
            if (q !== search.q) setPending((written) => [...written, q]);
            update({ q });
          }}
          spellCheck={false}
          autoCapitalize="off"
          autoComplete="off"
        />
        <label>
          {copy.browse.subseries}{' '}
          <select
            value={search.subseries ?? ''}
            onChange={(event) => update({ subseries: event.target.value || undefined })}
          >
            <option value="">{copy.browse.allSubseries}</option>
            {subseries.map((name) => (
              <option key={name} value={name}>
                {name}
              </option>
            ))}
          </select>
        </label>
        <label>
          <input
            type="checkbox"
            checked={search.indexed === true}
            onChange={(event) => update({ indexed: event.target.checked ? true : undefined })}
          />{' '}
          {copy.browse.indexedOnly}
        </label>
      </div>
      {volumes.isError ? (
        <p className="error" role="alert">
          {volumes.error instanceof ApiError ? volumes.error.message : String(volumes.error)}
        </p>
      ) : (
        <>
          <p className="count" role="status">
            {volumes.data ? copy.browse.showing(shown.length, volumes.data.total) : copy.browse.loading}
          </p>
          {volumes.data && (
            <p className="note">
              {copy.browse.coverage(volumes.data.coverage.indexedVolumes, items.filter((volume) => volume.teiAvailable).length)}
            </p>
          )}
          {volumes.data && shown.length === 0 ? (
            <div className="empty">
              <h2>{copy.browse.noMatches}</h2>
              <p>{copy.browse.noMatchesDetail}</p>
            </div>
          ) : (
            <ul className="volume-list" aria-label={copy.browse.title}>
              {shown.map((volume) => (
                <li key={volume.volumeId} className="volume-row">
                  <Link to="/browse/$volumeId" params={{ volumeId: volume.volumeId }}>
                    {volume.title}
                  </Link>
                  <p className="meta">
                    {volume.volumeId}
                    {volume.publicationDate && <> · {volume.publicationDate}</>}
                    {volume.status === 'partiallyPublished' && <Badge>{copy.browse.partial}</Badge>}
                    {volume.status === 'planned' && <Badge>{copy.browse.planned}</Badge>}
                    {volume.indexed && <Badge>{copy.browse.indexed}</Badge>}
                    {volume.teiAvailable && <Badge>{copy.browse.teiHere}</Badge>}
                  </p>
                </li>
              ))}
            </ul>
          )}
        </>
      )}
    </section>
  );
}
