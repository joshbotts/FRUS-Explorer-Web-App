-- Schema of a FRUS Explorer research export: index version 65, FTS schema 4, app build 49.
-- Taken from the owner's export of 3 October 2026 (sqlite_master, in creation order).
-- Schema only: no rows. SQLite internals and FTS5 shadow tables are left out; FTS5 creates those.

CREATE TABLE cross_references (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_volume_id TEXT NOT NULL,
    source_document_id TEXT NOT NULL,
    target_volume_id TEXT,
    target_document_id TEXT NOT NULL,
    is_broken INTEGER NOT NULL DEFAULT 0
, reference_type TEXT, context TEXT);

CREATE TABLE page_ranges (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    volume_id TEXT NOT NULL,
    document_id TEXT NOT NULL,
    section_id TEXT NOT NULL,
    page_number_type TEXT NOT NULL,
    page_number_int INTEGER,
    page_number_raw TEXT NOT NULL,
    is_start INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE document_dates (
    volume_id TEXT NOT NULL,
    document_id TEXT NOT NULL,
    date_iso TEXT,
    date_iso_max TEXT,
    date_precision TEXT,
    date_certainty TEXT,
    PRIMARY KEY (volume_id, document_id)
);

CREATE TABLE document_cache (
    volume_id TEXT NOT NULL,
    document_id TEXT NOT NULL,
    document_number TEXT,
    header TEXT NOT NULL,
    dateline TEXT,
    source_note TEXT,
    body_text TEXT NOT NULL,
    subject_tag_ids TEXT,
    user_tag_ids TEXT,
    summary_text TEXT,
    note_text TEXT,
    is_editorial_note INTEGER NOT NULL DEFAULT 0,
    is_front_matter   INTEGER NOT NULL DEFAULT 0,
    despatch_serial   TEXT,
    PRIMARY KEY (volume_id, document_id)
);

CREATE TABLE document_revisions (
    volume_id     TEXT NOT NULL,
    document_id   TEXT NOT NULL,
    content_hash  TEXT NOT NULL,
    body_hash     TEXT NOT NULL,
    changed_at    TEXT,
    change_kind   TEXT,
    reviewed_at   TEXT,
    index_version INTEGER,
    PRIMARY KEY (volume_id, document_id)
);

CREATE TABLE user_tags (
    tag_id TEXT PRIMARY KEY,
    name TEXT NOT NULL
);

CREATE TABLE person_mentions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    volume_id TEXT NOT NULL,
    document_id TEXT NOT NULL,
    person_ref TEXT NOT NULL,
    UNIQUE(volume_id, document_id, person_ref) ON CONFLICT REPLACE
);

CREATE TABLE persons (
    volume_id    TEXT NOT NULL,
    ref          TEXT NOT NULL,
    name         TEXT NOT NULL,
    description  TEXT, role TEXT, start_year INTEGER, end_year INTEGER,
    PRIMARY KEY (volume_id, ref)
);

CREATE TABLE person_list_sources (
    volume_id        TEXT NOT NULL,
    source_volume_id TEXT NOT NULL,
    PRIMARY KEY (volume_id, source_volume_id)
);

CREATE TABLE person_rollup (
    rollup_id      INTEGER PRIMARY KEY,
    namekey        TEXT NOT NULL,
    canonical_name TEXT NOT NULL,
    description    TEXT,
    mention_count  INTEGER NOT NULL DEFAULT 0
, role TEXT, start_year INTEGER, end_year INTEGER, volume_count INTEGER NOT NULL DEFAULT 0, authority_id INTEGER, viaf_id TEXT);

CREATE TABLE person_rollup_member (
    volume_id TEXT NOT NULL,
    ref       TEXT NOT NULL,
    rollup_id INTEGER NOT NULL,
    PRIMARY KEY (volume_id, ref)
);

CREATE TABLE person_cluster_candidate (
    rollup_id_a INTEGER NOT NULL,
    rollup_id_b INTEGER NOT NULL,
    reason      TEXT,
    PRIMARY KEY (rollup_id_a, rollup_id_b)
);

CREATE TABLE terms (
    volume_id   TEXT NOT NULL,
    ref         TEXT NOT NULL,
    term        TEXT NOT NULL,
    definition  TEXT,
    PRIMARY KEY (volume_id, ref)
);

CREATE TABLE document_sources (
    volume_id      TEXT NOT NULL,
    document_id    TEXT NOT NULL,
    repository     TEXT,
    record_group   TEXT,
    lot_file       TEXT,
    lot_file_norm  TEXT,
    series_name    TEXT,
    citation_era   TEXT NOT NULL DEFAULT 'unrecognized',
    raw_text       TEXT NOT NULL,
    classification TEXT,
    decimal_class  TEXT,
    job_number_norm TEXT,
    PRIMARY KEY (volume_id, document_id)
);

