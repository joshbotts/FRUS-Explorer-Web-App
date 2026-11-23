// Settings ▸ Word Cloud (PLAN's S24i), the app's `WordCloudSettingsView`: Sample, the settings bench's kept words from
// its stand-in sample (`WordCloudBench`), sized by rank; Filtering, the three switches; Thresholds, the minimum word
// length and occurrences with the bench's Effect line; Appearance, the typeface and density, kept in this browser as the
// app keeps them on each device; and Hidden Words, one editor whose Applies to picks every cloud's list or a lens's own.
// The criteria and the hidden words are the reader's synced preferences, which follow them to any browser and to the Mac
// in an export, written as the app's settings write them; on a server that keeps no reader's settings the pane offers
// Appearance alone. The web's own: number fields where the app has steppers, and the line for a server that keeps none.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { type ReactNode, useId, useState } from 'react';
import { cloudSampleQuery, hideWord, settingsToken, showWord, updateWordCloud, type WordCloudCriteria } from '../api/cloud';
import { errorMessage } from '../api/client';
import { meQuery } from '../api/userData';
import { copy } from '../copy';
import {
  densities,
  type Density,
  type FontDesign,
  fontDesigns,
  keepDensity,
  keepFontDesign,
  sampleFontSize,
  storedDensity,
  storedFontDesign,
} from '../cloud/cloudRules';
import { useHeadingReady } from '../shell/headingFocus';
import { useDocumentTitle } from '../shell/useDocumentTitle';
import { SettingsPanes } from './SettingsPanes';
import { useSyncedPreferences } from './syncedPreferences';

const words = copy.wordCloudSettings;

/** The app's nine lenses, in its picker's order (`WordCloudLens.allCases`), each a list the editor may show. */
const lenses = ['allTerms', 'people', 'places', 'organizations', 'topics', 'actions', 'descriptors', 'concepts', 'sentiment'] as const;

export function WordCloudSettingsScreen() {
  const me = useQuery(meQuery);
  const { keepsUserData, preferences } = useSyncedPreferences();
  const [design, setDesign] = useState<FontDesign>(storedFontDesign);
  const [density, setDensity] = useState<Density>(storedDensity);
  const appearanceId = useId();
  const appearanceFooter = useId();
  useDocumentTitle(words.title);
  useHeadingReady(!me.isPending);

  // Appearance, this browser's: between Thresholds and Hidden Words, as the app's pane orders its sections.
  const appearance = (
    <section aria-labelledby={appearanceId}>
      <h2 id={appearanceId}>{words.appearance}</h2>
      <label>
        {words.font}{' '}
        <select
          value={design}
          aria-describedby={appearanceFooter}
          onChange={(event) => {
            setDesign(event.target.value as FontDesign);
            keepFontDesign(event.target.value as FontDesign);
          }}
        >
          {fontDesigns.map((value) => (
            <option key={value} value={value}>
              {words.fonts[value]}
            </option>
          ))}
        </select>
      </label>
      <label>
        {words.density}{' '}
        <select
          value={density}
          aria-describedby={appearanceFooter}
          onChange={(event) => {
            setDensity(event.target.value as Density);
            keepDensity(event.target.value as Density);
          }}
        >
          {densities.map((value) => (
            <option key={value} value={value}>
              {words.densities[value]}
            </option>
          ))}
        </select>
      </label>
      <p id={appearanceFooter} className="note">
        {words.appearanceFooter}
      </p>
    </section>
  );

  return (
    <div className="settings">
      <SettingsPanes />
      <section className="settings-pane word-cloud-settings">
        <h1 tabIndex={-1} data-loading={me.isPending ? 'true' : undefined}>
          {words.title}
        </h1>
        {keepsUserData && preferences ? (
          <Criteria criteria={preferences.wordCloud} token={settingsToken(preferences)} design={design} appearance={appearance} />
        ) : (
          <>
            {!me.isPending && <p className="note">{words.noSettings}</p>}
            {appearance}
          </>
        )}
      </section>
    </div>
  );
}

