// The app's symbols beside Citation Lookup's labels, drawn small in the label's colour. They are
// decoration, hidden from assistive technology: each label says in words what the symbol shows.
import type { ReactNode } from 'react';
import type { SymbolName } from './lookupRules';

const strokes = { fill: 'none', stroke: 'currentColor', strokeWidth: 1.5, strokeLinecap: 'round', strokeLinejoin: 'round' } as const;
/** A mark cut out of a filled shape, in the page's own colour. */
const cutout = { fill: 'none', stroke: 'var(--bg)', strokeWidth: 1.6, strokeLinecap: 'round', strokeLinejoin: 'round' } as const;

const drawings: Record<SymbolName, ReactNode> = {
  'checkmark.seal.fill': (
    <>
      <path
        d="M8 1.2l1.6 1.2 2-.2.6 1.9 1.7 1.1-.6 1.9.6 1.9-1.7 1.1-.6 1.9-2-.2L8 14.8l-1.6-1.2-2 .2-.6-1.9-1.7-1.1.6-1.9-.6-1.9 1.7-1.1.6-1.9 2 .2z"
        fill="currentColor"
      />
      <path d="M5.4 8.1l1.8 1.8 3.5-3.6" {...cutout} />
    </>
  ),
  'number.circle': (
    <>
      <circle cx="8" cy="8" r="6.5" {...strokes} />
      <path d="M6.6 5v6M9.4 5v6M4.8 6.9h6.4M4.8 9.1h6.4" {...strokes} strokeWidth={1.1} />
    </>
  ),
  'doc.on.doc': (
    <>
      <rect x="5" y="1.5" width="8.5" height="10" rx="1.2" {...strokes} />
      <path d="M3.5 4.5h-.3A1.2 1.2 0 0 0 2 5.7v7.6a1.2 1.2 0 0 0 1.2 1.2h6.1a1.2 1.2 0 0 0 1.2-1.2v-.3" {...strokes} />
    </>
  ),
  'number.square': (
    <>
      <rect x="1.5" y="1.5" width="13" height="13" rx="2.5" {...strokes} />
      <path d="M6.6 5v6M9.4 5v6M4.8 6.9h6.4M4.8 9.1h6.4" {...strokes} strokeWidth={1.1} />
    </>
  ),
  'text.magnifyingglass': (
    <>
      <path d="M1.5 3h8M1.5 6h5M1.5 9h3.5" {...strokes} />
      <circle cx="10.2" cy="9.7" r="2.9" {...strokes} />
      <path d="M12.3 11.8l2.2 2.2" {...strokes} />
    </>
  ),
  'doc.circle': (
    <>
      <circle cx="8" cy="8" r="6.5" {...strokes} />
      <path d="M6 4.6h2.6L10.4 6.4v4.5a.5.5 0 0 1-.5.5H6a.5.5 0 0 1-.5-.5V5.1a.5.5 0 0 1 .5-.5z" {...strokes} strokeWidth={1.1} />
    </>
  ),
  lightbulb: (
    <>
      <path d="M5.6 10.4C4.4 9.5 3.7 8.2 3.7 6.7a4.3 4.3 0 0 1 8.6 0c0 1.5-.7 2.8-1.9 3.7v1.3H5.6z" {...strokes} />
      <path d="M6.1 13.3h3.8M6.8 14.8h2.4" {...strokes} />
    </>
  ),
  'checkmark.circle.fill': (
    <>
      <circle cx="8" cy="8" r="6.8" fill="currentColor" />
      <path d="M5.2 8.2l2 2 3.7-3.9" {...cutout} />
    </>
  ),
  'questionmark.circle.fill': (
    <>
      <circle cx="8" cy="8" r="6.8" fill="currentColor" />
      <path d="M6.3 6.3a1.8 1.8 0 1 1 2.5 1.6c-.5.2-.8.6-.8 1.1v.4" {...cutout} />
      <circle cx="8" cy="11.4" r=".55" fill="var(--bg)" />
    </>
  ),
  'minus.circle': (
    <>
      <circle cx="8" cy="8" r="6.5" {...strokes} />
      <path d="M5 8h6" {...strokes} />
    </>
  ),
  'exclamationmark.triangle.fill': (
    <>
      <path d="M8 1.5l6.8 12a.7.7 0 0 1-.6 1H1.8a.7.7 0 0 1-.6-1z" fill="currentColor" />
      <path d="M8 5.8v4" {...cutout} />
      <circle cx="8" cy="12" r=".6" fill="var(--bg)" />
    </>
  ),
};

export function SymbolIcon({ name }: { name: SymbolName }) {
  return (
    <svg className="symbol" viewBox="0 0 16 16" width="16" height="16" aria-hidden="true" focusable="false" data-symbol={name}>
      {drawings[name]}
    </svg>
  );
}
