// A file the server wrote, handed to the browser to save: Settings ▸ Data's JSON export (S16d) and a
// collection's exports (S18e).

/** Hands `file` to the browser to save as `name`, through an address of its own that lasts until the save has begun. */
export function saveFile(file: Blob, name: string) {
  const address = URL.createObjectURL(file);
  const link = document.createElement('a');
  link.href = address;
  link.download = name;
  document.body.append(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(address), 60_000);
}
