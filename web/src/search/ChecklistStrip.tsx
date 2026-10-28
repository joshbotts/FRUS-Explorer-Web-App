// The strip Checklist Mode shows above the results while it is on (S17e), as the Mac's `ChecklistStrip`:
// how many results it hides, or that it hides none, then Undo and Mark Page Reviewed, always where they
// were, so that a reader working down a list presses Mark Page Reviewed again and again; Undo dimmed
// until there is a page mark to take back. Both act on a page, so under the timeline, which has none,
// both are dimmed. What each did is announced, as the Mac tells VoiceOver.
import { copy } from '../copy';

export function ChecklistStrip({
  hiddenCount,
  pageRowCount,
  canUndo,
  announcement,
  onMarkPage,
  onUndo,
}: {
  /** Results hidden as reviewed. */
  hiddenCount: number;
  /** Rows on the page now, which Mark Page Reviewed would hide: none under a reading that has no page. */
  pageRowCount: number;
  canUndo: boolean;
  /** What the last action did, for the live region. */
  announcement: string;
  onMarkPage: () => void;
  onUndo: () => void;
}) {
  return (
    <div className="checklist-strip" role="group" aria-label={copy.checklist.toggleName}>
      <span className="status">
        <span aria-hidden="true">☑ </span>
        {hiddenCount > 0 ? copy.checklist.hidden(hiddenCount) : copy.checklist.nothingHidden}
      </span>
      <span className="checklist-actions">
        <button type="button" title={copy.checklist.undoHelp} disabled={!canUndo} onClick={onUndo}>
          {copy.checklist.undo}
        </button>
        <button type="button" title={copy.checklist.markPageHelp} disabled={pageRowCount === 0} onClick={onMarkPage}>
          {copy.checklist.markPage}
        </button>
      </span>
      <span className="visually-hidden" role="status">
        {announcement}
      </span>
    </div>
  );
}
