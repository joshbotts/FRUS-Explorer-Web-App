import { cleanup, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { VisitPlan, VisitPlanItem, VisitTarget } from '../api/visits';
import { ready, renderAt, stubServer } from '../test/renderRoute';
import { sent } from '../test/notes';
import { visitRowLine } from './VisitsScreen';

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

const me = { userId: 'owner', displayName: 'Owner', auth: 'none', roles: ['reader', 'curator', 'admin'], userData: true, csrfToken: 't' };
const planId = '5E30C000-0000-4000-8000-000000000001';

function item(fields: Partial<VisitPlanItem> & Pick<VisitPlanItem, 'id' | 'displayName'>): VisitPlanItem {
  return { name: fields.displayName, documentCount: 0, indexedDocumentCount: 0, ...fields };
}

function target(fields: Partial<VisitTarget> & Pick<VisitTarget, 'key' | 'label'>): VisitTarget {
  return {
    form: 'lotFile',
    drawnFrom: [
      {
        volumeId: 'frus1961-63v06',
        documentId: 'd10',
        citation: '_Foreign Relations of the United States_, 1961–1963, Volume VI, Document 10.',
        sourceNote: 'Source: Department of State, Presidential Correspondence: Lot 66 D 204.',
      },
    ],
    drawnFromCount: 1,
    pointedAt: [],
    pointedAtCount: 0,
    substitute: false,
    accessLines: [],
    lots: [],
    excluded: false,
    ...fields,
  };
}

function plan(fields: Partial<VisitPlan> = {}): VisitPlan {
  return {
    id: planId,
    name: 'Berlin',
    displayName: 'Berlin',
    inquiryText: 'What did Khrushchev want?',
    projectIds: ['P1'],
    project: { id: 'P1', name: 'Berlin crisis' },
    deliverables: { includeLinks: true, includeTargets: true, includeInquiry: true, includeCitationCrib: false },
    tiers: [{ id: 'T1', label: null, displayName: 'Priority 1', order: 0, members: 0 }],
    documentCount: 2,
    indexedDocumentCount: 2,
    served: true,
    summary: '2 targets across 1 repository.',
    sections: [
      {
        heading: 'National Archives at College Park',
        unplaced: false,
        links: [{ label: 'Visit planning', url: 'https://www.archives.gov/college-park' }],
        targets: [target({ key: 'lot|66D204', label: 'Files, Lot 66 D 204, RG 59, Department of State', recordsLine: 'RG 59 · Lot files · NAID 1' })],
      },
      {
        heading: 'Confirm before you travel',
        unplaced: true,
        links: [],
        targets: [target({ key: 'r|Source: Current Documents', label: 'Source: Current Documents', form: 'raw' })],
      },
    ],
    storedTargets: [
      { key: 'decimal|737.00/1-161', label: '737.00/1-161', kind: 'orphan', note: 'An orphan', excludedWhenOwn: false },
    ],
    documents: [
      {
        key: 'frus1961-63v06/d1',
        volumeId: 'frus1961-63v06',
        documentId: 'd1',
        header: '1. Telegram From the Embassy in the Soviet Union',
        volumeTitle: 'Kennedy-Khrushchev Exchanges',
        hasSourceNote: true,
        referenceCount: 0,
        includeSource: true,
        includeExternalRefs: true,
      },
      { key: 'frus1961-63v06/d10', includeSource: false, includeExternalRefs: false, hasSourceNote: false, referenceCount: 2 },
    ],
    sparsity: { withReferences: 12, indexed: 393 },
    ...fields,
  };
}

const server = (answers: Record<string, unknown> = {}) =>
  stubServer({ '/readyz': ready, '/api/v1/me': me, '/api/v1/me/visits': { total: 0, items: [] }, ...answers });

describe('the Archives Visits list', () => {
  it('lists each plan with the kit’s count or its documents’, the day it changed, and its amber coverage', async () => {
    const items = [
      item({ id: planId, displayName: 'Berlin', documentCount: 3, indexedDocumentCount: 2, summary: '2 targets · 1 repository', lastModified: '2026-11-25T12:00:00Z' }),
      item({ id: 'X', displayName: 'Untitled Archives Visit', name: '' }),
    ];
    expect(visitRowLine(items[0]!)).toBe('2 targets · 1 repository · Modified Nov 25, 2026');
    expect(visitRowLine(items[1]!)).toBe('0 documents');
    server({ '/api/v1/me/visits': { total: 2, items } });
    renderAt('/visits');
    const list = await screen.findByRole('list', { name: 'Archives Visits' });
    expect(within(list).getAllByRole('link').map((link) => link.textContent)).toEqual(['Berlin', 'Untitled Archives Visit']);
    expect(screen.getByText('2 of 3 documents indexed on this server').classList.contains('warning')).toBe(true);
    expect(screen.getByRole('navigation', { name: 'Research' }).textContent).toContain('Archives Visits');
  });

  it('makes a plan with New Archives Visit and opens its editor', async () => {
    const stub = server({ 'POST /api/v1/me/visits': plan({ name: '', displayName: 'Untitled Archives Visit', sections: [], documents: [] }), [`/api/v1/me/visits/${planId}`]: plan() });
    renderAt('/visits');
    await userEvent.click(await screen.findByRole('button', { name: 'New Archives Visit' }));
    await screen.findByRole('textbox', { name: 'Archive visit name' });
    const posted = stub.mock.calls.find(([url, init]) => String(url).endsWith('/api/v1/me/visits') && init?.method === 'POST');
    expect(sent(posted?.[1]).token).toBe('t');
  });
});

describe('an Archives Visit’s editor', () => {
  it('draws the sections in the server’s order with their links, each target’s lines, and the stored targets', async () => {
    server({ [`/api/v1/me/visits/${planId}`]: plan() });
    renderAt(`/visits/${planId}`);
    expect(await screen.findByRole('heading', { level: 2, name: 'National Archives at College Park' })).toBeTruthy();
    expect(screen.getAllByRole('heading', { level: 2 }).map((heading) => heading.textContent)).toEqual([
      'National Archives at College Park',
      'Confirm before you travel',
      'Stored targets',
    ]);
    expect(screen.getByRole('link', { name: 'Visit planning' }).getAttribute('href')).toBe('https://www.archives.gov/college-park');
    expect(screen.getByText('2 targets across 1 repository.')).toBeTruthy();
    expect(screen.getAllByText('drawn from 1 document')).toHaveLength(2);
    expect(screen.getByText('An orphan')).toBeTruthy();
    expect(screen.getByText(/^Stored target — no longer derives/)).toBeTruthy();
    // A target's seedings open under its label, the citation's series title in italics.
    const label = screen.getByRole('button', { name: 'Files, Lot 66 D 204, RG 59, Department of State' });
    expect(label.getAttribute('aria-expanded')).toBe('false');
    await userEvent.click(label);
    expect(label.getAttribute('aria-expanded')).toBe('true');
    expect(screen.getByText('Drawn from — 1 documents')).toBeTruthy();
    expect(screen.getAllByText('Foreign Relations of the United States')[0]?.tagName).toBe('EM');
  });

  it('writes a target’s tier, its note and its exclusion, each the server’s answer shown', async () => {
    const tiered = plan();
    tiered.sections[0]!.targets[0] = { ...tiered.sections[0]!.targets[0]!, tierId: 'T1', note: 'Box 4', excluded: true };
    const stub = server({ [`/api/v1/me/visits/${planId}`]: plan(), [`PATCH /api/v1/me/visits/${planId}/targets`]: tiered });
    renderAt(`/visits/${planId}`);
    await userEvent.click(await screen.findByRole('button', { name: 'Tier of Files, Lot 66 D 204, RG 59, Department of State: Set tier' }));
    await userEvent.click(screen.getByRole('menuitem', { name: 'Priority 1' }));
    await screen.findByRole('button', { name: 'Tier of Files, Lot 66 D 204, RG 59, Department of State: Priority 1' });
    const writes = () => stub.mock.calls.filter(([url, init]) => String(url).endsWith('/targets') && init?.method === 'PATCH').map(([, init]) => sent(init).body);
    expect(writes()).toEqual([{ key: 'lot|66D204', tierId: 'T1' }]);
    expect(screen.getByText('Excluded from the exported packet')).toBeTruthy();

    await userEvent.click(screen.getByRole('button', { name: 'Actions for Files, Lot 66 D 204, RG 59, Department of State' }));
    await userEvent.click(screen.getByRole('menuitem', { name: 'Edit Note…' }));
    const dialog = await screen.findByRole('dialog', { name: 'Target Note' });
    const field = within(dialog).getByRole('textbox', { name: 'Note' });
    expect((field as HTMLInputElement).value).toBe('Box 4');
    await userEvent.clear(field);
    await userEvent.type(field, 'Box 5{Enter}');
    await waitFor(() => expect(writes()).toContainEqual({ key: 'lot|66D204', note: 'Box 5' }));

    await userEvent.click(screen.getByRole('button', { name: 'Actions for Files, Lot 66 D 204, RG 59, Department of State' }));
    await userEvent.click(screen.getByRole('menuitem', { name: 'Include in Packet' }));
    await waitFor(() => expect(writes()).toContainEqual({ key: 'lot|66D204', included: true }));
  });

  it('narrows the list by its filters, and says so with a way to clear them', async () => {
    server({ [`/api/v1/me/visits/${planId}`]: plan() });
    renderAt(`/visits/${planId}`);
    await userEvent.selectOptions(await screen.findByRole('combobox', { name: 'Claim' }), 'Pointed at');
    expect(screen.getByText('No targets match the current filters.')).toBeTruthy();
    await userEvent.click(screen.getAllByRole('button', { name: 'Clear Filters' })[0]!);
    expect(screen.getByRole('heading', { level: 2, name: 'Confirm before you travel' })).toBeTruthy();
    await userEvent.selectOptions(screen.getByRole('combobox', { name: 'Repository' }), 'Confirm before you travel');
    expect(screen.queryByRole('heading', { level: 2, name: 'National Archives at College Park' })).toBeNull();
  });

  it('asks before Re-seed from Project replaces a topic, and writes the question on its yes', async () => {
    const stub = server({
      [`/api/v1/me/visits/${planId}`]: plan(),
      [`POST /api/v1/me/visits/${planId}/reseed`]: { topic: 'needsConfirmation', question: 'Why Vienna?', current: 'What did Khrushchev want?', added: 1, plan: plan() },
      [`PATCH /api/v1/me/visits/${planId}`]: plan({ inquiryText: 'Why Vienna?' }),
    });
    renderAt(`/visits/${planId}`);
    await userEvent.click(await screen.findByRole('button', { name: 'More' }));
    await userEvent.click(screen.getByRole('menuitem', { name: 'Re-seed from Project' }));
    const dialog = await screen.findByRole('alertdialog', { name: 'Replace the inquiry topic?' });
    expect(within(dialog).getByText('“Why Vienna?”')).toBeTruthy();
    expect(document.activeElement).toBe(within(dialog).getByRole('button', { name: 'Keep Current Topic' }));
    await userEvent.click(within(dialog).getByRole('button', { name: 'Replace Topic' }));
    await waitFor(() =>
      expect(stub.mock.calls.filter(([, init]) => init?.method === 'PATCH').map(([, init]) => sent(init).body)).toEqual([{ inquiryText: 'Why Vienna?' }]),
    );
  });

  it('offers no Re-seed from Project once the plan’s project is gone', async () => {
    server({ [`/api/v1/me/visits/${planId}`]: plan({ project: null }) });
    renderAt(`/visits/${planId}`);
    await userEvent.click(await screen.findByRole('button', { name: 'More' }));
    expect(screen.getAllByRole('menuitem').map((entry) => entry.textContent)).toEqual(['Priority Tiers…', 'Duplicate', 'Delete']);
  });

  it('lists the seeds with their two switches, or the caption where a half is absent', async () => {
    const stub = server({ [`/api/v1/me/visits/${planId}`]: plan(), [`PATCH /api/v1/me/visits/${planId}/documents`]: plan() });
    renderAt(`/visits/${planId}`);
    await userEvent.click(await screen.findByRole('radio', { name: 'Documents' }));
    const list = screen.getByRole('list', { name: 'Documents' });
    expect(within(list).getByText('1. Telegram From the Embassy in the Soviet Union')).toBeTruthy();
    expect(within(list).getByText('No unprinted references in this document’s footnotes')).toBeTruthy();
    expect(within(list).getByText('This document carries no source note')).toBeTruthy();
    expect(within(list).getByText('Contributes nothing to this plan')).toBeTruthy();
    await userEvent.click(within(list).getByRole('checkbox', { name: 'Unprinted references · 2' }));
    await waitFor(() =>
      expect(stub.mock.calls.filter(([, init]) => init?.method === 'PATCH').map(([, init]) => sent(init).body)).toEqual([
        { key: 'frus1961-63v06/d10', includeExternalRefs: true },
      ]),
    );
    expect(screen.getByText('On this server: 12 of 393 indexed documents carry such references.')).toBeTruthy();
  });

  it('adds a tier in the tiers’ sheet and moves one by a step', async () => {
    const two = plan({
      tiers: [
        { id: 'T1', label: null, displayName: 'Priority 1', order: 0, members: 0 },
        { id: 'T2', label: null, displayName: 'Priority 2', order: 1, members: 0 },
      ],
    });
    const stub = server({
      [`/api/v1/me/visits/${planId}`]: plan(),
      [`POST /api/v1/me/visits/${planId}/tiers`]: two,
      [`POST /api/v1/me/visits/${planId}/tiers/T2/move`]: two,
    });
    renderAt(`/visits/${planId}`);
    await userEvent.click(await screen.findByRole('button', { name: 'More' }));
    await userEvent.click(screen.getByRole('menuitem', { name: 'Priority Tiers…' }));
    const sheet = await screen.findByRole('dialog', { name: 'Priority Tiers' });
    await userEvent.click(within(sheet).getByRole('button', { name: 'Add a priority tier' }));
    await within(sheet).findByText('Priority 2');
    await userEvent.click(within(sheet).getByRole('button', { name: 'Actions for Priority 2' }));
    expect(within(sheet).getByRole('menuitem', { name: 'Move Down' }).getAttribute('aria-disabled')).toBe('true');
    await userEvent.click(within(sheet).getByRole('menuitem', { name: 'Move Up' }));
    await waitFor(() =>
      expect(stub.mock.calls.filter(([url]) => String(url).endsWith('/move')).map(([, init]) => sent(init).body)).toEqual([{ by: -1 }]),
    );
  });
});
