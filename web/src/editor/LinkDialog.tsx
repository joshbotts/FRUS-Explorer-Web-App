// The link dialog over the note editor (PLAN's S15d), as the app's link popover: Link selection to
// URL, its field filled with the link at the selection's start, Apply, and Remove Link when the
// selection has one; with the iPhone's Cancel, which Escape is. Apply trims the field, and an empty
// one removes the link, as the app's `applyLink` does. Unlike the app's, it makes only a link the
// page can follow, http, https or mailto, and says so of anything else, keeping the dialog open.
import type { Editor } from '@tiptap/core';
import { useId, useRef, useState } from 'react';
import { copy } from '../copy';
import { Modal } from '../shell/Modal';
import { linkAtStart } from './FormattingToolbar';
import { followableLink } from './runs';

export function LinkDialog({ editor, onClose }: { editor: Editor; onClose: () => void }) {
  const headingId = useId();
  const refusalId = useId();
  const field = useRef<HTMLInputElement>(null);
  const [existing] = useState(() => linkAtStart(editor));
  const [url, setUrl] = useState(existing ?? '');
  const [refused, setRefused] = useState(false);

  function remove() {
    editor.chain().unsetLink().run();
    onClose();
  }

  function apply() {
    const trimmed = url.trim();
    if (trimmed === '') {
      remove();
      return;
    }
    const href = followableLink(trimmed);
    if (!href) {
      setRefused(true);
      field.current?.focus();
      return;
    }
    editor.chain().setLink({ href }).run();
    onClose();
  }

  return (
    <Modal className="link-dialog" labelledBy={headingId} initial={field} onCancel={onClose} onClose={() => {}}>
      <h2 id={headingId} tabIndex={-1}>
        {copy.richText.linkTitle}
      </h2>
      <form
        onSubmit={(event) => {
          event.preventDefault();
          apply();
        }}
      >
        {/* A text field, not a URL one, so the browser's own check does not stand in for the sentence below. */}
        <input
          ref={field}
          type="text"
          value={url}
          placeholder={copy.richText.linkPlaceholder}
          aria-labelledby={headingId}
          aria-invalid={refused || undefined}
          aria-describedby={refused ? refusalId : undefined}
          autoComplete="off"
          autoCapitalize="off"
          autoCorrect="off"
          spellCheck={false}
          onChange={(event) => {
            setUrl(event.target.value);
            setRefused(false);
          }}
        />
        {refused && (
          <p id={refusalId} className="error" role="alert">
            {copy.richText.linkRefused}
          </p>
        )}
        <div className="actions">
          {existing !== null && (
            <button type="button" className="destructive" onClick={remove}>
              {copy.richText.linkRemove}
            </button>
          )}
          <button type="button" onClick={onClose}>
            {copy.richText.linkCancel}
          </button>
          <button type="submit">{copy.richText.linkApply}</button>
        </div>
      </form>
    </Modal>
  );
}
