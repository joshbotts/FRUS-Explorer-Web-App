// What the suite expects of the synthetic export (scripts/synthetic-export) and fixtures/tei.

/** The two documents the synthetic export's index finds for "treaties", from its rows. */
export const treatiesResults = ['1. Telegram From the Embassy in the Soviet Union', '2. Memorandum of Conversation'];

/** A sentence of frus1961-63v06 d1's text, from its TEI. */
export const d1Text = 'Allow me to congratulate you on the occasion of your election';

/**
 * frus1961-63v06 d1 in Chicago style, as the kit's formatter writes it from the manifest's entry
 * for the volume. A pin move that changes the entry or the formatter changes this, as it would a
 * golden file; Tests/FRUSLightServerTests/CitationAndWebClientTests.swift holds the same text.
 */
export const d1Chicago =
  'Foreign Relations of the United States, 1961–1963, Volume VI, Kennedy-Khrushchev Exchanges, edited by Charles S. Sampson (Washington, D.C.: Government Printing Office, 1996), Document 1.';
