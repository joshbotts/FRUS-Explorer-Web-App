// Semantic Analytics (PLAN's S28b, S28c), at /analytics/semantic, which the Mac's Analytics menu lists after Archival
// Analytics: the bundled semantic map, its 314,616 documents each where the layout put it, drawn by the web's own WebGL2
// renderer on the app's dark ground, with pan and zoom by pointer and keyboard and a fit to the whole (SemanticMap.tsx);
// and beside it the map's regions in a table, largest first, as the app's regions table ranks them, with the summary
// the app's accessibility list opens with. A browser without WebGL2 has the table and a sentence, and fetches no points;
// one whose WebGL2 fails as the map is made has the table and a sentence of its own, the reason in the console.
//
// Since S28c the map is read as the app's is: coloured by a lens the picker names (Regions, Era, On This Server, the
// app's Downloaded, and Provenance), each point's slot the server's, with the lens's key and caption; scoped by the
// scope bar's choices and the administrations, as Archival Analytics scopes, the points outside the scope ghosted; its
// regions named over it; a region's card and a point's, the app's (SemanticMapCards.tsx). The address is the kit's
// `SemanticMapRequest`: the lens, the scope, and the document a link reveals, as the reader's rail's On the Map does,
// or the region it focuses, against the layout it was named in. Every point, slot, name and card is the server's.
//
// Since S28e, the map's tools: with Lasso on, a drag draws a lasso, whose card says what it caught and saves it as a
// working corpus; a region's card saves its region the same way; a point's card sets the axis's poles, its volume as the
// low end or the high, and the two lay the corpus out as a slice, each point by its projection and its volume's year,
// which the address carries, both poles or neither, as the request does, until Back to the map; a point's card lists its
// nearest in language; and Export writes the regions' CSV with the kit's method block, or draws the figure as PNG with
// the kit's caption band, as the analytics' are. On a slice, a pick, a lasso and a document shown find their points
// among the slice's.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { getRouteApi } from '@tanstack/react-router';
import { useEffect, useEffectEvent, useId, useMemo, useRef, useState } from 'react';
import type { AnalyticsContext } from '../api/analytics';
import { archivalContextQuery, type ArchivalScope } from '../api/archivalAnalytics';
import { ApiError, errorMessage } from '../api/client';
import {
  bytesPerPoint,
  type LassoPath,
  type SemanticMapCameraAnswer,
  type SemanticMapLassoCapture,
  type SemanticMapPoint,
  type SemanticMapPoles,
  type SemanticMapReadingContext,
  type SemanticMapRegions,
  saveLassoCorpus,
  semanticMapCSV,
  semanticMapFigure,
  semanticMapFlagsQuery,
  semanticMapLasso,
  semanticMapLensQuery,
  semanticMapPick,
  semanticMapPointsQuery,
  semanticMapReadingQuery,
  semanticMapRegionsQuery,
  semanticMapRequest,
  semanticMapReveal,
  semanticMapScopeQuery,
  semanticMapSlicePick,
  semanticMapSlicePointsQuery,
  semanticMapSliceQuery,
} from '../api/semanticMap';
import { volumeScopesQuery } from '../api/searchSets';
import { meQuery } from '../api/userData';
import { copy } from '../copy';
import { useHeadingReady } from '../shell/headingFocus';
import { MenuButton } from '../shell/MenuButton';
import { saveFile } from '../shell/saveFile';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import { addressScope, type ScopeGroup, scopeFields, scopeGroups, scopeValue } from './analyticsRules';
import { Empty, ScopeOptions } from './CorpusAnalyticsScreen';
import { DataTable } from './PersonAnalyticsScreen';
import { type MapFocus, SemanticMap, type SliceScale } from './SemanticMap';
import { AxisCard, LassoCard, NotOnMap, PointCard, RegionCard } from './SemanticMapCards';
import { supportsWebGL2 } from './semanticMapRenderer';
import { cameraFrom, lassoPointLimit, type MapCamera, pointAt, type Rgba, type SemanticSearch, swatchColour, thinnedLasso } from './semanticMapRules';

const route = getRouteApi('/analytics/semantic');
const words = copy.semanticAnalytics;
const corpus = copy.corpusAnalytics;

