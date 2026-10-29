// The export sheet (PLAN's S18e), the app's `ExportSheetView`: the sentence of what an export carries,
// the format grid, HTML, Word, BibTeX and RIS, and Export {Format}, which saves the file the server's
// exporter writes, the kit's; the quotation check, run as the sheet opens, warning without blocking,
// in orange when a quotation is not found, as the app's; and a refusal in red, in the app's words. The
// saved file's line, the word cloud's note and a smart collection's sentence are the web's own.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useId, useState } from 'react';
import { errorMessage } from '../api/client';
import { excerptCheckQuery, exportCollection, exportFormats, type CollectionDetail, type ExportFormat } from '../api/collections';
import { copy } from '../copy';
import { Modal } from '../shell/Modal';
import { saveFile } from '../shell/saveFile';
import { compositionSentence } from './exportRules';

const words = copy.collectionExport;

export function CollectionExportSheet({ detail, onClose }: { detail: CollectionDetail; onClose: () => void }) {
  const client = useQueryClient();
  const id = useId();
  const check = useQuery(excerptCheckQuery(detail.id));
  const [format, setFormat] = useState<ExportFormat>('html');
  const [exporting, setExporting] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const [saved, setSaved] = useState<string | null>(null);
  const smart = !detail.takesHandAddedEntries;
  // The app's Export is disabled for a collection with nothing in it.
  const unavailable = smart || detail.entries.length === 0;
  const label = words.grid[format]!.label;

  async function run() {
    if (unavailable || exporting) return;
    setExporting(true);
    setFailure(null);
    setSaved(null);
    try {
      const file = await exportCollection(client, detail.id, format);
      saveFile(file.blob, file.name);
      setSaved(file.name);
    } catch (error) {
      setFailure(errorMessage(error));
    } finally {
      setExporting(false);
    }
  }

  const summary = check.data?.summary;
  return (
    <Modal className="export-sheet" labelledBy={`${id}-title`} onCancel={onClose} onClose={onClose}>
      <h2 id={`${id}-title`} tabIndex={-1}>
        {words.title}
      </h2>
      <p>{compositionSentence(detail)}</p>
      {detail.includeWordCloud && <p className="note">{words.noWordCloud}</p>}
      {smart && <p className="note">{words.smart}</p>}
      <fieldset className="format-grid" disabled={smart}>
        <legend className="visually-hidden">{words.formats}</legend>
        {exportFormats.map((each) => (
          <label key={each} className={each === format ? 'format-card selected' : 'format-card'}>
            {/* Named as the app's card is, its title and its caption. */}
            <input
              type="radio"
              name={`${id}-format`}
              value={each}
              aria-label={`${words.grid[each]!.label}, ${words.grid[each]!.caption}`}
              checked={each === format}
              onChange={() => setFormat(each)}
            />
            <span className="format-label">{words.grid[each]!.label}</span>
            <span className="format-caption">{words.grid[each]!.caption}</span>
          </label>
        ))}
      </fieldset>
      {/* The quotation check: a statement about the work, above the error about this attempt. */}
      <div role="status">
        {summary && (
          <p className={check.data?.hasFailures ? 'excerpt-check warning' : 'excerpt-check'}>
            <span aria-hidden="true">{check.data?.hasFailures ? '⚠︎ ' : 'ⓘ '}</span>
            {summary}
          </p>
        )}
      </div>
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
      <p className="export-progress" role="status">
        {exporting ? words.exporting : saved ? `${words.complete}: ${saved}` : ''}
      </p>
      <div className="dialog-actions">
        <button type="button" onClick={onClose}>
          {words.close}
        </button>
        {/* aria-disabled, not disabled, so Export pressed by keyboard keeps its focus while the file is made. */}
        <button type="button" className="primary" aria-disabled={unavailable || exporting} onClick={() => void run()}>
          {words.exportFormat(label)}
        </button>
      </div>
    </Modal>
  );
}
