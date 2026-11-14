// Send to Zotero Library (PLAN's S22e): the row the Mac's Share popover and the app's export sheet give it,
// its button and caption, which sends through the server with the user's own Zotero key, and what came of
// it, said under the row where the app shows its alerts: Sent to Zotero, the app's sentence of what was
// added and View in Zotero, or Couldn't Send to Zotero and why, in the server's words, which are the app's.
// Cite offers it while the user has a Zotero key stored, as the app's menu does while an account is
// connected; the export sheet always, saving the RIS file without one, as the app's sheet does.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useId, useState } from 'react';
import { errorMessage } from '../api/client';
import { sendDocumentToZotero, type ZoteroSent } from '../api/nara';
import { secretsQuery } from '../api/secrets';
import { meQuery } from '../api/userData';
import { copy } from '../copy';

const words = copy.zotero;

/** Whether the user has a Zotero key stored, on a server that keeps user data; undefined until it is known. */
export function useZoteroKey(): boolean | undefined {
  const me = useQuery(meQuery);
  const keeps = me.data?.userData === true;
  const secrets = useQuery({ ...secretsQuery, enabled: keeps });
  if (me.data && !keeps) return false;
  if (!secrets.data) return secrets.isError ? false : undefined;
  return secrets.data.secrets.some((secret) => secret.name === 'zotero' && secret.set);
}

/**
 * The row: Send to Zotero Library and its caption, then the send's result or error. `send` sends, or does
 * what the row does without a key; `message` says what a send added.
 */
export function ZoteroSendRow({
  caption,
  send,
  message,
}: {
  caption: string;
  send: () => Promise<ZoteroSent | null>;
  message: (sent: ZoteroSent) => string;
}) {
  const id = useId();
  const [sending, setSending] = useState(false);
  const [sent, setSent] = useState<ZoteroSent | null>(null);
  const [failure, setFailure] = useState<string | null>(null);

  async function run() {
    if (sending) return;
    setSending(true);
    setSent(null);
    setFailure(null);
    try {
      setSent(await send());
    } catch (error) {
      setFailure(errorMessage(error));
    } finally {
      setSending(false);
    }
  }

  return (
    <div className="zotero-send">
      {/* aria-disabled, not disabled, so a press by keyboard keeps its focus while the send is out. */}
      <button type="button" aria-describedby={`${id}-caption`} aria-disabled={sending} onClick={() => void run()}>
        {words.send}
      </button>
      <p id={`${id}-caption`} className="note">
        {caption}
      </p>
      <div role="status" className="zotero-result">
        {sending ? (
          <p>{words.sending}</p>
        ) : sent ? (
          <p>
            <strong>{words.sentTitle}.</strong> {message(sent)}{' '}
            {sent.webURL && (
              <a href={sent.webURL} target="_blank" rel="noopener noreferrer">
                {words.viewInZotero}
              </a>
            )}
          </p>
        ) : null}
      </div>
      {failure && (
        <p className="error" role="alert">
          <strong>{words.errorTitle}.</strong> {failure}
        </p>
      )}
    </div>
  );
}

/** Cite's row, the Mac popover's: shown while the user has a Zotero key stored; the document alone. */
export function CiteZoteroSend({ volumeId, documentId }: { volumeId: string; documentId: string }) {
  const client = useQueryClient();
  const hasKey = useZoteroKey();
  if (!hasKey) return null;
  return (
    <ZoteroSendRow
      key={`${volumeId}/${documentId}`}
      caption={words.documentCaption}
      send={() => sendDocumentToZotero(client, volumeId, documentId)}
      message={(sent) => words.documentResult(sent.addedItems, sent.addedNotes)}
    />
  );
}
