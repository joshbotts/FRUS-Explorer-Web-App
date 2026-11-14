// Source Explorer (PLAN's S22d), at /sources/{volumeId}/{documentId}, which the reader's Sources opens: the
// app's `SourceExplorerView`, its sections in its order. The Source Note with its classification chip; the
// provenance panels the note's case names, or a Subject-Numeric citation's own, with the filing periods, the
// scans, the lot cards, the series facts and the library catalogue's answer; the pre-1906 rolls, or what a
// document with no note shows; the Archival Neighbors; the Archival Collection; and the Unprinted Material.
// Everything shown is resolved on the server by the kit, the panels' words where the kit writes them, and the
// app's own words otherwise (copy.ts). The web's own: the way back, the NARA Catalog section's line until this
// server searches the catalogue (PLAN's S22e), and a link to the neighbours in their three scopes.
import { useQuery } from '@tanstack/react-query';
import { getRouteApi, Link } from '@tanstack/react-router';
import { Children, type ReactNode, useId } from 'react';
import { ApiError, errorMessage } from '../api/client';
import { documentQuery } from '../api/endpoints';
import { type SourceExplorer, sourceExplorerQuery, type SourcePanel, type SourceRecord, type SourceScan } from '../api/sources';
import { copy } from '../copy';
import { useHeadingReady } from '../shell/headingFocus';
import { plainTitle, useDocumentTitle } from '../shell/useDocumentTitle';
import { ClassificationChip, ConfidenceChip, ProvenanceChip } from './Chips';
import { confirmedDay, curatedSubtitle, publishedLinks, publishedLinkStale, statusValue } from './sourcesRules';

const route = getRouteApi('/sources/$volumeId/$documentId');
const words = copy.sources;

export function SourcesScreen() {
  const { volumeId, documentId } = route.useParams();
  const anchor = useQuery(documentQuery(volumeId, documentId));
  const sources = useQuery(sourceExplorerQuery(volumeId, documentId));
  const title = anchor.data ? plainTitle(anchor.data.document.displayTitle ?? documentId) : documentId;
  useDocumentTitle(words.title);
  useHeadingReady(!sources.isPending);
  const preparing = sources.isError && sources.error instanceof ApiError && sources.error.code === 'INDEX_NOT_READY';

  return (
    <div className="sources">
      <p className="back">
        <Link to="/doc/$volumeId/$documentId" params={{ volumeId, documentId }}>
          <span aria-hidden="true">← </span>
          {words.back(title)}
        </Link>
      </p>
      <div className="sources-heading">
        <h1 tabIndex={-1} data-loading={sources.isPending ? 'true' : undefined}>
          {words.title}
        </h1>
        <About />
      </div>
      {sources.isPending && (
        <p className="note" role="status">
          {words.resolving}
        </p>
      )}
      {preparing && (
        <p className="note" role="status">
          {words.preparing}
        </p>
      )}
      {sources.isError && !preparing && (
        <p className="error" role="alert">
          {errorMessage(sources.error)}
        </p>
      )}
      {sources.data && <Explorer sources={sources.data} />}
    </div>
  );
}

/** The info button's popover (`FeatureInfoButton.sourceExplorer`), as a disclosure. */
function About() {
  return (
    <details className="sources-about">
      <summary>{words.info.heading}</summary>
      <dl>
        {words.info.rows.map((row) => (
          <div key={row.title}>
            <dt>{row.title}</dt>
            <dd>{row.detail}</dd>
          </div>
        ))}
      </dl>
    </details>
  );
}

