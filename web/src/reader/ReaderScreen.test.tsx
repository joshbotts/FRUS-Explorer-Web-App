import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { DocumentDetail } from '../api/types';
import { resetPreferences } from '../settings/preferences';
import { coverage, ready, renderAt, stubServer } from '../test/renderRoute';

const d1: DocumentDetail = {
  document: {
    documentId: 'd1',
    volumeId: 'frus1961-63v06',
    documentNumber: '1',
    header: '1. Telegram From the Embassy in the Soviet Union',
    displayTitle: '1. Telegram From the Embassy in the Soviet Union',
    isEditorialNote: false,
    inIndex: true,
  },
  canonicalURL: 'https://history.state.gov/historicaldocuments/frus1961-63v06/d1',
  teiAvailable: true,
};

beforeEach(() => {
  resetPreferences();
  window.localStorage.removeItem('frus.readingWidth');
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

describe('ReaderScreen', () => {
  it('offers the app’s Reading Width beside Text Size, Standard at first, and loads the page at the width chosen', async () => {
    stubServer({
      '/readyz': ready,
      '/api/v1/volumes': { total: 0, limit: 1000, offset: 0, items: [], coverage },
      '/api/v1/volumes/frus1961-63v06/documents/d1': d1,
      // The page itself, which the reader checks before the frame loads it.
      '/api/v1/volumes/frus1961-63v06/documents/d1/html': {},
    });
    renderAt('/doc/frus1961-63v06/d1');
    const toolbar = await screen.findByRole('group', { name: 'Document' });
    const controls = within(toolbar).getAllByRole('combobox');
    expect(controls.map((control) => control.closest('label')?.firstChild?.textContent?.trim())).toEqual(['Text Size', 'Reading Width']);
    const width = within(toolbar).getByRole('combobox', { name: 'Reading Width' }) as HTMLSelectElement;
    expect([...width.options].map((option) => [option.value, option.textContent])).toEqual([
      ['narrow', 'Narrow'],
      ['standard', 'Standard'],
      ['wide', 'Wide'],
    ]);
    expect(width.value).toBe('standard');
    const frame = () => screen.getByTitle('Document text: 1. Telegram From the Embassy in the Soviet Union');
    await waitFor(() => expect(frame().getAttribute('src')).toContain('readingWidth=standard'));

    await userEvent.selectOptions(width, 'wide');
    await waitFor(() => expect(frame().getAttribute('src')).toContain('readingWidth=wide'));
    expect(frame().getAttribute('src')).toContain('textSize=medium');
    // The choice outlasts the page, as Text Size does.
    expect(window.localStorage.getItem('frus.readingWidth')).toBe('wide');
  });
});