type Criteria = WordCloudCriteria & { globalStopwords: string[]; lensStopwords: Record<string, string[]> };

/** The criteria and the hidden words: the reader's own, with the bench above them, and Appearance between them. */
function Criteria({ criteria, token, design, appearance }: { criteria: Criteria; token: string; design: FontDesign; appearance: ReactNode }) {
  const client = useQueryClient();
  const [scope, setScope] = useState<string>('');
  const [failure, setFailure] = useState<string | undefined>(undefined);
  const sample = useQuery(cloudSampleQuery(scope || undefined, token));
  const ids = { sample: useId(), filtering: useId(), filteringFooter: useId(), thresholds: useId(), thresholdsFooter: useId(), hidden: useId(), hiddenFooter: useId() };

  function set(changed: Partial<WordCloudCriteria>) {
    setFailure(undefined);
    void updateWordCloud(client, changed).catch((error: unknown) => setFailure(errorMessage(error)));
  }

  const kept = sample.data?.kept ?? [];
  const shown = kept.slice(0, 12);
  return (
    <>
      <section aria-labelledby={ids.sample}>
        <h2 id={ids.sample}>{words.sample}</h2>
        {sample.data && kept.length === 0 ? (
          <p className="note">{words.sampleNone}</p>
        ) : (
          <p className={`cloud-sample cloud-font-${design}`} aria-label={words.sampleA11y(shown.map((term) => term.term).join(', '))}>
            {shown.map((term, index) => (
              <span key={term.term} data-rank={index < 3 ? 'top' : undefined} style={{ fontSize: `${sampleFontSize(index, shown.length)}px`, fontWeight: index < 2 ? 600 : 400 }}>
                {term.term}
              </span>
            ))}
          </p>
        )}
        {sample.data && <p className="note">{sample.data.provenance}</p>}
      </section>
      <section aria-labelledby={ids.filtering}>
        <h2 id={ids.filtering}>{words.filtering}</h2>
        <label>
          <input type="checkbox" checked={criteria.excludeBoilerplate} aria-describedby={ids.filteringFooter} onChange={(event) => set({ excludeBoilerplate: event.target.checked })} />{' '}
          {words.boilerplate}
        </label>
        <label>
          <input type="checkbox" checked={criteria.filterMarkings} aria-describedby={ids.filteringFooter} onChange={(event) => set({ filterMarkings: event.target.checked })} />{' '}
          {words.markings}
        </label>
        <label>
          <input type="checkbox" checked={criteria.foldPlurals} aria-describedby={ids.filteringFooter} onChange={(event) => set({ foldPlurals: event.target.checked })} />{' '}
          {words.foldPlurals}
        </label>
        <p id={ids.filteringFooter} className="note">
          {words.markingsFooter}
        </p>
      </section>
      <section aria-labelledby={ids.thresholds}>
        <h2 id={ids.thresholds}>{words.thresholds}</h2>
        <Threshold label={words.minLength} value={criteria.minLength} min={2} max={8} describedBy={ids.thresholdsFooter} onChange={(value) => set({ minLength: value })} />
        <Threshold label={words.minCount} value={criteria.minCount} min={1} max={20} describedBy={ids.thresholdsFooter} onChange={(value) => set({ minCount: value })} />
        <p className="cloud-effect">
          <span>{words.effect}</span> <span data-empty={sample.data && kept.length === 0 ? 'true' : undefined}>{sample.data?.summary ?? words.measuring}</span>
        </p>
        <p id={ids.thresholdsFooter} className="note">
          {words.thresholdsFooter}
        </p>
      </section>
      {appearance}
      <HiddenWords
        criteria={criteria}
        scope={scope}
        headingId={ids.hidden}
        footerId={ids.hiddenFooter}
        onScope={setScope}
        onFailure={setFailure}
        onHide={(word) => hideWord(client, word, scope || undefined)}
        onShow={(word) => showWord(client, word, scope || undefined)}
      />
      {failure && (
        <p className="error" role="alert">
          {failure}
        </p>
      )}
    </>
  );
}

