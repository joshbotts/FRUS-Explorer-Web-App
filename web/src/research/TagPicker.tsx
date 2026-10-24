// The tag picker, as the app's document-mode sheet works (`UserTagPickerSheet`): New Tag at the top,
// which makes a tag, switches it on and lists it first with a New badge; Your Tags, a switch for each;
// Done, which gives the document exactly the tags switched on; and Cancel, which deletes the tags made
// in the sheet, as the app's does. A modal dialog here: it holds focus until it closes, and Escape is
// Cancel.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useId, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import type { UserTag } from '../api/types';
import { createTag, deleteTag, setDocumentTags, tagsQuery } from '../api/userData';
import { copy } from '../copy';
import { Badge } from '../shell/Badge';

export function TagPicker({
  volumeId,
  documentId,
  documentNumber,
  applied,
  onClose,
}: {
  volumeId: string;
  documentId: string;
  documentNumber?: string;
  /** The tags the document carries, which start switched on. */
  applied: UserTag[];
  onClose: () => void;
}) {
  const client = useQueryClient();
  // Read again as the sheet opens: a tag made in another tab since the list was read is listed too.
  const all = useQuery({ ...tagsQuery, staleTime: 0 });
  const dialog = useRef<HTMLDialogElement>(null);
  const field = useRef<HTMLInputElement>(null);
  const headingId = useId();
  const [selected, setSelected] = useState(() => new Set(applied.map((tag) => tag.id)));
  /** The tags made in the sheet, oldest first. */
  const [made, setMade] = useState<UserTag[]>([]);
  // The same, for Cancel, which may come while a tag is still being made: it waits for that one.
  const madeSoFar = useRef<UserTag[]>([]);
  const making = useRef<Promise<unknown> | null>(null);
  const [name, setName] = useState('');
  const [announcement, setAnnouncement] = useState('');
  const [failure, setFailure] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  // Done or Cancel closes the sheet once: a second press while the first is under way does nothing.
  const closing = useRef(false);
  /** A tag just made, whose switch takes focus once it is drawn. */
  const focusTag = useRef<string | null>(null);

  useEffect(() => {
    const element = dialog.current;
    if (element && !element.open) element.showModal();
    field.current?.focus();
  }, []);

  // A tag just made takes focus, as the app moves VoiceOver to it, once its switch is drawn.
  useEffect(() => {
    const option = focusTag.current ? document.getElementById(optionId(focusTag.current)) : null;
    if (!option) return;
    option.focus();
    focusTag.current = null;
  });

  const madeIds = new Set(made.map((tag) => tag.id));
  const listed = all.data?.items ?? [];
  const listedIds = new Set(listed.map((tag) => tag.id));
  // The tags made here first, newest first, then the rest by name, as the app pins them (#242). A tag
  // the document carries is listed even before the list has it, so Done never drops one unseen.
  const shown = [...made]
    .reverse()
    .concat([...listed, ...applied.filter((tag) => !listedIds.has(tag.id))].filter((tag) => !madeIds.has(tag.id)));

  async function add() {
    const trimmed = name.trim();
    if (!trimmed || busy) return;
    setBusy(true);
    setFailure(null);
    try {
      const creating = createTag(client, trimmed);
      making.current = creating.catch(() => null);
      const tag = await creating;
      madeSoFar.current = [...madeSoFar.current, tag];
      setMade((earlier) => [...earlier, tag]);
      setSelected((earlier) => new Set(earlier).add(tag.id));
      setName('');
      setAnnouncement(copy.tagPicker.created(tag.name));
      focusTag.current = tag.id;
    } catch (error) {
      setFailure(errorMessage(error));
    } finally {
      making.current = null;
      setBusy(false);
    }
  }

  async function done() {
    if (closing.current || !all.data) return;
    closing.current = true;
    setBusy(true);
    setFailure(null);
    try {
      await setDocumentTags(
        client,
        volumeId,
        documentId,
        shown.filter((tag) => selected.has(tag.id)).map((tag) => tag.id),
      );
      dialog.current?.close();
    } catch (error) {
      closing.current = false;
      setBusy(false);
      setFailure(errorMessage(error));
    }
  }

  async function cancel() {
    if (closing.current) return;
    closing.current = true;
    setBusy(true);
    // The tags made in the sheet go with it, as the app's Cancel deletes them, one still being
    // made included.
    await making.current;
    for (const tag of madeSoFar.current) {
      try {
        await deleteTag(client, tag.id);
      } catch {
        // One that cannot be deleted stays in Settings ▸ Tags, where it can be.
      }
    }
    dialog.current?.close();
  }

  const title = documentNumber ? copy.tagPicker.titleDoc(documentNumber) : copy.tagPicker.titleId(documentId);
  return (
    <dialog
      ref={dialog}
      className="card tag-picker"
      aria-labelledby={headingId}
      aria-busy={busy}
      onClose={onClose}
      // Escape is Cancel: the sheet closes once the tags made in it are deleted.
      onCancel={(event) => {
        event.preventDefault();
        void cancel();
      }}
      // Escape belongs to the dialog, not to the rail around it.
      onKeyDown={(event) => {
        if (event.key === 'Escape') event.stopPropagation();
      }}
    >
      <h2 id={headingId}>{title}</h2>
      <h3>{copy.tagPicker.newTag}</h3>
      <form
        className="new-tag"
        onSubmit={(event) => {
          event.preventDefault();
          void add();
        }}
      >
        <input
          ref={field}
          type="text"
          value={name}
          placeholder={copy.tagPicker.newTagPlaceholder}
          aria-label={copy.tagPicker.newTagField}
          onChange={(event) => setName(event.target.value)}
        />
        <button type="submit" disabled={name.trim() === '' || busy}>
          {copy.tagPicker.add}
        </button>
      </form>
      <h3>{copy.tagPicker.yourTags}</h3>
      {all.isError && !all.data ? (
        <p className="error" role="alert">
          {errorMessage(all.error)}
        </p>
      ) : !all.data && shown.length === 0 ? (
        <p role="status">{copy.research.loading}</p>
      ) : shown.length === 0 ? (
        <p className="note">{copy.tagPicker.empty}</p>
      ) : (
        <ul className="tag-options">
          {shown.map((tag) => (
            <li key={tag.id}>
              <label>
                <input
                  id={optionId(tag.id)}
                  type="checkbox"
                  checked={selected.has(tag.id)}
                  onChange={(event) => {
                    const next = new Set(selected);
                    if (event.target.checked) next.add(tag.id);
                    else next.delete(tag.id);
                    setSelected(next);
                  }}
                />{' '}
                {tag.name}
                {/* A word, not a colour alone, says why it is first. */}
                {madeIds.has(tag.id) && <Badge>{copy.tagPicker.badgeNew}</Badge>}
              </label>
            </li>
          ))}
        </ul>
      )}
      <p className="visually-hidden" role="status">
        {announcement}
      </p>
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      <div className="actions">
        <button type="button" onClick={() => void cancel()}>
          {copy.tagPicker.cancel}
        </button>
        <button type="button" disabled={busy || !all.data} onClick={() => void done()}>
          {copy.tagPicker.done}
        </button>
      </div>
    </dialog>
  );
}

function optionId(tagId: string): string {
  return `tag-option-${tagId}`;
}
