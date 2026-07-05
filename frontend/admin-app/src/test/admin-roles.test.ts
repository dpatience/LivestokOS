import { describe, expect, it } from "vitest";
import { isSuperAdmin } from "@livestok/api";

describe("admin roles", () => {
  it("only super_admin passes admin guard helper", () => {
    expect(isSuperAdmin("super_admin")).toBe(true);
    expect(isSuperAdmin("farm_owner")).toBe(false);
    expect(isSuperAdmin("farm_worker")).toBe(false);
  });
});
