import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { DocumentDetail, ReaderLinkTarget, Volume } from '../api/types';
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

  it('opens the volume a page link names in Browse, where the kit’s PageLink sends it, and the visit names the page', async () => {
    const v14: Volume = {
      volumeId: 'frus1961-63v14',
      filename: 'frus1961-63v14.xml',
      subseries: '1961-63',
      title: 'Foreign Relations of the United States, 1961–1963, Volume XIV, Berlin Crisis, 1961–1962',
      dateRange: {},
      status: 'published',
      editors: [],
      sizeBytes: 1,
      tags: [],
      indexed: false,
      indexedDocuments: 0,
      teiAvailable: false,
    };
    // A page the bundled page map names no document on, of a volume this server does not hold.
    const href = 'frusexplorer://doc/frus1961-63v14%23pg_859/frus1961-63v14';
    const link: ReaderLinkTarget = {
      kind: 'page',
      href,
      target: 'frus1961-63v14#pg_859',
      page: 859,
      pageVolumeId: 'frus1961-63v14',
      volumeId: 'frus1961-63v14',
      wholeVolumeLink: 'browse',
      volume: { title: v14.title, teiAvailable: false, indexed: false },
      url: 'https://history.state.gov/historicaldocuments/frus1961-63v14',
    };
    const v15: Volume = { ...v14, volumeId: 'frus1961-63v15', title: 'Volume XV', teiAvailable: true };
    stubServer({
      '/readyz': ready,
      '/api/v1/volumes': { total: 0, limit: 1000, offset: 0, items: [], coverage },
      '/api/v1/volumes/frus1961-63v06/documents/d1': d1,
      '/api/v1/volumes/frus1961-63v06/documents/d1/html': {},
      '/api/v1/volumes/frus1961-63v06/documents/d1/link': link,
      '/api/v1/volumes/frus1961-63v14': v14,
      '/api/v1/volumes/frus1961-63v15': v15,
    });
    const { router } = renderAt('/doc/frus1961-63v06/d1');
    const frame = (await screen.findByTitle('Document text: 1. Telegram From the Embassy in the Soviet Union')) as HTMLIFrameElement;
    // The page's host script posts the link, from the frame's window.
    const posted = { source: 'frus-reader', kind: 'link', detail: { href } };
    window.dispatchEvent(new MessageEvent('message', { data: posted, origin: 'null', source: frame.contentWindow }));
    await waitFor(() => expect(router.state.location.pathname).toBe('/browse/frus1961-63v14'));
    expect(await screen.findByText('You followed a link to page 859 of this volume, which isn’t on this server.')).toBeTruthy();

    // A visit by any other route names no page.
    await router.navigate({ to: '/browse/$volumeId', params: { volumeId: 'frus1961-63v14' } });
    await screen.findByText('Its TEI isn’t on this server, so its documents can’t be read here.');
    expect(screen.queryByText(/You followed a link/)).toBeNull();

    // A volume whose TEI is here, unindexed, is opened for the same reason, which the line gives.
    await router.navigate({ to: '/browse/$volumeId', params: { volumeId: 'frus1961-63v15' }, state: { followedPage: 539 } });
    expect(await screen.findByText('You followed a link to page 539 of this volume, which this server hasn’t indexed.')).toBeTruthy();
  });
});
