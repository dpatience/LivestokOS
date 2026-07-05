/**
 * Pairing helpers — device UID maps to Device.serial (verified in LoRaWAN ingest + tests).
 */
import type { Device, DevicePayload } from "./inventory";
import type { FarmResources } from "./resources";

export const NECKLACE_HARDWARE_TYPE = "necklace";

export interface PairDeviceInput {
  serial: string;
  farmId: number;
  cowId: number;
}

export interface PairDevicePlan {
  action: "create" | "update";
  deviceId?: number;
  payload: DevicePayload;
}

/** Decide create vs update from an existing device list (no GET-by-serial endpoint). */
export function planPairDevice(
  serial: string,
  farmId: number,
  cowId: number,
  existingDevices: Device[],
): PairDevicePlan {
  const normalized = serial.trim();
  const match = existingDevices.find(
    (d) => d.serial.toLowerCase() === normalized.toLowerCase(),
  );

  const base: DevicePayload = {
    serial: normalized,
    hardware_type: NECKLACE_HARDWARE_TYPE,
    farm_id: farmId,
    cow_id: cowId,
    status: "online",
  };

  if (match) {
    return {
      action: "update",
      deviceId: match.id,
      payload: {
        serial: normalized,
        farm_id: farmId,
        cow_id: cowId,
        hardware_type: match.hardware_type || NECKLACE_HARDWARE_TYPE,
      },
    };
  }

  return { action: "create", payload: base };
}

export async function executePairDevice(
  resources: FarmResources,
  plan: PairDevicePlan,
): Promise<Device> {
  if (plan.action === "update" && plan.deviceId != null) {
    const { data } = await resources.updateDevice(plan.deviceId, plan.payload);
    return data;
  }
  const { data } = await resources.createDevice(plan.payload);
  return data;
}

export function planUnpairDevice(): Partial<DevicePayload> {
  return { cow_id: null };
}

export async function executeUnpairDevice(
  resources: FarmResources,
  deviceId: number,
): Promise<Device> {
  const { data } = await resources.updateDevice(deviceId, planUnpairDevice());
  return data;
}
