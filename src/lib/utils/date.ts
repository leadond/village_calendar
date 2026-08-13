import { format, parseISO, startOfWeek, addDays, isSameDay } from "date-fns";

export function formatDate(iso: string | null | undefined, fmt: string = "EEE, MMM d · h:mm a"): string {
  if (!iso) return "";
  try {
    return format(parseISO(iso), fmt);
  } catch {
    return iso;
  }
}

export function formatTime(minutes: number): string {
  const h24 = Math.floor(minutes / 60);
  const m = minutes % 60;
  const ampm = h24 >= 12 ? "PM" : "AM";
  let h = h24 % 12;
  if (h === 0) h = 12;
  return `${h}:${m.toString().padStart(2, "0")} ${ampm}`;
}

export function parseTimeToMinutes(t: string | null | undefined): number | null {
  if (!t) return null;
  const parts = t.split(":");
  const h = parseInt(parts[0]) || 0;
  const m = parts.length > 1 ? parseInt(parts[1]) || 0 : 0;
  return h * 60 + m;
}

export function minutesToTime(minutes: number): string {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return `${h.toString().padStart(2, "0")}:${m.toString().padStart(2, "0")}`;
}

export function mondayOf(d: Date): Date {
  return startOfWeek(d, { weekStartsOn: 1 });
}

export function sameDay(a: Date, b: Date): boolean {
  return isSameDay(a, b);
}

export const WEEKDAY_NAMES = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

export function kidAge(dob: string | null | undefined): number | null {
  if (!dob) return null;
  const birth = parseISO(dob);
  const now = new Date();
  let age = now.getFullYear() - birth.getFullYear();
  const m = now.getMonth() - birth.getMonth();
  if (m < 0 || (m === 0 && now.getDate() < birth.getDate())) age--;
  return age < 0 ? null : age;
}

export function isStatusActive(s: string): boolean {
  return ["claimed", "confirmed", "in_progress", "arrived"].includes(s);
}

export function isStatusTerminal(s: string): boolean {
  return ["completed", "cancelled"].includes(s);
}
