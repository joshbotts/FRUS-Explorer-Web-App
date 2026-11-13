// Administration ▸ Library's Keeping Current and After an Update (PLAN's S21f): Check for Corrections, which lists
// the downloaded volumes GitHub's listing names another file for, by the kit's rule, each with Update, the app's
// Keeping Current; and the tallies of what the updates changed, by volume, the kit's `VolumeUpdateReview` over
// every user's research, with an Import server's comparison of its index with the TEI folder.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useId, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import { downloadVolumes } from '../api/library';
import { adminUpdatesQuery, checkForCorrections, type Corrections } from '../api/reviews';
import { copy } from '../copy';

const words = copy.admin.library;

/** Check for Corrections and Update, on a Standalone server that downloads. */
export function KeepingCurrent() {
  const client = useQueryClient();
  const [checking, setChecking] = useState(false);
  const [found, setFound] = useState<Corrections | null>(null);
  const [updating, setUpdating] = useState<string | null>(null);
  const [said, setSaid] = useState('');
  const [failure, setFailure] = useState<string | null>(null);
  const headingId = useId();
  const checkButton = useRef<HTMLButtonElement>(null);

  async function check() {
    if (checking) return;
    setChecking(true);
    setFailure(null);
    setSaid('');
    try {
      const answer = await checkForCorrections(client);
      setFound(answer);
      setSaid(answer.volumes.length === 0 ? words.upToDate : words.changedUpstream(answer.volumes.length));
    } catch (error) {
      setFailure(errorMessage(error));
    } finally {
      setChecking(false);
    }
  }

  async function update(volumeIds: string[], key: string) {
    if (updating) return;
    setUpdating(key);
    setFailure(null);
    setSaid('');
    try {
      const job = await downloadVolumes(client, { volumeIds });
      setSaid(words.updateQueued(job?.subject ?? volumeIds.join(', ')));
      // Those asked for leave the list, which a check later finds up to date, and focus goes on to the check, where
      // the row's Update was.
      setFound((current) => current && { ...current, volumes: current.volumes.filter((volume) => !volumeIds.includes(volume.volumeId)) });
      requestAnimationFrame(() => checkButton.current?.focus());
    } catch (error) {
      setFailure(errorMessage(error));
    } finally {
      setUpdating(null);
    }
  }

  return (
    <section aria-labelledby={headingId} className="library-updates">
      <h2 id={headingId}>{words.keepingCurrent}</h2>
      <p>
        <button ref={checkButton} type="button" aria-disabled={checking} aria-describedby={`${headingId}-help`} onClick={() => void check()}>
          {checking ? words.checkingCorrections : words.checkCorrections}
        </button>{' '}
        <span className="note" id={`${headingId}-help`}>
          {words.checkCorrectionsHelp}
        </span>
      </p>
      <p role="status">{said}</p>
      <p className="error" role="alert">
        {failure}
      </p>
      {found && found.volumes.length === 0 && <p className="note">{words.upToDateDetail}</p>}
      {found && found.volumes.length > 0 && (
        <>
          <ul className="library-corrections">
            {found.volumes.map((volume) => (
              <li key={volume.volumeId}>
                <span>
                  {volume.volumeId}
                  <br />
                  <span className="note">{volume.title}</span>
                  {volume.sideloaded && <span className="note"> · {words.sideloadedCopy}</span>}
                </span>{' '}
                <button
                  type="button"
                  aria-disabled={updating !== null}
                  aria-label={words.updateA11y(volume.volumeId)}
                  onClick={() => void update([volume.volumeId], volume.volumeId)}
                >
                  {words.update}
                </button>
              </li>
            ))}
          </ul>
          {found.volumes.length > 1 && (
            <p>
              <button
                type="button"
                aria-disabled={updating !== null}
                onClick={() => void update(found.volumes.map((volume) => volume.volumeId), 'all')}
              >
                {words.updateAll}
              </button>
            </p>
          )}
        </>
      )}
      <p className="note">{words.keepingCurrentFooter}</p>
    </section>
  );
}

/**
 * After an Update: what the updates changed, by volume, and an Import server's comparison with its TEI folder; read
 * again every two seconds while the library downloads or indexes, `busy`.
 */
export function AfterAnUpdate({ busy }: { busy: boolean }) {
  const updates = useQuery({ ...adminUpdatesQuery, ...(busy ? { refetchInterval: 2_000 } : {}) });
  const headingId = useId();
  const data = updates.data;
  return (
    <section aria-labelledby={headingId} className="library-updates">
      <h2 id={headingId}>{words.afterUpdate}</h2>
      {updates.isError && (
        <p className="error" role="alert">
          {errorMessage(updates.error)}
        </p>
      )}
      {data &&
        (data.volumes.length === 0 ? (
          <p>
            <strong>{words.noChanges}</strong> <span className="note">{words.noChangesDetail}</span>
          </p>
        ) : (
          <>
            <p>
              <strong>{words.changesWaiting}</strong>{' '}
              {words.changesTotals(data.totals.changedDocuments, data.totals.volumes, data.totals.annotatedDocuments)}
            </p>
            <ul className="library-corrections">
              {data.volumes.map((volume) => (
                <li key={volume.volumeId}>
                  <span>
                    {volume.volumeId}
                    <br />
                    <span className="note">{volume.title}</span>
                  </span>
                  <span className="note">
                    {[
                      words.changedAnnotated(volume.annotatedDocuments, volume.changedDocuments),
                      volume.body > 0 ? words.changedBody(volume.body) : null,
                      volume.apparatus > 0 ? words.changedApparatus(volume.apparatus) : null,
                      volume.vanished > 0 ? words.changedVanished(volume.vanished) : null,
                    ]
                      .filter(Boolean)
                      .join(' · ')}
                  </span>
                </li>
              ))}
            </ul>
          </>
        ))}
      {data?.teiCheck && (
        <>
          <h3>{words.teiCheck}</h3>
          <p className="note">{words.teiCheckLead}</p>
          <p role="status">
            {data.teiCheck.running
              ? words.teiCheckRunning(data.teiCheck.done, data.teiCheck.total, data.teiCheck.volume)
              : data.teiCheck.checked !== undefined
                ? words.teiCheckDone(data.teiCheck.checked, data.teiCheck.changed?.length ?? 0)
                : ''}
          </p>
          {data.teiCheck.problem && <p className="error">{data.teiCheck.problem}</p>}
          {(data.teiCheck.unchecked ?? []).length > 0 && (
            <ul>
              {data.teiCheck.unchecked!.map((volume) => (
                <li key={volume.volumeId} className="note">
                  {words.teiUnchecked(volume.volumeId, volume.reason)}
                </li>
              ))}
            </ul>
          )}
        </>
      )}
      <p className="note">{words.afterUpdateFooter}</p>
    </section>
  );
}
