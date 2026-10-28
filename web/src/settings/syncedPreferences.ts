// The synced preferences the browser app reads (PLAN's S17f): on a server that keeps user data, the
// user's own, the Mac's `SyncedPreferences`, which follow them to any browser; on one that keeps
// none, this browser's storage, as before S17f. A change shows at once, before the server answers it
// (`updatePreferences`). The citation style the browser kept in its own storage is given to the
// server once, the first time it is read while the server has none. The research panel's last state,
// which Remember Last reopens, stays in this browser, as the Mac keeps it on each device.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useMemo, useSyncExternalStore } from 'react';
import type { CitationStyleName } from '../api/types';
import { pendingPreferenceChanges, preferencesQuery, subscribePendingPreferences, updatePreferences } from '../api/research';
import { meQuery } from '../api/userData';
import { useCitationStyle } from './preferences';

const styles: readonly CitationStyleName[] = ['historyAtState', 'chicago', 'turabian'];

/** The user's synced preferences, with the changes not yet answered, while the server keeps user data. */
export function useSyncedPreferences() {
  const me = useQuery(meQuery);
  const keepsUserData = me.data?.userData === true;
  const preferences = useQuery({ ...preferencesQuery, enabled: keepsUserData });
  const pending = useSyncExternalStore(subscribePendingPreferences, pendingPreferenceChanges);
  const held = keepsUserData ? preferences.data : undefined;
  const shown = useMemo(() => (held ? { ...held, ...pending } : undefined), [held, pending]);
  return { keepsUserData, preferences: shown };
}

/** Log Research Sessions: on until it is turned off, and on wherever nothing is kept to say otherwise. */
export function useLoggingEnabled(): boolean {
  const { preferences } = useSyncedPreferences();
  return preferences?.researchLoggingEnabled ?? true;
}

/** Where this browser notes that the style it kept before S17f has had its one chance to go to the server. */
const styleOfferedKey = 'frus.citationStyle.offered';
let styleOffered = false;

/**
 * Whether this browser's style has had that chance, which it has once for the browser: whoever first
 * reads their preferences here, so no second user, and no import that empties a style, takes it.
 */
function takeStyleOffer(): boolean {
  if (styleOffered) return false;
  styleOffered = true;
  try {
    if (window.localStorage.getItem(styleOfferedKey) === 'true') return false;
    window.localStorage.setItem(styleOfferedKey, 'true');
    return true;
  } catch {
    // Storage that refuses kept no style to give.
    return false;
  }
}

/** Forgets that this page has offered the style, as a new page would, for tests. */
export function resetStyleOffer(): void {
  styleOffered = false;
}

/**
 * Cite's style: the user's synced one, none chosen read as history.state.gov's, as the app reads an
 * unset style; or this browser's while the server keeps no user data, and while the user's are read,
 * so a citation does not open in another style first. The browser keeps the last style chosen here.
 */
export function useCitationStyleSetting(): [CitationStyleName, (style: CitationStyleName) => void] {
  const client = useQueryClient();
  const { keepsUserData, preferences } = useSyncedPreferences();
  const [local, setLocal] = useCitationStyle();
  // The style this browser kept before S17f goes to the server once, while the server has none.
  useEffect(() => {
    if (!preferences || !takeStyleOffer()) return;
    if (preferences.citationStyle === '' && local !== 'historyAtState') {
      void updatePreferences(client, { citationStyle: local }).catch(() => {});
    }
  }, [preferences, local, client]);
  if (!keepsUserData) return [local, setLocal];
  const synced = preferences?.citationStyle;
  const style = !preferences ? local : styles.includes(synced as CitationStyleName) ? (synced as CitationStyleName) : 'historyAtState';
  return [
    style,
    (next) => {
      setLocal(next);
      void updatePreferences(client, { citationStyle: next }).catch(() => {});
    },
  ];
}

export type DocumentMode = 'read' | 'research' | 'rememberLast';

/** The mode a document opens in, Remember Last for none chosen, as the app's default is. */
export function useDocumentMode(): DocumentMode {
  const { preferences } = useSyncedPreferences();
  const mode = preferences?.defaultDocumentMode;
  return mode === 'read' || mode === 'research' ? mode : 'rememberLast';
}

/** Where this browser keeps whether the research panel was last open, as the Mac keeps it on each device. */
const panelKey = 'frus.document.researchPanel.visible';

export function lastPanelVisible(): boolean {
  try {
    return window.localStorage.getItem(panelKey) === 'true';
  } catch {
    return false;
  }
}

export function rememberPanelVisible(visible: boolean): void {
  try {
    window.localStorage.setItem(panelKey, visible ? 'true' : 'false');
  } catch {
    // Storage that refuses keeps nothing: the next document opens as Read.
  }
}

/** The reader's own order of the tag and project lists, by id; none while the server keeps no user data. */
export function useListOrder(): { tagOrder: string[]; projectOrder: string[] } {
  const { preferences } = useSyncedPreferences();
  return { tagOrder: preferences?.tagOrder ?? [], projectOrder: preferences?.projectOrder ?? [] };
}
