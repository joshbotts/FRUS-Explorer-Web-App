// A modal dialog, as the app's sheets and alerts are: open while it is drawn, its first focus where
// it names, Escape its Cancel, and its close after a request committed at once. The tag editor's,
// Merge Tag's and the reader's Remove Highlight. A dialog that may stay open on Escape, as the note
// editor does while it asks Discard Changes?, takes the key itself (`onEscape`).
import { type ReactNode, useEffect, useEffectEvent, useRef } from 'react';
import { flushSync } from 'react-dom';

/**
 * A dialog's close once its request has been answered, committed at once. A close from a press or a
 * key is committed before the next frame, where each dialog's parent sends focus back; one after a
 * request would be committed only in a later task, so that frame could find the page around the
 * dialog still inert, and focus would fall to the page's body when the dialog went.
 */
export function closeAtOnce(close: () => void): void {
  flushSync(close);
}

/** A modal dialog, open while it is drawn, that focuses `initial` or its heading when it opens. */
export function Modal({
  className,
  role,
  labelledBy,
  describedBy,
  initial,
  onCancel,
  onEscape,
  onClose,
  children,
}: {
  className: string;
  role?: 'alertdialog';
  labelledBy: string;
  describedBy?: string;
  initial?: { current: HTMLElement | null };
  onCancel: () => void;
  /**
   * Escape pressed in the dialog, in place of `onCancel`: called at the key, which is kept from the
   * browser, so that the dialog stays open while this says. Chrome lets a page refuse a close only once
   * between two of the reader's other inputs, and closes the dialog on a second Escape whatever the
   * page says; a dialog that asks before it closes cannot rely on a refused `cancel`.
   */
  onEscape?: () => void;
  onClose: () => void;
  children: ReactNode;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  const open = useEffectEvent(() => {
    const element = dialog.current;
    if (element && !element.open) element.showModal();
    (initial?.current ?? element?.querySelector<HTMLElement>('h2'))?.focus();
  });
  useEffect(() => open(), []);
  return (
    <dialog
      ref={dialog}
      className={`card ${className}`}
      role={role}
      aria-labelledby={labelledBy}
      aria-describedby={describedBy}
      // A dialog's own close and Escape only: React would hand it another's on their way up.
      onClose={(event) => {
        if (event.target === event.currentTarget) onClose();
      }}
      onCancel={(event) => {
        if (event.target !== event.currentTarget) return;
        event.preventDefault();
        onCancel();
      }}
      // Escape is the dialog's Cancel, not a key for the rail around it, which closes on Escape: the
      // browser fires cancel after the keydown has gone up through the page. One a control in the
      // dialog took for itself, as the formatting editor takes it, or one that ends a composition, is
      // not the dialog's.
      onKeyDown={(event) => {
        if (event.key !== 'Escape') return;
        event.stopPropagation();
        if (onEscape && !event.defaultPrevented && !event.nativeEvent.isComposing) {
          event.preventDefault();
          onEscape();
        }
      }}
    >
      {children}
    </dialog>
  );
}
