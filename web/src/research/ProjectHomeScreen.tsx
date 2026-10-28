// Project Home (PLAN's S17f), as the app's `ProjectHomeView` lays it out: the project's name, its
// research question, saved as it is typed, and its date focus; the summary's tiles, with a tile for
// each corpus its searches ran inside; its focus tags, once the reader has tags, with their editor;
// Suggested Next, the leads the Mac found, until Related Documents finds them here, each with Dismiss;
// Recent Activity; and the quick ways to Research and Search. The app's Focus subjects wait for the
// kit's subject profiles, its Collections section and Plan a Visit for the rows that bring them, and
// its weighting and Refresh for Related Documents.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { getRouteApi, Link } from '@tanstack/react-router';
import { useEffect, useEffectEvent, useId, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import { dismissLead, projectHomeQuery, type ProjectHome, updateProject } from '../api/research';
import { meQuery, tagsQuery } from '../api/userData';
import { copy } from '../copy';
import { useHeadingReady } from '../shell/headingFocus';
import { Modal } from '../shell/Modal';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import { dateFocusText, leadContext, trimmedQuestion } from './projectRules';

const route = getRouteApi('/projects/$projectId');

/** How long the research question waits after a key before it is saved: the app saves each edit. */
const questionPause = 600;

export function ProjectHomeScreen() {
  const { projectId } = route.useParams();
  const client = useQueryClient();
  const me = useQuery(meQuery);
  const keepsUserData = me.data?.userData === true;
  const home = useQuery({ ...projectHomeQuery(projectId), enabled: keepsUserData });
  const project = home.data?.project;
  useDocumentTitle(project?.name ?? copy.projectHome.title);
  useHeadingReady(!home.isPending || me.data?.userData === false);

  let body;
  if (me.data && !keepsUserData) {
    body = <p>{copy.settings.userDataOff}</p>;
  } else if (home.isError) {
    body = (
      <>
        <h2>{copy.projectHome.missingTitle}</h2>
        <p>{copy.projectHome.missingDetail}</p>
        <p className="error" role="alert">
          {errorMessage(home.error)}
        </p>
      </>
    );
  } else if (!home.data) {
    body = <p role="status">{copy.projectHome.loading}</p>;
  } else {
    body = <Workspace home={home.data} onFailure={() => void client.invalidateQueries({ queryKey: ['projectHome', projectId] })} />;
  }

  return (
    <div className="project-home">
      <h1 tabIndex={-1} data-loading={home.isPending && keepsUserData ? 'true' : undefined}>
        {project?.name ?? copy.projectHome.title}
      </h1>
      {body}
    </div>
  );
}

function Workspace({ home, onFailure }: { home: ProjectHome; onFailure: () => void }) {
  const project = home.project;
  const dateFocus = dateFocusText(project);
  return (
    <>
      <Question projectId={project.id} question={project.researchQuestion ?? ''} />
      {dateFocus && <p className="date-focus">{dateFocus}</p>}
      <ul className="stat-tiles" aria-label={copy.projectHome.title}>
        <Tile label={copy.projectHome.statCollections} value={home.counts.collections} />
        <Tile label={copy.projectHome.statNotes} value={home.counts.notes} />
        <Tile label={copy.projectHome.statVisited} value={home.counts.documentsVisited} />
        <Tile label={copy.projectHome.statSearches} value={home.counts.searches} />
        {home.coverage.map((tile) => (
          <li key={tile.corpusId} className="tile coverage" aria-label={`${tile.corpusName}: ${tile.description}`}>
            <span className="tile-label">{tile.corpusName}</span>
            <span className="tile-value">
              {tile.engagedCount}/{tile.totalCount}
            </span>
            <span className="tile-caption">{tile.untouched}</span>
            {tile.truncationLine && <span className={tile.truncationWarns ? 'tile-caption warn' : 'tile-caption'}>{tile.truncationLine}</span>}
          </li>
        ))}
      </ul>
      {home.hasTags && <FocusTags home={home} />}
      <Leads home={home} onFailure={onFailure} />
      <Recent home={home} />
      <nav className="quick-actions" aria-label={copy.projectHome.title}>
        <Link to="/research">{copy.projectHome.actionResearch}</Link>
        <Link to="/search">{copy.projectHome.actionSearch}</Link>
      </nav>
    </>
  );
}

function Tile({ label, value }: { label: string; value: number }) {
  return (
    <li className="tile">
      <span className="tile-label">{label}</span>
      <span className="tile-value">{value}</span>
    </li>
  );
}

/** The research question, saved as it is typed, as the app saves each edit, trimmed, and none when empty. */
function Question({ projectId, question }: { projectId: string; question: string }) {
  const client = useQueryClient();
  const [draft, setDraft] = useState(question);
  const [failure, setFailure] = useState<string | null>(null);
  const saved = useRef(trimmedQuestion(question));
  const timer = useRef<number | undefined>(undefined);

  async function commit(text: string) {
    window.clearTimeout(timer.current);
    const trimmed = trimmedQuestion(text);
    if (trimmed === saved.current) return;
    saved.current = trimmed;
    try {
      setFailure(null);
      await updateProject(client, projectId, { researchQuestion: trimmed });
    } catch (error) {
      setFailure(errorMessage(error));
    }
  }
  const flush = useEffectEvent(() => void commit(draft));
  useEffect(() => () => flush(), []);

  return (
    <div className="research-question">
      <textarea
        value={draft}
        rows={2}
        placeholder={copy.projectHome.questionPlaceholder}
        aria-label={copy.projects.questionField}
        onChange={(event) => {
          const text = event.target.value;
          setDraft(text);
          window.clearTimeout(timer.current);
          timer.current = window.setTimeout(() => void commit(text), questionPause);
        }}
        onBlur={() => void commit(draft)}
      />
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
    </div>
  );
}

function FocusTags({ home }: { home: ProjectHome }) {
  const [editing, setEditing] = useState(false);
  const opener = useRef<HTMLButtonElement>(null);
  const headingId = useId();
  return (
    <section className="focus-tags" aria-labelledby={headingId}>
      <div className="section-header">
        <h2 id={headingId}>{copy.projectHome.focusTags}</h2>
        <button ref={opener} type="button" aria-haspopup="dialog" onClick={() => setEditing(true)}>
          {home.focusTags.length === 0 ? copy.projectHome.focusAdd : copy.projectHome.focusEdit}
        </button>
      </div>
      {home.focusTags.length === 0 ? (
        <p className="note">{copy.projectHome.focusEmpty}</p>
      ) : (
        <ul className="chips">
          {home.focusTags.map((tag) => (
            <li key={tag.id}>{tag.name}</li>
          ))}
        </ul>
      )}
      {editing && (
        <FocusTagsEditor
          projectId={home.project.id}
          chosen={home.focusTags.map((tag) => tag.id)}
          onClose={() => {
            setEditing(false);
            opener.current?.focus();
          }}
        />
      )}
    </section>
  );
}

/** The focus tags' editor, as the app's `ProjectFocusTagsEditor`: each of the reader's tags a switch, saved at once. */
function FocusTagsEditor({ projectId, chosen, onClose }: { projectId: string; chosen: string[]; onClose: () => void }) {
  const client = useQueryClient();
  const tags = useQuery(tagsQuery);
  const headingId = useId();
  const [ids, setIds] = useState(chosen);
  const [failure, setFailure] = useState<string | null>(null);
  const body = useRef<HTMLDivElement>(null);

  async function toggle(id: string) {
    const next = ids.includes(id) ? ids.filter((held) => held !== id) : [...ids, id];
    setIds(next);
    setFailure(null);
    try {
      await updateProject(client, projectId, { defaultUserTagIds: next });
    } catch (error) {
      setFailure(errorMessage(error));
    }
  }

  const close = () => body.current?.closest('dialog')?.close();
  const items = tags.data?.items ?? [];
  return (
    <Modal className="focus-tags-editor" labelledBy={headingId} onCancel={close} onClose={onClose}>
      <div ref={body}>
        <h2 id={headingId} tabIndex={-1}>
          {copy.projectHome.focusTagsTitle}
        </h2>
        {tags.data && items.length === 0 ? (
          <>
            <h3>{copy.projectHome.focusTagsNoneTitle}</h3>
            <p>{copy.projectHome.focusTagsNone}</p>
          </>
        ) : (
          <>
            <ul className="toggles">
              {items.map((tag) => (
                <li key={tag.id}>
                  <label>
                    <input type="checkbox" checked={ids.includes(tag.id)} onChange={() => void toggle(tag.id)} /> {tag.name}
                  </label>
                </li>
              ))}
            </ul>
            <p className="note">{copy.projectHome.focusTagsFooter}</p>
          </>
        )}
        {failure && (
          <p className="error" role="alert">
            {failure}
          </p>
        )}
        <div className="actions">
          <button type="button" onClick={close}>
            {copy.projectHome.focusTagsDone}
          </button>
        </div>
      </div>
    </Modal>
  );
}

function Leads({ home, onFailure }: { home: ProjectHome; onFailure: () => void }) {
  const client = useQueryClient();
  const headingId = useId();
  const heading = useRef<HTMLHeadingElement>(null);
  const [failure, setFailure] = useState<string | null>(null);

  async function dismiss(leadId: string, index: number, list: HTMLElement | null) {
    setFailure(null);
    try {
      await dismissLead(client, home.project.id, leadId);
      // The focus goes on to the next lead's ×, or the last, or the section's heading for none.
      const buttons = [...(list?.querySelectorAll<HTMLButtonElement>('button.dismiss') ?? [])].filter(
        (button) => button.dataset.lead !== leadId,
      );
      (buttons[index] ?? buttons[index - 1] ?? heading.current)?.focus();
    } catch (error) {
      setFailure(errorMessage(error));
      onFailure();
    }
  }

  return (
    <section className="leads" aria-labelledby={headingId}>
      <h2 id={headingId} ref={heading} tabIndex={-1}>
        {copy.projectHome.leadsTitle}
      </h2>
      {home.leads.length === 0 ? (
        <p className="note">{copy.projectHome.leadsPlaceholder}</p>
      ) : (
        <ul className="lead-list">
          {home.leads.map((lead, index) => (
            <li key={lead.id}>
              <div className="lead">
                <Link to="/doc/$volumeId/$documentId" params={{ volumeId: lead.volumeId, documentId: lead.documentId }}>
                  {lead.title}
                </Link>
                {lead.isNew && <span className="badge">{copy.projectHome.leadNew}</span>}
                <span className="lead-context">{leadContext(lead)}</span>
              </div>
              <button
                type="button"
                className="dismiss"
                data-lead={lead.id}
                aria-label={copy.projectHome.dismissNamed(lead.title)}
                title={copy.projectHome.dismiss}
                onClick={(event) => void dismiss(lead.id, index, event.currentTarget.closest('ul'))}
              >
                <span aria-hidden="true">×</span>
              </button>
            </li>
          ))}
        </ul>
      )}
      <p className="note">{copy.projectHome.leadsFromMac}</p>
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
    </section>
  );
}

function Recent({ home }: { home: ProjectHome }) {
  const headingId = useId();
  return (
    <section className="recent" aria-labelledby={headingId}>
      <h2 id={headingId}>{copy.projectHome.recentTitle}</h2>
      {home.isEmpty ? (
        <p className="note">{copy.projectHome.recentEmpty}</p>
      ) : (
        <>
          {home.recentVisits.length > 0 && (
            <>
              <h3>{copy.projectHome.recentDocuments}</h3>
              <ul>
                {home.recentVisits.map((visit) => (
                  <li key={`${visit.volumeId}/${visit.documentId}`}>
                    <Link to="/doc/$volumeId/$documentId" params={{ volumeId: visit.volumeId, documentId: visit.documentId }}>
                      {visit.title}
                    </Link>
                  </li>
                ))}
              </ul>
            </>
          )}
          {home.recentNotes.length > 0 && (
            <>
              <h3>{copy.projectHome.recentNotes}</h3>
              <ul>
                {home.recentNotes.map((note) => (
                  <li key={note.id}>
                    <Link to="/doc/$volumeId/$documentId" params={{ volumeId: note.volumeId, documentId: note.documentId }}>
                      {`${note.volumeId} · ${note.documentId}`}
                    </Link>
                  </li>
                ))}
              </ul>
            </>
          )}
          {home.recentSearches.length > 0 && (
            <>
              <h3>{copy.projectHome.recentSearches}</h3>
              <ul>
                {home.recentSearches.map((search) => (
                  <li key={search.id}>
                    <span>{search.queryText === '' ? copy.projectHome.untitledSearch : search.queryText}</span>{' '}
                    <span className="note">{copy.projectHome.results(search.resultCount)}</span>
                  </li>
                ))}
              </ul>
            </>
          )}
        </>
      )}
    </section>
  );
}
