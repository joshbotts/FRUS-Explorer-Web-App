// The feedback on a semantic match (PLAN's S26d): the verdicts the user gave on Related Documents' semantic rows,
// kept with their account, which Settings ▸ Data's Semantic Match Feedback summarises as the app's screen does, the
// file it downloads, the app's `frus-semantic-feedback.json`, and Clear Recorded Feedback.
import { type QueryClient, queryOptions } from '@tanstack/react-query';
import { getJSON } from './client';
import { change } from './userData';

/** The app's summary of the verdicts (`SemanticFeedbackLog.summary()`), with each era's label. */
export interface SemanticFeedbackSummary {
  total: number;
  helpful: number;
  byEra: { era: string; label: string; count: number }[];
  /** Where the app's screen asks for the file. */
  address: string;
  fileName: string;
}

export const semanticFeedbackQuery = queryOptions({
  queryKey: ['semanticFeedback'],
  queryFn: ({ signal }) => getJSON<SemanticFeedbackSummary>('/api/v1/me/semantic-feedback', undefined, signal),
  staleTime: 0,
  retry: false,
});

/** The file, which the server names as the app names it. */
export const semanticFeedbackFilePath = '/api/v1/me/semantic-feedback/file';

/** Clear Recorded Feedback: every verdict of the user's deleted, and every list read again for its rows' verdicts. */
export async function clearSemanticFeedback(client: QueryClient): Promise<number> {
  const cleared = await change<{ removed: number }>(client, 'DELETE', '/api/v1/me/semantic-feedback');
  void client.invalidateQueries({ queryKey: ['semanticFeedback'] });
  void client.invalidateQueries({ queryKey: ['related'] });
  return cleared?.removed ?? 0;
}
