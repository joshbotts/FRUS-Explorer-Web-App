// The packet's sheet and the plan picker (PLAN's S30d): Export packet, disabled for a plan with no documents, opens the
// sheet over the plan; the sheet shows the server's packet, writes the topic half a second after typing stops and at Done,
// with its caption, writes What to Include, asks for a repository's slice, copies a repository's draft and says so, and
// saves the text it shows, and the PDF where the server's PDF service answers; the picker says what it adds, lists the
// plans, finds one by name, adds to it or makes one, shows Added and closes.
import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { VisitPacket, VisitPlan } from '../api/visits';
import { ProblemAnswer, ready, renderAt, stubServer } from '../test/renderRoute';
import { sent } from '../test/notes';
import { pickerBanner, planMatches, sameTopicText, showsSeededCaption, topicIsUncommitted, writtenTopic } from './visitRules';

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
  vi.useRealTimers();
});

const me = { userId: 'owner', displayName: 'Owner', auth: 'none', roles: ['reader', 'curator', 'admin'], userData: true, csrfToken: 't' };
const planId = '5E30D000-0000-4000-8000-000000000001';
const planPath = `/api/v1/me/visits/${planId}`;

function plan(fields: Partial<VisitPlan> = {}): VisitPlan {
  return {
    id: planId,
    name: 'Berlin',
    displayName: 'Berlin',
    inquiryText: 'What did Khrushchev want?',
    projectIds: ['P1'],
    project: { id: 'P1', name: 'Berlin crisis' },
    deliverables: { includeLinks: true, includeTargets: true, includeInquiry: true, includeCitationCrib: false },
    tiers: [],
    documentCount: 1,
    indexedDocumentCount: 1,
    served: true,
    summary: '1 target across 1 repository.',
    sections: [],
    storedTargets: [],
    documents: [{ key: 'frus1961-63v06/d10', volumeId: 'frus1961-63v06', documentId: 'd10', includeSource: true, includeExternalRefs: false }],
    sparsity: null,
    ...fields,
  };
}

const college = 'National Archives at College Park';
const library = 'John F. Kennedy Presidential Library';

function packet(fields: Partial<VisitPacket> = {}): VisitPacket {
  return {
    text: '# Archive visit packet: Berlin\n\n1 research target across 1 repository\n\n## National Archives at College Park',
    day: '2026-11-25',
    repository: null,
    repositories: [college, library],
    drafts: [
      { repository: college, text: '## Advance inquiry\n\n### National Archives at College Park\nTo: archives2reference@nara.gov' },
      { repository: library, text: '## Advance inquiry\n\n### John F. Kennedy Presidential Library' },
    ],
    topic: 'What did Khrushchev want?',
    topicPlaceholder: '[Describe your research topic in one or two sentences.]',
    researchQuestion: 'What did Khrushchev want?',
    deliverables: { includeLinks: true, includeTargets: true, includeInquiry: true, includeCitationCrib: false },
    title: 'Berlin',
    fileName: 'Archives Visit — Berlin.pdf',
    textFileName: 'Archives Visit — Berlin.txt',
    ...fields,
  };
}

const server = (answers: Record<string, unknown> = {}) =>
  stubServer({
    '/readyz': ready,
    '/api/v1/me': me,
    '/api/v1/pdf': { available: false },
    '/api/v1/me/visits': { total: 1, items: [{ id: planId, name: 'Berlin', displayName: 'Berlin', documentCount: 1, indexedDocumentCount: 1 }] },
    [planPath]: plan(),
    [`${planPath}/packet`]: packet(),
    ...answers,
  });

