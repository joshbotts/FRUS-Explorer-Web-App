// The cards a link in the reader opens (SPEC, Reader and Research rail): a person from the volume's
// list of names, a term from its list of abbreviations, or an unresolved reference with the bundled
// index's account of it. The app shows each as a sheet, so each is a modal dialog here: it holds
// focus until Done or Escape closes it, and the reader then hands focus back to the link.
import { type ReactNode, useEffect, useId, useRef } from 'react';
import type { ReaderLinkTarget } from '../api/types';
import { copy } from '../copy';

export function LinkCard({ target, onClose }: { target: ReaderLinkTarget; onClose: () => void }) {
  const dialog = useRef<HTMLDialogElement>(null);
  const heading = useRef<HTMLHeadingElement>(null);
  const headingId = useId();

  useEffect(() => {
    const element = dialog.current;
    if (element && !element.open) element.showModal();
    heading.current?.focus();
  }, []);

  let title: string;
  let body: ReactNode;
  if (target.kind === 'person') {
    title = target.person?.name ?? copy.card.personUnavailable;
    body = target.person ? target.person.description && <p>{target.person.description}</p> : <p>{copy.card.personUnavailableDetail}</p>;
  } else if (target.kind === 'gloss') {
    title = target.term?.term ?? copy.card.termUnavailable;
    body = target.term ? target.term.definition && <p>{target.term.definition}</p> : <p>{copy.card.termUnavailableDetail}</p>;
  } else {
    const broken = target.brokenReference;
    title = copy.card.unresolved;
    body = broken && (
      <>
        <p>{copy.card.unresolvedReason(broken.reason)}</p>
        {broken.resolvedAnchor && (
          <>
            <h3>{copy.card.apparentDestination}</h3>
            <p className="destination">
              {broken.resolvedVolume ? `${broken.resolvedVolume} · ${broken.resolvedAnchor}` : broken.resolvedAnchor}
            </p>
          </>
        )}
        <p className="note">{copy.card.flagged}</p>
      </>
    );
  }

  return (
    <dialog ref={dialog} className="card" aria-labelledby={headingId} onClose={onClose}>
      <h2 id={headingId} ref={heading} tabIndex={-1}>
        {title}
      </h2>
      {body}
      <div className="actions">
        <button type="button" onClick={() => dialog.current?.close()}>
          {copy.card.done}
        </button>
      </div>
    </dialog>
  );
}
