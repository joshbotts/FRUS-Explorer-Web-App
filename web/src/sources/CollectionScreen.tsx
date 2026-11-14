// An archival collection's record (PLAN's S22d), at /archival-collection?id=…: the app's `CollectionDetailView`,
// its sections in its order, those the kit's public readers give at this pin. The record's name, its FRUS-text
// chip, its repository, record group and lot, and up to six of the forms FRUS also cites it by; In Your Library,
// the documents of this server's index that cite it, with their Archival Neighbors; Cited Across the Series, the
// volumes that cite it, five at first; and its Sub-Series, each with its neighbours when it names a class.
// Related Collections, Cited Over Time, Divided at NARA, Pointed At, Not Printed and the NARA Catalog link read
// kit members still internal at this pin, and follow when an upstream pull request makes them public.
import { useQuery } from '@tanstack/react-query';
import { getRouteApi, Link, useCanGoBack, useRouter } from '@tanstack/react-router';
import { type ReactNode, useId, useState } from 'react';
import { ApiError, errorMessage } from '../api/client';
import { type ArchivalCollection, archivalCollectionQuery } from '../api/sources';
import { copy } from '../copy';
import { useHeadingReady } from '../shell/headingFocus';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import { ProvenanceChip } from './Chips';

const route = getRouteApi('/archival-collection');
const words = copy.archivalCollection;

/** How many aliases the overview shows (`aliasDisplayCap`). */
export const aliasDisplayCap = 6;
/** How many rows a long list shows until Show all (`CollectionRelations.previewRowCap`'s five, as the app's lists). */
export const previewRowCap = 5;

export interface CollectionSearch {
  id: string;
}

export function CollectionScreen() {
  const { id } = route.useSearch();
  const collection = useQuery(archivalCollectionQuery(id));
  const router = useRouter();
  const canGoBack = useCanGoBack();
  useDocumentTitle(collection.data?.name ?? words.title);
  useHeadingReady(!collection.isPending);
  const missing = collection.isError && collection.error instanceof ApiError && collection.error.code === 'COLLECTION_NOT_FOUND';

  return (
    <div className="collection-record">
      {/* The way back, where there is one: the record is opened from several pages. */}
      {canGoBack && (
        <p className="back">
          <button type="button" className="link-button" onClick={() => router.history.back()}>
            <span aria-hidden="true">← </span>
            {words.back}
          </button>
        </p>
      )}
      <h1 tabIndex={-1} data-loading={collection.isPending ? 'true' : undefined}>
        {missing ? words.unavailable : words.title}
      </h1>
      {missing && <p>{words.unavailableDetail}</p>}
      {collection.isError && !missing && (
        <p className="error" role="alert">
          {errorMessage(collection.error)}
        </p>
      )}
      {collection.data && <Record collection={collection.data} />}
    </div>
  );
}

function Section({ title, footer, children }: { title: string; footer?: string; children: ReactNode }) {
  const id = useId();
  return (
    <section className="se-section" aria-labelledby={id}>
      <h2 id={id}>{title}</h2>
      <div className="se-body">{children}</div>
      {footer && <p className="se-footer">{footer}</p>}
    </section>
  );
}

export function Record({ collection }: { collection: ArchivalCollection }) {
  const [allVolumes, setAllVolumes] = useState(false);
  const volumes = allVolumes ? collection.volumes : collection.volumes.slice(0, previewRowCap);
  const rows: [string, string | undefined][] = [
    [words.repository, collection.repository],
    [words.recordGroup, collection.recordGroup && `RG ${collection.recordGroup}`],
    [words.lot, collection.lotFileNorm],
  ];
  return (
    <div className="se-sections">
      <Section title={words.overview}>
        <p className="se-record-title">{collection.name}</p>
        <ProvenanceChip source="frusText" />
        <dl className="se-rows">
          {rows
            .filter((row): row is [string, string] => !!row[1])
            .map(([label, value]) => (
              <div key={label}>
                <dt>{label}</dt>
                <dd>{value}</dd>
              </div>
            ))}
        </dl>
        {collection.aliases.length > 0 && (
          <div className="se-aliases">
            <p className="se-label">{words.aliases}</p>
            <ul>
              {collection.aliases.slice(0, aliasDisplayCap).map((alias) => (
                <li key={alias}>{alias}</li>
              ))}
            </ul>
            {collection.aliases.length > aliasDisplayCap && (
              <p className="se-dates">{words.aliasesMore(collection.aliases.length - aliasDisplayCap)}</p>
            )}
          </div>
        )}
      </Section>
      <Section title={words.local} footer={words.localFooter}>
        {collection.documentCount > 0 ? (
          <>
            <p className="se-text">{words.localCounts(collection.documentCount, collection.volumeCount)}</p>
            <Link className="se-link" to="/archival-neighbors" search={{ collection: collection.id }} title={words.neighboursHint}>
              {words.neighbours}
            </Link>
          </>
        ) : (
          <p className="se-text">{words.localEmpty}</p>
        )}
      </Section>
      <Section title={words.volumes(collection.volumes.length)}>
        <ul className="se-volumes">
          {volumes.map((volume) => (
            <li key={volume.volumeId}>
              <Link to="/browse/$volumeId" params={{ volumeId: volume.volumeId }} title={words.volumeHint}>
                {volume.title ?? volume.volumeId}
              </Link>
              <p className="se-dates">{volume.volumeId}</p>
            </li>
          ))}
        </ul>
        {collection.volumes.length > previewRowCap && (
          <button type="button" className="link-button" aria-expanded={allVolumes} onClick={() => setAllVolumes((shown) => !shown)}>
            {allVolumes ? words.showFewer : words.showAllVolumes(collection.volumes.length)}
          </button>
        )}
      </Section>
      {collection.children.length > 0 && (
        <Section title={words.children}>
          <ul className="se-children">
            {collection.children.map((child) => (
              <li key={child.name}>
                <p className="se-text">{child.name}</p>
                {child.volumeCount > 1 && <p className="se-dates">{words.childVolumes(child.volumeCount)}</p>}
                {child.decimalClass && (
                  <Link
                    className="se-link"
                    to="/archival-neighbors"
                    search={{ decimalClass: child.decimalClass }}
                    title={words.childNeighboursHelp}
                  >
                    {words.childNeighbours}
                  </Link>
                )}
              </li>
            ))}
          </ul>
        </Section>
      )}
    </div>
  );
}
