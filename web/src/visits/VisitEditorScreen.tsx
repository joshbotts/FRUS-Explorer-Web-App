// An Archives Visit's editor (PLAN's S30c), at /visits/$planId, as the app's `ArchiveVisitEditorView` draws it: its name,
// committed on Return or on leaving the field, never at each key, an empty one put back; About research targets; the More
// menu's Priority Tiers…, Duplicate, Re-seed from Project while the plan's project exists, and Delete; and its two tabs.
// Targets: the kit's count of what derives, amber when this server lacks some of the documents, the four filters, then
// each repository's section with its verified links and "Confirm before you travel", each target's lines, its tier's
// control and its menu, Edit Note… and Include or Exclude, its seedings under a disclosure, and the stored targets a change
// has orphaned or another row is shown over, each with Remove Stored State, which asks first. Documents: each seed with its
// two switches, or the caption where a half is absent, Open Document and Remove. The tiers' sheet adds, renames, moves by a
// step and deletes tiers. Every write is the server's, by the kit's rules, and answers the plan as it then stands.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { getRouteApi, Link, useNavigate } from '@tanstack/react-router';
import { type ReactNode, useEffect, useId, useRef, useState } from 'react';
import { ApiError, errorMessage } from '../api/client';
import {
  addTier,
  deleteTier,
  duplicateVisit,
  editVisit,
  moveTier,
  relabelTier,
  removeSeed,
  removeStoredTarget,
  reseedVisit,
  visitQuery,
  writeSeed,
  writeTarget,
  type VisitPlan,
  type VisitSection,
  type VisitSeed,
  type VisitStoredTarget,
  type VisitTarget,
  type VisitTier,
} from '../api/visits';
import { copy } from '../copy';
import { useHeadingReady } from '../shell/headingFocus';
import { MenuButton, type MenuEntry } from '../shell/MenuButton';
import { closeAtOnce, Modal } from '../shell/Modal';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import { DeleteVisitDialog } from './VisitsScreen';
import {
  citationRuns,
  citationText,
  claimCountsLine,
  freshFilters,
  hasActiveFilters,
  noFilters,
  noTargetsExplanation,
  tierName,
  visibleSections,
  type ClaimFilter,
  type TargetFilters,
} from './visitRules';

const editorRoute = getRouteApi('/visits/$planId');

/** The packet's cap on each claim's list (`TripPacketExporter.seedingRowLimit`), which the server sends the first of. */
const seedingRowLimit = 8;

type Dialog =
  | { kind: 'note'; key: string; label: string; note: string }
  | { kind: 'removeStored'; key: string }
  | { kind: 'delete' }
  | { kind: 'tiers' }
  | { kind: 'topic'; question: string; current: string };

