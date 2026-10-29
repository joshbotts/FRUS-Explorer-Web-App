// Requests to the server's API, all same-origin under the app's base path, and its errors, which are
// RFC 9457 problem details. A change sends JSON with the token the server gave (api/userData.ts).
import { servedPath } from './base';
import type { Problem } from './types';

/** A response the server answered with an error; `code` names it, as the server's problems do. */
export class ApiError extends Error {
  readonly status: number;
  readonly problem: Problem | null;

  constructor(status: number, problem: Problem | null) {
    super(problem?.detail ?? `The server answered ${status}.`);
    this.name = 'ApiError';
    this.status = status;
    this.problem = problem;
  }

  get code(): string | undefined {
    return this.problem?.code;
  }

  static async from(response: Response): Promise<ApiError> {
    const isProblem = response.headers.get('content-type')?.startsWith('application/problem+json') ?? false;
    let problem: Problem | null = null;
    if (isProblem) {
      try {
        problem = (await response.json()) as Problem;
      } catch {
        problem = null;
      }
    }
    return new ApiError(response.status, problem);
  }
}

/** What a failed request says: the server's problem detail, or the error's own message. */
export function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

/**
 * The JSON at `path`, a path at the server's root, under the base path, with `params` as its query
 * string; throws an `ApiError` for an error status.
 */
export async function getJSON<T>(path: string, params?: URLSearchParams, signal?: AbortSignal): Promise<T> {
  const query = params?.toString();
  const url = servedPath(path);
  const response = await fetch(query ? `${url}?${query}` : url, { signal, headers: { Accept: 'application/json' } });
  if (!response.ok) throw await ApiError.from(response);
  return (await response.json()) as T;
}

/**
 * The file at `path`, a path at the server's root, under the base path, with the name the server
 * gives it in its `Content-Disposition`, or `name`: an export (PLAN's S16d). Throws an `ApiError` for
 * an error status, so that a page can say why there is no file.
 */
export async function getFile(path: string, name: string): Promise<{ blob: Blob; name: string }> {
  const response = await fetch(servedPath(path), { headers: { Accept: 'application/json' } });
  if (!response.ok) throw await ApiError.from(response);
  return { blob: await response.blob(), name: fileName(response, name) };
}

/**
 * The name a download's `Content-Disposition` gives: its UTF-8 `filename*` whole where it has one, as
 * a collection's export names a file in any script (S18e), else its `filename`, else `name`.
 */
export function fileName(response: Response, name: string): string {
  const header = response.headers.get('content-disposition') ?? '';
  const encoded = /filename\*=UTF-8''([^;]+)/i.exec(header)?.[1];
  if (encoded) {
    try {
      return decodeURIComponent(encoded);
    } catch {
      // A name that does not decode falls back to the plain one.
    }
  }
  return /filename="([^"]+)"/.exec(header)?.[1] ?? name;
}

/**
 * A request that changes state and answers a file, as a collection's export does, which the history
 * records (S18e): `body` as JSON, `token` in `X-CSRF-Token`. Throws an `ApiError` for an error status.
 */
export async function sendForFile(path: string, token: string, body: unknown, name: string): Promise<{ blob: Blob; name: string }> {
  const headers = { Accept: 'application/json', 'X-CSRF-Token': token, 'Content-Type': 'application/json' };
  const response = await fetch(servedPath(path), { method: 'POST', headers, body: JSON.stringify(body) });
  if (!response.ok) throw await ApiError.from(response);
  return { blob: await response.blob(), name: fileName(response, name) };
}

/**
 * The JSON a POST of `fields` as a form body to `path` answers, for a request that changes nothing
 * but carries more than an address should, such as Batch's block of notes; throws an `ApiError`
 * for an error status.
 */
export async function postForm<T>(path: string, fields: URLSearchParams, signal?: AbortSignal): Promise<T> {
  const response = await fetch(servedPath(path), { method: 'POST', signal, headers: { Accept: 'application/json' }, body: fields });
  if (!response.ok) throw await ApiError.from(response);
  return (await response.json()) as T;
}

/**
 * A file sent as a change's body, as it is, under `contentType`, with `token` in `X-CSRF-Token`:
 * an import's export (PLAN's S16c). Gives the answer's JSON; throws an `ApiError` for an error status.
 */
export async function sendFile<T>(path: string, token: string, file: Blob, contentType: string): Promise<T> {
  const headers = { Accept: 'application/json', 'X-CSRF-Token': token, 'Content-Type': contentType };
  const response = await fetch(servedPath(path), { method: 'POST', headers, body: file });
  if (!response.ok) throw await ApiError.from(response);
  return (await response.json()) as T;
}

/**
 * A request that changes state, to `path` at the server's root under the base path: `body` as JSON,
 * and `token` in `X-CSRF-Token`, as the server asks of every change. Gives the answer's JSON, or
 * null for one with no body; throws an `ApiError` for an error status.
 */
export async function sendJSON<T>(method: 'POST' | 'PUT' | 'PATCH' | 'DELETE', path: string, token: string, body?: unknown): Promise<T | null> {
  const headers: Record<string, string> = { Accept: 'application/json', 'X-CSRF-Token': token };
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  const response = await fetch(servedPath(path), { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  if (!response.ok) throw await ApiError.from(response);
  return response.status === 204 ? null : ((await response.json()) as T);
}
