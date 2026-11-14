// The export sheet (PLAN's S18e), the app's `ExportSheetView`: the sentence of what an export carries,
// the format grid, HTML, Word, BibTeX, RIS and from S18f `.fruscollection`, which a smart collection's
// grid drops, and Export {Format}, which saves the file the server writes, the kit's; for the native
// file, the app's switch that includes the reader's notes, off until turned on, and what the file
// carries; the quotation check, run as the sheet opens, warning without blocking, in orange when a
// quotation is not found, as the app's; and a refusal in red, in the app's words. From S25a, PDF first,
// the app's choice as the sheet opens, while the server's PDF service answers, which the sheet asks
// before it shows the grid; without it the grid has no PDF and opens on HTML. The saved file's line and
// the word cloud's note are the web's own. From PLAN's S22e, Send to Zotero Library, the app's row under
// the grid: with the user's Zotero key it sends the collection's documents, else it saves the RIS file. Export
// and the row hold each other while either works, as the app's one `isExporting` holds both.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useId, useState } from 'react';
import { ApiError, errorMessage } from '../api/client';
import { excerptCheckQuery, exportCollection, type CollectionDetail, type ExportFormat } from '../api/collections';
import { sendCollectionToZotero } from '../api/nara';
import { secretsQuery } from '../api/secrets';
import { offersPdf, pdfServiceQuery } from '../api/pdf';
import { holdsZoteroKey, useZoteroKey, ZoteroSendRow } from '../cite/ZoteroSend';
import { copy } from '../copy';
import { Modal } from '../shell/Modal';
import { saveFile } from '../shell/saveFile';
import { Switch } from './CollectionSettings';
import { compositionSentence, gridFormats } from './exportRules';

const words = copy.collectionExport;

export function CollectionExportSheet({ detail, onClose }: { detail: CollectionDetail; onClose: () => void }) {
  const client = useQueryClient();
  const id = useId();
  const check = useQuery(excerptCheckQuery(detail.id));
  const smart = !detail.takesHandAddedEntries;
  // The grid waits for the server to say whether it makes PDFs, so that it opens as it will stay.
  const pdf = useQuery(pdfServiceQuery);
  const known = !pdf.isPending;
  const formats = gridFormats(smart, offersPdf(pdf.data));
  const [chosen, setFormat] = useState<ExportFormat | null>(null);
  // The app's sheet opens on PDF, the grid's first; without it, on HTML, the first then. A format the grid
  // no longer offers, as the native file once the collection is linked, is the first again.
  const format = chosen !== null && formats.includes(chosen) ? chosen : formats[0]!;
  // Once shown, the choice holds: an answer that comes later, the sheet's own ask after the editor's has
  // gone stale, changes the cards but not the format chosen, unless it takes that card away.
  if (known && chosen === null) setFormat(format);
  const [includeNotes, setIncludeNotes] = useState(false);
  const [exporting, setExporting] = useState(false);
  // The Zotero row's send, or the RIS file it saves, under way: Export waits for it, as the row waits for Export.
  const [zoteroWorking, setZoteroWorking] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);
  const [saved, setSaved] = useState<string | null>(null);
  const zoteroKey = useZoteroKey();
  // The app's Export is disabled for a collection with nothing in it that is not smart.
  const unavailable = detail.entries.length === 0 && !smart;
  const label = words.grid[format]!.label;

  /** `exportZoteroRIS()`: the collection as the file Zotero imports, saved; the row's way without a key, and after a failed send. */
  async function saveZoteroFile() {
    const file = await exportCollection(client, detail.id, 'zoteroJSON');
    saveFile(file.blob, file.name);
    setSaved(file.name);
  }

  /** The row's work, holding Export until it ends, however it ends. */
  async function holdingExport<T>(work: () => Promise<T>): Promise<T> {
    setZoteroWorking(true);
    try {
      return await work();
    } finally {
      setZoteroWorking(false);
    }
  }

  async function run() {
    if (unavailable || exporting || zoteroWorking || !known) return;
    setExporting(true);
    setFailure(null);
    setSaved(null);
    try {
      const file = await exportCollection(client, detail.id, format, includeNotes);
      saveFile(file.blob, file.name);
      setSaved(file.name);
    } catch (error) {
      setFailure(errorMessage(error));
      // A PDF service that has stopped answering is asked again, and the grid offers PDF no longer.
      if (error instanceof ApiError && error.code === 'PDF_SERVICE_UNAVAILABLE') void client.invalidateQueries({ queryKey: pdfServiceQuery.queryKey });
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
      <fieldset className="format-grid" aria-busy={!known || undefined}>
        <legend className="visually-hidden">{words.formats}</legend>
        {known &&
          formats.map((each) => (
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
      {format === 'fruscollection' && (
        <div className="native-options">
          <Switch label={words.includeNotes} detail={words.nativeHint} checked={includeNotes} onChange={setIncludeNotes} />
        </div>
      )}
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
      {/* `zoteroSendRow` under its header: the web API's send with a key, the RIS file without one (`sendToZotero()`). */}
      <h3 className="export-section">{copy.zotero.section}</h3>
      <ZoteroSendRow
        caption={zoteroKey ? copy.zotero.collectionCaption : copy.zotero.collectionCaptionNoAccount}
        disabled={unavailable || exporting}
        working={zoteroKey ? copy.zotero.sending : words.exporting}
        send={() =>
          holdingExport(async () => {
            setFailure(null);
            setSaved(null);
            // The key as it is now, the list read again: one added in another tab sends.
            const keys = await client.fetchQuery({ ...secretsQuery, staleTime: 0 });
            if (holdsZoteroKey(keys)) return await sendCollectionToZotero(client, detail.id);
            await saveZoteroFile();
            return null;
          })
        }
        recovery={() => holdingExport(saveZoteroFile)}
        message={(sent) =>
          sent.failedItems > 0
            ? `${copy.zotero.collectionResult(sent.addedItems, sent.addedNotes)} ${copy.zotero.failed(sent.failedItems)}`
            : copy.zotero.collectionResult(sent.addedItems, sent.addedNotes)
        }
      />
      <p className="export-progress" role="status">
        {exporting ? words.exporting : saved ? `${words.complete}: ${saved}` : ''}
      </p>
      <div className="dialog-actions">
        <button type="button" onClick={onClose}>
          {words.close}
        </button>
        {/* aria-disabled, not disabled, so Export pressed by keyboard keeps its focus while the file is made. */}
        <button type="button" className="primary" aria-disabled={unavailable || exporting || zoteroWorking || !known} onClick={() => void run()}>
          {words.exportFormat(label)}
        </button>
      </div>
    </Modal>
  );
}