export function VisitEditorScreen() {
  const { planId } = editorRoute.useParams();
  const client = useQueryClient();
  const navigate = useNavigate();
  const query = useQuery(visitQuery(planId));
  const plan = query.data;
  const gone = query.error instanceof ApiError && query.error.code === 'VISIT_NOT_FOUND';
  useDocumentTitle(plan ? plan.displayName : copy.visits.editorTitle);
  useHeadingReady(!query.isPending);
  const [tab, setTab] = useState<'targets' | 'documents'>('targets');
  const [filters, setFilters] = useState<TargetFilters>(noFilters);
  const [failure, setFailure] = useState<string | null>(null);
  const [status, setStatus] = useState<string | null>(null);
  const [dialog, setDialog] = useState<Dialog | null>(null);
  const [showInfo, setShowInfo] = useState(false);
  const returnFocus = useRef<HTMLElement | null>(null);
  /** The target whose control a write was chosen from, whose row the answer may move or a filter may hide. */
  const restore = useRef<{ key: string; control: 'tier' | 'menu' } | null>(null);
  const tabsName = useId();
  const infoId = useId();

  // A write's answer can sort its target elsewhere, which moves its row and drops the focus it held, or hide it under a
  // filter: focus goes back to the control it was chosen from, wherever the row now sits, else to the filters.
  useEffect(() => {
    const wanted = restore.current;
    if (!wanted || !plan) return;
    restore.current = null;
    const active = document.activeElement;
    if (active && active !== document.body && active.isConnected) return;
    const row = [...document.querySelectorAll<HTMLElement>('li[data-target]')].find((item) => item.dataset.target === wanted.key);
    const control = row?.querySelector<HTMLElement>(wanted.control === 'tier' ? '.visit-tier-menu > button' : '.visit-target-menu > button');
    (control ?? document.querySelector<HTMLElement>('.visit-filters select') ?? document.querySelector<HTMLElement>('main h1'))?.focus();
  }, [plan]);

  // Filters can go stale between answers: a deleted tier, a repository that no longer derives (the app's reset).
  const fresh = plan ? freshFilters(filters, plan) : filters;
  if (fresh !== filters) setFilters(fresh);

  /** Runs one of the editor's writes, saying why when it fails. */
  async function run(write: () => Promise<unknown>) {
    setFailure(null);
    try {
      await write();
    } catch (error) {
      restore.current = null;
      setFailure(errorMessage(error));
    }
  }

  /** A target's write, chosen from its `control`, to which focus goes back once the answer has drawn the list. */
  function writeTo(key: string, write: { tierId: string | null } | { included: boolean }, control: 'tier' | 'menu') {
    restore.current = { key, control };
    return run(() => writeTarget(client, planId, key, write));
  }

  function open(next: Dialog) {
    returnFocus.current = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    setDialog(next);
  }

  function closeDialog() {
    setDialog(null);
    const back = returnFocus.current;
    returnFocus.current = null;
    if (back?.isConnected) back.focus();
  }

  if (gone) {
    return (
      <section className="screen research visit-editor">
        <h1 tabIndex={-1}>{copy.visits.editorTitle}</h1>
        <p className="error" role="alert">
          {copy.visits.gone}
        </p>
        <Link to="/visits">{copy.visits.backToList}</Link>
      </section>
    );
  }

  const tierEntries = (onTier: (tierId: string | null) => void): MenuEntry[] =>
    plan
      ? [
          { kind: 'item', label: copy.visits.unprioritized, onSelect: () => onTier(null) },
          ...plan.tiers.map((tier): MenuEntry => ({ kind: 'item', label: tier.displayName, onSelect: () => onTier(tier.id) })),
          { kind: 'separator' },
          { kind: 'item', label: copy.visits.tiers, onSelect: () => open({ kind: 'tiers' }) },
        ]
      : [];

  return (
    <section className="screen research visit-editor">
      <nav className="breadcrumb" aria-label={copy.visits.title}>
        <Link to="/visits">{copy.visits.backToList}</Link>
      </nav>
      <h1 tabIndex={-1}>{copy.visits.editorTitle}</h1>
      {query.isError ? (
        <p className="error" role="alert">
          {errorMessage(query.error)}
        </p>
      ) : !plan ? (
        <p role="status">{copy.visits.deriving}</p>
      ) : (
        <>
          <NameField plan={plan} onRename={(name) => run(() => editVisit(client, plan.id, { name }))} />
          <div className="visit-toolbar">
            <button
              type="button"
              aria-expanded={showInfo}
              aria-controls={infoId}
              title={copy.visits.aboutHelp}
              onClick={() => setShowInfo((shown) => !shown)}
            >
              {copy.visits.about}
            </button>
            <MenuButton
              label={copy.visits.more}
              entries={[
                { kind: 'item', label: copy.visits.tiers, onSelect: () => open({ kind: 'tiers' }) },
                {
                  kind: 'item',
                  label: copy.visits.duplicate,
                  onSelect: () =>
                    void run(async () => {
                      const copied = await duplicateVisit(client, plan.id);
                      setStatus(copy.visits.duplicated(copied.displayName));
                    }),
                },
                ...(plan.project
                  ? [
                      {
                        kind: 'item' as const,
                        label: copy.visits.reseed,
                        onSelect: () =>
                          void run(async () => {
                            const answer = await reseedVisit(client, plan.id);
                            if (answer.topic === 'filled') setStatus(copy.visits.topicFilled);
                            if (answer.topic === 'needsConfirmation') {
                              open({ kind: 'topic', question: answer.question ?? '', current: answer.current ?? '' });
                            }
                          }),
                      },
                    ]
                  : []),
                { kind: 'separator' },
                { kind: 'item', label: copy.visits.delete, destructive: true, onSelect: () => open({ kind: 'delete' }) },
              ]}
            />
          </div>
          {showInfo && <AboutTargets id={infoId} plan={plan} />}
          <p className="note visit-status" role="status">
            {status}
          </p>
          {failure && (
            <p className="error" role="alert">
              {failure}
            </p>
          )}
          <fieldset className="segmented visit-tabs">
            <legend className="visually-hidden">{copy.visits.tab}</legend>
            {(['targets', 'documents'] as const).map((choice) => (
              <label key={choice}>
                <input type="radio" name={tabsName} value={choice} checked={tab === choice} onChange={() => setTab(choice)} />
                {choice === 'targets' ? copy.visits.tabTargets : copy.visits.tabDocuments}
              </label>
            ))}
          </fieldset>
          {tab === 'targets' ? (
            <TargetsTab
              plan={plan}
              filters={filters}
              onFilters={setFilters}
              tierEntries={tierEntries}
              onTarget={writeTo}
              onNote={(key, label, note) => open({ kind: 'note', key, label, note })}
              onRemoveStored={(key) => open({ kind: 'removeStored', key })}
            />
          ) : (
            <DocumentsTab
              plan={plan}
              onSwitch={(key, write) => run(() => writeSeed(client, plan.id, key, write))}
              onRemove={(key) => run(() => removeSeed(client, plan.id, key))}
            />
          )}
          {dialog?.kind === 'note' && (
            <NoteDialog
              title={copy.visits.noteTitle}
              fieldLabel={copy.visits.notePlaceholder}
              initial={dialog.note}
              onSave={(note) => writeTarget(client, plan.id, dialog.key, { note })}
              onClose={closeDialog}
            />
          )}
          {dialog?.kind === 'removeStored' && (
            <ConfirmDialog
              title={copy.visits.removeStoredTitle}
              message={copy.visits.removeStoredMessage}
              confirm={copy.visits.removeStored}
              onConfirm={() => removeStoredTarget(client, plan.id, dialog.key)}
              onClose={closeDialog}
            />
          )}
          {dialog?.kind === 'delete' && (
            <DeleteVisitDialog
              plan={plan}
              onClose={(deleted) => {
                // The screen goes with the plan: drawn again, it would ask for the plan the delete removed.
                if (deleted) void navigate({ to: '/visits' });
                else closeDialog();
              }}
            />
          )}
          {dialog?.kind === 'tiers' && <TiersDialog plan={plan} onClose={closeDialog} />}
          {dialog?.kind === 'topic' && (
            <TopicDialog
              question={dialog.question}
              current={dialog.current}
              onReplace={() => editVisit(client, plan.id, { inquiryText: dialog.question })}
              onClose={closeDialog}
            />
          )}
        </>
      )}
    </section>
  );
}

