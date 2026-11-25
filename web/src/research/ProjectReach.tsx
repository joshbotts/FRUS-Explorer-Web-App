// Beyond your library at the project's grain (PLAN's S26d), under Suggested Next, as the app's `beyondLibrarySection`
// follows its leads: the volumes the project's documents reach that the served index does not hold, the kit's
// `SemanticProjectReach` on the server, each with its documents and how many of the project's reached it, its title
// opening its page in Browse where the app offers a download. Shown only when the reach found a volume
// (`!reach.isEmpty`), as the app shows it, and read again when a computation of the leads ends, as the app reads it at
// each, since the documents it starts from may have changed.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Link } from '@tanstack/react-router';
import { useEffect, useId, useRef } from 'react';
import { projectReachQuery } from '../api/reach';
import { findingLeads, type ProjectHome } from '../api/research';
import { copy } from '../copy';
import { plainTitle } from '../shell/useDocumentTitle';

export function ProjectReach({ home }: { home: ProjectHome }) {
  const client = useQueryClient();
  const projectId = home.project.id;
  const reach = useQuery(projectReachQuery(projectId));
  const finding = findingLeads(home);
  const wasFinding = useRef(finding);
  useEffect(() => {
    if (wasFinding.current && !finding) void client.invalidateQueries({ queryKey: ['projectReach', projectId] });
    wasFinding.current = finding;
  }, [finding, client, projectId]);
  const headingId = useId();
  const found = reach.data;
  if (!found || found.volumes.length === 0) return null;
  return (
    <section className="reach" aria-labelledby={headingId}>
      <h2 id={headingId}>{copy.projectHome.reachTitle}</h2>
      <p className="note">{copy.projectHome.reachCaption(found.documentCount, found.seedsProbed)}</p>
      <ul className="reach-list">
        {found.volumes.map((volume) => (
          <li key={volume.volumeId}>
            <Link to="/browse/$volumeId" params={{ volumeId: volume.volumeId }}>
              {plainTitle(volume.title)}
            </Link>
            <span className="reach-detail">{copy.projectHome.reachVolume(volume.documentCount, volume.reachingSeeds)}</span>
          </li>
        ))}
      </ul>
    </section>
  );
}
