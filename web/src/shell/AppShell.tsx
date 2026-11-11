// The frame around every screen: a skip link, the header with navigation, the project picker (PLAN's
// S17f) and appearance, the "Working on:" line over Browse and Search, the readiness banner, the
// screen, and the footer. Behind a proxy that signs people in (PLAN's S14e), or signed in with an
// account of the server's own (S20b), the header names the user and the footer says that the
// instance's operator can read what it keeps for them, as SPEC's Privacy asks; with an account, the
// header has Sign Out, and until someone signs in the screen is the sign-in page, whatever the address.
// The header's links are grouped by area, under a line each, in the order of the app's tabs (PLAN's
// S20a): a new link goes beside its area's kin, never at the end.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Link, Outlet, useRouter } from '@tanstack/react-router';
import { createContext, type MouseEvent, useContext, useEffect, useRef, useState } from 'react';
import { isSignedOut, sessionQuery, signedOut, signOut } from '../api/auth';
import { readinessQuery } from '../api/endpoints';
import { meQuery } from '../api/userData';
import { copy } from '../copy';
import { type Appearance, useAppearance, useResolvedScheme } from '../settings/preferences';
import { requestHeadingFocus } from './headingFocus';
import { ProjectPicker, WorkingOn } from './ProjectPicker';
import { SignInScreen } from './SignInScreen';

const SchemeContext = createContext<'light' | 'dark'>('light');

/** The scheme the app shows, for the reader's page to match. */
export const useScheme = () => useContext(SchemeContext);

