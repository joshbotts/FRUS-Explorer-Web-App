import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { cleanup, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { DocumentCitation } from '../api/types';
import { resetPreferences } from '../settings/preferences';
import { citationNodes, CitePanel } from './CitePanel';

const styles = [
  { style: 'historyAtState', name: 'History at State (Recommended)', shortName: 'history.state.gov' },
  { style: 'chicago', name: 'Chicago', shortName: 'Chicago' },
  { style: 'turabian', name: 'Turabian', shortName: 'Turabian' },
] as const;

function citation(style: DocumentCitation['style']): DocumentCitation {
  return {
    volumeId: 'frus1961-63v06',
    documentId: 'd1',
    style,
    citation: `_Foreign Relations of the United States_, ${style}, Document 1.`,
    plainText: `Foreign Relations of the United States, ${style}, Document 1.`,
    canonicalURL: 'https://history.state.gov/historicaldocuments/frus1961-63v06/d1',
    documentNumber: '1',
    documentLabel: 'Doc 1',
    numberSource: 'index',
    publicationYearSource: 'manifest',
    styles: [...styles],
  };
}

function renderPanel(onClose = () => {}) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <CitePanel volumeId="frus1961-63v06" documentId="d1" onClose={onClose} />
    </QueryClientProvider>,
  );
}

beforeEach(() => {
  window.localStorage.clear();
  resetPreferences();
  vi.stubGlobal(
    'fetch',
    vi.fn(async (url: string) => {
      const style = new URL(url, 'http://localhost').searchParams.get('style') as DocumentCitation['style'];
      return new Response(JSON.stringify(citation(style)), { headers: { 'content-type': 'application/json' } });
    }),
  );
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

describe('citationNodes', () => {
  it('turns the formatter’s emphasis into <em> and keeps the rest as text', () => {
    const { container } = render(<p>{citationNodes('_Foreign Relations_, 1894, *Nicaragua* <b>x</b>')}</p>);
    expect(container.querySelectorAll('em')).toHaveLength(2);
    expect(container.querySelector('b')).toBeNull();
    expect(container.textContent).toBe('Foreign Relations, 1894, Nicaragua <b>x</b>');
  });
});

describe('CitePanel', () => {
  it('copies the plain text of the chosen style and says so', async () => {
    const writeText = vi.fn(async () => {});
    vi.stubGlobal('navigator', { ...navigator, clipboard: { writeText } });
    renderPanel();
    await userEvent.click(await screen.findByRole('radio', { name: 'Chicago' }));
    await screen.findByText(/chicago, Document 1/);
    await userEvent.click(screen.getByRole('button', { name: 'Copy Citation' }));
    expect(writeText).toHaveBeenCalledWith('Foreign Relations of the United States, chicago, Document 1.');
    expect(screen.getByRole('status').textContent).toBe('Copied');
    await userEvent.click(screen.getByRole('button', { name: 'Copy URL' }));
    expect(writeText).toHaveBeenLastCalledWith('https://history.state.gov/historicaldocuments/frus1961-63v06/d1');
    expect(window.localStorage.getItem('frus.citationStyle')).toBe('chicago');
  });

  it('keeps the style choices and their focus while another style loads, and copies only a loaded one', async () => {
    let release = () => {};
    const chicagoLoaded = new Promise<void>((resolve) => (release = resolve));
    vi.stubGlobal(
      'fetch',
      vi.fn(async (url: string) => {
        const style = new URL(url, 'http://localhost').searchParams.get('style') as DocumentCitation['style'];
        if (style === 'chicago') await chicagoLoaded;
        return new Response(JSON.stringify(citation(style)), { headers: { 'content-type': 'application/json' } });
      }),
    );
    renderPanel();
    const chicago = await screen.findByRole('radio', { name: 'Chicago' });
    await userEvent.click(chicago);
    // The history.state.gov citation stays on screen, but Copy Citation waits for Chicago's.
    expect(document.activeElement).toBe(chicago);
    expect(screen.getByRole('button', { name: 'Copy Citation' }).hasAttribute('disabled')).toBe(true);
    expect(document.querySelector('.citation')?.getAttribute('data-style')).toBe('historyAtState');
    release();
    await waitFor(() => expect(document.querySelector('.citation')?.getAttribute('data-style')).toBe('chicago'));
    expect(document.activeElement).toBe(screen.getByRole('radio', { name: 'Chicago' }));
    expect(screen.getByRole('button', { name: 'Copy Citation' }).hasAttribute('disabled')).toBe(false);
  });

  it('takes focus to its heading when it opens, and closes', async () => {
    const onClose = vi.fn();
    renderPanel(onClose);
    expect(document.activeElement).toBe(screen.getByRole('heading', { name: 'Cite' }));
    await userEvent.click(screen.getByRole('button', { name: 'Close' }));
    expect(onClose).toHaveBeenCalledOnce();
  });

  it('shows the text selected to copy by hand when the browser refuses', async () => {
    vi.stubGlobal('navigator', { ...navigator, clipboard: { writeText: vi.fn(async () => Promise.reject(new Error('denied'))) } });
    renderPanel();
    await userEvent.click(await screen.findByRole('button', { name: 'Copy Citation' }));
    const field = await screen.findByRole('textbox', { name: 'Text to copy' });
    expect((field as HTMLTextAreaElement).value).toBe('Foreign Relations of the United States, historyAtState, Document 1.');
    await waitFor(() => expect(screen.getByRole('status').textContent).toMatch(/did not allow copying/));
  });
});
