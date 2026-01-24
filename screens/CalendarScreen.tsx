import React, { useMemo, useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView, FlatList } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useQuery } from 'convex/react';
import { useNavigation } from '@react-navigation/native';
import { api } from '../convex/_generated/api';
import { Ionicons } from '@expo/vector-icons';
import { theme } from '../lib/theme';
import Skeleton from '../components/Skeleton';

type Mode = 'day' | 'week' | 'month';

interface Props {
  profile: {
    id: string;
    role: 'parent' | 'helper';
    villageId: any;
    villageName: string;
  };
}

const DayViewSkeleton = () => (
  <View style={{ padding: 16 }}>
    <Skeleton width="100%" height={40} style={{ marginBottom: 16 }} />
    <Skeleton width="100%" height={120} style={{ marginBottom: 12 }} />
    <Skeleton width="100%" height={120} style={{ marginBottom: 12 }} />
  </View>
);

const MonthViewSkeleton = () => (
  <View style={{ paddingHorizontal: 12, paddingTop: 14 }}>
    <View style={styles.monthHeader}>
      <Skeleton width={36} height={36} style={{ borderRadius: 18 }} />
      <Skeleton width={150} height={24} />
      <Skeleton width={36} height={36} style={{ borderRadius: 18 }} />
    </View>
    <View style={styles.dowRow}>
      {Array.from({ length: 7 }).map((_, i) => (
        <View key={i} style={{ flex: 1, alignItems: 'center' }}>
          <Skeleton width="50%" height={12} />
        </View>
      ))}
    </View>
    <View style={styles.grid}>
      {Array.from({ length: 42 }).map((_, i) => (
        <View key={i} style={{ width: '14.2857%', aspectRatio: 1, padding: 4 }}>
          <Skeleton width="100%" height="100%" />
        </View>
      ))}
    </View>
  </View>
);


function isoToday(): string {
  return new Date().toISOString().slice(0, 10);
}

function startOfWeekMonday(iso: string): Date {
  const d = new Date(`${iso}T00:00:00`);
  // JS: 0=Sun ... 6=Sat; we want Monday as 0
  const day = (d.getDay() + 6) % 7;
  d.setDate(d.getDate() - day);
  return d;
}

function toISODate(d: Date): string {
  return d.toISOString().slice(0, 10);
}

function addDays(iso: string, days: number): string {
  const d = new Date(`${iso}T00:00:00`);
  d.setDate(d.getDate() + days);
  return toISODate(d);
}

function addMonths(d: Date, deltaMonths: number): Date {
  const next = new Date(d);
  next.setMonth(next.getMonth() + deltaMonths);
  return next;
}

function formatMonthTitle(d: Date): string {
  return d.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
}

function formatDayTitle(iso: string): string {
  const d = new Date(`${iso}T00:00:00`);
  return d.toLocaleDateString('en-US', { weekday: 'long', month: 'short', day: 'numeric' });
}

function parseTimeToMinutes(time: string): number | null {
  // Accept: "9:00 AM", "12:00 PM", "18:30", "6 PM", "6pm"
  const t = time.trim().toUpperCase();
  const ampmMatch = t.match(/^\s*(\d{1,2})(?::(\d{2}))?\s*(AM|PM)\s*$/);
  if (ampmMatch) {
    let hours = Number(ampmMatch[1]);
    const minutes = Number(ampmMatch[2] ?? '0');
    const meridiem = ampmMatch[3];
    if (hours < 1 || hours > 12 || minutes < 0 || minutes > 59) return null;
    if (meridiem === 'AM') {
      if (hours === 12) hours = 0;
    } else {
      if (hours !== 12) hours += 12;
    }
    return hours * 60 + minutes;
  }

  const h24Match = t.match(/^\s*(\d{1,2}):(\d{2})\s*$/);
  if (h24Match) {
    const hours = Number(h24Match[1]);
    const minutes = Number(h24Match[2]);
    if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) return null;
    return hours * 60 + minutes;
  }

  return null;
}

function sortByTime(a: any, b: any): number {
  const am = parseTimeToMinutes(a.time) ?? 0;
  const bm = parseTimeToMinutes(b.time) ?? 0;
  return am - bm;
}