/** The name, edited as a draft: committed on Return or on leaving the field; an empty one puts the name back. */
function NameField({ plan, onRename }: { plan: VisitPlan; onRename: (name: string) => Promise<void> }) {
  const [draft, setDraft] = useState(plan.name);
  const [seed, setSeed] = useState(plan.name);
  // A name changed elsewhere (a rename's answer) takes the field, unless a draft is being typed over it.
  if (plan.name !== seed) {
    if (draft === seed) setDraft(plan.name);
    setSeed(plan.name);
  }
  function commit() {
    const trimmed = draft.trim();
    if (trimmed === '') {
      setDraft(plan.name);
    } else if (trimmed !== plan.name) {
      void onRename(draft);
    }
  }
  return (
    <form
      className="visit-name-field"
      onSubmit={(event) => {
        event.preventDefault();
        commit();
      }}
    >
      <input
        type="text"
        aria-label={copy.visits.nameA11y}
        placeholder={copy.visits.untitled}
        value={draft}
        onChange={(event) => setDraft(event.target.value)}
        onBlur={commit}
      />
    </form>
  );
}

/** About research targets: the claims' definitions, the never-summed rule, the corpus's sparsity and this server's. */
function AboutTargets({ id, plan }: { id: string; plan: VisitPlan }) {
  return (
    <section id={id} className="visit-info" aria-label={copy.visits.about}>
      <p>{copy.visits.infoBody}</p>
      <p className="meta">{copy.visits.infoSparsity}</p>
      {plan.sparsity && plan.sparsity.indexed > 0 && (
        <p className="meta">{copy.visits.measuredSparsity(plan.sparsity.withReferences, plan.sparsity.indexed)}</p>
      )}
    </section>
  );
}

function TargetsTab({
  plan,
  filters,
  onFilters,
  tierEntries,
  onTarget,
  onNote,
  onRemoveStored,
}: {
  plan: VisitPlan;
  filters: TargetFilters;
  onFilters: (filters: TargetFilters) => void;
  tierEntries: (onTier: (tierId: string | null) => void) => MenuEntry[];
  onTarget: (key: string, write: { tierId: string | null } | { included: boolean }, control: 'tier' | 'menu') => Promise<void>;
  onNote: (key: string, label: string, note: string) => void;
  onRemoveStored: (key: string) => void;
}) {
  if (!plan.served) return <p className="note">{copy.visits.noIndex}</p>;
  if (plan.documents.length === 0) return <NoSeeds />;
  const sections = visibleSections(plan, filters);
  return <TargetsList plan={plan} filters={filters} onFilters={onFilters} sections={sections} tierEntries={tierEntries}
    onTarget={onTarget} onNote={onNote} onRemoveStored={onRemoveStored} />;
}

