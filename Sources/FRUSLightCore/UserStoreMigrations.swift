// The user store's numbered, forward-only migrations.

/// The SQL of each migration of `app.db`. Each entry is one migration; its number is its position,
/// starting at 1. Never edit one that has shipped: add another, and with it any change to
/// `UserStoreSchema`.
public enum UserStoreMigrations {
    public static let all: [String] = [one, two, three, four, five, six, seven]

    /// S2: the single user, and corrections as override rows.
    static let one = """
        CREATE TABLE users (
            user_id TEXT PRIMARY KEY,
            display_name TEXT NOT NULL,
            created_at TEXT NOT NULL
        );
        INSERT INTO users (user_id, display_name, created_at)
            VALUES ('owner', 'Owner', strftime('%Y-%m-%dT%H:%M:%SZ', 'now'));
        CREATE TABLE index_corrections (
            volume_id TEXT NOT NULL,
            document_id TEXT NOT NULL,
            field TEXT NOT NULL,
            value TEXT NOT NULL,
            recorded_by TEXT NOT NULL REFERENCES users (user_id),
            recorded_at TEXT NOT NULL,
            PRIMARY KEY (volume_id, document_id, field)
        );
        """

    /// S14a: a table for each of the 23 model types in the app's `frusModelTypes` at `2767a128`,
    /// as `UserStoreSchema` describes them; the indexes their screens will read them by; and
    /// `user_search`, whose rows a trigger deletes with their user. The two override tables replace `index_corrections`, whose rows become
    /// classification overrides: a correction of the flag asserts the value the TEI did not give.
    static let two = """
        CREATE TABLE notes (
            user_id TEXT NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT NOT NULL,
            document_id TEXT NOT NULL,
            volume_id TEXT NOT NULL,
            body_text TEXT NOT NULL,
            rich_text BLOB,
            project_ids TEXT NOT NULL,
            user_tag_ids TEXT NOT NULL,
            selected_summary_ids TEXT NOT NULL,
            created_at TEXT,
            last_modified TEXT,
            PRIMARY KEY (user_id, id)
        );
        CREATE TABLE highlights (
            user_id TEXT NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT NOT NULL,
            volume_id TEXT NOT NULL,
            document_id TEXT NOT NULL,
            start_offset INTEGER NOT NULL,
            end_offset INTEGER NOT NULL,
            color_tag TEXT NOT NULL,
            note_id TEXT,
            selected_text TEXT NOT NULL,
            rendering_version TEXT NOT NULL,
            created_at TEXT,
            PRIMARY KEY (user_id, id)
        );
        CREATE TABLE tags (
            user_id TEXT NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT NOT NULL,
            name TEXT NOT NULL,
            created_at TEXT,
            last_modified TEXT,
            PRIMARY KEY (user_id, id)
        );
        CREATE TABLE tag_assignments (
            user_id TEXT NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT NOT NULL,
            volume_id TEXT NOT NULL,
            document_id TEXT NOT NULL,
            tag_id TEXT NOT NULL,
            created_at TEXT,
            PRIMARY KEY (user_id, id)
        );
        CREATE TABLE collections (
            user_id TEXT NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT NOT NULL,
            name TEXT NOT NULL,
            note TEXT,
            subtitle TEXT,
            author_line TEXT,
            introduction_text TEXT,
            introduction_rich_text BLOB,
            include_colophon INTEGER NOT NULL,
            include_project_provenance INTEGER NOT NULL,
            include_method_appendix INTEGER NOT NULL,
            project_ids TEXT NOT NULL,
            saved_search_id TEXT,
            default_body_depth TEXT NOT NULL,
            footnote_style TEXT NOT NULL,
            include_footnotes INTEGER,
            include_source_note INTEGER,
            toc_style TEXT NOT NULL,
            apply_highlights INTEGER NOT NULL,
            include_notes INTEGER NOT NULL,
            include_word_cloud INTEGER NOT NULL,
            default_include_headnote INTEGER NOT NULL,
            summary_prompt_id TEXT,
            created_at TEXT,
            last_modified TEXT,
            PRIMARY KEY (user_id, id)
        );
        CREATE TABLE collection_entries (
            user_id TEXT NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT NOT NULL,
            collection_id TEXT NOT NULL,
            document_id TEXT NOT NULL,
            volume_id TEXT NOT NULL,
            title_override TEXT,
            sort_order INTEGER NOT NULL,
            level INTEGER NOT NULL,
            research_note_id TEXT,
            selected_note_ids TEXT NOT NULL,
            body_depth_override TEXT,
            apply_highlights_override INTEGER,
            include_notes_override INTEGER,
            include_source_note_override INTEGER,
            include_footnotes_override INTEGER,
            summary_prompt_id_override TEXT,
            selected_highlight_ids TEXT NOT NULL,
            include_related_documents INTEGER,
            include_headnote INTEGER,
            headnote_summary_id TEXT,
            excerpt_start INTEGER,
            excerpt_end INTEGER,
            excerpt_rendering_version TEXT,
            excerpt_color_tag TEXT,
            kind TEXT NOT NULL,
            generated_block_type TEXT,
            text TEXT,
            rich_text BLOB,
            created_at TEXT,
            last_modified TEXT,
            PRIMARY KEY (user_id, id)
        );
        CREATE TABLE projects (
            user_id TEXT NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT NOT NULL,
            name TEXT NOT NULL,
            research_question TEXT,
            default_date_range_start TEXT,
            default_date_range_end TEXT,
            default_subject_tag_ids TEXT NOT NULL,
            default_country_tag_ids TEXT NOT NULL,
            lead_axis_weights TEXT,
            default_user_tag_ids TEXT NOT NULL,
            created_at TEXT,
            last_modified TEXT,
            PRIMARY KEY (user_id, id)
        );
        CREATE TABLE project_leads (
            user_id TEXT NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT NOT NULL,
            project_id TEXT NOT NULL,
            volume_id TEXT NOT NULL,
            document_id TEXT NOT NULL,
            aggregate_score REAL NOT NULL,
            contributing_seed_keys TEXT NOT NULL,
            header TEXT NOT NULL,
            document_number TEXT,
            is_editorial_note INTEGER NOT NULL,
            first_surfaced_at TEXT NOT NULL,
            last_computed_at TEXT NOT NULL,
            dismissed INTEGER NOT NULL,
            PRIMARY KEY (user_id, id)
        );
        CREATE TABLE saved_searches (
            user_id TEXT NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT NOT NULL,
            name TEXT NOT NULL,
            query_text TEXT NOT NULL,
            phrase_text TEXT NOT NULL,
            prefix_wildcard TEXT NOT NULL,
            boolean_mode_raw TEXT NOT NULL,
            excluded_terms_csv TEXT NOT NULL,
            scope_flags INTEGER NOT NULL,
            date_range_start TEXT,
            date_range_end TEXT,
            subject_tag_ids_csv TEXT NOT NULL,
            document_type_filter_raw TEXT NOT NULL,
            person_ref TEXT NOT NULL,
            sort_order TEXT NOT NULL,
            created_at TEXT,
            last_modified TEXT,
            parameters_data TEXT,
            freshness_data TEXT,
            PRIMARY KEY (user_id, id)
        );
        CREATE TABLE working_corpora (
            user_id TEXT NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT NOT NULL,
            name TEXT NOT NULL,
            document_keys TEXT NOT NULL,
            captured_at TEXT,
            source_query TEXT,
            source_description TEXT,
            indexed_volume_count_at_capture INTEGER,
            was_truncated_at_capture INTEGER,
            total_match_count_at_capture INTEGER,
            created_at TEXT,
            last_modified TEXT,
            PRIMARY KEY (user_id, id)
        );
        CREATE TABLE volume_scopes (
            user_id TEXT NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT NOT NULL,
            name TEXT NOT NULL,
            volume_ids TEXT NOT NULL,
            created_at TEXT,
            last_modified TEXT,
            PRIMARY KEY (user_id, id)
        );
        CREATE TABLE trail_reading (
            user_id TEXT NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT NOT NULL,
            document_id TEXT NOT NULL,
            volume_id TEXT NOT NULL,
            display_title TEXT,
            project_id TEXT,
            accessed_at TEXT,
            PRIMARY KEY (user_id, id)
        );
        CREATE TABLE trail_search (
            user_id TEXT NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT NOT NULL,
            query_text TEXT NOT NULL,
            result_count INTEGER NOT NULL,
            project_id TEXT,
            executed_at TEXT,
            loaded_count INTEGER,
            match_count INTEGER,
            fetch_limit INTEGER,
            indexed_volume_count INTEGER,
            scope_signature TEXT,
            applied_corpus_id TEXT,
            rendered_expression TEXT,
            PRIMARY KEY (user_id, id)
        );
        CREATE TABLE trail_export (
            user_id TEXT NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT NOT NULL,
            format TEXT NOT NULL,
            document_count INTEGER NOT NULL,
            collection_name TEXT,
            project_id TEXT,
            exported_at TEXT,
            PRIMARY KEY (user_id, id)
        );
        CREATE TABLE visit_plans (
            user_id TEXT NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT NOT NULL,
            name TEXT NOT NULL,
            inquiry_text TEXT,
            project_ids TEXT NOT NULL,
            tiers_data TEXT,
            deliverable_toggles_data TEXT,
            created_at TEXT,
            last_modified TEXT,
            PRIMARY KEY (user_id, id)
        );
        CREATE TABLE visit_documents (
            user_id TEXT NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT NOT NULL,
            plan_id TEXT NOT NULL,
            document_key TEXT NOT NULL,
            include_source INTEGER NOT NULL,
            include_external_refs INTEGER NOT NULL,
            state_data BLOB,
            created_at TEXT,
            last_modified TEXT,
            PRIMARY KEY (user_id, id)
        );
        CREATE TABLE visit_targets (
            user_id TEXT NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT NOT NULL,
            plan_id TEXT NOT NULL,
            target_key TEXT NOT NULL,
            tier_id TEXT,
            included INTEGER NOT NULL,
            user_note TEXT,
            state_data BLOB,
            created_at TEXT,
            last_modified TEXT,
            PRIMARY KEY (user_id, id)
        );
        CREATE TABLE summaries (
            user_id TEXT NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT NOT NULL,
            document_id TEXT NOT NULL,
            volume_id TEXT NOT NULL,
            prompt_id TEXT NOT NULL,
            response_text TEXT NOT NULL,
            response_format TEXT NOT NULL,
            was_chunked INTEGER NOT NULL,
            authorship TEXT,
            is_headnote_draft INTEGER NOT NULL,
            source_content_hash TEXT,
            project_id TEXT,
            created_at TEXT,
            last_modified TEXT,
            PRIMARY KEY (user_id, id)
        );
        CREATE TABLE prompts (
            user_id TEXT NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT NOT NULL,
            name TEXT NOT NULL,
            prompt_text TEXT NOT NULL,
            response_format TEXT NOT NULL,
            is_standard INTEGER NOT NULL,
            schema TEXT,
            created_at TEXT,
            last_modified TEXT,
            PRIMARY KEY (user_id, id)
        );
        CREATE TABLE annotation_reviews (
            user_id TEXT NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            id TEXT NOT NULL,
            annotation_type TEXT NOT NULL,
            annotation_id TEXT,
            volume_id TEXT NOT NULL,
            document_id TEXT NOT NULL,
            content_hash TEXT NOT NULL,
            change_kind TEXT,
            reviewed_at TEXT,
            PRIMARY KEY (user_id, id)
        );
        CREATE TABLE preferences (
            user_id TEXT NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            wc_min_length INTEGER NOT NULL,
            wc_min_count INTEGER NOT NULL,
            wc_fold_plurals INTEGER NOT NULL,
            wc_filter_markings INTEGER NOT NULL,
            wc_exclude_boilerplate INTEGER NOT NULL,
            wc_global_stopwords_json TEXT NOT NULL,
            wc_lens_stopwords_json TEXT NOT NULL,
            citation_style_raw TEXT NOT NULL,
            default_document_mode_raw TEXT NOT NULL,
            research_logging_enabled INTEGER NOT NULL,
            list_order_json TEXT NOT NULL,
            PRIMARY KEY (user_id)
        );
        CREATE TABLE person_overrides (
            id TEXT NOT NULL,
            kind TEXT NOT NULL,
            volume_id_a TEXT NOT NULL,
            ref_a TEXT NOT NULL,
            volume_id_b TEXT,
            ref_b TEXT,
            created_at TEXT,
            PRIMARY KEY (id)
        );
        CREATE TABLE classification_overrides (
            id TEXT NOT NULL,
            volume_id TEXT NOT NULL,
            document_id TEXT NOT NULL,
            is_editorial_note INTEGER NOT NULL,
            parsed_is_editorial_note INTEGER NOT NULL,
            created_at TEXT,
            PRIMARY KEY (id)
        );

        CREATE INDEX notes_by_document ON notes (user_id, volume_id, document_id);
        CREATE INDEX highlights_by_document ON highlights (user_id, volume_id, document_id);
        CREATE INDEX tag_assignments_by_document ON tag_assignments (user_id, volume_id, document_id);
        CREATE INDEX tag_assignments_by_tag ON tag_assignments (user_id, tag_id);
        CREATE INDEX collection_entries_by_collection ON collection_entries (user_id, collection_id, sort_order);
        CREATE INDEX project_leads_by_project ON project_leads (user_id, project_id);
        CREATE INDEX trail_reading_by_time ON trail_reading (user_id, accessed_at);
        CREATE INDEX trail_search_by_time ON trail_search (user_id, executed_at);
        CREATE INDEX trail_export_by_time ON trail_export (user_id, exported_at);
        CREATE INDEX visit_documents_by_plan ON visit_documents (user_id, plan_id);
        CREATE INDEX visit_targets_by_plan ON visit_targets (user_id, plan_id);
        CREATE INDEX summaries_by_document ON summaries (user_id, volume_id, document_id);
        CREATE INDEX annotation_reviews_by_document ON annotation_reviews (user_id, volume_id, document_id);
        CREATE INDEX classification_overrides_by_document ON classification_overrides (volume_id, document_id);

        -- Each user's note and summary text for one document, as the Mac's user_content holds a
        -- document's: the same two indexed columns and the corpus's tokenizer.
        CREATE VIRTUAL TABLE user_search USING fts5(
            user_id UNINDEXED,
            document_id UNINDEXED,
            volume_id UNINDEXED,
            summary_text,
            note_text,
            tokenize = 'porter unicode61'
        );
        -- A virtual table cannot refer to users, so its rows go with their user by a trigger.
        CREATE TRIGGER user_search_follows_users AFTER DELETE ON users
        BEGIN
            DELETE FROM user_search WHERE user_id = old.user_id;
        END;

        INSERT INTO classification_overrides
            (id, volume_id, document_id, is_editorial_note, parsed_is_editorial_note, created_at)
        SELECT
            hex(randomblob(4)) || '-' || hex(randomblob(2)) || '-4' || substr(hex(randomblob(2)), 2) || '-'
                || substr('89AB', 1 + (random() & 3), 1) || substr(hex(randomblob(2)), 2) || '-'
                || hex(randomblob(6)),
            volume_id,
            document_id,
            value IN ('1', 'true'),
            value NOT IN ('1', 'true'),
            strftime('%Y-%m-%dT%H:%M:%fZ', recorded_at)
        FROM index_corrections
        WHERE field = 'is_editorial_note'
        ORDER BY recorded_at, rowid;
        DROP TABLE index_corrections;
        """

