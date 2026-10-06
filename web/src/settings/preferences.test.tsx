import { act, cleanup, render, screen } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { resetPreferences, useCitationStyle } from './preferences';

function Style() {
  const [style, setStyle] = useCitationStyle();
  return (
    <button type="button" onClick={() => setStyle('chicago')}>
      {style}
    </button>
  );
}

beforeEach(() => resetPreferences());
afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
});

describe('preferences', () => {
  it('keep a choice for the page, shared by every reader, when storage refuses', () => {
    vi.spyOn(Storage.prototype, 'getItem').mockImplementation(() => {
      throw new DOMException('blocked', 'SecurityError');
    });
    vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
      throw new DOMException('blocked', 'SecurityError');
    });
    const first = render(<Style />);
    expect(screen.getByRole('button').textContent).toBe('historyAtState');
    act(() => screen.getByRole('button').click());
    expect(screen.getByRole('button').textContent).toBe('chicago');
    // A panel closed and opened again reads the same choice.
    first.unmount();
    render(<Style />);
    expect(screen.getByRole('button').textContent).toBe('chicago');
  });

  it('keep a choice in storage for later pages', () => {
    window.localStorage.removeItem('frus.citationStyle');
    render(<Style />);
    act(() => screen.getByRole('button').click());
    expect(window.localStorage.getItem('frus.citationStyle')).toBe('chicago');
  });
});
