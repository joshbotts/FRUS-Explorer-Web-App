// Where a Browse screen sits: All Volumes, the volume, the sections above, and the screen itself.
import { Link } from '@tanstack/react-router';
import { copy } from '../copy';
import { plainTitle } from '../shell/useDocumentTitle';

export interface Crumb {
  label: string;
  volumeId?: string;
  sectionId?: string;
}

/** Each crumb links to its screen: no volume is All Volumes, a volume alone its page, else its section. */
export function Breadcrumb({ crumbs, current }: { crumbs: Crumb[]; current: string }) {
  return (
    <nav className="breadcrumb" aria-label={copy.browse.breadcrumb}>
      <ol>
        {crumbs.map((crumb) => (
          <li key={`${crumb.volumeId ?? ''}/${crumb.sectionId ?? ''}`}>
            {crumb.volumeId === undefined ? (
              <Link to="/browse">{crumb.label}</Link>
            ) : crumb.sectionId === undefined ? (
              <Link to="/browse/$volumeId" params={{ volumeId: crumb.volumeId }}>
                {plainTitle(crumb.label)}
              </Link>
            ) : (
              <Link to="/browse/$volumeId/$sectionId" params={{ volumeId: crumb.volumeId, sectionId: crumb.sectionId }}>
                {plainTitle(crumb.label)}
              </Link>
            )}
          </li>
        ))}
        <li aria-current="page">{plainTitle(current)}</li>
      </ol>
    </nav>
  );
}
