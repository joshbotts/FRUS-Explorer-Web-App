// Settings ▸ Projects (PLAN's S17f), as the app's Projects pane lays it out: the Active Project picker
// and Project Home, with the sentence of what the active project does; All Projects, each row its
// name, its tally and its question, opening the project's editor, with the Move commands that set the
// reader's own order, and New Project… at the end; and Related, Tags and Volume Scopes. The editor
// renames a project and writes its question, and Manage merges and deletes it, as the app's
// `ProjectEditorView`, `MergeProjectSheet` and `ProjectAdminService` do.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Link } from '@tanstack/react-router';
import { useEffect, useEffectEvent, useId, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import { createProject, deleteProject, mergeProject, setActiveProject, updatePreferences, updateProject } from '../api/research';
import { volumeScopesQuery } from '../api/searchSets';
import type { Project } from '../api/types';
import { meQuery, projectsQuery, tagsQuery } from '../api/userData';
import { copy } from '../copy';
import { applyOrder, type MoveStep, moving } from '../research/listOrder';
import { useHeadingReady } from '../shell/headingFocus';
import { Modal } from '../shell/Modal';
import { useActiveProjectId } from '../shell/ProjectPicker';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import { SettingsPanes } from './SettingsPanes';
import { useListOrder } from './syncedPreferences';

export function ProjectsSettingsScreen() {
  const client = useQueryClient();
  const me = useQuery(meQuery);
  const keepsUserData = me.data?.userData === true;
  const projects = useQuery({ ...projectsQuery, enabled: keepsUserData });
  const tags = useQuery({ ...tagsQuery, enabled: keepsUserData });
  const scopes = useQuery({ ...volumeScopesQuery, enabled: keepsUserData });
  const { projectOrder } = useListOrder();
  const heading = useRef<HTMLHeadingElement>(null);
  const activeId = useId();
  const listId = useId();
  const relatedId = useId();
  /** The project open in the editor, or `new` for New Project…. */
  const [editing, setEditing] = useState<Project | 'new' | null>(null);
  const [merging, setMerging] = useState<Project | null>(null);
  const [failure, setFailure] = useState<string | null>(null);
  const opener = useRef<HTMLElement | null>(null);
  useDocumentTitle(copy.projects.title);
  useHeadingReady(!me.isPending);

  const ordered = applyOrder(projects.data?.items ?? [], projectOrder, (project) => project.id);
  const active = useActiveProjectId(projects.data);

  async function run(action: () => Promise<unknown>) {
    setFailure(null);
    try {
      await action();
    } catch (error) {
      setFailure(errorMessage(error));
    }
  }

  /** A dialog closed: focus goes back to what opened it, or to the heading when that is gone. */
  function returnFocus(gone: boolean) {
    const target = opener.current;
    if (!gone && target?.isConnected) target.focus();
    else heading.current?.focus();
  }

  function move(project: Project, step: MoveStep, button: HTMLButtonElement) {
    const next = moving(project.id, step, ordered.map((item) => item.id));
    if (!next) return;
    const row = button.closest('li');
    void run(async () => {
      await updatePreferences(client, { projectOrder: next });
      // The focus stays with the project's row, on the command it can still take.
      requestAnimationFrame(() => {
        const moved = row?.parentElement?.querySelector<HTMLElement>(`li[data-id="${project.id}"]`);
        (moved?.querySelector<HTMLButtonElement>(`button[data-step="${step}"]`) ?? moved?.querySelector<HTMLButtonElement>('button.settings-row'))?.focus();
      });
    });
  }

  let body;
  if (me.isError) {
    body = (
      <p className="error" role="alert">
        {errorMessage(me.error)}
      </p>
    );
  } else if (me.data && !keepsUserData) {
    body = <p>{copy.settings.userDataOff}</p>;
  } else if (projects.isError) {
    body = (
      <p className="error" role="alert">
        {errorMessage(projects.error)}
      </p>
    );
  } else if (!projects.data) {
    body = <p role="status">{copy.projects.loading}</p>;
  } else {
    const tagCount = tags.data?.total ?? 0;
    const scopeCount = scopes.data?.total ?? 0;
    body = (
      <>
        <section aria-labelledby={activeId}>
          <h2 id={activeId} className="visually-hidden">
            {copy.projects.activeLabel}
          </h2>
          <label className="active-project">
            {copy.projects.activeLabel}{' '}
            <select value={active ?? ''} onChange={(event) => void run(() => setActiveProject(client, event.target.value || null))}>
              <option value="">{copy.projects.global}</option>
              {ordered.map((project) => (
                <option key={project.id} value={project.id}>
                  {project.name}
                </option>
              ))}
            </select>
          </label>
          {active && (
            <p>
              <Link to="/projects/$projectId" params={{ projectId: active }}>
                {copy.projects.home}
              </Link>
            </p>
          )}
          <p className="note">{copy.projects.activeFooter}</p>
        </section>
        <section aria-labelledby={listId}>
          <h2 id={listId}>{copy.projects.listHeader}</h2>
          {ordered.length === 0 ? (
            <p>{copy.projects.empty}</p>
          ) : (
            <ul className="settings-list">
              {ordered.map((project) => {
                const steps: MoveStep[] = ['toTop', 'up', 'down'];
                const ids = ordered.map((item) => item.id);
                return (
                  <li key={project.id} data-id={project.id}>
                    <button
                      type="button"
                      className="settings-row"
                      aria-haspopup="dialog"
                      onClick={(event) => {
                        opener.current = event.currentTarget;
                        setEditing(project);
                      }}
                    >
                      <span className="row-text">
                        {project.name}
                        <span className="detail">
                          {[project.tally, project.id === active ? copy.projects.active : undefined].filter(Boolean).join(' · ')}
                        </span>
                        {project.researchQuestion && <span className="detail">{project.researchQuestion}</span>}
                      </span>
                      <span aria-hidden="true">›</span>
                    </button>
                    {ordered.length > 1 && (
                      <span className="move-commands">
                        {steps
                          .filter((step) => moving(project.id, step, ids) !== undefined)
                          .map((step) => {
                            const command = step === 'toTop' ? copy.listOrder.moveToTop : step === 'up' ? copy.listOrder.moveUp : copy.listOrder.moveDown;
                            return (
                              <button
                                key={step}
                                type="button"
                                data-step={step}
                                aria-label={copy.listOrder.moveLabel(command, project.name)}
                                onClick={(event) => move(project, step, event.currentTarget)}
                              >
                                {command}
                              </button>
                            );
                          })}
                      </span>
                    )}
                  </li>
                );
              })}
            </ul>
          )}
          <button
            type="button"
            className="settings-new"
            aria-haspopup="dialog"
            onClick={(event) => {
              opener.current = event.currentTarget;
              setEditing('new');
            }}
          >
            {copy.projects.new}
          </button>
          <p className="note">{copy.projects.listFooter}</p>
        </section>
        <section aria-labelledby={relatedId}>
          <h2 id={relatedId}>{copy.projects.relatedHeader}</h2>
          <ul className="settings-list">
            <li>
              <Link to="/settings/tags" className="settings-row">
                <span className="row-text">
                  {copy.projects.tags}
                  <span className="detail">{tagCount === 0 ? copy.projects.noneYet : copy.projects.tagCount(tagCount)}</span>
                </span>
                <span aria-hidden="true">›</span>
              </Link>
            </li>
            <li>
              <Link to="/browse/scopes" className="settings-row">
                <span className="row-text">
                  {copy.projects.scopes}
                  <span className="detail">{scopeCount === 0 ? copy.projects.noneYet : copy.projects.scopeCount(scopeCount)}</span>
                </span>
                <span aria-hidden="true">›</span>
              </Link>
            </li>
          </ul>
          <p className="note">{copy.projects.relatedFooter}</p>
        </section>
        {failure && (
          <p className="error" role="alert">
            {failure}
          </p>
        )}
      </>
    );
  }

  return (
    <div className="settings">
      <SettingsPanes />
      <section className="settings-pane">
        <h1 ref={heading} tabIndex={-1} data-loading={me.isPending ? 'true' : undefined}>
          {copy.projects.title}
        </h1>
        {body}
      </section>
      {editing && (
        <ProjectEditor
          key={editing === 'new' ? 'new' : editing.id}
          project={editing === 'new' ? null : editing}
          peerProjectCount={ordered.length}
          onMerge={(project) => {
            setEditing(null);
            setMerging(project);
          }}
          onClose={(gone) => {
            setEditing(null);
            returnFocus(gone);
          }}
        />
      )}
      {merging && (
        <MergeProjectDialog
          source={merging}
          others={ordered.filter((project) => project.id !== merging.id)}
          onClose={(merged) => {
            setMerging(null);
            returnFocus(merged);
          }}
        />
      )}
    </div>
  );
}

/** The project editor, as the app's `ProjectEditorView`: the name and the research question, then Manage. */
function ProjectEditor({
  project,
  peerProjectCount,
  onMerge,
  onClose,
}: {
  /** None for New Project…, which has no Manage. */
  project: Project | null;
  peerProjectCount: number;
  onMerge: (project: Project) => void;
  /** Called once the editor has closed, with whether the project is gone. */
  onClose: (gone: boolean) => void;
}) {
  const client = useQueryClient();
  const headingId = useId();
  const field = useRef<HTMLInputElement>(null);
  const [name, setName] = useState(project?.name ?? '');
  const [question, setQuestion] = useState(project?.researchQuestion ?? '');
  const [confirming, setConfirming] = useState(false);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const deleteButton = useRef<HTMLButtonElement>(null);
  const outcome = useRef<{ gone: boolean; merge: boolean }>({ gone: false, merge: false });
  const body = useRef<HTMLDivElement>(null);
  const afterConfirmation = useRef<'return' | 'close' | null>(null);

  function close(result: { gone: boolean; merge: boolean } = { gone: false, merge: false }) {
    outcome.current = result;
    body.current?.closest('dialog')?.close();
  }

  const confirmationGone = useEffectEvent(() => {
    const next = afterConfirmation.current;
    afterConfirmation.current = null;
    if (next === 'return') deleteButton.current?.focus();
    else if (next === 'close') close({ gone: true, merge: false });
  });
  useEffect(() => {
    if (!confirming) confirmationGone();
  }, [confirming]);

  async function save() {
    if (name.trim() === '' || busy) return;
    setBusy(true);
    setFailure(null);
    try {
      if (project) await updateProject(client, project.id, { name, researchQuestion: question });
      else await createProject(client, name, question);
      close();
    } catch (error) {
      setBusy(false);
      setFailure(errorMessage(error));
    }
  }

  async function remove() {
    if (!project || busy) return;
    setBusy(true);
    setFailure(null);
    try {
      await deleteProject(client, project.id);
      afterConfirmation.current = 'close';
    } catch (error) {
      setBusy(false);
      setFailure(errorMessage(error));
      afterConfirmation.current = 'return';
    }
    setConfirming(false);
  }

  return (
    <>
      <Modal
        className="project-editor"
        labelledBy={headingId}
        initial={field}
        onCancel={() => close()}
        onClose={() => (outcome.current.merge && project ? onMerge(project) : onClose(outcome.current.gone))}
      >
        <div ref={body}>
          <h2 id={headingId} tabIndex={-1}>
            {project ? copy.projects.editorEdit : copy.projects.editorNew}
          </h2>
          <form
            onSubmit={(event) => {
              event.preventDefault();
              void save();
            }}
          >
            <h3>{copy.projects.nameHeader}</h3>
            <input
              ref={field}
              type="text"
              value={name}
              placeholder={copy.projects.namePlaceholder}
              aria-label={copy.projects.nameField}
              onChange={(event) => setName(event.target.value)}
            />
            <h3>{copy.projects.questionHeader}</h3>
            <textarea
              value={question}
              rows={3}
              aria-label={copy.projects.questionField}
              onChange={(event) => setQuestion(event.target.value)}
            />
          </form>
          {project && (
            <>
              <h3>{copy.projects.manage}</h3>
              <div className="manage">
                <button type="button" disabled={peerProjectCount < 2 || busy} onClick={() => close({ gone: false, merge: true })}>
                  {copy.projects.merge}
                </button>
                <button ref={deleteButton} type="button" className="destructive" disabled={busy} onClick={() => setConfirming(true)}>
                  {copy.projects.delete}
                </button>
              </div>
              <p className="note">{peerProjectCount < 2 ? copy.projects.manageFooterOnly : copy.projects.manageFooter}</p>
            </>
          )}
          {failure && (
            <p className="error" role="alert">
              {failure}
            </p>
          )}
          <div className="actions">
            <button type="button" onClick={() => close()}>
              {copy.projects.cancel}
            </button>
            <button type="button" disabled={name.trim() === '' || busy} onClick={() => void save()}>
              {copy.projects.save}
            </button>
          </div>
        </div>
      </Modal>
      {confirming && (
        <DeleteProjectConfirmation
          busy={busy}
          onDelete={() => void remove()}
          onCancel={() => {
            afterConfirmation.current = 'return';
            setConfirming(false);
          }}
        />
      )}
    </>
  );
}

/** "Delete Project?", as the app's confirmation asks it. */
function DeleteProjectConfirmation({ busy, onDelete, onCancel }: { busy: boolean; onDelete: () => void; onCancel: () => void }) {
  const headingId = useId();
  const messageId = useId();
  const cancel = useRef<HTMLButtonElement>(null);
  return (
    <Modal
      className="confirm"
      role="alertdialog"
      labelledBy={headingId}
      describedBy={messageId}
      initial={cancel}
      onCancel={onCancel}
      onClose={() => {}}
    >
      <h2 id={headingId} tabIndex={-1}>
        {copy.projects.deleteTitle}
      </h2>
      <p id={messageId}>{copy.projects.deleteMessage}</p>
      <div className="actions">
        <button ref={cancel} type="button" onClick={onCancel}>
          {copy.projects.deleteCancel}
        </button>
        <button type="button" className="destructive" disabled={busy} onClick={onDelete}>
          {copy.projects.deleteConfirm}
        </button>
      </div>
    </Modal>
  );
}

/** Merge Project (`MergeProjectSheet`): the project chosen takes everything filed under this one. */
function MergeProjectDialog({ source, others, onClose }: { source: Project; others: Project[]; onClose: (merged: boolean) => void }) {
  const client = useQueryClient();
  const headingId = useId();
  const [target, setTarget] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const merged = useRef(false);
  const body = useRef<HTMLDivElement>(null);
  const close = () => body.current?.closest('dialog')?.close();

  async function merge() {
    if (!target || busy) return;
    setBusy(true);
    setFailure(null);
    try {
      await mergeProject(client, source.id, target);
      merged.current = true;
      close();
    } catch (error) {
      setBusy(false);
      setFailure(errorMessage(error));
    }
  }

  return (
    <Modal className="merge-project" labelledBy={headingId} onCancel={close} onClose={() => onClose(merged.current)}>
      <div ref={body}>
        <h2 id={headingId} tabIndex={-1}>
          {copy.projects.mergeTitle}
        </h2>
        <fieldset>
          <legend>{copy.projects.mergeInto(source.name)}</legend>
          {others.map((project) => (
            <label key={project.id}>
              <input type="radio" name="merge-into" value={project.id} checked={target === project.id} onChange={() => setTarget(project.id)} />{' '}
              {project.name}
            </label>
          ))}
        </fieldset>
        <p className="note">{copy.projects.mergeExplanation(source.name)}</p>
        {failure && (
          <p className="error" role="alert">
            {failure}
          </p>
        )}
        <div className="actions">
          <button type="button" onClick={close}>
            {copy.projects.mergeCancel}
          </button>
          <button type="button" disabled={!target || busy} onClick={() => void merge()}>
            {copy.projects.mergeConfirm}
          </button>
        </div>
      </div>
    </Modal>
  );
}