/** The view's `body`: its sections in its order. */
export function Explorer({ sources }: { sources: SourceExplorer }) {
  return (
    <div className="se-sections">
      {sources.hasSourceNote && (
        <Section title={words.rawNote}>
          <p className="se-note">{sources.rawSourceNote}</p>
          {sources.classificationMarking && <ClassificationChip marking={sources.classificationMarking} />}
        </Section>
      )}
      {sources.provenance.map((panel, index) => (
        <Panel key={`${panel.kind}-${index}`} panel={panel} />
      ))}
      {sources.countrySeries && <CountrySeries series={sources.countrySeries} />}
      {sources.noSourceNote && <NoSourceNote section={sources.noSourceNote} />}
      <Neighbours sources={sources} />
      <ArchivalCollection collection={sources.collection} />
      {sources.unprinted && <Unprinted unprinted={sources.unprinted} />}
    </div>
  );
}

/** A section of the view's `Form`: its heading, its rows and its footer. */
function Section({ title, footer, children, label }: { title?: string; footer?: ReactNode; children: ReactNode; label?: string }) {
  const id = useId();
  return (
    <section className="se-section" aria-labelledby={title ? id : undefined} aria-label={title ? undefined : label}>
      {title && <h2 id={id}>{title}</h2>}
      <div className="se-body">{children}</div>
      {footer && <p className="se-footer">{footer}</p>}
    </section>
  );
}

/** The view's `LabeledContent` rows. */
function Rows({ rows }: { rows: [string, ReactNode | undefined][] }) {
  const shown = rows.filter((row): row is [string, ReactNode] => row[1] !== undefined && row[1] !== null && row[1] !== '');
  if (shown.length === 0) return null;
  return (
    <dl className="se-rows">
      {shown.map(([label, value], index) => (
        <div key={`${label}-${index}`}>
          <dt>{label}</dt>
          <dd>{value}</dd>
        </div>
      ))}
    </dl>
  );
}

/** A link out of the app, opened in a new tab, as the app's buttons open the browser. */
function Out({ href, children, className }: { href: string; children: ReactNode; className?: string }) {
  return (
    <a className={className ?? 'se-link'} href={href} target="_blank" rel="noopener noreferrer">
      {children}
    </a>
  );
}

/** A list of links, left out when none of its items is there, so that no list of nothing is announced. */
function Links({ children }: { children: ReactNode }) {
  return Children.toArray(children).length > 0 ? <ul className="se-links">{children}</ul> : null;
}

function Caption({ children }: { children: ReactNode }) {
  return <p className="se-caption">{children}</p>;
}

// MARK: - The provenance panels