    /// S17f's: the project each user works in, the web's own, since the Mac keeps its active project
    /// on each device (`AppState.activeProjectId`) and a user here has one, which a trail row's
    /// `project_id` is stamped from as the Mac stamps it. NULL is the Mac's Global Context.
    static let three = """
        ALTER TABLE users ADD COLUMN active_project_id TEXT;
        """

    /// S20b's: local accounts, `FRUS_AUTH=local`. A user gains the Argon2id hash of their password, as
    /// its PHC string, none for one who cannot sign in; a role, each of reader, curator and admin the
    /// one before it and more, a reader's unless the user is `owner`, who holds the three under
    /// `FRUS_AUTH=none` and so is an admin; when the account was disabled; and its last sign-in. A
    /// session is keyed by the SHA-256 of the token its cookie carries, so that neither the store nor a
    /// backup of it holds a token that signs anyone in, and goes with its user.
    static let four = """
        ALTER TABLE users ADD COLUMN password_hash TEXT;
        ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'reader' CHECK (role IN ('reader', 'curator', 'admin'));
        ALTER TABLE users ADD COLUMN disabled_at TEXT;
        ALTER TABLE users ADD COLUMN last_sign_in_at TEXT;
        UPDATE users SET role = 'admin' WHERE user_id = 'owner';
        CREATE TABLE sessions (
            session_id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
            created_at TEXT NOT NULL,
            last_used_at TEXT NOT NULL,
            expires_at TEXT NOT NULL
        );
        CREATE INDEX sessions_by_user ON sessions (user_id);
        """

