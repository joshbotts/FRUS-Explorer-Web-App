// The plan picker, Add to Archives Visit (PLAN's S30d), the app's `PlanPickerSheet`, which every way in presents: its
// banner, which says what is added, under which claims and from where, so that the reader approves what is about to be
// written; the user's plans, the most recently changed first, each its name and how many documents seed it, found by
// the search by the name its row shows; and New Archives Visit, a plan made under the active project, named as the way
// in suggests, then seeded like any other row. A choice adds the documents by the kit's one add, a seed's halves turned
// on and never off, shows Added, says so, and the picker closes a moment after, as the app's does.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { type ReactNode, useEffect, useId, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import { addSeeds, createVisitWith, visitsQuery, type SeedRequest } from '../api/visits';
import { addedPause } from '../collections/CollectionPicker';
import { useStillOpen } from '../collections/CollectionsScreen';
import { copy } from '../copy';
import { closeAtOnce, Modal } from '../shell/Modal';
import { pickerBanner, planMatches } from './visitRules';

/** A way in's request (`PlanPickerRequest`): its documents, the halves it presets, its basis and the name it suggests. */
export interface PlanPickerRequest extends SeedRequest {
  /** Where the add came from ("from Source Explorer", "the 12 neighbors shown"), the banner's end. */
  basis: string;
  /** The name a plan made from this add takes; none for an untitled one. */
  suggestedName?: string;
}

const words = copy.visits;

export function PlanPicker({ request, onClose }: { request: PlanPickerRequest; onClose: () => void }) {
  const client = useQueryClient();
  const headingId = useId();
  const bannerId = useId();
  const searchId = useId();
  const cancel = useRef<HTMLButtonElement>(null);
  const plans = useQuery(visitsQuery);
  const [search, setSearch] = useState('');
  /** The plan the documents went to, its id and its name as its row shows it. */
  const [added, setAdded] = useState<{ id: string; name: string } | null>(null);
  const [failure, setFailure] = useState<string | null>(null);
  const closing = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  useEffect(() => () => clearTimeout(closing.current), []);
  const stillOpen = useStillOpen();
  // Set at the press, as the app sets its added plan at once, so a second press adds nothing.
  const choosing = useRef(false);
  const items = plans.data?.items ?? [];
  const shown = items.filter((plan) => planMatches(plan, search));
  const seeds: SeedRequest = {
    documents: request.documents,
    includeSource: request.includeSource,
    includeExternalRefs: request.includeExternalRefs,
  };

  /** Adds the documents, to `id` or to a plan made for them, then shows Added and closes a moment after. */
  async function choose(id: string | null) {
    if (choosing.current) return;
    choosing.current = true;
    setFailure(null);
    try {
      const plan = id === null ? await createVisitWith(client, seeds, request.suggestedName ?? '') : await addSeeds(client, id, seeds);
      // An add answered after Cancel or Escape stands, and leaves the screen alone.
      if (!stillOpen.current) return;
      setAdded({ id: plan.id, name: plan.displayName });
      closing.current = setTimeout(() => closeAtOnce(onClose), addedPause);
    } catch (error) {
      if (!stillOpen.current) return;
      choosing.current = false;
      setFailure(errorMessage(error));
    }
  }

  return (
    <Modal className="plan-picker" labelledBy={headingId} describedBy={bannerId} initial={cancel} onCancel={onClose} onClose={() => {}}>
      <h2 id={headingId} tabIndex={-1}>
        {words.pickerTitle}
      </h2>
      <p id={bannerId} className="plan-picker-banner">
        {pickerBanner(request.documents.length, request.includeSource, request.includeExternalRefs, request.basis)}
      </p>
      {plans.isError ? (
        <p className="error" role="alert">
          {errorMessage(plans.error)}
        </p>
      ) : !plans.data ? (
        <p role="status">{words.pickerLoading}</p>
      ) : (
        <>
          {items.length > 0 && (
            <>
              <label htmlFor={searchId} className="visually-hidden">
                {words.pickerSearch}
              </label>
              <input id={searchId} type="search" value={search} placeholder={words.pickerSearch} onChange={(event) => setSearch(event.target.value)} />
            </>
          )}
          {items.length > 0 && shown.length === 0 && <p>{words.pickerNoResults(search)}</p>}
          <ul className="picker-list" aria-label={words.title}>
            {shown.map((plan) => (
              <li key={plan.id}>
                <button type="button" className="picker-row" onClick={() => void choose(plan.id)}>
                  <span className="picker-name">{plan.displayName}</span>
                  <span className="meta">{words.documents(plan.documentCount)}</span>
                  {added?.id === plan.id && <span className="added">{words.pickerAdded}</span>}
                </button>
              </li>
            ))}
            <li>
              <button type="button" className="picker-row picker-new" onClick={() => void choose(null)}>
                <span className="picker-name">{words.new}</span>
              </button>
            </li>
          </ul>
        </>
      )}
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      {/* Said at once, as the collection picker says its choice: the picker closes a moment after. */}
      <p role="alert" className="visually-hidden">
        {added ? words.pickerAnnounceAdded(added.name) : ''}
      </p>
      <div className="dialog-actions">
        <button ref={cancel} type="button" onClick={onClose}>
          {words.cancel}
        </button>
      </div>
    </Modal>
  );
}

/**
 * Couldn't Add to Archives Visit (#1619): why a way in gathered no documents, as a smart collection's search that cannot
 * run, said in an alert with its OK, where the add would otherwise do nothing and say nothing.
 */
export function AddToVisitFailure({ message, onClose }: { message: ReactNode; onClose: () => void }) {
  const headingId = useId();
  const messageId = useId();
  const ok = useRef<HTMLButtonElement>(null);
  function close() {
    ok.current?.closest('dialog')?.close();
  }
  return (
    <Modal className="confirm" role="alertdialog" labelledBy={headingId} describedBy={messageId} initial={ok} onCancel={close} onClose={onClose}>
      <h2 id={headingId} tabIndex={-1}>
        {words.collectionErrorTitle}
      </h2>
      <p id={messageId}>{message}</p>
      <div className="actions">
        <button ref={ok} type="button" onClick={close}>
          {words.ok}
        </button>
      </div>
    </Modal>
  );
}
