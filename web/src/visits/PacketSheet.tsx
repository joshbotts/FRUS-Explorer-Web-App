// The packet's sheet (PLAN's S30d), the app's `TripPacketSheet`, which the editor's Export packet opens over the plan:
// the inquiry's topic sentence, saved to the plan half a second after typing stops and at Done, with its caption, which
// says it was seeded from the project's research question only while the field still reads it; the Options, drawn in the
// sheet where the app's are a menu: the repositories the packet covers, whose slice it may be scoped to, each one's Copy
// inquiry draft, and What to Include, the four deliverables, saved to the plan; and the packet, the kit's exporter's text,
// always with its coverage report, rendered on the server. Save as Text and Save as PDF, the web's saves for the app's
// two shares, save the text the sheet shows, PDF while the server's PDF service answers.
import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useEffectEvent, useId, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import { offersPdf, pdfServiceQuery } from '../api/pdf';
import { editVisit, packetFile, packetQuery, type VisitDeliverables, type VisitPacket, type VisitPlan } from '../api/visits';
import { copy } from '../copy';
import { closeAtOnce, Modal } from '../shell/Modal';
import { saveFile } from '../shell/saveFile';
import { showsSeededCaption, topicIsUncommitted } from './visitRules';

const words = copy.visits;

/** How long the topic waits after a key before it is saved and the packet rendered again: the app's debounce. */
export const topicPause = 500;

/** The four deliverables, in the order the app's What to Include lists them, each with its label. */
const deliverableToggles: { key: keyof VisitDeliverables; label: string }[] = [
  { key: 'includeLinks', label: words.packetLinks },
  { key: 'includeTargets', label: words.packetTargets },
  { key: 'includeInquiry', label: words.packetInquiry },
  { key: 'includeCitationCrib', label: words.packetCrib },
];