    /// S20c's: the keys the server keeps for the outside services it calls, a user's own, by their id, or
    /// the instance's, with no user, each by its name, of which a user or the instance has one. A row
    /// holds no key as it was given: `sealed` is the key under AES-GCM, with what it takes to open it
    /// but the key file (`SecretKey`), and `key_id` names the key file it was sealed under, so that a
    /// server can tell a store whose keys its key file does not open. A user's keys go with the user.
    static let five = """
        CREATE TABLE secrets (
            user_id TEXT REFERENCES users (user_id) ON DELETE CASCADE,
            name TEXT NOT NULL,
            key_id TEXT NOT NULL,
            sealed BLOB NOT NULL,
            updated_at TEXT NOT NULL
        );
        CREATE UNIQUE INDEX secrets_of_user ON secrets (user_id, name) WHERE user_id IS NOT NULL;
        CREATE UNIQUE INDEX secrets_of_instance ON secrets (name) WHERE user_id IS NULL;
        """

    /// S20d's: the server's jobs, which its queue runs one at a time, each a row kept as it goes, so
    /// that the admin's Jobs list outlives a restart: what it does (`kind`, such as `indexImport`), what
    /// it works on, its state, a line of its progress and how far through it is where it can tell, who
    /// asked (NULL for the server itself, as an export found in /data/import), when it was queued,
    /// started and finished, why it failed, and who asked it to stop, and when. A job a server stopped
    /// mid-way is marked failed at the next start. The rows hold no research and no key: a user's id,
    /// an export's file name and the server's own sentences.
    static let six = """
        CREATE TABLE jobs (
            job_id TEXT PRIMARY KEY,
            kind TEXT NOT NULL,
            subject TEXT,
            state TEXT NOT NULL CHECK (state IN ('queued', 'running', 'succeeded', 'failed', 'cancelled')),
            progress TEXT,
            fraction REAL,
            requested_by TEXT,
            queued_at TEXT NOT NULL,
            started_at TEXT,
            finished_at TEXT,
            error TEXT,
            cancel_requested_by TEXT,
            cancel_requested_at TEXT
        );
        CREATE INDEX jobs_by_state ON jobs (state, finished_at);
        """

