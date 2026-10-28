// Settings ▸ Reading (PLAN's S17f), the web's own pane for two of the app's synced settings, in the
// words of its Display pane: Open Documents In, with Read, Research and Remember Last, and Citation
// Style, the style Cite opens with. On a server that keeps user data they are the user's, wherever they
// read; on one that keeps none, the citation style is this browser's.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useId, useState } from 'react';
import { errorMessage } from '../api/client';
import { updatePreferences } from '../api/research';
import type { CitationStyleName } from '../api/types';
import { meQuery } from '../api/userData';
import { copy } from '../copy';
import { useHeadingReady } from '../shell/headingFocus';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import { SettingsPanes } from './SettingsPanes';
import { type DocumentMode, useCitationStyleSetting, useDocumentMode, useSyncedPreferences } from './syncedPreferences';

const modes: DocumentMode[] = ['read', 'research', 'rememberLast'];
const styles: CitationStyleName[] = ['historyAtState', 'chicago', 'turabian'];

export function ReadingSettingsScreen() {
  const client = useQueryClient();
  const me = useQuery(meQuery);
  const { keepsUserData } = useSyncedPreferences();
  const mode = useDocumentMode();
  const [style, setStyle] = useCitationStyleSetting();
  const [failure, setFailure] = useState<string | null>(null);
  const readingId = useId();
  const citationsId = useId();
  const modeFooter = useId();
  const styleFooter = useId();
  useDocumentTitle(copy.reading.title);
  useHeadingReady(!me.isPending);

  return (
    <div className="settings">
      <SettingsPanes />
      <section className="settings-pane">
        <h1 tabIndex={-1} data-loading={me.isPending ? 'true' : undefined}>
          {copy.reading.title}
        </h1>
        {keepsUserData && (
          <section aria-labelledby={readingId}>
            <h2 id={readingId}>{copy.reading.title}</h2>
            <label>
              {copy.reading.openIn}{' '}
              <select
                value={mode}
                aria-describedby={modeFooter}
                onChange={(event) => {
                  setFailure(null);
                  void updatePreferences(client, { defaultDocumentMode: event.target.value }).catch((error: unknown) =>
                    setFailure(errorMessage(error)),
                  );
                }}
              >
                {modes.map((value) => (
                  <option key={value} value={value}>
                    {copy.reading.modes[value]}
                  </option>
                ))}
              </select>
            </label>
            <p id={modeFooter} className="note">
              {copy.reading.footer}
            </p>
          </section>
        )}
        <section aria-labelledby={citationsId}>
          <h2 id={citationsId}>{copy.reading.citations}</h2>
          <label>
            {copy.reading.citationStyle}{' '}
            <select value={style} aria-describedby={styleFooter} onChange={(event) => setStyle(event.target.value as CitationStyleName)}>
              {styles.map((value) => (
                <option key={value} value={value}>
                  {copy.reading.styles[value]}
                </option>
              ))}
            </select>
          </label>
          <p id={styleFooter} className="note">
            {copy.reading.citationFooter}
          </p>
        </section>
        {failure && (
          <p className="error" role="alert">
            {failure}
          </p>
        )}
      </section>
    </div>
  );
}
