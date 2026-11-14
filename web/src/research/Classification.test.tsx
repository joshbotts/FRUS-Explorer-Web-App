import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { DocumentClassification } from '../api/people';
import type { DocumentDetail, Me } from '../api/types';
import { resetPreferences } from '../settings/preferences';
import { coverage, ready, renderAt, stubServer } from '../test/renderRoute';
import { actionTitle, correctionLine, shownClassification } from './ClassificationSection';

const d1: DocumentDetail = {
  document: {
    documentId: 'd1',
    volumeId: 'frus1961-63v06',
    documentNumber: '1',
    header: '1. Message From Chairman Khrushchev to President-elect Kennedy',
    displayTitle: '1. Message From Chairman Khrushchev to President-elect Kennedy',
    isEditorialNote: false,
    inIndex: true,
  },
  canonicalURL: 'https://history.state.gov/historicaldocuments/frus1961-63v06/d1',
  teiAvailable: true,
};

const curator: Me = { userId: 'owner', displayName: 'Owner', auth: 'none', roles: ['reader', 'curator', 'admin'], userData: true, csrfToken: 't1' };
const reader: Me = { userId: 'bob', displayName: 'bob', auth: 'header', roles: ['reader'], userData: true, csrfToken: 't2' };
const path = '/api/v1/me/volumes/frus1961-63v06/documents/d1/classification';
const plain: DocumentClassification = {
  indexed: true, isEditorialNote: false, parsedIsEditorialNote: false, correction: null, waiting: null, canCorrect: true, mode: 'standalone',
};

function server(me: Me, classification: DocumentClassification | ((url: URL, init?: RequestInit) => unknown), answers: Record<string, unknown> = {}) {
  const document = '/api/v1/me/volumes/frus1961-63v06/documents/d1';
  return stubServer({
    '/readyz': ready,
    '/api/v1/volumes': { total: 0, limit: 1000, offset: 0, items: [], coverage },
    '/api/v1/volumes/frus1961-63v06/documents/d1': d1,
    '/api/v1/volumes/frus1961-63v06/documents/d1/html': {},
    '/api/v1/me': me,
    [`${document}/notes`]: { volumeId: 'frus1961-63v06', documentId: 'd1', items: [] },
    [`${document}/summaries`]: { volumeId: 'frus1961-63v06', documentId: 'd1', items: [] },
    [`${document}/tags`]: { volumeId: 'frus1961-63v06', documentId: 'd1', items: [] },
    [path]: classification,
    ...answers,
  });
}

/** Opens the rail and its Classification section. */
async function openSection() {
  renderAt('/doc/frus1961-63v06/d1');
  await userEvent.click(await screen.findByRole('button', { name: 'Research' }));
  const rail = await screen.findByRole('complementary', { name: 'Research' });
  await userEvent.click(within(rail).getByRole('button', { name: 'Classification' }));
  return rail;
}

beforeEach(() => {
  resetPreferences();
  window.localStorage.clear();
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

describe('the rail’s Classification', () => {
  it('reclassifies a document for a curator, after the app’s question, and says the index follows it', async () => {
    let corrected = false;
    const fetch = server(curator, () =>
      corrected ? { ...plain, isEditorialNote: true, correction: { isEditorialNote: true, madeBy: 'Owner', madeAt: '2026-11-14T13:00:00.000Z' } } : plain,
    {
      [`PUT ${path}`]: () => {
        corrected = true;
        return { state: 'applied', entryId: 'E1' };
      },
    });
    const rail = await openSection();
    expect(await within(rail).findByText('Document')).toBeTruthy();
    await userEvent.click(within(rail).getByRole('button', { name: 'Reclassify as Editorial Note…' }));
    const question = await screen.findByRole('alertdialog', { name: 'Reclassify as Editorial Note…' });
    expect(question.textContent).toContain('will follow the new classification for everyone on this server');
    expect(document.activeElement?.textContent).toBe('Cancel');
    await userEvent.click(within(question).getByRole('button', { name: 'Reclassify as Editorial Note…' }));
    expect(await within(rail).findByText('The index follows the new classification.')).toBeTruthy();
    const put = fetch.mock.calls.find(([url, init]) => String(url).endsWith(path) && init?.method === 'PUT');
    expect(JSON.parse(String(put?.[1]?.body))).toEqual({ isEditorialNote: true });
    expect(await within(rail).findByText('Editorial note')).toBeTruthy();
    expect(within(rail).getByText('FRUS tags this as a document — reclassified on this server by Owner.')).toBeTruthy();
    await waitFor(() => expect(within(rail).getByRole('button', { name: 'Restore FRUS’s Classification' })).toBeTruthy());
  });

  it('says on an Import server that a restore waits for the next export, as its question says the change does', async () => {
    let restored = false;
    const kept: DocumentClassification = {
      ...plain, mode: 'import', isEditorialNote: true, correction: { isEditorialNote: true, madeBy: 'Owner', madeAt: '2026-11-14T13:00:00.000Z' },
    };
    server(curator, () => (restored ? { ...plain, mode: 'import', isEditorialNote: true, waiting: 'restore' } : kept), {
      [`DELETE ${path}`]: () => {
        restored = true;
        return { state: 'nextExport', entryId: 'E2' };
      },
    });
    const rail = await openSection();
    await userEvent.click(await within(rail).findByRole('button', { name: 'Restore FRUS’s Classification' }));
    const question = await screen.findByRole('alertdialog', { name: 'Restore FRUS’s Classification' });
    expect(question.textContent).toContain('so the change is applied when the next export is installed.');
    await userEvent.click(within(question).getByRole('button', { name: 'Restore FRUS’s Classification' }));
    expect(await within(rail).findByText('FRUS’s classification is put back when the next export is installed.', { selector: '[role=status]' })).toBeTruthy();
    expect(await within(rail).findByRole('button', { name: 'Reclassify as Editorial Note…' })).toBeTruthy();
  });

  it('shows a reader the classification and no control', async () => {
    server(reader, { ...plain, canCorrect: false });
    const rail = await openSection();
    expect(await within(rail).findByText('Document')).toBeTruthy();
    expect(within(rail).queryByRole('button', { name: /^Reclassify/ })).toBeNull();
  });
});

describe('the classification’s rules', () => {
  it('shows the correction kept, a restore waiting, or the index’s, with the app’s lines', () => {
    expect(shownClassification(plain)).toBe(false);
    expect(actionTitle(plain)).toBe('Reclassify as Editorial Note…');
    const kept: DocumentClassification = { ...plain, mode: 'import', correction: { isEditorialNote: true }, waiting: 'correction' };
    expect(shownClassification(kept)).toBe(true);
    expect(actionTitle(kept)).toBe('Restore FRUS’s Classification');
    expect(correctionLine(kept)).toBe('FRUS tags this as a document — reclassified on this server.');
    expect(correctionLine({ ...kept, parsedIsEditorialNote: true })).toBe(
      'FRUS now tags this the same way, so this server’s correction no longer changes anything. You can restore FRUS’s classification.',
    );
    const restoring: DocumentClassification = { ...plain, isEditorialNote: true, parsedIsEditorialNote: false, waiting: 'restore', mode: 'import' };
    expect(shownClassification(restoring)).toBe(false);
    expect(actionTitle(restoring)).toBe('Reclassify as Editorial Note…');
    expect(shownClassification({ ...plain, indexed: false, isEditorialNote: null })).toBeNull();
  });
});