async function openSheet() {
  renderAt(`/visits/${planId}`);
  await userEvent.click(await screen.findByRole('button', { name: 'Export packet' }));
  const sheet = await screen.findByRole('dialog', { name: 'Archives Visit' });
  await within(sheet).findByText(/# Archive visit packet: Berlin/);
  return sheet;
}

describe('the packet’s sheet', () => {
  it('is offered for a plan with documents alone', async () => {
    server({ [planPath]: plan({ documents: [], documentCount: 0 }) });
    renderAt(`/visits/${planId}`);
    expect(((await screen.findByRole('button', { name: 'Export packet' })) as HTMLButtonElement).disabled).toBe(true);
  });

  it('shows the server’s packet, its topic with the seeded caption, and the repositories it covers', async () => {
    server();
    const sheet = await openSheet();
    expect(within(sheet).getByRole('region', { name: 'The packet' }).textContent).toBe(packet().text);
    const topic = within(sheet).getByRole('textbox', { name: 'Inquiry topic sentence' }) as HTMLTextAreaElement;
    expect(topic.value).toBe('What did Khrushchev want?');
    expect(within(sheet).getByText(/Seeded from your project’s research question/)).toBeTruthy();
    const scope = within(sheet).getByRole('combobox', { name: 'Repository' }) as HTMLSelectElement;
    expect([...scope.options].map((option) => option.textContent)).toEqual(['All repositories', college, library]);
    const drafts = within(sheet).getByRole('group', { name: 'Copy inquiry draft' });
    expect(within(drafts).getAllByRole('button').map((button) => button.textContent)).toEqual([college, library]);
    expect(within(sheet).getAllByRole('checkbox').map((box) => (box as HTMLInputElement).checked)).toEqual([true, true, true, false]);
    expect(within(sheet).getByRole('button', { name: 'Save as Text' })).toBeTruthy();
    expect(within(sheet).queryByRole('button', { name: 'Save as PDF' })).toBeNull();
  });

  it('saves the topic once, half a second after typing stops, the caption following the field', async () => {
    const saves: { at: number; body: unknown }[] = [];
    server({
      [`PATCH ${planPath}`]: (_url: URL, init?: RequestInit) => {
        saves.push({ at: performance.now(), body: sent(init).body });
        return plan({ inquiryText: 'The Vienna letters' });
      },
    });
    const sheet = await openSheet();
    const topic = within(sheet).getByRole('textbox', { name: 'Inquiry topic sentence' });
    await userEvent.clear(topic);
    await userEvent.type(topic, 'The Vienna letters');
    const typed = performance.now();
    expect(within(sheet).getByText('The inquiry drafts include what you write here.')).toBeTruthy();
    expect(saves).toEqual([]);
    await waitFor(() => expect(saves.length).toBe(1), { timeout: 3000 });
    expect(saves[0]!.body).toEqual({ inquiryText: 'The Vienna letters' });
    expect(saves[0]!.at - typed).toBeGreaterThanOrEqual(400);
    await new Promise((resolve) => setTimeout(resolve, 700));
    expect(saves).toHaveLength(1);
  });

  it('opens the topic on the plan’s, never on an older packet’s answer', async () => {
    server({ [planPath]: plan({ inquiryText: 'The topic as replaced' }), [`${planPath}/packet`]: packet({ topic: 'An older topic' }) });
    const sheet = await openSheet();
    expect((within(sheet).getByRole('textbox', { name: 'Inquiry topic sentence' }) as HTMLTextAreaElement).value).toBe('The topic as replaced');
  });

  it('keeps the sheet open, saying why, when Done’s save fails', async () => {
    server({ [`PATCH ${planPath}`]: new ProblemAnswer(413, 'CONTENT_TOO_LARGE', 'A change’s body here may be at most 64 KiB.') });
    const sheet = await openSheet();
    const topic = within(sheet).getByRole('textbox', { name: 'Inquiry topic sentence' });
    await userEvent.clear(topic);
    await userEvent.type(topic, 'A topic too long');
    await userEvent.click(within(sheet).getByRole('button', { name: 'Done' }));
    expect(await within(sheet).findByText('A change’s body here may be at most 64 KiB.')).toBeTruthy();
    expect(screen.getByRole('dialog', { name: 'Archives Visit' })).toBeTruthy();
  });

  it('writes What to Include, and asks for a repository’s slice', async () => {
    const asked: (string | null)[] = [];
    const stub = server({
      [`PATCH ${planPath}`]: plan({ deliverables: { includeLinks: true, includeTargets: true, includeInquiry: true, includeCitationCrib: true } }),
      [`${planPath}/packet`]: (url: URL) => {
        asked.push(url.searchParams.get('repository'));
        return packet({ repository: url.searchParams.get('repository') });
      },
    });
    const sheet = await openSheet();
    await userEvent.click(within(sheet).getByRole('checkbox', { name: 'Include NARA citation guidance' }));
    const patch = stub.mock.calls.find(([url, init]) => String(url).endsWith(planPath) && init?.method === 'PATCH');
    expect(sent(patch?.[1]).body).toEqual({ deliverables: { includeCitationCrib: true } });
    await userEvent.selectOptions(within(sheet).getByRole('combobox', { name: 'Repository' }), library);
    await waitFor(() => expect(asked).toContain(library));
  });

  it('copies a repository’s draft and says so', async () => {
    server();
    const writeText = vi.fn(async () => {});
    Object.defineProperty(navigator, 'clipboard', { value: { writeText }, configurable: true });
    const sheet = await openSheet();
    await userEvent.click(within(within(sheet).getByRole('group', { name: 'Copy inquiry draft' })).getByRole('button', { name: college }));
    expect(writeText).toHaveBeenCalledWith(packet().drafts[0]!.text);
    expect(await within(sheet).findByText(`Copied the inquiry draft for ${college}.`)).toBeTruthy();
  });

  it('saves the text it shows, for its day, and the PDF while the service answers', async () => {
    const saved: string[] = [];
    URL.createObjectURL = vi.fn(() => 'blob:packet');
    URL.revokeObjectURL = vi.fn();
    vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(function (this: HTMLAnchorElement) {
      saved.push(this.download);
    });
    const files: string[] = [];
    server({
      '/api/v1/pdf': { available: true },
      [`${planPath}/packet/file`]: (url: URL) => {
        files.push(url.search);
        const pdf = url.searchParams.get('format') === 'pdf';
        return new Response(pdf ? '%PDF-1.4' : packet().text, {
          headers: {
            'content-type': pdf ? 'application/pdf' : 'text/plain; charset=utf-8',
            'content-disposition': `attachment; filename="x"; filename*=UTF-8''Archives%20Visit%20%E2%80%94%20Berlin.${pdf ? 'pdf' : 'txt'}`,
          },
        });
      },
    });
    const sheet = await openSheet();
    await userEvent.click(within(sheet).getByRole('button', { name: 'Save as Text' }));
    await within(sheet).findByText('Saved Archives Visit — Berlin.txt.');
    await userEvent.click(await within(sheet).findByRole('button', { name: 'Save as PDF' }));
    await within(sheet).findByText('Saved Archives Visit — Berlin.pdf.');
    expect(files).toEqual(['?format=text&day=2026-11-25', '?format=pdf&day=2026-11-25']);
    expect(saved).toEqual(['Archives Visit — Berlin.txt', 'Archives Visit — Berlin.pdf']);
  });

  it('says why there is no packet', async () => {
    server({ [`${planPath}/packet`]: packet({ text: null, unavailable: 'indexUnavailable' }) });
    renderAt(`/visits/${planId}`);
    await userEvent.click(await screen.findByRole('button', { name: 'Export packet' }));
    const sheet = await screen.findByRole('dialog', { name: 'Archives Visit' });
    expect(await within(sheet).findByRole('heading', { name: 'The search index isn’t ready' })).toBeTruthy();
    expect(within(sheet).queryByRole('button', { name: 'Save as Text' })).toBeNull();
  });

  it('saves a topic the pause has not yet taken before Done closes', async () => {
    const stub = server({ [`PATCH ${planPath}`]: plan({ inquiryText: 'New topic' }) });
    const sheet = await openSheet();
    const topic = within(sheet).getByRole('textbox', { name: 'Inquiry topic sentence' });
    await userEvent.clear(topic);
    await userEvent.type(topic, 'New topic');
    await userEvent.click(within(sheet).getByRole('button', { name: 'Done' }));
    await waitFor(() => expect(screen.queryByRole('dialog', { name: 'Archives Visit' })).toBeNull());
    const patches = stub.mock.calls.filter(([url, init]) => String(url).endsWith(planPath) && init?.method === 'PATCH');
    expect(sent(patches.at(-1)?.[1]).body).toEqual({ inquiryText: 'New topic' });
  });
});

describe('the plan picker', () => {
  it('says what it adds, adds to the plan chosen, shows Added and closes', async () => {
    const stub = server({
      '/api/v1/volumes/frus1961-63v06/documents/d10/sources': sources(),
      '/api/v1/volumes/frus1961-63v06/documents/d10': { document: { displayTitle: '10. Letter' } },
      [`POST ${planPath}/documents`]: plan(),
    });
    renderAt('/sources/frus1961-63v06/d10');
    await userEvent.click(await screen.findByRole('button', { name: 'Add to Archives Visit' }));
    expect(screen.getAllByRole('menuitem').map((item) => item.textContent)).toEqual(['Add archival source', 'Add unprinted references (2)', 'Add both']);
    await userEvent.click(screen.getByRole('menuitem', { name: 'Add both' }));
    const picker = await screen.findByRole('dialog', { name: 'Add to Archives Visit' });
    expect(within(picker).getByText('Adding 1 document: archival sources + unprinted references — from Source Explorer')).toBeTruthy();
    const row = await within(picker).findByRole('button', { name: /Berlin/ });
    expect(row.textContent).toContain('1 document');
    await userEvent.click(row);
    await within(picker).findByText('Added');
    const added = stub.mock.calls.find(([url, init]) => String(url).endsWith(`${planPath}/documents`) && init?.method === 'POST');
    expect(sent(added?.[1]).body).toEqual({
      documents: [{ volumeId: 'frus1961-63v06', documentId: 'd10' }],
      includeSource: true,
      includeExternalRefs: true,
    });
    await waitFor(() => expect(screen.queryByRole('dialog', { name: 'Add to Archives Visit' })).toBeNull(), { timeout: 3000 });
  });

  it('offers the unprinted references from their own header for a document with no source note', async () => {
    server({
      '/api/v1/volumes/frus1961-63v06/documents/d10/sources': sources({ hasSourceNote: false, rawSourceNote: '' }),
      '/api/v1/volumes/frus1961-63v06/documents/d10': { document: { displayTitle: '10. Letter' } },
    });
    renderAt('/sources/frus1961-63v06/d10');
    const unprinted = await screen.findByRole('region', { name: 'Unprinted Material' });
    await userEvent.click(within(unprinted).getByRole('button', { name: 'Add to Archives Visit' }));
    expect(screen.getAllByRole('menuitem').map((item) => item.textContent)).toEqual(['Add unprinted references (2)']);
    expect(screen.getAllByRole('button', { name: 'Add to Archives Visit' })).toHaveLength(1);
  });

  it('makes a plan with its New row, and finds a plan by name', async () => {
    const stub = server({
      '/api/v1/volumes/frus1961-63v06/documents/d10/sources': sources({ unprinted: undefined }),
      '/api/v1/volumes/frus1961-63v06/documents/d10': { document: { displayTitle: '10. Letter' } },
      'POST /api/v1/me/visits': plan({ id: 'N1', name: '', displayName: 'Untitled Archives Visit' }),
    });
    renderAt('/sources/frus1961-63v06/d10');
    await userEvent.click(await screen.findByRole('button', { name: 'Add to Archives Visit' }));
    expect(screen.getAllByRole('menuitem').map((item) => item.textContent)).toEqual(['Add archival source']);
    await userEvent.click(screen.getByRole('menuitem', { name: 'Add archival source' }));
    const picker = await screen.findByRole('dialog', { name: 'Add to Archives Visit' });
    await within(picker).findByRole('button', { name: /Berlin/ });
    await userEvent.type(within(picker).getByRole('searchbox'), 'zurich');
    expect(within(picker).queryByRole('button', { name: /Berlin/ })).toBeNull();
    expect(within(picker).getByText('No Archives Visits match “zurich”.')).toBeTruthy();
    await userEvent.click(within(picker).getByRole('button', { name: 'New Archives Visit' }));
    await waitFor(() => expect(stub.mock.calls.some(([url, init]) => String(url).endsWith('/api/v1/me/visits') && init?.method === 'POST')).toBe(true));
    const made = stub.mock.calls.find(([url, init]) => String(url).endsWith('/api/v1/me/visits') && init?.method === 'POST');
    expect(sent(made?.[1]).body).toEqual({
      name: '',
      documents: [{ volumeId: 'frus1961-63v06', documentId: 'd10' }],
      includeSource: true,
      includeExternalRefs: false,
    });
  });
});

describe('the sheet’s and the picker’s rules', () => {
  it('reads the topic as the kit does', () => {
    expect(writtenTopic('  ')).toBeNull();
    expect(writtenTopic('A topic ')).toBe('A topic ');
    expect(sameTopicText(' A topic', 'A topic  ')).toBe(true);
    expect(sameTopicText('', '')).toBe(false);
    expect(showsSeededCaption('What did he want?', 'What did he want? ')).toBe(true);
    expect(showsSeededCaption('What did he want? Edited', 'What did he want?')).toBe(false);
    expect(topicIsUncommitted('  ', null)).toBe(false);
    expect(topicIsUncommitted('A topic ', 'A topic')).toBe(true);
  });

  it('says the banner by the halves an add turns on, and finds a plan by its name whatever its case', () => {
    expect(pickerBanner(12, true, false, 'the 12 neighbors shown')).toBe('Adding 12 documents: archival sources — the 12 neighbors shown');
    expect(pickerBanner(1, false, true, 'from Source Explorer')).toBe('Adding 1 document: unprinted references — from Source Explorer');
    expect(pickerBanner(2_400, true, true, 'from the collection “Letters”')).toBe(
      'Adding 2,400 documents: archival sources + unprinted references — from the collection “Letters”',
    );
    const item = { id: 'A', name: 'Zürich trip', displayName: 'Zürich trip', documentCount: 0, indexedDocumentCount: 0 };
    expect(planMatches(item, 'zürich')).toBe(true);
    expect(planMatches(item, 'berlin')).toBe(false);
  });
});

/** Source Explorer's answer for d10, a note with two footnotes pointing at unprinted material. */
function sources(fields: Record<string, unknown> = {}) {
  return {
    volumeId: 'frus1961-63v06',
    documentId: 'd10',
    documentTitle: '10. Letter',
    rawSourceNote: 'Source: Department of State, Presidential Correspondence: Lot 66 D 204.',
    hasSourceNote: true,
    parsed: { kind: 'lotFile', fields: {} },
    provenance: [],
    neighbours: { documents: [], totalCount: 0 },
    unprinted: {
      rows: [
        { id: 'f1', title: 'fn 1 · Lot 66 D 204', spokenTitle: 'Footnote 1, Lot 66 D 204', inherited: false, source: 'lotFile' },
        { id: 'f2', title: 'fn 2 · Ibid.', spokenTitle: 'Footnote 2, Ibid.', inherited: true, source: 'lotFile' },
      ],
      footer: 'Footnotes that point at material FRUS did not print.',
    },
    ...fields,
  };
}