function Panel({ panel }: { panel: SourcePanel }) {
  switch (panel.kind) {
    case 'subjectNumeric':
      return <SubjectNumeric panel={panel} />;
    case 'centralFiles':
      return (
        <Section title={words.provenance}>
          <Rows rows={[[words.type, words.centralFilesType(panel.recordGroup ?? '')], [words.fileIdentifier, panel.fileIdentifier]]} />
          <Caption>{words.centralFilesCite}</Caption>
        </Section>
      );
    case 'numericalFile':
      return <NumericalFile panel={panel} />;
    case 'filingPeriod':
      return <FilingPeriod panel={panel} />;
    case 'parisPeace':
      return <ParisPeace panel={panel} />;
    case 'digitizedScans':
      return <DigitizedScans panel={panel} />;
    case 'cfpf':
      return (
        <>
          <Section title={words.provenance}>
            <Rows rows={[[words.type, words.cfpfType], [words.recordGroup, 'RG 59'], [words.fileIdentifier, panel.fileIdentifier]]} />
            <Caption>{words.cfpfCite}</Caption>
          </Section>
          <Section title={words.cfpfResources}>
            <Links>
              {panel.links?.[0] && (
                <li>
                  <Out href={panel.links[0].url}>{words.cfpfGuide}</Out>
                </li>
              )}
              {panel.links?.[1] && (
                <li>
                  <Out href={panel.links[1].url}>{words.cfpfAAD}</Out>
                </li>
              )}
            </Links>
            <Caption>{words.cfpfNote}</Caption>
          </Section>
        </>
      );
    case 'lotFile':
      return (
        <Section title={words.provenance}>
          <Rows
            rows={[
              [words.type, panel.postRecords ? words.lotTypePost : words.lotType],
              [
                words.recordGroup,
                panel.recordGroup && (
                  <>
                    {panel.recordGroup} {panel.recordGroupSource && <ProvenanceChip source={panel.recordGroupSource} />}
                  </>
                ),
              ],
              [words.lotNumber, panel.lotNumber],
              [words.fileIdentifier, panel.fileIdentifier],
            ]}
          />
        </Section>
      );
    case 'naraCollection':
      return (
        <Section title={words.provenance}>
          <Rows
            rows={[
              [words.repository, words.nara],
              [words.recordGroup, panel.recordGroup && `RG ${panel.recordGroup}`],
              [words.series, panel.series],
              [words.lotFile, panel.lotFile],
              [words.box, panel.box],
            ]}
          />
        </Section>
      );
    case 'curatedLot':
      return <CuratedLot panel={panel} />;
    case 'bundledLot':
      return <BundledLot panel={panel} />;
    case 'naraCatalog':
      return (
        <Section title={words.naraHeader}>
          <p className="se-text">{words.notSearched}</p>
          {panel.catalogQuery?.manualSearchURL && <Out href={panel.catalogQuery.manualSearchURL}>{words.searchManually}</Out>}
        </Section>
      );
    case 'cia':
      return (
        <>
          <Section title={words.provenance}>
            <Rows rows={[[words.repository, words.cia], [words.ciaJob, panel.jobNumber], [words.box, panel.box]]} />
          </Section>
          <Section title={words.ciaHeader}>
            {panel.link && <Out href={panel.link.url}>{panel.jobNumber ? words.ciaLink : words.ciaLinkGeneral}</Out>}
            <Caption>{words.ciaNote}</Caption>
          </Section>
        </>
      );
    case 'presidentialLibrary':
      return (
        <Section title={words.provenance}>
          <Rows
            rows={[
              [words.type, words.libraryType],
              [words.library, panel.library],
              [words.collection, panel.libraryCollection],
              [words.fileIdentifier, panel.fileIdentifier],
            ]}
          />
        </Section>
      );
    case 'curatedLibrary':
      return (
        <Section title={words.findingAid}>
          <p className="se-text">{panel.link ? <Out href={panel.link.url}>{panel.title}</Out> : panel.title}</p>
          {panel.links?.[0] && <Out href={panel.links[0].url}>{words.catalogRecord}</Out>}
          {panel.rationale && <Caption>{panel.rationale}</Caption>}
        </Section>
      );
    case 'offlineLibrary':
      return <OfflineLibrary panel={panel} />;
    case 'outsideNARA':
      return (
        <Section title={words.naraHeader}>
          <p className="se-text">{words.outsideCustody(panel.library ?? '')}</p>
          {panel.guidance && (
            <div className="se-record">
              <p className="se-record-title">{panel.guidance.name}</p>
              {panel.guidance.formerName && (
                <p className="se-dates">
                  {panel.guidance.citedAsLabel}: {panel.guidance.formerName}
                </p>
              )}
              <Caption>{panel.guidance.holdings}</Caption>
              {panel.guidance.link && <Out href={panel.guidance.link.url}>{panel.guidance.link.label}</Out>}
            </div>
          )}
        </Section>
      );
    case 'namedFileSeries':
      return (
        <Section title={words.provenance}>
          <Rows rows={[[words.fileSeries, panel.seriesName], [words.recordGroup, panel.recordGroup], [words.file, panel.fileIdentifier]]} />
          {panel.explainer && <Caption>{panel.explainer}</Caption>}
          {panel.link && <Out href={panel.link.url}>{panel.link.label}</Out>}
        </Section>
      );
    case 'namedSeriesRouting':
      return (
        <Section title={panel.title}>
          <div className="se-record">
            {panel.notes?.[0] && <p className="se-label">{panel.notes[0]}</p>}
            {panel.notes?.[1] && <p className="se-record-title">{panel.notes[1]}</p>}
            {panel.link && <Out href={panel.link.url}>{panel.link.label}</Out>}
          </div>
          {panel.rationale && <Caption>{panel.rationale}</Caption>}
        </Section>
      );
    case 'foreignArchive':
      return (
        <>
          <Section title={words.provenance}>
            <Rows rows={[[words.type, words.foreignType]]} />
            <p className="se-note">{panel.description}</p>
          </Section>
          <Section label={words.foreignType}>
            <p className="se-text">{words.foreignNote}</p>
          </Section>
        </>
      );
    case 'previouslyPublished':
      return (
        <>
          <Section title={words.provenance}>
            <Rows rows={[[words.type, words.publishedType]]} />
            <p className="se-note">{panel.citation}</p>
          </Section>
          <Section label={words.publishedType}>
            <PublishedGuidance panel={panel} />
          </Section>
        </>
      );
    case 'unrecognized':
      return (
        <>
          <Section title={words.provenance}>
            <Rows rows={[[words.type, words.unrecognizedType]]} />
          </Section>
          <Section label={words.unrecognizedType}>
            <p className="se-text">{words.unrecognizedExplanation}</p>
          </Section>
        </>
      );
  }
}