export function PacketSheet({ plan, onClose }: { plan: VisitPlan; onClose: () => void }) {
  const client = useQueryClient();
  const headingId = useId();
  const topicId = useId();
  const captionId = useId();
  const copyId = useId();
  const done = useRef<HTMLButtonElement>(null);
  const [repository, setRepository] = useState<string | null>(null);
  // The packet on show stays while another slice or a write's is asked for, so the controls keep their place and focus.
  const packet = useQuery({ ...packetQuery(plan.id, repository, null), placeholderData: keepPreviousData });
  const pdfService = useQuery(pdfServiceQuery);
  const data = packet.data;
  /**
   * The topic as typed, opened on the plan's as the editor holds it (`openPlanDraft`), which each write sets at once, and
   * never on a packet's answer, which may be older; a live draft is never replaced by one.
   */
  const [draft, setDraft] = useState(plan.inquiryText ?? '');
  /** The topic the plan holds, as the last save that succeeded left it, and the last one sent, which may be on its way. */
  const saved = useRef<string | null>(plan.inquiryText ?? null);
  const sent = useRef<string | null>(plan.inquiryText ?? null);
  /** The saves, one after another, so that they reach the server in the order they were made. */
  const chain = useRef<Promise<unknown>>(Promise.resolve());
  /** The pause before a save, and the text it waits to save, which leaving the sheet saves at once. */
  const pending = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const waiting = useRef<string | null>(null);
  const [said, setSaid] = useState('');
  const [failure, setFailure] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  /** A save of `text`, after the saves before it; a save that fails leaves the plan's topic unsaved, as it is. */
  function saveTopic(text: string): Promise<unknown> {
    sent.current = text;
    const write = chain.current
      .then(() => editVisit(client, plan.id, { inquiryText: text }))
      .then(
        () => {
          saved.current = text;
        },
        (error: unknown) => {
          sent.current = saved.current;
          throw error;
        },
      );
    chain.current = write.catch(() => {});
    return write;
  }

  // The sheet gone, as the editor's page left within the pause, the text it waited to save is saved all the same, as the
  // app's task applies it.
  const flush = useEffectEvent(() => {
    clearTimeout(pending.current);
    const text = waiting.current;
    waiting.current = null;
    if (text !== null && topicIsUncommitted(text, sent.current)) void saveTopic(text).catch(() => {});
  });
  useEffect(() => () => flush(), []);

  // A re-derived plan can lose the scoped repository, which the server answers with the whole plan.
  if (data && !packet.isPlaceholderData && repository !== null && data.repository == null) setRepository(null);

  function close() {
    done.current?.closest('dialog')?.close();
  }

  /**
   * `applyTopicEdit()`: the draft saved to the plan, a blank one as none, and the packet rendered again; a text already on
   * its way waits for that save rather than sending a second.
   */
  function commitTopic(text: string): Promise<unknown> {
    clearTimeout(pending.current);
    waiting.current = null;
    if (!topicIsUncommitted(text, sent.current)) return chain.current;
    return saveTopic(text);
  }

  /** `scheduleTopicRender()`: saved half a second after typing stops. */
  function typed(text: string) {
    setDraft(text);
    clearTimeout(pending.current);
    waiting.current = text;
    pending.current = setTimeout(() => void run(() => commitTopic(text)), topicPause);
  }

  async function run(write: () => Promise<unknown>) {
    setFailure(null);
    try {
      await write();
    } catch (error) {
      setFailure(errorMessage(error));
    }
  }

  /**
   * Done: a topic the plan does not hold yet is saved first, so that closing never races what was just typed; one that
   * cannot be saved keeps the sheet open, saying why.
   */
  async function finish() {
    if (!topicIsUncommitted(draft, saved.current)) {
      close();
      return;
    }
    setFailure(null);
    try {
      await commitTopic(draft);
    } catch (error) {
      setFailure(errorMessage(error));
      return;
    }
    // A save of this text that was already on its way, and failed, said so when it failed.
    if (topicIsUncommitted(draft, saved.current)) return;
    closeAtOnce(close);
  }

  async function copyDraft(chosen: string) {
    const text = data?.drafts.find((each) => each.repository === chosen)?.text;
    if (text === undefined) return;
    setFailure(null);
    try {
      await navigator.clipboard.writeText(text);
      setSaid(words.packetCopied(chosen));
    } catch (error) {
      setFailure(errorMessage(error));
    }
  }

  async function save(format: 'text' | 'pdf', shown: VisitPacket) {
    setFailure(null);
    setSaving(true);
    setSaid(words.packetSaving);
    try {
      const file = await packetFile(plan.id, format, shown);
      saveFile(file.blob, file.name);
      setSaid(words.packetSaved(file.name));
    } catch (error) {
      setSaid('');
      setFailure(errorMessage(error));
    } finally {
      setSaving(false);
    }
  }

  const ready = data && data.text != null;
  return (
    <Modal className="packet-sheet" labelledBy={headingId} onCancel={() => void finish()} onClose={onClose}>
      <h2 id={headingId} tabIndex={-1}>
        {words.packetTitle}
      </h2>
      {packet.isError && !data ? (
        <p className="error" role="alert">
          {errorMessage(packet.error)}
        </p>
      ) : !data ? (
        <p role="status">{words.packetBuilding}</p>
      ) : !ready ? (
        <div className="empty">
          <h3>{data.unavailable === 'indexUnavailable' ? words.packetNoIndexTitle : words.packetEmptyTitle}</h3>
          <p>{data.unavailable === 'indexUnavailable' ? words.packetNoIndex : words.packetEmpty}</p>
        </div>
      ) : (
        <div className="packet-body" aria-busy={packet.isFetching}>
          <div className="packet-topic">
            <label htmlFor={topicId} className="packet-topic-header">
              {words.packetTopicHeader}
            </label>
            <textarea
              id={topicId}
              rows={3}
              aria-describedby={captionId}
              placeholder={data.topicPlaceholder}
              value={draft}
              onChange={(event) => typed(event.target.value)}
            />
            <p id={captionId} className="note">
              {showsSeededCaption(draft, data.researchQuestion) ? words.packetTopicSeeded : words.packetTopicUnseeded}
            </p>
          </div>
          <fieldset className="packet-options">
            <legend>{words.packetOptions}</legend>
            <label>
              {words.packetScope}{' '}
              <select value={repository ?? ''} onChange={(event) => setRepository(event.target.value === '' ? null : event.target.value)}>
                <option value="">{words.packetScopeAll}</option>
                {data.repositories.map((each) => (
                  <option key={each} value={each}>
                    {each}
                  </option>
                ))}
              </select>
            </label>
            {data.repositories.length > 0 && (
              <div className="packet-copy" role="group" aria-labelledby={copyId}>
                <span id={copyId} className="packet-group-label">
                  {words.packetCopyDraft}
                </span>
                {data.repositories.map((each) => (
                  <button key={each} type="button" onClick={() => void copyDraft(each)}>
                    {each}
                  </button>
                ))}
              </div>
            )}
            <fieldset className="packet-deliverables">
              <legend>{words.packetDeliverables}</legend>
              {deliverableToggles.map((toggle) => (
                <label key={toggle.key}>
                  <input
                    type="checkbox"
                    checked={data.deliverables[toggle.key]}
                    onChange={(event) => void run(() => editVisit(client, plan.id, { deliverables: { [toggle.key]: event.target.checked } }))}
                  />{' '}
                  {toggle.label}
                </label>
              ))}
            </fieldset>
          </fieldset>
          {/* The exporter's text as it is, which the saves write: one composition, never a second. */}
          <pre className="packet-text" role="region" aria-label={words.packetText} tabIndex={0}>
            {data.text}
          </pre>
        </div>
      )}
      <p className="note packet-status" role="status">
        {said}
      </p>
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      <div className="dialog-actions">
        {ready && (
          <button type="button" disabled={saving} onClick={() => void save('text', data)}>
            {words.packetSaveText}
          </button>
        )}
        {ready && offersPdf(pdfService.data) && (
          <button type="button" disabled={saving} onClick={() => void save('pdf', data)}>
            {words.packetSavePDF}
          </button>
        )}
        <button ref={done} type="button" onClick={() => void finish()}>
          {words.done}
        </button>
      </div>
    </Modal>
  );
}
