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

/** frus1961-63v06 as the catalogue names it, and its compilation's heading. */
export const v06Title = 'Foreign Relations of the United States, 1961–1963, Volume VI, Kennedy-Khrushchev Exchanges';
export const v06Compilation = 'Kennedy-Khrushchev Exchanges';

/** d2 as the synthetic export's index names it; its footnote names Document 1. */
export const d2Header = '2. Memorandum of Conversation';
export const d2Text = 'I am most appreciative of your courtesy in sending me a message';

/** p_KNS2, from frus1961-63v06's list of names (fixtures/tei/frus1961-63v06.xml). */
export const khrushchev = { name: 'Khrushchev, Nikita S.', description: 'Chairman of the Council of Ministers of the Soviet Union' };