/** `subjectNumericPanel(_:)`: the designation, its block of years, the era's page and its handbooks. */
function SubjectNumeric({ panel }: { panel: SourcePanel }) {
  const handbooks = panel.handbooks ?? [];
  return (
    <>
      <Section title={words.provenance}>
        <Rows
          rows={[
            [words.type, words.subjectNumericType],
            [words.recordGroup, 'RG 59'],
            [words.designation, panel.designation],
            [words.block, panel.block],
          ]}
        />
        <Caption>{words.subjectNumericCite}</Caption>
      </Section>
      <Section title={words.periodHeader}>
        <Rows rows={[[words.filingPeriod, words.subjectNumericPeriod]]} />
        <Links>
          {panel.period && (
            <li>
              <Out href={panel.period.url}>{words.periodLink}</Out>
            </li>
          )}
          {handbooks.length === 1 && handbooks[0] ? (
            <li>
              <Out href={handbooks[0].url}>{words.manualLink}</Out>
            </li>
          ) : (
            handbooks.map((handbook) => (
              <li key={handbook.url}>
                <Out href={handbook.url}>{handbook.label}</Out>
              </li>
            ))
          )}
        </Links>
        <Caption>{words.subjectNumericHint}</Caption>
      </Section>
    </>
  );
}

/** `numericalFileSection(fileIdentifier:)`: the rolls that hold a 1906–1910 file number, or the gap's links. */
function NumericalFile({ panel }: { panel: SourcePanel }) {
  const scans = panel.scans ?? [];
  return (
    <Section title={words.numericalFile}>
      {scans.length === 0 ? (
        <>
          <Caption>{words.numericalGap}</Caption>
          <Links>
            {panel.links?.[0] && (
              <li>
                <Out href={panel.links[0].url}>{words.cardIndex}</Out>
              </li>
            )}
            {panel.links?.[1] && (
              <li>
                <Out href={panel.links[1].url}>{words.numericalSeries}</Out>
              </li>
            )}
          </Links>
        </>
      ) : (
        <>
          <Caption>{words.numericalFound(panel.fileIdentifier ?? '')}</Caption>
          {scans.map((scan) => (
            <Scan key={scan.title + (scan.catalogURL ?? '')} scan={scan} />
          ))}
        </>
      )}
    </Section>
  );
}

