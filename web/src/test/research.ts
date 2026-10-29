// The research layer's fixtures (PLAN's S17f): the synced preferences as a user who has set nothing has them.
import type { Preferences } from '../api/research';

export const preferences: Preferences = {
  citationStyle: '',
  defaultDocumentMode: '',
  researchLoggingEnabled: true,
  tagOrder: [],
  projectOrder: [],
  wordCloud: { minLength: 3, minCount: 1, foldPlurals: true, filterMarkings: true, excludeBoilerplate: true, globalStopwords: [], lensStopwordsJSON: '' },
};
