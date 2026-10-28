// Browse's axes (S17e): All Volumes, and on a server that keeps user data the user's Working Corpora and
// My Scopes, as the Mac's corpus browser lists them among its axes. The others the Mac has, the
// arrangements of All Volumes, the clusters and Archives, wait for their rows.
import { useQuery } from '@tanstack/react-query';
import { Link } from '@tanstack/react-router';
import { meQuery } from '../api/userData';
import { copy } from '../copy';

export function BrowseAxes({ current }: { current: 'volumes' | 'corpora' | 'scopes' }) {
  const me = useQuery(meQuery);
  if (me.data?.userData !== true) return null;
  const axes = [
    { axis: 'volumes', to: '/browse', label: copy.axes.volumes },
    { axis: 'corpora', to: '/browse/corpora', label: copy.axes.corpora },
    { axis: 'scopes', to: '/browse/scopes', label: copy.axes.scopes },
  ] as const;
  return (
    <nav className="browse-axes" aria-label={copy.axes.label}>
      <ul>
        {axes.map((item) => (
          <li key={item.axis}>
            <Link to={item.to} aria-current={item.axis === current ? 'page' : undefined}>
              {item.label}
            </Link>
          </li>
        ))}
      </ul>
    </nav>
  );
}