/** The Targets list over its sections: the summary and filters, the empty states, the sections and the stored targets. */
function TargetsList({
  plan,
  filters,
  onFilters,
  sections,
  tierEntries,
  onTarget,
  onNote,
  onRemoveStored,
}: {
  plan: VisitPlan;
  filters: TargetFilters;
  onFilters: (filters: TargetFilters) => void;
  sections: VisitSection[];
  tierEntries: (onTier: (tierId: string | null) => void) => MenuEntry[];
  onTarget: (key: string, write: { tierId: string | null } | { included: boolean }, control: 'tier' | 'menu') => Promise<void>;
  onNote: (key: string, label: string, note: string) => void;
  onRemoveStored: (key: string) => void;
}) {
  const storedId = useId();
  return (
    <>
      <div className="visit-summary">
        {plan.summary && <p className="meta">{plan.summary}</p>}
        {plan.indexedDocumentCount < plan.documentCount && (
          <p className="count warning">{copy.visits.editorCoverage(plan.indexedDocumentCount, copy.visits.seeding(plan.documentCount))}</p>
        )}
        {plan.sections.length > 0 && <Filters plan={plan} filters={filters} onFilters={onFilters} />}
      </div>
      {plan.sections.length === 0 ? (
        <p className="note">{noTargetsExplanation(plan)}</p>
      ) : sections.length === 0 ? (
        <div className="visit-no-matches">
          <p className="note">{copy.visits.noMatches}</p>
          <button type="button" onClick={() => onFilters(noFilters)}>
            {copy.visits.clearFilters}
          </button>
        </div>
      ) : (
        sections.map((section) => (
          <SectionBlock
            key={section.heading}
            section={section}
            plan={plan}
            tierEntries={tierEntries}
            onTarget={onTarget}
            onNote={onNote}
          />
        ))
      )}
      {sections.length > 0 && plan.storedTargets.length > 0 && (
        <section className="visit-section visit-stored" aria-labelledby={storedId}>
          <h2 id={storedId}>{copy.visits.storedHeader}</h2>
          <ul className="visit-targets">
            {plan.storedTargets.map((stored) => (
              <StoredRow
                key={stored.key}
                plan={plan}
                stored={stored}
                tierEntries={tierEntries((tierId) => void onTarget(stored.key, { tierId }, 'tier'))}
                onNote={() => onNote(stored.key, stored.label, stored.note ?? '')}
                onRemove={() => onRemoveStored(stored.key)}
              />
            ))}
          </ul>
        </section>
      )}
    </>
  );
}

/** A repository's section, or Confirm before you travel: its heading, its verified links and its targets. */
function SectionBlock({
  section,
  plan,
  tierEntries,
  onTarget,
  onNote,
}: {
  section: VisitSection;
  plan: VisitPlan;
  tierEntries: (onTier: (tierId: string | null) => void) => MenuEntry[];
  onTarget: (key: string, write: { tierId: string | null } | { included: boolean }, control: 'tier' | 'menu') => Promise<void>;
  onNote: (key: string, label: string, note: string) => void;
}) {
  const headingId = useId();
  return (
    <section className="visit-section" aria-labelledby={headingId}>
      <h2 id={headingId}>{section.heading}</h2>
      {section.links.length > 0 && (
        <ul className="visit-links">
          {section.links.map((link) => (
            <li key={link.url}>
              <a href={link.url} target="_blank" rel="noreferrer">
                {link.label}
              </a>
            </li>
          ))}
        </ul>
      )}
      <ul className="visit-targets">
        {section.targets.map((target) => (
          <TargetRow
            key={target.key}
            plan={plan}
            target={target}
            tierEntries={tierEntries((tierId) => void onTarget(target.key, { tierId }, 'tier'))}
            onNote={() => onNote(target.key, target.label, target.note ?? '')}
            onIncluded={(included) => void onTarget(target.key, { included }, 'menu')}
          />
        ))}
      </ul>
    </section>
  );
}

function NoSeeds() {
  return (
    <div className="empty">
      <h2>{copy.visits.noSeedsTitle}</h2>
      <p>{copy.visits.noSeedsDetail}</p>
    </div>
  );
}

/** The four filters: repository, tier, claim, and Included only. */
function Filters({ plan, filters, onFilters }: { plan: VisitPlan; filters: TargetFilters; onFilters: (filters: TargetFilters) => void }) {
  const tierValue = filters.tier.kind === 'tier' ? `tier:${filters.tier.id}` : filters.tier.kind;
  return (
    <fieldset className="visit-filters">
      <legend className="visually-hidden">{copy.visits.filters}</legend>
      <label>
        {copy.visits.repository}{' '}
        <select
          value={filters.repository ?? ''}
          onChange={(event) => onFilters({ ...filters, repository: event.target.value === '' ? null : event.target.value })}
        >
          <option value="">{copy.visits.all}</option>
          {plan.sections.map((section) => (
            <option key={section.heading} value={section.heading}>
              {section.heading}
            </option>
          ))}
        </select>
      </label>
      <label>
        {copy.visits.tier}{' '}
        <select
          value={tierValue}
          onChange={(event) => {
            const value = event.target.value;
            onFilters({
              ...filters,
              tier: value === 'all' || value === 'unprioritized' ? { kind: value } : { kind: 'tier', id: value.slice('tier:'.length) },
            });
          }}
        >
          <option value="all">{copy.visits.all}</option>
          {plan.tiers.map((tier) => (
            <option key={tier.id} value={`tier:${tier.id}`}>
              {tier.displayName}
            </option>
          ))}
          <option value="unprioritized">{copy.visits.unprioritized}</option>
        </select>
      </label>
      <label>
        {copy.visits.claim}{' '}
        <select value={filters.claim} onChange={(event) => onFilters({ ...filters, claim: event.target.value as ClaimFilter })}>
          <option value="all">{copy.visits.all}</option>
          <option value="drawnFrom">{copy.visits.drawnFrom}</option>
          <option value="pointedAt">{copy.visits.pointedAt}</option>
        </select>
      </label>
      <button type="button" aria-pressed={filters.includedOnly} onClick={() => onFilters({ ...filters, includedOnly: !filters.includedOnly })}>
        {copy.visits.includedOnly}
      </button>
      {hasActiveFilters(filters) && (
        <button type="button" onClick={() => onFilters(noFilters)}>
          {copy.visits.clearFilters}
        </button>
      )}
    </fieldset>
  );
}

