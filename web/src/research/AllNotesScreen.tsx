// All Notes (PLAN's S15d), the app's Research destination for every note of the user's, at
// /research/notes until S19b's Research page holds it: its Project, Tag and search filters, which
// the URL keeps, the count its sheet gives, and its rows, the last changed first, each opening the
// note in the editor, as the app's opens its sheet. Each row's Delete… asks the app's Delete Note?
// question; it is a button of its own, the web's own, where the app's is in a context menu.
import { useQuery } from '@tanstack/react-query';
import { getRouteApi } from '@tanstack/react-router';
import { useId, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import type { NoteSummary } from '../api/types';
import { meQuery, notesQuery, projectsQuery, tagsQuery } from '../api/userData';
import { copy } from '../copy';
import { useHeadingReady } from '../shell/headingFocus';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import { DeleteNote } from './DeleteNote';
import { NoteEditor } from './NoteEditor';
import { countLine, filterNotes, noteDate, noteDetail, noteTitle } from './notesRules';

const route = getRouteApi('/research/notes');

export interface NotesSearch {
  /** The search field's text, as typed. */
  q?: string;
  /** A project's id, or `unfiled` for Not in a project. */
  project?: string;
  tag?: string;
}

function single(value: unknown): string | undefined {
  if (typeof value === 'string') return value;
  if (Array.isArray(value) && typeof value[0] === 'string') return value[0];
  return undefined;
}

/** Every field is returned, undefined when dropped, so the router's raw value cannot stand in for it. */
export function validateNotesSearch(raw: Record<string, unknown>): NotesSearch {
  const q = single(raw.q);
  const project = single(raw.project);
  const tag = single(raw.tag);
  return { q: q ? q : undefined, project: project ? project : undefined, tag: tag ? tag : undefined };
}

export function AllNotesScreen() {
  const search = route.useSearch();
  const navigate = route.useNavigate();
  const me = useQuery(meQuery);
  const keepsUserData = me.data?.userData === true;
  const notes = useQuery({ ...notesQuery, enabled: keepsUserData });
  const tags = useQuery({ ...tagsQuery, enabled: keepsUserData });
  const projects = useQuery({ ...projectsQuery, enabled: keepsUserData });
  const heading = useRef<HTMLHeadingElement>(null);
  const list = useRef<HTMLUListElement>(null);
  const [editing, setEditing] = useState<NoteSummary | null>(null);
  const [deleting, setDeleting] = useState<{ note: NoteSummary; index: number } | null>(null);
  useDocumentTitle(copy.allNotes.title);
  useHeadingReady(!me.isPending);

  // The search field's text, kept as it is typed and copied into the URL in place of the last copy,
  // as Browse's filter is: a value the URL shows that the field wrote is its own, and any other, as
  // after Back, the field takes.
  const [text, setText] = useState(search.q ?? '');
  const [seen, setSeen] = useState(search.q);
  const [pending, setPending] = useState<(string | undefined)[]>([]);
  if (search.q !== seen) {
    setSeen(search.q);
    const own = pending.indexOf(search.q);
    if (own >= 0) {
      setPending(pending.slice(own + 1));
    } else {
      setPending([]);
      setText(search.q ?? '');
    }
  }

  function update(changes: Partial<NotesSearch>) {
    void navigate({ search: (previous: NotesSearch) => ({ ...previous, ...changes }), replace: true });
  }

  /** A dialog closed: focus goes back to the row's own control, the next row's, or the heading. */
  function returnFocus(selector: string | null) {
    requestAnimationFrame(() => {
      const target = selector ? list.current?.querySelector<HTMLElement>(selector) : null;
      (target ?? heading.current)?.focus();
    });
  }

  const projectItems = projects.data?.items ?? [];
  const tagItems = tags.data?.items ?? [];
  const projectNames = new Map(projectItems.map((project) => [project.id.toUpperCase(), project.name]));
  const tagNames = new Map(tagItems.map((tag) => [tag.id.toUpperCase(), tag.name]));
  const all = notes.data?.items ?? [];
  const shown = filterNotes(all, { project: search.project, tag: search.tag, query: text });

  let body;
  if (me.isError) {
    body = (
      <p className="error" role="alert">
        {errorMessage(me.error)}
      </p>
    );
  } else if (me.data && !keepsUserData) {
    body = <p>{copy.settings.userDataOff}</p>;
  } else if (notes.isError) {
    body = (
      <p className="error" role="alert">
        {errorMessage(notes.error)}
      </p>
    );
  } else if (!notes.data) {
    body = <p role="status">{copy.allNotes.loading}</p>;
  } else {
    body = (
      <>
        <div className="notes-filters" role="search">
          <label>
            {copy.allNotes.project}{' '}
            <select value={search.project ?? ''} onChange={(event) => update({ project: event.target.value || undefined })}>
              <option value="">{copy.allNotes.allProjects}</option>
              <option value="unfiled">{copy.allNotes.unfiled}</option>
              {projectItems.map((project) => (
                <option key={project.id} value={project.id}>
                  {project.name}
                </option>
              ))}
            </select>
          </label>
          <label>
            {copy.allNotes.tag}{' '}
            <select value={search.tag ?? ''} onChange={(event) => update({ tag: event.target.value || undefined })}>
              <option value="">{copy.allNotes.allTags}</option>
              {tagItems.map((tag) => (
                <option key={tag.id} value={tag.id}>
                  {tag.name}
                </option>
              ))}
            </select>
          </label>
          <input
            type="search"
            value={text}
            placeholder={copy.allNotes.search}
            aria-label={copy.allNotes.search}
            spellCheck={false}
            autoCapitalize="off"
            autoComplete="off"
            onChange={(event) => {
              const q = event.target.value || undefined;
              setText(event.target.value);
              if (q !== search.q) setPending((written) => [...written, q]);
              update({ q });
            }}
          />
        </div>
        <p className="count" role="status">
          {countLine(shown.length, all.length)}
        </p>
        {shown.length === 0 ? (
          <div className="empty">
            <h2>{copy.allNotes.noneTitle}</h2>
            <p>{all.length === 0 ? copy.allNotes.empty : copy.allNotes.noneFiltered}</p>
          </div>
        ) : (
          <ul ref={list} className="all-notes" aria-label={copy.allNotes.title}>
            {shown.map((note, index) => (
              <NoteRow
                key={note.id}
                note={note}
                detail={noteDetail(note, projectNames, tagNames)}
                onOpen={() => setEditing(note)}
                onDelete={() => setDeleting({ note, index })}
              />
            ))}
          </ul>
        )}
      </>
    );
  }

  return (
    <section className="screen research-notes">
      <h1 ref={heading} tabIndex={-1} data-loading={me.isPending ? 'true' : undefined}>
        {copy.allNotes.title}
      </h1>
      {body}
      {editing && (
        <NoteEditor
          volumeId={editing.volumeId}
          documentId={editing.documentId}
          note={editing}
          onClose={(outcome) => {
            const { id } = editing;
            setEditing(null);
            returnFocus(outcome === 'deleted' ? null : `button.all-notes-row[data-id="${CSS.escape(id)}"]`);
          }}
        />
      )}
      {deleting && (
        <DeleteNote
          note={deleting.note}
          onClose={(deleted) => {
            const { note, index } = deleting;
            setDeleting(null);
            if (!deleted) returnFocus(`button.delete-note[data-id="${CSS.escape(note.id)}"]`);
            else
              requestAnimationFrame(() => {
                // The deleted row's own Delete… is passed over, should the list not have lost it yet.
                const buttons = [...(list.current?.querySelectorAll<HTMLButtonElement>('button.delete-note') ?? [])].filter(
                  (button) => button.dataset.id !== note.id,
                );
                (buttons[index] ?? buttons[index - 1] ?? heading.current)?.focus();
              });
          }}
        />
      )}
    </section>
  );
}

/**
 * A row, as the app's: the note's first line, where it is and what it is filed under, and the day
 * it last changed; then its Delete….
 */
function NoteRow({ note, detail, onOpen, onDelete }: { note: NoteSummary; detail: string; onOpen: () => void; onDelete: () => void }) {
  const titleId = useId();
  const date = noteDate(note.lastModified);
  return (
    <li>
      <button type="button" className="all-notes-row" data-id={note.id} aria-haspopup="dialog" onClick={onOpen}>
        <span id={titleId} className="all-notes-title">
          {noteTitle(note.bodyText)}
        </span>
        <span className="all-notes-detail">{detail}</span>
        {date && <span className="all-notes-date">{date}</span>}
      </button>
      <button type="button" className="destructive delete-note" data-id={note.id} aria-haspopup="dialog" aria-describedby={titleId} onClick={onDelete}>
        {copy.allNotes.delete}
      </button>
    </li>
  );
}