/** `centralFilesPeriodSection(fileIdentifier:)`: the filing period a year resolves, or the full table. */
function FilingPeriod({ panel }: { panel: SourcePanel }) {
  return (
    <Section title={words.periodHeader}>
      {panel.period ? (
        <>
          <Rows rows={[[words.filingPeriod, panel.period.label]]} />
          <ul className="se-links">
            <li>
              <Out href={panel.period.url}>{words.periodLink}</Out>
            </li>
            {panel.manual && (
              <li>
                <Out href={panel.manual.url}>{words.manualLink}</Out>
              </li>
            )}
          </ul>
          <Caption>{words.periodHint}</Caption>
        </>
      ) : (
        <>
          <Caption>{words.noYear}</Caption>
          <ul className="se-periods">
            {(panel.periods ?? []).map((period) => (
              <li key={period.id}>
                <Out href={period.url}>{period.label}</Out>
                {period.manuals.length > 0 && (
                  <ul className="se-links">
                    {period.manuals.map((manual) => (
                      <li key={manual.url}>
                        <Out href={manual.url} className="se-link se-minor">
                          {manual.label}
                        </Out>
                      </li>
                    ))}
                  </ul>
                )}
              </li>
            ))}
          </ul>
        </>
      )}
    </Section>
  );
}

/** `parisPeaceSection()`: the Commission's records, in the kit's words, and NARA's finding aids, closed. */
function ParisPeace({ panel }: { panel: SourcePanel }) {
  return (
    <Section title={panel.title}>
      {(panel.records ?? []).map((record) => (
        <RecordRow key={record.title} record={record} />
      ))}
      {(panel.notes ?? []).map((note) => (
        <Caption key={note}>{note}</Caption>
      ))}
      <details className="se-disclosure">
        <summary>{panel.findingAidsTitle}</summary>
        {(panel.findingAids ?? []).map((record) => (
          <RecordRow key={record.title} record={record} />
        ))}
      </details>
    </Section>
  );
}

/** A catalog record: the label above it, NARA's title, its dates and its link. */
function RecordRow({ record, candidate }: { record: SourceRecord; candidate?: boolean }) {
  return (
    <div className="se-record">
      {record.label && <p className="se-label">{record.label}</p>}
      <p className="se-record-title">
        {record.title} {candidate && <ConfidenceChip />}
      </p>
      {record.dates && <p className="se-dates">{record.dates}</p>}
      {record.catalogURL && <Out href={record.catalogURL}>{words.viewRecord}</Out>}
    </div>
  );
}

/** `digitizedScansSection(fileIdentifier:)`: the range a citation's serial lands in, the ranges, or the class's. */
function DigitizedScans({ panel }: { panel: SourcePanel }) {
  const scans = panel.scans ?? [];
  return (
    <Section title={words.scans}>
      {panel.scanState === 'multiple' && <Caption>{words.scansMultiple(scans.length, panel.fileIdentifier ?? '')}</Caption>}
      {panel.scanState === 'classOnly' && (
        <Caption>{words.scansClassOnly(panel.rangeCount ?? 0, panel.series ?? '', panel.fileIdentifier ?? '')}</Caption>
      )}
      {scans.map((scan) => (
        <Scan key={scan.title + (scan.catalogURL ?? '')} scan={scan} />
      ))}
      {panel.caveat && <Caption>{panel.caveat}</Caption>}
    </Section>
  );
}

/** `digitizedScanRow(_:isCandidate:)`: a scan's title, its images, its PDF and its catalog record. */
function Scan({ scan }: { scan: SourceScan }) {
  return (
    <div className="se-record">
      <p className="se-record-title">
        {scan.title} {scan.candidate && <ConfidenceChip />}
      </p>
      {scan.imageCountLabel && <p className="se-dates">{scan.imageCountLabel}</p>}
      <Links>
        {scan.pdf && (
          <li>
            <Out href={scan.pdf.url}>{scan.pdf.label}</Out>
          </li>
        )}
        {scan.catalogURL && (
          <li>
            <Out href={scan.catalogURL}>{words.viewRecord}</Out>
          </li>
        )}
      </Links>
    </div>
  );
}