/** A citation's runs, its series' title in italics. */
function Citation({ text }: { text: string }) {
  return (
    <>
      {citationRuns(text).map((run, index) => (run.emphasis ? <em key={index}>{run.text}</em> : <span key={index}>{run.text}</span>))}
    </>
  );
}

/** A target's row (`targetRow`): its label, which opens its seedings, its tier's control and its menu, and its lines. */
function TargetRow({
  plan,
  target,
  tierEntries,
  onNote,
  onIncluded,
}: {
  plan: VisitPlan;
  target: VisitTarget;
  tierEntries: MenuEntry[];
  onNote: () => void;
  onIncluded: (included: boolean) => void;
}) {
  const [open, setOpen] = useState(false);
  const seedingsId = useId();
  const tier = tierName(plan, target.tierId);
  return (
    <li className={target.excluded ? 'visit-target excluded' : 'visit-target'} data-target={target.key}>
      <div className="visit-target-head">
        <button type="button" className="visit-target-label" aria-expanded={open} aria-controls={seedingsId} onClick={() => setOpen((shown) => !shown)}>
          {target.label}
        </button>
        <MenuButton
          label={tier ?? copy.visits.setTier}
          accessibleLabel={`${copy.visits.tierOf(target.label)}: ${tier ?? copy.visits.setTier}`}
          className="visit-tier-menu"
          entries={tierEntries}
        />
        <MenuButton
          label="⋯"
          accessibleLabel={copy.visits.targetMenu(target.label)}
          className="visit-target-menu"
          entries={[
            { kind: 'item', label: copy.visits.editNote, onSelect: onNote },
            {
              kind: 'item',
              label: target.excluded ? copy.visits.include : copy.visits.exclude,
              onSelect: () => onIncluded(target.excluded),
            },
          ]}
        />
      </div>
      {target.recordsLine && <p className="meta">{target.recordsLine}</p>}
      <p className="meta">{claimCountsLine(target)}</p>
      {target.substitute && <p className="meta small">{copy.visits.substitute}</p>}
      {/* The packet's own English sentences, which quote NARA's words, as the app's row reads them. */}
      {target.accessLines.map((line) => (
        <p key={line} className="note warning small">
          {line}
        </p>
      ))}
      {target.lots.map((lot) => (
        <div key={lot.title} className="visit-lot">
          <p className="meta">
            <strong>{lot.title}</strong>
          </p>
          {lot.recordsLine && <p className="meta">{lot.recordsLine}</p>}
          {lot.accessLines.map((line) => (
            <p key={line} className="note warning small">
              {line}
            </p>
          ))}
        </div>
      ))}
      {target.note && (
        <p className="meta visit-note">
          <em>{target.note}</em>
        </p>
      )}
      {target.excluded && <p className="meta small">{copy.visits.excluded}</p>}
      <div id={seedingsId} hidden={!open} className="visit-seedings">
        {open && <Seedings target={target} />}
      </div>
    </li>
  );
}

/** The expanded row: the seedings under their claims, verbatim, each list the packet's capped one. */
function Seedings({ target }: { target: VisitTarget }) {
  return (
    <>
      {target.drawnFromCount > 0 && (
        <>
          <h3>{copy.visits.drawnFromHeader(target.drawnFromCount)}</h3>
          <ul>
            {target.drawnFrom.map((document) => (
              <li key={`${document.volumeId}/${document.documentId}`}>
                <Link to="/doc/$volumeId/$documentId" params={{ volumeId: document.volumeId, documentId: document.documentId }}>
                  <Citation text={document.citation} />
                </Link>
                <p className="meta small">{copy.visits.quoted(document.sourceNote)}</p>
              </li>
            ))}
          </ul>
          {target.drawnFromCount > seedingRowLimit && <p className="meta small">{copy.visits.seedingsMore(target.drawnFromCount - seedingRowLimit)}</p>}
        </>
      )}
      {target.pointedAtCount > 0 && (
        <>
          <h3>{copy.visits.pointedAtHeader(target.pointedAtCount)}</h3>
          <ul>
            {target.pointedAt.map((seeding, index) => (
              <li key={index}>
                <Link
                  to="/doc/$volumeId/$documentId"
                  params={{ volumeId: seeding.volumeId, documentId: seeding.documentId }}
                  aria-label={citationText(seeding.line)}
                >
                  <Citation text={seeding.line} />
                </Link>
                <p className="meta small">{copy.visits.quoted(seeding.rawText)}</p>
                {seeding.inherited && <p className="meta small">{copy.visits.inherited}</p>}
              </li>
            ))}
          </ul>
          {target.pointedAtCount > seedingRowLimit && <p className="meta small">{copy.visits.seedingsMore(target.pointedAtCount - seedingRowLimit)}</p>}
        </>
      )}
    </>
  );
}

