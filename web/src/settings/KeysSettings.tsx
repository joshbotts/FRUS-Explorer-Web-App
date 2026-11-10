// Settings ▸ Keys (PLAN's S20c), the web's own pane for the app's Connections: the user's NARA Catalog key
// and Zotero key, each with whether it is stored, what it is for and where to get one, and Add Key… or
// Replace Key… and Remove Key, as the app's NARA editor has them. A key is typed into a field that
// shows none of it and that the page reads only to send it, once: the key is never held in the page's
// state, the field is emptied as it is sent, whatever the answer, and the server says from then on only
// that it is stored. Removing asks first, as the app does, and while the removal is sent its question
// waits for it, as Delete Note's does. While the instance has a NARA key of its own, an admin's, the
// pane says that it serves the user who has none.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useId, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import { removeSecret, type SecretName, secretsQuery, setSecret } from '../api/secrets';
import { meQuery } from '../api/userData';
import { copy } from '../copy';
import { useHeadingReady } from '../shell/headingFocus';
import { closeAtOnce, Modal } from '../shell/Modal';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import { SettingsPanes } from './SettingsPanes';

/** What each service's section says and links to, in the app's words. */
const services: Record<SecretName, { name: string; about: string; getKey: string; url: string; field: string; fieldA11y: string }> = {
  nara: {
    name: copy.keys.nara,
    about: copy.keys.naraAbout,
    getKey: copy.keys.naraGetKey,
    url: 'https://www.archives.gov/research/catalog/help/api',
    field: copy.keys.naraField,
    fieldA11y: copy.keys.naraFieldA11y,
  },
  zotero: {
    name: copy.keys.zotero,
    about: copy.keys.zoteroAbout,
    getKey: copy.keys.zoteroGetKey,
    // The app's link, which asks for a key with library, notes and write access.
    url: 'https://www.zotero.org/settings/keys/new?name=FRUS%20Explorer&library_access=1&notes_access=1&write_access=1',
    field: copy.keys.zoteroField,
    fieldA11y: copy.keys.zoteroFieldA11y,
  },
};

export function KeysSettingsScreen() {
  const me = useQuery(meQuery);
  const keepsUserData = me.data?.userData === true;
  const secrets = useQuery({ ...secretsQuery, enabled: keepsUserData });
  useDocumentTitle(copy.keys.title);
  useHeadingReady(!me.isPending);

  let body;
  if (me.isError) {
    body = (
      <p className="error" role="alert">
        {errorMessage(me.error)}
      </p>
    );
  } else if (me.data && !keepsUserData) {
    body = <p>{copy.keys.userDataOff}</p>;
  } else if (secrets.isError && !secrets.data) {
    // A list read once stays on the screen when a later reading fails, as when the window regains focus.
    body = (
      <p className="error" role="alert">
        {errorMessage(secrets.error)}
      </p>
    );
  } else if (!secrets.data) {
    body = <p role="status">{copy.keys.loading}</p>;
  } else {
    const instance = secrets.data.instance ?? [];
    body = (
      <>
        <p className="note">{copy.keys.pending}</p>
        {secrets.data.secrets.map((secret) => (
          <KeySection key={secret.name} name={secret.name} stored={secret.set} instanceHasOne={instance.includes(secret.name)} />
        ))}
        <p className="note">{copy.keys.footer}</p>
      </>
    );
  }

  return (
    <div className="settings">
      <SettingsPanes />
      <section className="settings-pane keys-settings">
        <h1 tabIndex={-1} data-loading={me.isPending ? 'true' : undefined}>
          {copy.keys.title}
        </h1>
        {body}
      </section>
    </div>
  );
}

type Feedback = { kind: 'saved' | 'removed' } | { kind: 'failed'; message: string };

