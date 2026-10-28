// Working corpora and volume scopes in Search (S17e), as the Mac's window has them: Save as Working
// Corpus, the sheet that names a capture of the rows the search shows and says what it is, as the server
// counts it (`SaveWorkingCorpusSheet`); the banner over a search inside a corpus, whose ✕ leaves it; and
// the filter's My Working Corpora and My Volume Scopes, each row with what this server reaches of it,
// a corpus applied as the search's document gate, a scope filling the volume filter with its indexed
// members, and either refused with a warning, never searching unscoped, when the server holds none of it.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useId, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import {
  previewCapture,
  saveCorpus,
  volumeScopesQuery,
  workingCorporaQuery,
  type WorkingCorpus,
} from '../api/searchSets';
import { copy } from '../copy';
import { closeAtOnce, Modal } from '../shell/Modal';
import { filterFields, type SearchState } from './searchState';

/** A corpus's name in a list, or Untitled Corpus, as `CorporaAxis.displayName` gives it. */
export function corpusName(corpus: Pick<WorkingCorpus, 'name'>): string {
  return corpus.name === '' ? copy.corpora.untitled : corpus.name;
}

/** The Save Working Corpus sheet, over what the server would capture of the search's rows less `reviewed`. */
export function SaveCorpusDialog({ state, reviewed, onClose }: { state: SearchState; reviewed: readonly string[]; onClose: () => void }) {
  const client = useQueryClient();
  const headingId = useId();
  const field = useRef<HTMLInputElement>(null);
  const body = useRef<HTMLDivElement>(null);
  const [name, setName] = useState('');
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const preview = useQuery({
    queryKey: ['capturePreview', filterFields(state), reviewed],
    queryFn: () => previewCapture(client, state, reviewed),
    staleTime: 0,
    retry: false,
  });
  const corpora = useQuery(workingCorporaQuery);
  const trimmed = name.trim();
  // A warning, not a block: names are not unique, as the Mac's are not.
  const duplicate = trimmed !== '' && (corpora.data?.items ?? []).some((corpus) => corpus.name === trimmed);
  const captured = preview.data;
  const canSave = trimmed !== '' && captured !== undefined && captured.documentCount > 0 && !busy;

  function close() {
    body.current?.closest('dialog')?.close();
  }

  async function save() {
    if (!canSave) return;
    setBusy(true);
    setFailure(null);
    try {
      await saveCorpus(client, trimmed, state, reviewed);
      closeAtOnce(close);
    } catch (error) {
      setBusy(false);
      setFailure(errorMessage(error));
    }
  }

  return (
    <Modal className="save-corpus" labelledBy={headingId} initial={field} onCancel={close} onClose={onClose}>
      <div ref={body}>
        <h2 id={headingId} tabIndex={-1}>
          {copy.corpora.saveTitle}
        </h2>
        <form
          onSubmit={(event) => {
            event.preventDefault();
            void save();
          }}
        >
          <h3>{copy.corpora.nameHeader}</h3>
          <input
            ref={field}
            type="text"
            value={name}
            aria-label={copy.corpora.nameHeader}
            placeholder={copy.corpora.namePlaceholder}
            onChange={(event) => setName(event.target.value)}
          />
          {duplicate && <p className="warning">{copy.corpora.duplicate}</p>}
        </form>
        <h3>{copy.corpora.captured}</h3>
        {preview.isError ? (
          <p className="error" role="alert">
            {errorMessage(preview.error)}
          </p>
        ) : captured === undefined ? (
          <p role="status">{copy.corpora.preparing}</p>
        ) : (
          <>
            <dl className="captured">
              <dt>{copy.corpora.documents}</dt>
              <dd>{captured.documentCount.toLocaleString('en-US')}</dd>
              {captured.sourceQuery && (
                <>
                  <dt>{copy.corpora.from}</dt>
                  <dd>{captured.sourceQuery}</dd>
                </>
              )}
              {captured.narrowing.length > 0 && (
                <>
                  <dt>{copy.corpora.narrowedBy}</dt>
                  <dd>{captured.narrowing.join('; ')}</dd>
                </>
              )}
              <dt>{copy.corpora.indexedNow}</dt>
              <dd>{captured.indexedVolumeCount.toLocaleString('en-US')}</dd>
            </dl>
            {captured.truncationWarning && <p className="warning">⚠ {captured.truncationWarning}</p>}
            {captured.checklistWarning && <p className="warning">{captured.checklistWarning}</p>}
          </>
        )}
        <p className="note">{copy.corpora.footer}</p>
        {failure && (
          <p className="error" role="alert">
            {failure}
          </p>
        )}
        <div className="actions">
          <button type="button" onClick={close}>
            {copy.corpora.cancel}
          </button>
          <button type="button" disabled={!canSave} onClick={() => void save()}>
            {copy.corpora.saveButton}
          </button>
        </div>
      </div>
    </Modal>
  );
}

