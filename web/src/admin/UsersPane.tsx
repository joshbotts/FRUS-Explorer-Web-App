// Administration ▸ Users (PLAN's S20d): the users the server holds, each with their role, their last
// sign-in and whether the account can sign in. Under local accounts an admin adds an account, sets a role,
// disables or enables one after a question, and sets a new password, which signs the person out; the
// server refuses any change that would leave no admin who can sign in, and the pane says so. Behind a
// proxy, or with no sign-in, the list alone. In every mode, Erase Research…, the recovery action SPEC
// names, after a question that names what the user holds, in the export sheet's words: the server erases
// it only while that is still what they hold, and says when it changed.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { type FormEvent, useId, useRef, useState } from 'react';
import {
  addAccount,
  type AdminUser,
  changeAccount,
  eraseResearch,
  type ResearchHoldings,
  researchHoldings,
  type Role,
  setPassword,
  usersQuery,
} from '../api/admin';
import { ApiError, errorMessage } from '../api/client';
import { copy } from '../copy';
import { closeAtOnce, Modal } from '../shell/Modal';
import { AdminFrame, useAdmin } from './AdminPanes';

const words = copy.admin.users;
const roles: Role[] = ['reader', 'curator', 'admin'];

type Feedback = { kind: 'done'; message: string } | { kind: 'failed'; message: string } | null;

export function UsersScreen() {
  const { allowed } = useAdmin();
  const users = useQuery({ ...usersQuery, enabled: allowed });
  const [feedback, setFeedback] = useState<Feedback>(null);
  let body;
  if (users.isError && !users.data) {
    body = (
      <p className="error" role="alert">
        {errorMessage(users.error)}
      </p>
    );
  } else if (!users.data) {
    body = <p role="status">{copy.admin.loading}</p>;
  } else {
    const local = users.data.auth === 'local';
    body = (
      <>
        <p className="note">{words.leads[users.data.auth] ?? words.leads.none}</p>
        <div className="admin-feedback">
          {feedback?.kind === 'failed' ? (
            <p className="error" role="alert">
              {feedback.message}
            </p>
          ) : (
            <p role="status">{feedback?.message ?? ''}</p>
          )}
        </div>
        <UserTable users={users.data.users} local={local} onFeedback={setFeedback} />
        {local && <AddAccount onFeedback={setFeedback} />}
      </>
    );
  }
  return <AdminFrame title={words.title}>{body}</AdminFrame>;
}

type Dialog = { kind: 'disable' | 'password' | 'erase'; user: AdminUser } | null;

