// The reader's own order of the tag and project lists (PLAN's S17f), the app's `ListOrderPreferences`,
// mirrored: a permutation of each list's alphabetical baseline, the ids the reader moved first, in
// their order, and every other in its place after them, an id the order names that the list does not
// hold passed over. The order is the user's synced preferences' (`tagOrder`, `projectOrder`), and is
// set by the Move to Top, Move Up and Move Down commands. ProjectHistoryParityTests holds it to the
// app's source.

/** One step of the Move to Top, Move Up and Move Down commands. */
export type MoveStep = 'toTop' | 'up' | 'down';

/**
 * `items` in the reader's `order`, the ids it names first, in its order, the first place an id holds
 * there its own, and the rest in the order given (`ListOrderPreferences.apply(_:order:id:)`).
 */
export function applyOrder<T>(items: readonly T[], order: readonly string[], id: (item: T) => string): T[] {
  if (order.length === 0) return [...items];
  const rank = new Map<string, number>();
  order.forEach((key, place) => {
    const upper = key.toUpperCase();
    if (!rank.has(upper)) rank.set(upper, place);
  });
  const named = items.filter((item) => rank.has(id(item).toUpperCase()));
  named.sort((a, b) => rank.get(id(a).toUpperCase())! - rank.get(id(b).toUpperCase())!);
  return [...named, ...items.filter((item) => !rank.has(id(item).toUpperCase()))];
}

/**
 * The ids of `displayed` after `id` moves one `step`, or undefined when it would change nothing, so the
 * command can be left out (`ListOrderPreferences.moving(_:_:in:)`).
 */
export function moving(id: string, step: MoveStep, displayed: readonly string[]): string[] | undefined {
  const index = displayed.indexOf(id);
  if (index < 0) return undefined;
  const ids = [...displayed];
  switch (step) {
    case 'toTop':
      if (index === 0) return undefined;
      ids.splice(index, 1);
      ids.unshift(id);
      return ids;
    case 'up':
      if (index === 0) return undefined;
      [ids[index - 1], ids[index]] = [ids[index]!, ids[index - 1]!];
      return ids;
    case 'down':
      if (index === ids.length - 1) return undefined;
      [ids[index], ids[index + 1]] = [ids[index + 1]!, ids[index]!];
      return ids;
  }
}
