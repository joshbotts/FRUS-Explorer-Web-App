// A volume's sections as the kit's structure gives them, nested: a section with documents, or with a
// row of its own text, opens its own page, as a Sources section does, for its outline (S22d); a section
// the app's Read opens in the reader opens there; and the rest are named only, the list of persons
// among them, though the reader opens those where Previous and Next or a table of contents' link reach
// them.
import { Link } from '@tanstack/react-router';
import type { Section } from '../api/types';
import { copy } from '../copy';
import { plainTitle } from '../shell/useDocumentTitle';

export function SectionTree({ volumeId, sections }: { volumeId: string; sections: Section[] }) {
  return (
    <ul className="section-tree">
      {sections.map((section) => (
        <li key={section.sectionId}>
          <SectionEntry volumeId={volumeId} section={section} />
          {section.subsections.length > 0 && <SectionTree volumeId={volumeId} sections={section.subsections} />}
        </li>
      ))}
    </ul>
  );
}

function SectionEntry({ volumeId, section }: { volumeId: string; section: Section }) {
  const title = plainTitle(section.title);
  if (section.documentCount > 0 || section.hasOwnText || section.divType === 'sources') {
    return (
      <>
        <Link to="/browse/$volumeId/$sectionId" params={{ volumeId, sectionId: section.sectionId }}>
          {title}
        </Link>
        {section.documentCount > 0 && (
          <>
            {' '}
            <span className="meta">{copy.browse.documentCoverage(section.indexedDocumentCount, section.documentCount)}</span>
          </>
        )}
      </>
    );
  }
  if (section.readable) {
    return (
      <Link to="/doc/$volumeId/$documentId" params={{ volumeId, documentId: section.sectionId }}>
        {title}
      </Link>
    );
  }
  return <span>{title}</span>;
}
