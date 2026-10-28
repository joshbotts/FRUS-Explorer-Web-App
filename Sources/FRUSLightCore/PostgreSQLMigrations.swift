// The PostgreSQL store's numbered, forward-only migrations (PLAN's S14d): app.db's, in PostgreSQL's SQL.

/// The statements of each migration of the PostgreSQL store, by the numbers app.db's carry: migration
/// n makes in PostgreSQL what `UserStoreMigrations.all[n - 1]` makes in app.db, so the two stores
/// hold the same tables at the same number, which the conformance suite checks against
/// `UserStoreSchema`. Each runs in a transaction of its own. Never edit one that has shipped: add
/// another beside app.db's.
///
/// A value is kept as app.db keeps it, so that one SQL text serves both stores: a text, a UUID, a date
/// or JSON as `TEXT` with the "C" collation, which orders and compares bytes as SQLite does; an
/// integer or a `Bool` as `BIGINT`, a `Bool` as 0 or 1; a real as `DOUBLE PRECISION`; bytes as
/// `BYTEA`. Each of the 23 tables carries `rowid`, the number SQLite gives a row, which the export
/// reads as the order the store took its rows in. `user_search` is not here: search reads FTS5, in
/// the store's local SQLite copy (`PostgreSQLUserStore`).
enum PostgreSQLMigrations {
    static let all: [[String]] = [one, two]

    /// S2's: the single user, and corrections as override rows.
    static let one = [
        """
        CREATE TABLE users (
            user_id TEXT COLLATE "C" PRIMARY KEY,
            display_name TEXT COLLATE "C" NOT NULL,
            created_at TEXT COLLATE "C" NOT NULL
        )
        """,
        """
        INSERT INTO users (user_id, display_name, created_at)
            VALUES ('owner', 'Owner', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))
        """,
        """
        CREATE TABLE index_corrections (
            rowid BIGINT GENERATED ALWAYS AS IDENTITY,
            volume_id TEXT COLLATE "C" NOT NULL,
            document_id TEXT COLLATE "C" NOT NULL,
            field TEXT COLLATE "C" NOT NULL,
            value TEXT COLLATE "C" NOT NULL,
            recorded_by TEXT COLLATE "C" NOT NULL REFERENCES users (user_id),
            recorded_at TEXT COLLATE "C" NOT NULL,
            PRIMARY KEY (volume_id, document_id, field)
        )
        """,
    ]

