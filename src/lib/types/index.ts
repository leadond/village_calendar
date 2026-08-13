// ── Enums ──────────────────────────────────────────────────────────
export type UserRole = "parent" | "helper" | "admin" | "guest";
export type VillageType = "family" | "sports" | "school" | "work" | "other";

export type HelpCategoryValue =
  | "school_pickup"
  | "school_dropoff"
  | "sports_practice"
  | "doctor_appointment"
  | "playdate"
  | "babysitting"
  | "overnight"
  | "emergency"
  | "event"
  | "party"
  | "other";

export const HELP_CATEGORIES: { value: HelpCategoryValue; label: string; icon: string }[] = [
  { value: "school_pickup", label: "School pickup", icon: "Bus" },
  { value: "school_dropoff", label: "School dropoff", icon: "BusFront" },
  { value: "sports_practice", label: "Sports / practice", icon: "Trophy" },
  { value: "doctor_appointment", label: "Doctor appointment", icon: "Stethoscope" },
  { value: "playdate", label: "Playdate", icon: "Gamepad2" },
  { value: "babysitting", label: "Babysitting", icon: "Baby" },
  { value: "overnight", label: "Overnight", icon: "Moon" },
  { value: "emergency", label: "Emergency", icon: "Siren" },
  { value: "event", label: "Event", icon: "CalendarDays" },
  { value: "party", label: "Party", icon: "PartyPopper" },
  { value: "other", label: "Other", icon: "HelpCircle" },
];

export type HelpStatusValue =
  | "open"
  | "claimed"
  | "confirmed"
  | "in_progress"
  | "arrived"
  | "completed"
  | "cancelled"
  | "incident";

export const HELP_STATUS_LABELS: Record<HelpStatusValue, string> = {
  open: "Open",
  claimed: "Claimed",
  confirmed: "Confirmed",
  in_progress: "On the way",
  arrived: "Arrived",
  completed: "Completed",
  cancelled: "Cancelled",
  incident: "Incident",
};

export type EmergencyTypeValue =
  | "help_needed"
  | "medical"
  | "medical_emergency"
  | "safety"
  | "safety_concern";

export const EMERGENCY_TYPES: { value: EmergencyTypeValue; label: string; emoji: string }[] = [
  { value: "help_needed", label: "Help needed", emoji: "🆘" },
  { value: "medical", label: "Medical", emoji: "➕" },
  { value: "medical_emergency", label: "Medical emergency", emoji: "🚑" },
  { value: "safety", label: "Safety", emoji: "⚠️" },
  { value: "safety_concern", label: "Safety concern", emoji: "⚠️" },
];

export type AvailabilityKind = "work" | "available" | "unavailable";

// ── Models ─────────────────────────────────────────────────────────
export interface Profile {
  id: string;
  email: string;
  display_name: string;
  name?: string;
  role: UserRole;
  village_id?: string | null;
  current_village_id?: string | null;
  avatar_url?: string | null;
  subscription_tier: string;
  reliability_score: number;
}

export interface Village {
  id: string;
  name: string;
  invite_code: string;
  admin_id?: string | null;
  village_type: VillageType;
  avatar_url?: string | null;
}

export interface VillageMembership {
  village_id: string;
  name: string;
  invite_code: string;
  role: string;
  is_active: boolean;
}

export interface KidProfile {
  id: string;
  parent_id: string;
  name: string;
  village_id?: string | null;
  nickname?: string | null;
  photo_url?: string | null;
  date_of_birth?: string | null;
  birthdate?: string | null;
  grade?: string | null;
  school?: string | null;
  school_name?: string | null;
  allergies: string[];
  medical_notes?: string | null;
  notes?: string | null;
  care_start_time?: string | null;
  care_end_time?: string | null;
  care_weekdays: number[];
  age_years?: number | null;
  has_care_window: boolean;
}

export interface KidDraft {
  name: string;
  nickname?: string;
  date_of_birth?: string | null;
  grade?: string;
  school?: string;
  allergies: string[];
  medical_notes?: string;
  notes?: string;
  care_start_minutes?: number | null;
  care_end_minutes?: number | null;
  care_weekdays: number[];
  photo_file?: File | null;
}