export default function CalendarScreen({ profile }: Props) {
  const navigation = useNavigation<any>();
  const [mode, setMode] = useState<Mode>('month');
  const [selectedDate, setSelectedDate] = useState<string>(isoToday());
  const [visibleMonth, setVisibleMonth] = useState<Date>(() => {
    const d = new Date(`${isoToday()}T00:00:00`);
    return new Date(d.getFullYear(), d.getMonth(), 1);
  });

  const requests = useQuery(api.helpRequests.getVillageRequests as any, {
    villageId: profile.villageId,
  });

  const villageEvents = useQuery(api.events.getVillageEvents as any, {
    villageId: profile.villageId,
  });
  
  const isLoading = requests === undefined || villageEvents === undefined;

  const eventsByDate = useMemo(() => {
    const map: Record<string, any[]> = {};
    for (const r of requests ?? []) {
      const iso = typeof r.date === 'string' ? r.date.slice(0, 10) : null;
      if (!iso) continue;
      if (!map[iso]) map[iso] = [];
      map[iso].push({ ...r, kind: 'request' });
    }
    for (const ev of villageEvents ?? []) {
      const iso = typeof ev.date === 'string' ? ev.date.slice(0, 10) : null;
      if (!iso) continue;
      if (!map[iso]) map[iso] = [];
      map[iso].push({ ...ev, kind: 'event' });
    }
    for (const key of Object.keys(map)) {
      map[key].sort(sortByTime);
    }
    return map;
  }, [requests, villageEvents]);

  // Memoize week calculation
  const weekDays = useMemo(() => {
    if (mode !== 'week') return [];
    const weekStart = startOfWeekMonday(selectedDate);
    return Array.from({ length: 7 }, (_, i) => {
      const d = new Date(weekStart);
      d.setDate(weekStart.getDate() + i);
      return toISODate(d);
    });
  }, [selectedDate, mode]);

  // Memoize month calculation
  const monthCells = useMemo(() => {
    if (mode !== 'month') return [];
    const year = visibleMonth.getFullYear();
    const month = visibleMonth.getMonth();
    const first = new Date(year, month, 1);
    const startOffset = (first.getDay() + 6) % 7; // Monday start
    const gridStart = new Date(year, month, 1 - startOffset);

    return Array.from({ length: 42 }, (_, i) => {
      const d = new Date(gridStart);
      d.setDate(gridStart.getDate() + i);
      const iso = toISODate(d);
      const inMonth = d.getMonth() === month;
      const isSelected = iso === selectedDate;
      const count = eventsByDate[iso]?.length ?? 0;
      return { iso, day: d.getDate(), inMonth, isSelected, count };
    });
  }, [visibleMonth, selectedDate, mode, eventsByDate]);

  const dayEvents = (eventsByDate[selectedDate] ?? []) as any[];

  const renderEvent = ({ item }: { item: any }) => (
    <View style={styles.eventCard}>
      <View style={styles.eventHeader}>
        <View style={styles.eventTimeRow}>
          <Ionicons name="time-outline" size={16} color={theme.colors.primary} />
          <Text style={styles.eventTime}>{item.time}</Text>
        </View>
        <View
          style={[
            styles.statusBadge,
            item.kind === 'event' ? styles.statusEvent : item.status === 'open' ? styles.statusOpen : styles.statusClaimed,
          ]}
        >
          <Text style={styles.statusText}>
            {item.kind === 'event' ? 'Event' : item.status === 'open' ? 'Open' : 'Claimed'}
          </Text>
        </View>
      </View>

      <Text style={styles.eventTitle}>{item.title}</Text>
      <Text style={styles.eventDescription}>{item.description}</Text>

      <View style={styles.eventFooter}>
        <Text style={styles.eventMeta}>Posted by {item.createdByName}</Text>
        {item.kind !== 'event' && item.claimedByName ? (
          <Text style={styles.eventMeta}>Helping: {item.claimedByName}</Text>
        ) : null}
      </View>
    </View>
  );

  const renderDay = () => (
    <View style={{ flex: 1 }}>
      <View style={styles.dayHeader}>
        <TouchableOpacity
          onPress={() => setSelectedDate(addDays(selectedDate, -1))}
          style={styles.navIcon}
          hitSlop={{ top: 20, bottom: 20, left: 20, right: 20 }}
          accessibilityRole="button"
          accessibilityLabel="Previous day"
        >
          <Ionicons name="chevron-back" size={22} color={theme.colors.text.primary} />
        </TouchableOpacity>
        <Text style={styles.dayTitle}>{formatDayTitle(selectedDate)}</Text>
        <TouchableOpacity
          onPress={() => setSelectedDate(addDays(selectedDate, 1))}
          style={styles.navIcon}
          hitSlop={{ top: 20, bottom: 20, left: 20, right: 20 }}
          accessibilityRole="button"
          accessibilityLabel="Next day"
        >
          <Ionicons name="chevron-forward" size={22} color={theme.colors.text.primary} />
        </TouchableOpacity>
      </View>
      {isLoading ? <DayViewSkeleton/> : (
        <FlatList
          data={dayEvents}
          keyExtractor={(item: any) => `event-${item.id}`}
          renderItem={renderEvent}
          contentContainerStyle={{ padding: 16, paddingBottom: 120 }}
          getItemLayout={(data, index) => ({
            length: 190,
            offset: 190 * index,
            index,
          })}
          ListEmptyComponent={
            <View style={styles.emptyContainer}>
              <Ionicons name="calendar-outline" size={56} color={theme.colors.gray.medium} />
              <Text style={styles.emptyTitle}>No events</Text>
              <Text style={styles.emptyText}>Nothing scheduled for this day.</Text>
            </View>
          }
          removeClippedSubviews={true}
          maxToRenderPerBatch={5}
          windowSize={10}
          initialNumToRender={3}
        />
      )}
    </View>
  );

  const renderWeek = () => (
    <View style={{ flex: 1 }}>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.weekStrip}>
        {weekDays.map((iso) => {
          const isSelected = iso === selectedDate;
          const d = new Date(`${iso}T00:00:00`);
          const count = eventsByDate[iso]?.length ?? 0;
          return (
            <TouchableOpacity
              key={iso}
              style={[styles.weekDayChip, isSelected && styles.weekDayChipSelected]}
              onPress={() => setSelectedDate(iso)}
            >
              <Text style={[styles.weekDayName, isSelected && styles.weekDayNameSelected]}>
                {d.toLocaleDateString('en-US', { weekday: 'short' })}
              </Text>
              <Text style={[styles.weekDayNumber, isSelected && styles.weekDayNumberSelected]}>
                {d.getDate()}
              </Text>
              {count > 0 ? <View style={styles.weekDot} /> : <View style={styles.weekDotPlaceholder} />}
            </TouchableOpacity>
          );
        })}
      </ScrollView>
      {renderDay()}
    </View>
  );

  const renderMonth = () => {
    if (isLoading) {
      return <MonthViewSkeleton/>
    }

    return (
      <View style={{ flex: 1 }}>
        <View style={styles.monthHeader}>
          <TouchableOpacity
            onPress={() => setVisibleMonth((m: Date) => addMonths(m, -1))}
            style={styles.navIcon}
            hitSlop={{ top: 20, bottom: 20, left: 20, right: 20 }}
            accessibilityRole="button"
            accessibilityLabel="Previous month"
          >
            <Ionicons name="chevron-back" size={22} color={theme.colors.text.primary} />
          </TouchableOpacity>
          <Text style={styles.monthTitle}>{formatMonthTitle(visibleMonth)}</Text>
          <TouchableOpacity
            onPress={() => setVisibleMonth((m: Date) => addMonths(m, 1))}
            style={styles.navIcon}
            hitSlop={{ top: 20, bottom: 20, left: 20, right: 20 }}
            accessibilityRole="button"
            accessibilityLabel="Next month"
          >
            <Ionicons name="chevron-forward" size={22} color={theme.colors.text.primary} />
          </TouchableOpacity>
        </View>

        <View style={styles.dowRow}>
          {['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((d) => (
            <Text key={d} style={styles.dowText}>
              {d}
            </Text>
          ))}
        </View>

        <View style={styles.grid}>
          {monthCells.map((c) => (
            <TouchableOpacity
              key={c.iso}
              style={[
                styles.cell,
                c.isSelected && styles.cellSelected,
                !c.inMonth && styles.cellOutOfMonth,
              ]}
              onPress={() => {
                setSelectedDate(c.iso);
                setMode('day');
              }}
            >
              <Text
                style={[
                  styles.cellText,
                  !c.inMonth && styles.cellTextOutOfMonth,
                  c.isSelected && styles.cellTextSelected,
                ]}
              >
                {c.day}
              </Text>
              {c.count > 0 ? <View style={styles.dot} /> : <View style={styles.dotPlaceholder} />}
            </TouchableOpacity>
          ))}
        </View>

        <View style={styles.monthHint}>
          <Text style={styles.monthHintText}>Tap a day to view details</Text>
        </View>
      </View>
    );
  };

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <View style={styles.header}>
        <View style={styles.headerTopRow}>
          <View>
            <Text style={styles.title}>Calendar</Text>
            <Text style={styles.subtitle}>{profile.villageName}</Text>
          </View>
          <TouchableOpacity
            style={styles.addEventBtn}
            onPress={() => navigation.navigate('CreateEvent')}
            accessibilityRole="button"
            accessibilityLabel="Add Event"
            accessibilityHint="Opens a screen to create a new village event"
          >
            <Ionicons name="add" size={22} color={theme.colors.white} />
          </TouchableOpacity>
        </View>
        <View style={styles.segment}>
          <TouchableOpacity
            style={[styles.segmentBtn, mode === 'day' && styles.segmentBtnActive]}
            onPress={() => setMode('day')}
            accessibilityRole="button"
            accessibilityLabel="Day view"
            accessibilityHint="Switches to the day view of the calendar"
          >
            <Text style={[styles.segmentText, mode === 'day' && styles.segmentTextActive]}>Day</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[styles.segmentBtn, mode === 'week' && styles.segmentBtnActive]}
            onPress={() => setMode('week')}
            accessibilityRole="button"
            accessibilityLabel="Week view"
            accessibilityHint="Switches to the week view of the calendar"
          >
            <Text style={[styles.segmentText, mode === 'week' && styles.segmentTextActive]}>Week</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[styles.segmentBtn, mode === 'month' && styles.segmentBtnActive]}
            onPress={() => setMode('month')}
            accessibilityRole="button"
            accessibilityLabel="Month view"
            accessibilityHint="Switches to the month view of the calendar"
          >
            <Text style={[styles.segmentText, mode === 'month' && styles.segmentTextActive]}>Month</Text>
          </TouchableOpacity>
        </View>
      </View>

      {mode === 'month' ? renderMonth() : mode === 'week' ? renderWeek() : renderDay()}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: theme.colors.background,
  },
  header: {
    padding: 20,
    paddingBottom: 14,
    backgroundColor: theme.colors.white,
    borderBottomWidth: 1,
    borderBottomColor: theme.colors.gray.light,
  },
  headerTopRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  addEventBtn: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: theme.colors.primary,
    alignItems: 'center',
    justifyContent: 'center',
  },
  title: {
    fontSize: theme.fontSizes.xl,
    fontWeight: 'bold',
    color: theme.colors.text.primary,
  },
  subtitle: {
    marginTop: 2,
    fontSize: theme.fontSizes.sm,
    color: theme.colors.text.secondary,
  },
  segment: {
    marginTop: 12,
    backgroundColor: theme.colors.background,
    borderRadius: 12,
    padding: 4,
    flexDirection: 'row',
  },
  segmentBtn: {
    flex: 1,
    paddingVertical: 8,
    borderRadius: 10,
    alignItems: 'center',
  },
  segmentBtnActive: {
    backgroundColor: theme.colors.white,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.06,
    shadowRadius: 4,
    elevation: 1,
  },
  segmentText: {
    fontSize: theme.fontSizes.xs,
    fontWeight: '600',
    color: theme.colors.text.secondary,
  },
  segmentTextActive: {
    color: theme.colors.text.primary,
  },
  monthHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingTop: 14,
    paddingBottom: 10,
  },
  monthTitle: {
    fontSize: theme.fontSizes.lg,
    fontWeight: '600',
    color: theme.colors.text.primary,
  },
  navIcon: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: theme.colors.white,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: theme.colors.gray.light,
  },
  dowRow: {
    flexDirection: 'row',
    paddingHorizontal: 12,
    paddingBottom: 8,
  },
  dowText: {
    flex: 1,
    textAlign: 'center',
    fontSize: theme.fontSizes.xs,
    fontWeight: '600',
    color: theme.colors.text.secondary,
  },
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    paddingHorizontal: 12,
  },
  cell: {
    width: '14.2857%',
    aspectRatio: 1,
    borderRadius: 12,
    backgroundColor: theme.colors.white,
    marginBottom: 8,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: theme.colors.gray.light,
  },
  cellSelected: {
    borderColor: theme.colors.primary,
    backgroundColor: theme.colors.primary + '10',
  },
  cellOutOfMonth: {
    backgroundColor: theme.colors.background,
  },
  cellText: {
    fontSize: theme.fontSizes.sm,
    fontWeight: '600',
    color: theme.colors.text.primary,
  },
  cellTextOutOfMonth: {
    color: theme.colors.gray.medium,
  },
  cellTextSelected: {
    color: theme.colors.primary,
  },
  dot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: theme.colors.primary,
    marginTop: 4,
  },
  dotPlaceholder: {
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: 'transparent',
    marginTop: 4,
  },
  monthHint: {
    paddingHorizontal: 16,
    paddingTop: 10,
  },
  monthHintText: {
    fontSize: theme.fontSizes.xs,
    color: theme.colors.text.secondary,
  },
  dayHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingTop: 14,
    paddingBottom: 10,
  },
  dayTitle: {
    fontSize: theme.fontSizes.md,
    fontWeight: '600',
    color: theme.colors.text.primary,
  },
  eventCard: {
    backgroundColor: theme.colors.white,
    borderRadius: 16,
    padding: 16,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: theme.colors.gray.light,
  },
  eventHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 10,
  },
  eventTimeRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  eventTime: {
    fontSize: theme.fontSizes.sm,
    fontWeight: '600',
    color: theme.colors.primary,
  },
  statusBadge: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 12,
  },
  statusOpen: {
    backgroundColor: theme.colors.accent + '20',
  },
  statusClaimed: {
    backgroundColor: theme.colors.status.claimed + '20',
  },
  statusEvent: {
    backgroundColor: theme.colors.primary + '20',
  },
  statusText: {
    fontSize: theme.fontSizes.xs,
    fontWeight: '600',
    color: theme.colors.text.primary,
  },
  eventTitle: {
    fontSize: theme.fontSizes.lg,
    fontWeight: '600',
    color: theme.colors.text.primary,
    marginBottom: 6,
  },
  eventDescription: {
    fontSize: theme.fontSizes.sm,
    color: theme.colors.text.secondary,
    lineHeight: 22,
  },
  eventFooter: {
    borderTopWidth: 1,
    borderTopColor: theme.colors.gray.light,
    paddingTop: 12,
    marginTop: 12,
  },
  eventMeta: {
    fontSize: theme.fontSizes.xs,
    color: theme.colors.text.secondary,
    marginBottom: 4,
  },
  emptyContainer: {
    alignItems: 'center',
    paddingVertical: 60,
    paddingHorizontal: 24,
  },
  emptyTitle: {
    fontSize: theme.fontSizes.lg,
    fontWeight: '600',
    color: theme.colors.text.primary,
    marginTop: 16,
  },
  emptyText: {
    marginTop: 6,
    fontSize: theme.fontSizes.sm,
    color: theme.colors.text.secondary,
    textAlign: 'center',
    lineHeight: 20,
  },
  weekStrip: {
    paddingHorizontal: 12,
    paddingTop: 12,
    paddingBottom: 6,
    gap: 8,
  },
  weekDayChip: {
    width: 64,
    borderRadius: 14,
    backgroundColor: theme.colors.white,
    paddingVertical: 10,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: theme.colors.gray.light,
  },
  weekDayChipSelected: {
    borderColor: theme.colors.primary,
    backgroundColor: theme.colors.primary + '10',
  },
  weekDayName: {
    fontSize: theme.fontSizes.xs,
    fontWeight: '600',
    color: theme.colors.text.secondary,
  },
  weekDayNameSelected: {
    color: theme.colors.primary,
  },
  weekDayNumber: {
    marginTop: 2,
    fontSize: theme.fontSizes.md,
    fontWeight: '700',
    color: theme.colors.text.primary,
  },
  weekDayNumberSelected: {
    color: theme.colors.primary,
  },
  weekDot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: theme.colors.primary,
    marginTop: 6,
  },
  weekDotPlaceholder: {
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: 'transparent',
    marginTop: 6,
  },
});