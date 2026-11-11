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
// collection whose saved search is gone; and from S19b the Research page's rows and sections, its lists'
// titles and empty states, and its rows' lines. The selection bar's name, Selection, the
// formatting bar's, Text formatting, its glyphs, Write a Summary, Edit… and Delete… for a summary
// of one's own and the question before it, the visible Delete… on All Notes' rows, the rail's times,
// Settings ▸ Data's title and the lines for an editor that could not load or a note, formatted or
// plain, it could not show are the web's own, and so is the import's every other word, S16e's
// mark of a note block or a summary from a research database, since the app imports none, and from
// S14e the header's line naming the user and the footer's saying what the operator can read. The rest,
// chiefly what only a server has (what it indexes, which TEI it holds), are the web's own until
// check 10 settles them.

// One block a screen, grouped by area under a line each (PLAN's S20a): a new screen's block goes beside its
// area's kin, never at the end.
export const copy = {
  // ─── The shell ────────────────────────────────────────────────────────────
  app: {
    name: 'FRUS Explorer Light',
    skipToContent: 'Skip to content',
    navigation: 'Main',
    browse: 'Browse',
    search: 'Search',
    /** The Research tab's name, the app's: the Research page since S19b. */
    research: 'Research',
    /** From S18d, between Research and Settings, as the app's tabs order them. */
    collections: 'Collections',
    settings: 'Settings',
    /** The browser tab's title for a screen. */
    title: (screen: string) => `${screen} – FRUS Explorer Light`,
    /** The footer's name, beside the header's, the app's name (S18e). */
    footerLabel: 'About this instance',
    footer:
      'FRUS Explorer Light is a self-hosted edition of FRUS Explorer, with documents published by the Office of the Historian. This instance is not an Office of the Historian service.',
    /** Behind a proxy that signs people in (PLAN's S14e): who the proxy named. */
    signedInAs: (name: string) => `Signed in as ${name}`,
    /** And what SPEC's Privacy asks the app to say once someone has signed in, or is asked to (S20b). */
    operatorReads:
      'Whoever runs this instance can read everything it keeps for you, your tags, highlights, notes and summaries included.',
    /** With an account of the server's own (PLAN's S20b): ends the session, and shows the sign-in page. */
    signOut: 'Sign Out',
    signOutFailed: 'You are still signed in: the server could not be reached. Try Sign Out again.',
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
  /**
   * The sign-in page of a server with accounts of its own (PLAN's S20b), shown in place of any page until
   * someone signs in: the web's own, since the app signs in to iCloud and to no server.
   */
  signIn: {
    title: 'Sign In',
    intro: 'This instance keeps each person’s research under an account of their own. Sign in with the name and password its admin gave you.',
    name: 'Name',
    password: 'Password',
    submit: 'Sign In',
    signingIn: 'Signing In…',
    help: 'An admin makes each account, and sets a new password for one whose password is forgotten.',
  },
  /**
   * The project picker and the "Working on:" line (PLAN's S17f), in the app's words. The picker's
   * visible label, Project, is the History scope picker's; the app's menu has none.
   */
  projectPicker: {
    label: 'Project',
    global: 'Global Context',
    globalShort: 'Global',
    manage: 'Manage Projects',
    a11y: 'Switch project context',
    workingOn: 'Working on:',
    home: 'Project Home',
  },

  // ─── Browse and search ────────────────────────────────────────────────────
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
    // S17f: the strip's line while the history records nothing, which is what hides an opened result.
    loggingOff: 'Opening a result does not hide it while Log Research Sessions is off in Settings. Mark Reviewed still hides a result.',
  },
  /** Browse's axes, as the Mac's sidebar names the four the web has; the group's name is the web's own. */
  axes: {
    label: 'Browse by',
    volumes: 'All Volumes',
    annotations: 'Editors’ Annotations',
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
  /**
   * The editors' annotations (FRUS-Explorer#1859 to #1862, and their follow-ups #1868, #1873 and #1874), in
   * the app's words: a volume page's Editors’ Annotations (`VolumeAnnotationsPresentation`,
   * `VolumeAnnotationsSection`), and Browse's axis of that name with a layer's page and its lists
   * (`AnnotationLayer`, `AnnotationsAxis`, `AnnotationsAxisViews`).
   * A count's two forms are the app's one and many, which browse/annotationRules.ts chooses as the app's
   * `CountCopy` does; a `%1$@`/`%2$@` form takes its arguments in the app's order. The web's own: five
   * of the "In the app" sentences (`appUse`), where the app's name a screen this server does not have
   * yet, and the line for a server that cannot read the bundled file, where the app's says to reinstall it.
   */
  annotations: {
    title: 'Editors’ Annotations',
    families: { named: 'Who is named', provenance: 'Where it came from', connects: 'How it connects' },
    layers: {
      people: 'People tagged',
      abbreviations: 'Abbreviations explained',
      correspondents: 'Senders and recipients',
      subjects: 'Subject lines',
      participants: 'Meeting participants',
      sourceNotes: 'Source notes',
      classification: 'Classification markings',
      excisions: 'Redactions marked as not declassified',
      editorialOmissions: 'Marked editorial omissions',
      despatch: 'Despatch numbers',
      numbered: 'Numbered documents',
      crossReferences: 'Cross-references',
      editorialNotes: 'Editorial notes',
      footnotes: 'Footnotes',
      marginalNotes: 'Marginal notes',
      printedAids: 'Front and back matter',
    },
    /** The two standard layers narrower than a layer, which a volume's page lists as absent. */
    referencesToDocuments: 'References to documents',
    noteOnSources: 'Note on Sources',
    /** The front and back matter's sections by the kind that names each, "intro" for both kinds the app calls Introduction. */
    aids: {
      preface: 'Preface',
      foreword: 'Foreword',
      intro: 'Introduction',
      sources: 'Sources',
      terms: 'Abbreviations',
      persons: 'Persons',
      'list-of-papers': 'List of Papers',
      'note-on-covert-actions': 'Note on U.S. Covert Actions',
      'press-release': 'Press Release',
      'volume-summary': 'Volume Summary',
      index: 'Index',
      errata: 'Errata',
    } as Record<string, string>,
    // A row's line, its parts joined by the app's separator.
    separator: ' · ',
    ofDocumentsOne: (total: string, count: string) => `${count} of ${total} document`,
    ofDocumentsMany: (total: string, count: string) => `${count} of ${total} documents`,
    personsListedOne: (count: string) => `${count} person listed`,
    personsListedMany: (count: string) => `${count} people listed`,
    termsListedOne: (count: string) => `${count} term listed`,
    termsListedMany: (count: string) => `${count} terms listed`,
    /** The kit's `CountCopy.documents`. */
    documentsOne: (count: string) => `${count} document`,
    documentsMany: (count: string) => `${count} documents`,
    sourceForms: {
      citations: 'archival citations (“Source: …”)',
      fileNumbers: 'file numbers above the heading',
      both: 'archival citations and file numbers',
    },
    excisionsOne: (count: string) => `${count} document with a redaction marked`,
    excisionsMany: (count: string) => `${count} documents with redactions marked`,
    editorialOmissionsOne: (count: string) => `${count} document with an editorial omission marked`,
    editorialOmissionsMany: (count: string) => `${count} documents with editorial omissions marked`,
    editorialNotesOne: (count: string) => `${count} editorial note`,
    editorialNotesMany: (count: string) => `${count} editorial notes`,
    xrefDocumentsOne: (count: string) => `${count} document cites another in this volume`,
    xrefDocumentsMany: (count: string) => `${count} documents cite others in this volume`,
    xrefVolumesOne: (count: string) => `${count} document cites other volumes`,
    xrefVolumesMany: (count: string) => `${count} documents cite other volumes`,
    xrefPagesOne: (count: string) => `${count} document cites printed pages`,
    xrefPagesMany: (count: string) => `${count} documents cite printed pages`,
    rowSpoken: (label: string, detail: string) => `${label}: ${detail}.`,
    rowHint: 'Opens what the editors did, and the volumes that carry it.',
    absentTitle: (count: string) => `Not in this volume (${count})`,
    absentSpoken: (label: string) => `Not in this volume: ${label}.`,
    standardFrom: (year: string) => `Standard in the volumes covering ${year} on.`,
    peopleHint: 'Search the names instead.',
    // The axis.
    ofVolumesOne: (total: string, count: string) => `${count} of ${total} volume`,
    ofVolumesMany: (total: string, count: string) => `${count} of ${total} volumes`,
    /** The kit's `CountCopy.volumes`. */
    volumesOne: (count: string) => `${count} volume`,
    volumesMany: (count: string) => `${count} volumes`,
    eraRetrospective: 'the late retrospectives',
    eraSpan: (first: string, last: string) => `${first}–${last}`,
    eraFrom: (first: string) => `${first} on`,
    eraRetrospectiveShort: 'Retro.',
    eraRetrospectiveTitle: 'Late retrospectives',
    standardNoneRetrospective: 'No era made it standard. It is most common in the late retrospective volumes.',
    standardNone: (era: string) => `No era made it standard. It is most common in the volumes covering ${era}.`,
    /** Redactions' sentence in place of an era's: the practice follows the year a volume was published, not the years it covers. */
    standardRedactions:
      'Volumes produced after the passage of the 1991 statute include explicit editorial annotation of redactions made during the declassification process.',
    layerSpoken: (label: string, volumes: string) => `${label}: ${volumes}.`,
    bandSpoken: (era: string, volumes: string) => `${era}: ${volumes}`,
    cellSpoken: (label: string, band: string) => `${label}, ${band}`,
    indexCaption: (volumes: string) =>
      `What the editors of ${volumes} annotated, layer by layer. A layer that runs through a volume, such as people tagged, counts when it reaches at least half the volume's documents; one found here and there, such as an editorial note, when one document carries it. Each strip shades the eras, earliest first and the late retrospectives last, by the share of their volumes that carry the layer.`,
    rowHelp: 'What the editors did, when it became standard, and the volumes that carry it',
    // A layer's page.
    practiceHeader: 'What the editors did',
    erasHeader: 'Era by era',
    appHeader: 'In the app',
    volumesHeader: 'Volumes',
    rules: {
      people: 'A volume counts when at least half its documents link a name to its List of Persons.',
      abbreviations: 'A volume counts when at least half its documents link a term to its List of Abbreviations.',
      correspondents: 'A volume counts when at least half its documents mark a sender or a recipient in the heading.',
      subjects: 'A volume counts when one of its documents prints a Subject line.',
      participants: 'A volume counts when one of its documents lists who attended a meeting.',
      sourceNotes: 'A volume counts when at least half its documents carry a source note, of either form.',
      classification: 'A volume counts when at least half its documents carry a classification marking, as the app reads them.',
      excisions: 'A volume counts when one of its documents marks a redaction as not declassified: text in it, or the whole document.',
      editorialOmissions:
        'A volume published from 1925 counts when one of its documents says, in brackets, what the editors left out: “[Here follows …]” or “[Omitted here is …]”.',
      despatch: 'A volume counts when at least a tenth of its documents carry a despatch number.',
      numbered: 'A volume counts when at least half its documents print a document number.',
      crossReferences: 'A volume counts when one of its documents cites another of its documents, another volume or a printed page.',
      editorialNotes: 'A volume counts when it prints an editorial note.',
      footnotes: 'A volume counts when at least half its documents carry a footnote.',
      marginalNotes: 'A volume counts when one of its documents prints a marginal note.',
      printedAids: 'A volume counts when it prints one of the sections listed below.',
      sourceForm: 'A volume counts when at least half its documents carry a source note of this form.',
      aid: 'A volume counts when it prints this section.',
    },
    practices: {
      people: "The editors linked each person a document names to the volume's List of Persons, where the person is identified.",
      abbreviations: "The editors linked each abbreviation in a document to the volume's List of Abbreviations, where it is spelled out.",
      correspondents: 'The editors marked who sent each document, and to whom, in its heading.',
      subjects: 'Where a memorandum carried a Subject line, the editors printed it with the memorandum.',
      participants: 'Where a memorandum of conversation lists who took part, the editors marked the list.',
      sourceNotes:
        "A source note says where the editors found a document. It was printed first as a file number above the heading, and later as a note that begins “Source:” with the full archival citation. The earliest volumes print none: a despatch there carries the post's own number instead.",
      classification:
        "The editors printed each document's security classification, first above the dateline and later in the source note.",
      excisions:
        'The editors mark what declassification review redacted: a gap in the printed text, “[… not declassified]”, or a whole document withheld, listed in its place with its heading, its source note and the number of pages not declassified. From Secretary Kellogg’s 1925 order until the 1991 statute, volumes marked an omission with an ellipsis, whether the editors left the text out or it was not cleared for publication, so their redactions cannot be told from the editors’ omissions and are not counted here. Volumes published before the 1925 order marked an omission with a row of asterisks, under no written rule and without saying whose cut it was; those are not counted here either.',
      editorialOmissions:
        'Since Secretary Kellogg’s 1925 order, where the editors left out part of a document as not relevant to the volume, they could say so in brackets and describe what was omitted. Until the 1991 statute an ellipsis could also mark an omission, the editors’ or a redaction, and those are not counted here. Volumes published before the order marked an omission with a row of asterisks, not a bracketed note, and are not counted here.',
      despatch:
        'Older volumes print the number a diplomatic post gave each despatch it sent, “No. 74.”, by which the despatch is found in the archives.',
      numbered: 'The editors numbered the documents in print, so that each heading opens with its number: “12. Telegram From …”.',
      crossReferences:
        "The editors' notes point to other documents in the volume, to other volumes and to printed pages: “See Document 12”, “see p. 123”.",
      editorialNotes: 'Where no single document tells the story, the editors wrote a note of their own, set between the documents.',
      footnotes: "The editors' footnotes explain a document: who it names, what it answered, what became of it.",
      marginalNotes: "A few volumes print the notes written in a document's margin, set off from its text.",
      printedAids:
        'Besides its documents, a volume prints front and back matter to help readers use it: a preface, lists of sources, abbreviations and persons, an index.',
    },
    /**
     * What the app does with each layer, as the app's `appUse` says it where every screen it names is
     * this server's too; for people, source notes, classification, cross-references and the front and
     * back matter the sentence is the web's own, naming only what the web edition has, and despatch
     * numbers take the app's line for a layer nothing else reads.
     */
    appUse: {
      people: 'The reader opens a linked person’s entry. Where a volume does not link its names, search for them instead.',
      abbreviations: "The reader opens a linked abbreviation's meaning.",
      sourceNotes: 'The reader shows each document’s source note.',
      classification: 'The reader shows a document’s marking as the volume prints it.',
      numbered: 'Document titles and citations give the number the volume prints.',
      crossReferences: 'The reader follows each one.',
      editorialNotes: 'Search can limit its results to editorial notes.',
      footnotes: 'The reader shows each footnote with its document.',
      printedAids: 'A volume’s page lists them under Front Matter and Back Matter, and the reader opens most of them; its index and its lists of sources and persons do not open here yet.',
      none: 'The reader shows these as printed. Nothing else in the app reads them yet.',
    },
    // A layer's lists.
    drillWith: 'Volumes with it',
    drillWithout: 'Volumes without it',
    drillWithTitle: (label: string) => `With: ${label}`,
    drillWithoutTitle: (label: string) => `Without: ${label}`,
    drillCitation: 'Archival citations (“Source: …”)',
    drillFileNumber: 'File numbers above the heading',
    eraDrillTitle: (label: string, era: string) => `${label}, ${era}`,
    drillCaption: (count: string, rule: string) => `${count}. ${rule}`,
    drillSpoken: (title: string, volumes: string) => `${title}: ${volumes}`,
    notesOne: (count: string) => `${count} note`,
    notesMany: (count: string) => `${count} notes`,
    /** The kit's `CountCopy.docs`. */
    docsOne: (count: string) => `${count} doc`,
    docsMany: (count: string) => `${count} docs`,
    noteFrom: 'You came here from this volume.',
    notePersonsUnlinked: 'Prints a List of Persons, but none of its documents links a name to it.',
    noteTermsUnlinked: 'Prints a List of Abbreviations, but none of its documents links a term to it.',
    noteBefore1925: 'Published before the 1925 order, when the editors marked an omission with a row of asterisks, not a bracketed note.',
    unavailableTitle: 'Editors’ Annotations Unavailable',
    unavailableDetail: 'The bundled annotation data could not be loaded.',
  },

  // ─── The reader ───────────────────────────────────────────────────────────
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

  // ─── Research ─────────────────────────────────────────────────────────────
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
  /**
   * Project Home, in the words of the app's view, and of its focus subjects' editor (S25c). What
   * Suggested Next says of the Mac's leads, which the web keeps but cannot compute until Related
   * Documents, is the web's own, and so are the editor's line while its subjects load and what it
   * says, for a screen reader, of a subject added or removed.
   */
  projectHome: {
    title: 'Project Home',
    missingTitle: 'No Project Selected',
    missingDetail: 'Choose a project from the project picker to see its workspace.',
    questionPlaceholder: 'What is this project’s research question?',
    dateFrom: (year: number) => `From ${year}`,
    dateTo: (year: number) => `Through ${year}`,
    statCollections: 'Collections',
    statNotes: 'Notes',
    statVisited: 'Documents Visited',
    statSearches: 'Searches Run',
    focusSubjects: 'Focus subjects',
    focusSubjectsAdd: 'Add',
    focusSubjectsEdit: 'Edit',
    focusSubjectsEmpty: 'Choose subjects to focus discovery on the volumes they define.',
    focusSubjectsTitle: 'Focus Subjects',
    focusSubjectsDone: 'Done',
    focusSubjectsUnavailableTitle: 'Subjects Unavailable',
    focusSubjectsUnavailable: 'The subject index could not be loaded.',
    focusSubjectsLoading: 'Loading subjects…',
    focusSubjectsSearch: 'Search subjects',
    focusSubjectsSelected: 'Focus subjects',
    focusSubjectsSuggested: 'Suggested from your volumes',
    focusSubjectsSuggestedDetail:
      'Subjects that recur across the volumes you’ve already collected, annotated, or opened in this project.',
    focusSubjectsAll: 'All subjects',
    focusSubjectsNoMatches: 'No subjects match.',
    volumeCountOne: '1 volume',
    volumeCountOther: (count: number) => `${count.toLocaleString('en-US')} volumes`,
    focusSubjectAdded: (name: string) => `${name} added to Focus subjects`,
    focusSubjectRemoved: (name: string) => `${name} removed from Focus subjects`,
    focusTags: 'Focus tags',
    focusAdd: 'Add',
    focusEdit: 'Edit',
    focusEmpty: 'Choose tags whose documents should anchor this project’s suggestions.',
    focusTagsTitle: 'Focus Tags',
    focusTagsNoneTitle: 'No Tags',
    focusTagsNone: 'Tag documents while you research, then choose which tags focus this project’s suggestions here.',
    focusTagsFooter: 'Documents you’ve tagged with the chosen tags anchor this project’s Suggested Next.',
    focusTagsDone: 'Done',
    leadsTitle: 'Suggested Next',
    leadsPlaceholder:
      'As you add documents to this project’s collections, related documents you haven’t gathered yet will surface here.',
    leadsFromMac:
      'These are the leads FRUS Explorer found on the Mac. This server does not yet find leads of its own, so they change only when you dismiss one or import a newer export.',
    leadNew: 'NEW',
    relatedOne: 'Related to 1 of your documents',
    relatedMany: (count: number) => `Related to ${count.toLocaleString('en-US')} of your documents`,
    editorialNote: 'Editorial note',
    dismiss: 'Dismiss this lead',
    dismissNamed: (title: string) => `Dismiss this lead: ${title}`,
    recentTitle: 'Recent Activity',
    recentEmpty:
      'No activity in this project yet. Read documents, take notes, or build a collection while this project is active and it will appear here.',
    recentDocuments: 'Recently Read',
    recentNotes: 'Recent Notes',
    recentSearches: 'Recent Searches',
    untitledSearch: '(no query text)',
    results: (count: number) => `${count.toLocaleString('en-US')} results`,
    actionCollections: 'Collections',
    actionResearch: 'Research',
    actionSearch: 'Search',
    loading: 'Loading Project Home…',
  },
  /** The History screen, in the app's words. */
  history: {
    title: 'History',
    scopeLabel: 'Project',
    scopeAll: 'All Projects',
    scopeUnfiled: 'Not in a Project',
    scopeA11y: 'Filter history by project',
    scopeHelp: 'Show only history recorded while a specific project was active',
    search: 'Search history…',
    searchA11y: 'Search history',
    filteredTitle: 'No Matches',
    filteredDetail: 'No history matches the current filters.',
    documents: 'Documents Visited',
    documentsEmptyTitle: 'No Documents Visited',
    documentsEmpty: 'Documents you open will appear here.',
    searches: 'Searches Executed',
    searchesEmptyTitle: 'No Searches Executed',
    searchesEmpty: 'Searches you run will appear here.',
    exports: 'Collections Exported',
    exportsEmptyTitle: 'No Collections Exported',
    exportsEmpty: 'Collections you export will appear here.',
    showing: (shown: number, total: number) => `Showing ${shown} of ${total}`,
    loggingOff:
      'Research logging is off, so new activity is not being recorded. Turn it back on in Settings under Research Sessions.',
    showMore: 'Show More',
    delete: 'Delete',
    deleteNamed: (title: string) => `Delete ${title}`,
    resultCount: (count: number) => `${count.toLocaleString('en-US')} results`,
    documentCount: (count: number) => `${count.toLocaleString('en-US')} documents`,
    loading: 'Loading the history…',
  },
  /**
   * The Research page (PLAN's S19b), in the words of the app's `ResearchView`: its sidebar's rows and
   * sections, a list's title and what it says of no documents, and a row's lines, its counts printed
   * as the app's `String(format:)` prints them, the sidebar's as SwiftUI's `Text` groups them. The
   * categories' name, the narrow window's way back to them, the loading line, a highlight's colour and
   * a row's tags and collections named for a screen reader, and what Changed by an update says on a
   * server that does not review changed text are the web's own.
   */
  researchPage: {
    title: 'Research',
    categories: 'Categories',
    allAnnotated: 'All Research Documents',
    hasNotes: 'Contains Notes',
    notes: 'All Notes',
    updated: 'Changed by an update',
    updatedWaits:
      'Documents an update changed after you annotated them wait for a review of their new text, which this server does not offer yet, so none is listed here.',
    history: 'History',
    historyDetail: 'Documents opened and searches run',
    collections: 'By Collection',
    tags: 'By Tag',
    highlights: 'By Highlight',
    count: (count: number) => count.toLocaleString('en-US'),
    highlightList: (color: string) => `${color} Highlights`,
    unknownTag: 'Tag',
    noDocs: 'No Documents',
    emptyAllAnnotated: 'Research notes, tags, highlights, and collections you add from the document view will appear here.',
    emptyHasNotes:
      'Notes you write on a document will appear here. A document you have only tagged, highlighted, or collected appears under All Research Documents instead.',
    emptyTag: 'No documents have notes or tags matching this tag.',
    emptyCollection: 'This collection has no documents.',
    emptyHighlight: 'No documents have highlights in this color.',
    summaries: (count: number) => `${count} summaries`,
    inVisitPlan: 'In a visit plan',
    moreHighlights: (count: number) => `and ${count} more`,
    noteCount: (count: number) => `${count} notes`,
    noText: 'Highlighted passage',
    highlightColor: (color: string) => `${color} highlight: `,
    tagLabel: 'Tag: ',
    collectionLabel: 'Collection: ',
    loading: 'Loading your research…',
  },

  // ─── Collections ──────────────────────────────────────────────────────────
  /**
   * Collections (PLAN's S18d), in the app's words: the Collections tab's list, its project scope and its
   * rows, with their Rename Collection alert and the question before a delete (`CollectionDeletion`,
   * FRUS-Explorer#1831); the Mac's New Collection sheet; the Add to Collection picker; and the Research
   * rail's Collections section. A row's Delete…, which asks the app's question, is the web's own button for
   * its menu's Delete, as All Notes' rows have one.
   */
  collections: {
    title: 'Collections',
    new: 'New Collection',
    newLabel: 'Create new collection',
    emptyTitle: 'No Collections',
    emptyDetail: 'Create a collection to group documents for export.',
    emptyAction: 'New Collection',
    /** A row's count: its documents, not its entries. */
    documentCount: (count: number) => `${count} document${count === 1 ? '' : 's'}`,
    smartLabel: 'Smart collection',
    rename: 'Rename',
    /** The Rename Collection alert, whose Save keeps the old name for a name left empty. */
    renameTitle: 'Rename Collection',
    renamePlaceholder: 'Collection Name',
    renameCancel: 'Cancel',
    renameSave: 'Save',
    duplicate: 'Duplicate',
    showingAll: (project: string) => `Showing collections from every project, including ones outside “${project}”.`,
    scopeToProject: (project: string) => `Scope to “${project}”`,
    filteredWithHidden: (project: string, hidden: number) =>
      `Showing collections for “${project}” — ${hidden} other collection${hidden === 1 ? '' : 's'} hidden.`,
    filteredNoHidden: (project: string) => `Showing collections for “${project}”.`,
    showAll: 'Show All',
    untitledProject: 'Untitled Project',
    delete: 'Delete…',
    /** `CollectionDeletion`'s question for one collection, which it names as its row does. */
    deleteTitle: (name: string) => `Delete “${name}”?`,
    deleteMessage:
      'Its section headings, note blocks and headnotes go with it, on your other devices too once they sync. The documents in it, and your notes and highlights on them, stay.',
    deleteConfirm: 'Delete',
    deleteCancel: 'Cancel',
    loading: 'Loading the collections…',
    /** The Mac's New Collection sheet. */
    newTitle: 'New Collection',
    newName: 'Name',
    newNamePlaceholder: 'Collection Name',
    newCancel: 'Cancel',
    newCreate: 'Create',
    /** The Add to Collection picker. */
    pickerTitle: 'Add to Collection',
    pickerTitleExcerpt: 'Add Excerpt to Collection',
    pickerNew: 'New Collection',
    pickerNewHelp: 'Create a new collection',
    pickerSearch: 'Search collections…',
    pickerEmpty: 'No Collections',
    pickerEmptyHint: 'Use the button above to create one.',
    pickerNoResults: (text: string) => `No collections match “${text}”.`,
    pickerCancel: 'Cancel',
    pickerAdded: 'Added',
    smartSentence: 'Smart collection. Its documents come from its saved search.',
    addFailedTitle: 'Not Added',
    /** The rail's Collections section. */
    railTitle: 'Collections',
    railEmpty: 'Not in any collection yet.',
    railAdd: 'Add to Collection',
    /** The section's badge, the web's own: how many collections hold the document. */
    railCount: (count: number) => `${count.toLocaleString('en-US')} ${count === 1 ? 'collection' : 'collections'}`,
    railLoading: 'Loading the collections…',
    /** The selection bar's Excerpt. */
    excerpt: 'Excerpt',
    /** Import Collection… and Create Static Snapshot (S18f), with their alerts' titles. */
    importCollection: 'Import Collection…',
    importFailedTitle: 'Couldn’t Import Collection',
    snapshot: 'Create Static Snapshot',
    snapshotFailedTitle: 'Couldn’t Create Snapshot',
    alertOK: 'OK',
    /** What a row's buttons say while their file or snapshot is made, the web's own. */
    importing: 'Importing the collection…',
    snapshotting: 'Running the saved search…',
  },
  /**
   * The collection editor, in the words of the app's iPad editor: its Contents and Add menu, Sort by
   * Date, each row's words and actions, the chips a document row shows, and the apparatus blocks'
   * names.
   */
  collectionEditor: {
    untitled: 'Untitled Collection',
    contents: 'Contents',
    empty: 'No content yet. Add documents, headings, notes, and apparatus from the toolbar above.',
    add: 'Add',
    addLabel: 'Add documents, a section heading, a note block, highlighted passages, or an apparatus block',
    addDocuments: 'Add Documents…',
    addHeading: 'Add Section Heading',
    addProse: 'Add Note Block',
    addHighlights: 'Add Highlighted Passages…',
    apparatus: 'Apparatus',
    addDocumentsFooter:
      'Search the index, browse volumes, paste citations or history.state.gov links, or gather a tag. New documents are added to the end of the list.',
    sortByDate: 'Sort by Date',
    sortWhole: 'Across the Whole Collection',
    sortWholeHelp: 'Order every document into one chronology — a document may move past a section heading',
    sortSections: 'Within Each Section',
    sortSectionsHelp: 'Order documents chronologically within each section — documents stay under their heading',
    settings: 'Collection settings',
    done: 'Done',
    loading: 'Loading the collection…',
    unavailableTitle: 'Collection Unavailable',
    unavailableDetail: 'This collection was deleted, or is not yours.',
    /** A section heading's row. */
    expandSection: 'Expand section',
    collapseSection: 'Collapse section',
    headingPlaceholder: 'Section heading',
    hidden: (count: number) => `${count} hidden`,
    sectionDefaults: 'Section defaults',
    sectionDefaultsHelp: 'Set export defaults for every document in this section',
    sectionBodyDefault: 'Default',
    sectionBody: 'Section body',
    deleteSectionTitle: 'Delete Section?',
    deleteSectionAction: 'Delete Section',
    deleteSectionMessage: (count: number) => `Deletes this heading and the ${count} entries it contains.`,
    deleteSectionCancel: 'Cancel',
    rename: 'Rename',
    sectionDefaultsMenu: 'Section Defaults…',
    indent: 'Indent',
    outdent: 'Outdent',
    deleteHeadingOnly: 'Delete Heading Only',
    deleteSection: 'Delete Section',
    /** The menu of a row's actions, the web's own name for the app's context menu. */
    actions: 'Actions',
    /** Each row. */
    remove: 'Remove entry',
    removeHelp: 'Remove this document from the collection',
    configure: 'Configure',
    configureHint: 'Opens this document’s settings',
    moveUp: 'Move Up',
    moveDown: 'Move Down',
    openDocument: 'Open Document',
    duplicate: 'Also in collection',
    documentLabel: (header: string) => `Document ${header}`,
    excerptLabel: (documentId: string, text: string) => `Excerpt from ${documentId}: ${text}`,
    generatedUnsupported: 'Unsupported block',
    generatedUnsupportedDetail: 'Update FRUS Explorer to resolve this block.',
    generatedCaption: 'Generated from this collection’s documents at export and in the preview.',
    generatedCount: (count: number) => `Lists ${count} document${count === 1 ? '' : 's'}.`,
    generatedLabel: (title: string) => `Generated block: ${title}`,
    unrecognizedTitle: 'Unsupported entry',
    unrecognizedDetail: 'Update FRUS Explorer to view this entry.',
    /** A note block's editor, the web's own words for opening and leaving it. */
    proseLabel: 'Note block',
    proseEdit: 'Edit',
    proseDone: 'Done',
    proseEmpty: 'Empty note block',
    proseLoading: 'Loading the editor…',
    proseFailed: 'The formatting editor could not be loaded. Reload the page to edit this note block.',
    proseKept: 'This note block keeps formatting the web cannot show. Editing it here keeps its text and drops that formatting.',
    /** A note block the formatting editor cannot show as its text reads, the web's own, as the note editor says of a note. */
    proseUnreadable:
      'This note block could not be shown with its formatting, so it is open as plain text. Its formatting is kept until its text is changed here.',
    /** The five apparatus blocks (`CollectionGeneratedBlockType.displayName`). */
    blocks: {
      bibliography: 'Bibliography',
      chronology: 'Chronology',
      archivalSources: 'Sources & Archives',
      personsIndex: 'Persons Index',
      thematicIndex: 'Thematic Index',
    } as Record<string, string>,
    /** A document row's chips (`entryStatusChips`), a body depth by its chip label. */
    chips: {
      bodyDepth: { full: 'Full', summaryOnly: 'Summary', index: 'Index' } as Record<string, string>,
      notesOff: 'Notes off',
      notes: (count: number) => (count === 1 ? '1 note' : `${count} notes`),
      highlightsOff: 'Highlights off',
      headnote: 'Headnote',
      seeAlso: 'See also',
    },
    addedOne: 'Added 1 document',
    addedMany: (count: number) => `Added ${count} documents`,
    /** A smart collection's entries from before its link (S18f), `SmartCollectionRule`'s words. */
    earlierHeading: 'Not part of the smart collection: added before it was linked to its saved search.',
    earlierRemove: 'Remove These Entries',
    earlierRemoveTitle: 'Remove These Entries?',
    earlierRemoveMessage: (count: number) =>
      count === 1
        ? 'Removes the entry added before this collection was linked to its saved search.'
        : `Removes the ${count.toLocaleString('en-US')} entries added before this collection was linked to its saved search.`,
    earlierRemoveCancel: 'Cancel',
    earlierEmptyNote: 'Empty note block',
    /** `CollectionEditorNaming.untitledSection`, a heading with no text. */
    untitledSection: 'Untitled section',
    /** The group's name, the web's own. */
    earlierLabel: 'Entries added before the link',
    /** The toolbar's Export…, and the iPhone's Outline | Preview control, which a narrow window shows (S18e). */
    export: 'Export…',
    pane: 'View',
    outline: 'Outline',
    preview: 'Preview',
  },
  /**
   * The live preview beside Contents (PLAN's S18e), the app's `CollectionPreviewView`: the HTML
   * export's page, the first 20 documents until Render All, with the app's bars and caption, a smart
   * collection's results counted as the app counts them (S18f). The frame's name and the missing
   * volumes' note are the web's own, as a server downloads no volume.
   */
  collectionPreview: {
    loading: 'Building preview…',
    unavailable: 'Preview Unavailable',
    capNotice: (shown: number, total: number) => `Showing first ${shown} of ${total} documents`,
    renderAll: 'Render All',
    /** What the preview says once Render All has taken its bar away, the web's own. */
    renderingAll: (count: number) => `Showing all ${count} documents`,
    missingVolumes: (count: number) => `${count} volume${count === 1 ? '' : 's'} not downloaded`,
    fidelityNote: 'Preview of the HTML export — PDF and Word pagination will differ',
    frameTitle: 'Preview of the collection’s HTML export',
    missingVolumesNote: 'This server’s folder of volumes does not hold them, so their documents show as citations.',
  },
  /**
   * The export sheet (PLAN's S18e), the app's `ExportSheetView`: the composition's sentence, the format
   * grid, the quotation check and Export {Format}, in the app's words, and from S18f `.fruscollection`
   * with its notes switch and hint, and from S25a PDF, while the server's PDF service answers. Its Send
   * to Zotero Library waits for phase 3's secrets; the word cloud's note and the saved file's line are
   * the web's own.
   */
  collectionExport: {
    title: 'Export collection',
    close: 'Close',
    exportFormat: (format: string) => `Export ${format}`,
    exporting: 'Exporting…',
    complete: 'Export Complete',
    formats: 'Format',
    grid: {
      pdf: { label: 'PDF', caption: 'Formatted reader' },
      html: { label: 'HTML', caption: 'Web page' },
      docx: { label: 'Word', caption: 'Editable .docx' },
      bibtex: { label: 'BibTeX', caption: 'Reference manager' },
      zoteroJSON: { label: 'RIS', caption: 'Zotero / EndNote' },
      fruscollection: { label: '.fruscollection', caption: 'Editable copy for a colleague' },
    } as Record<string, { label: string; caption: string }>,
    /** `nativeShareOptions`: the notes' switch, off unless turned on, and what the file carries. */
    includeNotes: 'Include my research notes',
    nativeHint:
      'Shares an editable copy of this collection: its documents, composition, sections, and prose. Recipients open it in FRUS Explorer and download any volumes they don’t have. Your research notes stay private unless you include them above.',
    /** `Collection.compositionSummarySentence`: the default body depth, then what the composition turns on. */
    lead: {
      full: 'Exports the full text of each document',
      summaryOnly: 'Exports an AI summary of each document',
      index: 'Exports a citation-only index',
    } as Record<string, string>,
    included: {
      headnotes: 'headnotes',
      notes: 'your notes',
      footnotes: 'footnotes',
      sourceNotes: 'source notes',
      highlights: 'highlights',
      wordCloud: 'a word-cloud overview',
    },
    withIncluded: (lead: string, list: string) => `${lead}, with ${list}.`,
    noWordCloud: 'An export from this server draws no word cloud: the app draws it with a renderer of its own.',
  },
  /**
   * Collection settings, the iPad editor's ⚙ sheet: the name and note, the title page and
   * introduction, the presets, the three composition groups and, from S18f, the Smart Collection rows
   * with Link to Saved Search…, in the app's words. The summary prompt's hint is the web's own, as the
   * server writes no summary, and so is the line under a Summary only it does not offer, which ends in
   * the app's reason.
   */
  collectionSettings: {
    title: 'Collection settings',
    done: 'Done',
    nameHeader: 'Name',
    namePlaceholder: 'Collection Name',
    nameLabel: 'Collection name',
    noteHeader: 'Note',
    notePlaceholder: 'Optional note about this collection…',
    noteLabel: 'Collection note',
    addNote: 'Add a note',
    addNoteLabel: 'Add a collection note',
    frontMatterHeader: 'Title Page & Introduction',
    frontMatterFooter:
      'Rendered on the exported title page; the introduction opens the body, after the table of contents and before the first document. Leave blank to keep the plain document layout.',
    subtitlePlaceholder: 'Subtitle (title page)',
    subtitleLabel: 'Collection subtitle',
    authorPlaceholder: 'Author',
    authorLabel: 'Author line',
    introduction: 'Introduction',
    colophon: 'Include colophon',
    projectProvenance: 'Stamp active project on export',
    methodAppendix: 'Append the query log',
    methodAppendixDetail: 'Every search you ran under the active project, with its scope and result count.',
    presetsHeader: 'Start from a template — optional',
    presetActive: 'Active',
    presetHint: 'Applies this composition. Everything stays editable afterward.',
    presets: {
      teachingReader: { name: 'Teaching reader', subtitle: 'Full text · notes · chronology' },
      briefingPacket: { name: 'Briefing packet', subtitle: 'Summaries · headnotes · word cloud' },
      sourceDossier: { name: 'Source dossier', subtitle: 'Outline · source notes · sources' },
      scholarlyEdition: { name: 'Scholarly edition', subtitle: 'Everything · full apparatus' },
    },
    documentContent: 'Document content',
    documentContentHelp: 'How much of each source to include.',
    bodyDepth: 'Body depth',
    bodyDepths: { full: 'Full document', summaryOnly: 'Summary only', index: 'Index / outline' } as Record<string, string>,
    summaryPrompt: 'Summary prompt',
    summaryPromptNone: 'Select…',
    summaryPromptHint: 'Summary only shows the summary stored for each document under this prompt: this server writes none.',
    /** `composition.summaryPrompt.hint`, the app's reason a summary must be had, which the web says where Summary only is not offered. */
    summaryOnlyReason: 'Summaries are generated on demand for documents that don’t already have one for this prompt. Requires Apple Intelligence.',
    summaryOnlyUnavailable: 'Summary only is not offered: none of this collection’s documents has a summary stored.',
    smartHeader: 'Smart Collection',
    smartLink: 'Link to Saved Search…',
    smartUnlink: 'Unlink',
    smartMissing: 'Saved search not found',
    smartMissingExplanation:
      'The linked saved search could not be found. It may have been deleted. Unlink it to add to this collection by hand.',
    smartExplanation: 'Documents are resolved from this saved search at export time. Static entries are ignored.',
    smartNoSearches: 'Save a search from the Search tab to enable smart collections.',
    smartPickerTitle: 'Link to Saved Search',
    smartPickerCancel: 'Cancel',
    footnotes: 'Footnotes',
    sourceNote: 'Archival source note',
    annotations: 'Your annotations',
    annotationsHelp: 'Notes, highlights & headnotes — linked to each source.',
    notes: 'Research notes',
    highlights: 'Highlights in body',
    headnotes: 'Headnotes',
    analysis: 'Analysis & apparatus',
    analysisHelp: 'Generated overviews and the contents-list style.',
    wordCloud: 'Word-cloud overview',
    tocStyle: 'Contents list',
    tocStyles: { citation: 'Citation', headerAndDateline: 'Header & Dateline' } as Record<string, string>,
    introductionLoading: 'Loading the editor…',
    introductionKept: 'The introduction keeps formatting the web cannot show. Editing it here keeps its text and drops that formatting.',
    introductionUnreadable:
      'The introduction could not be shown with its formatting, so it is open as plain text. Its formatting is kept until its text is changed here.',
  },
  /**
   * The entry inspector, Document Details and Section Details, in the app's words: its identity and title
   * override, the reader's annotations with what the entry includes, New Note… and Insert as Excerpt, the
   * export overrides and section defaults with what Default resolves to, the headnote's switch and its
   * card (S18f), the excerpts here and the provenance. The line under a Summary only the web does not
   * offer is its own, ending in the app's reason.
   */
  collectionInspector: {
    sectionTitle: 'Section Details',
    documentTitle: 'Document Details',
    done: 'Done',
    loading: 'Loading document details…',
    document: 'Document',
    volume: 'Volume',
    titleOverride: 'Title override',
    titleOverrideCaption: 'Overrides the document title in the table of contents and the export heading. Leave blank to use the derived title.',
    section: 'Section',
    yourAnnotations: 'Your Annotations',
    noNotes: 'No research notes',
    noteInclude: 'Include this research note when notes apply',
    noteCaption: 'Checked notes are included when research notes apply to this document. Unselecting every note turns notes off for it.',
    highlightCount: (count: number) => (count === 1 ? '1 highlight' : `${count} highlights`),
    highlightInclude: 'Include this passage when highlights apply',
    inserted: 'Inserted',
    insertExcerpt: 'Insert as Excerpt',
    noText: 'No stored passage text — open the document and re-create this highlight to excerpt it.',
    highlightCaption: 'Checked passages are included when highlights apply to this document. Unselecting every passage turns highlights off for it.',
    summaryFromPrompt: (name: string) => `AI summary — ${name}`,
    summary: 'AI summary',
    resolvesOn: 'Default → On',
    resolvesOff: 'Default → Off',
    resolvesTo: (text: string) => `Default → ${text}`,
    promptNone: 'None',
    default: 'Default',
    on: 'On',
    off: 'Off',
    highlights: 'Highlights',
    notes: 'Research notes',
    sourceNote: 'Source note',
    footnotes: 'Footnotes',
    prompt: 'Summary prompt',
    related: 'Related documents',
    relatedCaption:
      'Adds a \u{201C}See also\u{201D} line listing cross-referenced documents that are also in this collection. Off unless turned on here or on the section.',
    bodyDepthDefault: 'Default',
    bodyDepth: 'Body depth',
    overrides: 'Export Overrides',
    overridesCaption: 'Default follows the section’s setting when its heading sets one, else the collection’s composition.',
    sectionDefaults: 'Section Defaults',
    sectionDefaultsCaption:
      'Documents in this section use these settings unless they set their own. Default falls through to the collection’s composition.',
    excerpts: 'Excerpts in This Collection',
    excerptsCaption: 'Reorder or delete excerpts in the collection list. Insert new ones from the highlight rows above.',
    headnote: 'Headnote',
    headnoteToggle: 'Show a summary above the document',
    /** The headnote card: its title, its chip of who wrote it, its words with none, Edit, Cancel and Save. */
    headnoteKeyTakeaway: 'Key takeaway · headnote',
    headnoteChips: { aiGenerated: 'AI draft', aiEdited: 'AI · edited', userWritten: 'Yours' } as Record<string, string>,
    headnoteEmpty: 'No headnote yet. Edit to write a key takeaway, or generate a document summary to seed one.',
    headnoteEdit: 'Edit',
    headnoteCancel: 'Cancel',
    headnoteSave: 'Save',
    /** The card's editor's name, the web's own. */
    headnoteText: 'Headnote text',
    /** New Note…, and `InlineNoteCreateSheet`'s title and Save. */
    newNote: 'New Note…',
    newNoteTitle: 'New Research Note',
    newNoteCancel: 'Cancel',
    newNoteSave: 'Save Note',
    /** The note's field's name, the web's own. */
    newNoteText: 'Note text',
    summaryOnlyUnavailable: 'Summary only is not offered: this document has no summary stored.',
    provenance: 'Provenance',
    noSource: 'No archival source note indexed',
    tags: 'Tags',
  },
  /** Add Highlighted Passages, in the app's words. */
  addHighlights: {
    title: 'Add Highlighted Passages',
    emptyTitle: 'No Highlighted Passages',
    emptyDetail: 'Highlight passages in this collection’s documents to insert them here as excerpts.',
    insert: (count: number) => `Insert ${count} Excerpt${count === 1 ? '' : 's'}`,
    cancel: 'Cancel',
    loading: 'Loading the highlights…',
  },
  /**
   * Add Documents, in the app's words for its four tabs, Citations and Tags since PLAN's S25d. The Citations
   * tab's hint names the server's index where the app's names the device's, and its line while it resolves is
   * the web's own, where the app shows a spinner; so is the line on a tag's document whose volume the catalogue
   * does not list, which the app's sheet adds.
   */
  addDocuments: {
    title: 'Add Documents',
    cancel: 'Cancel',
    tabs: 'Find documents',
    search: 'Search',
    browse: 'Browse',
    citations: 'Citations',
    tags: 'Tags',
    add: (count: number) => `Add ${count} Document(s)`,
    searchPlaceholder: 'Search indexed documents',
    searchHint: 'Search the full text of the volumes this server has indexed.',
    noResults: 'No results.',
    editorialNote: 'Editorial note',
    filter: 'Filter volumes by title or ID',
    back: 'Volumes',
    selectAll: 'Select All',
    deselectAll: 'Deselect All',
    inCollection: 'In collection',
    loading: 'Loading…',
    notIndexed: 'This server has not indexed this volume, so its documents cannot be listed here.',
    citationsPlaceholder: 'Paste citations or history.state.gov links, one per line…',
    resolve: 'Resolve',
    citationsHint:
      'Each line is resolved against the FRUS manifest and this server’s index — footnotes, bibliography entries, and document links all work.',
    citationsEmpty: 'Nothing to resolve — paste at least one line.',
    resolvedCount: (resolved: number, total: number) => `${resolved} of ${total} resolved`,
    toReview: (count: number) => `· ${count} to review`,
    noMatch: (reason: string) => `No match — ${reason}`,
    resolving: 'Resolving…',
    tagsNone: 'No user tags yet. Tag documents or research notes to gather them here.',
    tagsBack: 'Tags',
    tagsEmpty: 'No documents carry this tag.',
    notCatalogued: 'The published catalogue does not list this volume, so this server cannot add the document to a collection.',
  },

  // ─── Tools ────────────────────────────────────────────────────────────────
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

  // ─── Settings ─────────────────────────────────────────────────────────────
  /** Settings ▸ Tags, its editor and its merge sheet, in the app's words. */
  settings: {
    title: 'Settings',
    panes: 'Settings',
    tags: 'Tags',
    tagsEmpty:
      'No tags yet. Tags are the labels you apply to research notes and documents as you read — create one here, or from any note.',
    tagsFooter: 'Tags are global labels you apply to research notes and documents. They are not scoped to a project.',
    // S17f: the reader's own order, which the Move commands set.
    tagsOrderFooter: 'This order is also the order of your tags in the note editor, the document tag picker and Search.',
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
    // The method appendix (PLAN's S17f), in the words of the app's export sheet; the two files' own
    // links are the web's, since a browser saves one file at a time.
    appendixAction: 'Export Query Log as a Method Appendix',
    appendixEmpty: 'No searches recorded yet.',
    appendixFooter:
      'Every search you ran, in a Markdown table and a CSV. Each row gives the scope the search ran under and how many volumes were indexed at the time. Counts that hit the app’s row ceiling appear as “at least N”, so a partial result is never printed as a total.',
    appendixMarkdown: 'Markdown table (frus-query-log.md)',
    appendixCSV: 'CSV (frus-query-log.csv)',
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
   * Settings ▸ Keys (PLAN's S20c), the web's own pane for the app's Connections: the services' names, the
   * status, About and field lines, the links to a key, Add Key…, Replace Key…, Remove Key, Save,
   * Cancel, Saved, Removed and the question before a removal, in the app's words; the rest are the
   * web's own, since a key is kept on this server and not in a keychain.
   */
  keys: {
    title: 'Keys',
    nara: 'NARA Catalog',
    zotero: 'Zotero',
    stored: 'Key stored',
    notStored: 'No key stored',
    naraAbout:
      'A free key from the National Archives Catalog. Source Explorer needs it to search lot files and Presidential Library records; everything else in the app works without it.',
    naraGetKey: 'Get a free key from NARA',
    naraField: 'Paste your key',
    naraFieldA11y: 'NARA Catalog key',
    zoteroAbout:
      'Send to Zotero Library sends FRUS documents to your Zotero library with your tags and research notes attached, and Zotero syncs them to all your devices.',
    zoteroGetKey: 'Create a Zotero API key',
    zoteroField: 'Paste your Zotero API key…',
    zoteroFieldA11y: 'Zotero API key',
    add: 'Add Key…',
    replace: 'Replace Key…',
    remove: 'Remove Key',
    save: 'Save',
    cancel: 'Cancel',
    saved: 'Saved',
    removed: 'Removed',
    removeTitle: 'Remove the stored key?',
    removeConfirm: 'Remove',
    removeMessage: 'The server forgets it, for every browser you sign in from. Nothing you’ve already saved is affected.',
    // The web's own: the server keeps the key, and nothing here uses it yet.
    pending:
      'Nothing on this server uses these keys yet: Source Explorer’s archival search and Send to Zotero Library, which will, are still to come.',
    instanceNara: 'This server has a NARA Catalog key of its own, which serves you while you have none.',
    footer:
      'Each key is kept on this server, encrypted, and is never shown again once it is saved: the server alone uses it, to reach the service for you. Whoever runs this server holds the key file that opens them.',
    loading: 'Loading the keys…',
    userDataOff: 'This server keeps no keys or other data of yours: it is read-only.',
  },
  /** Settings ▸ Projects, the project editor and Merge Project, in the app's words. */
  projects: {
    title: 'Projects',
    activeLabel: 'Active Project',
    global: 'Global Context',
    home: 'Project Home',
    activeFooter: 'The active project scopes the notes, collections, history, and searches you see. Global Context shows everything.',
    empty: 'No projects yet. A project keeps one line of research — its notes, collections, history and searches — separate from the rest.',
    listHeader: 'All Projects',
    new: 'New Project…',
    listFooter: "This order is also the order of the Active Project picker, the project switcher and the note editor's project list.",
    active: 'active',
    edit: 'Edit',
    mergeShort: 'Merge into…',
    relatedHeader: 'Related',
    tags: 'Tags',
    scopes: 'Volume Scopes',
    relatedFooter: 'Open Tags to rename, merge or delete a tag. Open Volume Scopes to edit or delete a scope — scopes cannot be merged.',
    noneYet: 'None yet',
    tagCount: (count: number) => (count === 1 ? '1 tag' : `${count.toLocaleString('en-US')} tags`),
    scopeCount: (count: number) => (count === 1 ? '1 scope' : `${count.toLocaleString('en-US')} scopes`),
    editorNew: 'New Project',
    editorEdit: 'Edit Project',
    cancel: 'Cancel',
    save: 'Save',
    nameHeader: 'Name',
    namePlaceholder: 'Project name',
    nameField: 'Project name',
    questionHeader: 'Research Question',
    questionField: 'Research question',
    manage: 'Manage',
    merge: 'Merge into Another Project…',
    delete: 'Delete Project',
    manageFooterOnly:
      'Merging needs a second project to merge into. Deleting keeps your notes, collections, and history — it only unlinks them from this project.',
    manageFooter:
      'Merging moves everything filed here into the project you choose. Deleting keeps your notes, collections, and history — it only unlinks them from this project.',
    deleteTitle: 'Delete Project?',
    deleteMessage: 'Activity records are kept but unlinked from this project.',
    deleteConfirm: 'Delete',
    deleteCancel: 'Cancel',
    mergeTitle: 'Merge Project',
    mergeInto: (name: string) => `Merge “${name}” into:`,
    mergeExplanation: (name: string) =>
      `All notes, collections, summaries, and reading history assigned to “${name}” will be re-assigned to the selected project. “${name}” will be deleted.`,
    mergeCancel: 'Cancel',
    mergeConfirm: 'Merge',
    loading: 'Loading the projects…',
  },
  /** The Move commands of the Settings lists, in the app's words. */
  listOrder: {
    moveToTop: 'Move to Top',
    moveUp: 'Move Up',
    moveDown: 'Move Down',
    moveLabel: (command: string, name: string) => `${command}: ${name}`,
  },
  /** Settings ▸ Research Sessions and the Session Log, in the app's words. */
  sessions: {
    title: 'Research Sessions',
    recording: 'Recording',
    logging: 'Log Research Sessions',
    loggingFooter:
      'Despite the name, this switch covers everything the app can track about your work. That means the documents you open, the text of the searches you run, and the collections you export. The app keeps one record of each. The History screen, a project’s Recently Read and Recent Searches cards, its Documents Visited and Searches Run counts, and the Session Log all read those same records. The Session Log groups them into sessions, and a session ends after 30 minutes of inactivity. The records stay on this device, and in your private iCloud database if iCloud sync is on. Turn the switch off and all of that recording stops. Those surfaces will thin out and eventually empty. That is the switch working, not a fault. Anything recorded before you turned it off stays until you delete it.',
    activity: 'Recorded Activity',
    log: 'Session Log',
    activityEmpty: 'Nothing has been recorded yet. Open a document or run a search and it will appear here.',
    activityFooter:
      'The app infers sessions from the times you opened documents, ran searches, and exported collections. A gap of 30 minutes starts a new session. The same records fill the History screen and a project’s Recents.',
    manage: 'Manage',
    deleteAll: 'Delete Recorded Sessions…',
    manageFooter:
      'This deletes the whole record of your work: every document you opened, every search you ran, and every collection you exported. It goes from this device, and from your iCloud database if iCloud sync is on. Your notes, highlights, tags, and collections are not touched. To delete single entries instead, use the History screen.',
    deleteTitle: 'Delete Recorded Sessions?',
    deleteMessage: (events: string) =>
      `${events} will be permanently deleted from this device. If iCloud sync is on, the same records go from iCloud too. A session is made of every document you opened, every search you ran, and every collection you exported. Your notes, highlights, tags, and collections are not affected.`,
    deleteConfirm: 'Delete',
    deleteCancel: 'Cancel',
    nothingRecorded: 'Nothing recorded yet',
    sessionCount: (count: number, exact: boolean) =>
      exact
        ? count === 1
          ? '1 session'
          : `${count} sessions`
        : count === 1
          ? 'at least 1 session'
          : `at least ${count} sessions`,
    eventCount: (count: number) => (count === 1 ? '1 event' : `${count} events`),
    lastToday: (time: string) => `last today ${time}`,
    lastOlder: (date: string) => `last ${date}`,
    emptyTitle: 'No Sessions Yet',
    emptyDetail: 'Your research activity will appear here as you open documents, run searches, and export collections.',
    showMore: 'Show More',
    showingRecent: (shown: number, total: number) => `Showing the most recent ${shown} of ${total} recorded activities.`,
    oldestPartial: 'The oldest session listed may reach further back than the activity loaded.',
    ongoing: 'Ongoing',
    results: (count: number) => (count === 1 ? '1 result' : `${count} results`),
    searchLine: (query: string, results: string) => `“${query}” — ${results}`,
    documents: (count: number) => (count === 1 ? '1 document' : `${count} documents`),
    exportLine: (format: string, documents: string) => `Exported ${format} — ${documents}`,
    loading: 'Loading the sessions…',
  },
  /**
   * Settings ▸ Reading, the web's own pane for the app's Display ▸ Reading and Citations sections, in
   * their words.
   */
  reading: {
    title: 'Reading',
    openIn: 'Open Documents In',
    openInA11y: 'Default document mode',
    modes: { read: 'Read', research: 'Research', rememberLast: 'Remember Last' },
    footer:
      '“Remember Last” reopens documents in the mode you used last, Read or Research. Research mode shows the Research rail in a side panel beside the document. Read mode hides the rail so you can just read. The rail toggle inside a document always wins for that document.',
    citations: 'Citations',
    citationStyle: 'Citation Style',
    citationFooter: 'Used when copying or sharing a citation.',
    /** The kit's names for the styles in Settings (`CitationStyle.displayName`). */
    styles: { historyAtState: 'History at State (Recommended)', chicago: 'Chicago', turabian: 'Turabian' },
  },

  // ─── Admin ────────────────────────────────────────────────────────────────
  /**
   * Administration (PLAN's S20d), the web's own, since the Mac has one user and no admin: its panes,
   * Status, Jobs, Users, Backups and Keys, their lists, an admin's changes to the accounts, and the
   * recovery actions SPEC names, erasing a user's research and resetting the index; what a user's
   * research holds is named in the export sheet's words (Settings ▸ Data's `types`).
   */
  admin: {
    title: 'Administration',
    link: 'Admin',
    panes: 'Administration',
    loading: 'Loading…',
    stale: (detail: string) => `This may be out of date, since it could not be read again: ${detail}`,
    notAdmin: 'Administration is for admins, and your account does not hold the role.',
    userDataOff:
      'This server keeps no user data (FRUS_USER_DATA is off), and its administration lives in the user store: use frus-light on the server instead.',
    yes: 'Yes',
    no: 'No',
    cancel: 'Cancel',
    never: 'Never',
    /** A time the server gave, in the browser's own zone. */
    time: (text: string) => new Date(text).toLocaleString('en-US', { dateStyle: 'medium', timeStyle: 'short' }),
    bytes: (count: number) =>
      count >= 1_048_576 ? `${(count / 1_048_576).toFixed(1)} MB` : count >= 1_024 ? `${Math.round(count / 1_024)} KB` : `${count} bytes`,
    status: {
      title: 'Status',
      server: 'Server',
      version: 'Version',
      mode: 'Mode',
      modes: { import: 'Import: an index exported from the Mac', standalone: 'Standalone: the server keeps its own library' },
      auth: 'Sign-in',
      auths: { none: 'None: one user, on this machine', header: 'Through a proxy that signs people in', local: 'Accounts of this server’s own' } as Record<string, string>,
      started: 'Running since',
      index: 'Index',
      readiness: 'State',
      noIndex: 'No index is served.',
      served: (volumes: number, catalogue: number, documents: number) =>
        `${volumes.toLocaleString('en-US')} of the catalogue’s ${catalogue.toLocaleString('en-US')} volumes, ${documents.toLocaleString('en-US')} documents`,
      volumes: 'Volumes served',
      indexVersion: 'Index version',
      indexVersions: (index: number, supported: number) =>
        index === supported ? String(index) : `${index}, where this server serves ${supported}`,
      exported: 'Exported',
      exportedBy: (version: string, build: string) => `by FRUS Explorer ${version} (${build})`,
      store: 'User store',
      stores: { sqlite: 'app.db, SQLite', postgreSQL: 'PostgreSQL' },
      migration: 'Migration',
      migrations: (at: number, latest: number) => (at === latest ? `${at}, this build’s` : `${at} of ${latest}`),
      backups: 'Backups',
      backupsDaily: (daily: number, kept: number) => `${daily} daily ${daily === 1 ? 'backup' : 'backups'} kept, of ${kept} at most`,
      backupsAt: (hour: string, zone: string) => `Each day at ${hour}, ${zone}`,
      backupsNewest: 'Newest',
      backupsNone: 'None yet: the first is taken once the store holds research.',
      backupsHost: 'Copied to the host’s folder',
      backupsService: 'The user store is a PostgreSQL database, whose backups are its database service’s.',
      keys: 'Stored keys',
      keyFile: 'Key file',
      keysStored: (count: number) => (count === 1 ? '1 key stored' : `${count.toLocaleString('en-US')} keys stored`),
      jobs: 'Jobs',
      jobsNone: 'No job is running.',
      jobsQueued: (count: number) => (count === 1 ? '1 waiting' : `${count} waiting`),
      recovery: 'Recovery',
      reset: 'Reset the Index…',
      resetLead:
        'Removes the index this server serves, so that it waits for an export in /data/import, as at its first start. Search stops until one is imported; the reader keeps working from the TEI files, and nobody’s research changes.',
      resetStandalone: 'A Standalone server’s index is reset by indexing its library again, which comes with the library’s own screens.',
      resetTitle: 'Reset the index?',
      resetMessage:
        'The server stops serving its index and removes it, with the index the last import replaced. Search stops until you copy an export into /data/import. Nobody’s notes, highlights or other research change.',
      resetConfirm: 'Reset',
      resetQueued: 'The reset is queued as a job: Jobs follows it.',
    },
    jobs: {
      title: 'Jobs',
      lead: 'Long work runs as a job, one at a time, in the order asked for: an index imported from /data/import, a JSON export imported into someone’s research, an index reset, and the library’s downloads. A job stops between two of its steps when it is cancelled.',
      caption: 'The jobs the server holds, newest first',
      empty: 'No jobs yet.',
      job: 'Job',
      state: 'State',
      progress: 'Progress',
      askedBy: 'Asked by',
      queued: 'Queued',
      started: 'Started',
      finished: 'Finished',
      actions: 'Actions',
      kinds: {
        indexImport: 'Index import',
        researchImport: 'Research import',
        indexReset: 'Index reset',
        libraryDownload: 'Library download',
      } as Record<string, string>,
      states: { queued: 'Waiting', running: 'Running', succeeded: 'Finished', failed: 'Failed', cancelled: 'Cancelled' },
      stopping: 'Stopping at its next step',
      theServer: 'The server',
      percent: (fraction: number) => `${Math.round(fraction * 100)}%`,
      cancel: 'Cancel…',
      cancelA11y: (job: string) => `Cancel ${job}`,
      cancelTitle: 'Cancel this job?',
      cancelMessage:
        'A job waiting leaves the line at once. A job running stops before its next step, and what it had not finished is not kept.',
      cancelConfirm: 'Cancel Job',
      keepRunning: 'Keep It',
      cancelled: (job: string) => `Cancelled ${job}.`,
      stopAsked: (job: string) => `${job} stops before its next step.`,
    },
    /** Administration ▸ Library (PLAN's S21c): a Standalone server's volumes and their downloads. */
    library: {
      title: 'Library',
      lead: 'The volumes this server keeps, in /data/volumes, each downloaded from the address the catalogue names and kept only once its length and hash are those GitHub’s listing gives, with its figure images. A download is a job, which Jobs follows: it stops between two volumes when it is cancelled, and goes on volume by volume when the server starts again after a restart stopped it.',
      leadImport:
        'This server serves an index exported from the Mac, and reads its volumes from the TEI folder mounted at /data/volumes, which it never writes. The library downloads in Standalone mode.',
      fromGitHub: 'Volumes come from GitHub’s HistoryAtState/frus repository, and their figure images from history.state.gov.',
      fromMirror: 'Volumes and their figure images come from the mirror this server’s operator names (FRUS_LIBRARY_MIRROR).',
      count: (count: number, word: string) => `${count.toLocaleString('en-US')} ${word.charAt(0).toLowerCase()}${word.slice(1)}`,
      statuses: {
        notDownloaded: 'Not downloaded',
        queued: 'Waiting to download',
        downloading: 'Downloading',
        downloaded: 'Downloaded',
        indexed: 'Indexed',
        failed: 'Failed',
      },
      importStatuses: { downloaded: 'In the TEI folder', notDownloaded: 'Not in the TEI folder' },
      shows: {
        notDownloaded: 'Not downloaded',
        queued: 'Waiting or downloading',
        downloading: 'Downloading',
        downloaded: 'Downloaded',
        indexed: 'Indexed',
        failed: 'Failed',
      },
      downloadAll: 'Download All',
      downloadAllNote: (count: number) =>
        `Every volume not downloaded: ${count.toLocaleString('en-US')} of the catalogue’s, each GitHub’s listing still names.`,
      allDownloaded: 'Every volume of the catalogue is downloaded.',
      queued: (subject: string) => `The download of ${subject} is queued as a job: Jobs follows it.`,
      queuedPlain: 'The download is queued as a job: Jobs follows it.',
      filter: 'Find a volume',
      show: 'Show',
      showAll: 'All volumes',
      shownCount: (shown: number, all: number) =>
        shown === all ? `${all.toLocaleString('en-US')} volumes` : `${shown.toLocaleString('en-US')} of ${all.toLocaleString('en-US')} volumes`,
      caption: 'The catalogue’s volumes, with what this server holds of each',
      volume: 'Volume',
      state: 'State',
      file: 'File',
      actions: 'Actions',
      indexedWithoutFile: 'Its file is not downloaded, so the reader cannot open its documents: Download brings it.',
      askedBy: (user: string) => `Asked for by ${user}`,
      figures: (count: number) => (count === 1 ? '1 figure image' : `${count.toLocaleString('en-US')} figure images`),
      catalogueSize: (size: string) => `${size} in the catalogue`,
      download: 'Download',
      downloadA11y: (volume: string) => `Download ${volume}`,
      downloadAgain: 'Download Again',
      downloadAgainA11y: (volume: string) => `Download Again ${volume}`,
      remove: 'Remove…',
      removeA11y: (volume: string) => `Remove ${volume}`,
      removeTitle: (volume: string) => `Remove ${volume}?`,
      removeMessage:
        'Its file and figure images are deleted from /data/volumes, and the reader can no longer open its documents. Download brings them back.',
      removeConfirm: 'Remove',
      keep: 'Keep It',
      removed: (volume: string) => `Removed ${volume}.`,
    },
    users: {
      title: 'Users',
      leads: {
        local: 'Each person signs in with an account of this server’s own. An admin makes each account and gives the person its first password.',
        header: 'People sign in through the proxy in front of this server, which keeps their accounts: a user is made the first time it names them. FRUS_ADMIN_USERS names the admins.',
        none: 'This server has no sign-in: it has one user, owner, who holds every role.',
      } as Record<string, string>,
      caption: 'The users this server holds, by name',
      name: 'Name',
      displayName: 'Display name',
      role: 'Role',
      roleA11y: (name: string) => `Role of ${name}`,
      setRole: 'Set Role',
      setRoleA11y: (name: string) => `Set Role of ${name}`,
      roles: { reader: 'Reader', curator: 'Curator', admin: 'Admin' },
      lastSignIn: 'Last sign-in',
      account: 'Account',
      active: 'Active',
      disabled: 'Disabled',
      noPassword: 'No password',
      actions: 'Actions',
      disable: 'Disable…',
      enable: 'Enable',
      disableA11y: (name: string) => `Disable ${name}`,
      enableA11y: (name: string) => `Enable ${name}`,
      password: 'Set Password…',
      passwordA11y: (name: string) => `Set Password for ${name}`,
      erase: 'Erase Research…',
      eraseA11y: (name: string) => `Erase Research of ${name}`,
      add: 'Add an Account',
      addName: 'Name',
      addDisplayName: 'Display name (optional)',
      addRole: 'Role',
      newPassword: 'Password',
      confirmPassword: 'Password again',
      passwordRule: 'At least 15 characters.',
      mismatch: 'The two passwords differ.',
      addAction: 'Add Account',
      added: (name: string) => `Made ${name}’s account.`,
      changed: (name: string) => `Changed ${name}’s account.`,
      disableTitle: (name: string) => `Disable ${name}?`,
      disableMessage: 'They are signed out at once and cannot sign in until an admin enables the account. Their research is kept.',
      disableConfirm: 'Disable',
      passwordTitle: (name: string) => `Set a password for ${name}`,
      passwordMessage: 'They are signed out everywhere, and sign in with the new password, which you give them.',
      passwordSave: 'Set Password',
      passwordSet: (name: string) => `Set ${name}’s password.`,
      eraseTitle: (name: string) => `Erase the research of ${name}?`,
      eraseLoading: 'Counting what they hold…',
      eraseHolds: (name: string) => `${name} holds, on this server:`,
      eraseNothing: (name: string) => `${name} holds no research on this server.`,
      eraseMessage:
        'All of it is erased, and cannot be brought back but from a backup. Their account, its role and its password stay as they are.',
      eraseChanged: 'What they hold changed since it was counted, so nothing was erased. Here is what they hold now.',
      eraseConfirm: 'Erase',
      erased: (name: string, count: number) =>
        `Erased ${count.toLocaleString('en-US')} ${count === 1 ? 'record' : 'records'} of ${name}’s research.`,
      storedKeys: 'Stored Keys',
      holding: (count: number, name: string) => `${count.toLocaleString('en-US')} ${name}`,
    },
    backups: {
      title: 'Backups',
      lead: (hour: string, zone: string) =>
        `The server backs up its user store every day at ${hour}, ${zone}, and keeps the newest seven, beside the copies it takes before a migration or a restore. frus-light backup takes one now.`,
      leadPlain: 'The server backs up its user store every day, and keeps the newest seven, beside the copies it takes before a migration or a restore.',
      service: 'The user store is a PostgreSQL database: its backups are its database service’s, and the server takes none.',
      download: 'Download the Newest Backup',
      downloadNote: 'One tar archive: the newest daily backup and a manifest of what it holds. No backup holds the key file the stored keys are sealed under.',
      caption: 'The backups and copies the server keeps, newest first',
      empty: 'No backup yet: the first is taken soon after the store holds research.',
      name: 'Backup',
      kind: 'Kind',
      kinds: { daily: 'Daily', beforeMigration: 'Before a migration', beforeRestore: 'Before a restore' },
      taken: 'Taken',
      size: 'Size',
      migration: 'Migration',
      onHost: 'On the host',
    },
    keys: {
      title: 'Keys',
      lead: 'The instance’s NARA Catalog key serves each user who has no key of their own. Users keep their own in Settings ▸ Keys.',
      removeMessage: 'The server forgets the instance’s key: a user with no key of their own then has none.',
    },
  },
} as const;
