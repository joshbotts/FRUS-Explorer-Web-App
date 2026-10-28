// Browse's Working Corpora axis (S17e), as the Mac's lists and opens them (`CorporaIndexView`,
// `CorpusDocumentsView`): the user's corpora, the most recently captured first, each with its count,
// where it came from and when, and the kit's line for a capture that was not every match; and a corpus
// opened, its coverage on this server once at the top, its documents in one section a volume, those of
// a volume the server holds opening in the reader and the rest named, never a dead end. Browse lists and
// opens corpora; Search captures them. Rename and Delete are the web's own, where the Mac keeps them in
// its Settings.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { getRouteApi, Link, useNavigate } from '@tanstack/react-router';
import { useId, useRef, useState } from 'react';
import { ApiError, errorMessage } from '../api/client';
import { deleteCorpus, renameCorpus, workingCorporaQuery, workingCorpusQuery, type WorkingCorpus } from '../api/searchSets';
import { copy } from '../copy';
import { useHeadingReady } from '../shell/headingFocus';
import { closeAtOnce, Modal } from '../shell/Modal';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import { corpusName } from '../search/WorkingCorpora';
import { BrowseAxes } from './BrowseAxes';
import { Breadcrumb } from './Breadcrumb';

/** A day as the Mac's lists print one, abbreviated: Oct 24, 2026. */
export function shortDate(text: string | undefined): string | undefined {
  if (!text) return undefined;
  const date = new Date(text);
  return Number.isNaN(date.getTime()) ? undefined : date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

/** A corpus row's caption, as `CorporaAxis.rowCaption` gives it: count · origin · capture date. */
export function corpusCaption(corpus: WorkingCorpus): string {
  const parts = [copy.corpora.rowCount(corpus.documentCount)];
  if (corpus.sourceDescription) parts.push(corpus.sourceDescription);
  else if (corpus.sourceQuery) parts.push(copy.corpora.capturedFrom(quotable(corpus.sourceQuery)));
  const captured = shortDate(corpus.capturedAt);
  if (captured) parts.push(captured);
  return parts.join(' · ');
}

/** A query quoted once: one that is a single phrase in its own marks loses them (`QueryQuoting.quotable`). */
export function quotable(query: string): string {
  const trimmed = query.trim();
  const inner = trimmed.slice(1, -1);
  return trimmed.length >= 2 && trimmed.startsWith('"') && trimmed.endsWith('"') && !inner.includes('"') ? inner : trimmed;
}

export function CorporaScreen() {
  const corpora = useQuery(workingCorporaQuery);
  useDocumentTitle(copy.corpora.title);
  useHeadingReady(!corpora.isPending);
  const items = corpora.data?.items;
  return (
    <section className="screen browse corpora">
      <h1 tabIndex={-1}>{copy.corpora.title}</h1>
      <BrowseAxes current="corpora" />
      {corpora.isError ? (
        <p className="error" role="alert">
          {errorMessage(corpora.error)}
        </p>
      ) : !items ? (
        <p role="status">{copy.browse.loading}</p>
      ) : items.length === 0 ? (
        <div className="empty">
          <h2>{copy.corpora.emptyTitle}</h2>
          <p>{copy.corpora.emptyDetail}</p>
        </div>
      ) : (
        <>
          <ul className="volume-list" aria-label={copy.corpora.title}>
            {items.map((corpus) => (
              <li key={corpus.id} className="volume-row">
                <Link
                  to="/browse/corpora/$corpusId"
                  params={{ corpusId: corpus.id }}
                  title={copy.corpora.rowHelp}
                  aria-label={copy.corpora.rowLabel(corpusName(corpus), corpus.documentCount)}
                >
                  {corpusName(corpus)}
                </Link>
                <p className="meta">{corpusCaption(corpus)}</p>
                {corpus.truncationLine && <p className={corpus.truncationWarns ? 'meta warning' : 'meta'}>{corpus.truncationLine}</p>}
              </li>
            ))}
          </ul>
          <p className="note">{copy.corpora.listFooter}</p>
        </>
      )}
    </section>
  );
}

const corpusRoute = getRouteApi('/browse/corpora/$corpusId');

export function CorpusScreen() {
  const { corpusId } = corpusRoute.useParams();
  const detail = useQuery(workingCorpusQuery(corpusId));
  const corpus = detail.data?.corpus;
  const title = corpus ? corpusName(corpus) : copy.corpora.title;
  useDocumentTitle(title);
  useHeadingReady(!detail.isPending);
  const gone = detail.error instanceof ApiError && detail.error.code === 'CORPUS_NOT_FOUND';
  const [dialog, setDialog] = useState<'rename' | 'delete' | null>(null);
  const opener = useRef<HTMLButtonElement>(null);
  const navigate = useNavigate();
  return (
    <section className="screen browse corpus">
      <Breadcrumb crumbs={[{ label: copy.corpora.title, axis: 'corpora' }]} current={title} />
      <h1 tabIndex={-1} data-loading={detail.isPending ? 'true' : undefined}>
        {gone ? copy.corpora.unavailableTitle : title}
      </h1>
      {gone ? (
        <p>{copy.corpora.unavailableDetail}</p>
      ) : detail.isError ? (
        <p className="error" role="alert">
          {errorMessage(detail.error)}
        </p>
      ) : !detail.data || !corpus ? (
        <p role="status">{copy.browse.loading}</p>
      ) : (
        <>
          <p className="meta">{corpusCaption(corpus)}</p>
          {corpus.coverage && (
            // Once, at the top, in the resolver's words; the list below never blocks.
            <p className={corpus.coverage.isComplete ? 'count' : 'count warning'}>
              {copy.corpora.coverage(corpus.coverage.indexedCount, corpus.coverage.totalCount)}
            </p>
          )}
          {corpus.truncationLine && <p className={corpus.truncationWarns ? 'note warning' : 'note'}>{corpus.truncationLine}</p>}
          <div className="manage">
            <button
              type="button"
              onClick={(event) => {
                opener.current = event.currentTarget;
                setDialog('rename');
              }}
            >
              {copy.corpora.rename}
            </button>
            <button
              type="button"
              className="destructive"
              onClick={(event) => {
                opener.current = event.currentTarget;
                setDialog('delete');
              }}
            >
              {copy.corpora.delete}
            </button>
          </div>
          {detail.data.sections.map((section) => (
            <section key={section.volumeId} className="corpus-volume" aria-labelledby={`corpus-${section.volumeId}`}>
              <h2 id={`corpus-${section.volumeId}`}>{section.title ?? section.volumeId}</h2>
              <ol className="document-list">
                {section.documents.map((document) =>
                  section.indexed ? (
                    <li key={document.documentId}>
                      <Link to="/doc/$volumeId/$documentId" params={{ volumeId: document.volumeId, documentId: document.documentId }}>
                        {document.displayTitle ?? document.documentId}
                      </Link>
                      {document.dateISO && <p className="meta">{document.dateISO}</p>}
                    </li>
                  ) : (
                    <li key={document.documentId} className="not-indexed">
                      <span>
                        {document.volumeId} · {document.documentId}
                      </span>
                      <p className="meta">{copy.corpora.notIndexed}</p>
                    </li>
                  ),
                )}
              </ol>
            </section>
          ))}
          {dialog === 'rename' && (
            <RenameCorpusDialog
              corpus={corpus}
              onClose={() => {
                setDialog(null);
                opener.current?.focus();
              }}
            />
          )}
          {dialog === 'delete' && (
            <DeleteCorpusDialog
              corpus={corpus}
              onClose={(deleted) => {
                setDialog(null);
                if (deleted) void navigate({ to: '/browse/corpora' });
                else opener.current?.focus();
              }}
            />
          )}
        </>
      )}
    </section>
  );
}

function RenameCorpusDialog({ corpus, onClose }: { corpus: WorkingCorpus; onClose: () => void }) {
  const client = useQueryClient();
  const headingId = useId();
  const field = useRef<HTMLInputElement>(null);
  const body = useRef<HTMLDivElement>(null);
  const [name, setName] = useState(corpus.name);
  const [failure, setFailure] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  function close() {
    body.current?.closest('dialog')?.close();
  }
  async function save() {
    if (name.trim() === '' || busy) return;
    setBusy(true);
    try {
      await renameCorpus(client, corpus.id, name);
      closeAtOnce(close);
    } catch (error) {
      setBusy(false);
      setFailure(errorMessage(error));
    }
  }
  return (
    <Modal className="rename-corpus" labelledBy={headingId} initial={field} onCancel={close} onClose={onClose}>
      <div ref={body}>
        <h2 id={headingId} tabIndex={-1}>
          {copy.corpora.renameTitle}
        </h2>
        <form
          onSubmit={(event) => {
            event.preventDefault();
            void save();
          }}
        >
          <input
            ref={field}
            type="text"
            value={name}
            aria-label={copy.corpora.nameHeader}
            placeholder={copy.corpora.namePlaceholder}
            onChange={(event) => setName(event.target.value)}
          />
        </form>
        {failure && (
          <p className="error" role="alert">
            {failure}
          </p>
        )}
        <div className="actions">
          <button type="button" onClick={close}>
            {copy.corpora.cancel}
          </button>
          <button type="button" disabled={name.trim() === '' || busy} onClick={() => void save()}>
            {copy.corpora.saveButton}
          </button>
        </div>
      </div>
    </Modal>
  );
}

function DeleteCorpusDialog({ corpus, onClose }: { corpus: WorkingCorpus; onClose: (deleted: boolean) => void }) {
  const client = useQueryClient();
  const headingId = useId();
  const messageId = useId();
  const cancel = useRef<HTMLButtonElement>(null);
  const deleted = useRef(false);
  const [failure, setFailure] = useState<string | null>(null);
  function close() {
    cancel.current?.closest('dialog')?.close();
  }
  async function remove() {
    try {
      await deleteCorpus(client, corpus.id);
      deleted.current = true;
      closeAtOnce(close);
    } catch (error) {
      setFailure(errorMessage(error));
    }
  }
  return (
    <Modal
      className="confirm"
      role="alertdialog"
      labelledBy={headingId}
      describedBy={messageId}
      initial={cancel}
      onCancel={close}
      onClose={() => onClose(deleted.current)}
    >
      <h2 id={headingId} tabIndex={-1}>
        {copy.corpora.deleteTitle}
      </h2>
      <p id={messageId}>{copy.corpora.deleteMessage}</p>
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      <div className="actions">
        <button ref={cancel} type="button" onClick={close}>
          {copy.corpora.cancel}
        </button>
        <button type="button" className="destructive" onClick={() => void remove()}>
          {copy.corpora.deleteConfirm}
        </button>
      </div>
    </Modal>
  );
}
