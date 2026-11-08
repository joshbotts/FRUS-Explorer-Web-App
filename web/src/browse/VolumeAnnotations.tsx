// A volume page's Editors’ Annotations (FRUS-Explorer#1860, #1861), as the app's
// `VolumeAnnotationsSection` lists them: what editorial annotation the volume carries, in three groups,
// each row its layer's name and a line of counts, and behind a disclosure, collapsed at first, the
// standard layers it lacks with the era from which the series made each standard. It comes from the
// bundled file, so it shows for every volume the file holds, indexed on this server or not, and nothing
// for one it does not. A row, and an absent row too, opens its layer's page on the axis, which marks
// this volume in its lists.
import { useQuery } from '@tanstack/react-query';
import { Link } from '@tanstack/react-router';
import { Fragment, useId } from 'react';
import { volumeAnnotationsQuery } from '../api/annotations';
import { copy } from '../copy';
import { absentLabel, absentNote, absentSpoken, absentTitle, layerLabel, rowDetail, rowSpoken } from './annotationRules';

const words = copy.annotations;

export function VolumeAnnotations({ volumeId }: { volumeId: string }) {
  const section = useQuery(volumeAnnotationsQuery(volumeId)).data;
  const headingId = useId();
  if (!section) return null;
  return (
    <section className="volume-annotations" aria-labelledby={headingId}>
      <h2 id={headingId}>{words.title}</h2>
      {section.groups.map((group) => (
        <Fragment key={group.family}>
          <h3>{words.families[group.family]}</h3>
          <ul className="annotation-rows">
            {group.rows.map((row) => (
              <li key={row.layer}>
                <Link
                  to="/browse/annotations/$layer"
                  params={{ layer: row.layer }}
                  search={{ from: volumeId }}
                  aria-label={rowSpoken(row.layer, row.parts)}
                  title={words.rowHint}
                >
                  <span className="annotation-label">{layerLabel(row.layer)}</span>
                  <span className="annotation-detail">{rowDetail(row.parts)}</span>
                </Link>
              </li>
            ))}
          </ul>
        </Fragment>
      ))}
      {section.absent.length > 0 && (
        <details className="annotations-absent">
          <summary>{absentTitle(section.absent.length)}</summary>
          <ul className="annotation-rows">
            {section.absent.map((row) => {
              const note = absentNote(row);
              return (
                <li key={row.id}>
                  <Link
                    to="/browse/annotations/$layer"
                    params={{ layer: row.layer }}
                    search={{ from: volumeId }}
                    aria-label={absentSpoken(row)}
                    title={words.rowHint}
                  >
                    <span className="annotation-label">{absentLabel(row.id)}</span>
                    {note && <span className="annotation-detail">{note}</span>}
                  </Link>
                </li>
              );
            })}
          </ul>
        </details>
      )}
    </section>
  );
}
