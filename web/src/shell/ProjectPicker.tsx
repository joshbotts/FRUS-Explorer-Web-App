// The project picker in the header (PLAN's S17f), as the app's `ProjectPickerMenu`: Global Context,
// then the user's projects, by name with the reader's own order over it, the one they work in chosen;
// with Project Home for that one and Manage Projects, which opens Settings ▸ Projects. A select, the
// web's own, as the one control a keyboard and a screen reader know for a choice of one; the app's is
// a menu. And the "Working on:" line Browse and Search show under it, as the app's `WorkingOnBanner`.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Link, useRouterState } from '@tanstack/react-router';
import { useState } from 'react';
import { errorMessage } from '../api/client';
import { setActiveProject } from '../api/research';
import { meQuery, projectsQuery } from '../api/userData';
import { copy } from '../copy';
import { applyOrder } from '../research/listOrder';
import { workingOnQuestion } from '../research/projectRules';
import { useListOrder } from '../settings/syncedPreferences';

export function ProjectPicker() {
  const client = useQueryClient();
  const me = useQuery(meQuery);
  const keepsUserData = me.data?.userData === true;
  const projects = useQuery({ ...projectsQuery, enabled: keepsUserData });
  const { projectOrder } = useListOrder();
  const [failure, setFailure] = useState<string | null>(null);
  if (!keepsUserData || !projects.data) return null;
  const ordered = applyOrder(projects.data.items, projectOrder, (project) => project.id);
  const active = projects.data.activeProjectId;

  async function choose(projectId: string | null) {
    setFailure(null);
    try {
      await setActiveProject(client, projectId);
    } catch (error) {
      setFailure(errorMessage(error));
    }
  }

  return (
    <div className="project-picker">
      {/* Named as the app names its menu, which holds the visible word, so no other Project control shares it. */}
      <label>
        {copy.projectPicker.label}{' '}
        <select value={active ?? ''} aria-label={copy.projectPicker.a11y} onChange={(event) => void choose(event.target.value || null)}>
          <option value="">{copy.projectPicker.global}</option>
          {ordered.map((project) => (
            <option key={project.id} value={project.id}>
              {project.name}
            </option>
          ))}
        </select>
      </label>
      {active && (
        <Link to="/projects/$projectId" params={{ projectId: active }}>
          {copy.projectPicker.home}
        </Link>
      )}
      <Link to="/settings/projects">{copy.projectPicker.manage}</Link>
      {failure && (
        <span className="error" role="alert">
          {failure}
        </span>
      )}
    </div>
  );
}

/** "Working on: <question>" over Browse and Search while the project worked in has a question. */
export function WorkingOn() {
  const me = useQuery(meQuery);
  const keepsUserData = me.data?.userData === true;
  const projects = useQuery({ ...projectsQuery, enabled: keepsUserData });
  const path = useRouterState({ select: (state) => state.location.pathname });
  if (!keepsUserData || !projects.data || !/\/(browse|search)(\/|$)/.test(path)) return null;
  const question = workingOnQuestion(projects.data.activeProjectId, projects.data.items);
  if (!question) return null;
  return (
    <p className="working-on">
      <strong>{copy.projectPicker.workingOn}</strong> {question}
    </p>
  );
}
