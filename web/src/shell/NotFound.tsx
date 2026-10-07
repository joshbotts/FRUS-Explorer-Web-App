import { Link } from '@tanstack/react-router';
import { copy } from '../copy';
import { useDocumentTitle } from './useDocumentTitle';

export function NotFound() {
  useDocumentTitle(copy.notFound.title);
  return (
    <section className="screen">
      <h1 tabIndex={-1}>{copy.notFound.title}</h1>
      <p>{copy.notFound.body}</p>
      <p>
        <Link to="/browse">{copy.notFound.toBrowse}</Link>
      </p>
    </section>
  );
}
