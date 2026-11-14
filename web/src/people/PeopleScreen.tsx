// The People screen (PLAN's S21g), `/people`, the app's People browser (`PersonIndexView`): the served index's person
// rollup, by letter, filtered as the reader types, each row its name, the app's `role · era · N volumes` line, its
// mention count and the mark of a "possibly the same person" suggestion; the editors' annotations' caption of how
// many volumes tag their people; a row opens the person's sheet (PersonSheet.tsx); and for a curator, Corrections,
// the app's sheet of the merges and separations made, each with Undo. A reader reads the people and corrects none.
// The web's own: the list is one of Browse's axes; a curator on an Import server is told that a correction waits for
// the next export; and what a correction did is said in the screen's status line, as the app's VoiceOver says it.
import { useQuery } from '@tanstack/react-query';
import { Link } from '@tanstack/react-router';
import { useId, useRef, useState } from 'react';
import { annotationLayerQuery } from '../api/annotations';
import { errorMessage } from '../api/client';
import { peopleQuery, personCorrectionsQuery, type PersonRow } from '../api/people';
import { meQuery } from '../api/userData';
import { BrowseAxes } from '../browse/BrowseAxes';
import { volumesLine } from '../browse/annotationRules';
import { copy } from '../copy';
import { useHeadingReady } from '../shell/headingFocus';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import { CorrectionsSheet } from './CorrectionsSheet';
import { displaySections, rowLabel } from './peopleRules';
import { PersonSheet } from './PersonSheet';

export function PeopleScreen() {
  const people = useQuery(peopleQuery);
  const me = useQuery(meQuery);
  const tagging = useQuery(annotationLayerQuery('people'));
  const curator = me.data?.userData === true && me.data.roles.includes('curator');
  const corrections = useQuery({ ...personCorrectionsQuery, enabled: curator });
  useDocumentTitle(copy.people.title);
  useHeadingReady(!people.isPending);
  const [query, setQuery] = useState('');
  // The sheet open, and the row that opened it, which focus goes back to, unless a correction rebuilt the list.
  const [open, setOpen] = useState<PersonRow | null>(null);
  const [showCorrections, setShowCorrections] = useState(false);
  const [status, setStatus] = useState('');
  const heading = useRef<HTMLHeadingElement>(null);
  const correctionsButton = useRef<HTMLButtonElement>(null);
  const opener = useRef<HTMLButtonElement | null>(null);
  const searchId = useId();
  const list = people.data;
  const sections = list ? displaySections(list, query.trim()) : [];

  const reach = tagging.data?.reach;
  const caption = reach && reach.total > 0 && (
    <p className="note people-caption">
      {copy.people.taggingCaption(volumesLine(reach.carrying, reach.total))}{' '}
      <Link to="/browse/annotations/$layer" params={{ layer: 'people' }}>
        {copy.people.taggingLink}
      </Link>
    </p>
  );

  return (
    <section className="screen browse people">
      <h1 ref={heading} tabIndex={-1}>
        {copy.people.title}
      </h1>
      <BrowseAxes current="people" />
      {curator && (
        <div className="people-tools">
          <button ref={correctionsButton} type="button" title={copy.people.correctionsHelp} onClick={() => setShowCorrections(true)}>
            {copy.people.corrections}
          </button>
          {corrections.data?.mode === 'import' && <p className="note">{copy.people.importNote}</p>}
        </div>
      )}
      <p className="visually-hidden" role="status">
        {status}
      </p>
      {people.isError ? (
        <p className="error" role="alert">
          {errorMessage(people.error)}
        </p>
      ) : !list ? (
        <p role="status">{copy.people.loading}</p>
      ) : list.count === 0 ? (
        <div className="empty">
          <h2>{copy.people.emptyTitle}</h2>
          <p>{copy.people.emptyDetail}</p>
          {caption}
        </div>
      ) : (
        <>
          <div className="people-search">
            <label htmlFor={searchId} className="visually-hidden">
              {copy.people.searchPrompt}
            </label>
            <input
              id={searchId}
              type="search"
              placeholder={copy.people.searchPrompt}
              value={query}
              autoComplete="off"
              onChange={(event) => setQuery(event.target.value)}
            />
          </div>
          {caption}
          {sections.length === 0 ? (
            <div className="empty">
              <h2>{copy.people.noResults(query.trim())}</h2>
              <p>{copy.people.noResultsDetail}</p>
            </div>
          ) : (
            sections.map((section) => (
              <section key={section.letter} className="people-section" aria-labelledby={`people-${section.letter}`}>
                <h2 id={`people-${section.letter}`}>{section.letter}</h2>
                <ul className="people-list">
                  {section.people.map((row) => (
                    <li key={row.rollupId}>
                      <button
                        type="button"
                        className="person-row"
                        aria-label={rowLabel(row)}
                        title={row.possibleDuplicate ? copy.people.candidateHelp : undefined}
                        onClick={(event) => {
                          opener.current = event.currentTarget;
                          setOpen(row);
                        }}
                      >
                        <span className="person-name">{row.name}</span>
                        {row.subtitle && <span className="meta">{row.subtitle}</span>}
                        <span className="person-marks" aria-hidden="true">
                          {row.possibleDuplicate && <span className="person-candidate">?</span>}
                          {row.mentionCount > 0 && <span className="badge">{row.mentionCount.toLocaleString('en-US')}</span>}
                        </span>
                      </button>
                    </li>
                  ))}
                </ul>
              </section>
            ))
          )}
        </>
      )}
      {open && list && (
        <PersonSheet
          key={open.rollupId}
          row={open}
          list={list}
          curator={curator}
          onClose={(said) => {
            setOpen(null);
            if (said) {
              // A correction rebuilt the list, and the row may be gone: the heading has the focus, the line says what happened.
              setStatus(said);
              requestAnimationFrame(() => heading.current?.focus());
            } else {
              const back = opener.current;
              requestAnimationFrame(() => (back?.isConnected ? back : heading.current)?.focus());
            }
          }}
        />
      )}
      {showCorrections && (
        <CorrectionsSheet
          onClose={(said) => {
            setShowCorrections(false);
            if (said) setStatus(said);
            requestAnimationFrame(() => correctionsButton.current?.focus());
          }}
        />
      )}
    </section>
  );
}
