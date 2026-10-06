// Query strings with HTML form semantics, as the server's FormQuery reads them: the browser's own
// URLSearchParams writes a space as +, a plus as %2B, and every other byte outside A-Z a-z 0-9 * - . _
// percent-encoded. A list is its name repeated, and one empty value is the empty list.

export type FormValue = string | number | boolean | readonly string[] | undefined;

/**
 * The fields as a query string's pairs, in order. An undefined field is left out, which means no
 * filter. A list drops empty strings, which the server refuses among other values, and an empty
 * list is one empty value: callers decide whether they mean that, since the server reads an empty
 * `volumeIds` as no filter and an empty `yearKeys` as matching nothing.
 */
export function formEncode(fields: Record<string, FormValue>): URLSearchParams {
  const params = new URLSearchParams();
  for (const [name, value] of Object.entries(fields)) {
    if (value === undefined) continue;
    if (Array.isArray(value)) {
      const items = (value as readonly string[]).filter((item) => item !== '');
      if (items.length === 0) params.append(name, '');
      else for (const item of items) params.append(name, item);
    } else {
      params.append(name, String(value));
    }
  }
  return params;
}

/** A query string's pairs, each name with its values in order. */
export function formDecode(query: string): Map<string, string[]> {
  const fields = new Map<string, string[]>();
  for (const [name, value] of new URLSearchParams(query)) {
    const values = fields.get(name);
    if (values) values.push(value);
    else fields.set(name, [value]);
  }
  return fields;
}
