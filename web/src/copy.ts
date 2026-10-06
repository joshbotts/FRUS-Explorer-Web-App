// Every string the app shows, in one place, for the string catalogue that check 10 will compare
// with the app's. Where the Mac app labels the same control, this uses its wording: Copy URL from
// its Cite popover, Copy Citation from the reader, Document type and its choices from the search
// filters, Text Size from Settings. The rest are the web's own until check 10 settles them.

export const copy = {
  app: {
    name: 'FRUS Explorer Light',
    skipToContent: 'Skip to content',
    navigation: 'Main',
    search: 'Search',
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
    toSearch: 'Go to Search',
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
  reader: {
    previous: 'Previous',
    next: 'Next',
    openOnline: 'Open on history.state.gov',
    textSize: 'Text Size',
    textSizes: { small: 'Small', medium: 'Medium', large: 'Large', extraLarge: 'Extra Large' },
    cite: 'Cite',
    frameTitle: (header: string) => `Document text: ${header}`,
    toolbar: 'Document',
    linksLater: 'Links inside documents open in a later version of FRUS Explorer Light.',
    loading: 'Loading the document…',
  },
  cite: {
    title: 'Cite',
    style: 'Citation style',
    copyCitation: 'Copy Citation',
    copyLink: 'Copy URL',
    copied: 'Copied',
    copyFailed: 'The browser did not allow copying. The text is selected below: press ⌘C or Ctrl+C.',
    toCopy: 'Text to copy',
    close: 'Close',
  },
} as const;
