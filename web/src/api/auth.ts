// Signing in and out of a server with accounts of its own (PLAN's S20b), FRUS_AUTH=local: whether this
// browser is signed in, which the shell asks before anything else; the sign-in, whose answer is the
// user as GET /api/v1/me gives them; and the sign-out. The session is a cookie no script can read, so
// the server alone says whether there is one. Signing in or out forgets everything the browser holds
// of a user, its queries and what the tab keeps, so that no one sees the last person's research.
import { queryOptions, type QueryClient } from '@tanstack/react-query';
import { servedPath } from './base';
import { ApiError, getJSON } from './client';
import type { AuthSession, Me } from './types';
import { meQuery } from './userData';

export const sessionQuery = queryOptions({
  queryKey: ['authSession'],
  queryFn: ({ signal }) => getJSON<AuthSession>('/api/v1/auth/session', undefined, signal),
  staleTime: Infinity,
  retry: false,
});

/** Signs in with `name` and `password`; gives the user, or throws the server's refusal as an `ApiError`. */
export async function signIn(name: string, password: string): Promise<Me> {
  const response = await fetch(servedPath('/api/v1/auth/sign-in'), {
    method: 'POST',
    headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
    body: JSON.stringify({ name, password }),
  });
  if (!response.ok) throw await ApiError.from(response);
  return (await response.json()) as Me;
}

/** Ends this browser's session; the server clears its cookie whether or not it named one. */
export async function signOut(): Promise<void> {
  const response = await fetch(servedPath('/api/v1/auth/sign-out'), { method: 'POST', headers: { Accept: 'application/json' } });
  if (!response.ok) throw await ApiError.from(response);
}

/**
 * Forgets what the browser holds of a user: every query but the session, the server's readiness and
 * those `keeping` names, and what the tab keeps for its session, Citation Lookup's form and the search
 * history's last rows.
 */
function forgetTheUser(client: QueryClient, keeping: string[] = []) {
  const kept = ['authSession', 'readyz', ...keeping];
  client.removeQueries({ predicate: (query) => !kept.includes(String(query.queryKey[0])) });
  try {
    window.sessionStorage.clear();
  } catch {
    // A browser that keeps nothing for the tab has nothing to forget.
  }
}

/** After a sign-in: the user, as the server answered, and the session; nothing of anyone before. */
export function signedIn(client: QueryClient, me: Me) {
  forgetTheUser(client, ['me']);
  client.setQueryData(meQuery.queryKey, me);
  client.setQueryData(sessionQuery.queryKey, { auth: me.auth, signedIn: true });
}

/** After a sign-out: the sign-in page, and nothing of the user who left. */
export function signedOut(client: QueryClient) {
  client.setQueryData(sessionQuery.queryKey, { auth: 'local', signedIn: false });
  forgetTheUser(client);
}

/** Whether `error` says the request carried no session that is current, as when one expires. */
export function isSignedOut(error: unknown): boolean {
  return error instanceof ApiError && error.code === 'NOT_SIGNED_IN';
}