/** The applied working corpus, named over the results it governs, with the ✕ that leaves it. */
export function CorpusBanner({ state, onLeave }: { state: SearchState; onLeave: () => void }) {
  const corpora = useQuery(workingCorporaQuery);
  if (state.workingCorpusId === undefined) return null;
  const corpus = corpora.data?.items.find((item) => item.id === state.workingCorpusId);
  return (
    <div className="corpus-banner" role="group" aria-label={copy.corpora.filterTitle}>
      <span aria-hidden="true">▤ </span>
      <span className="name">{corpus ? copy.corpora.inside(corpusName(corpus)) : copy.corpora.insideUnknown}</span>
      <button type="button" className="chip" title={copy.corpora.leaveHelp} aria-label={copy.corpora.leave} onClick={onLeave}>
        ×
      </button>
    </div>
  );
}

/**
 * My Working Corpora, among the filters: each of the user's corpora, by name, with what this server
 * reaches of it and where it came from, applied by a click, or refused with a warning when the server
 * holds none of it, as an empty gate would read as no matches; the applied one checked, and Clear.
 */
export function CorpusFilter({ state, update }: { state: SearchState; update: (changes: Partial<SearchState>) => void }) {
  const corpora = useQuery(workingCorporaQuery);
  const [warning, setWarning] = useState<string | null>(null);
  const items = [...(corpora.data?.items ?? [])].sort((a, b) => a.name.localeCompare(b.name, 'en-US'));
  if (items.length === 0) return null;
  const applied = items.find((corpus) => corpus.id === state.workingCorpusId);
  const summary = applied
    ? [copy.corpora.inside(corpusName(applied)), applied.sourceDescription].filter(Boolean).join(' · ')
    : copy.search.myTagsSummary(0);
  return (
    <details className="corpus-filter">
      <summary>
        {copy.corpora.filterTitle} <span className="count">{summary}</span>
      </summary>
      <ul>
        {items.map((corpus) => {
          const isApplied = corpus.id === state.workingCorpusId;
          return (
            <li key={corpus.id}>
              <button
                type="button"
                aria-pressed={isApplied}
                onClick={() => {
                  // Refused rather than an empty gate, which would read as no matches for the query.
                  if (corpus.coverage && corpus.coverage.indexedCount === 0) {
                    setWarning(corpus.id);
                    return;
                  }
                  setWarning(null);
                  update({ workingCorpusId: corpus.id });
                }}
              >
                <span className="name">
                  {corpusName(corpus)}
                  {isApplied && <span aria-hidden="true"> ✓</span>}
                </span>
                {corpus.coverage && (
                  <span className={corpus.coverage.isComplete ? 'caption' : 'caption warning'}>
                    {copy.corpora.coverage(corpus.coverage.indexedCount, corpus.coverage.totalCount)}
                  </span>
                )}
                {corpus.sourceDescription && <span className="caption">{corpus.sourceDescription}</span>}
              </button>
              {warning === corpus.id && (
                <p className="warning" role="alert">
                  ⚠ {copy.corpora.noneIndexed(corpusName(corpus))}
                </p>
              )}
            </li>
          );
        })}
      </ul>
      {state.workingCorpusId !== undefined && (
        <button type="button" className="destructive" onClick={() => update({ workingCorpusId: undefined })}>
          {copy.corpora.clear}
        </button>
      )}
      <p className="caption">{copy.corpora.filterFooter}</p>
    </details>
  );
}

/**
 * My Volume Scopes, among the filters: each of the user's scopes, by name, with how many of its
 * volumes this server indexes, applied by a click, which fills the volume filter with those, as the
 * kit resolves a scope; or refused with a warning when the server indexes none of them.
 */
export function ScopeFilter({ update }: { update: (changes: Partial<SearchState>) => void }) {
  const scopes = useQuery(volumeScopesQuery);
  const [warning, setWarning] = useState<string | null>(null);
  const items = [...(scopes.data?.items ?? [])].sort((a, b) => a.name.localeCompare(b.name, 'en-US'));
  if (items.length === 0) return null;
  return (
    <details className="scope-filter">
      <summary>
        {copy.scopes.filterTitle} <span className="count">{copy.search.myTagsSummary(items.length)}</span>
      </summary>
      <ul>
        {items.map((scope) => {
          const name = scope.name === '' ? copy.scopes.untitled : scope.name;
          return (
            <li key={scope.id}>
              <button
                type="button"
                title={copy.scopes.applyHint}
                onClick={() => {
                  if (scope.indexedResolution === 'resolved' && scope.indexedVolumeIds) {
                    setWarning(null);
                    update({ volumeIds: scope.indexedVolumeIds });
                  } else {
                    setWarning(scope.id);
                  }
                }}
              >
                <span className="name">{name}</span>
                <span className="caption">
                  {scope.indexedVolumeIds
                    ? copy.scopes.indexedOf(scope.indexedVolumeIds.length, scope.volumeIds.length)
                    : copy.scopes.noneIndexedRow}
                </span>
              </button>
              {warning === scope.id && (
                <p className="warning" role="alert">
                  ⚠ {copy.scopes.noneIndexed(name)}
                </p>
              )}
            </li>
          );
        })}
      </ul>
      <p className="caption">{copy.scopes.filterFooter}</p>
    </details>
  );
}
