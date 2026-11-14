// A chart drawn by Vega-Lite (PLAN's S24f), loaded with the analytics pages rather than with the app, and the
// figure it exports, PNG or SVG, drawn in the browser. The app's policy runs no script it did not load and applies
// no style a page writes inline, so Vega runs as its expression interpreter (`ast`), adds no style sheet of its own
// and no actions menu, and shows a mark's values through its own title, the browser's tooltip.
import { useEffect, useEffectEvent, useRef } from 'react';
import embed, { type EmbedOptions, type Result, type VisualizationSpec } from 'vega-embed';
import type { ChartSpec } from './analyticsRules';

const options: EmbedOptions = {
  mode: 'vega-lite',
  renderer: 'svg',
  ast: true,
  actions: false,
  defaultStyle: false,
  tooltip: false,
};

/** A datum of the mark the reader chose, as its specification wrote it. */
export type ChartDatum = Record<string, unknown>;

export function VegaChart({
  spec,
  label,
  onChoose,
}: {
  spec: ChartSpec;
  /** What the chart is, for a screen reader, which reads its numbers in the table beside it. */
  label: string;
  /** A mark chosen with the pointer: a bar's datum, as the app's chart opens what a bar stands for. */
  onChoose?: (datum: ChartDatum) => void;
}) {
  const frame = useRef<HTMLDivElement>(null);
  const choose = useEffectEvent((datum: ChartDatum) => onChoose?.(datum));
  useEffect(() => {
    const element = frame.current;
    if (!element) return;
    let result: Result | undefined;
    let ended = false;
    embed(element, spec as VisualizationSpec, options)
      .then((made) => {
        if (ended) {
          made.finalize();
          return;
        }
        result = made;
        made.view.addEventListener('click', (_event, item) => {
          const datum = (item as { datum?: ChartDatum } | null | undefined)?.datum;
          if (datum) choose(datum);
        });
      })
      .catch(() => {
        // A chart that cannot be drawn leaves its table beside it, which holds every number.
      });
    return () => {
      ended = true;
      result?.finalize();
    };
  }, [spec]);
  // An image to a screen reader, named by the page: Vega's marks inside it are its presentation alone.
  return <div className="analytics-chart" ref={frame} role="img" aria-label={label} />;
}

/** A figure drawn apart from the page, at its own width, as a PNG twice its size or as SVG text. */
export async function renderFigure(spec: ChartSpec, format: 'png' | 'svg'): Promise<Blob> {
  const holder = document.createElement('div');
  const made = await embed(holder, spec as VisualizationSpec, options);
  try {
    if (format === 'svg') return new Blob([await made.view.toSVG()], { type: 'image/svg+xml' });
    const canvas = await made.view.toCanvas(2);
    return await new Promise<Blob>((resolve, reject) =>
      canvas.toBlob((blob) => (blob ? resolve(blob) : reject(new Error('The figure could not be rendered.'))), 'image/png'),
    );
  } finally {
    made.finalize();
  }
}