/** `curatedLotSection(_:)`: a curated outcome, hedged in each of its kinds. */
function CuratedLot({ panel }: { panel: SourcePanel }) {
  const outcome = panel.outcome;
  if (!outcome) return null;
  const series = outcome.series[0];
  if (outcome.kind === 'possible' && series) {
    return (
      <Section title={words.possibleHeader}>
        <p className="se-record-title">
          {series.title} <ConfidenceChip />
        </p>
        <Rows rows={[[words.hmsMlr, series.entryNumber], [words.seriesDates, series.dateRange]]} />
        <Caption>{outcome.rationale}</Caption>
        <Out href={series.catalogURL}>{words.openSeries}</Out>
        <Caption>{words.possibleNote}</Caption>
      </Section>
    );
  }
  if (outcome.kind === 'candidates') {
    return (
      <Section title={words.candidatesHeader}>
        <Caption>{outcome.rationale}</Caption>
        <Rows rows={[[words.creator, outcome.creatorName]]} />
        <ul className="se-candidates">
          {outcome.series.map((series) => {
            const subtitle = curatedSubtitle(series);
            return (
              <li key={series.catalogURL}>
                <Out href={series.catalogURL}>{series.title}</Out> <ConfidenceChip />
                {subtitle && <p className="se-caption">{subtitle}</p>}
              </li>
            );
          })}
        </ul>
        {outcome.seeAllURL && <Out href={outcome.seeAllURL}>{words.seeAll}</Out>}
        <Caption>{words.candidatesNote}</Caption>
      </Section>
    );
  }
  return (
    <Section title={words.referralHeader}>
      <p className="se-text">{outcome.rationale}</p>
      <Rows
        rows={[
          [words.seriesCount, outcome.seriesCount !== undefined ? String(outcome.seriesCount) : undefined],
          [words.entryRange, outcome.entryNumberRange],
        ]}
      />
      {outcome.guidance && <Caption>{outcome.guidance}</Caption>}
      {outcome.browseURL && <Out href={outcome.browseURL}>{words.browseSeries}</Out>}
    </Section>
  );
}

/** `bundledLotSection(_:)`: a lot's one bundled series, with NARA's creator and facts, and what to cite. */
function BundledLot({ panel }: { panel: SourcePanel }) {
  const lot = panel.lot;
  if (!lot) return null;
  const entries = lot.entryNumbers && lot.entryNumbers.length > 0 ? lot.entryNumbers : undefined;
  const seriesEntries = !entries && lot.seriesEntryNumbers && lot.seriesEntryNumbers.length > 0 ? lot.seriesEntryNumbers : undefined;
  return (
    <Section title={words.bundledHeader}>
      <p className="se-record-title">{lot.title}</p>
      <Rows
        rows={[
          [words.fileSeries, lot.seriesTitle],
          [words.creator, lot.creator],
          [words.access, lot.accessStatus && statusValue(lot.accessStatus, lot.accessRestrictions)],
          [words.use, lot.useStatus && statusValue(lot.useStatus, lot.useRestrictions)],
          [words.seriesDates, lot.years],
          [words.extent, lot.extent],
          [words.heldAt, lot.heldAt],
          [words.findingAids, lot.findingAids?.join(', ')],
          [words.hmsMlr, entries?.join(', ')],
          [words.hmsMlrSeries, seriesEntries?.join(', ')],
        ]}
      />
      {seriesEntries && <Caption>{words.hmsMlrSeriesNote}</Caption>}
      <Out href={lot.catalogURL}>{words.openSeries}</Out>
      {(entries || seriesEntries) && <Caption>{words.lotCite}</Caption>}
      <Caption>{words.bundledNote}</Caption>
    </Section>
  );
}

