// Each screen names the browser's tab after itself (WCAG 2.4.2), and the shell's name follows.
import { useEffect } from 'react';
import { copy } from '../copy';

/** A title from the TEI may hold line breaks and runs of spaces; a tab or a heading shows one space. */
export function plainTitle(title: string): string {
  return title.replace(/\s+/g, ' ').trim();
}

export function useDocumentTitle(screen: string): void {
  useEffect(() => {
    document.title = copy.app.title(plainTitle(screen));
  }, [screen]);
}