/** A row under Stored targets: the stored key's label, its tier's control, its caption and note, and its menu. */
function StoredRow({
  plan,
  stored,
  tierEntries,
  onNote,
  onRemove,
}: {
  plan: VisitPlan;
  stored: VisitStoredTarget;
  tierEntries: MenuEntry[];
  onNote: () => void;
  onRemove: () => void;
}) {
  const tier = tierName(plan, stored.tierId);
  return (
    <li className="visit-target stored" data-target={stored.key}>
      <div className="visit-target-head">
        <span className="visit-target-label">{stored.label}</span>
        <MenuButton
          label={tier ?? copy.visits.setTier}
          accessibleLabel={`${copy.visits.tierOf(stored.label)}: ${tier ?? copy.visits.setTier}`}
          className="visit-tier-menu"
          entries={tierEntries}
        />
        <MenuButton
          label="⋯"
          accessibleLabel={copy.visits.targetMenu(stored.label)}
          className="visit-target-menu"
          entries={[
            { kind: 'item', label: copy.visits.editNote, onSelect: onNote },
            { kind: 'item', label: copy.visits.removeStored, destructive: true, onSelect: onRemove },
          ]}
        />
      </div>
      <p className="meta small">
        {stored.kind === 'orphan' ? copy.visits.orphanCaption : copy.visits.supersededCaption(stored.partOf ?? stored.label)}
      </p>
      {stored.kind === 'superseded' && stored.excludedWhenOwn && <p className="meta small">{copy.visits.supersededExcluded}</p>}
      {stored.note && (
        <p className="meta visit-note">
          <em>{stored.note}</em>
        </p>
      )}
    </li>
  );
}

function DocumentsTab({
  plan,
  onSwitch,
  onRemove,
}: {
  plan: VisitPlan;
  onSwitch: (key: string, write: { includeSource: boolean } | { includeExternalRefs: boolean }) => Promise<void>;
  onRemove: (key: string) => Promise<void>;
}) {
  if (plan.documents.length === 0) return <NoSeeds />;
  return (
    <>
      <ul className="visit-documents" aria-label={copy.visits.tabDocuments}>
        {plan.documents.map((seed) => (
          <SeedRow key={seed.key} seed={seed} onSwitch={onSwitch} onRemove={onRemove} />
        ))}
      </ul>
      <p className="note">{copy.visits.documentsFooter}</p>
      {plan.sparsity && plan.sparsity.indexed > 0 && (
        <p className="note">{copy.visits.measuredSparsity(plan.sparsity.withReferences, plan.sparsity.indexed)}</p>
      )}
    </>
  );
}

/** A seed's row (`documentRow`): its head and volume, its two halves, Open Document and Remove. */
function SeedRow({
  seed,
  onSwitch,
  onRemove,
}: {
  seed: VisitSeed;
  onSwitch: (key: string, write: { includeSource: boolean } | { includeExternalRefs: boolean }) => Promise<void>;
  onRemove: (key: string) => Promise<void>;
}) {
  const title = seed.header ?? seed.key;
  return (
    <li className="visit-document">
      <p className="visit-document-title">{title}</p>
      {seed.volumeTitle && <p className="meta">{seed.volumeTitle}</p>}
      {!seed.includeSource && !seed.includeExternalRefs && <p className="count warning">{copy.visits.nothing}</p>}
      {seed.hasSourceNote !== false ? (
        <label>
          <input type="checkbox" checked={seed.includeSource} onChange={(event) => void onSwitch(seed.key, { includeSource: event.target.checked })} />{' '}
          {copy.visits.source}
        </label>
      ) : (
        <p className="meta">{copy.visits.noSource}</p>
      )}
      {seed.referenceCount === 0 ? (
        <p className="meta">{copy.visits.noRefs}</p>
      ) : (
        <label>
          <input
            type="checkbox"
            checked={seed.includeExternalRefs}
            onChange={(event) => void onSwitch(seed.key, { includeExternalRefs: event.target.checked })}
          />{' '}
          {seed.referenceCount != null ? copy.visits.refsCounted(seed.referenceCount) : copy.visits.refs}
        </label>
      )}
      <div className="visit-document-actions">
        {seed.volumeId && seed.documentId && (
          <Link to="/doc/$volumeId/$documentId" params={{ volumeId: seed.volumeId, documentId: seed.documentId }}>
            {copy.visits.open}
          </Link>
        )}
        <button type="button" aria-label={copy.visits.removeSeed(title)} onClick={() => void onRemove(seed.key)}>
          {copy.visits.remove}
        </button>
      </div>
    </li>
  );
}

