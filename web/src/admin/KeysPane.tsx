// Administration ▸ Keys (PLAN's S20d): the instance's NARA Catalog key, which serves each user who has no
// key of their own, with Settings ▸ Keys' section over the admin's routes (S20c's `/api/v1/admin/secrets`).
import { useQuery } from '@tanstack/react-query';
import { instanceSecretsQuery } from '../api/admin';
import { copy } from '../copy';
import { KeySection } from '../settings/KeysSettings';
import { AdminFrame, ReadFailure, useAdmin } from './AdminPanes';

export function AdminKeysScreen() {
  const { allowed } = useAdmin();
  const secrets = useQuery({ ...instanceSecretsQuery, enabled: allowed });
  let body;
  if (secrets.isError && !secrets.data) {
    body = <ReadFailure error={secrets.error} stale={false} />;
  } else if (!secrets.data) {
    body = <p role="status">{copy.admin.loading}</p>;
  } else {
    body = (
      <>
        <p className="note">{copy.admin.keys.lead}</p>
        {secrets.data.secrets.map((secret) => (
          <KeySection key={secret.name} name={secret.name} stored={secret.set} instanceHasOne={false} owner="instance" />
        ))}
        <p className="note">{copy.keys.footer}</p>
      </>
    );
  }
  return (
    <AdminFrame title={copy.admin.keys.title}>
      <div className="keys-settings">{body}</div>
    </AdminFrame>
  );
}
