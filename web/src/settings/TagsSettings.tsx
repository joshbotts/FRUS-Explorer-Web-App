// Settings ▸ Tags (SPEC, Settings and administration), as the app's Tags pane lays it out
// (`SettingsTagsPane`): a row for each tag, which opens the tag's editor, and New Tag… at the end of
// the list, which makes a tag named New Tag and opens it in the editor to be named. The editor
// renames, merges and deletes, each by the server's rules, which are the app's.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Link } from '@tanstack/react-router';
import { type MouseEvent, useRef, useState } from 'react';
import { errorMessage } from '../api/client';
import type { UserTag } from '../api/types';
import { createTag, meQuery, tagsQuery } from '../api/userData';
import { copy } from '../copy';
import { useHeadingReady } from '../shell/headingFocus';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import { MergeTagDialog, TagEditor } from './TagEditor';

export function TagsSettingsScreen() {
  const client = useQueryClient();
  const me = useQuery(meQuery);
  const keepsUserData = me.data?.userData === true;
  const tags = useQuery({ ...tagsQuery, enabled: keepsUserData });
  const heading = useRef<HTMLHeadingElement>(null);
  /** The tag open in the editor, and whether it was just made, which hides Merge and Delete. */
  const [editing, setEditing] = useState<{ tag: UserTag; isNew: boolean } | null>(null);
  const [merging, setMerging] = useState<UserTag | null>(null);
  const [failure, setFailure] = useState<string | null>(null);
  // New Tag… makes one tag a press, however often it is pressed while the first is made.
  const [creating, setCreating] = useState(false);
  const opener = useRef<HTMLElement | null>(null);
  useDocumentTitle(copy.settings.tags);
  useHeadingReady(!me.isPending);

  const items = tags.data?.items ?? [];

  async function newTag(event: MouseEvent<HTMLButtonElement>) {
    if (creating) return;
    setCreating(true);
    setFailure(null);
    opener.current = event.currentTarget;
    try {
      const tag = await createTag(client, copy.settings.newTagDefault);
      setEditing({ tag, isNew: true });
    } catch (error) {
      setFailure(errorMessage(error));
    } finally {
      setCreating(false);
    }
  }

  /** A dialog closed: focus goes back to what opened it, or to the heading when that is gone. */
  function returnFocus(gone: boolean) {
    const target = opener.current;
    if (!gone && target?.isConnected) target.focus();
    else heading.current?.focus();
  }

  let body;
  if (me.isError) {
    body = (
      <p className="error" role="alert">
        {errorMessage(me.error)}
      </p>
    );
  } else if (me.data && !keepsUserData) {
    body = <p>{copy.settings.userDataOff}</p>;
  } else if (tags.isError) {
    body = (
      <p className="error" role="alert">
        {errorMessage(tags.error)}
      </p>
    );
  } else if (!tags.data) {
    body = <p role="status">{copy.settings.loading}</p>;
  } else {
    body = (
      <>
        {items.length === 0 ? (
          <p>{copy.settings.tagsEmpty}</p>
        ) : (
          <ul className="settings-list" aria-label={copy.settings.tags}>
            {items.map((tag) => (
              <li key={tag.id}>
                <button
                  type="button"
                  className="settings-row"
                  aria-haspopup="dialog"
                  onClick={(event) => {
                    opener.current = event.currentTarget;
                    setEditing({ tag, isNew: false });
                  }}
                >
                  {tag.name}
                  <span aria-hidden="true">›</span>
                </button>
              </li>
            ))}
          </ul>
        )}
        <button type="button" className="settings-new" aria-haspopup="dialog" disabled={creating} onClick={(event) => void newTag(event)}>
          {copy.settings.newTag}
        </button>
        {failure && (
          <p className="error" role="alert">
            {failure}
          </p>
        )}
        <p className="note">{copy.settings.tagsFooter}</p>
      </>
    );
  }

  return (
    <div className="settings">
      <nav className="settings-panes" aria-label={copy.settings.panes}>
        <ul>
          <li>
            <Link to="/settings/tags" activeProps={{ 'aria-current': 'page' }}>
              {copy.settings.tags}
            </Link>
          </li>
        </ul>
      </nav>
      <section className="settings-pane">
        <h1 ref={heading} tabIndex={-1} data-loading={me.isPending ? 'true' : undefined}>
          {copy.settings.tags}
        </h1>
        {body}
      </section>
      {editing && (
        <TagEditor
          key={editing.tag.id}
          tag={editing.tag}
          peerTagCount={items.length}
          isNew={editing.isNew}
          onMerge={() => {
            setMerging(editing.tag);
            setEditing(null);
          }}
          onClose={(gone) => {
            setEditing(null);
            returnFocus(gone);
          }}
        />
      )}
      {merging && (
        <MergeTagDialog
          source={merging}
          others={items.filter((tag) => tag.id !== merging.id)}
          onClose={(merged) => {
            setMerging(null);
            returnFocus(merged);
          }}
        />
      )}
    </div>
  );
}
