// Administration's panes (PLAN's S20d), as Settings' are laid out: Status, Jobs, Users, Backups and the
// instance's Keys, each a page of its own under /admin, for an admin; and the frame every pane is drawn
// in, which says why there is nothing to show to anyone else, or on a server that keeps no user data.
// The panes are grouped by area under a line each, as Settings' are (PLAN's S20a): a later row's pane
// goes beside its area's kin, never at the end, as the library's (S21c) does.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Link } from '@tanstack/react-router';
import { type ReactNode, useEffect } from 'react';
import { ApiError, errorMessage } from '../api/client';
import { meQuery } from '../api/userData';
import { copy } from '../copy';
import { useHeadingReady } from '../shell/headingFocus';
import { useDocumentTitle } from '../shell/useDocumentTitle';

export function AdminPanes() {
  return (
    <nav className="settings-panes" aria-label={copy.admin.panes}>
      <ul>
        {/* ─── The server ────────────────────────────────────────────────── */}
        <li>
          <Link to="/admin/status" activeProps={{ 'aria-current': 'page' }}>
            {copy.admin.status.title}
          </Link>
        </li>
        <li>
          <Link to="/admin/jobs" activeProps={{ 'aria-current': 'page' }}>
            {copy.admin.jobs.title}
          </Link>
        </li>
        {/* ─── The library ───────────────────────────────────────────────── */}
        <li>
          <Link to="/admin/library" activeProps={{ 'aria-current': 'page' }}>
            {copy.admin.library.title}
          </Link>
        </li>
        {/* ─── People ────────────────────────────────────────────────────── */}
        <li>
          <Link to="/admin/users" activeProps={{ 'aria-current': 'page' }}>
            {copy.admin.users.title}
          </Link>
        </li>
        {/* ─── The store ─────────────────────────────────────────────────── */}
        <li>
          <Link to="/admin/backups" activeProps={{ 'aria-current': 'page' }}>
            {copy.admin.backups.title}
          </Link>
        </li>
        <li>
          <Link to="/admin/keys" activeProps={{ 'aria-current': 'page' }}>
            {copy.admin.keys.title}
          </Link>
        </li>
      </ul>
    </nav>
  );
}

/** Whether the browser's user may see administration: an admin, on a server that keeps user data. */
export function useAdmin() {
  const me = useQuery(meQuery);
  const allowed = me.data?.userData === true && me.data.roles.includes('admin');
  return { me, allowed };
}

/**
 * A pane's reading that failed: why, and with `stale`, that what the pane still shows may be out of date.
 * When the user is no longer an admin, or no longer signed in, the app asks again who they are, so that
 * the pane says so, and its reading stops.
 */
export function ReadFailure({ error, stale }: { error: unknown; stale: boolean }) {
  const client = useQueryClient();
  useEffect(() => {
    if (error instanceof ApiError && (error.code === 'ROLE_REQUIRED' || error.code === 'NOT_SIGNED_IN')) {
      void client.invalidateQueries({ queryKey: ['me'] });
    }
  }, [error, client]);
  return (
    <p className="error" role="alert">
      {stale ? copy.admin.stale(errorMessage(error)) : errorMessage(error)}
    </p>
  );
}

/**
 * A pane: its title, as its heading and the page's, and `children` once the browser's user is known to
 * be an admin; until then a line, and after, for anyone else, why there is nothing here.
 */
export function AdminFrame({ title, busy, children }: { title: string; busy?: boolean; children: ReactNode }) {
  const { me, allowed } = useAdmin();
  useDocumentTitle(`${title} · ${copy.admin.title}`);
  useHeadingReady(!me.isPending && !busy);
  let body: ReactNode;
  if (me.isError) {
    body = (
      <p className="error" role="alert">
        {errorMessage(me.error)}
      </p>
    );
  } else if (!me.data) {
    body = <p role="status">{copy.admin.loading}</p>;
  } else if (!me.data.userData) {
    body = <p>{copy.admin.userDataOff}</p>;
  } else if (!allowed) {
    body = <p>{copy.admin.notAdmin}</p>;
  } else {
    body = children;
  }
  return (
    <div className="settings admin">
      <AdminPanes />
      <section className="settings-pane admin-pane">
        <h1 tabIndex={-1} data-loading={me.isPending || busy ? 'true' : undefined}>
          {title}
        </h1>
        {body}
      </section>
    </div>
  );
}
