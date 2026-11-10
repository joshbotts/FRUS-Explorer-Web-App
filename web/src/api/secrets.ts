// The keys the server keeps for the outside services it calls (PLAN's S20c), under /api/v1/me/secrets:
// a user's NARA Catalog key and Zotero key, as the Mac keeps them in the Keychain. The server takes a
// key and says from then on only that it is set, and since when: no answer gives one back, and this
// file never keeps one past the request that sends it. The instance's NARA key, an admin's, is under
// /api/v1/admin/secrets; this list names it when it is set, since it serves a user who has none.
import { queryOptions, type QueryClient } from '@tanstack/react-query';
import { getJSON } from './client';
import { change } from './userData';

/** The keys a user keeps, by the names the API gives them. */
export type SecretName = 'nara' | 'zotero';

/** One key a user may keep: whether it is set, and since when. Never the key. */
export interface SecretStatus {
  name: SecretName;
  set: boolean;
  /** When it was last set, as the store writes dates; absent while it is not. */
  updatedAt?: string;
}

/** `GET /api/v1/me/secrets`. */
export interface SecretList {
  secrets: SecretStatus[];
  /** The instance's keys that are set, by name, which serve the user while they have none of their own. */
  instance?: SecretName[];
}

const secretsPath = '/api/v1/me/secrets';

export const secretsQuery = queryOptions({
  queryKey: ['secrets'],
  queryFn: ({ signal }) => getJSON<SecretList>(secretsPath, undefined, signal),
  staleTime: 0,
  retry: false,
});

/**
 * Keeps `value` as the user's key `name`, in place of any they had; the answer names it as set. Returns
 * once the list of keys has been read again.
 */
export async function setSecret(client: QueryClient, name: SecretName, value: string): Promise<SecretStatus | null> {
  const status = await change<SecretStatus>(client, 'PUT', `${secretsPath}/${name}`, { value });
  await client.invalidateQueries({ queryKey: ['secrets'] });
  return status;
}

/** Clears the user's key `name`, and returns once the list of keys has been read again. */
export async function removeSecret(client: QueryClient, name: SecretName): Promise<void> {
  await change(client, 'DELETE', `${secretsPath}/${name}`);
  await client.invalidateQueries({ queryKey: ['secrets'] });
}
