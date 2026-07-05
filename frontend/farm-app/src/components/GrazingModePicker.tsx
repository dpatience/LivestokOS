import { GRAZING_MODE_INFO, type GrazingMode } from "@livestok/api";
import { Card, farmInteractive } from "@livestok/ui";

interface GrazingModePickerProps {
  value: GrazingMode;
  onChange: (mode: GrazingMode) => void;
}

const MODES: GrazingMode[] = ["pasture", "zero_grazing", "mixed"];

export function GrazingModePicker({ value, onChange }: GrazingModePickerProps) {
  return (
    <div className="space-y-3">
      <p className="text-farm-body font-semibold text-farm-text">
        How does your farm operate?
      </p>
      <p className="text-sm text-farm-text-muted">
        This choice controls which modules appear later (pasture tools vs indoor/zero-grazing
        tools). You can change it in farm settings.
      </p>
      <div className="space-y-3">
        {MODES.map((mode) => {
          const info = GRAZING_MODE_INFO[mode];
          const selected = value === mode;
          return (
            <button
              key={mode}
              type="button"
              onClick={() => onChange(mode)}
              className={`w-full rounded-farm border-2 p-4 text-left ${farmInteractive} ${
                selected
                  ? "border-farm-primary bg-farm-primary/5"
                  : "border-farm-border bg-farm-surface hover:border-farm-primary/50 hover:bg-farm-surface-alt"
              }`}
            >
              <p className="text-farm-body font-bold text-farm-text">{info.title}</p>
              <p className="mt-1 text-sm text-farm-text-muted">{info.description}</p>
              <ul className="mt-2 list-inside list-disc text-sm text-farm-text-muted">
                {info.features.map((f) => (
                  <li key={f}>{f}</li>
                ))}
              </ul>
            </button>
          );
        })}
      </div>
    </div>
  );
}

export function GrazingModeBadge({ mode }: { mode: GrazingMode }) {
  return (
    <Card variant="farm" className="!py-2">
      <p className="text-sm text-farm-text-muted">Grazing mode</p>
      <p className="font-semibold text-farm-text">{GRAZING_MODE_INFO[mode].title}</p>
    </Card>
  );
}
