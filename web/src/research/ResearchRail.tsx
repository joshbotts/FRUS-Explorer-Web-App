// The reader's Research rail (SPEC, Reader and Research rail), the app's RESEARCH panel beside the
// text: from S14c its Tags section, which the app's rail keeps closed until it is opened, and
// remembers. The section shows the document's tags, each with the × that takes it off, and Add Tag,
// which opens the tag picker.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import type { UserTag } from '../api/types';
import { documentTagsQuery, removeDocumentTag } from '../api/userData';
import { copy } from '../copy';
import { useTagsSectionOpen } from '../settings/preferences';
import { TagPicker } from './TagPicker';

export function ResearchRail({
  volumeId,
  documentId,
  documentNumber,
  autoFocus,
  onClose,
}: {
  volumeId: string;
  documentId: string;
  /** The printed number, which the tag picker's title names, as the app's does. */
  documentNumber?: string;
  /** Whether opening it takes focus to it: when the reader opens it, not when a page loads with it open. */
  autoFocus: boolean;
  onClose: () => void;
}) {
  const heading = useRef<HTMLHeadingElement>(null);
  const [tagsOpen, setTagsOpen] = useTagsSectionOpen();
  const tags = useQuery(documentTagsQuery(volumeId, documentId));
  const count = tags.data?.items.length ?? 0;
  const [focusOnOpen] = useState(autoFocus);
  useEffect(() => {
    if (focusOnOpen) heading.current?.focus({ preventScroll: true });
  }, [focusOnOpen]);

  return (
    <aside
      id="research-panel"
      className="rail"
      aria-labelledby="research-heading"
      // Escape closes the rail, as Close does; a dialog open over it takes Escape first.
      onKeyDown={(event) => {
        if (event.key === 'Escape' && !event.defaultPrevented) {
          event.stopPropagation();
          onClose();
        }
      }}
    >
      <div className="rail-header">
        <h2 id="research-heading" ref={heading} tabIndex={-1}>
          {copy.research.title}
        </h2>
        <button type="button" onClick={onClose}>
          {copy.research.close}
        </button>
      </div>
      <section className="rail-section">
        <h3>
          <button
            type="button"
            className="disclosure"
            aria-expanded={tagsOpen === 'open'}
            aria-controls="research-tags"
            onClick={() => setTagsOpen(tagsOpen === 'open' ? 'closed' : 'open')}
          >
            {copy.research.tags}
            {count > 0 && (
              <span className="badge">
                <span aria-hidden="true">{count.toLocaleString('en-US')}</span>
                <span className="visually-hidden">, {copy.research.tagCount(count)}</span>
              </span>
            )}
          </button>
        </h3>
        {tagsOpen === 'open' && (
          <div id="research-tags">
            <TagsSection volumeId={volumeId} documentId={documentId} documentNumber={documentNumber} tags={tags.data?.items} error={tags.error} />
          </div>
        )}
      </section>
    </aside>
  );
}

function TagsSection({
  volumeId,
  documentId,
  documentNumber,
  tags,
  error,
}: {
  volumeId: string;
  documentId: string;
  documentNumber?: string;
  tags?: UserTag[];
  error: unknown;
}) {
  const client = useQueryClient();
  const addButton = useRef<HTMLButtonElement>(null);
  const [picking, setPicking] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);

  async function remove(tag: UserTag) {
    setFailure(null);
    try {
      await removeDocumentTag(client, volumeId, documentId, tag.id);
      // The chip is gone; focus goes to Add Tag, which stays.
      addButton.current?.focus();
    } catch (problem) {
      setFailure(errorMessage(problem));
    }
  }

  if (error) {
    return (
      <p className="error" role="alert">
        {errorMessage(error)}
      </p>
    );
  }
  if (!tags) return <p role="status">{copy.research.loading}</p>;
  return (
    <>
      <div className="chips tag-chips" role="group" aria-label={copy.research.tags}>
        {tags.map((tag) => (
          <button key={tag.id} type="button" className="chip tag-chip" aria-label={copy.research.removeTag(tag.name)} onClick={() => void remove(tag)}>
            {tag.name} <span aria-hidden="true">×</span>
          </button>
        ))}
        {/* With tags shown, the app's button is a plus alone; its name stays Add Tag. */}
        <button ref={addButton} type="button" className="chip add-tag" onClick={() => setPicking(true)}>
          <span aria-hidden="true">+</span>{' '}
          <span className={tags.length > 0 ? 'visually-hidden' : undefined}>{copy.research.addTag}</span>
        </button>
      </div>
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      {picking && (
        <TagPicker
          volumeId={volumeId}
          documentId={documentId}
          documentNumber={documentNumber}
          applied={tags}
          onClose={() => {
            setPicking(false);
            addButton.current?.focus();
          }}
        />
      )}
    </>
  );
}
