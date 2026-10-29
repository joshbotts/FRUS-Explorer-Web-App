// Research's screens, listed above All Notes and History, the web's own, as the app's Research tab
// pushes each from its sidebar (PLAN's S17f): the Research page (S19b), All Notes and History. The
// page lists the other two among its categories, as the app's sidebar does.
import { Link } from '@tanstack/react-router';
import { copy } from '../copy';

export function ResearchNav() {
  return (
    <nav className="research-nav" aria-label={copy.research.title}>
      <Link to="/research" activeOptions={{ exact: true, includeSearch: false }} activeProps={{ 'aria-current': 'page' }}>
        {copy.researchPage.title}
      </Link>
      <Link to="/research/notes" activeProps={{ 'aria-current': 'page' }}>
        {copy.allNotes.title}
      </Link>
      <Link to="/research/history" activeProps={{ 'aria-current': 'page' }}>
        {copy.history.title}
      </Link>
    </nav>
  );
}
