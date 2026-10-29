// Settings' panes (SPEC, Settings and administration), listed beside each one: Tags, from S14c; from
// S17f Projects and Research Sessions, the app's, and Reading, the web's own pane for two of the app's
// synced settings; and Data, from S15d, the web's own pane for the app's Markdown export.
import { Link } from '@tanstack/react-router';
import { copy } from '../copy';

export function SettingsPanes() {
  return (
    <nav className="settings-panes" aria-label={copy.settings.panes}>
      <ul>
        <li>
          <Link to="/settings/tags" activeProps={{ 'aria-current': 'page' }}>
            {copy.settings.tags}
          </Link>
        </li>
        <li>
          <Link to="/settings/projects" activeProps={{ 'aria-current': 'page' }}>
            {copy.projects.title}
          </Link>
        </li>
        <li>
          <Link to="/settings/sessions" activeProps={{ 'aria-current': 'page' }} activeOptions={{ exact: false }}>
            {copy.sessions.title}
          </Link>
        </li>
        <li>
          <Link to="/settings/reading" activeProps={{ 'aria-current': 'page' }}>
            {copy.reading.title}
          </Link>
        </li>
        <li>
          <Link to="/settings/data" activeProps={{ 'aria-current': 'page' }}>
            {copy.dataSettings.title}
          </Link>
        </li>
      </ul>
    </nav>
  );
}
