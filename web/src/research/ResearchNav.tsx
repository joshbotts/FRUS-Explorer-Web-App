// Research's screens, listed above each, the web's own, as the app's Research tab lists All Notes and
// pushes History (PLAN's S17f): All Notes until S19b's Research page, and History.
import { Link } from '@tanstack/react-router';
import { copy } from '../copy';

export function ResearchNav() {
  return (
    <nav className="research-nav" aria-label={copy.research.title}>
      <Link to="/research/notes" activeProps={{ 'aria-current': 'page' }}>
        {copy.allNotes.title}
      </Link>
      <Link to="/research/history" activeProps={{ 'aria-current': 'page' }}>
        {copy.history.title}
      </Link>
    </nav>
  );
}