/** The regions' table: largest first, ties by id, as the app's regions table and its labels rank them. */
export function regionRows(answer: SemanticMapRegions): string[][] {
  return [...answer.regions]
    .sort((a, b) => b.documentCount - a.documentCount || a.id - b.id)
    .map((region) => [String(region.id), region.terms.join(' '), region.documentCount.toLocaleString('en-US')]);
}

/** The scope the address names: the scope menu's, or a presidency's. */
function mapScope(search: SemanticSearch): ArchivalScope | undefined {
  if (search.administration) return { kind: 'administration', id: search.administration };
  return addressScope({
    subseries: search.subseries, volume: search.volume, topic: search.topic, subtopic: search.subtopic,
    volumes: search.volumes, scopeLabel: search.scopeLabel,
  });
}

function scopeKey(scope: ArchivalScope | undefined): string {
  return scope?.kind === 'administration' ? `administration:${scope.id}` : scopeValue(scope);
}

/**
 * The scope's choices over the series, as the app's map offers them (`scopeControls`): the analytics scope menu's, and
 * the administration menu's presidencies, one with no volume the map places disabled and saying so.
 */
function useMapScopes(reading: SemanticMapReadingContext | undefined): ScopeGroup[] {
  const context = useQuery(archivalContextQuery);
  const me = useQuery(meQuery);
  const scopes = useQuery({ ...volumeScopesQuery, enabled: me.data?.userData === true });
  return useMemo(() => {
    // A reader's volume scope is resolved against the series, as the bar resolves it against its population.
    const series = new Set(context.data?.seriesVolumeIds ?? []);
    const resolved = scopes.data?.items.map((scope) => ({ ...scope, indexedVolumeIds: scope.volumeIds.filter((id) => series.has(id)) }));
    const asContext = { subseries: context.data?.subseries ?? [], topics: context.data?.topics ?? [] } as AnalyticsContext;
    const groups = scopeGroups(asContext, resolved);
    const administrations = reading?.administrations ?? [];
    if (administrations.length > 0) {
      groups.push({
        label: copy.archivalAnalytics.administration,
        options: administrations.map((profile) =>
          profile.mappedVolumes > 0
            ? { value: `administration:${profile.id}`, label: profile.president }
            : { value: `none:administration:${profile.id}`, label: words.administrationNone(profile.president), disabled: true },
        ),
      });
    }
    return groups;
  }, [context.data, scopes.data, reading]);
}

/** A value of the scope menu as the address's fields: each of them set or cleared. */
function scopeSearch(value: string, groups: ScopeGroup[]): Partial<SemanticSearch> | undefined {
  const cleared = { subseries: undefined, volume: undefined, topic: undefined, subtopic: undefined, volumes: undefined, scopeLabel: undefined, administration: undefined };
  if (value.startsWith('administration:')) return { ...cleared, administration: value.slice('administration:'.length) };
  const option = groups.flatMap((group) => group.options).find((each) => each.value === value);
  if (!option || option.disabled) return undefined;
  return { ...cleared, ...scopeFields(option.scope) };
}

/** What the page shows beside the map: a region's card, a point's, and the notice for a document with no place. */
interface Cards {
  region?: number;
  point?: SemanticMapPoint;
  notOnMap?: string;
}

/** A lasso's capture, with the path, the scope and the slice it was drawn under, which its save draws again. */
interface Lassoed {
  serial: number;
  path: LassoPath;
  poles?: SemanticMapPoles;
  capture: SemanticMapLassoCapture;
}

/** The axis's poles as the page holds them: the low end, the high end, either set alone while the reader chooses. */
interface Poles {
  negative?: string;
  positive?: string;
}

