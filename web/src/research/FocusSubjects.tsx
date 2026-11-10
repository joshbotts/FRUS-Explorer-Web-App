// Project Home's Focus subjects (PLAN's S25c), as the app's `ProjectHomeView.focusSubjectsSection`
// draws them, the subjects the project chose, with Add or Edit; and their editor, the app's
// `ProjectFocusSubjectsEditor`: Focus subjects, Suggested from your volumes and All subjects under
// its search field, each row a switch that saves the project's whole list at once. The server
// filters the chosen subjects and makes the suggestions, with the kit's rule; the editor's sections,
// its search and its rows' words are the app's view code, mirrored in focusSubjectRules.ts.
// The web's own: a list that changes while an earlier save is under way is saved after it, the
// newest list whole, so the server ends with what the rows show; a save the server refuses puts the
// rows back as it holds them, and says why; a row that leaves its section hands the focus to the
// row that takes its place; and a subject added or removed is said for a screen reader.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useId, useRef, useState } from 'react';
import { flushSync } from 'react-dom';
import { errorMessage } from '../api/client';
import { type FocusSubject, focusSubjectsQuery, type ProjectHome, updateProject } from '../api/research';
import { copy } from '../copy';
import { Modal } from '../shell/Modal';
import { chosenSubjects, filteredSubjects, showsSuggestions, subjectKind, subjectReach, toggledSubjects } from './focusSubjectRules';

/**
 * A project's focus subjects' refs, and their toggle. `stored` is the list the server holds; while a
 * toggle's save is under way or waits its turn, the list is the one the rows last made. The saves
 * go one at a time, each the newest list whole, so a slow answer never lands over a later toggle.
 */
function useFocusSubjectRefs(projectId: string, stored: readonly string[]) {
  const client = useQueryClient();
  const [pending, setPending] = useState<string[] | null>(null);
  const [failure, setFailure] = useState<string | null>(null);
  const wanted = useRef<string[] | null>(null);
  const saving = useRef(false);

  async function save() {
    if (saving.current) return;
    saving.current = true;
    try {
      for (let sent = wanted.current; sent; sent = wanted.current) {
        try {
          // Its answer is Project Home's project at once (`updateProject`), so `stored` is this list.
          await updateProject(client, projectId, { defaultSubjectTagIds: sent });
        } catch (error) {
          // A later toggle waits, and its list holds this one's change too.
          if (wanted.current !== sent) continue;
          setFailure(errorMessage(error));
          // What the server holds, read again, in case it is not what this page read.
          void client.invalidateQueries({ queryKey: ['projectHome', projectId] });
        }
        if (wanted.current === sent) {
          wanted.current = null;
          setPending(null);
        }
      }
    } finally {
      saving.current = false;
    }
  }

  function toggle(ref: string) {
    const next = toggledSubjects(wanted.current ?? stored, ref);
    wanted.current = next;
    setPending(next);
    setFailure(null);
    void save();
  }

  return { refs: pending ?? stored, failure, toggle };
}

/** Project Home's section: the chosen subjects' names, or the app's sentence for none, and the editor's way in. */
export function FocusSubjects({ home }: { home: ProjectHome }) {
  const subjects = home.focusSubjects ?? [];
  const chosen = useFocusSubjectRefs(home.project.id, home.project.defaultSubjectTagIds ?? []);
  const [editing, setEditing] = useState(false);
  const opener = useRef<HTMLButtonElement>(null);
  const headingId = useId();
  return (
    <section className="focus-subjects" aria-labelledby={headingId}>
      <div className="section-header">
        <h2 id={headingId}>{copy.projectHome.focusSubjects}</h2>
        <button ref={opener} type="button" aria-haspopup="dialog" aria-describedby={headingId} onClick={() => setEditing(true)}>
          {subjects.length === 0 ? copy.projectHome.focusSubjectsAdd : copy.projectHome.focusSubjectsEdit}
        </button>
      </div>
      {subjects.length === 0 ? (
        <p className="note">{copy.projectHome.focusSubjectsEmpty}</p>
      ) : (
        <ul className="chips">
          {subjects.map((subject) => (
            <li key={subject.ref}>{subject.name}</li>
          ))}
        </ul>
      )}
      {editing && (
        <FocusSubjectsEditor
          refs={chosen.refs}
          suggestions={home.focusSuggestions ?? []}
          failure={chosen.failure}
          onToggle={chosen.toggle}
          onClose={() => {
            setEditing(false);
            opener.current?.focus();
          }}
        />
      )}
    </section>
  );
}

