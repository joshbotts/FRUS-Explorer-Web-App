// Browse's axes: All Volumes and, since FRUS-Explorer#1861, Editors’ Annotations, on every server; and on a
// server that keeps user data the user's Working Corpora and My Scopes (S17e), as the Mac's corpus browser
// lists them among its axes, its Browse section before Your sets. The others the Mac has, the arrangements
// of All Volumes, the clusters and Archives, wait for their rows.
import { useQuery } from '@tanstack/react-query';
import { Link } from '@tanstack/react-router';
import { meQuery } from '../api/userData';
import { copy } from '../copy';

export function BrowseAxes({ current }: { current: 'volumes' | 'annotations' | 'corpora' | 'scopes' }) {
  const me = useQuery(meQuery);
  const axes = [
    { axis: 'volumes', to: '/browse', label: copy.axes.volumes },
    { axis: 'annotations', to: '/browse/annotations', label: copy.axes.annotations },
    ...(me.data?.userData === true
      ? ([
          { axis: 'corpora', to: '/browse/corpora', label: copy.axes.corpora },
          { axis: 'scopes', to: '/browse/scopes', label: copy.axes.scopes },
        ] as const)
      : []),
  ] as const;
  return (
    <nav className="browse-axes" aria-label={copy.axes.label}>
      <ul>
        {axes.map((item) => (
          <li key={item.axis}>
            {/* The router marks a link the current page wherever the path goes on below it, which would
                make All Volumes current on every other axis: each is current on its own path alone. */}
            <Link
              to={item.to}
              activeOptions={{ exact: true, includeSearch: false }}
              aria-current={item.axis === current ? 'page' : undefined}
            >
              {item.label}
            </Link>
          </li>
        ))}
      </ul>
    </nav>
  );
}