function UserTable({ users, local, onFeedback }: { users: AdminUser[]; local: boolean; onFeedback: (feedback: Feedback) => void }) {
  const client = useQueryClient();
  const [dialog, setDialog] = useState<Dialog>(null);
  const area = useRef<HTMLDivElement>(null);

  async function apply(user: AdminUser, fields: { role?: Role; disabled?: boolean }) {
    onFeedback(null);
    try {
      await changeAccount(client, user.id, fields);
      onFeedback({ kind: 'done', message: words.changed(user.id) });
    } catch (error) {
      onFeedback({ kind: 'failed', message: errorMessage(error) });
      // What the server holds is shown again, the refused choice with it.
      void client.invalidateQueries({ queryKey: ['admin', 'users'] });
    }
  }

  /** Closes the dialog, and sends focus back to the button that opened it. */
  function close(kind: string, user: AdminUser) {
    closeAtOnce(() => setDialog(null));
    const opener = area.current?.querySelector<HTMLButtonElement>(`button[data-action="${kind}"][data-user="${CSS.escape(user.id)}"]`);
    (opener ?? area.current?.querySelector<HTMLButtonElement>('button'))?.focus();
  }

  return (
    // A region a keyboard can scroll, where the table is wider than the pane.
    <div ref={area} className="admin-table" role="region" aria-label={words.caption} tabIndex={0}>
      <table>
        <caption>{words.caption}</caption>
        <thead>
          <tr>
            <th scope="col">{words.name}</th>
            <th scope="col">{words.displayName}</th>
            <th scope="col">{words.role}</th>
            <th scope="col">{words.lastSignIn}</th>
            <th scope="col">{words.account}</th>
            <th scope="col">{words.actions}</th>
          </tr>
        </thead>
        <tbody>
          {users.map((user) => (
            <tr key={user.id} data-user={user.id}>
              <th scope="row">{user.id}</th>
              <td>{user.displayName}</td>
              <td>
                {local ? (
                  <select aria-label={words.roleA11y(user.id)} value={user.role} onChange={(event) => void apply(user, { role: event.target.value as Role })}>
                    {roles.map((role) => (
                      <option key={role} value={role}>
                        {words.roles[role]}
                      </option>
                    ))}
                  </select>
                ) : (
                  words.roles[user.role]
                )}
              </td>
              <td>{user.lastSignInAt ? copy.admin.time(user.lastSignInAt) : copy.admin.never}</td>
              <td>{user.disabledAt ? words.disabled : user.hasPassword || !local ? words.active : words.noPassword}</td>
              <td>
                <div className="actions">
                  {local &&
                    (user.disabledAt ? (
                      <button type="button" data-action="enable" data-user={user.id} aria-label={words.enableA11y(user.id)} onClick={() => void apply(user, { disabled: false })}>
                        {words.enable}
                      </button>
                    ) : (
                      <button type="button" data-action="disable" data-user={user.id} aria-label={words.disableA11y(user.id)} onClick={() => setDialog({ kind: 'disable', user })}>
                        {words.disable}
                      </button>
                    ))}
                  {local && (
                    <button type="button" data-action="password" data-user={user.id} aria-label={words.passwordA11y(user.id)} onClick={() => setDialog({ kind: 'password', user })}>
                      {words.password}
                    </button>
                  )}
                  <button
                    type="button"
                    className="destructive"
                    data-action="erase"
                    data-user={user.id}
                    aria-label={words.eraseA11y(user.id)}
                    onClick={() => setDialog({ kind: 'erase', user })}
                  >
                    {words.erase}
                  </button>
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      {dialog?.kind === 'disable' && (
        <DisableConfirmation
          user={dialog.user}
          onDone={(message) => {
            onFeedback({ kind: 'done', message });
            close('disable', dialog.user);
          }}
          onCancel={() => close('disable', dialog.user)}
        />
      )}
      {dialog?.kind === 'password' && (
        <PasswordDialog
          user={dialog.user}
          onDone={(message) => {
            onFeedback({ kind: 'done', message });
            close('password', dialog.user);
          }}
          onCancel={() => close('password', dialog.user)}
        />
      )}
      {dialog?.kind === 'erase' && (
        <EraseDialog
          user={dialog.user}
          onDone={(message) => {
            onFeedback({ kind: 'done', message });
            close('erase', dialog.user);
          }}
          onCancel={() => close('erase', dialog.user)}
        />
      )}
    </div>
  );
}

/** "Disable bob?", with Disable and Cancel, which wait for the change sent. */
function DisableConfirmation({ user, onDone, onCancel }: { user: AdminUser; onDone: (message: string) => void; onCancel: () => void }) {
  const client = useQueryClient();
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const cancel = useRef<HTMLButtonElement>(null);
  const headingId = useId();
  const messageId = useId();

  async function disable() {
    if (busy) return;
    setBusy(true);
    setFailure(null);
    try {
      await changeAccount(client, user.id, { disabled: true });
      setBusy(false);
      onDone(words.changed(user.id));
    } catch (error) {
      setFailure(errorMessage(error));
      setBusy(false);
    }
  }

  return (
    <Modal className="confirm" role="alertdialog" labelledBy={headingId} describedBy={messageId} initial={cancel} onCancel={() => !busy && onCancel()} onClose={() => {}}>
      <h2 id={headingId} tabIndex={-1}>
        {words.disableTitle(user.id)}
      </h2>
      <p id={messageId}>{words.disableMessage}</p>
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      <div className="actions">
        <button ref={cancel} type="button" aria-disabled={busy} onClick={() => !busy && onCancel()}>
          {copy.admin.cancel}
        </button>
        <button type="button" className="destructive" aria-disabled={busy} onClick={() => void disable()}>
          {words.disableConfirm}
        </button>
      </div>
    </Modal>
  );
}

/** A new password's two fields, which no browser fills or keeps, read only to send them. */
function PasswordFields({ idPrefix, first, second, onChange }: {
  idPrefix: string;
  first: { current: HTMLInputElement | null };
  second: { current: HTMLInputElement | null };
  onChange: () => void;
}) {
  return (
    <>
      <label htmlFor={`${idPrefix}-password`}>{words.newPassword}</label>
      <input
        id={`${idPrefix}-password`}
        ref={first}
        type="password"
        autoComplete="new-password"
        aria-describedby={`${idPrefix}-rule`}
        minLength={15}
        required
        data-1p-ignore="true"
        data-lpignore="true"
        data-bwignore="true"
        onChange={onChange}
      />
      <label htmlFor={`${idPrefix}-again`}>{words.confirmPassword}</label>
      <input
        id={`${idPrefix}-again`}
        ref={second}
        type="password"
        autoComplete="new-password"
        required
        data-1p-ignore="true"
        data-lpignore="true"
        data-bwignore="true"
        onChange={onChange}
      />
      <p id={`${idPrefix}-rule`} className="note">
        {words.passwordRule}
      </p>
    </>
  );
}

/** The two fields' password, or why there is none to send, the second field emptied to be typed again. */
function chosenPassword(first: HTMLInputElement | null, second: HTMLInputElement | null): { password: string } | { problem: string } {
  const password = first?.value ?? '';
  if (password !== (second?.value ?? '')) {
    if (second) second.value = '';
    return { problem: words.mismatch };
  }
  return { password };
}

function PasswordDialog({ user, onDone, onCancel }: { user: AdminUser; onDone: (message: string) => void; onCancel: () => void }) {
  const client = useQueryClient();
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const first = useRef<HTMLInputElement>(null);
  const second = useRef<HTMLInputElement>(null);
  const headingId = useId();
  const messageId = useId();
  const fieldsId = useId();

  async function save(event: FormEvent) {
    event.preventDefault();
    if (busy) return;
    const chosen = chosenPassword(first.current, second.current);
    if ('problem' in chosen) {
      setFailure(chosen.problem);
      second.current?.focus();
      return;
    }
    setBusy(true);
    setFailure(null);
    try {
      await setPassword(client, user.id, chosen.password);
      onDone(words.passwordSet(user.id));
    } catch (error) {
      setFailure(errorMessage(error));
      setBusy(false);
      first.current?.focus();
    } finally {
      if (first.current) first.current.value = '';
      if (second.current) second.current.value = '';
    }
  }

  return (
    <Modal className="confirm admin-dialog" labelledBy={headingId} describedBy={messageId} initial={first} onCancel={() => !busy && onCancel()} onClose={() => {}}>
      <form onSubmit={(event) => void save(event)}>
        <h2 id={headingId} tabIndex={-1}>
          {words.passwordTitle(user.id)}
        </h2>
        <p id={messageId}>{words.passwordMessage}</p>
        <div className="admin-fields">
          <PasswordFields idPrefix={fieldsId} first={first} second={second} onChange={() => setFailure(null)} />
        </div>
        {failure && (
          <p className="error" role="alert">
            {failure}
          </p>
        )}
        <div className="actions">
          <button type="button" aria-disabled={busy} onClick={() => !busy && onCancel()}>
            {copy.admin.cancel}
          </button>
          <button type="submit" aria-disabled={busy}>
            {words.passwordSave}
          </button>
        </div>
      </form>
    </Modal>
  );
}

/** The non-empty holdings, in the export sheet's words. */
function holdingLines(holdings: ResearchHoldings): string[] {
  const names: Record<string, string> = { ...copy.dataSettings.types, StoredKey: words.storedKeys };
  return holdings.holdings.filter((holding) => holding.count > 0).map((holding) => words.holding(holding.count, names[holding.type] ?? holding.type));
}

/**
 * "Erase the research of bob?": what they hold, counted as the dialog opens, then Erase and Cancel, which
 * wait for the erasure sent; when what they hold changed meanwhile, the server erases nothing and the
 * dialog counts again, and asks once more.
 */
function EraseDialog({ user, onDone, onCancel }: { user: AdminUser; onDone: (message: string) => void; onCancel: () => void }) {
  const client = useQueryClient();
  const counted = useQuery({
    queryKey: ['admin', 'holdings', user.id],
    queryFn: ({ signal }) => researchHoldings(user.id, signal),
    staleTime: 0,
    gcTime: 0,
    retry: false,
  });
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const [changed, setChanged] = useState(false);
  const cancel = useRef<HTMLButtonElement>(null);
  const headingId = useId();
  const messageId = useId();

  async function erase() {
    if (busy || !counted.data) return;
    setBusy(true);
    setFailure(null);
    setChanged(false);
    try {
      const erased = await eraseResearch(client, counted.data);
      onDone(words.erased(user.id, erased?.total ?? counted.data.total));
    } catch (error) {
      if (error instanceof ApiError && error.code === 'RESEARCH_CHANGED') {
        setChanged(true);
        await counted.refetch();
      } else {
        setFailure(errorMessage(error));
      }
      setBusy(false);
    }
  }

  const holds = counted.data;
  return (
    <Modal className="confirm admin-dialog" role="alertdialog" labelledBy={headingId} describedBy={messageId} initial={cancel} onCancel={() => !busy && onCancel()} onClose={() => {}}>
      <h2 id={headingId} tabIndex={-1}>
        {words.eraseTitle(user.id)}
      </h2>
      <div id={messageId}>
        {counted.isError ? (
          <p className="error" role="alert">
            {errorMessage(counted.error)}
          </p>
        ) : !holds || counted.isFetching ? (
          <p role="status">{words.eraseLoading}</p>
        ) : holds.total === 0 ? (
          <p>{words.eraseNothing(user.id)}</p>
        ) : (
          <>
            {changed && (
              <p className="error" role="alert">
                {words.eraseChanged}
              </p>
            )}
            <p>{words.eraseHolds(user.id)}</p>
            <ul className="erase-holdings">
              {holdingLines(holds).map((line) => (
                <li key={line}>{line}</li>
              ))}
            </ul>
            <p>{words.eraseMessage}</p>
          </>
        )}
      </div>
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      <div className="actions">
        <button ref={cancel} type="button" aria-disabled={busy} onClick={() => !busy && onCancel()}>
          {copy.admin.cancel}
        </button>
        {holds && holds.total > 0 && !counted.isFetching && (
          <button type="button" className="destructive" aria-disabled={busy} onClick={() => void erase()}>
            {words.eraseConfirm}
          </button>
        )}
      </div>
    </Modal>
  );
}

/** Add an Account: a name, a display name, a role and the first password, which the admin gives the person. */
function AddAccount({ onFeedback }: { onFeedback: (feedback: Feedback) => void }) {
  const client = useQueryClient();
  const [name, setName] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [role, setRole] = useState<Role>('reader');
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const first = useRef<HTMLInputElement>(null);
  const second = useRef<HTMLInputElement>(null);
  const nameField = useRef<HTMLInputElement>(null);
  const headingId = useId();
  const fieldsId = useId();

  async function add(event: FormEvent) {
    event.preventDefault();
    if (busy) return;
    const chosen = chosenPassword(first.current, second.current);
    if ('problem' in chosen) {
      setFailure(chosen.problem);
      second.current?.focus();
      return;
    }
    setBusy(true);
    setFailure(null);
    onFeedback(null);
    try {
      const made = await addAccount(client, {
        name: name.trim(),
        role,
        password: chosen.password,
        ...(displayName.trim() ? { displayName: displayName.trim() } : {}),
      });
      setName('');
      setDisplayName('');
      setRole('reader');
      onFeedback({ kind: 'done', message: words.added(made?.id ?? name.trim()) });
      nameField.current?.focus();
    } catch (error) {
      setFailure(errorMessage(error));
      nameField.current?.focus();
    } finally {
      if (first.current) first.current.value = '';
      if (second.current) second.current.value = '';
      setBusy(false);
    }
  }

  return (
    <section className="admin-add" aria-labelledby={headingId}>
      <h2 id={headingId}>{words.add}</h2>
      <form onSubmit={(event) => void add(event)}>
        <div className="admin-fields">
          <label htmlFor={`${fieldsId}-name`}>{words.addName}</label>
          <input
            id={`${fieldsId}-name`}
            ref={nameField}
            value={name}
            required
            autoComplete="off"
            autoCapitalize="off"
            spellCheck={false}
            onChange={(event) => setName(event.target.value)}
          />
          <label htmlFor={`${fieldsId}-display`}>{words.addDisplayName}</label>
          <input id={`${fieldsId}-display`} value={displayName} autoComplete="off" onChange={(event) => setDisplayName(event.target.value)} />
          <label htmlFor={`${fieldsId}-role`}>{words.addRole}</label>
          <select id={`${fieldsId}-role`} value={role} onChange={(event) => setRole(event.target.value as Role)}>
            {roles.map((choice) => (
              <option key={choice} value={choice}>
                {words.roles[choice]}
              </option>
            ))}
          </select>
          <PasswordFields idPrefix={fieldsId} first={first} second={second} onChange={() => setFailure(null)} />
        </div>
        {failure && (
          <p className="error" role="alert">
            {failure}
          </p>
        )}
        <div className="actions">
          <button type="submit" aria-disabled={busy}>
            {words.addAction}
          </button>
        </div>
      </form>
    </section>
  );
}
