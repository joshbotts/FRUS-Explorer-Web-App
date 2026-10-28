// Every string the app shows, in one place, for the string catalogue that check 10 will compare
// with the app's. Where the Mac app labels the same control, this uses its wording: Copy URL, Copy
// BibTeX, Copy RIS and Save as .bib (less its ellipsis, since a browser saves at once) from its
// Cite popover, Copy Citation from the reader, Document type and its choices from the search
// filters, Text Size, and Reading Width with its Narrow, Standard and Wide, from Settings; Browse's
// All Volumes, its filter's prompt, Partial, Planned and
// Documents (n), and the row of a section's own text, Read and the section's title over its
// sentence; the person, term and unresolved-reference sheets' titles, sentences and Done, the
// person sheet's In Indexed Documents and its count, and
// the titles of the app's alerts for a person or term it has no entry for, whose sentences, about
// re-indexing on the Mac, are replaced; the facet panel's titles, rows, controls and captions,
// with its filter tokens' field names, but for a sentence about the Mac's library; and the Query
// Inspector's strip, the search window's view of a search that found nothing, and its sort bar's
// label and tooltips, where "this device" and "you have indexed" become this server; the Reading
// picker and its tooltip, the timeline's Chart and List, its lines for loading, for no dated
// documents and for the undated, and its caption for a search kept in part, and the concordance's
// Align by, its count, its view of no aligned occurrences and its two notes of what it left out,
// with the singulars the Mac's count and notes lack; the line a
// volume's page shows when a page link opened it, where "isn't downloaded" becomes what this server
// lacks of the volume; and the Research rail's header, its Tags section and Add Tag, the tag
// picker's document mode, and Settings ▸ Tags with its pane's lines, the tag editor and Merge Tag,
// where Delete Tag's question takes the editor's own sentence of what deleting does, since the
// count it names comes later (PLAN's S17b); the four highlight colours, the selection bar's names
// for them, Highlight Yellow and the rest, the Remove Highlight
// question, and the review sheet's Highlights, Remove…, Highlighted passage and its two lines for a
// highlight made against an earlier version of the text; and from S15d the selection bar's Note,
// the Research tab's name, the rail's Notes section, its Empty note, Add Note to Highlight and Add
// Note, its Summary section with the Mac's summary block's AI summary, its prompt's name and its
// history control, and the headnote chips' AI · edited and Yours for the other authorships; the note
// editor's titles, sections, empty lines, new tag field, Insert into note and Remove from note,
// Delete, Discard and Save, and its Formatting switch by its visible word, since the switch's
// hidden "Formatted text" would not match what it shows; the formatting bar's Bold, Italic,
// Underline, Text Color and Link selected text to a URL, and its link popover with the iPhone's
// Cancel; All Notes with its filters, its rows' Empty note, its empty states, its count from the
// app's sheet and its Delete Note? question; and the Markdown export's action, its line while it
// is prepared, its line for no notes and its footer; from S19a Search's Find by Citation and
// Citation Lookup's window, its modes, fields, prompts, Look Up, its results, errors and empty states,
// View Document, and Batch's table with its sort and its rows' labels; and from S16c the names of the
// records an import's report counts, its export sheet's Contents, and its sentence for a smart
// collection whose saved search is gone. The selection bar's name, Selection, the
// formatting bar's, Text formatting, its glyphs, Write a Summary, Edit… and Delete… for a summary
// of one's own and the question before it, the visible Delete… on All Notes' rows, the rail's times,
// Settings ▸ Data's title and the lines for an editor that could not load or a note, formatted or
// plain, it could not show are the web's own, and so is the import's every other word, S16e's
// mark of a note block or a summary from a research database, since the app imports none, and from
// S14e the header's line naming the user and the footer's saying what the operator can read. The rest,
// chiefly what only a server has (what it indexes, which TEI it holds), are the web's own until
// check 10 settles them.