/** Target Note: the note as typed, trimmed by the server's rule, an empty one clearing it. */
function NoteDialog({
  title,
  fieldLabel,
  initial,
  onSave,
  onClose,
}: {
  title: string;
  fieldLabel: string;
  initial: string;
  onSave: (note: string) => Promise<unknown>;
  onClose: () => void;
}) {
  const headingId = useId();
  const field = useRef<HTMLInputElement>(null);
  const [draft, setDraft] = useState(initial);
  const [failure, setFailure] = useState<string | null>(null);
  function close() {
    field.current?.closest('dialog')?.close();
  }
  async function save() {
    try {
      await onSave(draft);
      closeAtOnce(close);
    } catch (error) {
      setFailure(errorMessage(error));
    }
  }
  return (
    <Modal className="visit-note-dialog" labelledBy={headingId} initial={field} onCancel={close} onClose={onClose}>
      <form
        onSubmit={(event) => {
          event.preventDefault();
          void save();
        }}
      >
        <h2 id={headingId} tabIndex={-1}>
          {title}
        </h2>
        <label>
          {fieldLabel}{' '}
          <input ref={field} type="text" value={draft} onChange={(event) => setDraft(event.target.value)} />
        </label>
        {failure && (
          <p className="error" role="alert">
            {failure}
          </p>
        )}
        <div className="actions">
          <button type="button" onClick={close}>
            {copy.visits.cancel}
          </button>
          <button type="submit">{copy.visits.save}</button>
        </div>
      </form>
    </Modal>
  );
}

/** A question before a destructive write: its title, its message, Cancel first. */
function ConfirmDialog({
  title,
  message,
  confirm,
  onConfirm,
  onClose,
}: {
  title: string;
  message: ReactNode;
  confirm: string;
  onConfirm: () => Promise<unknown>;
  onClose: () => void;
}) {
  const headingId = useId();
  const messageId = useId();
  const cancel = useRef<HTMLButtonElement>(null);
  const [failure, setFailure] = useState<string | null>(null);
  function close() {
    cancel.current?.closest('dialog')?.close();
  }
  async function act() {
    try {
      await onConfirm();
      closeAtOnce(close);
    } catch (error) {
      setFailure(errorMessage(error));
    }
  }
  return (
    <Modal className="confirm" role="alertdialog" labelledBy={headingId} describedBy={messageId} initial={cancel} onCancel={close} onClose={onClose}>
      <h2 id={headingId} tabIndex={-1}>
        {title}
      </h2>
      <div id={messageId}>{typeof message === 'string' ? <p>{message}</p> : message}</div>
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      <div className="actions">
        <button ref={cancel} type="button" onClick={close}>
          {copy.visits.cancel}
        </button>
        <button type="button" className="destructive" onClick={() => void act()}>
          {confirm}
        </button>
      </div>
    </Modal>
  );
}

/** Replace the inquiry topic?: each quoted text a paragraph of its own; Keep Current Topic is the cancel. */
function TopicDialog({
  question,
  current,
  onReplace,
  onClose,
}: {
  question: string;
  current: string;
  onReplace: () => Promise<unknown>;
  onClose: () => void;
}) {
  const headingId = useId();
  const messageId = useId();
  const keep = useRef<HTMLButtonElement>(null);
  const [failure, setFailure] = useState<string | null>(null);
  function close() {
    keep.current?.closest('dialog')?.close();
  }
  async function replace() {
    try {
      await onReplace();
      closeAtOnce(close);
    } catch (error) {
      setFailure(errorMessage(error));
    }
  }
  return (
    <Modal className="confirm" role="alertdialog" labelledBy={headingId} describedBy={messageId} initial={keep} onCancel={close} onClose={onClose}>
      <h2 id={headingId} tabIndex={-1}>
        {copy.visits.topicTitle}
      </h2>
      <div id={messageId}>
        <p>{copy.visits.topicNow}</p>
        <p>{copy.visits.quoted(question)}</p>
        <p>{copy.visits.topicDrafts}</p>
        <p>{copy.visits.quoted(current)}</p>
        <p>{copy.visits.topicAsk}</p>
      </div>
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      <div className="actions">
        <button ref={keep} type="button" onClick={close}>
          {copy.visits.topicKeep}
        </button>
        <button type="button" onClick={() => void replace()}>
          {copy.visits.topicReplace}
        </button>
      </div>
    </Modal>
  );
}