CREATE TABLE external_citations (
    volume_id     TEXT NOT NULL,
    document_id   TEXT NOT NULL,
    note_ordinal  INTEGER NOT NULL,
    note_label    TEXT,
    citation_index INTEGER NOT NULL,
    anchor        TEXT NOT NULL,
    repository    TEXT,
    collection    TEXT,
    lot_file      TEXT,
    lot_file_norm TEXT,
    file_id       TEXT,
    inherited     INTEGER NOT NULL DEFAULT 0,
    raw_text      TEXT NOT NULL,
    decimal_class TEXT,
    PRIMARY KEY (volume_id, document_id, note_ordinal, citation_index)
);

CREATE TABLE document_subjects (
    volume_id   TEXT    NOT NULL,
    document_id TEXT    NOT NULL,
    bucket      INTEGER NOT NULL,
    PRIMARY KEY (volume_id, document_id, bucket)
) WITHOUT ROWID;

CREATE TABLE document_subject_refs (
    volume_id   TEXT    NOT NULL,
    document_id TEXT    NOT NULL,
    subject     INTEGER NOT NULL,
    PRIMARY KEY (volume_id, document_id, subject)
) WITHOUT ROWID;

CREATE TABLE document_subject_volumes (
    volume_id TEXT PRIMARY KEY,
    digest    TEXT NOT NULL
);

CREATE TABLE volume_sources (
    volume_id     TEXT NOT NULL,
    repository    TEXT,
    record_group  TEXT,
    lot_file      TEXT,
    lot_file_norm TEXT,
    series_name   TEXT,
    decimal_class TEXT,
    job_number    TEXT,
    job_number_norm TEXT,
    entry_text    TEXT NOT NULL,
    kind          TEXT NOT NULL DEFAULT 'item',
    depth         INTEGER NOT NULL DEFAULT 0,
    is_heading    INTEGER NOT NULL DEFAULT 0,
    sort_order    INTEGER NOT NULL DEFAULT 0,
    note          TEXT,
    PRIMARY KEY (volume_id, sort_order)
);

CREATE TABLE volume_structures (
    volume_id      TEXT PRIMARY KEY,
    structure_json TEXT NOT NULL
);

CREATE INDEX idx_crossref_source ON cross_references(source_volume_id, source_document_id);

CREATE INDEX idx_crossref_target ON cross_references(target_document_id);

CREATE INDEX idx_page_ranges_volume ON page_ranges(volume_id, page_number_type, page_number_int);

CREATE INDEX idx_page_ranges_document ON page_ranges(volume_id, document_id);

CREATE INDEX idx_doc_dates ON document_dates(date_iso);

CREATE INDEX idx_doc_dates_max ON document_dates(date_iso_max);

CREATE INDEX idx_document_revisions_changed
    ON document_revisions(volume_id, changed_at);

CREATE INDEX idx_person_mentions_ref ON person_mentions(person_ref);

CREATE INDEX idx_person_mentions_doc ON person_mentions(volume_id, document_id);

CREATE INDEX idx_document_cache_facet
ON document_cache(is_front_matter, is_editorial_note, volume_id, document_id);

CREATE INDEX idx_document_cache_note_text
ON document_cache(volume_id, document_id) WHERE note_text IS NOT NULL;

CREATE INDEX idx_persons_name ON persons(name);

CREATE INDEX idx_person_list_sources_source ON person_list_sources(source_volume_id);

CREATE INDEX idx_person_mentions_volref ON person_mentions(volume_id, person_ref);

CREATE INDEX idx_persons_namekey ON persons(lower(trim(name)));

CREATE INDEX idx_person_rollup_name ON person_rollup(canonical_name);

CREATE INDEX idx_person_rollup_member_rollup ON person_rollup_member(rollup_id);

CREATE INDEX idx_person_cluster_candidate_b ON person_cluster_candidate(rollup_id_b);

CREATE INDEX idx_terms_term ON terms(term);

CREATE INDEX idx_doc_src_rg ON document_sources(record_group);

CREATE INDEX idx_doc_src_repo ON document_sources(repository);

CREATE INDEX idx_doc_src_lot ON document_sources(lot_file);

CREATE INDEX idx_doc_src_job ON document_sources(job_number_norm);

CREATE INDEX idx_doc_src_era_series ON document_sources(citation_era, series_name);

CREATE INDEX idx_doc_src_lot_norm ON document_sources(lot_file_norm);

CREATE INDEX idx_doc_src_class ON document_sources(decimal_class);

CREATE INDEX idx_ext_cit_class ON external_citations(decimal_class);

CREATE INDEX idx_ext_cit_doc
ON external_citations(volume_id, document_id);

CREATE INDEX idx_ext_cit_lot_norm ON external_citations(lot_file_norm);

CREATE INDEX idx_ext_cit_repo_collection
ON external_citations(repository, collection);

CREATE INDEX idx_vol_src_rg ON volume_sources(volume_id, record_group);

CREATE INDEX idx_vol_src_lot_norm ON volume_sources(lot_file_norm);

