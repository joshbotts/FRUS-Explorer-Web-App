// A section of a volume (SPEC, Browse): the row of the text it prints outside the documents and
// sections it holds, first, as the app's Browse lists it; its subsections; and its documents in the
// volume's order, each named by the kit's rule for lists from the index's entry, as the reader's
// heading is, or, for one the index lacks, by its number from the TEI.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { getRouteApi, Link } from '@tanstack/react-router';
import { useId } from 'react';
import { ApiError } from '../api/client';
import { sectionQuery, volumeQuery } from '../api/endpoints';
import type { Section, SectionDocument } from '../api/types';
import { copy } from '../copy';
import { Badge } from '../shell/Badge';
import { useHeadingReady } from '../shell/headingFocus';
import { plainTitle, useDocumentTitle } from '../shell/useDocumentTitle';
import { Breadcrumb } from './Breadcrumb';
import { SectionTree } from './SectionTree';

const route = getRouteApi('/browse/$volumeId/$sectionId');

function findSection(sections: Section[], sectionId: string): Section | undefined {
  for (const section of sections) {
    if (section.sectionId === sectionId) return section;
    const found = findSection(section.subsections, sectionId);
    if (found) return found;
  }
  return undefined;
}

export function SectionScreen() {
  const { volumeId, sectionId } = route.useParams();
  const page = useQuery(sectionQuery(volumeId, sectionId));
  const queryClient = useQueryClient();
  const data = page.data;
  // The volume's page, when it has been read, already names the section.
  const structure = queryClient.getQueryData(volumeQuery(volumeId).queryKey)?.structure;
  const known = structure ? findSection(structure, sectionId) : undefined;
  const title = data?.section.title ?? known?.title ?? sectionId;
  useDocumentTitle(title);
  useHeadingReady(!page.isPending || known !== undefined);

  return (
    <section className="screen browse-section">
      <Breadcrumb
        crumbs={[
          { label: copy.browse.title },
          { label: data?.volumeTitle ?? volumeId, volumeId },
          ...(data?.path ?? []).map((ancestor) => ({ label: ancestor.title, volumeId, sectionId: ancestor.sectionId })),
        ]}
        current={title}
      />
      <h1 tabIndex={-1} data-loading={page.isPending && !known ? 'true' : undefined}>
        {plainTitle(title)}
      </h1>
      {page.isError && (
        <p className="error" role="alert">
          {page.error instanceof ApiError ? page.error.message : String(page.error)}
        </p>
      )}
      {page.isPending && <p role="status">{copy.browse.loading}</p>}
      {data && (
        <>
          {data.section.documentCount > 0 && (
            <p className="count">{copy.browse.documentCoverage(data.section.indexedDocumentCount, data.section.documentCount)}</p>
          )}
          {data.ownText && <OwnText volumeId={volumeId} title={data.section.title} row={data.ownText} />}
          {data.section.subsections.length > 0 && (
            <>
              <h2>{copy.browse.sections}</h2>
              <SectionTree volumeId={volumeId} sections={data.section.subsections} />
            </>
          )}
          {data.documents.length > 0 && (
            <>
              <h2>{copy.browse.documents(data.documents.length)}</h2>
              <ol className="document-list">
                {data.documents.map((document) => (
                  <li key={document.documentId}>
                    {document.readable === false ? (
                      <span>{document.displayTitle}</span>
                    ) : (
                      <Link to="/doc/$volumeId/$documentId" params={{ volumeId, documentId: document.documentId }}>
                        {document.displayTitle}
                      </Link>
                    )}
                    {(document.dateline || document.isEditorialNote || !document.inIndex) && (
                      <p className="meta">
                        {document.dateline}
                        {document.isEditorialNote && <Badge>{copy.browse.editorialNote}</Badge>}
                        {!document.inIndex && <Badge>{copy.browse.notIndexedBadge}</Badge>}
                      </p>
                    )}
                  </li>
                ))}
              </ol>
            </>
          )}
        </>
      )}
    </section>
  );
}

/**
 * The row the index holds for the text a section prints outside the documents and sections it holds,
 * such as a meeting's list of those present: first in the section, above both, as the app's Browse
 * lists it, named Read and the section's title over the app's sentence, and opening the row in the
 * reader. One the reader cannot open is named, not linked.
 */
function OwnText({ volumeId, title, row }: { volumeId: string; title: string; row: SectionDocument }) {
  const note = useId();
  const label = copy.browse.readSection(plainTitle(title));
  return (
    <div className="own-text">
      <p>
        {row.readable === false ? (
          <span aria-describedby={note}>{label}</span>
        ) : (
          <Link to="/doc/$volumeId/$documentId" params={{ volumeId, documentId: row.documentId }} aria-describedby={note}>
            {label}
          </Link>
        )}
      </p>
      <p className="note" id={note}>
        {copy.browse.ownTextNote}
      </p>
    </div>
  );
}