export const copy = {
  app: {
    name: 'FRUS Explorer Light',
    skipToContent: 'Skip to content',
    navigation: 'Main',
    browse: 'Browse',
    search: 'Search',
    /** The Research tab's name, the app's: All Notes until S19b's Research page. */
    research: 'Research',
    settings: 'Settings',
    /** The browser tab's title for a screen. */
    title: (screen: string) => `${screen} – FRUS Explorer Light`,
    footer:
      'FRUS Explorer Light is a self-hosted edition of FRUS Explorer, with documents published by the Office of the Historian. This instance is not an Office of the Historian service.',
    /** Behind a proxy that signs people in (PLAN's S14e): who the proxy named. */
    signedInAs: (name: string) => `Signed in as ${name}`,
    /** And what SPEC's Privacy asks the app to say once someone has signed in. */
    operatorReads:
      'Whoever runs this instance can read everything it keeps for you, your tags, highlights, notes and summaries included.',
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
    /** Search in, as the Mac's window offers it (`ScopeChip`): its lead-in, each chip and its help, and the refusal with all three off. */
    searchIn: 'Search in',
    scopes: { documents: 'Documents', notes: 'Notes', summaries: 'Summaries' },
    scopeHelp: {
      documents: 'Search the full text of FRUS documents (header, dateline, source note, body)',
      notes: 'Search the body text of your research notes',
      // The web's own: the Mac's "Search the text of generated AI summaries" is all a Mac holds, and
      // the web keeps the summaries a researcher writes too.
      summaries: 'Search the text of generated AI summaries and your own',
    },
    emptyScope: 'Enable at least one of Documents, Notes, or Summaries to search.',
    /** The Mac's My Tags, the filter's toggles of the user's tags, with each one's count over the results. */
    myTags: 'My Tags',
    /** What the closed filter says of its toggles, as the Mac's collapsed section does. */
    myTagsSummary: (count: number) => (count === 0 ? 'Any' : `${count.toLocaleString('en-US')} selected`),
    myTagsCountFooter: 'Counts are documents in your current results carrying that tag.',
    myTagCount: (name: string, count: number) => `${name}: ${count.toLocaleString('en-US')} documents in your current results`,
    /** The Tags token's value, as the Mac's `tagFilterLabel` gives it, when the list does not name its one tag, or for several. */
    tagsToken: { unresolved: '1 tag', count: (count: number) => `${count.toLocaleString('en-US')} tags` },
    /** A row's tags, the web's name for the list of the Mac's ◆ chips. */
    rowTags: 'Your tags',
    volumes: 'Volumes',
    removeVolume: (title: string) => `Remove ${title}`,
    /** A filter token's field, as the Mac's search window names it; a recalled search's phrase, prefix and excluded terms are the web's own. */
    filterFields: { years: 'Years', person: 'Person', tags: 'Tags', subject: 'Subject', phrase: 'Phrase', prefix: 'Prefix', excluding: 'Excluding' },
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
    /** The notice above the results when a search keeps only part of its match, as the Mac's window gives it. */
    overCap: (loaded: number, total: number) => `Showing ${loaded.toLocaleString('en-US')} of ${total.toLocaleString('en-US')} matches`,
    overCapGuidance: 'Narrow your search with a date range, volume filter, or more specific terms to load every match.',
    notReady: (detail: string) => `The server has no index to search yet. ${detail}`,
    /** The sort bar's label and each order's tooltip; the orders' own labels are the kit's, from the server. */
    sort: 'Sort',
    sortHelp: {
      relevance: 'Sort results by BM25 relevance — best matches first',
      dateAscending: 'Sort by document date, oldest first. Undated documents go to the end.',
      dateDescending: 'Sort by document date, most recent first. Undated documents go to the end.',
    } as Record<string, string>,
  },
  /**
   * Saved searches (S17e), in the words of the Mac's Save Search sheet (`SaveSearchSheet`), its toolbar's two
   * bookmark buttons and its Saved Searches sheet (`SavedSearchesView`), with the NEW capsule and "+N since last
   * run". The sheet's empty line, which names the Mac's bookmark button, and the line for what a Mac's saved
   * search sets that a recall here runs without, are the web's own.
   */
  savedSearches: {
    save: 'Save this search',
    saveHelp: 'Save this search so you can quickly run it again',
    open: 'Saved searches',
    openHelp: 'Browse and re-run your saved searches',
    saveTitle: 'Save Search',
    nameLabel: 'Name',
    namePlaceholder: 'Name this search',
    queryLabel: 'Query',
    saveButton: 'Save',
    cancel: 'Cancel',
    title: 'Saved Searches',
    emptyTitle: 'No Saved Searches',
    emptyDetail: 'Use Save this search in Search to save a search for quick access later.',
    done: 'Done',
    rename: 'Rename',
    renameTitle: 'Rename',
    renamePlaceholder: 'Name',
    renameSave: 'Save',
    renameCancel: 'Cancel',
    delete: 'Delete',
    newBadge: 'NEW',
    fresh: (count: number) => `+${count.toLocaleString('en-US')} since last run`,
    notRecalled: (names: readonly string[]) => `Runs here without what only the Mac’s search sets: ${names.join(', ')}.`,
    notRecalledNames: {
      booleanMode: 'any of the words',
      personRef: 'a person in one volume',
      projectId: 'a project',
      subjectRef: 'a topic',
    } as Record<string, string>,
  },
  /**
   * Working corpora (S17e), in the words of the Mac's Save as Working Corpus (`SaveWorkingCorpusSheet`), the
   * banner over a search inside one, the filter's My Working Corpora, and Browse's Working Corpora
   * (`CorporaIndexView`, `CorpusDocumentsView`), where "this device" becomes this server; the lines that name the
   * semantic map, iCloud and Settings are the web's own, and so are Rename and Delete, which the Mac keeps in its
   * Settings.
   */
  corpora: {
    save: 'Save as Working Corpus…',
    saveHelp: 'Save these results as a named working corpus you can search inside later',
    saveTitle: 'Save Working Corpus',
    nameHeader: 'Name',
    namePlaceholder: 'Corpus name',
    duplicate: 'You already have a corpus with this name. Both will be kept.',
    captured: 'Captured',
    documents: 'Documents',
    from: 'From',
    narrowedBy: 'Narrowed by',
    indexedNow: 'Volumes indexed now',
    footer:
      'The set is fixed at capture. Re-running the query later may find different documents; this corpus will not change, which is what makes counts taken inside it reproducible.',
    cancel: 'Cancel',
    saveButton: 'Save',
    preparing: 'Counting what this search shows…',
    inside: (name: string) => `Inside “${name}”`,
    insideUnknown: 'Inside a working corpus',
    leaveHelp: 'Leave this working corpus and search the full scope again',
    leave: 'Leave this working corpus',
    filterTitle: 'My Working Corpora',
    filterFooter: 'A working corpus is a fixed set of documents. Applying one searches only inside it. Manage them in Browse.',
    clear: 'Clear working corpus',
    noneIndexed: (name: string) => `None of “${name}” is indexed on this server.`,
    coverage: (indexed: number, total: number) =>
      `${indexed.toLocaleString('en-US')} of ${total.toLocaleString('en-US')} ${total === 1 ? 'document' : 'documents'} indexed on this server`,
    title: 'Working Corpora',
    emptyTitle: 'No Working Corpora',
    emptyDetail: 'A working corpus is a fixed set of documents captured from a result set — use “Save as Working Corpus” on Search results.',
    listFooter: 'A corpus is captured from a result set, in Search results, and kept on this server for you. There is nothing to create here.',
    untitled: 'Untitled Corpus',
    rowCount: (count: number) => `${count.toLocaleString('en-US')} documents`,
    capturedFrom: (query: string) => `captured from “${query}”`,
    rowLabel: (name: string, count: number) => `${name}, ${count.toLocaleString('en-US')} documents`,
    rowHelp: 'Browse this corpus’s documents, grouped by volume',
    unavailableTitle: 'Corpus Unavailable',
    unavailableDetail: 'This corpus no longer exists — it may have been deleted.',
    notIndexed: 'Not indexed on this server',
    rename: 'Rename Corpus',
    renameTitle: 'Rename Working Corpus',
    delete: 'Delete Corpus',
    deleteTitle: 'Delete Working Corpus?',
    deleteMessage: 'The corpus is deleted. Its documents, and searches saved inside it, are not.',
    deleteConfirm: 'Delete',
  },
  /**
   * Volume scopes (S17e), in the words of the Mac's filter's My Volume Scopes, Browse's My Scopes
   * (`ScopeIndexView`) and its scope editor (`ScopeEditorView`), where "this device" becomes this server; the
   * lines that name Save as Scope, iCloud and Settings are the web's own, and so is Delete Scope, which the Mac
   * keeps in its Settings.
   */
  scopes: {
    filterTitle: 'My Volume Scopes',
    filterFooter: 'Applying a scope fills the volume picker with its indexed members. Manage scopes in Browse.',
    indexedOf: (indexed: number, total: number) =>
      `${indexed.toLocaleString('en-US')} of ${total.toLocaleString('en-US')} volumes indexed`,
    noneIndexedRow: 'No indexed volumes',
    applyHint: 'Fills the volume picker with this scope’s indexed volumes',
    noneIndexed: (name: string) => `No volumes of “${name}” are indexed on this server.`,
    title: 'My Scopes',
    emptyTitle: 'No Scopes Yet',
    emptyDetail: 'A scope is a set of volumes you assemble yourself. Create one here.',
    coverage: 'Volume sets you assemble yourself, most recently edited first. Scopes also narrow Search.',
    new: 'New Scope',
    newHelp: 'Create an empty scope and choose its volumes',
    untitled: 'Untitled Scope',
    rowEmpty: 'No volumes yet',
    rowCaption: (count: number, edited?: string) =>
      `${count.toLocaleString('en-US')} volumes${edited ? ` · edited ${edited}` : ''}`,
    rowLabel: (name: string, count: number) => `${name}, ${count.toLocaleString('en-US')} volumes`,
    edit: (name: string) => `Edit ${name}`,
    editHelp: 'Rename this scope or change its volumes',
    drillCaption: (count: number) => `${count.toLocaleString('en-US')} volumes in this scope, by volume number.`,
    drillMissing: (count: number) => `Entries referencing volumes outside this server’s catalogue: ${count.toLocaleString('en-US')}.`,
    editTitle: 'Edit Scope',
    nameHeader: 'Name',
    namePrompt: 'Scope name',
    clearName: 'Clear the scope name',
    volumesHeader: (count: number) => `Volumes (${count.toLocaleString('en-US')})`,
    addVolumes: 'Add Volumes…',
    addVolumesHelp: 'Choose volumes from the All Volumes catalogue',
    editorFooter: 'Removing a volume never deletes it from this server.',
    remove: (volumeId: string) => `Remove ${volumeId} from this scope`,
    unresolved: 'Not in this server’s catalogue',
    pickerTitle: 'Add Volumes',
    pickerDone: 'Done',
    pickerCancel: 'Cancel',
    done: 'Done',
    unavailableTitle: 'Scope Unavailable',
    unavailableDetail: 'This scope no longer exists — it may have been deleted.',
    delete: 'Delete Scope',
    deleteTitle: 'Delete Scope?',
    deleteMessage: 'The scope is deleted. Its volumes are not.',
    deleteConfirm: 'Delete',
    deleteCancel: 'Cancel',
  },
  /** Checklist Mode (S17e), the Mac's toolbar toggle, strip, row action and empty state (`ChecklistCopy`). */
  checklist: {
    toggle: 'Checklist',
    toggleName: 'Checklist Mode',
    onHelp: 'Checklist review mode — hide results as you review them',
    offHelp: 'Turn off Checklist Mode and show every result',
    hidden: (count: number) => `${count.toLocaleString('en-US')} reviewed hidden`,
    nothingHidden: 'Nothing hidden',
    markPage: 'Mark Page Reviewed',
    markPageHelp: 'Hide every result on this page as reviewed',
    undo: 'Undo',
    undoHelp: 'Bring back the results the last Mark Page Reviewed hid',
    marked: (count: number) => `${count.toLocaleString('en-US')} ${count === 1 ? 'result' : 'results'} marked reviewed`,
    undone: (count: number) => `${count.toLocaleString('en-US')} ${count === 1 ? 'result is' : 'results are'} back in the list`,
    markReviewed: 'Mark Reviewed',
    allReviewedTitle: 'All Results Reviewed',
    allReviewedDetail: 'You’ve reviewed every result. Turn off Checklist Mode to see them again.',
  },
  /** Browse's axes, as the Mac's sidebar names the three the web has; the group's name is the web's own. */
  axes: {
    label: 'Browse by',
    volumes: 'All Volumes',
    corpora: 'Working Corpora',
    scopes: 'My Scopes',
  },
  /** The Reading picker, as the Mac's window titles it, and the set each reading covers, from its tooltip. */
  readings: {
    label: 'Reading',
    help: 'How to read these results. The concordance covers this page; the others cover the whole retained set.',
    titles: { list: 'List', timeline: 'Timeline', concordance: 'Concordance' },
  },
  timeline: {
    /** The mode picker's name, which the Mac's segmented picker hides. */
    viewMode: 'View mode',
    modes: { chart: 'Chart', list: 'List' },
    loading: 'Loading timeline…',
    emptyTitle: 'No Dated Documents',
    emptyDetail: 'None of these documents have machine-readable dates.',
    undated: (count: number) =>
      `${count.toLocaleString('en-US')} ${count === 1 ? 'document' : 'documents'} without a reliable date excluded from the timeline.`,
    /** Above the chart when the search keeps only part of its match: the shape is a ranking's. */
    bias: 'These are the highest-scoring matches, not a sample across time — this shape is theirs, not the whole match’s.',
    /** The chart's axes, as the Mac's chart names them. */
    year: 'Year',
    documents: 'Documents',
    /** The chart's name for assistive technology, and the web's own words for its table. */
    chartLabel: (first: string, last: string, documents: number, years: number) =>
      first === last
        ? `Documents per year: ${documents.toLocaleString('en-US')} in ${first}`
        : `Documents per year, ${first} to ${last}: ${documents.toLocaleString('en-US')} in ${years.toLocaleString('en-US')} years`,
    table: 'Table of the counts',
    /** What the chart says of the bar under the pointer. */
    readout: (year: string, count: number) => `${year}: ${count.toLocaleString('en-US')} ${count === 1 ? 'document' : 'documents'}`,
    failed: 'The timeline could not be computed.',
  },
  concordance: {
    alignBy: 'Align by',
    /** Unqualified on one page, where “on this page” says nothing. */
    count: (occurrences: number, documentsOnPage: number, singlePage: boolean) =>
      `${occurrences.toLocaleString('en-US')} ${occurrences === 1 ? 'occurrence' : 'occurrences'}${
        singlePage ? '' : ` in the ${documentsOnPage.toLocaleString('en-US')} ${documentsOnPage === 1 ? 'document' : 'documents'} on this page`
      }`,
    emptyTitle: 'No Aligned Occurrences',
    emptyDetail:
      'These results matched, but none of their text could be aligned on your search term. Phrase, wildcard and proximity searches match in ways a concordance cannot center on a single word.',
    omitted: (count: number, limit: number) =>
      count === 1
        ? `1 further occurrence isn’t shown — each document contributes at most ${limit.toLocaleString('en-US')} lines.`
        : `${count.toLocaleString('en-US')} further occurrences aren’t shown — each document contributes at most ${limit.toLocaleString('en-US')} lines.`,
    unaligned: (count: number) =>
      count === 1
        ? '1 matching document contributed no line — its match isn’t a whole word this view can center on.'
        : `${count.toLocaleString('en-US')} matching documents contributed no line — their match isn’t a whole word this view can center on.`,
    /** The lines' name for assistive technology, the web's own. */
    lines: 'Occurrences',
    loading: 'Building the concordance…',
    failed: 'The concordance could not be built.',
  },
  inspector: {
    /** The strip's name for assistive technology; the Mac's strip shows no title. */
    label: 'Query Inspector',
    matchTag: 'MATCH',
    showDetail: 'Show term detail',
    hideDetail: 'Hide term detail',
    approximate:
      'Narrower than typed: part of this query only excludes terms, and a search needs something to find, so that part was left out.',
    filterOnly: 'No text search — this query is filters only, so there is no expression to show.',
    refusedNear: (proximity: string) =>
      `No expression — ${proximity} holds something a NEAR cannot: a boolean, a minus sign, a nested group, or a distance that is not a whole number. The query was refused rather than run as an ordinary boolean search.`,
    /** The parser's limit on nesting, FTS5InlineQueryParser.maximumGroupDepth, which a server test holds this to. */
    refused:
      'No expression — this query cannot run: nothing is left to search for once its exclusions apply, or its parentheses nest more than 32 deep.',
    excludedTag: 'EXCLUDED',
    exactTag: 'EXACT',
    structuredTag: 'ADVANCED',
    notAppliedTag: 'NOT APPLIED',
    stemWarning: (text: string, stem: string) => `${text} is searched as ${stem} — other words with that root match too`,
    countInScope: 'Count each term in scope…',
    counting: 'Counting…',
    notAppliedDetail:
      'not searched — this part of the query only excludes, and a search needs something to find, so it was left out',
    excludedDetail: 'excluded — documents containing this are removed wherever the expression above applies it',
    scopedCount: (count: number) => `${count.toLocaleString('en-US')} in your current scope`,
    corpusCount: (count: number) => `${count.toLocaleString('en-US')} across everything this server has indexed`,
    /** The figure to one place, half to even, as the Mac's formatter rounds it. */
    occurrences: (count: number, perDocument: number) =>
      `${count.toLocaleString('en-US')} occurrences, ${perDocument.toLocaleString('en-US', { minimumFractionDigits: 1, maximumFractionDigits: 1, roundingMode: 'halfEven' })} per document`,
    noCount: 'no corpus count — this term has no single index form',
    denominator: (volumes: number) =>
      `Counts are over the ${volumes.toLocaleString('en-US')} volumes indexed on this server — not the whole published series.`,
  },
  /** The search window's view of a search that found nothing, which names the term responsible. */
  zeroResult: {
    title: 'No Results',
    combination: 'Each of your terms matches something on its own — it is the combination that appears in no single document.',
    detail: 'Try different keywords or adjust your filters.',
    oneEmpty: (term: string) => `${term} matches no document in your current scope. The rest of your query is not the problem.`,
    severalEmpty: (terms: readonly string[]) => `${terms.join(', ')} match no document in your current scope.`,
    denominator: (volumes: number) => `0 here means 0 in what this server has indexed — ${volumes.toLocaleString('en-US')} volumes.`,
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
    /** The line the page shows when a page link opened it, as the app's FollowedPageLink.notice words it for a volume not downloaded. */
    followedPage: (page: number, teiAvailable: boolean) =>
      `You followed a link to page ${page} of this volume, which ${teiAvailable ? 'this server hasn’t indexed' : 'isn’t on this server'}.`,
    sections: 'Sections',
    documents: (count: number) => `Documents (${count.toLocaleString('en-US')})`,
    /** The row of a section's own text, as the app's Browse names it, by the section's title. */
    readSection: (title: string) => `Read ${title}`,
    /** The sentence under that row, the app's. */
    ownTextNote: 'The text this section prints outside the documents and sections it holds.',
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
    readingWidth: 'Reading Width',
    readingWidths: { narrow: 'Narrow', standard: 'Standard', wide: 'Wide' },
    cite: 'Cite',
    research: 'Research',
    frameTitle: (header: string) => `Document text: ${header}`,
    toolbar: 'Document',
    /** The selection bar's name, the web's own: the Mac's bar names only its verbs. */
    selectionBar: 'Selection',
    loading: 'Loading the document…',
    linkNotOnServer: (title: string) => `The linked document is in “${title}”, which isn’t on this server.`,
    linkUnknownVolume: 'The referenced volume isn’t part of this collection.',
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
  /** The reader's Research rail and its Tags section, in the app's words. */
  research: {
    title: 'Research',
    close: 'Close',
    tags: 'Tags',
    /** The section's badge: how many tags the document carries. */
    tagCount: (count: number) => `${count.toLocaleString('en-US')} ${count === 1 ? 'tag' : 'tags'}`,
    addTag: 'Add Tag',
    removeTag: (name: string) => `Remove ${name}`,
    loading: 'Loading the tags…',
  },
  /**
   * Highlights: the colours, the selection bar's names for them, the question a tap asks, and the
   * Highlights section's rows, in the words of the app's review sheet. The section's count, the name of each row's group of colour buttons, Color, and the line for a
   * highlight the page could not draw are the web's own.
   */
  highlights: {
    colors: { yellow: 'Yellow', green: 'Green', blue: 'Blue', pink: 'Pink' },
    /** A colour's button in the selection bar, as VoiceOver reads the app's dot. */
    highlightColor: (color: string) => `Highlight ${color}`,
    removeTitle: 'Remove Highlight',
    removeMessage: 'This highlight will be permanently removed.',
    removeConfirm: 'Remove',
    removeCancel: 'Cancel',
    section: 'Highlights',
    /** The section's badge: how many highlights the document carries. */
    count: (count: number) => `${count.toLocaleString('en-US')} ${count === 1 ? 'highlight' : 'highlights'}`,
    color: 'Color',
    remove: 'Remove…',
    noPassage: 'Highlighted passage',
    stale: 'Made against an earlier version of the text — its position may have moved.',
    staleNoPassage:
      'Made against an earlier version of the text, and the words it covered were not stored — it can only be checked by eye.',
    notDrawn: 'This highlight could not be drawn in the text.',
    loading: 'Loading the highlights…',
  },
  /**
   * The selection bar's Note, which makes a note on the document, as the app's does, and the rail's
   * Notes section, in the app's words. The times since a note changed are the web's own, as near as
   * it comes to the app's relative time.
   */
  notes: {
    note: 'Note',
    title: 'Notes',
    emptyNote: 'Empty note',
    addToHighlight: 'Add Note to Highlight',
    add: 'Add Note',
    loading: 'Loading the notes…',
    /**
     * A document's note block from a research database the Mac exported with the owner's writing, which
     * joins its notes into one (S16e): the web's own words, as the app imports no research database.
     */
    fromResearchDatabase: 'From a research database',
    /** One unit of the time since a note changed. */
    unit: (count: number, unit: 'year' | 'month' | 'week' | 'day' | 'hour' | 'minute' | 'second') =>
      `${count.toLocaleString('en-US')} ${count === 1 ? unit : `${unit}s`}`,
    /** Its two largest units, "2 hours, 23 minutes", as the app's reads. */
    elapsed: (units: readonly string[]) => units.join(', '),
  },
  /**
   * The rail's Summary section: the Mac's summary block's label, its prompt's name and its history
   * control, and for a summary not the model's alone the headnote chips' words, the app's only words
   * for who wrote one. Writing, editing and deleting one's own are the web's own: the app writes no
   * summary of a document by hand.
   */
  summary: {
    title: 'Summary',
    label: 'AI summary',
    aiEdited: 'AI \u{00B7} edited',
    userWritten: 'Yours',
    prompt: (name: string) => `· ${name}`,
    /** A document's newest summary from a research database (S16e), in the prompt's place: the web's own words. */
    fromResearchDatabase: '· From a research database',
    olderHelp: 'Show older summary',
    older: 'Older summary',
    position: (index: number, count: number) => `${index}/${count}`,
    positionLabel: (index: number, count: number) => `Summary ${index} of ${count}`,
    newerHelp: 'Show newer summary',
    newer: 'Newer summary',
    write: 'Write a Summary',
    edit: 'Edit…',
    delete: 'Delete…',
    editTitle: 'Edit Summary',
    cancel: 'Cancel',
    save: 'Save',
    deleteTitle: 'Delete Summary?',
    deleteMessage: 'This summary will be permanently deleted.',
    deleteConfirm: 'Delete',
    deleteCancel: 'Cancel',
    loading: 'Loading the summaries…',
  },
  /**
   * The note editor, as the app's sheet words it. Its lines for a note being read, an editor being
   * loaded or one that could not be, and a note whose formatting it cannot show are the web's own.
   */
  noteEditor: {
    titleNew: 'New Research Note',
    titleEdit: 'Edit Note',
    delete: 'Delete',
    discard: 'Discard',
    save: 'Save',
    body: 'Note',
    bodyLabel: 'Research note body',
    formatting: 'Formatting',
    tags: 'Tags',
    tagsEmpty: 'No tags yet — add one below.',
    newTag: 'New tag name',
    addTag: 'Add',
    projects: 'Projects',
    projectsEmpty: 'No projects yet.',
    summaries: 'Generated Summaries',
    insert: 'Insert into note',
    remove: 'Remove from note',
    loading: 'Loading the note…',
    editorLoading: 'Loading the editor…',
    editorFailed: 'The formatting editor could not be loaded, so this note is open as plain text.',
    /** The same for a note with formatting, which a change to its text here drops. */
    editorFailedFormatted:
      'The formatting editor could not be loaded, so this note is open as plain text. Its formatting is kept until its text is changed here.',
    unreadable:
      'This note could not be shown with its formatting, so it is open as plain text. Its formatting is kept until its text is changed here.',
    /** The same for a plain note, which has no formatting to keep: a CR or U+2029 among its line breaks. */
    unreadablePlain: 'This note’s line breaks cannot be shown in the formatting editor, so it is open as plain text.',
    formattingKept: 'This note’s formatting cannot be shown here. It is kept until the note’s text is changed here.',
  },
  /**
   * The formatting bar and its link popover, in the app's words, with the iPhone's Cancel. The bar's
   * name, its glyphs and the line for a link the page could not follow are the web's own.
   */
  richText: {
    toolbar: 'Text formatting',
    bold: 'Bold',
    italic: 'Italic',
    underline: 'Underline',
    color: 'Text Color',
    link: 'Link selected text to a URL',
    glyphs: { bold: 'B', italic: 'I', underline: 'U', link: 'Link' },
    linkTitle: 'Link selection to URL',
    linkPlaceholder: 'https://…',
    linkRemove: 'Remove Link',
    linkApply: 'Apply',
    linkCancel: 'Cancel',
    linkRefused: 'A link here starts with http://, https:// or mailto:.',
  },
  /** The tag picker, as the app's document-mode sheet words it. */
  tagPicker: {
    title: 'Tags',
    titleDoc: (number: string) => `Tags — Doc ${number}`,
    titleId: (documentId: string) => `Tags — ${documentId}`,
    newTag: 'New Tag',
    newTagPlaceholder: 'Tag name…',
    newTagField: 'New tag name',
    add: 'Add',
    yourTags: 'Your Tags',
    empty: 'No user tags yet. Type a name above to create one.',
    badgeNew: 'New',
    created: (name: string) => `Tag ${name} created and selected`,
    cancel: 'Cancel',
    done: 'Done',
  },
  /** Settings ▸ Tags, its editor and its merge sheet, in the app's words. */
  settings: {
    title: 'Settings',
    panes: 'Settings',
    tags: 'Tags',
    tagsEmpty:
      'No tags yet. Tags are the labels you apply to research notes and documents as you read — create one here, or from any note.',
    tagsFooter: 'Tags are global labels you apply to research notes and documents. They are not scoped to a project.',
    newTag: 'New Tag…',
    newTagDefault: 'New Tag',
    edit: (name: string) => `Edit ${name}`,
    loading: 'Loading the tags…',
    userDataOff: 'This server keeps no tags or other research data of yours: it is read-only.',
  },
  tagEditor: {
    title: 'Edit Tag',
    nameHeader: 'Name',
    namePlaceholder: 'Tag name',
    nameField: 'Tag name',
    manage: 'Manage',
    merge: 'Merge into Another Tag…',
    delete: 'Delete Tag',
    manageFooterOnly:
      'Merging needs a second tag to merge into. Deleting removes this tag from every note and document that carries it; nothing else is deleted.',
    manageFooter:
      'Merging re-tags everything here with the tag you choose, then removes this one. Deleting removes this tag from every note and document that carries it; nothing else is deleted.',
    cancel: 'Cancel',
    save: 'Save',
    deleteTitle: 'Delete Tag?',
    deleteMessage: 'Deleting removes this tag from every note and document that carries it; nothing else is deleted.',
    deleteConfirm: 'Delete',
    deleteCancel: 'Cancel',
  },
  mergeTag: {
    title: 'Merge Tag',
    into: (name: string) => `Merge ‘${name}’ into:`,
    explanation: (name: string) => `All notes tagged ‘${name}’ will be re-tagged with the selected tag. ‘${name}’ will be deleted.`,
    cancel: 'Cancel',
    confirm: 'Merge',
  },
  /**
   * All Notes, as the app's Research destination words it, with the count its sheet gives. Each row's
   * Delete… is the web's own, since the app's is in a context menu.
   */
  allNotes: {
    title: 'All Notes',
    project: 'Project',
    allProjects: 'All projects',
    unfiled: 'Not in a project',
    tag: 'Tag',
    allTags: 'All tags',
    search: 'Search notes…',
    emptyNote: 'Empty note',
    noneTitle: 'No Notes',
    empty: 'No notes yet. Notes you write from a document appear here.',
    noneFiltered: 'No notes match the selected filters.',
    showing: (shown: number, total: string) => `Showing ${shown} of ${total}`,
    noteOne: (count: string) => `${count} note`,
    noteMany: (count: string) => `${count} notes`,
    delete: 'Delete…',
    deleteTitle: 'Delete Note?',
    deleteMessage: 'This note will be permanently deleted.',
    deleteConfirm: 'Delete',
    deleteCancel: 'Cancel',
    loading: 'Loading the notes…',
  },
  /** Settings ▸ Data, the web's own pane, with the app's Markdown export in its words. */
  dataSettings: {
    title: 'Data',
    // The export (PLAN's S16d), in the words of the app's export sheet.
    contents: 'Contents',
    tagsAndAssignments: 'Tags & Assignments',
    includeSummaries: 'Include AI-Generated Summaries',
    includeSummariesFooter: (count: number) =>
      `Adds all ${count.toLocaleString('en-US')} generated summaries to the JSON export. Off by default since AI output can be large.`,
    exportJSON: 'Export as JSON',
    jsonError: (detail: string) => `Couldn’t prepare the export: ${detail}`,
    jsonFooter:
      'One JSON file with your notes, tags, highlights, collections, custom prompts, projects, archive visit plans, saved searches, working corpora, volume scopes, corrections, reviewed changes, Suggested Next leads, and synced settings. It also holds your research trail: every document you opened, every search you ran and how many results it returned, and every collection you exported.',
    exportMarkdown: (count: number) => `Export Notes as Markdown (${count.toLocaleString('en-US')})`,
    preparing: 'Preparing export…',
    empty: 'No research notes to export.',
    footer:
      'One Markdown file per research note, with a citation and link back to the source document. Compatible with Obsidian and similar note-taking tools.',
    // The import (PLAN's S16c), the web's own words, since the app imports no JSON export, but for
    // the records' names, which are its export sheet's Contents, and the missing search's sentence.
    importTitle: 'Import a JSON Export',
    importLead:
      'Import the file FRUS Explorer writes on the Mac with Settings ▸ Data & Recovery ▸ Export as JSON; turn on Include AI-Generated Summaries there to bring your summaries. Each record keeps its id from the Mac, and a record you already have here is replaced only by a newer copy. Nothing here is deleted.',
    importFile: 'Export file',
    importAction: 'Import',
    importQueued: (name: string) => `${name} waits for the server’s other work…`,
    importRunning: (name: string) => `Importing ${name}…`,
    importDone: (name: string) => `Imported ${name}`,
    importFailed: (name: string) => `${name} could not be imported. Nothing of it was kept.`,
    importLost: (name: string) =>
      `The import of ${name} can no longer be followed, as after the server restarts, so whether it finished is not known here. Importing the file again changes nothing it brought.`,
    importWritten: (version: number, date: string) => `A version-${version} export, written on ${date}.`,
    reportCaption: 'What the export held, and what became of it',
    reportType: 'Records',
    reportInFile: 'In the file',
    reportAdded: 'Came in',
    reportReplaced: 'Replaced',
    reportKept: 'Kept',
    reportKeptNote: 'Replaced: you had an older copy here. Kept: you had a copy as new or newer.',
    notCarried: (version: number, names: string) => `A version-${version} export carries no ${names}.`,
    repeated: (count: number, name: string) =>
      `${count.toLocaleString('en-US')} of the ${name.toLowerCase()} came twice in the file: each is kept once, the newer copy.`,
    setAsideSettings: (count: number) =>
      count === 1
        ? 'The file held a second set of synced settings, from a device iCloud had not yet merged: the earliest set is kept, as the app keeps it.'
        : `The file held ${count.toLocaleString('en-US')} more sets of synced settings, from devices iCloud had not yet merged: the earliest set is kept, as the app keeps it.`,
    setAsideCorrections: (count: number) =>
      `${count.toLocaleString('en-US')} ${count === 1 ? 'correction was' : 'corrections were'} left out: a correction changes the index everyone here reads, and only a curator imports one.`,
    formattingKept: (count: number) =>
      count === 1
        ? 'One note keeps formatting this server cannot show: it opens as plain text until you edit it here.'
        : `${count.toLocaleString('en-US')} notes keep formatting this server cannot show: they open as plain text until you edit them here.`,
    headnoteDrafts: (count: number) =>
      count === 1
        ? 'One summary is a collection’s headnote draft, which no list of a document’s summaries shows.'
        : `${count.toLocaleString('en-US')} summaries are collections’ headnote drafts, which no list of a document’s summaries shows.`,
    withoutAuthorship: (count: number) =>
      `${count.toLocaleString('en-US')} ${count === 1 ? 'summary says' : 'summaries say'} nothing of who wrote ${count === 1 ? 'it' : 'them'}, as exports before version 5 do, and ${count === 1 ? 'is' : 'are'} shown as AI summaries.`,
    inertEntries: (count: number) =>
      count === 1
        ? 'One collection entry has no document. A version-6 export does not say what it was, a section heading, a note block or an apparatus block, so it is kept as an entry this server does not show.'
        : `${count.toLocaleString('en-US')} collection entries have no document. A version-6 export does not say what they were, section headings, note blocks or apparatus blocks, so they are kept as entries this server does not show.`,
    unlinkedLead: 'These smart collections keep their link to a saved search this export does not carry:',
    missingSearch: 'The linked saved search could not be found. It may have been deleted.',
    /** What the app's lists call a collection with no name (`CollectionEditorNaming.listName`). */
    untitledCollection: 'Untitled Collection',
    types: {
      ResearchNote: 'Research Notes',
      UserTag: 'Tags',
      DocumentTagAssignment: 'Tag Assignments',
      DocumentHighlight: 'Highlights',
      Collection: 'Collections',
      CollectionEntry: 'Collection Entries',
      SummarizationPrompt: 'Custom Prompts',
      Project: 'Projects',
      ArchiveVisitPlan: 'Archives Visits',
      ArchiveVisitDocument: 'Archives Visit Documents',
      ArchiveVisitTarget: 'Archives Visit Targets',
      SavedSearch: 'Saved Searches',
      WorkingCorpus: 'Working Corpora',
      CustomVolumeScope: 'Volume Scopes',
      DocumentClassificationOverride: 'Classification Corrections',
      PersonClusterOverride: 'Person Corrections',
      AnnotationReview: 'Reviewed Changes',
      ProjectLeadEntry: 'Suggested Next Leads',
      SyncedPreferences: 'Synced Settings',
      ReadingHistoryEntry: 'Documents Visited',
      SearchHistoryEntry: 'Searches Executed',
      ExportHistoryEntry: 'Collections Exported',
      GeneratedSummary: 'Generated Summaries',
    },
  },
  /**
   * Citation Lookup, in the words of the app's window and of Search's Find by Citation, with the kit's
   * names for the modes. Each result's label, a Batch row's own label and the table's summary are the
   * kit's, from the server. View Volume, which stands where the app offers Download Volume, and its
   * tooltip are the web's own.
   */
  lookup: {
    title: 'Citation Lookup',
    findByCitation: 'Find by Citation',
    findByCitationHelp: 'Resolve a pasted or manually entered FRUS citation to a specific document',
    mode: 'Input mode',
    modes: { paste: 'Paste Citation', structured: 'Structured Entry', batch: 'Batch' },
    pasteHeader: 'Citation Text',
    pastePlaceholder: 'Paste a FRUS citation…',
    batchHeader: 'Footnotes',
    batchFooter:
      'Paste a chapter’s footnotes. Numbered notes are split on their numbers, and a note wrapped across lines is rejoined; an unnumbered list is one citation per line.',
    fieldsHeader: 'Parsed Fields',
    fieldsFooter: 'Provide at least a document number, page number, or volume to search.',
    subseries: 'Subseries',
    subseriesPlaceholder: 'e.g. 1969-76',
    volume: 'Volume',
    volumePlaceholder: 'e.g. I or 1',
    part: 'Part',
    partPlaceholder: 'e.g. 1 or I',
    document: 'Document no.',
    documentPlaceholder: 'e.g. 15',
    page: 'Page',
    pagePlaceholder: 'e.g. 47',
    lookUp: 'Look Up',
    lookUpHelp: 'Resolve the citation to matching FRUS documents',
    searching: 'Looking up…',
    errorTitle: 'Lookup Error',
    noMatchTitle: 'No Matches Found',
    noMatchDetail: 'No FRUS documents matched the provided citation. Check the subseries and volume, then try again.',
    results: (count: number) => `Results (${count} found)`,
    /** What a lookup that found matches announces, as the app's announcement words it. */
    matchesFound: (count: number) => `${count} matches found`,
    viewDocument: 'View Document',
    viewDocumentHelp: 'Open this document',
    viewVolume: 'View Volume',
    viewVolumeHelp: 'Open this volume’s page in Browse, which says what this server holds of it',
    batchEmptyTitle: 'Nothing to Triage',
    batchEmptyDetail: 'No citations were found in that text.',
    needsWorkFirst: 'Needs work first',
    resolved: (identity: string) => `Resolved — ${identity}`,
    possibleDocuments: (count: number) => `${count} possible documents`,
    noMatch: 'No match',
  },
} as const;
