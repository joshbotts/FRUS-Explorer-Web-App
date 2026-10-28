// Settings ▸ Research Sessions and its Session Log (PLAN's S17f), as the app's `ResearchSessionsView`
// and `SessionLogView` lay them out: Recording, Log Research Sessions with what it covers; Recorded
// Activity, the Session Log with the summary of what it holds; and Manage, Delete Recorded Sessions…,
// which asks first, naming every event it deletes. The Session Log is the kit's sessions, newest
// first, each its date, its start, its length or Ongoing and its events, opened to its activities.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Link } from '@tanstack/react-router';
import { useEffect, useEffectEvent, useId, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import { deleteTrail, type SessionActivity, type SessionLog, sessionLogIncrement, sessionLogLimit, sessionLogQuery, updatePreferences } from '../api/research';
import { meQuery } from '../api/userData';
import { copy } from '../copy';
import { useHeadingReady } from '../shell/headingFocus';
import { Modal } from '../shell/Modal';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import { SettingsPanes } from './SettingsPanes';
import { useLoggingEnabled, useSyncedPreferences } from './syncedPreferences';

const time = (iso: string) => new Date(iso).toLocaleTimeString('en-US', { timeStyle: 'short' });
const longDate = (iso: string) => new Date(iso).toLocaleDateString('en-US', { dateStyle: 'long' });

/** "12 sessions · 340 events · last today 3:04 PM", or "Nothing recorded yet" (`ResearchSessionsSummary.text`). */
export function summaryText(summary: SessionLog['summary'], now: Date = new Date()): string {
  if (summary.eventCount === 0) return copy.sessions.nothingRecorded;
  const parts = [copy.sessions.sessionCount(summary.sessionCount, summary.isSessionCountExact), copy.sessions.eventCount(summary.eventCount)];
  if (summary.lastSessionStart) {
    const last = new Date(summary.lastSessionStart);
    parts.push(
      last.toDateString() === now.toDateString()
        ? copy.sessions.lastToday(time(summary.lastSessionStart))
        : copy.sessions.lastOlder(last.toLocaleDateString('en-US', { dateStyle: 'medium' })),
    );
  }
  return parts.join(' · ');
}

export function SessionsSettingsScreen() {
  const client = useQueryClient();
  const me = useQuery(meQuery);
  const { keepsUserData, preferences } = useSyncedPreferences();
  const logging = useLoggingEnabled();
  const log = useQuery({ ...sessionLogQuery(sessionLogLimit), enabled: keepsUserData });
  const heading = useRef<HTMLHeadingElement>(null);
  const deleteButton = useRef<HTMLButtonElement>(null);
  const [confirming, setConfirming] = useState(false);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const recordingId = useId();
  const activityId = useId();
  const manageId = useId();
  const afterConfirmation = useRef<'return' | 'heading' | null>(null);
  useDocumentTitle(copy.sessions.title);
  useHeadingReady(!me.isPending);

  const confirmationGone = useEffectEvent(() => {
    const next = afterConfirmation.current;
    afterConfirmation.current = null;
    if (next === 'return') deleteButton.current?.focus();
    else if (next === 'heading') heading.current?.focus();
  });
  useEffect(() => {
    if (!confirming) confirmationGone();
  }, [confirming]);

  async function remove() {
    setBusy(true);
    setFailure(null);
    try {
      await deleteTrail(client);
      // Delete Recorded Sessions… is dimmed with nothing left to delete, so the focus goes to the heading.
      afterConfirmation.current = 'heading';
    } catch (error) {
      setFailure(errorMessage(error));
      afterConfirmation.current = 'return';
    }
    setBusy(false);
    setConfirming(false);
  }

  const summary = log.data?.summary;
  let body;
  if (me.data && !keepsUserData) {
    body = <p>{copy.settings.userDataOff}</p>;
  } else if (!preferences || !summary) {
    body = log.isError ? (
      <p className="error" role="alert">
        {errorMessage(log.error)}
      </p>
    ) : (
      <p role="status">{copy.sessions.loading}</p>
    );
  } else {
    body = (
      <>
        <section aria-labelledby={recordingId}>
          <h2 id={recordingId}>{copy.sessions.recording}</h2>
          <label className="switch">
            <input
              type="checkbox"
              role="switch"
              checked={logging}
              onChange={(event) => {
                const on = event.target.checked;
                setFailure(null);
                void updatePreferences(client, { researchLoggingEnabled: on }).catch((error: unknown) => setFailure(errorMessage(error)));
              }}
            />{' '}
            {copy.sessions.logging}
          </label>
          <p className="note">{copy.sessions.loggingFooter}</p>
        </section>
        <section aria-labelledby={activityId}>
          <h2 id={activityId}>{copy.sessions.activity}</h2>
          <ul className="settings-list">
            <li>
              <Link to="/settings/sessions/log" className="settings-row">
                <span className="row-text">
                  {copy.sessions.log}
                  <span className="detail">{summaryText(summary)}</span>
                </span>
                <span aria-hidden="true">›</span>
              </Link>
            </li>
          </ul>
          <p className="note">{summary.eventCount === 0 ? copy.sessions.activityEmpty : copy.sessions.activityFooter}</p>
        </section>
        <section aria-labelledby={manageId}>
          <h2 id={manageId}>{copy.sessions.manage}</h2>
          <button
            ref={deleteButton}
            type="button"
            className="destructive"
            aria-haspopup="dialog"
            disabled={summary.eventCount === 0 || busy}
            onClick={() => setConfirming(true)}
          >
            {copy.sessions.deleteAll}
          </button>
          <p className="note">{copy.sessions.manageFooter}</p>
        </section>
        {failure && (
          <p className="error" role="alert">
            {failure}
          </p>
        )}
      </>
    );
  }

  return (
    <div className="settings">
      <SettingsPanes />
      <section className="settings-pane">
        <h1 ref={heading} tabIndex={-1} data-loading={me.isPending ? 'true' : undefined}>
          {copy.sessions.title}
        </h1>
        {body}
      </section>
      {confirming && summary && (
        <DeleteTrailConfirmation
          events={summary.eventCount}
          busy={busy}
          onDelete={() => void remove()}
          onCancel={() => {
            afterConfirmation.current = 'return';
            setConfirming(false);
          }}
        />
      )}
    </div>
  );
}

function DeleteTrailConfirmation({
  events,
  busy,
  onDelete,
  onCancel,
}: {
  events: number;
  busy: boolean;
  onDelete: () => void;
  onCancel: () => void;
}) {
  const headingId = useId();
  const messageId = useId();
  const cancel = useRef<HTMLButtonElement>(null);
  return (
    <Modal className="confirm" role="alertdialog" labelledBy={headingId} describedBy={messageId} initial={cancel} onCancel={onCancel} onClose={() => {}}>
      <h2 id={headingId} tabIndex={-1}>
        {copy.sessions.deleteTitle}
      </h2>
      <p id={messageId}>{copy.sessions.deleteMessage(copy.sessions.eventCount(events))}</p>
      <div className="actions">
        <button ref={cancel} type="button" onClick={onCancel}>
          {copy.sessions.deleteCancel}
        </button>
        <button type="button" className="destructive" disabled={busy} onClick={onDelete}>
          {copy.sessions.deleteConfirm}
        </button>
      </div>
    </Modal>
  );
}

/** A session's length, as the app's row gives it: Ongoing, or seconds, minutes, or hours and minutes. */
export function sessionLength(session: SessionLog['sessions'][number]): string {
  if (session.isOngoing) return copy.sessions.ongoing;
  const interval = session.duration;
  if (interval < 60) return `${Math.floor(interval)}s`;
  if (interval < 3_600) return `${Math.floor(interval / 60)}m`;
  return `${Math.floor(interval / 3_600)}h ${Math.floor((interval % 3_600) / 60)}m`;
}

/** What an activity's row says (`SessionActivityRowView.descriptionText`). */
export function activityText(activity: SessionActivity): string {
  switch (activity.kind) {
    case 'documentOpen':
      return activity.displayTitle ? activity.displayTitle : `${activity.volumeId} · ${activity.documentId}`;
    case 'search':
      return copy.sessions.searchLine(activity.query ?? '', copy.sessions.results(activity.resultCount ?? 0));
    case 'export':
      return copy.sessions.exportLine(activity.collectionName ?? activity.format ?? '', copy.sessions.documents(activity.documentCount ?? 0));
  }
}

export function SessionLogScreen() {
  const { keepsUserData } = useSyncedPreferences();
  const me = useQuery(meQuery);
  const [limit, setLimit] = useState(sessionLogLimit);
  const log = useQuery({ ...sessionLogQuery(limit), enabled: keepsUserData });
  useDocumentTitle(copy.sessions.log);
  useHeadingReady(!me.isPending && (!keepsUserData || !log.isPending));
  const data = log.data;

  let body;
  if (me.data && !keepsUserData) {
    body = <p>{copy.settings.userDataOff}</p>;
  } else if (log.isError) {
    body = (
      <p className="error" role="alert">
        {errorMessage(log.error)}
      </p>
    );
  } else if (!data) {
    body = <p role="status">{copy.sessions.loading}</p>;
  } else if (data.totalActivities === 0) {
    body = (
      <p className="empty">
        <strong>{copy.sessions.emptyTitle}</strong> {copy.sessions.emptyDetail}
      </p>
    );
  } else {
    body = (
      <>
        <ul className="session-log">
          {data.sessions.map((session) => (
            <li key={session.id}>
              <details>
                <summary>
                  <span className="session-date">{longDate(session.startedAt)}</span>{' '}
                  <span className="caption">
                    {[time(session.startedAt), sessionLength(session), copy.sessions.eventCount(session.activityCount)].join(' · ')}
                  </span>
                </summary>
                <ul>
                  {session.activities.map((activity) => (
                    <li key={activity.id}>
                      {activityText(activity)} <span className="caption">{time(activity.timestamp)}</span>
                    </li>
                  ))}
                </ul>
              </details>
            </li>
          ))}
        </ul>
        {data.hasMore && (
          <>
            <button type="button" onClick={() => setLimit((current) => current + sessionLogIncrement)}>
              {copy.sessions.showMore}
            </button>
            <p className="note">{copy.sessions.showingRecent(data.loadedActivities, data.totalActivities)}</p>
            <p className="note">{copy.sessions.oldestPartial}</p>
          </>
        )}
      </>
    );
  }

  return (
    <div className="settings">
      <SettingsPanes />
      <section className="settings-pane">
        <p className="back">
          <Link to="/settings/sessions">{copy.sessions.title}</Link>
        </p>
        <h1 tabIndex={-1} data-loading={me.isPending ? 'true' : undefined}>
          {copy.sessions.log}
        </h1>
        {body}
      </section>
    </div>
  );
}