/** `offlineLibrarySection(_:)`: the bundled catalogue's collection and series, in the kit's words. */
function OfflineLibrary({ panel }: { panel: SourcePanel }) {
  const outcome = panel.libraryOutcome;
  if (!outcome) return null;
  return (
    <Section title={outcome.sectionTitle}>
      {outcome.collection && <RecordRow record={outcome.collection} />}
      {outcome.resolvedSeries && <RecordRow record={outcome.resolvedSeries} />}
      {outcome.caveat && <Caption>{outcome.caveat}</Caption>}
      {outcome.candidates.map((series) => (
        <RecordRow key={series.title + (series.catalogURL ?? '')} record={series} candidate />
      ))}
      <Caption>{outcome.provenanceNote}</Caption>
    </Section>
  );
}

/** `PublishedSourceGuidanceView`: the publication the grammar recognizes, what to look for, and its link. */
function PublishedGuidance({ panel }: { panel: SourcePanel }) {
  const publication = panel.publication ? words.publications[panel.publication] : undefined;
  const url = panel.publication ? publishedLinks[panel.publication] : undefined;
  if (!panel.publication || !publication) return <p className="se-text">{words.publishedNote}</p>;
  return (
    <div className="se-record">
      <p className="se-record-title">{publication.name}</p>
      {panel.publicationDesignation && <p className="se-text">{words.publishedLookFor(panel.publicationDesignation)}</p>}
      {url && <Out href={url}>{publication.link}</Out>}
      {url && publishedLinkStale() && <p className="se-dates">{words.publishedStale(confirmedDay())}</p>}
    </div>
  );
}

// MARK: - The other sections

/** `countrySeriesSection`: the series a pre-1906 document was likely filed in, and the serial to look for. */
function CountrySeries({ series }: { series: NonNullable<SourceExplorer['countrySeries']> }) {
  return (
    <Section title={words.countrySeries}>
      <Caption>{words.countrySeriesIntro}</Caption>
      {series.serial && (
        <div className="se-record">
          <p className="se-record-title">
            <span aria-hidden="true"># </span>
            {series.serial.title}
          </p>
          <Caption>{series.serial.caption}</Caption>
          <ProvenanceChip source="frusText" />
        </div>
      )}
      {series.enclosureNote && <Caption>{series.enclosureNote}</Caption>}
      {series.homes.map((home) => (
        <div className="se-record" key={`${home.part ?? ''}|${home.category}`}>
          <p className="se-record-title">
            {home.category} <ConfidenceChip label={home.confidence} level={home.confidenceLevel} />{' '}
            <ProvenanceChip source="naraCatalog" />
            {home.chiefOfMission && (
              <>
                {' '}
                <ProvenanceChip source="ohPeopleRegister" />
              </>
            )}
          </p>
          {home.part && <p className="se-label">{home.part}</p>}
          <Caption>{home.rationale}</Caption>
          <ul className="se-links">
            {home.rolls.map((roll) => (
              <li key={roll.catalogURL ?? roll.title}>{roll.catalogURL ? <Out href={roll.catalogURL}>{roll.title}</Out> : roll.title}</li>
            ))}
          </ul>
        </div>
      ))}
    </Section>
  );
}

/** `noSourceNoteSection`: why no roll was found for a document with no note, and the era's likely series. */
function NoSourceNote({ section }: { section: NonNullable<SourceExplorer['noSourceNote']> }) {
  let message: string | undefined;
  if (section.state === 'notChecked') {
    message = (section.reason && words.notChecked[section.reason]) ?? section.message;
  } else if (section.state === 'notApplicable') {
    message = section.message;
  } else {
    message = words.noNoteDetail;
  }
  return (
    <Section title={words.noNote}>
      {message && <Caption>{message}</Caption>}
      {section.predictedSeries && <Caption>{words.predictedSeries[section.predictedSeries]}</Caption>}
    </Section>
  );
}

