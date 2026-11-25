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
import { useQuery } from '@tanstack/react-query';
import { getRouteApi } from '@tanstack/react-router';
import { useEffect, useEffectEvent, useId, useMemo, useRef, useState } from 'react';
import type { AnalyticsContext } from '../api/analytics';
import { archivalContextQuery, type ArchivalScope } from '../api/archivalAnalytics';
import { errorMessage } from '../api/client';
import {
  bytesPerPoint,
  type SemanticMapPoint,
  type SemanticMapReadingContext,
  type SemanticMapRegions,
  semanticMapFlagsQuery,
  semanticMapLensQuery,
  semanticMapPick,
  semanticMapPointsQuery,
  semanticMapReadingQuery,
  semanticMapRegionsQuery,
  semanticMapRequest,
  semanticMapReveal,
  semanticMapScopeQuery,
} from '../api/semanticMap';
import { volumeScopesQuery } from '../api/searchSets';
import { meQuery } from '../api/userData';
import { copy } from '../copy';
import { useHeadingReady } from '../shell/headingFocus';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import { addressScope, type ScopeGroup, scopeFields, scopeGroups, scopeValue } from './analyticsRules';
import { Empty, ScopeOptions } from './CorpusAnalyticsScreen';
import { DataTable } from './PersonAnalyticsScreen';
import { type MapFocus, SemanticMap } from './SemanticMap';
import { NotOnMap, PointCard, RegionCard } from './SemanticMapCards';
import { supportsWebGL2 } from './semanticMapRenderer';
import { cameraFrom, type Rgba, type SemanticSearch, swatchColour } from './semanticMapRules';

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

/**
 * What the page shows beside the map: a region's card, a point's, or the notice for a document with no place; a point's
 * under the scope it was found in, since a scope drops the card of a point it may ghost, as the app's `setScope` drops
 * its selection.
 */
interface Cards {
  region?: number;
  point?: SemanticMapPoint;
  pointScope?: string;
  notOnMap?: string;
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
  const [focus, setFocus] = useState<MapFocus | undefined>(undefined);
  const focusSerial = useRef(0);
  const pointHeading = useRef<HTMLHeadingElement>(null);
  const wantsPointFocus = useRef(false);
  const point = cards.point && cards.pointScope === chosen ? cards.point : undefined;
  const scopeId = useId();
  const lensId = useId();
  const layout = answer?.layoutIdentity ?? reading.data?.layoutIdentity ?? '';
  const gridExtent = answer?.gridExtent ?? 30_000;

  function bring(camera: { x: number; y: number; halfExtent: number } | undefined) {
    if (!camera) return;
    focusSerial.current += 1;
    setFocus({ camera: cameraFrom(camera, gridExtent), serial: focusSerial.current });
  }

  // The map a link names, applied once a request: the document it reveals, or the region it focuses, as the app applies
  // a continuation after the map has loaded (`applyContinuedRequestIfNeeded`). A request the reader then moves away from
  // is not applied again until the address names another.
  const asked = search.document !== undefined || search.region !== undefined;
  const requestKey = `${search.document ?? ''}|${search.region ?? ''}|${search.layout ?? ''}`;
  const applyRequest = useEffectEvent((data: Awaited<ReturnType<typeof semanticMapRequest>>) => {
    if (data.reveal) {
      if (data.reveal.revealed && data.reveal.point) {
        setCards({ point: data.reveal.point, pointScope: chosen });
        bring(data.reveal.camera);
      } else {
        setCards({ notOnMap: data.reveal.volumeTitle });
      }
    } else if (data.focus?.focused) {
      setCards({ region: data.focus.region });
      bring(data.focus.camera);
    }
  });
  useEffect(() => {
    if (!asked || !whole) return;
    const controller = new AbortController();
    void semanticMapRequest({ scope, document: search.document, region: search.region, layout: search.layout }, controller.signal)
      .then(applyRequest)
      .catch((error: unknown) => {
        if (!controller.signal.aborted) console.warn(`Semantic map: ${errorMessage(error)}`);
      });
    return () => controller.abort();
  }, [asked, whole, requestKey]); // eslint-disable-line react-hooks/exhaustive-deps

  // A point shown from a region's card takes the focus, so that the keyboard is on its card.
  useEffect(() => {
    if (point && wantsPointFocus.current) {
      wantsPointFocus.current = false;
      pointHeading.current?.focus();
    }
  }, [point]);

  function change(fields: Partial<SemanticSearch>) {
    void navigate({ search: (previous) => ({ ...previous, ...fields }) });
  }

  async function pick(grid: [number, number], tolerance: number) {
    try {
      const found = await semanticMapPick(grid[0], grid[1], tolerance, scope);
      // A point's card replaces a region's, as the app's tap swaps them; a pick that finds nothing clears the point's card,
      // as a tap on empty map does, and leaves a region's.
      setCards((current) => (found ? { point: found, pointScope: chosen } : { region: current.region }));
    } catch (error) {
      console.warn(`Semantic map: ${errorMessage(error)}`);
    }
  }

  async function show(key: string) {
    try {
      const shown = await semanticMapReveal(key, scope);
      const reveal = shown.reveal;
      if (reveal?.revealed && reveal.point) {
        wantsPointFocus.current = true;
        setCards((current) => ({ region: current.region, point: reveal.point, pointScope: chosen }));
        bring(reveal.camera);
      } else if (reveal) {
        setCards((current) => ({ region: current.region, notOnMap: reveal.volumeTitle }));
      }
    } catch (error) {
      console.warn(`Semantic map: ${errorMessage(error)}`);
    }
  }

  function escape(): boolean {
    if (point || cards.notOnMap !== undefined) {
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
          </div>
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
              ) : points.error || slots.error ? (
                <Empty title={words.unavailableTitle} detail={errorMessage(points.error ?? slots.error)} />
              ) : !points.data || !drawn || !drawnLens ? (
                <p className="analytics-loading" role="status">
                  {words.loading}
                </p>
              ) : !whole ? (
                <Empty title={words.unavailableTitle} detail={words.unreadable} />
              ) : (
                <SemanticMap
                  points={points.data}
                  gridExtent={answer.gridExtent}
                  lens={drawn.id}
                  slots={drawn.slots}
                  palette={drawn.palette}
                  flags={ghost.flags}
                  scope={scope}
                  scopeKey={ghost.key}
                  regions={listed}
                  centres={centres}
                  selectedRegion={cards.region}
                  marker={point ? [point.x, point.y] : undefined}
                  focus={focus}
                  onRegion={(id) => setCards({ region: id })}
                  onPick={(grid, tolerance) => void pick(grid, tolerance)}
                  onEscape={escape}
                  onUnavailable={unavailable}
                />
              )}
              {drawable && whole && (
                <div className="semantic-cards">
                  {cards.notOnMap !== undefined && !point && (
                    <NotOnMap volumeTitle={cards.notOnMap} onDismiss={() => setCards((current) => ({ region: current.region }))} />
                  )}
                  {point && (
                    <PointCard point={point} headingRef={pointHeading} onDismiss={() => setCards((current) => ({ region: current.region }))} />
                  )}
                  {cards.region !== undefined && (
                    <RegionCard
                      key={`${cards.region}|${chosen}`}
                      region={cards.region}
                      layout={layout}
                      scope={scope}
                      scoped={scope !== undefined}
                      onDismiss={() => setCards((current) => ({ point: current.point, pointScope: current.pointScope, notOnMap: current.notOnMap }))}
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
              <p className="semantic-map-caveat">{words.caveat}</p>
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