/**
 * A threshold, the app's stepper as a number field in its range: a whole number in range is kept as it is typed, as a
 * stepper's step is, and the field shows the kept value again when it is left.
 */
function Threshold({ label, value, min, max, describedBy, onChange }: {
  label: string;
  value: number;
  min: number;
  max: number;
  describedBy: string;
  onChange: (value: number) => void;
}) {
  const [draft, setDraft] = useState(String(value));
  const [shown, setShown] = useState(value);
  if (shown !== value) {
    setShown(value);
    setDraft(String(value));
  }
  return (
    <label>
      {label}{' '}
      <input
        type="number"
        inputMode="numeric"
        min={min}
        max={max}
        step={1}
        value={draft}
        aria-describedby={describedBy}
        onChange={(event) => {
          setDraft(event.target.value);
          const typed = Number(event.target.value);
          if (Number.isInteger(typed) && typed >= min && typed <= max && typed !== value) onChange(typed);
        }}
        onBlur={() => setDraft(String(value))}
      />
    </label>
  );
}

/** Hidden Words: one editor, its list every cloud's or a lens's own (`StopListScope`). */
function HiddenWords({
  criteria,
  scope,
  headingId,
  footerId,
  onScope,
  onFailure,
  onHide,
  onShow,
}: {
  criteria: Criteria;
  scope: string;
  headingId: string;
  footerId: string;
  onScope: (scope: string) => void;
  onFailure: (message: string | undefined) => void;
  onHide: (word: string) => Promise<unknown>;
  onShow: (word: string) => Promise<unknown>;
}) {
  const [word, setWord] = useState('');
  const fieldId = useId();
  const list = scope ? (criteria.lensStopwords[scope] ?? []) : criteria.globalStopwords;

  function add() {
    if (word.trim() === '') return;
    onFailure(undefined);
    onHide(word).then(
      () => setWord(''),
      (error: unknown) => onFailure(errorMessage(error)),
    );
  }

  return (
    <section aria-labelledby={headingId}>
      <h2 id={headingId}>{words.hiddenWords}</h2>
      <label>
        {words.appliesTo}{' '}
        <select value={scope} aria-describedby={footerId} onChange={(event) => onScope(event.target.value)}>
          <option value="">{words.everyCloud}</option>
          {lenses.map((lens) => (
            <option key={lens} value={lens}>
              {words.lenses[lens]}
            </option>
          ))}
        </select>
      </label>
      <form
        className="cloud-add-word"
        onSubmit={(event) => {
          event.preventDefault();
          add();
        }}
      >
        <label htmlFor={fieldId} className="visually-hidden">
          {words.addPrompt}
        </label>
        <input
          id={fieldId}
          type="text"
          autoCapitalize="none"
          autoCorrect="off"
          spellCheck={false}
          placeholder={words.addPrompt}
          value={word}
          onChange={(event) => setWord(event.target.value)}
        />
        <button type="submit" disabled={word.trim() === ''} aria-label={words.addA11y}>
          {words.add}
        </button>
      </form>
      {list.length === 0 ? (
        <p className="note">{words.empty}</p>
      ) : (
        <ul className="cloud-hidden-words">
          {list.map((each) => (
            <li key={each}>
              <span>{each}</span>{' '}
              <button
                type="button"
                aria-label={words.remove(each)}
                onClick={() => {
                  onFailure(undefined);
                  onShow(each).then(
                    () => document.getElementById(fieldId)?.focus(),
                    (error: unknown) => onFailure(errorMessage(error)),
                  );
                }}
              >
                {words.removeShort}
              </button>
            </li>
          ))}
        </ul>
      )}
      <p id={footerId} className="note">
        {scope ? words.lensFooter : words.globalFooter}
      </p>
    </section>
  );
}