    /// S14a's: a table for each of the 23 model types, as `UserStoreSchema` describes them at
    /// `2767a128`, and the indexes their screens read them by. `index_corrections`' rows become
    /// classification overrides, as in app.db.
    static let two = [
        """
        CREATE TABLE notes (
            rowid BIGINT GENERATED ALWAYS AS IDENTITY,
            user_id TEXT COLLATE "C" NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT COLLATE "C" NOT NULL,
            document_id TEXT COLLATE "C" NOT NULL,
            volume_id TEXT COLLATE "C" NOT NULL,
            body_text TEXT COLLATE "C" NOT NULL,
            rich_text BYTEA,
            project_ids TEXT COLLATE "C" NOT NULL,
            user_tag_ids TEXT COLLATE "C" NOT NULL,
            selected_summary_ids TEXT COLLATE "C" NOT NULL,
            created_at TEXT COLLATE "C",
            last_modified TEXT COLLATE "C",
            PRIMARY KEY (user_id, id)
        )
        """,
        """
        CREATE TABLE highlights (
            rowid BIGINT GENERATED ALWAYS AS IDENTITY,
            user_id TEXT COLLATE "C" NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT COLLATE "C" NOT NULL,
            volume_id TEXT COLLATE "C" NOT NULL,
            document_id TEXT COLLATE "C" NOT NULL,
            start_offset BIGINT NOT NULL,
            end_offset BIGINT NOT NULL,
            color_tag TEXT COLLATE "C" NOT NULL,
            note_id TEXT COLLATE "C",
            selected_text TEXT COLLATE "C" NOT NULL,
            rendering_version TEXT COLLATE "C" NOT NULL,
            created_at TEXT COLLATE "C",
            PRIMARY KEY (user_id, id)
        )
        """,
        """
        CREATE TABLE tags (
            rowid BIGINT GENERATED ALWAYS AS IDENTITY,
            user_id TEXT COLLATE "C" NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT COLLATE "C" NOT NULL,
            name TEXT COLLATE "C" NOT NULL,
            created_at TEXT COLLATE "C",
            last_modified TEXT COLLATE "C",
            PRIMARY KEY (user_id, id)
        )
        """,
        """
        CREATE TABLE tag_assignments (
            rowid BIGINT GENERATED ALWAYS AS IDENTITY,
            user_id TEXT COLLATE "C" NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT COLLATE "C" NOT NULL,
            volume_id TEXT COLLATE "C" NOT NULL,
            document_id TEXT COLLATE "C" NOT NULL,
            tag_id TEXT COLLATE "C" NOT NULL,
            created_at TEXT COLLATE "C",
            PRIMARY KEY (user_id, id)
        )
        """,
        """
        CREATE TABLE collections (
            rowid BIGINT GENERATED ALWAYS AS IDENTITY,
            user_id TEXT COLLATE "C" NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT COLLATE "C" NOT NULL,
            name TEXT COLLATE "C" NOT NULL,
            note TEXT COLLATE "C",
            subtitle TEXT COLLATE "C",
            author_line TEXT COLLATE "C",
            introduction_text TEXT COLLATE "C",
            introduction_rich_text BYTEA,
            include_colophon BIGINT NOT NULL,
            include_project_provenance BIGINT NOT NULL,
            include_method_appendix BIGINT NOT NULL,
            project_ids TEXT COLLATE "C" NOT NULL,
            saved_search_id TEXT COLLATE "C",
            default_body_depth TEXT COLLATE "C" NOT NULL,
            footnote_style TEXT COLLATE "C" NOT NULL,
            include_footnotes BIGINT,
            include_source_note BIGINT,
            toc_style TEXT COLLATE "C" NOT NULL,
            apply_highlights BIGINT NOT NULL,
            include_notes BIGINT NOT NULL,
            include_word_cloud BIGINT NOT NULL,
            default_include_headnote BIGINT NOT NULL,
            summary_prompt_id TEXT COLLATE "C",
            created_at TEXT COLLATE "C",
            last_modified TEXT COLLATE "C",
            PRIMARY KEY (user_id, id)
        )
        """,
        """
        CREATE TABLE collection_entries (
            rowid BIGINT GENERATED ALWAYS AS IDENTITY,
            user_id TEXT COLLATE "C" NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT COLLATE "C" NOT NULL,
            collection_id TEXT COLLATE "C" NOT NULL,
            document_id TEXT COLLATE "C" NOT NULL,
            volume_id TEXT COLLATE "C" NOT NULL,
            title_override TEXT COLLATE "C",
            sort_order BIGINT NOT NULL,
            level BIGINT NOT NULL,
            research_note_id TEXT COLLATE "C",
            selected_note_ids TEXT COLLATE "C" NOT NULL,
            body_depth_override TEXT COLLATE "C",
            apply_highlights_override BIGINT,
            include_notes_override BIGINT,
            include_source_note_override BIGINT,
            include_footnotes_override BIGINT,
            summary_prompt_id_override TEXT COLLATE "C",
            selected_highlight_ids TEXT COLLATE "C" NOT NULL,
            include_related_documents BIGINT,
            include_headnote BIGINT,
            headnote_summary_id TEXT COLLATE "C",
            excerpt_start BIGINT,
            excerpt_end BIGINT,
            excerpt_rendering_version TEXT COLLATE "C",
            excerpt_color_tag TEXT COLLATE "C",
            kind TEXT COLLATE "C" NOT NULL,
            generated_block_type TEXT COLLATE "C",
            text TEXT COLLATE "C",
            rich_text BYTEA,
            created_at TEXT COLLATE "C",
            last_modified TEXT COLLATE "C",
            PRIMARY KEY (user_id, id)
        )
        """,
        """
        CREATE TABLE projects (
            rowid BIGINT GENERATED ALWAYS AS IDENTITY,
            user_id TEXT COLLATE "C" NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT COLLATE "C" NOT NULL,
            name TEXT COLLATE "C" NOT NULL,
            research_question TEXT COLLATE "C",
            default_date_range_start TEXT COLLATE "C",
            default_date_range_end TEXT COLLATE "C",
            default_subject_tag_ids TEXT COLLATE "C" NOT NULL,
            default_country_tag_ids TEXT COLLATE "C" NOT NULL,
            lead_axis_weights TEXT COLLATE "C",
            default_user_tag_ids TEXT COLLATE "C" NOT NULL,
            created_at TEXT COLLATE "C",
            last_modified TEXT COLLATE "C",
            PRIMARY KEY (user_id, id)
        )
        """,
        """
        CREATE TABLE project_leads (
            rowid BIGINT GENERATED ALWAYS AS IDENTITY,
            user_id TEXT COLLATE "C" NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT COLLATE "C" NOT NULL,
            project_id TEXT COLLATE "C" NOT NULL,
            volume_id TEXT COLLATE "C" NOT NULL,
            document_id TEXT COLLATE "C" NOT NULL,
            aggregate_score DOUBLE PRECISION NOT NULL,
            contributing_seed_keys TEXT COLLATE "C" NOT NULL,
            header TEXT COLLATE "C" NOT NULL,
            document_number TEXT COLLATE "C",
            is_editorial_note BIGINT NOT NULL,
            first_surfaced_at TEXT COLLATE "C" NOT NULL,
            last_computed_at TEXT COLLATE "C" NOT NULL,
            dismissed BIGINT NOT NULL,
            PRIMARY KEY (user_id, id)
        )
        """,
        """
        CREATE TABLE saved_searches (
            rowid BIGINT GENERATED ALWAYS AS IDENTITY,
            user_id TEXT COLLATE "C" NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT COLLATE "C" NOT NULL,
            name TEXT COLLATE "C" NOT NULL,
            query_text TEXT COLLATE "C" NOT NULL,
            phrase_text TEXT COLLATE "C" NOT NULL,
            prefix_wildcard TEXT COLLATE "C" NOT NULL,
            boolean_mode_raw TEXT COLLATE "C" NOT NULL,
            excluded_terms_csv TEXT COLLATE "C" NOT NULL,
            scope_flags BIGINT NOT NULL,
            date_range_start TEXT COLLATE "C",
            date_range_end TEXT COLLATE "C",
            subject_tag_ids_csv TEXT COLLATE "C" NOT NULL,
            document_type_filter_raw TEXT COLLATE "C" NOT NULL,
            person_ref TEXT COLLATE "C" NOT NULL,
            sort_order TEXT COLLATE "C" NOT NULL,
            created_at TEXT COLLATE "C",
            last_modified TEXT COLLATE "C",
            parameters_data TEXT COLLATE "C",
            freshness_data TEXT COLLATE "C",
            PRIMARY KEY (user_id, id)
        )
        """,
        """
        CREATE TABLE working_corpora (
            rowid BIGINT GENERATED ALWAYS AS IDENTITY,
            user_id TEXT COLLATE "C" NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT COLLATE "C" NOT NULL,
            name TEXT COLLATE "C" NOT NULL,
            document_keys TEXT COLLATE "C" NOT NULL,
            captured_at TEXT COLLATE "C",
            source_query TEXT COLLATE "C",
            source_description TEXT COLLATE "C",
            indexed_volume_count_at_capture BIGINT,
            was_truncated_at_capture BIGINT,
            total_match_count_at_capture BIGINT,
            created_at TEXT COLLATE "C",
            last_modified TEXT COLLATE "C",
            PRIMARY KEY (user_id, id)
        )
        """,
        """
        CREATE TABLE volume_scopes (
            rowid BIGINT GENERATED ALWAYS AS IDENTITY,
            user_id TEXT COLLATE "C" NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT COLLATE "C" NOT NULL,
            name TEXT COLLATE "C" NOT NULL,
            volume_ids TEXT COLLATE "C" NOT NULL,
            created_at TEXT COLLATE "C",
            last_modified TEXT COLLATE "C",
            PRIMARY KEY (user_id, id)
        )
        """,
        """
        CREATE TABLE trail_reading (
            rowid BIGINT GENERATED ALWAYS AS IDENTITY,
            user_id TEXT COLLATE "C" NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT COLLATE "C" NOT NULL,
            document_id TEXT COLLATE "C" NOT NULL,
            volume_id TEXT COLLATE "C" NOT NULL,
            display_title TEXT COLLATE "C",
            project_id TEXT COLLATE "C",
            accessed_at TEXT COLLATE "C",
            PRIMARY KEY (user_id, id)
        )
        """,
        """
        CREATE TABLE trail_search (
            rowid BIGINT GENERATED ALWAYS AS IDENTITY,
            user_id TEXT COLLATE "C" NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT COLLATE "C" NOT NULL,
            query_text TEXT COLLATE "C" NOT NULL,
            result_count BIGINT NOT NULL,
            project_id TEXT COLLATE "C",
            executed_at TEXT COLLATE "C",
            loaded_count BIGINT,
            match_count BIGINT,
            fetch_limit BIGINT,
            indexed_volume_count BIGINT,
            scope_signature TEXT COLLATE "C",
            applied_corpus_id TEXT COLLATE "C",
            rendered_expression TEXT COLLATE "C",
            PRIMARY KEY (user_id, id)
        )
        """,
        """
        CREATE TABLE trail_export (
            rowid BIGINT GENERATED ALWAYS AS IDENTITY,
            user_id TEXT COLLATE "C" NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT COLLATE "C" NOT NULL,
            format TEXT COLLATE "C" NOT NULL,
            document_count BIGINT NOT NULL,
            collection_name TEXT COLLATE "C",
            project_id TEXT COLLATE "C",
            exported_at TEXT COLLATE "C",
            PRIMARY KEY (user_id, id)
        )
        """,
        """
        CREATE TABLE visit_plans (
            rowid BIGINT GENERATED ALWAYS AS IDENTITY,
            user_id TEXT COLLATE "C" NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT COLLATE "C" NOT NULL,
            name TEXT COLLATE "C" NOT NULL,
            inquiry_text TEXT COLLATE "C",
            project_ids TEXT COLLATE "C" NOT NULL,
            tiers_data TEXT COLLATE "C",
            deliverable_toggles_data TEXT COLLATE "C",
            created_at TEXT COLLATE "C",
            last_modified TEXT COLLATE "C",
            PRIMARY KEY (user_id, id)
        )
        """,
        """
        CREATE TABLE visit_documents (
            rowid BIGINT GENERATED ALWAYS AS IDENTITY,
            user_id TEXT COLLATE "C" NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT COLLATE "C" NOT NULL,
            plan_id TEXT COLLATE "C" NOT NULL,
            document_key TEXT COLLATE "C" NOT NULL,
            include_source BIGINT NOT NULL,
            include_external_refs BIGINT NOT NULL,
            state_data BYTEA,
            created_at TEXT COLLATE "C",
            last_modified TEXT COLLATE "C",
            PRIMARY KEY (user_id, id)
        )
        """,
        """
        CREATE TABLE visit_targets (
            rowid BIGINT GENERATED ALWAYS AS IDENTITY,
            user_id TEXT COLLATE "C" NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT COLLATE "C" NOT NULL,
            plan_id TEXT COLLATE "C" NOT NULL,
            target_key TEXT COLLATE "C" NOT NULL,
            tier_id TEXT COLLATE "C",
            included BIGINT NOT NULL,
            user_note TEXT COLLATE "C",
            state_data BYTEA,
            created_at TEXT COLLATE "C",
            last_modified TEXT COLLATE "C",
            PRIMARY KEY (user_id, id)
        )
        """,
        """
        CREATE TABLE summaries (
            rowid BIGINT GENERATED ALWAYS AS IDENTITY,
            user_id TEXT COLLATE "C" NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT COLLATE "C" NOT NULL,
            document_id TEXT COLLATE "C" NOT NULL,
            volume_id TEXT COLLATE "C" NOT NULL,
            prompt_id TEXT COLLATE "C" NOT NULL,
            response_text TEXT COLLATE "C" NOT NULL,
            response_format TEXT COLLATE "C" NOT NULL,
            was_chunked BIGINT NOT NULL,
            authorship TEXT COLLATE "C",
            is_headnote_draft BIGINT NOT NULL,
            source_content_hash TEXT COLLATE "C",
            project_id TEXT COLLATE "C",
            created_at TEXT COLLATE "C",
            last_modified TEXT COLLATE "C",
            PRIMARY KEY (user_id, id)
        )
        """,
        """
        CREATE TABLE prompts (
            rowid BIGINT GENERATED ALWAYS AS IDENTITY,
            user_id TEXT COLLATE "C" NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT COLLATE "C" NOT NULL,
            name TEXT COLLATE "C" NOT NULL,
            prompt_text TEXT COLLATE "C" NOT NULL,
            response_format TEXT COLLATE "C" NOT NULL,
            is_standard BIGINT NOT NULL,
            schema TEXT COLLATE "C",
            created_at TEXT COLLATE "C",
            last_modified TEXT COLLATE "C",
            PRIMARY KEY (user_id, id)
        )
        """,
        """
        CREATE TABLE annotation_reviews (
            rowid BIGINT GENERATED ALWAYS AS IDENTITY,
            user_id TEXT COLLATE "C" NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT COLLATE "C" NOT NULL,
            annotation_type TEXT COLLATE "C" NOT NULL,
            annotation_id TEXT COLLATE "C",
            volume_id TEXT COLLATE "C" NOT NULL,
            document_id TEXT COLLATE "C" NOT NULL,
            content_hash TEXT COLLATE "C" NOT NULL,
            change_kind TEXT COLLATE "C",
            reviewed_at TEXT COLLATE "C",
            PRIMARY KEY (user_id, id)
        )
        """,
        """
        CREATE TABLE preferences (
            rowid BIGINT GENERATED ALWAYS AS IDENTITY,
            user_id TEXT COLLATE "C" NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            created_at TEXT COLLATE "C" NOT NULL,
            updated_at TEXT COLLATE "C" NOT NULL,
            wc_min_length BIGINT NOT NULL,
            wc_min_count BIGINT NOT NULL,
            wc_fold_plurals BIGINT NOT NULL,
            wc_filter_markings BIGINT NOT NULL,
            wc_exclude_boilerplate BIGINT NOT NULL,
            wc_global_stopwords_json TEXT COLLATE "C" NOT NULL,
            wc_lens_stopwords_json TEXT COLLATE "C" NOT NULL,
            citation_style_raw TEXT COLLATE "C" NOT NULL,
            default_document_mode_raw TEXT COLLATE "C" NOT NULL,
            research_logging_enabled BIGINT NOT NULL,
            list_order_json TEXT COLLATE "C" NOT NULL,
            PRIMARY KEY (user_id)
        )
        """,
        """
        CREATE TABLE person_overrides (
            rowid BIGINT GENERATED ALWAYS AS IDENTITY,
            id TEXT COLLATE "C" NOT NULL,
            kind TEXT COLLATE "C" NOT NULL,
            volume_id_a TEXT COLLATE "C" NOT NULL,
            ref_a TEXT COLLATE "C" NOT NULL,
            volume_id_b TEXT COLLATE "C",
            ref_b TEXT COLLATE "C",
            created_at TEXT COLLATE "C",
            PRIMARY KEY (id)
        )
        """,
        """
        CREATE TABLE classification_overrides (
            rowid BIGINT GENERATED ALWAYS AS IDENTITY,
            id TEXT COLLATE "C" NOT NULL,
            volume_id TEXT COLLATE "C" NOT NULL,
            document_id TEXT COLLATE "C" NOT NULL,
            is_editorial_note BIGINT NOT NULL,
            parsed_is_editorial_note BIGINT NOT NULL,
            created_at TEXT COLLATE "C",
            PRIMARY KEY (id)
        )
        """,
        "CREATE INDEX notes_by_document ON notes (user_id, volume_id, document_id)",
        "CREATE INDEX highlights_by_document ON highlights (user_id, volume_id, document_id)",
        "CREATE INDEX tag_assignments_by_document ON tag_assignments (user_id, volume_id, document_id)",
        "CREATE INDEX tag_assignments_by_tag ON tag_assignments (user_id, tag_id)",
        "CREATE INDEX collection_entries_by_collection ON collection_entries (user_id, collection_id, sort_order)",
        "CREATE INDEX project_leads_by_project ON project_leads (user_id, project_id)",
        "CREATE INDEX trail_reading_by_time ON trail_reading (user_id, accessed_at)",
        "CREATE INDEX trail_search_by_time ON trail_search (user_id, executed_at)",
        "CREATE INDEX trail_export_by_time ON trail_export (user_id, exported_at)",
        "CREATE INDEX visit_documents_by_plan ON visit_documents (user_id, plan_id)",
        "CREATE INDEX visit_targets_by_plan ON visit_targets (user_id, plan_id)",
        "CREATE INDEX summaries_by_document ON summaries (user_id, volume_id, document_id)",
        "CREATE INDEX annotation_reviews_by_document ON annotation_reviews (user_id, volume_id, document_id)",
        "CREATE INDEX classification_overrides_by_document ON classification_overrides (volume_id, document_id)",
        """
        INSERT INTO classification_overrides
            (id, volume_id, document_id, is_editorial_note, parsed_is_editorial_note, created_at)
        SELECT
            upper(gen_random_uuid()::text),
            volume_id,
            document_id,
            CASE WHEN value IN ('1', 'true') THEN 1 ELSE 0 END,
            CASE WHEN value IN ('1', 'true') THEN 0 ELSE 1 END,
            to_char(recorded_at::timestamptz AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
        FROM index_corrections
        WHERE field = 'is_editorial_note'
        ORDER BY recorded_at, rowid
        """,
        "DROP TABLE index_corrections",
    ]
}