CREATE VIRTUAL TABLE frus_documents USING fts5(
    document_id UNINDEXED,
    volume_id UNINDEXED,
    document_number UNINDEXED,
    header,
    dateline,
    source_note,
    body_text,
    subject_tag_ids UNINDEXED,
    user_tag_ids UNINDEXED,
    is_editorial_note UNINDEXED,
    content='document_cache', content_rowid='rowid', tokenize = 'porter unicode61'
);

CREATE VIRTUAL TABLE frus_documents_vocab USING fts5vocab('frus_documents', 'row');

CREATE VIRTUAL TABLE user_content USING fts5(
    document_id UNINDEXED,
    volume_id UNINDEXED,
    summary_text,
    note_text,
    content='document_cache', content_rowid='rowid', tokenize = 'porter unicode61'
);

CREATE TRIGGER document_cache_frus_documents_ai AFTER INSERT ON document_cache BEGIN
  INSERT INTO frus_documents(rowid, document_id, volume_id, document_number, header, dateline, source_note, body_text, subject_tag_ids, user_tag_ids, is_editorial_note) VALUES (new.rowid, new.document_id, new.volume_id, new.document_number, new.header, new.dateline, new.source_note, new.body_text, new.subject_tag_ids, new.user_tag_ids, new.is_editorial_note);
END;

CREATE TRIGGER document_cache_frus_documents_ad AFTER DELETE ON document_cache BEGIN
  INSERT INTO frus_documents(frus_documents, rowid, document_id, volume_id, document_number, header, dateline, source_note, body_text, subject_tag_ids, user_tag_ids, is_editorial_note) VALUES('delete', old.rowid, old.document_id, old.volume_id, old.document_number, old.header, old.dateline, old.source_note, old.body_text, old.subject_tag_ids, old.user_tag_ids, old.is_editorial_note);
END;

CREATE TRIGGER document_cache_frus_documents_au AFTER UPDATE OF header, dateline, source_note, body_text ON document_cache BEGIN
  INSERT INTO frus_documents(frus_documents, rowid, document_id, volume_id, document_number, header, dateline, source_note, body_text, subject_tag_ids, user_tag_ids, is_editorial_note) VALUES('delete', old.rowid, old.document_id, old.volume_id, old.document_number, old.header, old.dateline, old.source_note, old.body_text, old.subject_tag_ids, old.user_tag_ids, old.is_editorial_note);
  INSERT INTO frus_documents(rowid, document_id, volume_id, document_number, header, dateline, source_note, body_text, subject_tag_ids, user_tag_ids, is_editorial_note) VALUES (new.rowid, new.document_id, new.volume_id, new.document_number, new.header, new.dateline, new.source_note, new.body_text, new.subject_tag_ids, new.user_tag_ids, new.is_editorial_note);
END;

CREATE TRIGGER document_cache_user_content_ai AFTER INSERT ON document_cache BEGIN
  INSERT INTO user_content(rowid, document_id, volume_id, summary_text, note_text) VALUES (new.rowid, new.document_id, new.volume_id, new.summary_text, new.note_text);
END;

CREATE TRIGGER document_cache_user_content_ad AFTER DELETE ON document_cache BEGIN
  INSERT INTO user_content(user_content, rowid, document_id, volume_id, summary_text, note_text) VALUES('delete', old.rowid, old.document_id, old.volume_id, old.summary_text, old.note_text);
END;

CREATE TRIGGER document_cache_user_content_au AFTER UPDATE OF summary_text, note_text ON document_cache BEGIN
  INSERT INTO user_content(user_content, rowid, document_id, volume_id, summary_text, note_text) VALUES('delete', old.rowid, old.document_id, old.volume_id, old.summary_text, old.note_text);
  INSERT INTO user_content(rowid, document_id, volume_id, summary_text, note_text) VALUES (new.rowid, new.document_id, new.volume_id, new.summary_text, new.note_text);
END;

CREATE VIEW research_suppressed_volumes AS
SELECT DISTINCT later.volume_id AS volume_id
FROM document_cache AS later
WHERE later.volume_id GLOB '*Ed[0-9]'
  AND EXISTS (SELECT 1 FROM document_cache AS first_edition
              WHERE first_edition.volume_id =
                    substr(later.volume_id, 1, length(later.volume_id) - 3));

CREATE VIEW research_documents AS
SELECT volume_id, document_id, document_number, header, dateline,
       source_note, despatch_serial, body_text, user_tag_ids
FROM document_cache
WHERE is_front_matter = 0
  AND is_editorial_note = 0
  AND volume_id NOT IN (SELECT volume_id FROM research_suppressed_volumes);

CREATE VIEW research_cross_references AS
SELECT source_volume_id, source_document_id, target_volume_id, target_document_id,
       reference_type, context
FROM cross_references
WHERE is_broken = 0;

CREATE TABLE research_provenance (key TEXT PRIMARY KEY, value TEXT);

