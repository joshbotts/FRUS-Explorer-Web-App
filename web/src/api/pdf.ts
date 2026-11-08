// The server's PDF service (PLAN's S25a): whether it answers now, as `GET /api/v1/pdf` says, which the
// export sheet asks before it offers PDF. None answers while `FRUS_PDF_URL` is unset, or while the
// Compose install's `pdf` profile is off.
import { queryOptions } from '@tanstack/react-query';
import { getJSON } from './client';

/** `GET /api/v1/pdf`. */
export interface PdfService {
  /** Whether the server's PDF service answers its health check now. */
  available: boolean;
}

/**
 * Whether the server makes PDFs now: asked again after ten seconds, as often as the server asks its
 * service, and not when the window regains focus.
 */
export const pdfServiceQuery = queryOptions({
  queryKey: ['pdfService'],
  queryFn: ({ signal }) => getJSON<PdfService>('/api/v1/pdf', undefined, signal),
  staleTime: 10_000,
  refetchOnWindowFocus: false,
  retry: false,
});

/** Whether to offer PDF: once the server has said its service answers, and not when it could not say. */
export const offersPdf = (service: PdfService | undefined): boolean => service?.available === true;
