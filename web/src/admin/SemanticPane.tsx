// Administration ▸ Semantic (PLAN's S27b), a pane of the library's group, opening with Search Model: the app's
// section in a server's words. The model in the image, its file, size and SHA-256 held to the bundled vectors'
// index, its licence and the engine that runs it; and the encoder's setting and state, off, idle, starting or
// loaded with the memory it holds and when it stops. The image holds the model, so there is nothing to
// download or remove. Read again every ten seconds while the encoder is loaded, which ends by itself. S26c
// adds the vectors.
import { useQuery } from '@tanstack/react-query';
import { semanticQuery, type SearchModelReport } from '../api/admin';
import { copy } from '../copy';
import { AdminFrame, ReadFailure, useAdmin } from './AdminPanes';

const words = copy.admin.semantic;

export function SemanticScreen() {
  const { allowed } = useAdmin();
  const report = useQuery({ ...semanticQuery, enabled: allowed });
  let body;
  if (report.isError && !report.data) {
    body = <ReadFailure error={report.error} stale={false} />;
  } else if (!report.data) {
    body = <p role="status">{copy.admin.loading}</p>;
  } else {
    body = (
      <>
        {report.isError && <ReadFailure error={report.error} stale />}
        <SearchModel report={report.data} />
      </>
    );
  }
  return <AdminFrame title={words.title}>{body}</AdminFrame>;
}

/** A clock time the server gave, in the browser's own zone. */
const clock = (text: string) => new Date(text).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });

function SearchModel({ report }: { report: SearchModelReport }) {
  const model = report.model;
  let modelLine: string;
  if (!model.present) {
    modelLine = words.missing;
  } else if (model.verified === true && model.bytes !== undefined) {
    modelLine = words.present(words.megabytes(model.bytes));
  } else if (model.verified === false) {
    modelLine = words.notVerified;
  } else {
    modelLine = words.notRead;
  }
  const engine = report.engine;
  return (
    <section aria-labelledby="semantic-model">
      <h2 id="semantic-model">{words.searchModel}</h2>
      <dl className="admin-facts">
        <dt>{words.searchModel}</dt>
        <dd>{report.state === 'unavailable' && model.present && model.verified !== false ? words.unavailable : modelLine}</dd>
        <dt>{words.modelFile}</dt>
        <dd>
          <code>{model.path}</code>
        </dd>
        {model.bytes !== undefined && (
          <>
            <dt>{words.size}</dt>
            <dd>{words.bytes(model.bytes, model.bytes === model.publishedBytes)}</dd>
          </>
        )}
        {(model.sha256 ?? model.bundledSHA256) && (
          <>
            <dt>{words.digest}</dt>
            <dd>
              <code className="digest">{model.sha256 ?? model.bundledSHA256}</code>{' '}
              {model.verified === true ? words.digestVerified : model.bundledSHA256 && model.verified === false ? words.digestOther(model.bundledSHA256) : ''}
            </dd>
          </>
        )}
        <dt>{words.licence}</dt>
        <dd>{model.licence}</dd>
        <dt>{words.engine}</dt>
        <dd>{engine.present ? words.engineLine(engine.commit) : words.engineMissing(engine.path)}</dd>
        <dt>{words.encoder}</dt>
        <dd>
          <EncoderState report={report} />
        </dd>
        {report.setting === 'on' && (
          <>
            <dt>{words.queries}</dt>
            <dd>{words.queryCount(report.queries, report.starts)}</dd>
          </>
        )}
        {report.problem && (
          <>
            <dt>{words.problem}</dt>
            <dd>{report.problem}</dd>
          </>
        )}
      </dl>
      <p className="note">{words.footer}</p>
    </section>
  );
}

function EncoderState({ report }: { report: SearchModelReport }) {
  if (report.state !== 'loaded') return <>{words.states[report.state] ?? report.state}</>;
  const memory = report.residentBytes !== undefined ? words.megabytes(report.residentBytes) : undefined;
  return (
    <>
      {words.loaded(report.loadedAt ? clock(report.loadedAt) : '', memory)}
      {report.stopsAt && ` ${words.stops(clock(report.stopsAt), Math.round(report.idleSeconds / 60))}`}
    </>
  );
}
