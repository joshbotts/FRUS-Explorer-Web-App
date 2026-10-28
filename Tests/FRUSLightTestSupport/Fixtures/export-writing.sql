-- The owner's writing in a synthetic export made with Include My Notes, Summaries, and Tags on (PLAN's
-- S16e), over SyntheticExport's three documents: what the Mac's index keeps of it, by document its
-- newest summary, its notes joined into one block by a blank line (ResearchNote.indexedTextSeparator),
-- and the ids of the tags it carries, space-separated, and the name of every tag, one of them on no
-- document. The export schema's triggers index the summaries and the notes in user_content, as the
-- Mac's own writes do. SyntheticExport.includesWriting and scripts/synthetic-export --writing both
-- read this file, and stamp my_writing_included = 1. None of its text is in the corpus's.
UPDATE document_cache SET
    summary_text = 'Llewellyn Thompson reports from Moscow that the minister welcomed the treaty talks but would not fix a date for the Vienna meeting.',
    note_text = 'Ask the archivist whether the Vienna cables survive in the embassy files.' || char(10) || char(10)
        || 'Compare this account with the memoir before drafting chapter three.',
    user_tag_ids = '5C1E0001-7E4A-4B9C-9D2E-0A1B2C3D4E5F 5C1E0002-7E4A-4B9C-9D2E-0A1B2C3D4E5F'
WHERE volume_id = 'frus1961-63v06' AND document_id = 'd1';
UPDATE document_cache SET
    note_text = 'Quoted in the seminar paper; check the page break against the printed volume.',
    user_tag_ids = '5C1E0002-7E4A-4B9C-9D2E-0A1B2C3D4E5F'
WHERE volume_id = 'frus1961-63v06' AND document_id = 'd2';
UPDATE document_cache SET
    summary_text = '{"overview":"Minister Baker weighs the canal concession against British claims on the Mosquito Coast."}',
    user_tag_ids = '5C1E0001-7E4A-4B9C-9D2E-0A1B2C3D4E5F'
WHERE volume_id = 'frus1894Nicaragua' AND document_id = 'd1';
INSERT INTO user_tags (tag_id, name) VALUES
    ('5C1E0001-7E4A-4B9C-9D2E-0A1B2C3D4E5F', 'Berlin crisis chapter'),
    ('5C1E0002-7E4A-4B9C-9D2E-0A1B2C3D4E5F', 'Vienna summit follow-up'),
    ('5C1E0003-7E4A-4B9C-9D2E-0A1B2C3D4E5F', 'Unassigned research thread');