/** One service's key: its status, what it is for, and its actions, or the field a new key is typed in. */
function KeySection({ name, stored: listed, instanceHasOne }: { name: SecretName; stored: boolean; instanceHasOne: boolean }) {
  const client = useQueryClient();
  const service = services[name];
  const [editing, setEditing] = useState(false);
  // Whether the field holds anything: the key itself stays in the field.
  const [hasText, setHasText] = useState(false);
  const [busy, setBusy] = useState(false);
  const [confirming, setConfirming] = useState(false);
  const [removeFailure, setRemoveFailure] = useState<string | null>(null);
  const [feedback, setFeedback] = useState<Feedback | null>(null);
  // What this section's last save or removal left, shown at once, while the list still says what it
  // said when it was made; once the list is read again, the list says.
  const [known, setKnown] = useState<{ stored: boolean; over: boolean } | null>(null);
  const stored = known !== null && known.over === listed ? known.stored : listed;
  const headingId = useId();
  const statusId = useId();
  const area = useRef<HTMLElement>(null);
  const field = useRef<HTMLInputElement>(null);
  const opener = useRef<HTMLButtonElement>(null);
  const remover = useRef<HTMLButtonElement>(null);

  // Each change of what is drawn is committed at once, so that focus moves to what is drawn now
  // (shell/Modal.tsx's closeAtOnce); and after a request, only while the reader has left focus in this
  // section or nowhere, so that a slow answer never takes it from where they have gone since.
  function focusAfterRequest(target: HTMLElement | null) {
    const active = document.activeElement;
    if (!active || active === document.body || area.current?.contains(active)) target?.focus();
  }

  function open() {
    closeAtOnce(() => {
      setFeedback(null);
      setHasText(false);
      setEditing(true);
    });
    field.current?.focus();
  }

  function close() {
    if (busy) return;
    closeAtOnce(() => {
      setFeedback(null);
      setHasText(false);
      setEditing(false);
    });
    opener.current?.focus();
  }

  async function save() {
    const input = field.current;
    const key = input?.value.trim() ?? '';
    if (!input || key === '' || busy) return;
    input.value = '';
    setHasText(false);
    setBusy(true);
    setFeedback(null);
    try {
      await setSecret(client, name, key);
      closeAtOnce(() => {
        setBusy(false);
        setKnown({ stored: true, over: listed });
        setEditing(false);
        setFeedback({ kind: 'saved' });
      });
      focusAfterRequest(opener.current);
    } catch (error) {
      closeAtOnce(() => {
        setBusy(false);
        setFeedback({ kind: 'failed', message: errorMessage(error) });
      });
      focusAfterRequest(field.current);
    }
  }

  async function remove() {
    if (busy) return;
    setBusy(true);
    setRemoveFailure(null);
    setFeedback(null);
    try {
      await removeSecret(client, name);
      closeAtOnce(() => {
        setBusy(false);
        setConfirming(false);
        setKnown({ stored: false, over: listed });
        setFeedback({ kind: 'removed' });
      });
      focusAfterRequest(opener.current);
    } catch (error) {
      // The question stays, saying why, as Delete Note's does.
      setRemoveFailure(errorMessage(error));
      setBusy(false);
    }
  }

  const inline =
    feedback === null ? null : feedback.kind === 'failed' ? (
      <p className="error" role="alert">
        {feedback.message}
      </p>
    ) : (
      <p className="key-feedback" role="status">
        {feedback.kind === 'saved' ? copy.keys.saved : copy.keys.removed}
      </p>
    );

  return (
    <section ref={area} className="key-service" aria-labelledby={headingId}>
      <h2 id={headingId}>{service.name}</h2>
      <p id={statusId} className={stored ? 'key-status stored' : 'key-status'}>
        {stored ? copy.keys.stored : copy.keys.notStored}
      </p>
      {!stored && instanceHasOne && <p className="note">{copy.keys.instanceNara}</p>}
      <p className="note">{service.about}</p>
      <p>
        <a href={service.url} target="_blank" rel="noopener noreferrer">
          {service.getKey}
        </a>
      </p>
      {editing ? (
        <form
          className="key-form"
          onSubmit={(event) => {
            event.preventDefault();
            void save();
          }}
          onKeyDown={(event) => {
            if (event.key === 'Escape') {
              event.preventDefault();
              close();
            }
          }}
        >
          {/* Not a password of this site's: no browser offers one to fill it, nor keeps what is typed. */}
          <input
            ref={field}
            type="password"
            aria-label={service.fieldA11y}
            aria-describedby={statusId}
            placeholder={service.field}
            defaultValue=""
            autoComplete="new-password"
            autoCapitalize="off"
            autoCorrect="off"
            spellCheck={false}
            data-1p-ignore="true"
            data-lpignore="true"
            data-bwignore="true"
            onChange={(event) => setHasText(event.target.value.trim() !== '')}
          />
          <div className="actions">
            <button type="submit" disabled={busy || !hasText}>
              {copy.keys.save}
            </button>
            <button type="button" aria-disabled={busy} onClick={close}>
              {copy.keys.cancel}
            </button>
          </div>
          {inline}
        </form>
      ) : (
        <div className="actions">
          <button ref={opener} type="button" onClick={open}>
            {stored ? copy.keys.replace : copy.keys.add}
          </button>
          {stored && (
            <button
              ref={remover}
              type="button"
              className="destructive"
              onClick={() => {
                setRemoveFailure(null);
                setConfirming(true);
              }}
            >
              {copy.keys.remove}
            </button>
          )}
          {inline}
        </div>
      )}
      {confirming && (
        <RemoveConfirmation
          busy={busy}
          failure={removeFailure}
          onRemove={() => void remove()}
          onCancel={() => {
            if (busy) return;
            closeAtOnce(() => setConfirming(false));
            remover.current?.focus();
          }}
        />
      )}
    </section>
  );
}

/** "Remove the stored key?", as the app's confirmation asks it, with Remove and Cancel, which wait for a removal sent. */
function RemoveConfirmation({
  busy,
  failure,
  onRemove,
  onCancel,
}: {
  busy: boolean;
  failure: string | null;
  onRemove: () => void;
  onCancel: () => void;
}) {
  const headingId = useId();
  const messageId = useId();
  const cancel = useRef<HTMLButtonElement>(null);
  return (
    <Modal className="confirm" role="alertdialog" labelledBy={headingId} describedBy={messageId} initial={cancel} onCancel={onCancel} onClose={() => {}}>
      <h2 id={headingId} tabIndex={-1}>
        {copy.keys.removeTitle}
      </h2>
      <p id={messageId}>{copy.keys.removeMessage}</p>
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      <div className="actions">
        <button ref={cancel} type="button" aria-disabled={busy} onClick={onCancel}>
          {copy.keys.cancel}
        </button>
        <button type="button" className="destructive" aria-disabled={busy} onClick={onRemove}>
          {copy.keys.removeConfirm}
        </button>
      </div>
    </Modal>
  );
}
