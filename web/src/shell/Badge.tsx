// A status beside a title, such as Partial or Indexed. Its comma is for screen readers and braille,
// which would otherwise run it into the text before it.
import type { ReactNode } from 'react';

export function Badge({ children }: { children: ReactNode }) {
  return (
    <span className="badge">
      <span className="visually-hidden">, </span>
      {children}
    </span>
  );
}
