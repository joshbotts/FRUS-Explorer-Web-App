// The sign-in page of a server with accounts of its own (PLAN's S20b), FRUS_AUTH=local, which the shell
// shows in place of any page until someone signs in: a name and a password, posted to the server, which
// answers with the user and keeps the session in a cookie no script can read. A refusal is said in the
// server's words, which tell a wrong password from a slowed attempt, and the
// password is cleared for another try. Once signed in, the page that was asked for opens, and the shell
// moves focus to its heading.
import { useQueryClient } from '@tanstack/react-query';
import { type FormEvent, useRef, useState } from 'react';
import { signedIn, signIn } from '../api/auth';
import { errorMessage } from '../api/client';
import { copy } from '../copy';
import { useDocumentTitle } from './useDocumentTitle';

export function SignInScreen() {
  useDocumentTitle(copy.signIn.title);
  const queryClient = useQueryClient();
  const [name, setName] = useState('');
  const [password, setPassword] = useState('');
  const [problem, setProblem] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const passwordField = useRef<HTMLInputElement>(null);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy) return;
    setBusy(true);
    setProblem(null);
    try {
      signedIn(queryClient, await signIn(name, password));
    } catch (error) {
      setProblem(errorMessage(error));
      setPassword('');
      setBusy(false);
      passwordField.current?.focus();
    }
  }

  return (
    <section className="screen sign-in">
      <h1 tabIndex={-1}>{copy.signIn.title}</h1>
      <p>{copy.signIn.intro}</p>
      <form className="sign-in-form" onSubmit={(event) => void submit(event)}>
        <label htmlFor="sign-in-name">{copy.signIn.name}</label>
        <input
          id="sign-in-name"
          name="username"
          type="text"
          autoComplete="username"
          autoCapitalize="none"
          spellCheck={false}
          required
          value={name}
          onChange={(event) => setName(event.target.value)}
        />
        <label htmlFor="sign-in-password">{copy.signIn.password}</label>
        <input
          id="sign-in-password"
          ref={passwordField}
          name="password"
          type="password"
          autoComplete="current-password"
          required
          value={password}
          onChange={(event) => setPassword(event.target.value)}
        />
        {problem && (
          <p className="error" role="alert">
            {problem}
          </p>
        )}
        <button type="submit" disabled={busy}>
          {busy ? copy.signIn.signingIn : copy.signIn.submit}
        </button>
      </form>
      <p className="sign-in-help">{copy.signIn.help}</p>
    </section>
  );
}