/** The editor: the project's subjects, those its volumes suggest, and the vocabulary under a search field. */
function FocusSubjectsEditor({
  refs,
  suggestions,
  failure,
  onToggle,
  onClose,
}: {
  /** The project's refs, as the rows last made them. */
  refs: readonly string[];
  /** The server's suggestions for the list it holds. */
  suggestions: readonly FocusSubject[];
  failure: string | null;
  onToggle: (ref: string) => void;
  onClose: () => void;
}) {
  const vocabulary = useQuery(focusSubjectsQuery);
  const headingId = useId();
  const [search, setSearch] = useState('');
  const [said, setSaid] = useState('');
  const body = useRef<HTMLDivElement>(null);
  const searchField = useRef<HTMLInputElement>(null);

  function toggle(subject: FocusSubject, box: HTMLInputElement) {
    const section = box.closest('[role="group"]');
    const boxes = (from: Element | null | undefined) => [...(from?.querySelectorAll<HTMLInputElement>('input[type="checkbox"]') ?? [])];
    const index = boxes(section).indexOf(box);
    const adding = !refs.includes(subject.ref);
    // Drawn before the focus is looked for, so that the rows found are the rows now shown.
    flushSync(() => {
      onToggle(subject.ref);
      setSaid(adding ? copy.projectHome.focusSubjectAdded(subject.name) : copy.projectHome.focusSubjectRemoved(subject.name));
    });
    // A row that left its section took the focus with it: it goes on to the row now in its place, or
    // the last, or, from a section that went with its last row, to the search field.
    if (box.isConnected) return;
    const left = section?.isConnected ? boxes(section) : [];
    (left[index] ?? left[left.length - 1] ?? searchField.current)?.focus();
  }

  const close = () => body.current?.closest('dialog')?.close();
  const all = vocabulary.data?.items ?? [];
  // A subject just chosen is no suggestion, before the server answers with the list that leaves it out.
  const suggested = suggestions.filter((subject) => !refs.includes(subject.ref));
  let sections;
  if (vocabulary.isError) {
    sections = (
      <>
        <h3>{copy.projectHome.focusSubjectsUnavailableTitle}</h3>
        <p>{copy.projectHome.focusSubjectsUnavailable}</p>
        <p className="error" role="alert">
          {errorMessage(vocabulary.error)}
        </p>
      </>
    );
  } else if (!vocabulary.data) {
    sections = <p role="status">{copy.projectHome.focusSubjectsLoading}</p>;
  } else {
    sections = (
      <>
        <input
          ref={searchField}
          type="search"
          value={search}
          placeholder={copy.projectHome.focusSubjectsSearch}
          aria-label={copy.projectHome.focusSubjectsSearch}
          onChange={(event) => setSearch(event.target.value)}
        />
        {refs.length > 0 && (
          <SubjectRows title={copy.projectHome.focusSubjectsSelected} subjects={chosenSubjects(all, refs)} refs={refs} onToggle={toggle} />
        )}
        {showsSuggestions(search, suggested) && (
          <SubjectRows
            title={copy.projectHome.focusSubjectsSuggested}
            subjects={suggested}
            refs={refs}
            footer={copy.projectHome.focusSubjectsSuggestedDetail}
            onToggle={toggle}
          />
        )}
        <SubjectRows
          title={copy.projectHome.focusSubjectsAll}
          subjects={filteredSubjects(all, search)}
          refs={refs}
          empty={copy.projectHome.focusSubjectsNoMatches}
          onToggle={toggle}
        />
      </>
    );
  }

  return (
    <Modal className="focus-subjects-editor" labelledBy={headingId} onCancel={close} onClose={onClose}>
      <div ref={body}>
        <div className="editor-header">
          <h2 id={headingId} tabIndex={-1}>
            {copy.projectHome.focusSubjectsTitle}
          </h2>
          <button type="button" onClick={close}>
            {copy.projectHome.focusSubjectsDone}
          </button>
        </div>
        {sections}
        {failure && (
          <p className="error" role="alert">
            {failure}
          </p>
        )}
        <p className="visually-hidden" role="status">
          {said}
        </p>
      </div>
    </Modal>
  );
}

/** One of the editor's sections: its title, its subjects, each a switch, and what it says under them or for none. */
function SubjectRows({
  title,
  subjects,
  refs,
  footer,
  empty,
  onToggle,
}: {
  title: string;
  subjects: readonly FocusSubject[];
  refs: readonly string[];
  footer?: string;
  empty?: string;
  onToggle: (subject: FocusSubject, box: HTMLInputElement) => void;
}) {
  const id = useId();
  let rows;
  if (subjects.length > 0) {
    rows = (
      <ul className="subject-rows">
        {subjects.map((subject, index) => (
          <li key={subject.ref}>
            <label>
              <input
                type="checkbox"
                checked={refs.includes(subject.ref)}
                aria-labelledby={`${id}-name-${index}`}
                aria-describedby={`${id}-kind-${index} ${id}-reach-${index}`}
                onChange={(event) => onToggle(subject, event.currentTarget)}
              />
              <span className="subject-text">
                <span id={`${id}-name-${index}`}>{subject.name}</span>
                <span id={`${id}-kind-${index}`} className="subject-kind">
                  {subjectKind(subject)}
                </span>
              </span>
              <span id={`${id}-reach-${index}`} className="subject-reach">
                {subjectReach(subject)}
              </span>
            </label>
          </li>
        ))}
      </ul>
    );
  } else if (empty) {
    rows = <p className="note">{empty}</p>;
  }
  return (
    <div className="subject-section" role="group" aria-labelledby={id}>
      <h3 id={id}>{title}</h3>
      {rows}
      {footer && <p className="note">{footer}</p>}
    </div>
  );
}