/** `relatedDocumentsSection`: the documents from the same archival source, their line, and the match. */
function Neighbours({ sources }: { sources: SourceExplorer }) {
  const neighbours = sources.neighbours;
  const id = useId();
  const shown = neighbours.documents;
  return (
    <section className="se-section" aria-labelledby={id}>
      <div className="se-section-heading">
        <h2 id={id}>{words.neighbours}</h2>
        {shown.length > 0 && <span className="se-count">{neighbours.totalCount.toLocaleString('en-US')}</span>}
      </div>
      <div className="se-body">
        {shown.length > 0 ? (
          <>
            {neighbours.basis && <Caption>{neighbours.basis}</Caption>}
            <ol className="se-neighbours">
              {shown.map((document) => (
                <li key={`${document.volumeId}/${document.documentId}`}>
                  <Link to="/doc/$volumeId/$documentId" params={{ volumeId: document.volumeId, documentId: document.documentId }}>
                    {document.number && <span className="se-number">{document.number}</span>}
                    {plainTitle(document.title)}
                  </Link>
                  <p className="se-dates">
                    {document.volumeId}
                    {document.dateline && (
                      <>
                        <span aria-hidden="true"> · </span>
                        {document.dateline}
                      </>
                    )}
                  </p>
                </li>
              ))}
            </ol>
            {neighbours.totalCount > shown.length && <p className="se-dates">{words.neighboursMore(neighbours.totalCount - shown.length)}</p>}
          </>
        ) : (
          neighbours.emptyState && <p className="se-text">{words.neighboursEmpty[neighbours.emptyState]}</p>
        )}
        {shown.length > 0 && (
          <Link
            className="se-link"
            to="/archival-neighbors"
            search={{ volumeId: sources.volumeId, documentId: sources.documentId, year: sources.year }}
          >
            {words.allNeighbours}
          </Link>
        )}
      </div>
      {neighbours.matchKey && <p className="se-footer">{words.matchKey(neighbours.matchKey)}</p>}
    </section>
  );
}

/** `archivalCollectionSection`: the authority's record the note resolves to, which opens it. */
function ArchivalCollection({ collection }: { collection: SourceExplorer['collection'] }) {
  if (!collection) return null;
  return (
    <Section title={words.collectionHeader} footer={words.collectionFooter}>
      <div className="se-record">
        <Link className="se-record-title" to="/archival-collection" search={{ id: collection.id }}>
          {collection.name}
        </Link>
        <p className="se-dates">{words.collectionCited(collection.volumeCount)}</p>
        <ProvenanceChip source="frusText" />
      </div>
    </Section>
  );
}

/** `unprintedPointersSection`: the footnotes that point at material FRUS did not print, in reading order. */
function Unprinted({ unprinted }: { unprinted: NonNullable<SourceExplorer['unprinted']> }) {
  return (
    <Section title={words.unprinted} footer={unprinted.footer}>
      <ul className="se-unprinted">
        {unprinted.rows.map((row) => (
          <li key={row.id}>
            {/* The title as the volume prints it, "fn 2 · …", and as a screen reader says it, "Footnote 2, …". */}
            {row.record ? (
              <Link className="se-record-title" to="/archival-collection" search={{ id: row.record.id }}>
                <span aria-hidden="true">{row.title}</span>
                <span className="visually-hidden">{row.spokenTitle}</span>
              </Link>
            ) : (
              <p className="se-record-title">
                <span aria-hidden="true">{row.title}</span>
                <span className="visually-hidden">{row.spokenTitle}</span>
              </p>
            )}
            {row.clause && <p className="se-caption">{row.clause}</p>}
            {row.repeatNote && <p className="se-dates">{row.repeatNote}</p>}
            <p className="se-dates">
              {row.fileId && <span>{row.fileId} </span>}
              {row.inherited && (
                <span>
                  <span aria-hidden="true">↱ </span>
                  {words.inherited}{' '}
                </span>
              )}
              <ProvenanceChip source={row.source} />
            </p>
            {row.sameLotNote && (
              <p className="se-dates">
                <span aria-hidden="true">= </span>
                {row.sameLotNote}
              </p>
            )}
          </li>
        ))}
      </ul>
    </Section>
  );
}