export interface HelpRequest {
  id: string;
  village_id?: string | null;
  creator_id: string;
  helper_id?: string | null;
  title: string;
  description?: string | null;
  category: HelpCategoryValue;
  status: HelpStatusValue;
  scheduled_start: string;
  scheduled_at?: string;
  scheduled_end?: string | null;
  pickup_address?: string | null;
  dropoff_address?: string | null;
  special_instructions?: string | null;
  kid_ids: string[];
  parent_confirmed_at?: string | null;
  helper_checkin_at?: string | null;
  arrived_at_destination_at?: string | null;
  parent_receipt_confirmed_at?: string | null;
  created_at?: string;
  is_draft?: boolean;
  auto_generated?: boolean;
  cancellation_reason?: string | null;
  cancelled_by?: string | null;
  is_recurring?: boolean;
  recurrence_rule?: string | null;
}

export interface HelpRequestDraft {
  title: string;
  category: HelpCategoryValue;
  scheduled_start: string;
  scheduled_end?: string | null;
  description?: string;
  pickup_address?: string;
  dropoff_address?: string;
  special_instructions?: string;
  kid_ids: string[];
  is_recurring?: boolean;
  recurrence_rule?: string | null;
}

export interface RequestComment {
  id: string;
  request_id: string;
  author_id: string;
  body: string;
  created_at: string;
}

export interface Message {
  id: string;
  request_id: string;
  sender_id: string;
  recipient_id?: string | null;
  content?: string;
  body: string;
  created_at: string;
  read_at?: string | null;
  attachment_url?: string | null;
}

export interface DirectMessage {
  id: string;
  village_id: string;
  sender_id: string;
  recipient_id: string;
  body: string;
  created_at: string;
  read_at?: string | null;
  attachment_url?: string | null;
}

export interface Announcement {
  id: string;
  village_id: string;
  created_by: string;
  title: string;
  message: string;
  created_at: string;
}

export interface AppNotification {
  id: string;
  type: string;
  title: string;
  body: string;
  data: Record<string, unknown>;
  created_at: string;
  read_at?: string | null;
}

export interface EmergencyAlert {
  id: string;
  sender_id: string;
  village_id?: string | null;
  alert_type: EmergencyTypeValue;
  status: "active" | "resolved" | "cancelled";
  message?: string | null;
  lat?: number | null;
  lng?: number | null;
  created_at: string;
  resolved_at?: string | null;
  resolved_by?: string | null;
}

export interface AvailabilityBlock {
  id: string;
  user_id: string;
  village_id: string;
  kind: AvailabilityKind;
  weekday?: number | null;
  specific_date?: string | null;
  start_time: string;
  end_time: string;
  note?: string | null;
}

export interface Breadcrumb {
  lat: number;
  lng: number;
  ts: string;
  accuracy?: number | null;
  speed?: number | null;
  heading?: number | null;
}

export interface JoinRequestResult {
  status: string;
  village_name?: string | null;
}

export interface PendingJoin {
  request_id: string;
  village_id: string;
  village_name: string;
}

export interface JoinRequestItem {
  request_id: string;
  requester_id: string;
  display_name: string;
  email: string;
  created_at: string;
}

export interface VillageEvent {
  id: string;
  title: string;
  description?: string | null;
  location?: string | null;
  starts_at: string;
  ends_at?: string | null;
  created_by: string;
  village_id?: string | null;
}

export interface AuditEntry {
  created_at: string;
  action: string;
  actor_name: string;
}

// ── Daily Care Log ──────────────────────────────────────────────────
export interface DailyLog {
  id: string;
  request_id: string;
  kid_id: string;
  logged_by: string;
  entry_type: "meal" | "nap" | "activity" | "note" | "photo";
  description: string;
  created_at: string;
  photo_url?: string | null;
}

export interface MedicineLog {
  id: string;
  kid_id: string;
  request_id?: string | null;
  administered_by: string;
  medicine_name: string;
  dosage: string;
  administered_at: string;
  notes?: string | null;
}

// ── Group Chat ─────────────────────────────────────────────────────
export interface GroupChatMessage {
  id: string;
  village_id: string;
  sender_id: string;
  body: string;
  created_at: string;
  attachment_url?: string | null;
}