export function SemanticAnalyticsScreen() {
  useDocumentTitle(words.title);
  const search = route.useSearch();
  const navigate = route.useNavigate();
  const regions = useQuery(semanticMapRegionsQuery);
  const reading = useQuery(semanticMapReadingQuery);
  useHeadingReady(!regions.isPending);
  const [webGL2] = useState(supportsWebGL2);
  const [failure, setFailure] = useState<string | undefined>(undefined);
  const drawable = webGL2 && failure === undefined;
  function unavailable(reason: string) {
    console.warn(`Semantic map: ${reason}`);
    setFailure(reason);
  }
  const points = useQuery({ ...semanticMapPointsQuery, enabled: drawable && regions.isSuccess });
  const answer = regions.data;
  const whole = answer !== undefined && points.data !== undefined && points.data.byteLength === answer.documentCount * bytesPerPoint;
  const client = useQueryClient();
  const me = useQuery(meQuery);
  const canSave = me.data?.userData === true;

  // The slice the address names, both poles or neither: its answer, and its points once it is laid out.
  const named: SemanticMapPoles | undefined = search.from !== undefined && search.to !== undefined ? { from: search.from, to: search.to } : undefined;
  const sliceAnswer = useQuery({ ...semanticMapSliceQuery(named ?? { from: '', to: '' }), enabled: named !== undefined && drawable });
  const sliceFor = named && sliceAnswer.data?.from === named.from && sliceAnswer.data.to === named.to ? sliceAnswer.data : undefined;
  const addressRefusal = sliceFor?.refusal;
  const laid = sliceFor && !sliceFor.refusal ? sliceFor : undefined;
  const slicePoints = useQuery({ ...semanticMapSlicePointsQuery(named ?? { from: '', to: '' }), enabled: laid !== undefined && whole });
  const sliceData = slicePoints.data;
  // The named slice, once its answer and its points have come.
  const ready =
    named && laid && sliceData && sliceData.poles.from === named.from && sliceData.poles.to === named.to && answer &&
    sliceData.points.byteLength === answer.documentCount * bytesPerPoint
      ? { poles: named, answer: laid, points: sliceData.points }
      : undefined;
  // A slice the address names that could not be laid out or read, which the axis's card says.
  const sliceFailure = named && !addressRefusal ? (sliceAnswer.error ?? slicePoints.error ?? undefined) : undefined;
  // The slice the address names is still being laid out, or its points are on their way.
  const laying = named !== undefined && !addressRefusal && !sliceFailure && !ready;
  // The last slice drawn stays while the next one comes, as the app's re-layout never shows the plane between two slices;
  // it goes with the address's slice, and is never drawn again once the map has been.
  const [kept, setKept] = useState<typeof ready>(undefined);
  if (ready && (ready.points !== kept?.points || ready.answer !== kept?.answer)) setKept(ready);
  if (!named && kept) setKept(undefined);
  const sliced = ready ?? (laying ? kept : undefined);
  // What is drawn: the slice's points and grid, or the map's.
  const drawnPoints = sliced?.points ?? points.data;
  const layoutKey = sliced ? `slice:${sliced.poles.from}|${sliced.poles.to}` : 'map';
  const sliceScale: SliceScale | undefined = sliced
    ? {
        from: sliced.poles.from,
        to: sliced.poles.to,
        ticks: sliced.answer.ticks ?? [],
        gutterY: sliced.answer.gutterY,
        undatedCount: sliced.answer.scale?.undatedCount ?? 0,
      }
    : undefined;
  // A link's request waits for the slice it names, which re-lays every point before a document is shown on it.
  const requestReady = whole && (named === undefined || !laying);

  // The lens: the address's, where this server draws it, or Regions, as the app falls back.
  const lenses = reading.data?.lenses ?? [];
  const lens = lenses.find((each) => each.id === search.lens) ?? lenses.find((each) => each.id === 'cluster');
  const slots = useQuery({ ...semanticMapLensQuery(lens?.id ?? 'cluster'), enabled: drawable && lens !== undefined });
  // What is drawn: a lens's slots with its own palette and key, the last lens's until the next lens's slots have come.
  const drawnLens = lenses.find((each) => each.id === slots.data?.lens);
  const drawn = drawnLens && slots.data && answer && slots.data.slots.length === answer.documentCount
    ? { id: drawnLens.id, slots: slots.data.slots, palette: drawnLens.palette as readonly Rgba[] }
    : undefined;

  // The scope: its facts and the regions the keyboard lists, and, under one, the mask that ghosts the rest.
  const scope = mapScope(search);
  const chosen = scopeKey(scope);
  const groups = useMapScopes(reading.data);
  const facts = useQuery(semanticMapScopeQuery(scope));
  const flags = useQuery({ ...semanticMapFlagsQuery(scope, chosen), enabled: drawable && scope !== undefined });
  // The ghost drawn: none for the whole series at once, and under a scope its mask, the last one's until its own has come.
  const ghost = scope === undefined ? { key: 'whole' } : flags.data ? { key: flags.data.key, flags: flags.data.flags } : { key: 'whole' };

  const [cards, setCards] = useState<Cards>({});
  const [lasso, setLasso] = useState<Lassoed | undefined>(undefined);
  const [lassoing, setLassoing] = useState(false);
  // A lasso's answer on its way, or why it did not come.
  const [gathering, setGathering] = useState<{ serial: number; failure?: string } | undefined>(undefined);
  // A scope drops the point's card and the notice, which may name a document it ghosts, as the app's `setScope` drops its
  // selection, and the lasso's capture, whose count a redraw under the scope would no longer give; the region's card
  // stays, its counts the scope's. The cards adjusted as the page draws, not after.
  const [cardsScope, setCardsScope] = useState(chosen);
  if (cardsScope !== chosen) {
    setCardsScope(chosen);
    setCards((current) => ({ region: current.region }));
    setLasso(undefined);
    setGathering(undefined);
  }
  const point = cards.point;

  // The axis's poles. The address's slice sets both; a refusal of them lets the high end go and says why, as the app's
  // second `setPole` would.
  const [poles, setPoles] = useState<Poles>(() => (named ? { negative: named.from, positive: named.to } : {}));
  const [notice, setNotice] = useState<string | undefined>(undefined);
  const namedKey = named ? `${named.from}|${named.to}` : '';
  const [namedSeen, setNamedSeen] = useState(namedKey);
  if (namedKey !== namedSeen) {
    setNamedSeen(namedKey);
    setPoles(named ? { negative: named.from, positive: named.to } : {});
    setNotice(undefined);
  }
  const [refusalSeen, setRefusalSeen] = useState<string | undefined>(undefined);
  if (named && addressRefusal && refusalSeen !== namedKey) {
    setRefusalSeen(namedKey);
    setPoles({ negative: named.from });
    setNotice(addressRefusal.notice);
  }
  const poleSerial = useRef(0);
  // The view on screen, as the map last drew it, which the figure is drawn through.
  const viewRef = useRef<{ camera: MapCamera; pixelHeight: number } | null>(null);
  const [exportFailure, setExportFailure] = useState<string | undefined>(undefined);
  const lassoSerial = useRef(0);
  const [focus, setFocus] = useState<MapFocus | undefined>(undefined);
  const focusSerial = useRef(0);
  const pointHeading = useRef<HTMLHeadingElement>(null);
  const keysRef = useRef<HTMLDivElement>(null);
  const cardsRef = useRef<HTMLDivElement>(null);
  const wantsPointFocus = useRef(false);
  // The document whose button in a region's card showed the point, where the keyboard goes back to when its card closes.
  const returnTo = useRef<string | undefined>(undefined);
  // Only the latest pick or show lands, and only under the scope it was asked in: a late answer is let go.
  const askSerial = useRef(0);
  const latestScope = useRef(chosen);
  useEffect(() => {
    latestScope.current = chosen;
  }, [chosen]);
  const scopeId = useId();
  const lensId = useId();
  const layout = answer?.layoutIdentity ?? reading.data?.layoutIdentity ?? '';
  const gridExtent = sliced?.answer.gridExtent ?? answer?.gridExtent ?? 30_000;
  // The layout a pick, a lasso or a document shown was asked on: a late answer for another is let go.
  const latestLayout = useRef(layoutKey);
  useEffect(() => {
    latestLayout.current = layoutKey;
  }, [layoutKey]);

  function bring(camera: { x: number; y: number; halfExtent: number } | undefined) {
    if (!camera) return;
    focusSerial.current += 1;
    setFocus({ camera: cameraFrom(camera, gridExtent), serial: focusSerial.current });
  }

  /**
   * A point the server placed on the map, at its place in what is drawn: on a slice, where the slice puts its row, the
   * camera brought there at the reveal's extent.
   */
  function placed(found: SemanticMapPoint, camera?: SemanticMapCameraAnswer): { point: SemanticMapPoint; camera?: SemanticMapCameraAnswer } {
    if (!sliced) return { point: found, camera };
    const at = pointAt(sliced.points, found.row);
    if (!at) return { point: found, camera };
    return { point: { ...found, x: at[0], y: at[1] }, camera: camera ? { x: at[0], y: at[1], halfExtent: camera.halfExtent } : undefined };
  }

  // The map a link names, applied once a request: the document it reveals, or the region it focuses, as the app applies
  // a continuation after the map has loaded (`applyContinuedRequestIfNeeded`). A request the reader then moves away from
  // is not applied again until the address names another.
  const asked = search.document !== undefined || search.region !== undefined;
  const requestKey = `${search.document ?? ''}|${search.region ?? ''}|${search.layout ?? ''}`;
  // Each request is applied once, though a slice laid out later makes the page ready again.
  const appliedRequest = useRef<string | undefined>(undefined);
  const applyRequest = useEffectEvent((data: Awaited<ReturnType<typeof semanticMapRequest>>) => {
    appliedRequest.current = requestKey;
    // A link's request goes before a pick still on its way.
    askSerial.current += 1;
    returnTo.current = undefined;
    if (data.reveal) {
      if (data.reveal.revealed && data.reveal.point) {
        const shown = placed(data.reveal.point, data.reveal.camera);
        setCards({ point: shown.point });
        bring(shown.camera);
      } else {
        // A reveal that fails leaves the cards the reader has, as the app's leaves its region's card.
        const volumeTitle = data.reveal.volumeTitle;
        setCards((current) => ({ ...current, notOnMap: volumeTitle }));
      }
    } else if (data.focus?.focused) {
      setCards({ region: data.focus.region });
      bring(data.focus.camera);
    }
  });
  useEffect(() => {
    if (!asked || !requestReady || appliedRequest.current === requestKey) return;
    const controller = new AbortController();
    void semanticMapRequest({ scope, document: search.document, region: search.region, layout: search.layout }, controller.signal)
      .then(applyRequest)
      .catch((error: unknown) => {
        if (!controller.signal.aborted) console.warn(`Semantic map: ${errorMessage(error)}`);
      });
    return () => controller.abort();
  }, [asked, requestReady, requestKey]); // eslint-disable-line react-hooks/exhaustive-deps

  // A point shown from a region's card takes the focus, so that the keyboard is on its card.
  useEffect(() => {
    if (!point) {
      wantsPointFocus.current = false;
    } else if (wantsPointFocus.current) {
      wantsPointFocus.current = false;
      pointHeading.current?.focus();
    }
  }, [point]);

  function change(fields: Partial<SemanticSearch>) {
    void navigate({ search: (previous) => ({ ...previous, ...fields }) });
  }

  async function pick(grid: [number, number], tolerance: number) {
    const serial = ++askSerial.current;
    const asked = chosen;
    const askedLayout = layoutKey;
    try {
      // On a slice, among the slice's points, as the app's hit test scans the positions on screen.
      const found = sliced
        ? await semanticMapSlicePick(grid[0], grid[1], tolerance, scope, sliced.poles)
        : await semanticMapPick(grid[0], grid[1], tolerance, scope);
      if (serial !== askSerial.current || asked !== latestScope.current || askedLayout !== latestLayout.current) return;
      returnTo.current = undefined;
      // A point's card stands beside a region's, as the app's tap leaves its region's card (`select(at:)`); a pick that
      // finds nothing clears the point's card, as a tap on empty map does, and leaves a region's.
      setCards((current) => (found ? { region: current.region, point: found } : { region: current.region }));
    } catch (error) {
      console.warn(`Semantic map: ${errorMessage(error)}`);
    }
  }

  async function show(key: string) {
    const serial = ++askSerial.current;
    const asked = chosen;
    const askedLayout = layoutKey;
    try {
      const shown = await semanticMapReveal(key, scope);
      if (serial !== askSerial.current || asked !== latestScope.current || askedLayout !== latestLayout.current) return;
      const reveal = shown.reveal;
      if (reveal?.revealed && reveal.point) {
        const at = placed(reveal.point, reveal.camera);
        returnTo.current = key;
        wantsPointFocus.current = true;
        setCards((current) => ({ region: current.region, point: at.point }));
        bring(at.camera);
      } else if (reveal) {
        setCards((current) => ({ region: current.region, notOnMap: reveal.volumeTitle }));
      }
    } catch (error) {
      console.warn(`Semantic map: ${errorMessage(error)}`);
    }
  }

  /**
   * Makes a document's volume one end of the axis (`setPole`): the low end, or the high one. With both set the server
   * lays the slice out, or refuses the pair in the app's words, which lets the end just set go, so that the reader's
   * earlier choice stands; a slice laid out goes in the address.
   */
  async function setPole(volume: string, positive: boolean) {
    const next: Poles = positive ? { ...poles, positive: volume } : { ...poles, negative: volume };
    const serial = ++poleSerial.current;
    setNotice(undefined);
    setPoles(next);
    if (next.negative === undefined || next.positive === undefined) return;
    try {
      const answer = await client.fetchQuery(semanticMapSliceQuery({ from: next.negative, to: next.positive }));
      if (serial !== poleSerial.current) return;
      if (answer.refusal) {
        setPoles(positive ? { negative: next.negative } : { positive: next.positive });
        setNotice(answer.refusal.notice);
        return;
      }
      change({ from: next.negative, to: next.positive });
    } catch (error) {
      if (serial === poleSerial.current) setNotice(errorMessage(error));
    }
  }

  /** Back to the map (`clearSlice`): the poles cleared, the map's own plane drawn again, and the keyboard on the map. */
  function clearSlice() {
    poleSerial.current += 1;
    setPoles({});
    setNotice(undefined);
    if (named) change({ from: undefined, to: undefined });
    keysRef.current?.focus();
  }

  /** What a lasso drawn on the grid encloses, among the points drawn, under the scope: its card, or none. */
  async function lassoed(drawnPath: [number, number][]) {
    const serial = ++lassoSerial.current;
    const asked = chosen;
    const askedLayout = layoutKey;
    const askedPoles = sliced?.poles;
    // A stroke longer than the server takes is thinned evenly to its length, which keeps its shape.
    const path = thinnedLasso(drawnPath, lassoPointLimit);
    setGathering({ serial });
    try {
      const found = await semanticMapLasso(path, scope, askedPoles);
      if (serial !== lassoSerial.current || asked !== latestScope.current || askedLayout !== latestLayout.current) return;
      setGathering(undefined);
      setLasso(found.capture ? { serial, path, poles: askedPoles, capture: found.capture } : undefined);
    } catch (error) {
      if (serial !== lassoSerial.current) return;
      setGathering({ serial, failure: errorMessage(error) });
    }
  }

  async function exportCSV() {
    setExportFailure(undefined);
    try {
      const file = await semanticMapCSV(scope, drawn?.id ?? 'cluster');
      saveFile(file.blob, file.name);
    } catch (error) {
      setExportFailure(errorMessage(error));
    }
  }

  /** The figure of the view on screen, its points drawn again at the plate's size under the kit's caption band. */
  async function exportFigure() {
    setExportFailure(undefined);
    const view = viewRef.current;
    if (!view || !drawnPoints || !drawn) return;
    const camera = view.camera;
    try {
      const [{ renderMapFigure }, figure] = await Promise.all([
        import('./semanticMapFigure'),
        semanticMapFigure(scope, drawn.id, { x: camera.centre[0], y: camera.centre[1], halfExtent: camera.halfExtent }, sliced?.poles),
      ]);
      const blob = await renderMapFigure({
        points: drawnPoints, slots: drawn.slots, palette: drawn.palette, flags: ghost.flags, camera, screenPixelHeight: view.pixelHeight, figure,
      });
      saveFile(blob, `${figure.plate.fileName}.png`);
    } catch (error) {
      setExportFailure(error instanceof ApiError ? errorMessage(error) : words.export.renderError);
    }
  }

  /** The keyboard's way back when a card closes: the document that showed the point, or the map's list box. */
  function returnFocus(toDocument: boolean) {
    const key = toDocument ? returnTo.current : undefined;
    returnTo.current = undefined;
    const button = key ? [...(cardsRef.current?.querySelectorAll<HTMLButtonElement>('button[data-key]') ?? [])].find((each) => each.dataset.key === key) : undefined;
    (button ?? keysRef.current)?.focus();
  }

  function dismissPoint() {
    returnFocus(true);
    setCards((current) => ({ region: current.region }));
  }

  function dismissRegion() {
    returnFocus(false);
    setCards((current) => ({ point: current.point, notOnMap: current.notOnMap }));
  }

  function dismissNotice() {
    returnFocus(false);
    setCards((current) => ({ region: current.region, point: current.point }));
  }

  // Escape in the map's list box closes the point's card or the notice, then the region's; the focus stays in the list.
  function escape(): boolean {
    if (point || cards.notOnMap !== undefined) {
      returnTo.current = undefined;
      setCards((current) => ({ region: current.region }));
      return true;
    }
    if (cards.region !== undefined) {
      setCards({});
      return true;
    }
    return false;
  }

  const centres = useMemo(
    () => new Map((answer?.regions ?? []).map((region) => [region.id, [region.centreX, region.centreY] as const])),
    [answer],
  );
  const listed = facts.data?.regions ?? [];
  const keyEntries = drawnLens ? (drawnLens.namesEveryColour ? drawnLens.legend : drawnLens.legend.slice(0, 1)) : [];
  const marker = point && drawnPoints ? (pointAt(drawnPoints, point.row) ?? [point.x, point.y]) : undefined;
  const axisShown = named !== undefined || poles.negative !== undefined || notice !== undefined;
  // What the axis's card says while a slice is drawn, laid out or refused.
  const axisNotice = notice ?? (sliceFailure ? errorMessage(sliceFailure) : undefined);

  return (
    <div className="analytics-page semantic-analytics">
      <h1 tabIndex={-1} data-loading={regions.isPending ? 'true' : undefined}>
        {words.title}
      </h1>
      {regions.error ? (
        <Empty title={words.unavailableTitle} detail={errorMessage(regions.error)} />
      ) : !answer ? (
        <p className="analytics-loading" role="status">
          {words.loading}
        </p>
      ) : (
        <>
          <div className="analytics-filters">
            <div className="analytics-field">
              <label htmlFor={scopeId}>{corpus.scope}</label>
              <select
                id={scopeId}
                value={chosen}
                onChange={(event) => {
                  const fields = scopeSearch(event.target.value, groups);
                  if (fields) change(fields);
                }}
              >
                {!groups.some((group) => group.options.some((option) => option.value === chosen)) && (
                  <option value={chosen}>{facts.data?.label ?? ''}</option>
                )}
                {groups.map((group, index) => (
                  <ScopeOptions key={`${group.label}-${index}`} group={group} />
                ))}
              </select>
            </div>
            {lenses.length > 0 && (
              <div className="analytics-field">
                <label htmlFor={lensId}>{words.colorBy}</label>
                <select id={lensId} value={lens?.id ?? 'cluster'} onChange={(event) => change({ lens: event.target.value === 'cluster' ? undefined : event.target.value })}>
                  {lenses.map((each) => (
                    <option key={each.id} value={each.id}>
                      {each.name}
                    </option>
                  ))}
                </select>
              </div>
            )}
            {drawable && (
              <div className="analytics-field semantic-map-tools">
                <button type="button" aria-pressed={lassoing} title={words.lasso.help}
                        onClick={() => {
                          // Off or on, the last lasso goes, and an answer still on its way with it, as the app's toggle
                          // clears its lasso at once.
                          lassoSerial.current += 1;
                          setLassoing((on) => !on);
                          setLasso(undefined);
                          setGathering(undefined);
                        }}>
                  {words.lasso.toggle}
                </button>
                <MenuButton
                  label={words.export.label}
                  accessibleLabel={words.export.accessibleLabel}
                  entries={[
                    { kind: 'item', label: words.export.csv, onSelect: () => void exportCSV(), disabled: !answer },
                    { kind: 'item', label: words.export.png, onSelect: () => void exportFigure(), disabled: !whole || !drawn },
                  ]}
                />
              </div>
            )}
          </div>
          {exportFailure && (
            <div className="analytics-alert" role="alert">
              <strong>{words.export.failed}</strong> {exportFailure}
            </div>
          )}
          {/* Said while a lasso's answer comes, in a region there before it; a failure is an alert. */}
          <p className="visually-hidden" role="status">
            {gathering && !gathering.failure ? words.lasso.gathering : ''}
          </p>
          {gathering?.failure && (
            <div className="analytics-alert" role="alert">
              <strong>{words.lasso.failed}</strong> {gathering.failure}
            </div>
          )}
          {facts.data?.summary && (
            <p className={facts.data.documentCount === 0 ? 'semantic-scope-summary is-empty' : 'semantic-scope-summary'}>{facts.data.summary}</p>
          )}
          {facts.error && (
            <div className="analytics-alert" role="alert">
              {errorMessage(facts.error)}
            </div>
          )}
          <div className="semantic-layout">
            <div className="semantic-map-column">
              {!drawable ? (
                <p className="semantic-map-unavailable">{webGL2 ? words.failed : words.noWebGL2}</p>
              ) : points.error || slots.error || reading.error ? (
                <Empty title={words.unavailableTitle} detail={errorMessage(points.error ?? slots.error ?? reading.error)} />
              ) : !drawnPoints || !drawn || !drawnLens ? (
                <p className="analytics-loading" role="status">
                  {words.loading}
                </p>
              ) : !whole ? (
                <Empty title={words.unavailableTitle} detail={words.unreadable} />
              ) : (
                <SemanticMap
                  points={drawnPoints}
                  gridExtent={gridExtent}
                  layoutKey={layoutKey}
                  names={!sliced}
                  slice={sliceScale}
                  lassoing={lassoing}
                  onLasso={(path) => void lassoed(path)}
                  viewRef={viewRef}
                  lens={drawn.id}
                  slots={drawn.slots}
                  palette={drawn.palette}
                  flags={ghost.flags}
                  scope={scope}
                  scopeKey={ghost.key}
                  regions={listed}
                  centres={centres}
                  selectedRegion={cards.region}
                  marker={marker}
                  focus={focus}
                  onRegion={(id) => {
                    returnTo.current = undefined;
                    setCards({ region: id });
                  }}
                  keysRef={keysRef}
                  onPick={(grid, tolerance) => void pick(grid, tolerance)}
                  onEscape={escape}
                  onUnavailable={unavailable}
                />
              )}
              {/* Said when it appears, in a region of its own that is there before it. */}
              <p className="visually-hidden" role="status">
                {cards.notOnMap !== undefined && !point ? words.notOnMap.title : ''}
              </p>
              {drawable && whole && (
                <div className="semantic-cards" ref={cardsRef}>
                  {axisShown && (
                    <AxisCard
                      slice={sliced?.poles}
                      scale={sliced?.answer.scale}
                      pole={sliced || laying || (named && !addressRefusal) ? undefined : (poles.negative ?? poles.positive)}
                      notice={axisNotice}
                      laying={laying}
                      onClear={clearSlice}
                    />
                  )}
                  {lasso && (
                    <LassoCard
                      key={lasso.serial}
                      capture={lasso.capture}
                      canSave={canSave}
                      onSave={() => saveLassoCorpus(client, lasso.path, scope, lasso.poles)}
                      onDismiss={() => {
                        setLasso(undefined);
                        keysRef.current?.focus();
                      }}
                    />
                  )}
                  {cards.notOnMap !== undefined && !point && <NotOnMap volumeTitle={cards.notOnMap} onDismiss={dismissNotice} />}
                  {point && (
                    <PointCard
                      point={point}
                      headingRef={pointHeading}
                      onDismiss={dismissPoint}
                      poles={{
                        sliced: sliced !== undefined,
                        canSetTo: poles.negative !== undefined,
                        onFrom: () => void setPole(point.volumeId, false),
                        onTo: () => void setPole(point.volumeId, true),
                      }}
                      onShow={(key) => void show(key)}
                    />
                  )}
                  {cards.region !== undefined && (
                    <RegionCard
                      key={`${cards.region}|${chosen}`}
                      region={cards.region}
                      layout={layout}
                      scope={scope}
                      scoped={scope !== undefined}
                      canSave={canSave}
                      onDismiss={dismissRegion}
                      onShow={(key) => void show(key)}
                    />
                  )}
                </div>
              )}
              {drawnLens && (
                <div className="semantic-map-legend">
                  {keyEntries.map((entry, slot) => (
                    <span key={entry} className="semantic-map-key">
                      <span className="semantic-map-swatch" aria-hidden="true">
                        <span style={{ background: swatchColour(drawnLens.palette, slot) }} />
                      </span>
                      {entry}
                    </span>
                  ))}
                  {drawnLens.caption && <p className="semantic-map-caption">{drawnLens.caption}</p>}
                </div>
              )}
              <p className="semantic-map-caveat">{sliced?.answer.caveat ?? words.caveat}</p>
            </div>
            <div className="semantic-regions">
              <p className="semantic-regions-summary">
                {words.summary(answer.regions.length, answer.documentCount - answer.unclusteredCount, answer.unclusteredCount)}
              </p>
              <DataTable
                table={{
                  title: words.table,
                  columns: [words.columns.region, words.columns.terms, words.columns.documents],
                  rows: regionRows(answer),
                }}
              />
            </div>
          </div>
        </>
      )}
    </div>
  );
}
