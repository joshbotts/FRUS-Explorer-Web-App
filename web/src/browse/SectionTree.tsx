// A volume's sections as the kit's structure gives them, nested: a section with documents opens its
// own page, a prose section the reader can open opens in the reader, and the rest are named only.
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
  if (section.documentCount > 0) {
    return (
      <>
        <Link to="/browse/$volumeId/$sectionId" params={{ volumeId, sectionId: section.sectionId }}>
          {title}
        </Link>{' '}
        <span className="meta">{copy.browse.documentCoverage(section.indexedDocumentCount, section.documentCount)}</span>
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