export function AppShell() {
  const [appearance, setAppearance] = useAppearance();
  const scheme = useResolvedScheme(appearance);
  const router = useRouter();
  const queryClient = useQueryClient();
  // Whether this browser is signed in (S20b): a server with accounts of its own shows its sign-in page
  // in place of any other until someone signs in, and asks nothing of a user before. One that cannot
  // say, as a server from before accounts, needs no sign-in of the app's.
  const session = useQuery(sessionQuery);
  const signingIn = session.data?.auth === 'local' && !session.data.signedIn;
  const entered = (session.isSuccess && !signingIn) || session.isError;
  // Signed in, through the proxy or with an account: a server with no sign-in has one user, its operator.
  const me = useQuery({ ...meQuery, enabled: entered });
  const signedIn = entered && me.data && me.data.auth !== 'none' ? me.data : undefined;
  const keepsUserData = me.data?.userData === true;
  // From S20d: an admin's link to administration, on a server that keeps user data.
  const isAdmin = keepsUserData && me.data?.roles.includes('admin') === true;
  const [signOutFailed, setSignOutFailed] = useState(false);
  // Signing in or out shows another screen, so focus moves to its heading once it has rendered, as the
  // router's arrivals move it; the field or button that had it is gone by then. A page just loaded
  // starts at its top, the sign-in page too.
  const shown = signingIn ? 'signIn' : entered ? 'app' : 'waiting';
  const lastShown = useRef(shown);
  useEffect(() => {
    if (lastShown.current !== 'waiting' && shown !== 'waiting' && lastShown.current !== shown) requestHeadingFocus();
    lastShown.current = shown;
  }, [shown]);

  // A session that ends while a page is open, expired or ended by an admin, is refused at the next
  // request, and the shell asks again whether it is signed in, which shows the sign-in page.
  useEffect(
    () =>
      queryClient.getQueryCache().subscribe((event) => {
        if (event.type === 'updated' && event.action.type === 'error' && isSignedOut(event.action.error)) {
          void queryClient.invalidateQueries({ queryKey: sessionQuery.queryKey });
        }
      }),
    [queryClient],
  );

  /** Ends the session; the page stays as it is if the server could not be told, since its cookie would. */
  async function leave() {
    setSignOutFailed(false);
    try {
      await signOut();
    } catch {
      setSignOutFailed(true);
      return;
    }
    signedOut(queryClient);
  }

  // A new screen takes focus at its heading, so a screen reader announces where it arrived. The
  // router says when the new screen has rendered; a new search on the same screen keeps its focus,
  // and a page just loaded starts at its top, where Skip to content is the first stop.
  useEffect(
    () =>
      router.subscribe('onRendered', (event) => {
        if (event.pathChanged && event.fromLocation) requestHeadingFocus();
      }),
    [router],
  );

  return (
    <SchemeContext.Provider value={scheme}>
      {/* Against the page's <base>, #main names the app's first page, so the link moves focus itself. */}
      <a className="skip-link" href="#main" onClick={skipToMain}>
        {copy.app.skipToContent}
      </a>
      {/* Named, as its footer is, since a collection's preview frames the kit's page, whose own header and
          footer are a banner and a page's footer too, and two of a kind need names to be told apart (S18e). */}
      <header className="app-header" aria-label={copy.app.name}>
        <Link to="/search" className="brand">
          {copy.app.name}
        </Link>
        {/* Hidden on the sign-in page, where every link would lead back to it. */}
        <nav aria-label={copy.app.navigation} hidden={!entered}>
          {/* ─── Browse and search ─────────────────────────────────────── */}
          <Link to="/browse" activeProps={{ 'aria-current': 'page' }}>
            {copy.app.browse}
          </Link>
          <Link to="/search" activeProps={{ 'aria-current': 'page' }}>
            {copy.app.search}
          </Link>
          {/* ─── Research ──────────────────────────────────────────────── */}
          {/* Between Search and Settings, as the app's tabs order them. */}
          <Link to="/research" activeProps={{ 'aria-current': 'page' }}>
            {copy.app.research}
          </Link>
          {/* ─── Collections ───────────────────────────────────────────── */}
          {/* From S18d, the app's Collections tab, on a server that keeps user data. */}
          {keepsUserData && (
            <Link to="/collections" activeProps={{ 'aria-current': 'page' }}>
              {copy.app.collections}
            </Link>
          )}
          {/* ─── Tools ─────────────────────────────────────────────────── */}
          {/* ─── Settings ──────────────────────────────────────────────── */}
          <Link to="/settings" activeProps={{ 'aria-current': 'page' }}>
            {copy.app.settings}
          </Link>
          {/* ─── Admin ─────────────────────────────────────────────────── */}
          {isAdmin && (
            <Link to="/admin" activeProps={{ 'aria-current': 'page' }} activeOptions={{ exact: false }}>
              {copy.admin.link}
            </Link>
          )}
        </nav>
        {entered && <ProjectPicker />}
        <label className="appearance">
          {copy.appearance.label}{' '}
          <select value={appearance} onChange={(event) => setAppearance(event.target.value as Appearance)}>
            <option value="system">{copy.appearance.system}</option>
            <option value="light">{copy.appearance.light}</option>
            <option value="dark">{copy.appearance.dark}</option>
          </select>
        </label>
        {signedIn && <p className="signed-in">{copy.app.signedInAs(signedIn.displayName)}</p>}
        {signedIn?.auth === 'local' && (
          <button type="button" className="sign-out" onClick={() => void leave()}>
            {copy.app.signOut}
          </button>
        )}
        {signOutFailed && (
          <p className="error" role="alert">
            {copy.app.signOutFailed}
          </p>
        )}
      </header>
      {entered && <WorkingOn />}
      <ReadinessBanner />
      <main id="main" tabIndex={-1}>
        {signingIn ? <SignInScreen /> : entered ? <Outlet /> : null}
      </main>
      <footer className="app-footer" aria-label={copy.app.footerLabel}>
        <p>{copy.app.footer}</p>
        {(signedIn || signingIn) && <p>{copy.app.operatorReads}</p>}
      </footer>
    </SchemeContext.Provider>
  );
}

function skipToMain(event: MouseEvent<HTMLAnchorElement>) {
  event.preventDefault();
  document.getElementById('main')?.focus();
}

/** While no index is served, says which step the server is at; the reader works meanwhile. */
function ReadinessBanner() {
  const readiness = useQuery(readinessQuery);
  const queryClient = useQueryClient();
  const ready = readiness.data?.ready;
  const wasReady = useRef(ready);

  // When an index becomes ready, what was asked before it is asked again: searches and their
  // readings, citations and Citation Lookup's answers, documents, and what Browse shows of what the
  // server indexes.
  useEffect(() => {
    if (ready && wasReady.current === false) {
      for (const key of ['search', 'facets', 'inspect', 'timeline', 'concordance', 'citation', 'citationLookup', 'citationBatch', 'document', 'volumes', 'volume', 'section', 'readingOrder']) {
        void queryClient.invalidateQueries({ queryKey: [key] });
      }
    }
    wasReady.current = ready;
  }, [ready, queryClient]);

  if (!readiness.data || readiness.data.ready) return null;
  return (
    <p className="banner" role="status">
      {copy.readiness.notReady} {readiness.data.detail}
    </p>
  );
}
