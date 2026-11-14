// The Source Explorer's three chips, as the app draws them: the classification marking in one quiet capsule
// (`ClassificationChip`), a confidence in the pre-1906 section's grammar, Likely or Possible (`ConfidenceChip`),
// and the provenance of a claim, its tier's glyph and the kit's label (`ProvenanceChip`). Each is said to a
// screen reader in the app's words.
import { copy } from '../copy';
import { provenanceGlyph } from './sourcesRules';

export function ClassificationChip({ marking }: { marking: string }) {
  return (
    <span className="se-chip se-classification" role="img" aria-label={copy.sources.classification(marking)}>
      {marking}
    </span>
  );
}

/** A confidence, its kit word (`CentralFilesConfidence.label`) and its level for the chip's tint. */
export function ConfidenceChip({ label = copy.sources.possible, level = 'medium' }: { label?: string; level?: 'high' | 'medium' }) {
  return (
    <span className={`se-chip se-confidence se-confidence-${level}`} role="img" aria-label={copy.sources.confidence(label)}>
      {label}
    </span>
  );
}

/** A claim's provenance (`ProvenanceSource`), by its case's name; nothing for a source the page does not know. */
export function ProvenanceChip({ source }: { source: string }) {
  const known = copy.sources.provenanceSources[source];
  if (!known) return null;
  return (
    <span className={`se-chip se-provenance se-provenance-${known.tier}`} role="img" aria-label={known.spoken}>
      <span aria-hidden="true">{provenanceGlyph(known.tier)} </span>
      {known.label}
    </span>
  );
}
