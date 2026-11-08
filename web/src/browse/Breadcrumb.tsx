// Where a Browse screen sits: All Volumes, the volume, the sections above, and the screen itself.
import { Link } from '@tanstack/react-router';
import { copy } from '../copy';
import { plainTitle } from '../shell/useDocumentTitle';

export interface Crumb {
  label: string;
  volumeId?: string;
  sectionId?: string;
  /** One of Browse's other axes (S17e), Working Corpora or My Scopes, in place of All Volumes. */
  axis?: 'corpora' | 'scopes' | 'annotations';
  /** On the Editors’ Annotations axis, a layer's page, with the volume whose page opened it. */
  layer?: string;
  from?: string;
}

/**
 * A crumb is never the page it is on: the router marks a link the current page wherever the path
 * goes on below it, so each crumb is marked only on its own path, which the screen's last item is.
 */
const ownPath = { exact: true, includeSearch: false } as const;

/** Each crumb links to its screen: no volume is All Volumes, or the axis it names, or a layer's page on it, a volume alone its page, else its section. */
export function Breadcrumb({ crumbs, current }: { crumbs: Crumb[]; current: string }) {
  return (
    <nav className="breadcrumb" aria-label={copy.browse.breadcrumb}>
      <ol>
        {crumbs.map((crumb) => (
          <li key={`${crumb.axis ?? ''}/${crumb.layer ?? ''}/${crumb.volumeId ?? ''}/${crumb.sectionId ?? ''}`}>
            {crumb.axis === 'corpora' ? (
              <Link to="/browse/corpora" activeOptions={ownPath}>
                {crumb.label}
              </Link>
            ) : crumb.axis === 'scopes' ? (
              <Link to="/browse/scopes" activeOptions={ownPath}>
                {crumb.label}
              </Link>
            ) : crumb.axis === 'annotations' ? (
              crumb.layer === undefined ? (
                <Link to="/browse/annotations" activeOptions={ownPath}>
                  {crumb.label}
                </Link>
              ) : (
                <Link to="/browse/annotations/$layer" params={{ layer: crumb.layer }} search={{ from: crumb.from }} activeOptions={ownPath}>
                  {crumb.label}
                </Link>
              )
            ) : crumb.volumeId === undefined ? (
              <Link to="/browse" activeOptions={ownPath}>
                {crumb.label}
              </Link>
            ) : crumb.sectionId === undefined ? (
              <Link to="/browse/$volumeId" params={{ volumeId: crumb.volumeId }} activeOptions={ownPath}>
                {plainTitle(crumb.label)}
              </Link>
            ) : (
              <Link to="/browse/$volumeId/$sectionId" params={{ volumeId: crumb.volumeId, sectionId: crumb.sectionId }} activeOptions={ownPath}>
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
