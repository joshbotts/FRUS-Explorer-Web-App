// The collection editor's switches, checkboxes and choices show what was chosen in the moment it is
// chosen, as the app's bindings do. A change goes into the collection held at once (api/collections.ts),
// but the query tells React of it a moment later, and a controlled control would show its old value in
// between; so each control holds what was chosen until the value it is given moves on from the one it
// was chosen over: to agree with it, or, where the server refused, back.
import { type ComponentProps, useState } from 'react';

/** `given`, or the value just chosen over it until `given` moves on; and the way to choose one. */
export function useChosen<T>(given: T): [T, (value: T) => void] {
  const [chosen, setChosen] = useState<{ value: T; over: T } | null>(null);
  if (chosen && !Object.is(chosen.over, given)) setChosen(null);
  return [chosen ? chosen.value : given, (value: T) => setChosen({ value, over: given })];
}

/** A select that shows the option chosen at once. */
export function ChosenSelect({
  value,
  onChoose,
  ...props
}: Omit<ComponentProps<'select'>, 'value' | 'onChange'> & { value: string; onChoose: (value: string) => void }) {
  const [shown, choose] = useChosen(value);
  return (
    <select
      {...props}
      value={shown}
      onChange={(event) => {
        choose(event.target.value);
        onChoose(event.target.value);
      }}
    />
  );
}

/** A checkbox, or a switch, that shows the state chosen at once. */
export function ChosenCheckbox({
  checked,
  onChoose,
  ...props
}: Omit<ComponentProps<'input'>, 'checked' | 'onChange' | 'type'> & { checked: boolean; onChoose: (checked: boolean) => void }) {
  const [shown, choose] = useChosen(checked);
  return (
    <input
      {...props}
      type="checkbox"
      checked={shown}
      onChange={(event) => {
        choose(event.target.checked);
        onChoose(event.target.checked);
      }}
    />
  );
}
