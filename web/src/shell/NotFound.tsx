import { Link } from '@tanstack/react-router';
import { copy } from '../copy';

export function NotFound() {
  return (
    <section className="screen">
      <h1 tabIndex={-1}>{copy.notFound.title}</h1>
      <p>{copy.notFound.body}</p>
      <p>
        <Link to="/search">{copy.notFound.toSearch}</Link>
      </p>
    </section>
  );
}
