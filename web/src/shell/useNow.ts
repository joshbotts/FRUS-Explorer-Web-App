// The time now, for lines that say how long ago something was: the rail's notes (S15d) and the
// History screen's rows (S17f).
import { useEffect, useState } from 'react';

/** The time now, again every 15 seconds while the rows show times since. */
export function useNow(): number {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const tick = setInterval(() => setNow(Date.now()), 15_000);
    return () => clearInterval(tick);
  }, []);
  return now;
}
