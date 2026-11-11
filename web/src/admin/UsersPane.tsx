// Administration ▸ Users (PLAN's S20d): the users the server holds, each with their role, their last
// sign-in and whether the account can sign in. Under local accounts an admin adds an account, chooses a
// role and sets it, disables or enables one after a question, and sets a new password, which signs the
// person out; the server refuses any change that would leave no admin who can sign in, and the pane
// says so. Behind a proxy, or with no sign-in, the list alone. In every mode, Erase Research…, the
// recovery action SPEC names, after a question that names what the user holds, in the export sheet's
// words: the server erases it only while that is still what they hold, and the question counts again
// when it changed. What each change did is said in a status line, and a refusal in an alert, both always
// on the page, so that a screen reader hears each as it comes. Focus goes back after a request only
// while the admin has left it in the place the request came from, or nowhere.
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
import { meQuery, researchImported } from '../api/userData';
import { copy } from '../copy';
import { closeAtOnce, Modal } from '../shell/Modal';
import { AdminFrame, useAdmin } from './AdminPanes';

const words = copy.admin.users;
const roles: Role[] = ['reader', 'curator', 'admin'];

type Feedback = { kind: 'done' | 'failed'; message: string } | null;

/** Moves focus to `target` after a request, only while focus is within `area` or nowhere. */
function focusAfterRequest(area: HTMLElement | null, target: HTMLElement | null | undefined) {
  const active = document.activeElement;
  if (!active || active === document.body || area?.contains(active)) target?.focus();
}

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
        {users.isError && (
          <p className="error" role="alert">
            {errorMessage(users.error)}
          </p>
        )}
        {/* Always on the page, so that each new line is announced as it comes. */}
        <div className="admin-feedback">
          <p role="status">{feedback?.kind === 'done' ? feedback.message : ''}</p>
          <p className="error" role="alert">
            {feedback?.kind === 'failed' ? feedback.message : ''}
          </p>
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
  const [enabling, setEnabling] = useState<string | null>(null);
  const area = useRef<HTMLDivElement>(null);

  async function enable(user: AdminUser) {
    if (enabling) return;
    setEnabling(user.id);
    onFeedback(null);
    try {
      await changeAccount(client, user.id, { disabled: false });
      onFeedback({ kind: 'done', message: words.changed(user.id) });
    } catch (error) {
      onFeedback({ kind: 'failed', message: errorMessage(error) });
    } finally {
      setEnabling(null);
    }
  }

  /** Closes the dialog, and sends focus back to the button `kind` names on the user's row, or else the table's first. */
  function close(kind: string, user: AdminUser) {
    closeAtOnce(() => setDialog(null));
    const opener = area.current?.querySelector<HTMLButtonElement>(`button[data-action="${kind}"][data-user="${CSS.escape(user.id)}"]`);
    (opener ?? area.current?.querySelector<HTMLButtonElement>('button') ?? area.current)?.focus();
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
              <td>{local ? <RoleChoice user={user} onFeedback={onFeedback} /> : words.roles[user.role]}</td>
              <td>{user.lastSignInAt ? copy.admin.time(user.lastSignInAt) : copy.admin.never}</td>
              <td>{user.disabledAt ? words.disabled : user.hasPassword || !local ? words.active : words.noPassword}</td>
              <td>
                <div className="actions">
                  {/* One button, Disable… or Enable, so that focus stays on it as the account changes. */}
                  {local && (
                    <button
                      type="button"
                      data-action="access"
                      data-user={user.id}
                      aria-label={user.disabledAt ? words.enableA11y(user.id) : words.disableA11y(user.id)}
                      aria-disabled={enabling === user.id}
                      onClick={() => (user.disabledAt ? void enable(user) : setDialog({ kind: 'disable', user }))}
                    >
                      {user.disabledAt ? words.enable : words.disable}
                    </button>
                  )}
                  {local && (
                    <button
                      type="button"
                      data-action="password"
                      data-user={user.id}
                      aria-label={words.passwordA11y(user.id)}
                      onClick={() => setDialog({ kind: 'password', user })}
                    >
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
          key={`disable:${dialog.user.id}`}
          user={dialog.user}
          onDone={(message) => {
            onFeedback({ kind: 'done', message });
            close('access', dialog.user);
          }}
          onCancel={() => close('access', dialog.user)}
        />
      )}
      {dialog?.kind === 'password' && (
        <PasswordDialog
          key={`password:${dialog.user.id}`}
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
          key={`erase:${dialog.user.id}`}
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

/**
 * A role chosen in its list and set with Set Role, so that no step through the list sends a change of its
 * own: one request at a time, the list showing the choice while it is sent, and the server's role again
 * once it has answered, whether it took the change or refused it.
 */
function RoleChoice({ user, onFeedback }: { user: AdminUser; onFeedback: (feedback: Feedback) => void }) {
  const client = useQueryClient();
  const [chosen, setChosen] = useState<Role | null>(null);
  const [busy, setBusy] = useState(false);
  const area = useRef<HTMLSpanElement>(null);
  const button = useRef<HTMLButtonElement>(null);
  const shown = chosen ?? user.role;

  async function apply() {
    if (busy || chosen === null || chosen === user.role) return;
    setBusy(true);
    onFeedback(null);
    try {
      await changeAccount(client, user.id, { role: chosen });
      await client.refetchQueries({ queryKey: ['admin', 'users'] });
      onFeedback({ kind: 'done', message: words.changed(user.id) });
    } catch (error) {
      onFeedback({ kind: 'failed', message: errorMessage(error) });
    } finally {
      closeAtOnce(() => {
        setChosen(null);
        setBusy(false);
      });
      focusAfterRequest(area.current, button.current);
    }
  }

  return (
    <span ref={area} className="role-choice">
      <select aria-label={words.roleA11y(user.id)} value={shown} onChange={(event) => setChosen(event.target.value as Role)}>
        {roles.map((role) => (
          <option key={role} value={role}>
            {words.roles[role]}
          </option>
        ))}
      </select>{' '}
      <button
        ref={button}
        type="button"
        aria-label={words.setRoleA11y(user.id)}
        aria-disabled={busy || chosen === null || chosen === user.role}
        onClick={() => void apply()}
      >
        {words.setRole}
      </button>
    </span>
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
    <Modal className="confirm" role="alertdialog" labelledBy={headingId} describedBy={messageId} initial={cancel} onCancel={() => !busy && onCancel()} onClose={onCancel}>
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

/**
 * A new password's two fields, which no browser fills or keeps, read only to send them: a hidden field
 * names whose password it is, so that a browser that offers to save it names that user, never the admin.
 */
function PasswordFields({
  idPrefix,
  owner,
  first,
  second,
  onChange,
}: {
  idPrefix: string;
  owner: string;
  first: { current: HTMLInputElement | null };
  second: { current: HTMLInputElement | null };
  onChange: () => void;
}) {
  return (
    <>
      <input type="text" name="username" autoComplete="username" value={owner} readOnly hidden />
      <label htmlFor={`${idPrefix}-password`}>{words.newPassword}</label>
      <input
        id={`${idPrefix}-password`}
        ref={first}
        type="password"
        autoComplete="new-password"
        aria-describedby={`${idPrefix}-rule`}
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

/**
 * The two fields' password, both fields emptied as it is read, so that nothing of it stays on the page
 * while it is sent; or why there is none to send, the second field emptied to be typed again.
 */
function takePassword(first: HTMLInputElement | null, second: HTMLInputElement | null): { password: string } | { problem: string } {
  const password = first?.value ?? '';
  const again = second?.value ?? '';
  if (second) second.value = '';
  if (password !== again) return { problem: words.mismatch };
  if (first) first.value = '';
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
    const taken = takePassword(first.current, second.current);
    if ('problem' in taken) {
      setFailure(taken.problem);
      second.current?.focus();
      return;
    }
    setBusy(true);
    setFailure(null);
    try {
      await setPassword(client, user.id, taken.password);
      onDone(words.passwordSet(user.id));
    } catch (error) {
      setFailure(errorMessage(error));
      setBusy(false);
      first.current?.focus();
    }
  }

  return (
    <Modal className="confirm admin-dialog" labelledBy={headingId} describedBy={messageId} initial={first} onCancel={() => !busy && onCancel()} onClose={onCancel}>
      <form onSubmit={(event) => void save(event)}>
        <h2 id={headingId} tabIndex={-1}>
          {words.passwordTitle(user.id)}
        </h2>
        <p id={messageId}>{words.passwordMessage}</p>
        <div className="admin-fields">
          <PasswordFields idPrefix={fieldsId} owner={user.id} first={first} second={second} onChange={() => setFailure(null)} />
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
 * wait for the erasure sent; when what they hold changed meanwhile, the server erases nothing, and the
 * dialog counts again, says so, and asks once more, its Erase focused. The admin's own research erased
 * leaves nothing of it in what the app holds of theirs.
 */
function EraseDialog({ user, onDone, onCancel }: { user: AdminUser; onDone: (message: string) => void; onCancel: () => void }) {
  const client = useQueryClient();
  const me = useQuery(meQuery);
  const counted = useQuery({
    queryKey: ['admin', 'holdings', user.id],
    queryFn: ({ signal }) => researchHoldings(user.id, signal),
    staleTime: 0,
    gcTime: 0,
    retry: false,
    refetchOnWindowFocus: false,
  });
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const [changed, setChanged] = useState(false);
  const cancel = useRef<HTMLButtonElement>(null);
  const eraser = useRef<HTMLButtonElement>(null);
  const headingId = useId();
  const messageId = useId();

  async function erase() {
    if (busy || !counted.data || counted.isFetching) return;
    setBusy(true);
    setFailure(null);
    setChanged(false);
    try {
      const erased = await eraseResearch(client, counted.data);
      if (user.id === me.data?.userId) {
        researchImported(client);
        void client.invalidateQueries({ queryKey: ['secrets'] });
      }
      onDone(words.erased(user.id, erased?.total ?? counted.data.total));
    } catch (error) {
      if (error instanceof ApiError && error.code === 'RESEARCH_CHANGED') {
        await counted.refetch();
        closeAtOnce(() => {
          setChanged(true);
          setBusy(false);
        });
        eraser.current?.focus();
      } else {
        setFailure(errorMessage(error));
        setBusy(false);
      }
    }
  }

  const holds = counted.data;
  return (
    <Modal className="confirm admin-dialog" role="alertdialog" labelledBy={headingId} describedBy={messageId} initial={cancel} onCancel={() => !busy && onCancel()} onClose={onCancel}>
      <h2 id={headingId} tabIndex={-1}>
        {words.eraseTitle(user.id)}
      </h2>
      <div id={messageId}>
        {counted.isError ? (
          <p className="error" role="alert">
            {errorMessage(counted.error)}
          </p>
        ) : !holds ? (
          <p role="status">{words.eraseLoading}</p>
        ) : holds.total === 0 ? (
          <p>{words.eraseNothing(user.id)}</p>
        ) : (
          <>
            <p className="error" role="alert">
              {changed ? words.eraseChanged : ''}
            </p>
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
        {holds && holds.total > 0 && (
          <button ref={eraser} type="button" className="destructive" aria-disabled={busy || counted.isFetching} onClick={() => void erase()}>
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
  const area = useRef<HTMLElement>(null);
  const first = useRef<HTMLInputElement>(null);
  const second = useRef<HTMLInputElement>(null);
  const nameField = useRef<HTMLInputElement>(null);
  const headingId = useId();
  const fieldsId = useId();

  async function add(event: FormEvent) {
    event.preventDefault();
    if (busy) return;
    const taken = takePassword(first.current, second.current);
    if ('problem' in taken) {
      setFailure(taken.problem);
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
        password: taken.password,
        ...(displayName.trim() ? { displayName: displayName.trim() } : {}),
      });
      setName('');
      setDisplayName('');
      setRole('reader');
      onFeedback({ kind: 'done', message: words.added(made?.id ?? name.trim()) });
    } catch (error) {
      setFailure(errorMessage(error));
    } finally {
      setBusy(false);
      focusAfterRequest(area.current, nameField.current);
    }
  }

  return (
    <section ref={area} className="admin-add" aria-labelledby={headingId}>
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
          <PasswordFields idPrefix={fieldsId} owner={name.trim()} first={first} second={second} onChange={() => setFailure(null)} />
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
