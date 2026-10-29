// A menu button, the web's way to the app's menus: the collection editor's Add, Sort by Date and a row's
// context menu. The WAI-ARIA menu button: the button opens the menu, its first item focused (the
// last for ArrowUp); the arrow keys, Home and End move between the items, a letter to the next that
// starts with it; Return or Space chooses one; Escape closes it, focus back on the button; and Tab, or
// a press elsewhere, closes it. An item the app disables is aria-disabled, so it is read and passed
// over, and a group is named, as the app's submenu is.
import { type ReactNode, useEffect, useEffectEvent, useId, useRef, useState } from 'react';

export type MenuEntry =
  | { kind: 'item'; label: string; onSelect: () => void; disabled?: boolean; hint?: string; destructive?: boolean }
  | { kind: 'separator' }
  | { kind: 'group'; label: string; items: { label: string; onSelect: () => void; disabled?: boolean; hint?: string }[] };

type Item = { label: string; onSelect: () => void; disabled?: boolean; hint?: string; destructive?: boolean };

export function MenuButton({
  label,
  accessibleLabel,
  entries,
  className,
  children,
}: {
  /** The button's text. */
  label: string;
  /** Its name for assistive technology, when the text is not enough. */
  accessibleLabel?: string;
  entries: MenuEntry[];
  className?: string;
  /** What the button shows, its text by default. */
  children?: ReactNode;
}) {
  const [open, setOpen] = useState<null | 'first' | 'last'>(null);
  const button = useRef<HTMLButtonElement>(null);
  const menu = useRef<HTMLDivElement>(null);
  const items = useRef<(HTMLButtonElement | null)[]>([]);
  const menuId = useId();
  const flat: Item[] = entries.flatMap((entry) =>
    entry.kind === 'item' ? [entry] : entry.kind === 'group' ? entry.items : [],
  );

  // Only the opening places focus; the keys move it after.
  const place = useEffectEvent((where: 'first' | 'last') => items.current[where === 'first' ? 0 : flat.length - 1]?.focus());
  useEffect(() => {
    if (open) place(open);
  }, [open]);

  useEffect(() => {
    if (!open) return;
    function away(event: PointerEvent) {
      const target = event.target as Node;
      if (!menu.current?.contains(target) && !button.current?.contains(target)) setOpen(null);
    }
    document.addEventListener('pointerdown', away, true);
    return () => document.removeEventListener('pointerdown', away, true);
  }, [open]);

  function focusItem(index: number) {
    const count = flat.length;
    items.current[((index % count) + count) % count]?.focus();
  }

  function current(): number {
    return items.current.findIndex((item) => item === document.activeElement);
  }

  function close(returnFocus: boolean) {
    setOpen(null);
    if (returnFocus) button.current?.focus();
  }

  function choose(item: Item) {
    if (item.disabled) return;
    close(true);
    item.onSelect();
  }

  // Each item's place among them all, which the keys move through.
  const places = new Map<Item, number>(flat.map((item, at) => [item, at]));
  function itemButton(item: Item, key: string) {
    const at = places.get(item) ?? 0;
    return (
      <button
        key={key}
        ref={(element) => {
          items.current[at] = element;
        }}
        type="button"
        role="menuitem"
        tabIndex={-1}
        className={item.destructive ? 'destructive' : undefined}
        aria-disabled={item.disabled || undefined}
        title={item.hint}
        onClick={() => choose(item)}
      >
        {item.label}
      </button>
    );
  }

  return (
    <div className={`menu-button ${className ?? ''}`}>
      <button
        ref={button}
        type="button"
        aria-haspopup="menu"
        aria-expanded={open !== null}
        aria-controls={open ? menuId : undefined}
        aria-label={accessibleLabel}
        onClick={() => setOpen(open ? null : 'first')}
        onKeyDown={(event) => {
          if (event.key === 'ArrowDown') {
            event.preventDefault();
            setOpen('first');
          } else if (event.key === 'ArrowUp') {
            event.preventDefault();
            setOpen('last');
          }
        }}
      >
        {children ?? label}
      </button>
      {open && (
        <div
          ref={menu}
          id={menuId}
          role="menu"
          aria-label={accessibleLabel ?? label}
          className="menu"
          onKeyDown={(event) => {
            const at = current();
            if (event.key === 'ArrowDown') {
              event.preventDefault();
              focusItem(at + 1);
            } else if (event.key === 'ArrowUp') {
              event.preventDefault();
              focusItem(at - 1);
            } else if (event.key === 'Home') {
              event.preventDefault();
              focusItem(0);
            } else if (event.key === 'End') {
              event.preventDefault();
              focusItem(flat.length - 1);
            } else if (event.key === 'Escape') {
              event.preventDefault();
              event.stopPropagation();
              close(true);
            } else if (event.key === 'Tab') {
              close(false);
            } else if (event.key.length === 1 && /\S/.test(event.key)) {
              const letter = event.key.toLocaleLowerCase('en-US');
              for (let step = 1; step <= flat.length; step += 1) {
                const next = (at + step) % flat.length;
                if (flat[next]!.label.toLocaleLowerCase('en-US').startsWith(letter)) {
                  focusItem(next);
                  break;
                }
              }
            }
          }}
        >
          {entries.map((entry, n) =>
            entry.kind === 'item' ? (
              itemButton(entry, `item-${n}`)
            ) : entry.kind === 'separator' ? (
              <div key={`separator-${n}`} role="separator" className="menu-separator" />
            ) : (
              <div key={`group-${n}`} role="group" aria-label={entry.label} className="menu-group">
                <p className="menu-group-label" aria-hidden="true">
                  {entry.label}
                </p>
                {entry.items.map((item, m) => itemButton(item, `group-${n}-${m}`))}
              </div>
            ),
          )}
        </div>
      )}
    </div>
  );
}
