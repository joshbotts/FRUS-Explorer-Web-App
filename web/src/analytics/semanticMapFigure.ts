// The semantic map's figure (PLAN's S28e), as the app's `exportMapFigure` makes it and the analytics' figures are drawn
// here (`figureSpec`, `renderFigure`): the points drawn again, by the map's own renderer, into a plate of the app's
// rectangle at its twice-size raster (`AnalyticsFigureExporter.scale`), through the camera on screen, with the lens's
// colours and the scope's ghost; the regions' names over it, laid out by the kit for the plate on the server, none on a
// slice; and the kit's caption band around it, its title and facts above and its caveats, the attribution and the
// pointer to the CSV below. The plate is the app's dark map inset in the light figure, as the app's is.
import type { SemanticMapFigure } from '../api/semanticMap';
import { type ChartSpec, figureSpec } from './analyticsRules';
import { SemanticMapRenderer } from './semanticMapRenderer';
import type { MapCamera, Rgba } from './semanticMapRules';

/** The figure's raster scale: a plate of 1,144 points is drawn 2,288 pixels wide (`AnalyticsFigureExporter.scale`). */
export const figureScale = 2;

/** The plate as a chart of the figure: the drawn points as one image, and the names over them in the app's white. */
export function mapFigureChart(image: string, figure: SemanticMapFigure): ChartSpec {
  const place = {
    x: { field: 'x', type: 'quantitative', scale: null, axis: null },
    y: { field: 'y', type: 'quantitative', scale: null, axis: null },
    text: { field: 'text', type: 'nominal' },
  };
  const layers: ChartSpec[] = [
    {
      data: { values: [{}] },
      mark: { type: 'image', width: figure.width, height: figure.height, align: 'left', baseline: 'top' },
      encoding: { x: { value: 0 }, y: { value: 0 }, url: { value: image } },
    },
  ];
  if (figure.labels.length > 0) {
    // The app's two shadows, as a dark halo under the white names.
    layers.push(
      {
        data: { values: figure.labels },
        mark: { type: 'text', fontSize: 11, fontWeight: 500, color: '#000000', stroke: '#000000', strokeWidth: 3, opacity: 0.7 },
        encoding: place,
      },
      {
        data: { values: figure.labels },
        mark: { type: 'text', fontSize: 11, fontWeight: 500, color: '#ffffff' },
        encoding: place,
      },
    );
  }
  return { width: figure.width, height: figure.height, layer: layers };
}

/** The points drawn into the plate's raster, as a PNG's address, or a throw where the browser cannot draw them. */
export function drawPlate(
  draw: { points: ArrayBuffer; slots: Uint8Array; palette: readonly Rgba[]; flags?: Uint8Array; camera: MapCamera },
  figure: SemanticMapFigure,
): string {
  const canvas = document.createElement('canvas');
  canvas.width = figure.width * figureScale;
  canvas.height = figure.height * figureScale;
  const renderer = new SemanticMapRenderer(canvas, draw.palette);
  try {
    renderer.setPoints(draw.points);
    renderer.setLens(draw.slots, draw.palette);
    renderer.setScope(draw.flags);
    renderer.draw(draw.camera);
    // Read in the task that drew it, before the browser may clear a buffer it does not keep.
    return canvas.toDataURL('image/png');
  } finally {
    renderer.dispose();
    renderer.release();
  }
}

/** The whole figure as a PNG: the plate, its names and the kit's caption band. */
export async function renderMapFigure(
  draw: { points: ArrayBuffer; slots: Uint8Array; palette: readonly Rgba[]; flags?: Uint8Array; camera: MapCamera; figure: SemanticMapFigure },
): Promise<Blob> {
  const image = drawPlate(draw, draw.figure);
  const { renderFigure } = await import('./VegaChart');
  return renderFigure(figureSpec(mapFigureChart(image, draw.figure), draw.figure.plate, []), 'png');
}
