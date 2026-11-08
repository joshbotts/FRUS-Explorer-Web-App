// A summary as the app's readers draw it since FRUS-Explorer#1824, the app's
// `StructuredSummaryDisplay.text(responseText:format:)`: a structured summary's fields one to a line, each
// opening with its label and a colon in bold, then a space and its text; any other summary's text as it is
// stored. The fields are the kit's, which the server gives as the summary's reading.
import { Fragment } from 'react';
import type { SummaryReading } from '../api/types';

export function SummaryReadingText({ reading }: { reading: SummaryReading }) {
  if (!reading.fields) return <>{reading.text}</>;
  return (
    <>
      {reading.fields.map((field, index) => (
        <Fragment key={index}>
          {index > 0 && <br />}
          <strong>{field.label}:</strong>
          {` ${field.text}`}
        </Fragment>
      ))}
    </>
  );
}
