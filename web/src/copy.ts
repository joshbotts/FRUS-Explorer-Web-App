// Every string the app shows, in one place, for the string catalogue that check 10 will compare
// with the app's. Where the Mac app labels the same control, this uses its wording: Copy URL, Copy
// BibTeX, Copy RIS and Save as .bib (less its ellipsis, since a browser saves at once) from its
// Cite popover, Copy Citation from the reader, Document type and its choices from the search
// filters, Text Size from Settings; Browse's All Volumes, its filter's prompt, Partial, Planned and
// Documents (n); the person, term and unresolved-reference sheets' titles, sentences and Done, the
// person sheet's In Indexed Documents and its count, and
// the titles of the app's alerts for a person or term it has no entry for, whose sentences, about
// re-indexing on the Mac, are replaced; and the facet panel's titles, rows, controls and captions,
// with its filter tokens' field names, but for a sentence about the Mac's library. The rest, chiefly what only a server has (what it indexes,
// which TEI it holds), are the web's own until check 10 settles them.

export const copy = {
  app: {
    name: 'FRUS Explorer Light',
    skipToContent: 'Skip to content',
    navigation: 'Main',
    browse: 'Browse',
    search: 'Search',
    /** The browser tab's title for a screen. */
    title: (screen: string) => `${screen} – FRUS Explorer Light`,
    footer:
      'FRUS Explorer Light is a self-hosted edition of FRUS Explorer, with documents published by the Office of the Historian. This instance is not an Office of the Historian service.',
  },
  appearance: {
    label: 'Appearance',
    system: 'System',
    light: 'Light',
    dark: 'Dark',
  },
  readiness: {
    notReady: 'Search waits for an index.',
  },
  notFound: {
    title: 'Not found',
    body: 'Nothing is at this address.',
    toBrowse: 'Go to Browse',
  },
  search: {
    title: 'Search',
    label: 'Search the documents',
    submit: 'Search',
    syntax: 'Search syntax',
    syntaxBody:
      'Words are matched in any order, stemmed: treaty finds treaties. "Quoted words" are a phrase. AND, OR and NOT combine terms, and -word leaves a word out. Parentheses group. A trailing * matches a prefix. NEAR(word other, 10) finds words within 10 of each other. =word matches that exact word, unstemmed.',
    filters: 'Filters',
    documentType: 'Document type',
    documentTypes: { all: 'All', documentsOnly: 'Documents only', editorialNotesOnly: 'Editorial notes only' },
    dateFrom: 'From',
    dateTo: 'To',
    dateNote: 'A date range leaves out undated documents.',
    frontMatter: 'Include front matter',
    volumes: 'Volumes',
    removeVolume: (title: string) => `Remove ${title}`,
    /** A filter token's field, as the Mac's search window names it. */
    filterFields: { years: 'Years', person: 'Person', subject: 'Subject' },
    /** Up to three years by name, as the Mac's Years token shows them. */
    years: (years: readonly string[]) =>
      years.length === 0 ? 'none' : years.length <= 3 ? years.join(', ') : `${years.length.toLocaleString('en-US')} years`,
    narrowedBy: 'Narrowed by',
    clearThisFilter: 'clear this filter',
    narrowedFrom: (total: number) => `narrowed from ${total.toLocaleString('en-US')}`,
    results: 'Results',
    count: (total: number, basis: 'exact' | 'atLeast') =>
      `${basis === 'atLeast' ? 'At least ' : ''}${total.toLocaleString('en-US')} ${total === 1 ? 'document matches' : 'documents match'}`,
    showing: (first: number, last: number) => `showing ${first.toLocaleString('en-US')}–${last.toLocaleString('en-US')}`,
    coverage: (indexed: number, manifest: number) =>
      `in ${indexed.toLocaleString('en-US')} of ${manifest.toLocaleString('en-US')} volumes indexed on this server`,
    none: 'No documents match.',
    pastEnd: 'This page is past the last result.',
    searching: 'Searching…',
    editorialNote: 'Editorial Note',
    frontMatterBadge: 'Front Matter',
    pages: 'Pages',
    previous: 'Previous',
    next: 'Next',
    page: (page: number, pages: number) => `Page ${page} of ${pages}`,
    pageCount: (pages: number) => `${pages.toLocaleString('en-US')} ${pages === 1 ? 'page' : 'pages'}`,
    pageSize: 'Per page',
    retained: 'Pages reach the first 7,500 results, as on the Mac; narrow the search to see more.',
    notReady: (detail: string) => `The server has no index to search yet. ${detail}`,
  },
  facets: {
    toggle: 'Facets',
    toggleHelp:
      'Break the whole match down by year, volume, person, document type, archival provenance and subject — before any narrowing you apply',
    hideHelp: 'Hide the result-set facets',
    panel: 'Result-set facets',
    describing: (count: number) => `Describing all ${count.toLocaleString('en-US')} matches`,
    describingUnknown: 'Describing this result set — total unavailable',
    wholeMatch: 'Facets read the whole match, before any narrowing you apply below.',
    sections: {
      years: 'Years',
      volumes: 'Volumes',
      people: 'People',
      documentType: 'Document type',
      provenance: 'Archival provenance',
      subjects: 'Subjects',
    },
    counting: 'Counting…',
    none: 'Nothing to break down here.',
    failed: 'This breakdown could not be computed.',
    filterNoMatches: (total: number) => `No rows contain that. Clear the filter to see all ${total.toLocaleString('en-US')}.`,
    sortOrder: 'Sort order',
    rowsPerPage: 'Rows per page',
    filterRows: (count: number) => `Filter ${count.toLocaleString('en-US')} rows`,
    clearRowFilter: 'Clear filter',
    range: (first: number, last: number, matching: number) =>
      `Showing ${first.toLocaleString('en-US')}–${last.toLocaleString('en-US')} of ${matching.toLocaleString('en-US')}`,
    rangeFiltered: (first: number, last: number, matching: number, total: number) =>
      `${first.toLocaleString('en-US')}–${last.toLocaleString('en-US')} of ${matching.toLocaleString('en-US')} matching, ${total.toLocaleString('en-US')} in all`,
    previousPage: 'Previous page',
    nextPage: 'Next page',
    pageIndicator: (page: number, pages: number) => `${page} / ${pages}`,
    rowStates: { neutral: 'Not selected', included: 'Included', excluded: 'Excluded' },
    stagedHint: 'Cycles between included, excluded, and not selected. Choose rows, then Apply.',
    included: (count: number) => `${count.toLocaleString('en-US')} included`,
    excluded: (count: number) => `${count.toLocaleString('en-US')} excluded`,
    clear: 'Clear',
    apply: 'Apply',
    sectionChanged: 'These rows have changed since they were counted, so they are counted again. Choose again, then Apply.',
    narrowTo: (label: string) => `Narrow the search to ${label}`,
    /** The kit keys a document-type row 0 for documents and 1 for editorial notes. */
    documentTypes: { '0': 'Documents', '1': 'Editorial notes' } as Record<string, string>,
    undated: (count: number) => `${count.toLocaleString('en-US')} matched documents carry no date and appear in no year above.`,
    bound: (shown: number, total: number) =>
      `This breakdown stopped at ${shown.toLocaleString('en-US')} of ${total.toLocaleString('en-US')} values.`,
    concentration: (percent: number) => `The top three hold ${percent}% of the match.`,
    provenanceCoverage: (parsed: number, matches: number, withRecordGroup: number) =>
      `Source notes parsed for ${parsed.toLocaleString('en-US')} of ${matches.toLocaleString('en-US')} matches; ${withRecordGroup.toLocaleString('en-US')} name a record group.`,
    provenanceDescriptive: 'Descriptive only — the search has no provenance filter to narrow to.',
    subjectsCoverage: (detected: number, matches: number) =>
      `Subjects detected for ${detected.toLocaleString('en-US')} of ${matches.toLocaleString('en-US')} matches.`,
    subjectsPreparing: 'Subjects are still being prepared for this server — this breakdown is not complete yet.',
    subjectsSource: 'Detected topics from the Office of the Historian, matched by name — not the volumes’ own markup.',
  },
  browse: {
    title: 'All Volumes',
    breadcrumb: 'Breadcrumb',
    filter: 'Title or volume number',
    subseries: 'Subseries',
    allSubseries: 'All subseries',
    indexedOnly: 'Indexed on this server',
    showing: (shown: number, total: number) =>
      `Showing ${shown.toLocaleString('en-US')} of ${total.toLocaleString('en-US')} volumes`,
    coverage: (indexed: number, withTEI: number) =>
      `${indexed.toLocaleString('en-US')} indexed on this server · ${withTEI.toLocaleString('en-US')} with their TEI on this server`,
    noMatches: 'No Matching Volumes',
    noMatchesDetail: 'No volume title or number matches this search.',
    partial: 'Partial',
    planned: 'Planned',
    indexed: 'Indexed',
    teiHere: 'TEI on this server',
    published: (date: string) => `Published ${date}`,
    generalEditor: (name: string) => `General Editor: ${name}`,
    partiallyPublished: 'Partially Published',
    documentCoverage: (indexed: number, total: number) =>
      `${indexed.toLocaleString('en-US')} of ${total.toLocaleString('en-US')} ${total === 1 ? 'document' : 'documents'} indexed on this server`,
    noTEI: 'Its TEI isn’t on this server, so its documents can’t be read here.',
    sections: 'Sections',
    documents: (count: number) => `Documents (${count.toLocaleString('en-US')})`,
    noContents: 'Neither an index nor the TEI on this server gives this volume’s contents.',
    notIndexedBadge: 'Not indexed on this server',
    editorialNote: 'Editorial Note',
    loading: 'Loading…',
  },
  reader: {
    previous: 'Previous',
    next: 'Next',
    openOnline: 'Open on history.state.gov',
    textSize: 'Text Size',
    textSizes: { small: 'Small', medium: 'Medium', large: 'Large', extraLarge: 'Extra Large' },
    cite: 'Cite',
    frameTitle: (header: string) => `Document text: ${header}`,
    toolbar: 'Document',
    loading: 'Loading the document…',
    linkNotOnServer: (title: string) => `The linked document is in “${title}”, which isn’t on this server.`,
    linkUnknownVolume: 'The referenced volume isn’t part of this collection.',
    linkPageNotIndexed: (page: number, title: string) =>
      `Page ${page} is in “${title}”, which this server hasn’t indexed, so it can’t say which document is on it.`,
    linkPageNotPlaced: (page: number) => `This server’s index places no document on page ${page}.`,
    linkUnresolved: 'This reference has no destination that can be opened.',
    linkExternal: 'This link leads outside FRUS Explorer Light:',
    linkBrokenUnknown: 'This reference could not be resolved.',
  },
  card: {
    done: 'Done',
    personUnavailable: 'Person Information Unavailable',
    personUnavailableDetail: 'The volume’s list of names has no entry for this person.',
    termUnavailable: 'Term Definition Unavailable',
    termUnavailableDetail: 'The volume’s list of abbreviations and terms has no entry for this term.',
    unresolved: 'Unresolved Reference',
    unresolvedReason: (reason: string) =>
      reason === 'unknownPage'
        ? 'The page this reference cites could not be found in the cited volume.'
        : reason === 'unknownVolume'
          ? 'The referenced volume isn’t part of this collection.'
          : reason === 'emptyTarget'
            ? 'This cross-reference has no destination.'
            : 'The document or section this reference cites no longer exists in the cited volume.',
    apparentDestination: 'Apparent destination',
    flagged: 'Flagged by FRUS Explorer’s corpus-wide cross-reference validation.',
    inIndexedDocuments: 'In Indexed Documents',
    /** As the app's sheet writes it, the number grouped as its localized string groups it. */
    mentionedIn: (count: number) =>
      `Mentioned in ${count.toLocaleString('en-US')} indexed ${count === 1 ? 'document' : 'documents'}`,
    notMentioned: 'Not found in indexed documents',
  },
  cite: {
    title: 'Cite',
    style: 'Citation style',
    copyCitation: 'Copy Citation',
    copyLink: 'Copy URL',
    copyBibTeX: 'Copy BibTeX',
    copyRIS: 'Copy RIS',
    saveBibTeX: 'Save as .bib',
    copied: 'Copied',
    copyFailed: 'The browser did not allow copying. The text is selected below: press ⌘C or Ctrl+C.',
    toCopy: 'Text to copy',
    close: 'Close',
  },
} as const;
