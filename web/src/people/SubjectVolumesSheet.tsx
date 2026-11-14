// A subject chip's pivot (S21g's follow-up), the app's `VolumeSubjectVolumesSheet` as a person's sheet opens it, with no
// volume excluded: titled by the subject, with Done beside the title, where the app's toolbar keeps it, so that a list
// of hundreds of volumes is not between them; how many volumes cover the subject; each covering volume a row that opens
// its page in Browse by its title, with its id below; and the subject's name under the list; or the app's empty state.
// The order and the volumes are the server's, the app's sheet's two branches over the bundled files (People.swift's
// `SubjectPivot`). The app's sheet's two doors, the archival profile of these volumes and the topic in the index, open
// surfaces this server does not have yet: Archival Analytics, and the Topic Index.
import { useQuery } from '@tanstack/react-query';
import { Link } from '@tanstack/react-router';
import { useId, useRef } from 'react';
import { errorMessage } from '../api/client';
import { type PersonSubject, subjectVolumesQuery } from '../api/people';
import { copy } from '../copy';
import { Modal } from '../shell/Modal';
import { subjectVolumesHeader } from './peopleRules';

export function SubjectVolumesSheet({ subject, onClose }: { subject: PersonSubject; onClose: () => void }) {
  const headingId = useId();
  const countId = useId();
  const body = useRef<HTMLDivElement>(null);
  const volumes = useQuery(subjectVolumesQuery(subject.ref));
  const rows = volumes.data?.volumes ?? [];

  function close() {
    body.current?.closest('dialog')?.close();
  }

  return (
    <Modal className="subject-volumes" labelledBy={headingId} onCancel={close} onClose={onClose}>
      <div ref={body}>
        <div className="sheet-header">
          <h2 id={headingId} tabIndex={-1}>
            {subject.name}
          </h2>
          <button type="button" onClick={close}>
            {copy.people.done}
          </button>
        </div>
        {volumes.isError ? (
          <p className="error" role="alert">
            {errorMessage(volumes.error)}
          </p>
        ) : !volumes.data ? (
          <p role="status">{copy.people.subjectVolumesLoading}</p>
        ) : rows.length === 0 ? (
          <div className="empty">
            <h3>{copy.people.subjectVolumesEmptyTitle}</h3>
            <p>{copy.people.subjectVolumesEmptyDetail}</p>
          </div>
        ) : (
          <section aria-labelledby={countId}>
            <h3 id={countId}>{subjectVolumesHeader(rows.length)}</h3>
            <ul className="subject-volume-rows">
              {rows.map((volume) => (
                <li key={volume.volumeId}>
                  <Link to="/browse/$volumeId" params={{ volumeId: volume.volumeId }} title={copy.people.subjectVolumeHint}>
                    <span className="subject-volume-title">{volume.title ?? volume.volumeId}</span>{' '}
                    <span className="meta">{volume.volumeId}</span>
                  </Link>
                </li>
              ))}
            </ul>
            <p className="note">{subject.name}</p>
          </section>
        )}
      </div>
    </Modal>
  );
}
