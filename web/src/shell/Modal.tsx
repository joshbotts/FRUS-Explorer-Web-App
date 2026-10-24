// A modal dialog, as the app's sheets and alerts are: open while it is drawn, its first focus where
// it names, Escape its Cancel. The tag editor's, Merge Tag's and the reader's Remove Highlight.
import { type ReactNode, useEffect, useEffectEvent, useRef } from 'react';

/** A modal dialog, open while it is drawn, that focuses `initial` or its heading when it opens. */
export function Modal({
  className,
  role,
  labelledBy,
  describedBy,
  initial,
  onCancel,
  onClose,
  children,
}: {
  className: string;
  role?: 'alertdialog';
  labelledBy: string;
  describedBy?: string;
  initial?: { current: HTMLElement | null };
  onCancel: () => void;
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
      // browser fires cancel after the keydown has gone up through the page.
      onKeyDown={(event) => {
        if (event.key === 'Escape') event.stopPropagation();
      }}
    >
      {children}
    </dialog>
  );
}