/** Priority Tiers (artboard 1c): each tier with its members, renamed, moved a step, or deleted after a question. */
function TiersDialog({ plan, onClose }: { plan: VisitPlan; onClose: () => void }) {
  const client = useQueryClient();
  const headingId = useId();
  const done = useRef<HTMLButtonElement>(null);
  const add = useRef<HTMLButtonElement>(null);
  const [renaming, setRenaming] = useState<VisitTier | null>(null);
  const [deleting, setDeleting] = useState<VisitTier | null>(null);
  const [failure, setFailure] = useState<string | null>(null);
  const list = useRef<HTMLOListElement>(null);
  /** The tier whose menu a write was chosen from, which a move takes elsewhere in the list, dropping the focus it held. */
  const moved = useRef<string | null>(null);
  // The plan as its last write left it, which the sheet shows.
  const { data } = useQuery({ ...visitQuery(plan.id), initialData: plan });
  const tiers = data.tiers;
  function close() {
    done.current?.closest('dialog')?.close();
  }
  /** The menu button of the tier `id`, wherever it now sits, if the plan still has it. */
  function tierMenu(id: string): HTMLElement | null {
    const row = [...(list.current?.querySelectorAll<HTMLElement>('li[data-tier]') ?? [])].find((item) => item.dataset.tier === id);
    return row?.querySelector<HTMLElement>('.menu-button > button') ?? null;
  }
  useEffect(() => {
    const id = moved.current;
    if (id === null) return;
    moved.current = null;
    tierMenu(id)?.focus();
  }, [tiers]);
  /** Back to the tier's menu once a dialog over the sheet closes, else to the tier after it, else to Add. */
  function backTo(id: string, index: number) {
    requestAnimationFrame(() => {
      const after = tiers.filter((tier) => tier.id !== id)[index] ?? tiers.filter((tier) => tier.id !== id)[index - 1];
      (tierMenu(id) ?? (after ? tierMenu(after.id) : null) ?? add.current)?.focus();
    });
  }
  async function run(write: () => Promise<unknown>) {
    setFailure(null);
    try {
      await write();
    } catch (error) {
      setFailure(errorMessage(error));
    }
  }
  return (
    <Modal className="visit-tiers" labelledBy={headingId} onCancel={close} onClose={onClose}>
      <h2 id={headingId} tabIndex={-1}>
        {copy.visits.tiersTitle}
      </h2>
      <ol ref={list} className="visit-tier-list">
        {tiers.map((tier, index) => (
          <li key={tier.id} data-tier={tier.id}>
            <span className="visit-tier-name">{tier.displayName}</span>
            <span className="meta">{copy.visits.members(tier.members)}</span>
            <MenuButton
              label="⋯"
              accessibleLabel={copy.visits.tierActions(tier.displayName)}
              entries={[
                { kind: 'item', label: copy.visits.rename, onSelect: () => setRenaming(tier) },
                {
                  kind: 'item',
                  label: copy.visits.moveUp,
                  disabled: index === 0,
                  onSelect: () => {
                    moved.current = tier.id;
                    void run(() => moveTier(client, plan.id, tier.id, -1));
                  },
                },
                {
                  kind: 'item',
                  label: copy.visits.moveDown,
                  disabled: index === tiers.length - 1,
                  onSelect: () => {
                    moved.current = tier.id;
                    void run(() => moveTier(client, plan.id, tier.id, 1));
                  },
                },
                { kind: 'separator' },
                { kind: 'item', label: copy.visits.delete, destructive: true, onSelect: () => setDeleting(tier) },
              ]}
            />
          </li>
        ))}
      </ol>
      <button ref={add} type="button" onClick={() => void run(() => addTier(client, plan.id))}>
        {copy.visits.addTier}
      </button>
      <p className="note">{copy.visits.tiersFooter}</p>
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      <div className="actions">
        <button ref={done} type="button" onClick={close}>
          {copy.visits.done}
        </button>
      </div>
      {renaming && (
        <NoteDialog
          title={copy.visits.renameTier}
          fieldLabel={copy.visits.tierLabel}
          initial={renaming.label ?? ''}
          onSave={(label) => relabelTier(client, plan.id, renaming.id, label)}
          onClose={() => {
            const { id } = renaming;
            setRenaming(null);
            backTo(id, tiers.findIndex((tier) => tier.id === id));
          }}
        />
      )}
      {deleting && (
        <ConfirmDialog
          title={copy.visits.deleteTierTitle(deleting.displayName)}
          message={copy.visits.deleteTierMessage(deleting.members)}
          confirm={copy.visits.deleteTier}
          onConfirm={() => deleteTier(client, plan.id, deleting.id)}
          onClose={() => {
            const { id } = deleting;
            setDeleting(null);
            backTo(id, tiers.findIndex((tier) => tier.id === id));
          }}
        />
      )}
    </Modal>
  );
}

