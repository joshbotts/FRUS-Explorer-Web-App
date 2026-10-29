// A field that saves as it is typed, as the app's editor commits each field from its binding: the
// newest value goes a moment after the typing stops, or at once when the field is left, and a value
// is sent only after the one before it is answered, so the newest is what the server keeps. A
// refusal is said, and the field keeps what was typed, which the next keystroke or a leave sends
// again.
import { useEffect, useEffectEvent, useRef, useState } from 'react';
import { errorMessage } from '../api/client';

/** How long the typing pauses before the field saves, in milliseconds. */
export const saveDelay = 500;

export function useSaver<T>(save: (value: T) => Promise<unknown>): {
  /** A new value: saved after the pause. */
  change: (value: T) => void;
  /** Saves the value waiting, now: the field was left. */
  flush: () => void;
  /** Whether a value is waiting or being sent. */
  pending: boolean;
  failure: string | null;
} {
  const waiting = useRef<{ value: T } | null>(null);
  const sending = useRef(false);
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const [pending, setPending] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  // The newest save, which a send made after the typing stops calls.
  const latest = useRef(save);
  useEffect(() => {
    latest.current = save;
  });

  async function send() {
    clearTimeout(timer.current);
    if (sending.current || !waiting.current) return;
    const { value } = waiting.current;
    waiting.current = null;
    sending.current = true;
    let refused = false;
    try {
      await latest.current(value);
      setFailure(null);
    } catch (error) {
      refused = true;
      setFailure(errorMessage(error));
      // Kept to be sent again, by the next keystroke, which replaces it, or a leave; never at once.
      waiting.current ??= { value };
    } finally {
      sending.current = false;
      if (waiting.current && !refused) void send();
      // Pending while a value waits, so the field keeps what was typed and not the server's.
      else if (!waiting.current) setPending(false);
    }
  }

  // A field that goes, its row deleted or its dialog closed, sends what it was given.
  const leave = useEffectEvent(() => {
    if (waiting.current) void send();
  });
  useEffect(() => () => leave(), []);

  return {
    change: (value: T) => {
      waiting.current = { value };
      setPending(true);
      clearTimeout(timer.current);
      timer.current = setTimeout(() => void send(), saveDelay);
    },
    flush: () => void send(),
    pending,
    failure,
  };
}
