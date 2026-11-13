// S23e's done-when (docs/PLAN.md): Playwright reaches every node of the cross-reference graph by keyboard
// on Chromium with no axe violations. In the main suite, over the synthetic export, the reader's Graph opens
// the graph of frus1961-63v06's d2, which a document of a volume the server lacks cites, by the bundled
// index: the banner counts it, the keyboard reaches both nodes, and Enter shows the citer's details. With
// FRUS_E2E_GRAPH, on the smoke test's Standalone server, whose index holds the three fixture volumes, a graph
// at three hops, with its archival nodes, is walked node by node on the timeline and in the network, each
// node the keyboard reaches said by the kit's words and ringed on the canvas, and a date cluster expanded.
import type { Locator, Page } from '@playwright/test';
import { axeCheck } from './axe';
import { expect, test } from './fixtures';
import { backTabTo, tabTo } from './keyboard';

const standalone = !!process.env.FRUS_E2E_GRAPH;

interface Node {
  id: string;
  kind: string;
  label: string;
}

interface Graph {
  nodes: Node[];
  layout: string;
  timeline?: { visible: string[]; dateClusters: Node[]; positions: Record<string, unknown> };
}

/** The node the keyboard is on, as the list box says it. */
async function spoken(list: Locator): Promise<string | null> {
  const id = await list.getAttribute('aria-activedescendant');
  return id ? list.page().locator(`[id="${id}"]`).textContent() : null;
}

/**
 * Walks the canvas's nodes from the first to the last by the arrow keys, and gives what each said: every
 * option the list box holds, each once, in its order.
 */
async function walk(page: Page, list: Locator): Promise<string[]> {
  if (!(await list.evaluate((element) => element === document.activeElement))) await tabTo(page, list, 60);
  await page.keyboard.press('Home');
  const options = await list.getByRole('option').allTextContents();
  const heard: string[] = [];
  for (let step = 0; step < options.length; step++) {
    if (step > 0) await page.keyboard.press('ArrowDown');
    const said = await spoken(list);
    expect(said, `the node ${step + 1} of ${options.length}`).not.toBeNull();
    heard.push(said ?? '');
  }
  expect(heard).toEqual(options);
  // The walk stops at the last node.
  await page.keyboard.press('ArrowDown');
  expect(await spoken(list)).toBe(options[options.length - 1]);
  return heard;
}

/** The labels of the nodes a graph's answer draws, in no order. */
function drawnLabels(graph: Graph): string[] {
  if (!graph.timeline) return graph.nodes.map((node) => node.label).sort();
  const byId = new Map([...graph.nodes, ...graph.timeline.dateClusters].map((node) => [node.id, node]));
  return graph.timeline.visible
    .filter((id) => graph.timeline!.positions[id] !== undefined)
    .map((id) => byId.get(id)!.label)
    .sort();
}

