// Cite (SPEC, Citation): the document's citation in the kit's three styles, as the server writes
// it, with Copy Citation and Copy URL.
import { useQuery } from '@tanstack/react-query';
import { type ReactNode, useEffect, useRef, useState } from 'react';
import { citationQuery } from '../api/endpoints';
import type { CitationStyleName } from '../api/types';
import { copy } from '../copy';
import { useCitationStyle } from '../settings/preferences';

/** The formatter's Markdown emphasis, `_…_` or `*…*`, as <em>; everything else stays text. */
export function citationNodes(citation: string): ReactNode[] {
  const nodes: ReactNode[] = [];
  const emphasis = /_([^_]+)_|\*([^*]+)\*/g;
  let last = 0;
  for (const match of citation.matchAll(emphasis)) {
    if (match.index > last) nodes.push(citation.slice(last, match.index));
    nodes.push(<em key={match.index}>{match[1] ?? match[2]}</em>);
    last = match.index + match[0].length;
  }
  if (last < citation.length) nodes.push(citation.slice(last));
  return nodes;
}

export function CitePanel({
  volumeId,
  documentId,
  autoFocus,
  onClose,
}: {
  volumeId: string;
  documentId: string;
  /** Whether opening it takes focus to it: when the reader opens it, not when a page loads with it open. */
  autoFocus: boolean;
  onClose: () => void;
}) {
  const [style, setStyle] = useCitationStyle();
  const citation = useQuery(citationQuery(volumeId, documentId, style));
  const heading = useRef<HTMLHeadingElement>(null);
  // What Copy said, and the text to copy by hand, belong to the citation they were for.
  const key = `${volumeId}/${documentId}/${style}`;
  const [outcome, setOutcome] = useState<{ key: string; status: string; fallback: string | null } | null>(null);
  const current = outcome?.key === key ? outcome : null;
  const fallbackField = useRef<HTMLTextAreaElement>(null);

  useEffect(() => fallbackField.current?.select(), [current?.fallback]);
  // Opening the rail takes focus to it: below 900 px it covers the text. Only on opening.
  const [focusOnOpen] = useState(autoFocus);
  useEffect(() => {
    if (focusOnOpen) heading.current?.focus({ preventScroll: true });
  }, [focusOnOpen]);

  async function copyText(text: string) {
    try {
      await navigator.clipboard.writeText(text);
      setOutcome({ key, status: copy.cite.copied, fallback: null });
    } catch {
      // An insecure origin, or a browser that refuses: the text, selected, to copy by hand.
      setOutcome({ key, status: copy.cite.copyFailed, fallback: text });
    }
  }

  const data = citation.data;
  // While another style loads, the last one stays on screen, but only its own style is copied.
  const loadingStyle = citation.isPlaceholderData;
  return (
    <aside
      id="cite-panel"
      className="rail"
      aria-labelledby="cite-heading"
      // Escape closes the rail, as Close does, and as it closes the app's sheets.
      onKeyDown={(event) => {
        if (event.key === 'Escape') {
          event.stopPropagation();
          onClose();
        }
      }}
    >
      <div className="rail-header">
        <h2 id="cite-heading" ref={heading} tabIndex={-1}>
          {copy.cite.title}
        </h2>
        <button type="button" onClick={onClose}>
          {copy.cite.close}
        </button>
      </div>
      {data && (
        <fieldset>
          <legend>{copy.cite.style}</legend>
          {data.styles.map((option) => (
            <label key={option.style}>
              <input
                type="radio"
                name="citation-style"
                value={option.style}
                checked={option.style === style}
                onChange={() => setStyle(option.style as CitationStyleName)}
              />{' '}
              {option.shortName}
            </label>
          ))}
        </fieldset>
      )}
      {citation.isError && (
        <p className="error" role="alert">
          {citation.error instanceof Error ? citation.error.message : String(citation.error)}
        </p>
      )}
      {data && (
        <>
          <p className="citation" data-style={data.style} aria-busy={loadingStyle}>
            {citationNodes(data.citation)}
          </p>
          <div className="actions">
            <button type="button" disabled={loadingStyle} onClick={() => void copyText(data.plainText)}>
              {copy.cite.copyCitation}
            </button>
            <button type="button" onClick={() => void copyText(data.canonicalURL)}>
              {copy.cite.copyLink}
            </button>
          </div>
        </>
      )}
      <p role="status" className="copy-status">
        {current?.status ?? ''}
      </p>
      {current?.fallback != null && (
        <textarea ref={fallbackField} readOnly value={current.fallback} aria-label={copy.cite.toCopy} rows={4} />
      )}
    </aside>
  );
}