    /// S21c's: the library a Standalone server downloads, one row a catalogue volume it has been asked
    /// for. `state` is its download's: `queued` while a job waits to fetch it, `downloading` while one
    /// does, then `downloaded` or `failed`, with why in the server's own sentence; a row left `queued`
    /// or `downloading` by a server that stopped is fetched again at the next start, volume by volume.
    /// `blob_sha` and `size_bytes` describe the file in the volumes folder, the git blob SHA-1 GitHub's
    /// listing gives and its length, checked before it took its place, with when it was downloaded and
    /// whether it was side-loaded (S21e), and the figure images fetched beside it and refused by the
    /// host. A volume never asked for has no row. No row holds research or a key: a volume's id, the
    /// server's sentences, and who asked.
    static let seven = """
        CREATE TABLE library_volumes (
            volume_id TEXT PRIMARY KEY,
            state TEXT NOT NULL CHECK (state IN ('queued', 'downloading', 'downloaded', 'failed')),
            blob_sha TEXT,
            size_bytes INTEGER,
            downloaded_at TEXT,
            sideloaded INTEGER NOT NULL DEFAULT 0,
            figures_stored INTEGER,
            figures_refused INTEGER,
            error TEXT,
            requested_by TEXT,
            queued_at TEXT,
            updated_at TEXT NOT NULL
        );
        CREATE INDEX library_volumes_by_state ON library_volumes (state, queued_at);
        """
}
