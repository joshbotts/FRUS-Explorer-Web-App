// Requests to the server's API, all same-origin, and its errors, which are RFC 9457 problem details.
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

/** The JSON at `path`, with `params` as its query string; throws an `ApiError` for an error status. */
export async function getJSON<T>(path: string, params?: URLSearchParams, signal?: AbortSignal): Promise<T> {
  const query = params?.toString();
  const response = await fetch(query ? `${path}?${query}` : path, { signal, headers: { Accept: 'application/json' } });
  if (!response.ok) throw await ApiError.from(response);
  return (await response.json()) as T;
}
