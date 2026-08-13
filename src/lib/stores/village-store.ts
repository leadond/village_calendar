import { create } from "zustand";
import { createClient } from "@/lib/supabase/client";
import type {
  Village,
  VillageMembership,
  Profile,
  JoinRequestResult,
  PendingJoin,
  JoinRequestItem,
  AuditEntry,
} from "@/lib/types";

interface VillageState {
  currentVillage: Village | null;
  memberships: VillageMembership[];
  members: Profile[];
  pendingJoins: JoinRequestItem[];
  myPendingJoin: PendingJoin | null;
  loading: boolean;
  fetchCurrentVillage: (villageId: string) => Promise<void>;
  fetchMemberships: () => Promise<void>;
  fetchMembers: () => Promise<void>;
  fetchPendingJoins: () => Promise<void>;
  fetchMyPendingJoin: () => Promise<void>;
  createVillage: (name: string, type: string) => Promise<Village>;
  requestToJoin: (code: string) => Promise<JoinRequestResult>;
  switchVillage: (villageId: string) => Promise<void>;
  approveJoin: (requestId: string) => Promise<void>;
  rejectJoin: (requestId: string) => Promise<void>;
  cancelMyJoin: (requestId: string) => Promise<void>;
  setMemberRole: (userId: string, role: string) => Promise<void>;
  removeMember: (userId: string) => Promise<void>;
  fetchAudit: () => Promise<AuditEntry[]>;
}

export const useVillageStore = create<VillageState>((set, get) => ({
  currentVillage: null,
  memberships: [],
  members: [],
  pendingJoins: [],
  myPendingJoin: null,
  loading: false,

  fetchCurrentVillage: async (villageId: string) => {
    const supabase = createClient();
    const { data } = await supabase
      .from("villages")
      .select("*")
      .eq("id", villageId)
      .maybeSingle();
    if (data) set({ currentVillage: data as Village });
  },

  fetchMemberships: async () => {
    const supabase = createClient();
    const { data } = await supabase.rpc("my_villages");
    if (data) set({ memberships: data as VillageMembership[] });
  },

  fetchMembers: async () => {
    const supabase = createClient();
    const { data } = await supabase.rpc("active_village_members");
    if (data && Array.isArray(data)) {
      set({ members: data.map((m) => ({ ...m, role: m.role || "parent" } as Profile)) });
    }
  },

  fetchPendingJoins: async () => {
    const supabase = createClient();
    const { data } = await supabase.rpc("pending_join_requests");
    if (data && Array.isArray(data)) {
      set({ pendingJoins: data.map((j) => ({
        ...j,
        request_id: j.request_id,
        requester_id: j.requester_id,
        display_name: j.display_name,
        email: j.email,
        created_at: j.created_at,
      } as JoinRequestItem)) });
    }
  },

  fetchMyPendingJoin: async () => {
    const supabase = createClient();
    const { data } = await supabase.rpc("my_pending_join_request");
    if (data) set({ myPendingJoin: data as PendingJoin });
    else set({ myPendingJoin: null });
  },

  createVillage: async (name: string, type: string) => {
    const supabase = createClient();
    const { data } = await supabase.rpc("create_village", {
      p_name: name,
      p_type: type,
    });
    return data as Village;
  },

  requestToJoin: async (code: string) => {
    const supabase = createClient();
    const { data } = await supabase.rpc("request_to_join_village", {
      p_code: code.toUpperCase(),
    });
    return {
      status: (data as Record<string, unknown>)?.["status"] as string ?? "error",
      village_name: (data as Record<string, unknown>)?.["village_name"] as string | undefined,
    } as JoinRequestResult;
  },

  switchVillage: async (villageId: string) => {
    const supabase = createClient();
    await supabase.rpc("switch_active_village", { p_village: villageId });
    // Clear state so it re-fetches
    set({ currentVillage: null, members: [], pendingJoins: [] });
  },

  approveJoin: async (requestId: string) => {
    const supabase = createClient();
    await supabase.rpc("approve_join_request", { p_request_id: requestId });
  },

  rejectJoin: async (requestId: string) => {
    const supabase = createClient();
    await supabase.rpc("reject_join_request", { p_request_id: requestId });
  },

  cancelMyJoin: async (requestId: string) => {
    const supabase = createClient();
    await supabase.from("village_join_requests").delete().eq("id", requestId);
  },

  setMemberRole: async (userId: string, role: string) => {
    const supabase = createClient();
    await supabase.rpc("set_member_role", { p_user: userId, p_role: role });
  },

  removeMember: async (userId: string) => {
    const supabase = createClient();
    await supabase.rpc("remove_member", { p_user: userId });
  },

  fetchAudit: async () => {
    const supabase = createClient();
    const { data } = await supabase.rpc("active_village_audit");
    return (data as AuditEntry[]) ?? [];
  },
}));
