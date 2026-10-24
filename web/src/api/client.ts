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