test('opens the graph from the reader by keyboard, reaches its nodes, and shows a citer’s details', async ({ page }) => {
  test.skip(standalone, 'the Standalone server’s graph is the test below');
  await page.goto('doc/frus1961-63v06/d2');
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
  const tile = page.getByRole('group', { name: 'Document' }).getByRole('link', { name: 'Graph', exact: true });
  await tabTo(page, tile);
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/graph\/frus1961-63v06\/d2/);
  await expect(page.getByRole('heading', { level: 1, name: 'Cross-References' })).toBeFocused();
  // A document of a volume the server does not hold cites d2, by the bundled index, and the banner counts it.
  await expect(page.getByText('1 document in 1 volume this server does not hold also cites this one. It is shown without a title.')).toBeVisible();
  const list = page.getByRole('listbox', { name: 'Cross-reference graph' });
  await expect(list.getByRole('option')).toHaveCount(2);
  await expect(page.getByText('Drawing the graph…')).toHaveCount(0);
  await axeCheck(page);
  const heard = await walk(page, list);
  expect(heard[1]).toBe('Inbound: frus1961-63v05/d134');
  // Enter shows the citer's details: the server holds none of its volume, so it has no head and no Open.
  await page.keyboard.press('Enter');
  const details = page.getByRole('region', { name: 'frus1961-63v05/d134' });
  await expect(details.getByText('Not on this server')).toBeVisible();
  await expect(details.getByRole('button', { name: 'View Document' })).toBeDisabled();
  await expect(list).toBeFocused();
  await axeCheck(page);
  await page.keyboard.press('Escape');
  await expect(details).toHaveCount(0);
  // The reference list lists it, under the app's heading.
  await expect(page.getByRole('heading', { level: 3, name: 'Cites This Document' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Inbound: frus1961-63v05/d134' })).toBeVisible();
  // Two hops, by keyboard: the degree is kept in the address.
  const twoHops = page.getByRole('radio', { name: '2 hops' });
  // Back from the node list, past Reset view, to the depth's radios.
  await backTabTo(page, page.getByRole('radio', { name: '1 hop' }));
  await page.keyboard.press('ArrowRight');
  await expect(twoHops).toBeChecked();
  await expect(page).toHaveURL(/degree=2/);
  await expect(twoHops).toBeFocused();
  await expect(page.getByText('Drawing the graph…')).toHaveCount(0);
  await axeCheck(page);
});

test('walks every node of a graph at three hops by keyboard, on the timeline and in the network', async ({ page }) => {
  test.skip(!standalone, 'runs on the smoke test’s Standalone server, with FRUS_E2E_GRAPH');
  // Four axe passes and two walks over a graph of tens of nodes.
  test.setTimeout(120_000);
  const asked = (response: { url(): string }) => response.url().includes('/documents/d79/graph');
  const answered = page.waitForResponse(asked);
  await page.goto('graph/frus1961-63v06/d79?degree=3');
  const graph = (await (await answered).json()) as Graph;
  await expect(page.getByRole('heading', { level: 1, name: 'Cross-References' })).toBeVisible();
  const list = page.getByRole('listbox', { name: 'Cross-reference graph' });
  await expect(page.getByText('Drawing the graph…')).toHaveCount(0);
  expect(graph.layout).toBe('timeline');
  expect(graph.nodes.some((node) => node.kind === 'unit' || node.kind === 'centralFileClass'), 'an archival node').toBe(true);
  // Every node the timeline draws, and none other, each said by the kit's words.
  const onTimeline = await walk(page, list);
  expect([...onTimeline].sort()).toEqual(drawnLabels(graph));
  await axeCheck(page);

  // A date cluster, where the timeline gathers four or more, expands on Enter, and its documents are reached.
  const cluster = graph.timeline?.dateClusters[0];
  if (cluster) {
    await page.keyboard.press('Home');
    while ((await spoken(list)) !== cluster.label) await page.keyboard.press('ArrowDown');
    const expanded = page.waitForResponse(asked);
    await page.keyboard.press('Enter');
    await expanded;
    await expect(page).toHaveURL(/dates=datecluster/);
    await expect(page.getByText('Drawing the graph…')).toHaveCount(0);
    await expect(list.getByRole('option', { name: cluster.label, exact: true })).toHaveCount(0);
    await walk(page, list);
  }

  // The network, by keyboard: every node of the graph, the date clusters' documents among them.
  const network = page.getByRole('radio', { name: 'Network' });
  const relaid = page.waitForResponse(asked);
  await backTabTo(page, page.getByRole('radio', { name: 'Timeline' }));
  await page.keyboard.press('ArrowRight');
  const inNetwork = (await (await relaid).json()) as Graph;
  await expect(network).toBeChecked();
  await expect(page).toHaveURL(/layout=network/);
  await expect(page.getByText('Drawing the graph…')).toHaveCount(0);
  expect(inNetwork.timeline).toBeUndefined();
  const heard = await walk(page, list);
  expect([...heard].sort()).toEqual(drawnLabels(inNetwork));
  expect(heard.length).toBe(inNetwork.nodes.length);
  await axeCheck(page);

  // An archival node's details: its collection's name, and no document to open or recentre on.
  const archival = inNetwork.nodes.find((node) => node.kind === 'unit' || node.kind === 'centralFileClass')!;
  await page.keyboard.press('Home');
  while ((await spoken(list)) !== archival.label) await page.keyboard.press('ArrowDown');
  await page.keyboard.press('Enter');
  const details = page.locator('.graph-details');
  await expect(details.getByText(archival.kind === 'unit' ? 'Not printed' : 'Central file, not printed', { exact: true })).toBeVisible();
  await expect(details.getByRole('link', { name: 'Recenter' })).toHaveCount(0);
  await axeCheck(page);
});
