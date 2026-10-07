import { cleanup, render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { ReaderLinkTarget } from '../api/types';
import { LinkCard } from './LinkCard';

afterEach(cleanup);

const khrushchev: ReaderLinkTarget = {
  kind: 'person',
  href: 'frusexplorer://person/p_KNS2',
  ref: 'p_KNS2',
  person: { ref: 'p_KNS2', name: 'Khrushchev, Nikita S.', description: 'Chairman of the Council of Ministers of the Soviet Union' },
};

describe('LinkCard', () => {
  it('shows a person from the volume’s list of names, focused at the name, and closes with Done', async () => {
    const onClose = vi.fn();
    render(<LinkCard target={khrushchev} onClose={onClose} />);
    const dialog = screen.getByRole('dialog', { name: 'Khrushchev, Nikita S.' });
    expect(dialog.hasAttribute('open')).toBe(true);
    expect(dialog.textContent).toContain('Chairman of the Council of Ministers of the Soviet Union');
    expect(document.activeElement).toBe(screen.getByRole('heading', { name: 'Khrushchev, Nikita S.' }));
    await userEvent.click(screen.getByRole('button', { name: 'Done' }));
    expect(onClose).toHaveBeenCalledOnce();
  });

  it('says how many indexed documents mention the person, as the app’s sheet does, and nothing without an index', () => {
    const counted = (mentionCount?: number) => {
      cleanup();
      render(<LinkCard target={{ ...khrushchev, mentionCount }} onClose={() => {}} />);
      return screen.getByRole('dialog', { name: 'Khrushchev, Nikita S.' }).textContent;
    };
    expect(counted(120)).toContain('In Indexed DocumentsMentioned in 120 indexed documents');
    expect(counted(1)).toContain('Mentioned in 1 indexed document');
    expect(counted(0)).toContain('Not found in indexed documents');
    expect(counted(undefined)).not.toContain('In Indexed Documents');
  });

  it('says so when the volume’s lists have no entry', () => {
    render(<LinkCard target={{ kind: 'person', href: 'frusexplorer://person/p_X', ref: 'p_X' }} onClose={() => {}} />);
    expect(screen.getByRole('dialog', { name: 'Person Information Unavailable' }).textContent).toContain(
      'The volume’s list of names has no entry for this person.',
    );
    cleanup();
    render(<LinkCard target={{ kind: 'gloss', href: 'frusexplorer://gloss/t_X', ref: 't_X' }} onClose={() => {}} />);
    expect(screen.getByRole('dialog', { name: 'Term Definition Unavailable' })).toBeDefined();
  });

  it('shows a term and its definition', () => {
    const ussr: ReaderLinkTarget = {
      kind: 'gloss',
      href: 'frusexplorer://gloss/t_USSR1',
      ref: 't_USSR1',
      term: { ref: 't_USSR1', term: 'USSR', definition: 'Union of Soviet Socialist Republics' },
    };
    render(<LinkCard target={ussr} onClose={() => {}} />);
    expect(screen.getByRole('dialog', { name: 'USSR' }).textContent).toContain('Union of Soviet Socialist Republics');
  });

  it('explains an unresolved reference, with its apparent destination', () => {
    const broken: ReaderLinkTarget = {
      kind: 'brokenReference',
      href: 'frusexplorer://brokenref/%23pg_700',
      target: '#pg_700',
      brokenReference: { target: '#pg_700', reason: 'unknownPage', resolvedVolume: 'frus1872p2v3', resolvedAnchor: 'pg_700' },
    };
    render(<LinkCard target={broken} onClose={() => {}} />);
    const dialog = screen.getByRole('dialog', { name: 'Unresolved Reference' });
    expect(dialog.textContent).toContain('The page this reference cites could not be found in the cited volume.');
    expect(screen.getByRole('heading', { name: 'Apparent destination' })).toBeDefined();
    expect(dialog.textContent).toContain('frus1872p2v3 · pg_700');
    expect(dialog.textContent).toContain('Flagged by FRUS Explorer’s corpus-wide cross-reference validation.');
  });
});
