// What the notes' and summaries' tests share: the user, a note and a summary with the fields the
// server writes, what a change sent, and a component rendered with a query client of its own.
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render } from '@testing-library/react';
import type { ReactNode } from 'react';
import type { Me, Note, NoteSummary, Summary, UserTag } from '../api/types';

export const me: Me = { userId: 'owner', displayName: 'Owner', auth: 'none', roles: ['reader', 'curator', 'admin'], userData: true, csrfToken: 'token-1' };

export const berlin: UserTag = { id: 'B0000000-0000-4000-8000-000000000000', name: 'Berlin' };
export const revisit: UserTag = { id: 'C0000000-0000-4000-8000-000000000000', name: 'Revisit' };

export const documentPaths = {
  notes: '/api/v1/me/volumes/frus1961-63v06/documents/d1/notes',
  summaries: '/api/v1/me/volumes/frus1961-63v06/documents/d1/summaries',
};

export function noteSummary(fields: Partial<NoteSummary> & Pick<NoteSummary, 'id'>): NoteSummary {
  return {
    volumeId: 'frus1961-63v06',
    documentId: 'd1',
    bodyText: 'A note.',
    projectIds: [],
    userTagIds: [],
    selectedSummaryIds: [],
    linkedHighlightIds: [],
    createdAt: '2026-10-24T09:00:00.000Z',
    lastModified: '2026-10-24T09:00:00.000Z',
    ...fields,
  };
}

export function note(fields: Partial<Note> & Pick<Note, 'id'>): Note {
  return { runs: null, formattingKept: false, ...noteSummary(fields), ...fields };
}

export function summary(fields: Partial<Summary> & Pick<Summary, 'id'>): Summary {
  return {
    volumeId: 'frus1961-63v06',
    documentId: 'd1',
    promptId: '0EB00000-0000-4000-8000-000000000001',
    promptName: null,
    responseText: 'A summary.',
    responseFormat: 'general',
    wasChunked: false,
    authorship: 'userWritten',
    isHeadnoteDraft: false,
    projectId: null,
    createdAt: '2026-10-24T09:00:00.000Z',
    lastModified: '2026-10-24T09:00:00.000Z',
    editable: true,
    ...fields,
  };
}

/** What a change sent: its body as JSON, and its token. */
export function sent(init?: RequestInit) {
  const headers = (init?.headers ?? {}) as Record<string, string>;
  return { body: init?.body ? JSON.parse(String(init.body)) : undefined, token: headers['X-CSRF-Token'] };
}

/** `ui` rendered with a query client of its own, which a test may read. */
export function renderWithClient(ui: ReactNode) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return { ...render(<QueryClientProvider client={client}>{ui}</QueryClientProvider>), client };
}
