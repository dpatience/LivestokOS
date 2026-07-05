import type { Cow, Device } from "@livestok/api";
import { Card } from "@livestok/ui";
import { useCallback, useEffect, useState } from "react";
import { CowSearchPicker } from "../components/CowSearchPicker";
import { DiaryEntryForm } from "../components/DiaryEntryForm";
import { NfcCowIdentify, type IdentifiedCow } from "../components/NfcCowIdentify";
import { SyncStatusBar } from "../components/SyncStatusBar";
import { countOutboxByStatus } from "../db/outbox";
import { useAuth } from "../context/AuthContext";
import {
  flushOutbox,
  registerBackgroundSyncBonus,
  submitDiaryEntry,
  type DiarySubmission,
} from "../lib/diary-sync";

export function DiaryPage() {
  const { user, resources, farm } = useAuth();
  const [cows, setCows] = useState<Cow[]>([]);
  const [devices, setDevices] = useState<Device[]>([]);
  const [selectedCow, setSelectedCow] = useState<IdentifiedCow | null>(null);
  const [savedMessage, setSavedMessage] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [flushing, setFlushing] = useState(false);
  const [online, setOnline] = useState(
    typeof navigator !== "undefined" ? navigator.onLine : true,
  );
  const [syncCounts, setSyncCounts] = useState({
    queued: 0,
    syncing: 0,
    synced: 0,
    failed: 0,
  });

  const refreshSyncCounts = useCallback(async () => {
    const counts = await countOutboxByStatus();
    setSyncCounts(counts);
  }, []);

  const runFlush = useCallback(async () => {
    if (!navigator.onLine) return;
    setFlushing(true);
    try {
      await flushOutbox(resources);
    } finally {
      setFlushing(false);
      await refreshSyncCounts();
    }
  }, [resources, refreshSyncCounts]);

  useEffect(() => {
    void (async () => {
      const [cowRes, deviceRes] = await Promise.all([
        resources.listCows({ limit: 200 }),
        resources.listDevices({ limit: 200 }),
      ]);
      setCows(cowRes.data);
      setDevices(deviceRes.data);
    })();
    void refreshSyncCounts();
    registerBackgroundSyncBonus();
  }, [resources, refreshSyncCounts]);

  useEffect(() => {
    function onOnline() {
      setOnline(true);
      void runFlush();
    }
    function onOffline() {
      setOnline(false);
    }
    window.addEventListener("online", onOnline);
    window.addEventListener("offline", onOffline);
    return () => {
      window.removeEventListener("online", onOnline);
      window.removeEventListener("offline", onOffline);
    };
  }, [runFlush]);

  async function handleSubmit(submission: DiarySubmission) {
    setLoading(true);
    setSavedMessage(null);
    try {
      const result = await submitDiaryEntry(submission, {
        resources,
        online: navigator.onLine,
      });
      await refreshSyncCounts();
      if (result.mode === "queued") {
        setSavedMessage("Entry saved offline — will sync when connected.");
      } else {
        setSavedMessage("Entry logged.");
        void runFlush();
      }
      setSelectedCow(null);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="space-y-4">
      <h2 className="text-xl font-bold">Daily diary</h2>

      <SyncStatusBar
        summary={{ ...syncCounts, online }}
        flushing={flushing}
        onRetry={() => void runFlush()}
      />

      {savedMessage ? (
        <Card variant="farm">
          <p className="font-semibold text-farm-success" role="status">
            {savedMessage}
          </p>
        </Card>
      ) : null}

      {selectedCow ? (
        <DiaryEntryForm
          cowId={selectedCow.id}
          cowName={selectedCow.name}
          farmId={user?.farm_id ?? undefined}
          loading={loading}
          onSubmit={handleSubmit}
        />
      ) : (
        <>
          <NfcCowIdentify devices={devices} onCow={setSelectedCow} />
          <div className="relative py-2 text-center text-sm font-semibold text-farm-text-muted">
            <span className="bg-farm-surface px-2">or search</span>
            <div className="absolute inset-x-0 top-1/2 -z-10 border-t border-farm-border" />
          </div>
          <CowSearchPicker cows={cows} onSelect={setSelectedCow} />
        </>
      )}

      {selectedCow ? (
        <button
          type="button"
          className="tap-target w-full text-sm font-semibold text-farm-primary underline"
          onClick={() => setSelectedCow(null)}
        >
          Pick a different cow
        </button>
      ) : null}

      {farm ? (
        <p className="text-xs text-farm-text-muted">
          Entries post to /api/feed_events, /api/inhibitor_doses, /api/grazing_events, or PUT
          /api/cows/:id (health). No unified diary endpoint exists on the backend.
        </p>
      ) : null}
    </div>
  );
}
